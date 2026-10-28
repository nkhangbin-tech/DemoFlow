# Presenter Assistant Architecture

## Shape

Use one Win64 Delphi VCL executable with a hidden main form and system-tray
icon. The UI thread is the coordinator and owner of VCL controls. Services
publish immutable messages to a controller-owned queue; the controller applies
state transitions on the UI thread. Domain units do not depend on VCL, COM,
HWNDs, or file paths.

Recommended source layout for PA-003:

| Area | Responsibility | Depends on |
|---|---|---|
| `Domain` | records, enums, result types, sequence and volume policies | RTL only |
| `Config` | JSON parsing, schema validation, atomic replacement | Domain, `System.JSON` |
| `App` | lifecycle, controller, service coordination, safe mode | Domain, service interfaces |
| `PowerPoint` | COM adapter, polling, optional event sink | RTL/Windows, Domain |
| `Audio` | Core Audio adapter and endpoint notifications | Windows COM, Domain |
| `Windows` | window discovery/activation and input hooks | Winapi.Windows, Domain |
| `UI` | tray menu, status, diagnostics, configuration commands | VCL, App interfaces |
| `Infrastructure` | clock, logging, file replacement, queues | RTL/Windows |

Dependency direction is inward: adapters depend on domain interfaces; domain
never references COM, VCL forms, HWNDs, or configuration paths.

## State ownership and messages

`TApplicationController` owns the current immutable
`TApplicationSnapshot`, active validated configuration, sequence cursor, volume
state, input binding snapshot, service health, and safe-mode flag. It is the
only writer of this aggregate.

Services emit typed messages such as `PowerPointSnapshot`,
`PowerPointHealth`, `AudioEndpointChanged`, `AudioVolumeChanged`,
`WindowObservation`, `InputObservation`, `InputCommandResult`, and
`ServiceFault`. Messages are heap-owned records or reference-counted immutable
objects placed in a thread-safe queue. The UI thread drains the queue through a
posted private window message or a short timer; it never waits on a worker while
holding VCL state.

Every message carries a monotonic sequence number, observed timestamp, source,
and correlation ID. Late messages are rejected by service generation and
timestamp checks.

## Thread and COM ownership

| Component | Owner | Rules |
|---|---|---|
| VCL/tray/controller | Main VCL thread, STA | All UI and state commits occur here |
| PowerPoint adapter | Dedicated STA worker | `CoInitializeEx(COINIT_APARTMENTTHREADED)`, own COM references, message pump if events are enabled |
| Core Audio adapter | Dedicated STA worker, selected for the initial implementation | Creates, uses, and releases all Core Audio COM interfaces; owns notification registration; receives commands through a nonblocking command queue |
| Low-level hooks | Dedicated hook thread with message loop | Callback performs bounded synchronous policy lookup and posts nonblocking commands; no COM or VCL |
| Logger | Dedicated writer or synchronized infrastructure service | Bounded queue, explicit overflow policy, no UI-thread blocking on disk |

### Core Audio ownership

The dedicated audio STA creates and owns `IMMDeviceEnumerator`,
`IMMDevice`, `IAudioEndpointVolume`, and the endpoint notification registration.
All read/write volume commands are executed on that same worker. The controller
posts a compact command; it never calls the COM interface directly.

The `IAudioEndpointVolumeCallback` callback may execute on an audio-service
callback context. It only copies the event context, scalar, mute state, and
endpoint generation into a bounded notification message. It does not evaluate
rules, call endpoint methods, wait for a queue, or re-enter COM. The audio
worker consumes notifications and publishes them to the controller.

The worker unregisters the endpoint callback before releasing the endpoint,
enumerator, and COM initialization. Default-device notifications invalidate the
current endpoint, increment its generation, and cause fresh enumeration on the
audio worker. Shutdown stops new commands, unregisters callbacks, releases
interfaces, then joins the worker. All GUIDs, vtable declarations, calling
conventions, and event-context semantics must be verified against authoritative
Windows SDK declarations before implementation; this document does not invent
those declarations.

## PowerPoint polling and event reconciliation

The PowerPoint adapter uses polling as its authoritative reconciliation source
and subscribes to the verified `EApplication` event connection point as an
accelerator. Both the generated event wrapper and all PowerPoint COM
interfaces remain owned by the same STA worker. The worker attaches only to an
existing instance, reads `SlideShowWindows`, `View.Slide`, `SlideIndex`, and
`CurrentShowPosition`, then releases temporary references. Polling cadence and
COM timeout behavior are implementation constants, not scenario values.

States are `Disconnected`, `ConnectedNoShow`, `ShowKnown`, `ShowUnknown`, and
`Faulted`. Modal dialogs, RPC/COM errors, terminated shows, and stale snapshots
move the adapter to an explicit degraded state and schedule bounded reconnect.
The controller retains the last valid context for browser volume evaluation
until its configured freshness limit; after that it is stale and cannot drive
automatic routing or entry-specific volume matching.

The verified event callbacks record only a bounded event sequence, timestamp,
event name, and reconciliation request; they do not call COM, log
synchronously, or update VCL state. The STA pumps its Windows message queue so
COM events can be delivered, and reconciliation runs after callbacks return.
`SlideShowNextSlide` and `SlideShowNextBuild` are pre-transition notifications,
so neither publishes the announced slide or an animation build as current.
Build and next-click counters are diagnostic event counts, not authoritative
sequence positions. Polling remains the reconciliation source of truth and
detects missed events.

An observed `CurrentShowPosition` of zero, or a failed property read, is
unavailable. The adapter preserves independently valid slide-index data,
marks the show position unavailable, and publishes a later poll when valid
data returns. A COM/RPC failure invalidates the connection and cached
observation, unadvises the event sink before releasing its source, and retries
attachment on the bounded polling cadence. A successful reconnect is not
reported until a new event sink is connected and a fresh observation is
published.

## Synchronous input boundary

Input observation and input suppression are separate decisions. The hook
callback must decide synchronously whether to return the event to the hook chain
or suppress it; it cannot await the controller.

The controller publishes an immutable, atomically replaced
`TInputBindingSnapshot` containing enabled state, binding identity, capture-only
state, routing mode, hook generation, and the command authorization needed for
the configured mapping. The hook thread owns a read-only reference to the
latest safely published snapshot. Publication uses an atomic pointer/reference
swap with lifetime protection; the callback never waits for the controller.

The low-level keyboard/mouse callback performs only bounded work:

1. Copy the event data and reject injected events, repeated key-downs, and
   unrelated devices according to the snapshot policy.
2. Read the current snapshot.
3. If capture-only mode is active, record an observation through a nonblocking
   bounded queue and **return zero** so ordinary input is preserved.
4. If a fully enabled, configured mapping matches and a command slot is
   available, reserve that slot, enqueue a nonblocking `WinTabCommand`, and
   return nonzero to suppress the selected physical event.
5. Otherwise return zero and call the next hook.

Unknown state, disabled mapping, unavailable queue, stale snapshot, unsupported
event, failed slot reservation, or any input not safely authorized to intercept
always passes through. The callback never calls PowerPoint COM, Core Audio,
VCL, logging I/O, configuration code, `SendInput`, waits, locks with
unbounded duration, or blocking operations.

The command consumer performs `SendInput` outside the hook callback. It sends a
complete key sequence with explicit key-down/up pairs, checks the returned count,
and records partial failure. It ignores injected hook events generated by its
own command using the documented injected-event flags. Repeated key-downs are
not separately suppressed. If the physical input was suppressed but dispatch
fails, PA cannot replay that physical input; it reports the failure, clears the
reserved slot, emits best-effort modifier cleanup, and disables the mapping
until explicitly re-enabled if cleanup cannot be confirmed. No key is left
logically held in PA's state.

Capture-only mode never suppresses input. Disable and shutdown first publish a
disabled snapshot, then unhook, stop the hook message loop, and join the hook
thread. Repeated stop is safe.

## Window discovery and activation

Window discovery enumerates top-level windows and scores configured criteria:
process executable, process ID when runtime-known, class name, title pattern,
and visibility. PowerPoint slideshow windows are distinguished from editor
windows by window class/title plus the active slideshow relationship; no single
title is trusted. HWNDs are never serialized.

Activation tries restore/show, foreground activation, and a bounded verification
of the resulting foreground HWND. Failure is reported explicitly. It does not
silently send keys to a different window.

## Shutdown order

1. Mark controller stopping and publish a disabled input snapshot.
2. Disable routing and input capture.
3. Unhook input and join the hook thread.
4. Stop PowerPoint polling/events and release COM on its owner STA.
5. Stop audio commands, unregister endpoint notifications, release audio COM,
   and join the audio worker.
6. Drain/discard queued stale messages by generation.
7. Flush logger with a bounded timeout.
8. Destroy tray/UI state.

## Packaging

Initial distribution is a per-user Win64 executable and documented
configuration directory. No installer, service, startup registration, registry
write, or administrator requirement is part of the initial scope. Runtime
support must explicitly state Windows version, Office bitness/version, display
setup, and presenter hardware assumptions after manual verification.

# PA-008B Production Core Audio Service

## Scope

`Audio\PACoreAudioService.pas` is the production adapter for the Windows
default console render endpoint. It is not integrated into PA-009 and does not
apply slide, browser, delta-mode, or automatic volume rules.

The service owns all Core Audio COM objects on a dedicated
`COINIT_APARTMENTTHREADED` worker. The caller never receives a COM interface.
Snapshots and request results are copied under a lock and can be read from the
controller thread without entering COM.

## Public API

### `TAudioService`

- `Create(EnableDiagnostics)` creates a service. Volume and mute state are
  callback-driven after the initial endpoint read; there is no volume polling
  interval.
- `Start` starts the worker. Repeated calls are harmless.
- `Stop(TimeoutMs)` requests shutdown and returns whether the worker stopped
  within the requested wait. A `False` result means the service object must not
  be freed until shutdown has completed; its destructor waits without claiming a
  bounded duration.
- `TryGetLatest` returns the latest immutable `TAudioServiceSnapshot`.
- `RequestMasterVolume(Percent, RequestId, ErrorText)` accepts only integer
  values from 0 through 100. Acceptance means queueing only; it performs no
  Core Audio call on the caller thread.
- `TryGetRequestResult` returns `pending`, `succeeded`, `failed`, or `rejected`
  status for an accepted request.

`TAudioServiceSnapshot` reports service state, active endpoint count, default
endpoint ID, friendly name, device state, scalar volume, rounded display
percentage, mute state, event-context classification counters, observation source, callback registration HRESULT, callback-processed count,
and explicit error text. Unavailable
volume readings have `HasVolume=False`; zero is never used as an unavailable
fallback.

## Worker and notification behavior

The worker enumerates active render endpoints and binds only the current
`eRender`/`eConsole` default endpoint. It registers:

- `IMMNotificationClient` for endpoint/default-device changes.
- `IAudioEndpointVolumeCallback` for endpoint-volume changes.

Callbacks only copy the minimum notification data and signal the worker. They
do not reconstruct endpoints, wait for service locks, log synchronously, or
perform Core Audio operations. The worker performs one initial endpoint
resolution and later resolves/rebinds only after device/default-endpoint
notifications. Endpoint
volume callbacks compare the event-context GUID with the service's stable
per-instance GUID, so service-originated and external changes are reported
separately.

Shutdown unregisters endpoint callbacks before releasing endpoint interfaces,
unregisters device notifications before releasing the enumerator, uninitializes
COM on the worker, and rejects queued requests that were not completed.

## Service probe

The separate harness [PAAudioServiceProbe.dpr](../tools/PAAudioServiceProbe.dpr)
uses only the public service API:

```text
Win64\Debug\audio-service-probe\PAAudioServiceProbe.exe 10
```

The explicit one-shot mode runs for ten seconds and prints the initial snapshot
plus subsequent meaningful changes:

```text
Win64\Debug\audio-service-probe\PAAudioServiceProbe.exe 10
```

For manual device and volume observation, use continuous read-only mode. It
prints the initial snapshot, remains active until Enter is pressed, and prints
only meaningful changes. The worker processes endpoint/device and
endpoint-volume notifications while the console waits:

```text
Win64\Debug\audio-service-probe\PAAudioServiceProbe.exe --continuous
```

Continuous mode is intended for an interactive Command Prompt or RAD Studio
console. Its Enter detection uses the console input handle; redirected input
is not a substitute for an interactive Enter session. A non-console or
redirected input handle is ignored, so continuous mode does not terminate from
EOF or unrelated input and remains active until a verified console Enter or
explicit process cancellation.

For a bounded read-only diagnostic heartbeat every five seconds, use:

```text
Win64\Debug\audio-service-probe\PAAudioServiceProbe.exe --continuous --diagnostics
```

`DIAGNOSTIC_HEARTBEAT` reports only cached endpoint state, callback
received/processed counts, the latest callback payload, observation source,
snapshot sequence, callback registration HRESULT, and any error. It performs
no Core Audio reads, endpoint activation, default-role resolution, or active
endpoint enumeration.

Each snapshot includes an ISO-8601 timestamp, endpoint identity and friendly
name, service state, volume availability, raw scalar, display percentage, mute
state, own/external event counters, observation source, callback registration
HRESULT, callback-processed count, last event name, and error text. Repeated
unchanged snapshots are
intentionally suppressed by the probe. Raw scalar changes are compared with a
small tolerance, so changes within one rounded display percentage remain
observable.

`callbackProcessed` is the number of callback notifications processed for the
currently bound endpoint callback object. `externalCount` is the cumulative
number of processed callback notifications whose event context did not match
the service's own context; it is used for external Windows volume changes.
When the default endpoint is rebound, a new callback object is registered, so
`callbackProcessed` starts again from that endpoint's callback sequence. The
external counter is copied into the new snapshot and therefore remains
cumulative across rebinding.

An explicit setter is opt-in only:

```text
Win64\Debug\audio-service-probe\PAAudioServiceProbe.exe 10 --set 23
```

Do not use `--set` during automated validation. It changes the current Windows
default console endpoint volume through the service API.

### Manual continuous verification

1. Start `PAAudioServiceProbe.exe --continuous` without `--set`.
2. Change the Windows master volume using the volume UI. Observe an updated
   snapshot without changing the endpoint. A callback path reports
   `source=callback`, increments `callbackProcessed`, and sets
   `event=endpoint-volume-changed`. `callbackRegistrationHr=00000000`
   confirms successful endpoint-volume callback registration.
3. Change the Windows default output device. Observe the endpoint ID and
   friendly name change without restarting the probe.
4. Return to the original device and observe recovery.
5. Press Enter and confirm `SHUTDOWN_COMPLETE status=success`.

The probe does not fabricate events. Volume changes after initialization are
reported through the endpoint callback. Endpoint reconciliation is
event-triggered and is used to rebind after device/default-endpoint changes,
not as a periodic volume fallback.

The endpoint-volume callback binding uses the
`IAudioEndpointVolumeCallback` interface type for registration and
unregistration. The notification payload follows the Windows layout:
`guidEventContext`, `bMuted`, `fMasterVolume`, `nChannels`, and channel
volumes. The callback remains a short data-capture operation; the worker
processes the captured data.

Continuous probe shutdown prints `TERMINATION reason=console-enter` when
stopped by Enter, or `TERMINATION reason=one-shot-duration` for one-shot mode.
Unexpected exceptions are reported as probe failures.

## Live verification evidence

The final user-performed run of
`PAAudioServiceProbe.exe --continuous --diagnostics` verified the read-only
monitoring path. The initial read succeeded; volume changes on Speakers
produced callback snapshots; the default endpoint changed among Speakers,
LG ULTRAFINE, and Headset; endpoint-rebind snapshots were published without
restarting the service; and subsequent volume changes on Speakers and
LG ULTRAFINE were again detected through callbacks. Heartbeats reported
`cached=TRUE` and contained no fresh scalar/mute reads or periodic endpoint
enumeration. Enter terminated the probe with
`SHUTDOWN_COMPLETE status=success`.

The live run verified callback-driven monitoring and endpoint replacement
recovery. It did not verify the asynchronous `RequestMasterVolume` API; that
feature remains covered only by deterministic validation and explicit
implementation review.

## Evidence boundary

Building the service and deterministic tests does not prove live notification
delivery, endpoint replacement recovery, or volume-setting behavior. The first
two are covered by the final user-performed run above; volume-setting remains
unverified live. Those
checks require a developer-controlled Windows session and must record the
before/after endpoint, volume, mute state, default-device changes, and clean
shutdown. PA-009 remains separate and unstarted.

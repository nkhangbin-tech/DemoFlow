# Presenter Assistant Test Plan

## Test layers

1. **Domain unit tests:** pure schema validation, sequence matching, transition
   precedence, volume priority, delta math, stale-state rules, and input policy.
2. **Adapter contract tests:** fake PowerPoint, audio, window, hook, clock, and
   file providers; no COM, HWND, or hardware required.
3. **Controller integration tests:** queued messages, generation ordering,
   shutdown, safe mode, atomic configuration replacement, and command results.
4. **Build checks:** clean Win64 compile and, once supported, Win32 compile.
5. **Manual runtime tests:** actual PowerPoint, playback endpoint, browser
   windows, display layout, presenter hardware, and Windows focus behavior.

PA-004A domain harness tests cover percentage boundaries, positive and negative
offsets, clipping, and default unknown/unavailable state records. The harness
uses only Delphi RTL and exits nonzero on assertion failure.

PA-004B configuration tests cover strict version-1 parsing, unknown-property
rejection, field-path diagnostics, selector/reference validation, round trips,
safe reload preservation, missing files, and temporary-file saving.

PA-004C logger tests cover every severity, structured metadata, explicit
exception fields, URL query/fragment redaction, malformed URLs, newline
escaping, concurrent callers, bounded-queue overflow, bounded flush,
writer-error reporting, rotation and retention, repeated shutdown, logging
after shutdown, and temporary-directory cleanup. The logger harness is
RTL-only and does not exercise VCL, COM, PowerPoint, Core Audio, hooks, or
hardware.

PA-005A bootstrap verification uses the real configuration store and logger
through the VCL startup path. Missing, valid, malformed, and invalid
configuration cases are deterministic when run against an isolated
`LOCALAPPDATA` test profile or fixture. The current command-line evidence
covers compilation; startup status and shutdown remain manual IDE/runtime
checks because the implementation is VCL-owned. PA-005B tray behavior is not
part of this task.

PA-005B manual checks cover tray visibility after startup, double-click
restore, context-menu actions, minimize and ordinary-close hide behavior,
repeated restore without duplicate initialization, reload success/failure and
active-configuration preservation, explicit Exit, tray removal, bounded logger
shutdown, and Windows logoff/shutdown handling. These checks require the VCL
application and are not claimed by the console harnesses.

PA-006A is a standalone diagnostic runtime check, not a production-service
test. It verifies COM initialization, existing-instance attachment, repeated
unavailable reporting, slideshow-window enumeration, distinct slide index and
show position reads, connection loss, reattachment, and normal completion.
The probe does not provide a hard timeout around an individual external COM
call and does not use event sinks.

PA-006B1 deterministic tests cover state-name mapping, safe interval clamping,
initial snapshot publication, bounded stop, and repeated stop. The monitor
probe uses the same worker implementation and covers real COM attachment,
polling, slideshow transitions, and disconnection only when run by the
developer with PowerPoint.

PA-007A deterministic tests cover event sequence ordering, event invalidation,
post-callback reconciliation, failed-poll unknown state, duplicate/out-of-order
handling, and stable event names. The event probe uses the imported
PowerPoint type library, an STA message pump, and a bounded event buffer.
These tests do not prove live Office event delivery.

PA-008A deterministic tests cover scalar-to-display conversion at zero,
midrange, and maximum values, explicit rejection of out-of-range values, and
endpoint-state naming. The Core Audio probe performs only read operations.
Endpoint enumeration, default-device identity, scalar, mute state, and
non-mutation require the developer's actual Windows runtime test.
The diagnostic executable and pure test harness must be built and run to
distinct output directories; `PASS:` output is test evidence only and never
live endpoint evidence.

## Deterministic configuration and sequence cases

- Accept only integer `schemaVersion: 1`; reject `0`, `1.1`, strings, and
  unsupported values.
- Reject unknown properties, duplicate IDs, missing references, invalid ranges,
  forbidden self-transitions, and ambiguous equal-priority/equal-specificity
  rules with field paths.
- Verify failed reload preserves the last valid configuration; absent or
  malformed first-run configuration enters safe mode.
- Test `next` for PowerPoint and browser entries.
- Test browser Previous using `browserReturn` when present and `previous` when
  absent, including a direct return that skips a buffer entry.
- Test slide-index matching, show-position matching, both-identifiers conflict,
  wildcard disambiguation, no match, multiple match, and logical entry matching.
- Test configured logical build against `Verified`, `Unavailable`, and
  `Ambiguous` observed states; only verified state can match a required build.

## PowerPoint cases

- Disconnected, no slideshow, known slide, stale snapshot, modal failure,
  external slide change, and slideshow termination.
- Confirm `SlideIndex` and `CurrentShowPosition` remain separate.
- PA-006B2 deterministic coverage includes monitor lifecycle regression tests
  and a successful main Win64 compile with the VCL timer/form integration.
- Manual PA-006B2 coverage must verify startup with and without PowerPoint,
  connected/no-show, known slideshow values, ambiguous multiple windows,
  disconnect/reconnect, tray tooltip/status updates while hidden, and bounded
  shutdown. These require the developer's Delphi IDE and live PowerPoint.
- Simulate `SlideShowNextSlide` before-transition notification and verify that
  the callback invalidates state and a later poll confirms the new slide.
- Verify event loss and out-of-order polling do not advance the cursor wrongly.
- PA-007A manual event cases cover `SlideShowBegin`, `SlideShowNextSlide`,
  `SlideShowNextBuild`, `SlideShowNextClick`, `SlideShowEnd`, later reconciliation, event sink
  shutdown, and PowerPoint disconnect. Use the procedure in
  `docs\POWERPOINT_EVENT_PROBE.md`.
- A polling result of `CurrentShowPosition=0` during a transition is
  unavailable evidence, not a valid position; transient COM/RPC failures must
  be reported as reconciliation failures or unavailable fields.
- PA-007B deterministic coverage verifies zero and failed-position handling,
  restoration by a later valid position, and bounded monitor shutdown. The
  PA-007A event-state harness covers event ordering and post-callback
  reconciliation semantics. Integrated event delivery and reconnection require
  the developer's live PowerPoint test.

## Volume and delta cases

- Exact profile priority, foreground-kind fallback, wildcard, no-rule
  preservation, explicit unknown rule, and equal-specificity rejection.
- `Effective = Clamp(Nominal + Offset, 0, 100)`.
- Slide change with unchanged rule sends no new command.
- Rule change applies the existing offset exactly once.
- A matching PA event context never changes the offset, including repeated or
  delayed notifications.
- An external event recalculates `Offset = ObservedActual - Nominal` once.
- Manual adjustment remains in future rules without cumulative drift.
- Endpoint replacement resets generation/baseline and prevents writes until
  re-enumeration succeeds.
- Unknown context does not select a specific slide rule.

## Input boundary cases

- Capture-only records a matching key/button and never suppresses it.
- Disabled, unconfigured, unknown, stale, queue-full, injected, unrelated,
  repeated, and unsafe events return zero and reach the next hook.
- Enabled mapping with a reserved command slot returns nonzero exactly once for
  the intended physical event and dispatches nonblocking.
- Verify that the hook callback never waits for a controller decision and never
  calls COM, Core Audio, VCL, disk logging, or `SendInput`.
- Verify command failure after suppression is reported, the slot is released,
  cleanup is attempted, and mapping is disabled if cleanup is unconfirmed.
- Verify partial `SendInput`, injected feedback, modifier key-up cleanup,
  repeated key-down, disable, unhook, and repeated shutdown.

## Core Audio probe and service cases

- Run PA-008A and confirm active render endpoint count, endpoint IDs, friendly
  names, state, default-console identity, scalar, display conversion, and mute
  state.
- Confirm unavailable values are labelled unavailable and no volume or mute
  operation occurs.

- PA-008B will enumerate actual default render endpoints, read/write master
  volume, and receive endpoint replacement/loss notifications. The production
  implementation is covered by `tests\PAAudioServiceTests.dpr` for
  non-hardware logic and `tools\PAAudioServiceProbe.dpr` for live service
  observations.
- Verify callback unregister occurs before COM release and no callback reaches
  freed state through worker teardown review and a live shutdown run.
- Verify callbacks never block, re-enter endpoint operations, or evaluate rules;
  deterministic tests do not claim to prove this external callback behavior.
- Verify valid/invalid request acceptance, request IDs and completion states,
  immutable snapshot reads, own/external event-context classification, repeated
  start/stop, and explicit unavailable/no-default states.
- The service probe is read-only by default. Endpoint replacement, Windows
  volume UI notification, and device-loss recovery are manual tests and are
  not claimed by compilation or pure tests. The final live run completed the
  volume notification and endpoint replacement checks. Volume-setting through
  the asynchronous request API remains unverified live.
- Deterministic service tests cover raw scalar changes within one rounded
  display percentage, significant scalar/display changes, mute-only changes,
  unchanged suppression, and the reconciliation comparison seam independently
  of callback delivery.
- Continuous manual probe mode is:
  `Win64\Debug\audio-service-probe\PAAudioServiceProbe.exe --continuous`.
  It exits on Enter, suppresses unchanged reconciliation snapshots, and must
  be used to observe volume UI changes, default-device replacement, recovery,
  and clean shutdown without restarting the process. The final user-performed
  run completed these monitoring checks. It requires an
  interactive console; redirected standard input is not equivalent.
- For callback-path diagnosis, add `--diagnostics`. The five-second heartbeat
  reports cached scalar/mute values, callback payloads, and snapshot
  correlation only; it does not poll Core Audio or enumerate endpoints.
  Initial reads and endpoint-rebind reads are event-triggered service work.
- Continuous mode must remain alive without a verified interactive console
  Enter; duration limits apply only to one-shot mode.
- Callback registration uses the typed `IAudioEndpointVolumeCallback`
  interface pointer, and the notification payload layout must match the
  Windows SDK order. Automated tests cannot prove OS callback delivery.
- The completed final live run changed the default output device and verified
  endpoint rebind, callback registration, one initial read for each newly
  bound endpoint, and clean shutdown.
- The final live evidence also confirmed that callback counters are scoped
  differently: `callbackProcessed` restarts for the newly bound endpoint
  callback, while `externalCount` remains cumulative across rebinding.

## Runtime evidence gates

No runtime feature is accepted solely on a unit-test result. PowerPoint features
require an actual slideshow run. Core Audio requires actual endpoint
enumeration/read/write. Hooks require real input hardware or a documented
equivalent. Browser behavior requires the supported browser and window profile.

Record date, OS build, Office/browser versions, target bitness, connected
devices, exact scenario fixture version, observed result, and log correlation
IDs. Do not record URL query strings or unnecessary personal information.

## Environment blockers

The PA-001 WMI sound-device query returned no rows. This is inconclusive;
PA-008A enumerates Core Audio render endpoints directly. PA-008B source,
build, deterministic harness, and a read-only local service probe are complete;
runtime write/notification and endpoint-replacement behavior remain pending.

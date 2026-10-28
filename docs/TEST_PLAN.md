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
- Simulate `SlideShowNextSlide` before-transition notification and verify that
  the callback invalidates state and a later poll confirms the new slide.
- Verify event loss and out-of-order polling do not advance the cursor wrongly.

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

## Core Audio service cases

- Enumerate actual default render endpoints, read/write master volume, and
  receive endpoint replacement/loss notifications.
- Verify callback unregister occurs before COM release and no callback reaches
  freed state.
- Verify callbacks never block, re-enter endpoint operations, or evaluate rules.
- Use a fake endpoint to verify command context and notification idempotency.

## Runtime evidence gates

No runtime feature is accepted solely on a unit-test result. PowerPoint features
require an actual slideshow run. Core Audio requires actual endpoint
enumeration/read/write. Hooks require real input hardware or a documented
equivalent. Browser behavior requires the supported browser and window profile.

Record date, OS build, Office/browser versions, target bitness, connected
devices, exact scenario fixture version, observed result, and log correlation
IDs. Do not record URL query strings or unnecessary personal information.

## Environment blockers

The PA-001 WMI sound-device query returned no rows. This is inconclusive; PA-008
must enumerate Core Audio render endpoints directly. Build and runtime evidence
remain pending until PA-003 exists.

# Presenter Assistant Implementation Plan

Tasks are ordered by dependency. Each task must leave the application in a
buildable or deliberately unchanged state; no task may conceal missing runtime
evidence as a unit-test pass.

| ID | Purpose | Depends on |
|---|---|---|
| PA-003 | Buildable Win64 VCL skeleton and repository baseline | PA-002 |
| PA-004A | Domain models and pure functions | PA-003 |
| PA-004B | JSON configuration loading, validation, and saving | PA-004A |
| PA-004C | Logging and log redaction | PA-004A |
| PA-005 | Tray UI and lifecycle/safe mode | PA-004B, PA-004C |
| PA-006 | Minimal PowerPoint attachment and polling | PA-003, PA-004A, PA-004C |
| PA-007 | PowerPoint events and reconciliation | PA-006 |
| PA-008 | Core Audio endpoint discovery/read/write | PA-003, PA-004A, PA-004C |
| PA-009 | Volume rules and delta mode | PA-004A, PA-004B, PA-008 |
| PA-010 | Window Tracker | PA-004A, PA-004B, PA-005 |
| PA-011 | Input capture without suppression | PA-003, PA-004A |
| PA-012 | Configurable Win+Tab mapping | PA-011, PA-005 |
| PA-013 | JSON Sequence Engine | PA-004A, PA-004B |
| PA-014 | Scenario Manager integration | PA-006, PA-009, PA-010, PA-013 |
| PA-015 | End-to-end tests, recovery, release preparation | PA-007, PA-012, PA-014 |

## Task contracts

### PA-003 — Buildable project skeleton

- Files: `.dpr`, `.dproj`, minimal `.pas`/`.dfm`, `README` only if later
  requested, project-local build settings.
- Acceptance: a Win64 VCL GUI project opens in RAD Studio 12.3 and compiles
  without PA behavior.
- Automated check: invoke the verified Delphi command environment against the
  project; record exact command/output.
- Manual check: open in RAD Studio, select Win64, Build All, run and close.
- Evidence: compiler output, IDE target screenshot/log, executable launch.
- Fallback: keep the skeleton with no services if target or license blocks build.

### PA-004A — Domain models and pure functions

- Files: `Domain\PADomainTypes.pas`, `tests\PADomainTests.dpr`.
- Acceptance: RTL-only value types represent approved state and configuration
  contracts; effective volume uses `Clamp(Nominal + Offset, 0, 100)`.
- Automated check: build and run the Win64 console domain harness.
- Manual check: inspect default unknown/unavailable record states.
- Evidence: compiler output and passing test output.
- Fallback: no runtime services depend on this layer until accepted.

### PA-004B — Configuration, validation, and saving

- Files: `Config\PAConfiguration.pas`, configuration test harness.
- Acceptance: version-1 JSON parses and serializes bidirectionally; unknown
  properties, invalid values, references, transitions, and ambiguity report
  field paths; failed reload preserves the active configuration.
- Automated check: isolated RTL-only parser, validator, round-trip, reload, and
  safe-save tests.
- Manual check: inspect a saved UTF-8 configuration and verify the active
  configuration remains unchanged after a failed reload.
- Evidence: compiler output, passing test output, and isolated temporary-file
  cleanup.
- Fallback: safe mode with no active sequence.

### PA-004C — Logging and log redaction

- Files: Infrastructure logging units and focused tests.
- Dependencies: PA-004A; does not depend on PA-004B.
- Acceptance: structured severity/timestamp logging, bounded writes, retention,
  and URL query-string redaction work without blocking the controller.
- Automated check: log redaction and writer failure tests.
- Manual check: inspect sanitized local log output.
- Evidence: test output and sanitized log sample.
- Fallback: explicit diagnostics if logging is unavailable.

Implementation record:

- `Infrastructure\PALogger.pas` provides `TLogger` with Debug, Info, Warning,
  Error, and Critical severities; category, correlation ID, and explicit
  exception fields; UTF-8 JSON-lines output; `Flush`; idempotent `Shutdown`;
  dropped-message and write-error counters; and a last-write-error status.
- A dedicated writer thread drains a bounded queue. The default capacity is
  256 messages. Debug and Info messages are dropped when full; Warning,
  Error, and Critical messages evict the oldest lowest-severity queued item
  when possible. Enqueue performs no disk I/O.
- Messages are redacted before enqueue. HTTP/HTTPS query strings and
  fragments are replaced with a fixed marker; newline characters are JSON
  escaped. This is not arbitrary secret detection.
- The active file rotates before exceeding 1 MiB. Up to three numbered
  rotations are retained (`.1` through `.3`); unavailable directories,
  locked files, and write failures increment the error counter without
  escaping from the writer thread or recursively logging. Logger
  initialization also records directory-creation failures instead of raising
  them to the application. Logging remains optional and does not change
  application startup in PA-004C.

### PA-005 — Tray shell and lifecycle

- Acceptance: tray status, diagnostics, enable/disable, and safe shutdown work.
- Automated check: controller lifecycle tests with fake services.
- Manual check: enable/disable repeatedly, terminate process, confirm no hooks
  or COM services remain.
- Evidence: lifecycle log and process/service inspection.
- Fallback: visible diagnostic state and disabled automation.

### PA-006 — PowerPoint attachment and polling

- Acceptance: attach only to an existing instance, distinguish no-show/show,
  report slide index and show position separately, enforce the configured
  matching policy, and reconnect safely.
- Automated check: fake COM adapter tests for stale/error transitions.
- Manual check: PowerPoint slideshow with slide changes, termination, and
  direct observation of both identifiers.
- Evidence: sanitized COM state log and observed slide values.
- Fallback: disconnected/show-unknown state; no routing.

### PA-007 — Events and reconciliation

- Acceptance: verified type-library events are optional accelerators; polling
- reconciles missed events; pre-transition events invalidate state rather than
  claiming the next slide is already active; build ambiguity is explicit.
- Automated check: event/poll ordering, post-event refresh, and
  stale-generation tests.
- Manual check: transitions, builds, modal dialog, and PowerPoint exit.
- Evidence: event and poll correlation log; documented unsupported semantics.
- Fallback: polling-only mode.

### PA-008 — Core Audio endpoint

- Acceptance: enumerate default render endpoint and read/write master volume.
- Automated check: fake endpoint adapter tests, scalar conversion tests,
  callback non-reentrancy tests, and notification-unregister-before-release
  tests.
- Manual check: enumerate actual playback endpoints, change default device,
  mute/unmute, and verify system output.
- Evidence: endpoint IDs redacted as needed, before/after scalar readings.
- Fallback: audio automation disabled with explicit diagnostic.

### PA-009 — Volume rules and delta mode

- Acceptance: explicit slide/foreground selectors, priority and specificity,
  deterministic tie rejection, unknown-state behavior, absolute mode, and
  `Clamp(Nominal + Offset, 0, 100)` without cumulative drift.
- Automated check: deterministic fake clock/endpoint/controller tests covering
  command-context filtering and external-offset recalculation.
- Manual check: change slide/profile and manually adjust volume between rules.
- Evidence: rule identity/generation log and measured endpoint values.
- Fallback: preserve current volume.

### PA-010 — Window Tracker

- Acceptance: distinguish slideshow/editor, score browser criteria, handle zero
  and multiple matches, and verify foreground activation.
- Automated check: fake window provider tests.
- Manual check: real PowerPoint, browser, minimized/elevated/multiple windows.
- Evidence: match scores and activation outcomes without durable HWND config.
- Fallback: no activation or routing when ambiguous.

### PA-011 — Input capture without suppression

- Acceptance: capture-only mode never suppresses; the callback makes a bounded
  synchronous decision from an atomically published binding snapshot;
  disabled/unconfigured/unknown/unsafe input passes through; callback stays
  non-blocking.
- Automated check: fake hook provider and queue tests distinguish observation,
  suppression, command reservation, dispatch failure, injected input, repeated
  events, and modifier cleanup.
- Manual check: actual keyboard/mouse/presenter hardware capture and disable.
- Evidence: captured event report and cleanup verification.
- Fallback: hooks remain uninstalled.

### PA-012 — Win+Tab mapping

- Acceptance: explicit configured mapping suppresses only the authorized event,
  dispatches `SendInput` nonblocking outside the hook, handles partial results
  and injected feedback, cleans modifiers, and disables safely after failure.
- Automated check: input command generation tests.
- Manual check: presenter button opens task view and disable restores pass-through.
- Evidence: Windows runtime observation and shutdown hook check.
- Fallback: mapping disabled.

### PA-013 — JSON Sequence Engine

- Acceptance: explicit Next/Previous/browser-return precedence, slide-index and
  show-position matching, verified/unavailable/ambiguous builds, and
  unreconciled state with no hard-coded scenario values.
- Automated check: table-driven navigation, schema, ambiguity, and
  reconciliation suite.
- Manual check: load representative sequence and inspect diagnostics.
- Evidence: deterministic test report and config fixture version.
- Fallback: pass-through mode.

### PA-014 — Scenario Manager integration

- Acceptance: controller combines PowerPoint, audio, windows, input, and
  sequence state while preserving service failure boundaries.
- Automated check: fake adapter end-to-end controller tests.
- Manual check: staged PowerPoint/browser/audio scenario.
- Evidence: correlated trace across services.
- Fallback: disable only failed capability and retain diagnostics.

### PA-015 — End-to-end, recovery, release

- Acceptance: supported matrix, clean build, install/run instructions, failure
  recovery, and release artifacts are documented.
- Automated check: full unit suite and repeatable build.
- Manual check: actual Office, browser, audio endpoint, displays, and presenter.
- Evidence: signed-off test matrix, logs, build output, and known limitations.
- Fallback: release only with unsupported capabilities visibly disabled.

**Immediate next task:** PA-003. It is the first implementation task and must
produce the smallest compilable Win64 VCL application.

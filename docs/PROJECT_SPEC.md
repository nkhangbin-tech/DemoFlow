# Presenter Assistant Project Specification

## Status and scope

- Task: PA-002 — Architecture and Implementation Specification
- Date: 2026-10-27
- Status: specification complete; implementation has not started
- Initial target: Win64 VCL desktop application

PA is a local Windows desktop assistant for live presentations that alternate
between a PowerPoint slideshow and prepared browser video windows. The first
release is conservative: it attaches to an existing PowerPoint instance,
preserves normal navigation by default, and never launches a presentation
automatically.

## Goals

1. Make configured slide/browser transitions predictable and observable.
2. Control the Windows default playback endpoint without changing application
   session volumes.
3. Keep input capture disabled unless explicitly enabled and configured.
4. Fail safe when PowerPoint, audio, windows, hooks, or configuration are
   unavailable.
5. Keep deterministic domain logic testable without Office, hardware, or hooks.

The initial configuration contract is version `1` only. Unknown properties are
errors, invalid reloads preserve the last valid configuration, and first-run
absence enters safe mode.

## Non-goals

- Automatic Windows startup, registry modification, or administrator elevation.
- Launching PowerPoint or a presentation automatically.
- Guaranteeing detection of every PowerPoint animation/build step.
- Persisting HWND values as configuration identity.
- Treating a WMI sound-device result as Core Audio verification.

## Operational modes

### Pass-through mode (default)

PowerPoint owns navigation. PA observes actual slide and show-position state,
updates the last valid context, applies eligible volume rules, and performs only
explicitly configured non-invasive actions. An external slide change never
causes PA to invent a sequence cursor.

### Intercept-and-route mode (opt-in)

Configured Next/Previous input is translated by the sequence engine into a
validated target. The controller first confirms that the current state is
known and compatible with the configured transition. If it is not, the action is
reported as unavailable and normal input is preserved; no guessed navigation is
sent.

## Safety invariants

- Unknown PowerPoint state is a first-class state, not slide zero.
- A stale snapshot may inform diagnostics but cannot authorize a new sequence
  transition after its freshness limit.
- Configuration is parsed and validated off the live state, then swapped
  atomically only after all references and ranges are valid.
- Hook callbacks do not call COM, Core Audio, VCL, logging I/O, or configuration
  code.
- Service shutdown is idempotent and removes hooks and notifications before
  releasing their owners.
- A failed optional action never turns into a success-shaped fallback.
- A hook callback never waits for a controller decision; only a published,
  valid binding snapshot can authorize synchronous suppression.

## Acceptance boundary

The architecture is ready for PA-003 only when the module, state, thread,
schema, test, and roadmap definitions in the companion documents are accepted.
No application source is created by PA-002.

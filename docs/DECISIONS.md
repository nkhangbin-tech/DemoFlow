# Presenter Assistant Architecture Decisions

| ID | Decision | Rationale | Alternative / verification |
|---|---|---|---|
| ADR-001 | Start with one Win64 VCL executable | Installed `dcc64`, Win64 libraries, 64-bit OS and Office support the lowest-risk target | Win32 remains a compatibility assessment; verify Office/dependency bitness |
| ADR-002 | UI/controller owns aggregate state | Avoids cross-thread VCL and domain mutation | Actor-style controller considered; queue model is smaller |
| ADR-003 | PowerPoint polling is baseline | Polling is observable and reconciles missed event notifications | Add events only after typelib/event verification; retain polling |
| ADR-004 | Attach, never auto-launch, by default | Prevents unintended presentation changes | Explicit future launch feature would require a new decision |
| ADR-005 | Direct Core Audio adapter after signature verification | Avoids unverified dependency and controls endpoint semantics | A maintained library is acceptable only after source/API review |
| ADR-006 | Hooks disabled by default; callbacks synchronously consult a published binding snapshot | A hook cannot await the controller before deciding suppression; capture-only and unsafe states pass through | Registered hotkeys/raw input may be evaluated for narrower scope |
| ADR-007 | Atomic immutable configuration swap; version 1 only; unknown properties are errors | Prevents partially applied scenarios and misspelled safety-critical options | A future schema version requires an explicit migration decision |
| ADR-008 | Unknown state blocks routing | Guessing a slide or cursor could cause live-presentation errors | Pass-through observation remains available |
| ADR-009 | No HWND persistence | HWNDs are process/session runtime handles | Persist matching criteria and re-discover |
| ADR-010 | No startup registration/admin in initial release | Not required and increases deployment/security scope | Revisit only with explicit requirement |
| ADR-011 | Core Audio is owned by a dedicated STA worker | One thread owns COM interfaces, volume commands, callback registration, and release | Main STA was rejected to keep callbacks and UI independent |
| ADR-012 | Delta mode uses `Effective = Clamp(Nominal + Offset)` | Manual changes become a reusable offset without polling drift; PA event context excludes PA-origin changes | If event context is unavailable, disable delta updates rather than infer them |
| ADR-013 | Browser `browserReturn` overrides `previous` | Makes direct return over a buffer explicit and deterministic | Without `browserReturn`, browser Previous uses `previous` |
| ADR-014 | `SlideIndex` and `CurrentShowPosition` are separate selectors | Presentations can require document identity or show ordering | Both supplied values must match; otherwise state is unreconciled |

## Genuine blockers

- Verify exact PowerPoint typelib interfaces and event behavior before event
  monitoring implementation.
- Verify Core Audio declarations and direct endpoint behavior on an actual
  playback device.
- Confirm supported Office/browser versions, presenter hardware, display
  topology, and runtime permissions.
- Confirm RAD Studio edition/license state and a usable command-line build path
  once PA-003 exists.

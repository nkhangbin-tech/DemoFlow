# Presenter Assistant Open Decisions

## PA-001 audit findings

This file records decisions that must be resolved during architectural
specification. No application feature is implemented by this audit.

| Decision | Current status | Evidence or question |
|---|---|---|
| Primary target | **Proposed: Win64** | `dcc64.exe` and `lib\win64\release` are installed on a 64-bit Windows host. Do not change project settings until a project exists. |
| Secondary Win32 target | Open | Confirm Office/deployment compatibility and whether any native dependency requires a matching architecture. |
| RAD Studio edition and update level | Open | Compiler 36.0 and registry product version 29 were observed; edition, license, and patch level were not verified. |
| Project structure | Open | The workspace contains no `.dpr` or `.dproj`; choose VCL application structure and module boundaries in PA-002. |
| PowerPoint automation | Open | Decide attach-versus-launch behavior, typelib/import strategy, COM apartment model, event-sink ownership, and failure/timeouts. |
| Core Audio implementation | Open | Decide direct Windows Core Audio COM bindings versus a maintained dependency, plus endpoint/session semantics. |
| Input capture | Open | Decide low-level hooks versus registered hotkeys/raw input and define permission, focus, teardown, and conflict behavior. |
| Window identity | Open | Define stable matching keys and activation fallback/error behavior. |
| Scenario schema | Open | Define versioned JSON schema, validation, navigation transactionality, and malformed-input UX. |
| Logging | Open | Define structured log format, rotation/retention, sensitive-data policy, and diagnostic UI. |
| Test strategy | Open | Define unit seams plus integration fixtures for PowerPoint, browser, audio, input, and presenter hardware. |
| Runtime support matrix | Open | Confirm supported Windows versions, Office versions/bitness, display setups, permissions, and hardware. |

## Recommended next review

PA-002 should specify the VCL application architecture, target matrix,
dependency policy, and test seams before any feature implementation begins.


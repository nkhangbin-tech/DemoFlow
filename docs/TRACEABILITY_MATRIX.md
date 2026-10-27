# Presenter Assistant Traceability Matrix

| Requirement | Design location | Implementation task | Verification |
|---|---|---|---|
| VCL tray application | ARCHITECTURE, PROJECT_SPEC | PA-003, PA-005 | Win64 build and tray manual test |
| PowerPoint attach/poll | ARCHITECTURE | PA-006 | COM runtime test |
| Event reconciliation | ARCHITECTURE | PA-007 | Event/poll and exit tests |
| Separate slide/show position | ARCHITECTURE, CONFIGURATION_SCHEMA | PA-006 | Snapshot unit/runtime evidence |
| Pre-transition event handling | ARCHITECTURE | PA-007 | Event invalidation/post-poll test |
| Explicit build uncertainty | CONFIGURATION_SCHEMA, TEST_PLAN | PA-006, PA-007, PA-013 | Verified/unavailable/ambiguous build tests |
| Default endpoint master volume | ARCHITECTURE | PA-008 | Core Audio endpoint runtime test |
| Domain state contracts | ARCHITECTURE, CONFIGURATION_SCHEMA | PA-004A | Domain harness and default-state tests |
| Effective volume arithmetic | CONFIGURATION_SCHEMA | PA-004A | Boundary, offset, and clipping tests |
| JSON configuration parsing | CONFIGURATION_SCHEMA | PA-004B | Valid/invalid parser harness tests |
| Configuration validation diagnostics | CONFIGURATION_SCHEMA | PA-004B | Field-path and reference validation tests |
| Configuration round-trip/save/reload | CONFIGURATION_SCHEMA | PA-004B | Serialization and isolated file tests |
| Volume selectors/priority | CONFIGURATION_SCHEMA | PA-004B, PA-009 | Selector, priority, tie-rejection tests |
| Volume delta math | CONFIGURATION_SCHEMA | PA-009 | Command-context and no-drift tests |
| Endpoint callback cleanup | ARCHITECTURE | PA-008 | Unregister-before-release test |
| Window tracking | ARCHITECTURE | PA-010 | Fake and real window tests |
| Input capture safe default | ARCHITECTURE | PA-011 | Capture-only non-suppression test |
| Synchronous input suppression | ARCHITECTURE | PA-011, PA-012 | Snapshot, queue-full, dispatch-failure tests |
| Win+Tab mapping | ARCHITECTURE | PA-012 | SendInput, injected, modifier-cleanup tests |
| Versioned dynamic JSON | CONFIGURATION_SCHEMA | PA-004B, PA-013 | Version/unknown-property/atomic-reload tests |
| Pass-through/intercept modes | PROJECT_SPEC | PA-013, PA-014 | Controller integration tests |
| Browser return precedence | CONFIGURATION_SCHEMA | PA-013 | Next/Previous route tests |
| Logging/diagnostics | ARCHITECTURE, TEST_PLAN | PA-004C, PA-005, PA-015 | Logger harness: structured output, redaction, bounded queue, writer errors, rotation, flush, and shutdown; later lifecycle/recovery tests |
| Safe shutdown | ARCHITECTURE | PA-005, PA-011, PA-015 | Repeated shutdown and process inspection |
| No auto-start/admin | PROJECT_SPEC | PA-003, PA-015 | Packaging review |
| Application bootstrap and safe mode | ARCHITECTURE, CONFIGURATION_SCHEMA | PA-005A | VCL startup status, missing/invalid configuration, logger shutdown |

Each row requires both automated evidence where possible and the specified
runtime evidence for hardware/Office behavior.

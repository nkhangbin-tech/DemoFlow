# WELCOME-UX-02 — Implementation and verification report

## Current PO verification status — publication correction

Authority: explicit PO Authorized Consolidated Welcome Git Publication assignment in this session. LIVE VERIFIED only within the PO-tested scenarios: PowerPoint document discovery; Create New -> Scene Editor and external Scene insertion; Save -> Back to Welcome -> Open Existing -> Scene List restoration; Smart PowerPoint ComboBox preselection (WELCOME-UX-02).

Reopen Recent, v1/v2 compatibility and failure-recovery scenarios are not claimed LIVE VERIFIED without specific PO evidence. Overall WELCOME-VNEXT-M01 is NOT YET PO ACCEPTED; this publication does not imply acceptance of WELCOME-VNEXT-M01 or VOL-M02.

The remainder of this report preserves historical checkpoints. Earlier statements that live verification was pending describe those checkpoints, not the current limited PO evidence above. Historical build/test counts are retained and must not be interpreted as fresh verification of the publication snapshot. Fresh publication evidence, if obtained, is recorded in the publication addendum.

Status: IMPLEMENTED / BUILD VERIFIED / TEST VERIFIED. Not LIVE VERIFIED or ACCEPTED.

## Baseline and preservation

Workspace: E:\Programming\Tool\pa-development. Branch: review/pa-development. Starting/final HEAD: 07741d12b3d340c46761b30cdb84532a69c092fa. Starting index empty. Existing WELCOME/VOL-M02 modifications and untracked files inspected via actual local status; retained without restoration or overwrite. No commit/push/merge/reset/discard.

Preflight hashes of all tracked/untracked source files recorded at C:\Users\tatic\AppData\Local\Temp\PA_WELCOME_UX02\preflight-hashes.json. Comparison before documentation confirmed that the only modified existing file was uWelcomeForm.pas. Both DFM files, discovery/COM fix, session/persistence/compiler/audio and all pre-existing tests retained their starting bytes.

## Changed files

- uWelcomeForm.pas: selection tracking and Smart Refresh; shared project-selection path for Browse/Reopen; protected discovery scan override for deterministic Form tests. Reopen focuses the ComboBox only when the Form is visible and focusable. No geometry/component/Anchor changes.
- tests/PAWelcomeSelectionTests.dpr (new): deterministic tests of the actual hidden VCL Welcome Form with discovery snapshots and real temporary v1/v2/v3 project fixtures.
- docs/PRODUCT_DECISIONS.md: record the explicitly authorized WELCOME-UX-02 scope and its replacement of the earlier unselected-default policy.
- docs/WELCOME_UX02_REPORT.md (new): this report.

## Implemented selection policy

- Create: after discovery, choose first eligible candidate if none was retained; empty list means index -1 and Create disabled. Refresh retains the prior candidate by the existing SamePresentation identity contract, even if enumeration order changes. Disappearing/changed candidates fall back to the first current item.
- Open: load the selected project without adopting it into the active session, then refresh candidates. v3 matching uses actual candidate FileName, case-insensitively, never its caption. Exactly one match is preselected; zero/multiple matches remain unselected. SlideCount is deliberately not a preselection filter.
- Refresh preserves an explicit manual candidate if it still satisfies the unchanged candidate identity contract. Automatic choices are re-evaluated against the current project metadata. Choosing a different v3 project matches the new project rather than carrying over a manual choice made for another project.
- Legacy v1/v2: no inferred match. A manual candidate may be retained, including through Refresh; affirmative legacy confirmation remains required by the unchanged Open handler.
- Browse and Reopen both call SelectProjectFile -> RefreshClick. Recent never automatically opens a project; it selects the recent source and applies exactly the same preselection rules, then requires the Open action.
- Existing Create/Open handlers still perform live candidate resolution, filename/count validation or legacy confirmation, dirty replacement consent and pending-session adoption. Refresh/preselection never calls them or changes the active document. Invalid/unloadable project files remain unselected and cannot enable Open through guessing.

## Verification

| Suite / build | Passed checks | Failed | Exit |
| --- | ---: | ---: | --- |
| Win64 Debug application, Delphi Win64 36.0 | Build PASS | 0 errors | 0 |
| PAWelcomeSelectionTests | 33 | 0 | build 0 / test 0 |
| PAWelcomeIntegrationTests | 70 | 0 | build 0 / test 0 |
| PAPresentationDiscoveryTests | 9 | 0 | build 0 / test 0 |
| PAPowerPointMonitorTests | 10 | 0 | build 0 / test 0 |

Total 122 passing checks, zero failures. Existing third-party VirtualTrees.Header.pas(280) warning W1075 remains; no new compiler warnings. git diff --check passed.

New tests cover zero/one/multiple Create candidates; identity-preserving reorder; disappeared selection and last document; matching actual filename rather than caption; unique/no/ambiguous v3 matches; manual choice with duplicate filenames; refreshed/new-project metadata; filename match with slide-count mismatch still preselected and rejected by existing binding validation; case-insensitive names; v1/v2 no-guess and confirmation gates; Recent v3/ambiguous/legacy/manual flows; no automatic active-session adoption and failed-project-load preservation.

Build/test commands use the unchanged TEMP/PA_WELCOME_M01_verify/build.cmd and test.cmd documented in WELCOME_VNEXT_M01_REPORT.md. Test execution redirects LOCALAPPDATA into an isolated TEMP profile, so recent-index fixtures do not alter the actual user profile. Build log: C:\Users\tatic\AppData\Local\Temp\PA_WELCOME_UX02\app-build.log. Suite build.log/test.log: C:\Users\tatic\AppData\Local\Temp\PA_WELCOME_M01_verify/<suite>/. Source/hash backups: C:\Users\tatic\AppData\Local\Temp\PA_WELCOME_UX02.

Welcome DFM SHA256 unchanged: e5035982e5eb789c295c3ffbcf3fd04cb1fe8d9249d0ef5baf2f6bde11c59987. Scene Editor DFM SHA256 unchanged: 1486166a1ce3f67c725aed03a67f6e9f3ee684c5f626cb4537e160784aff33dc.

## Remaining PO manual tests

Run the updated application from Delphi with zero, one and several actual PowerPoint documents; check first-item Create selection, manual selection preservation and closing a selected document before Refresh. Browse v3 fixtures with unique/duplicate/no filename matches, including different captions and mismatched slide count; verify no automatic Open, and explicit Open still rejects mismatches. Repeat via Recent and legacy v1/v2, including the confirmation dialog. No live UI evidence for this new selection policy is claimed here. Existing discovery limitations (active registered instance, saved presentations only, busy COM latency) remain unchanged.

## Final Git status

HEAD unchanged, index empty; status includes pre-existing work as well as this assignment.

```text
 M Domain/PASceneDomain.pas
 M Persistence/PASceneDocumentCodec.pas
 M Persistence/PASceneProjectFileStore.pas
 M PresenterAssistant.dproj
 M README.txt
 M Runtime/PASceneCompiler.pas
 M tests/PASceneDocumentCodecTests.dpr
 M tests/PASceneProjectFileStoreTests.dpr
 M tests/PAVolumeContractsTests.dpr
 M uMainForm.pas
 M uSceneEditorForm.dfm
 M uSceneEditorForm.pas
 M uWelcomeForm.dfm
 M uWelcomeForm.pas
?? Authoring/PARecentProject.pas
?? Authoring/PASceneProjectSession.pas
?? PowerPoint/PAPresentationDiscovery.pas
?? docs/PRODUCT_DECISIONS.md
?? docs/VOL_M02_CONTRACT.md
?? docs/WELCOME_DISCOVERY_DEFECT_REPORT.md
?? docs/WELCOME_UX02_REPORT.md
?? docs/WELCOME_VNEXT_M01_REPORT.md
?? tests/PAPresentationDiscoveryTests.dpr
?? tests/PAVolumeBaselineTests.dpr
?? tests/PAVolumeEditorTests.dpr
?? tests/PAVolumeSessionTests.dpr
?? tests/PAWelcomeIntegrationTests.dpr
?? tests/PAWelcomeSelectionTests.dpr
?? verification.txt
```

## Fresh controlled-publication snapshot verification

Fresh verification executed during the authorized consolidated publication task, independently of historical results above. Exported the staged index (HEAD plus exactly the 24 authorized paths) into a plain TEMP source directory using git checkout-index. This is neither a new repository nor a Git worktree. Runtime/PASceneCompiler.pas in this snapshot was checked against HEAD with CRLF normalization and contains none of the excluded local VOL-M02 compiler changes. No excluded local source was used.

Win64 Debug application build: exit 0; Delphi Win64 36.0; existing VirtualTrees.Header.pas(280) W1075 warning only. All test builds and executions below exited 0. LOCALAPPDATA redirected to an isolated TEMP profile. No main application or new interactive UI was launched.

| Fresh suite | PASS checks | FAIL | Build / test exit |
| --- | ---: | ---: | --- |
| PAWelcomeSelectionTests | 33 | 0 | 0 / 0 |
| PAWelcomeIntegrationTests | 70 | 0 | 0 / 0 |
| PAPresentationDiscoveryTests | 9 | 0 | 0 / 0 |
| PAPowerPointMonitorTests | 10 | 0 | 0 / 0 |
| PAVolumeSessionTests | 52 | 0 | 0 / 0 |
| PAVolumeEditorTests | 26 | 0 | 0 / 0 |
| PAVolumeContractsTests | 70 | 0 | 0 / 0 |
| PASceneDocumentCodecTests | 149 | 0 | 0 / 0 |
| PASceneProjectFileStoreTests | 19 | 0 | 0 / 0 |
| PASceneDomainTests | 30 | 0 | 0 / 0 |
| PASceneCompilerTests | 23 | 0 | 0 / 0 |
| PAConfigurationTests | 27 | 0 | 0 / 0 |
| PADomainTests | 17 | 0 | 0 / 0 |

Total: 535 passing checks, zero failures. These are independent publication-snapshot results. Three report addenda were updated afterward; executable source and test source are byte-identical to the verified staged snapshot.

Snapshot/log/script directory: C:\Users\tatic\AppData\Local\Temp\PA_WELCOME_PUBLICATION_20261101. Application log: verify/app-build.log. Per-suite logs: verify/<suite>/build.log and test.log. Scripts: build.cmd and test.cmd. Commands use the same rsvars/MSBuild/dcc64 setup recorded above, run from the exported snapshot with output redirected to the publication verify directory.

Publication stopped before commit: git diff --cached --check reports trailing whitespace in tests/PAPresentationDiscoveryTests.dpr at lines 51 and 139 (the two ScrollIntoView signatures). The paths are exactly the authorized 24, but this check is not PASS. Source was left untouched under the report-corrections-only boundary. No commit or push performed; the 24 paths remain staged. All five excluded files retain their preflight SHA256 hashes. A narrowly authorized removal of these two trailing whitespace sequences is required before repeating the check and continuing publication.

Overall WELCOME-VNEXT-M01 remains NOT YET PO ACCEPTED. Limited PO LIVE VERIFIED evidence is as stated in the current-status correction; Reopen Recent, legacy and failure-recovery live verification are not inferred from deterministic results.

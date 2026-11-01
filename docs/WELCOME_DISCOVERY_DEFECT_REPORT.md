# Welcome vNext — PowerPoint discovery defect fix

## Current PO verification status — publication correction

Authority: explicit PO Authorized Consolidated Welcome Git Publication assignment in this session. LIVE VERIFIED only within the PO-tested scenarios: PowerPoint document discovery; Create New -> Scene Editor and external Scene insertion; Save -> Back to Welcome -> Open Existing -> Scene List restoration; Smart PowerPoint ComboBox preselection (WELCOME-UX-02).

Reopen Recent, v1/v2 compatibility and failure-recovery scenarios are not claimed LIVE VERIFIED without specific PO evidence. Overall WELCOME-VNEXT-M01 is NOT YET PO ACCEPTED; this publication does not imply acceptance of WELCOME-VNEXT-M01 or VOL-M02.

The remainder of this report preserves historical checkpoints. Earlier statements that live verification was pending describe those checkpoints, not the current limited PO evidence above. Historical build/test counts are retained and must not be interpreted as fresh verification of the publication snapshot. Fresh publication evidence, if obtained, is recorded in the publication addendum.

Status: IMPLEMENTED / BUILD VERIFIED / TEST VERIFIED. Limited live read-only COM discovery and revalidation VERIFIED on the existing 80-slide presentation. Full PO Welcome UI retest and acceptance remain pending.

## Starting source

Workspace E:\Programming\Tool\pa-development; branch review/pa-development; starting/final HEAD 07741d12b3d340c46761b30cdb84532a69c092fa. Index empty. Inspected actual discovery unit and all Git status entries before editing; retained the existing dirty WELCOME/VOL-M02 tree. No commit/push/merge/reset/clean/discard.

## Root cause and direct evidence

The precise failing production invocation was NativeUInt(Int64(Window.HWND)) in TDiscoveryWorker.Execute. The OleVariant automation call on PowerPoint DocumentWindow returned EOleSysError, HRESULT 0x80020003 (DISP_E_MEMBERNOTFOUND). The old catch omitted the member name, making the error look like generic enumeration failure. Application.Windows, DocumentWindows.Item, DocumentWindow.Presentation and Presentation.Path succeeded before this call.

A read-only Delphi Win64 probe reproduced that failure against the already-running PowerPoint instance. QueryInterface to the imported PowerPoint_TLB.DocumentWindow and its typed HWND_ getter succeeded on the same window (handle 265152), with caption Notebook Lesson XL by Slidesgo, filename Notebook Lesson XL by Slidesgo.pptx and Slides.Count=80. A dispatch call to imported DISPID 2020 also failed with 0x80020003 on the actual server; changing only the automation spelling/DISPID was insufficient. The final fix uses the dual interface vtable getter, not an invented fallback or unchecked candidate.

## Small correction and changed files

- PowerPoint/PAPresentationDiscovery.pas: ReadDocumentWindowKey queries DocumentWindow from the existing IDispatch and calls its typed HWND_ getter, zero-extending the 32-bit OLE handle on Win64. It executes on the same dedicated discovery STA; its local interface is released there. All other candidate reads and eligibility checks remain intact. Added member/window-index/exception/HRESULT diagnostics around COM reads, and preserve those diagnostics when selected-candidate revalidation fails.
- tests/PAPresentationDiscoveryTests.dpr (new): fake typed COM DocumentWindow implementing its imported interface. Name lookup and dispatch invocation deliberately fail; only the real typed handle getter succeeds. Tests verify old-path rejection, correct vtable path, absence of name lookup/Invoke, zero extension, zero handle preservation and propagation of genuine getter exceptions. Unused interface methods are neutral stubs required to implement the imported COM interface.
- docs/WELCOME_DISCOVERY_DEFECT_REPORT.md (new): this report.

No changes in this defect fix to Welcome PAS/DFM, Anchors, Scene Editor, project schema, session/persistence, monitoring, Runtime Controller or Core Audio. Normal document enumeration is still Application.Windows (DocumentWindows), never SlideShowWindows. Candidates still require a saved presentation, nonzero handle, basename and a successfully read nonnegative slide count. COM failures never produce partially verified candidates.

## Before / after

Before: DocumentWindows.Count=1, but Window.HWND raises 0x80020003 and the only eligible window is omitted. This matches the PO UI report.

After: the actual DiscoverPresentations worker returns EligibleDocumentWindows=1, Diagnostic empty, WindowKey=265152, the expected caption/filename and SlideCount=80. ResolvePresentation succeeds and independently returns SlideCount=80. Neither probe starts PowerPoint, changes slides, activates a window, saves or closes a presentation.

## Verification

| Verification | Result | Exit |
| --- | --- | --- |
| Win64 Debug application build, Delphi Win64 36.0 | PASS; existing third-party VirtualTrees.Header.pas(280) W1075 only | 0 |
| PAPresentationDiscoveryTests | 9 checks PASS, 0 failed | build 0 / test 0 |
| PAWelcomeIntegrationTests | 70 checks PASS, 0 failed | build 0 / test 0 |
| PAPowerPointMonitorTests | 10 checks PASS, 0 failed | build 0 / test 0 |
| Actual read-only discovery + resolve on 80-slide presentation | 1 candidate, no diagnostic, resolve PASS | 0 |
| git diff --check | PASS | 0 |

89 relevant checks passed. Other persistence/volume suites were not rerun for this discovery-only fix; their prior results are not new verification evidence here.

Application build and test commands are the unchanged build.cmd and test.cmd recorded in WELCOME_VNEXT_M01_REPORT.md. Latest build log: C:\Users\tatic\AppData\Local\Temp\PA_WELCOME_DISCOVERY_FIX\app-build.log. Deterministic logs: C:\Users\tatic\AppData\Local\Temp\PA_WELCOME_M01_verify/<suite>/build.log and test.log. Original source snapshot and before/after live probe source/scripts/logs: C:\Users\tatic\AppData\Local\Temp\PA_WELCOME_DISCOVERY_FIX.

Welcome DFM SHA256 before/after: E5035982E5EB789C295C3FFBCF3FD04CB1FE8D9249D0EF5BAF2F6BDE11C59987. Scene Editor DFM SHA256 before/after: 1486166A1CE3F67C725AED03A67F6E9F3EE684C5F626CB4537E160784AFF33DC.

## PO retest / limitations

Build/run the updated application from Delphi, Refresh in both Create and Open, verify the 80-slide presentation appears and can be explicitly selected. Verify Create yields 80 logical PowerPoint Scenes and that Open retains its filename/count gate. Full UI, duplicate-title/multiple-document, close/change and Slide Show coexistence tests remain PO live checks; the limited read-only probe does not establish complete LIVE VERIFIED or ACCEPTED status.

Existing boundaries remain: only the PowerPoint instance registered by GetActiveObject is enumerated, unsaved presentations are excluded, and busy COM can delay synchronous discovery. No new scope or product decision introduced.

## Final Git status

HEAD unchanged; no staged files. The status includes earlier WELCOME/VOL-M02 work, not solely this fix.

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
?? docs/WELCOME_VNEXT_M01_REPORT.md
?? tests/PAPresentationDiscoveryTests.dpr
?? tests/PAVolumeBaselineTests.dpr
?? tests/PAVolumeEditorTests.dpr
?? tests/PAVolumeSessionTests.dpr
?? tests/PAWelcomeIntegrationTests.dpr
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

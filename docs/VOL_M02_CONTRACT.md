# VOL-M02 — Current reconciliation and acceptance preparation

Date: 2026-11-02 (Asia/Saigon).
Reviewed/verified development HEAD: 29494ededa10fdc91b84e6ab6b149816a4cc7302,
branch review/pa-development, plus the existing uncommitted compiler baseline.

VOL-M02 status: IMPLEMENTED / BUILD VERIFIED / TEST VERIFIED.
Recommendation: READY FOR VOL-M02 ACCEPTANCE. This is not PO acceptance and does
not grant LIVE VERIFIED or ACCEPTED status to VOL-M02.

## Authority and reading this document

The explicit PO acceptance-preparation assignment identifies Welcome vNext at
29494ededa10fdc91b84e6ab6b149816a4cc7302 as PO ACCEPTED. The current published
[PRODUCT_DECISIONS.md](PRODUCT_DECISIONS.md) records the approved PowerPoint-first,
WELCOME-ARCH-01, WELCOME-COMPAT-01, Active Project Session and WELCOME-UX-02 contracts.
Those approved behaviors govern this reconciliation. The older status statements
in published Welcome reports/decision checkpoints do not revoke the PO's later
explicit Welcome acceptance and do not establish VOL-M02 acceptance.

The complete original 2026-11-01 checkpoint is retained below, explicitly labeled
historical. Its old implementation descriptions, deferred items, filenames and
467-check results are evidence of that checkpoint, not current requirements or
fresh verification. The table below identifies the superseded behavior; approved
positional volume semantics remain unchanged. No product decision is created here.

## Historical-to-current reconciliation

| Historical checkpoint | Status of that description | Current approved/published behavior |
| --- | --- | --- |
| Manual Add PowerPoint/Browser/ExternalApp Scenes | SUPERSEDED for PowerPoint insertion | Welcome Create New selects an eligible PowerPoint document; its logical slides generate ordered PowerPoint Scenes. Add New Scene offers only Browser and External App, default volume -1. |
| Editor creates/owns its own initial session | SUPERSEDED ownership | The application owns the Active Project Session established through Welcome Create/Open; the Editor borrows it. A prepared candidate is adopted only after the applicable confirmation gates. |
| Open UI/Welcome integration deferred | SUPERSEDED | Welcome Open Existing and Reopen Recent route through presentation selection, compatibility/binding gates and the active session. Recent remains one independent latest successful entry. |
| First legacy save uses Save As v2 | SUPERSEDED workflow | v1/v2 Open retains the original source unchanged, requires explicit presentation selection and affirmative legacy binding confirmation, then explicit Save As v3 to a different safe destination. Confirmed legacy binding is not described as a verified metadata match. |
| No project-level PowerPoint metadata | SUPERSEDED by WELCOME-ARCH-01 | Published PA.SceneProject v3 adds PowerPoint basename and slide count; no schema change is made by this acceptance-preparation task. |
| 467 checks across the original ten harnesses | HISTORICAL EVIDENCE | Retained verbatim below. The prior final review's 583 checks across thirteen harnesses are also historical; the new results are reported separately in this document. |

For current-format projects, existing v3 compatibility/matching checks and explicit
presentation binding remain in force. Open does not regenerate saved Scenes.
The low-level codec can still emit v2 for metadata-free documents; that does not
replace the approved bound-project legacy-to-v3 Save As workflow.

## Volume and architecture contracts preserved

- A project owns PresentationBaseVolumePercent, integer 0..100; NewSceneProject
  initializes it to 50. No system-volume read supplies this default.
- ExplicitVolumePercent=-1 means No Volume Override. A Scene with a valid 0..100
  target replaces the logical baseline at that Scene; consecutive overrides use
  the latest explicit value in logical Scene order.
- Leading -1 Scenes inherit project base. Later/trailing -1 Scenes inherit the
  latest preceding applicable target. Reorder/recompile recalculates by new
  position, not query/navigation history or previous snapshot state.
- NewSceneCompileRequest(Project, ExpectedRevision) copies the explicit project
  base and Scenes, preserving revision gating. Default(TSceneCompileRequest)
  remains zero-initialized (base 0), not the new-project creation contract.
- The compiled snapshot's baseline cache and base are immutable/read-only.
  Invalid indices are rejected; an empty authoring list does not compile.
- Calculation has no Core Audio effects or UI-thread COM calls. The authoring
  session does not invoke runtime compilation as a Save gate. Incomplete drafts
  and the existing identity, physical mapping and revision rules remain intact.
- Legacy Nominal + DeltaOffset semantics, Core Audio STA ownership, Settings UI,
  runtime controller and VOL-M03 are untouched. Settings backend remains available;
  Settings Form design and UI binding remain deferred to a separate PO decision.

## This task's exact change boundary

Only tests/PAVolumeBaselineTests.dpr and docs/VOL_M02_CONTRACT.md were edited.
The 58 pre-existing baseline assertions remain; 98 assertions were added.
No compiler implementation was rewritten. No accepted Welcome/Editor source,
DFM, Anchors, event bindings, project settings, persistence source or other tests
were changed. README.txt, verification.txt and all other existing local changes
were preserved. No staging, commit, push, merge, reset, clean or rebase occurred.

New regression cases:

- For each project base 0/50/100, a run [-1,-1,0,100,0,100,-1,-1]
  expects [base,base,0,100,0,100,100,100], including consecutive overrides.
- All-no-override runs [-1,-1,-1] preserve each explicitly supplied project base.
- Reorder the same Scene identities from [0,1,2,3] with volumes [-1,0,100,-1]
  to identities [3,2,0,1] with volumes [-1,100,-1,0], rebuild valid adjacency
  through the approved request factory, and verify baselines change from
  [50,0,100,100] to [50,100,100,0].
- Original/reordered snapshots keep independent caches after recompilation,
  caller/request/returned-copy mutation and destruction of the other snapshot.
- Two snapshots with the same no-override pattern but different project bases
  0 and 100 retain independent results under interleaved queries and destruction.

## Fresh verification — 2026-11-02 acceptance preparation

These results were executed after the authorized regression additions against
HEAD 29494ededa10fdc91b84e6ab6b149816a4cc7302 plus the complete current local
working tree. They are independent of the historical 467/583-check reports.
All thirteen compiler exits and all thirteen test exits were 0.

| Harness | Passed | Failed | Compiler exit | Test exit |
| --- | ---: | ---: | ---: | ---: |
| PAVolumeBaselineTests | 156 | 0 | 0 | 0 |
| PAVolumeSessionTests | 52 | 0 | 0 | 0 |
| PAVolumeEditorTests | 26 | 0 | 0 | 0 |
| PAVolumeContractsTests | 70 | 0 | 0 | 0 |
| PASceneDomainTests | 30 | 0 | 0 | 0 |
| PASceneCompilerTests | 23 | 0 | 0 | 0 |
| PASceneDocumentCodecTests | 149 | 0 | 0 | 0 |
| PASceneProjectFileStoreTests | 19 | 0 | 0 | 0 |
| PAConfigurationTests | 27 | 0 | 0 | 0 |
| PADomainTests | 17 | 0 | 0 | 0 |
| PAWelcomeIntegrationTests | 70 | 0 | 0 | 0 |
| PAWelcomeSelectionTests | 33 | 0 | 0 | 0 |
| PAPresentationDiscoveryTests | 9 | 0 | 0 | 0 |
| **Total** | **681** | **0** | | |

Win64 Debug application build: exit 0, Delphi Win64 version 36.0. The existing
VirtualTrees.Header.pas(280) W1075 warning remains; no new compile error occurred.
No compiler defect was found and no implementation change was needed.

All output is isolated under:

    E:\Programming\Tool\pa-development\Win64\Debug\vol-m02-acceptance-prep-20261102

Each harness has build.log/test.log in its own subdirectory; results.json records
commands, exit codes and passing/failing line counts. Application build.log is in
app-build. TEMP/TMP and process-local LOCALAPPDATA were redirected into this output
root so tests cannot overwrite the user's real recent-project record. The legacy
domain harness receives a newline for its final Readln.

From the development root, initialize the environment:

    call "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" >nul

All thirteen harnesses used the installed compiler and this flag template; OUT
is the isolated output root plus the harness name:

    "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\dcc64.exe" -B -Q -CC -NSSystem;Vcl;Winapi;System.Win -U"Domain;Runtime;Persistence;Config;Authoring;PowerPoint;tools\generated;E:\Software\Programing\Components\JAM-Virtual-TreeView\Source" -I"tools\generated;E:\Software\Programing\Components\JAM-Virtual-TreeView\Source" -E"OUT" -NU"OUT" tests\HARNESS.dpr

Application build used the existing .dproj (OUT is the isolated app-build path):

    "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe" PresenterAssistant.dproj /t:Build /p:Config=Debug /p:Platform=Win64 /p:DCC_ExeOutput=OUT /p:DCC_DcuOutput=OUT /p:DelphiDCPOutput=OUT /p:DelphiHPPOutputPath=OUT /p:DelphiDLLOutputPath=OUT /v:minimal /nologo

These are deterministic tests, including hidden VCL forms and mocked discovery,
not a fresh live PowerPoint or PO interaction test. Welcome acceptance remains
limited to the PO-approved baseline/scenarios. This task neither expands that
acceptance nor declares VOL-M02 ACCEPTED. Settings UI, VOL-M03 and real audio
execution remain outside scope.

---

# Historical checkpoint — 2026-11-01 (retained verbatim)

The following original document is a historical implementation/evidence record.
Where it describes manual PowerPoint insertion, Editor-owned session behavior,
Open UI being deferred or legacy Save As v2, use the current reconciliation above.
Its 467-check result is historical, not current verification.

# VOL-M02 — Baseline, authoring/session and Scene Editor binding

Baseline: review/pa-development at ce1f3a633f4c4e42fc071be042cbc1d094a60e20.
Implementation was authorized by the PO separately from the draft assignment.
Status: IMPLEMENTED / BUILD VERIFIED / TEST VERIFIED; not LIVE VERIFIED or ACCEPTED.

## Scope and preservation

Pre-existing local edits were README.txt, uSceneEditorForm.pas/.dfm and untracked
verification.txt. Implementation extends the actual local PAS control declarations;
it does not restore the Git version. The DFM, README and verification.txt remain
byte-for-byte identical to their preflight hashes. No controls are created for
Settings. No global IDE settings, audio services, PowerPoint monitor or unrelated
Forms have been modified. No source schema or persistence subsystem changes.

Task changes:
- Runtime/PASceneCompiler.pas: project base and positional baseline query.
- Authoring/PASceneProjectSession.pas: minimal authoring/settings/file session.
- uSceneEditorForm.pas: runtime event binding into existing PO controls.
- PresenterAssistant.dproj: add Authoring/Domain/Persistence unit search paths.
- tests/PAVolumeBaselineTests.dpr: pure compiler/baseline tests.
- tests/PAVolumeSessionTests.dpr: settings/Scene/session/Save As tests.
- tests/PAVolumeEditorTests.dpr: deterministic tests of the actual hidden VCL Form.
- docs/VOL_M02_CONTRACT.md: this evidence and integration/deferred contract.

## Pure compiled baseline

NewSceneCompileRequest copies a project's Scenes, base and source revision;
the caller supplies ExpectedAuthoringRevision. It does not invent revisions or
physical mappings. As with VOL-M01, raw Default(record) remains zero-initialized:
a raw compile request has base 0. Production callers should use the project-copy
factory so an intentional base 0 and a new-project default 50 are not confused.

The compiler validates base 0..100 and keeps all existing Scene, revision and
physical-resource checks. The immutable compiled snapshot computes a prefix
baseline: start with project base, keep it for -1, replace it for 0..100.
GetActiveVolumeBaseline(Index) returns the precomputed logical-position value,
independent of prior queries/navigation history. Both base and cached baselines
are private/read-only. Invalid indices raise ERangeError. Empty authoring lists
remain rejected by compilation; an empty direct snapshot rejects index lookups.
There is no runtime controller, navigation execution or audio API call here.

## Authoring/session and future Settings interface

TSceneProjectSession owns the authoring document and selection. GetDocument
returns a detached array copy. New projects use NewSceneProject (base 50).
PresentationBaseVolumePercent is a backend/session property restricted to 0..100;
changing it marks authoring state modified without reading or writing system audio.
The future Settings UI can bind this property; Settings controls/events are deferred.

AddScene supports PowerPoint, Browser and ExternalApp with fresh stable GUID ids
and ExplicitVolumePercent=-1. Missing slides and references are left incomplete.
Insert is immediately after selection, or at index 0 without selection (including
an empty list). Remove and one-step move preserve whole Scene records and revision.
No new revision lifecycle policy or runtime compilation is introduced.

## Existing Scene Editor binding

The DFM is unchanged; events are wired in the PAS constructor. The tree mirrors
session array order and selection, never owns the Domain data. Existing Add menu,
Remove and Move buttons use the session. The detail card reflects selected kind.

Edit text -1 is explained as No Volume Override in the existing label and status.
TrackBar always remains 0..100: its position 0 for no-override is a display
placeholder, not a model update. A reentrancy guard suppresses writes during
selection/inspector refresh. User TrackBar notifications use the Edit commit path.
Invalid input displays the existing error label, does not commit an invalid value
and blocks Save. Selecting another Scene discards uncommitted invalid text and
loads that Scene's value without writing it into another Scene.

Target/slide fields are display-only for this milestone. No new target discovery,
reference mapping or advanced inspector editing is provided. Existing PowerPoint
physical target selection has no persisted domain mapping and remains unavailable.

## v1 Save As v2

OpenProject adopts a detached document only after successful read, retains source
path/version and never writes/upgrades it. Failed Open preserves current edits.
Save returns SaveAsRequired for new projects or v1 sources. SaveAs('') is cancellation.
Explicit Save As delegates to VOL-M01, protecting original v1 paths/bytes. Failure
preserves active data, path, source version, selection and dirty status. Only success
adopts the new v2 path/version and clears Modified. Subsequent v2 Save uses that path.
Authoring Save never calls CompileSceneList, so incomplete drafts remain saveable.

The existing Save button is connected to this contract and a standard Save As picker.
There is no real Open entry point in the PO Form/Welcome placeholder yet. A public
Form/session OpenProject API is available and tested, but connecting an Open picker
or Welcome selection is deferred. No end-to-end user Save As flow is claimed.

## Verification commands and results

RAD Studio setup (for all builds):

    call "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" >nul

Compiler: D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\dcc64.exe,
Win64 version 36.0. From the development worktree root, console harness template:

    dcc64.exe -B -Q -CC -UDomain;Runtime;Persistence;Config;Authoring -EWin64\Debug\<output> -NUWin64\Debug\<output> tests\<harness>.dpr

For PAVolumeEditorTests, replace the unit/include flags with:

    -NSSystem;Vcl;Winapi;System.Win -U"Domain;Runtime;Persistence;Config;Authoring;E:\Software\Programing\Components\JAM-Virtual-TreeView\Source" -I"E:\Software\Programing\Components\JAM-Virtual-TreeView\Source"

| Harness | Output under Win64\Debug | Passed | Failed |
| --- | --- | ---: | ---: |
| PAVolumeBaselineTests | vol-m02-baseline | 58 | 0 |
| PAVolumeSessionTests | vol-m02-session | 50 | 0 |
| PAVolumeEditorTests | vol-m02-editor | 24 | 0 |
| PAVolumeContractsTests | vol-m01 | 70 | 0 |
| PASceneDomainTests | m02a-regression | 30 | 0 |
| PASceneCompilerTests | m02b-regression | 23 | 0 |
| PASceneDocumentCodecTests | m03a-codec-tests | 149 | 0 |
| PASceneProjectFileStoreTests | m03b-file-store | 19 | 0 |
| PAConfigurationTests | legacy-config | 27 | 0 |
| PADomainTests | legacy-domain | 17 | 0 |

Observed on 2026-11-01: all compiler and test exit codes 0; total 467 passing
assertions/checks and 0 failures. Build/test output is retained in build.log/test.log
inside each isolated output directory. TEMP/TMP are Win64\Debug for file tests.
The legacy domain harness receives a newline for its final Readln.
The editor harness creates a hidden form; it does not instantiate MainForm,
PowerPoint or audio services. This is deterministic UI binding evidence, not a
Product Owner live test. No Settings UI exists to verify.

Application build after the same setup:

    "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe" PresenterAssistant.dproj /t:Build /p:Config=Debug /p:Platform=Win64 /p:DCC_ExeOutput=Win64\Debug\app-build /p:DCC_DcuOutput=Win64\Debug\app-build /p:DelphiDCPOutput=Win64\Debug\app-build /p:DelphiHPPOutputPath=Win64\Debug\app-build /p:DelphiDLLOutputPath=Win64\Debug\app-build /v:minimal /nologo

Application build exit 0; log Win64\Debug\app-build\build.log. Existing third-party
VirtualTrees.Header.pas(280) warning W1075 remains. No main application launched.

## PO manual checks and remaining boundaries

- Open Scene Editor from the existing main-window entry point; verify unchanged
  geometry, list, pinned Add menu and cards at actual display DPI.
- Add each Scene kind; confirm -1 display, stable ordering and selection.
- Edit -1/0/100, move the TrackBar, enter invalid text and switch Scenes; verify
  no unwanted cross-Scene writes and that Save blocks invalid current input.
- Exercise Save As picker cancel/error/success; inspect resulting v2 draft.
- A full interactive v1 Open-to-Save-As test awaits an approved Open UI entry point.
- Settings UI/binding, target editing/discovery, and all VOL-M03/Core Audio runtime
  effects remain deferred. No pending product decision blocks this bounded backend
  and existing-control integration; future Open/Settings UI decisions remain with PO.

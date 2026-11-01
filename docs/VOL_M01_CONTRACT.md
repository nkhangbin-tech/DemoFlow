# VOL-M01: Volume domain and Scene Project persistence

Implementation baseline: b0058ea67bebb9473c614a4bddd824077d065009.
Status: implementation and deterministic verification; not LIVE VERIFIED or ACCEPTED.

## Domain

Scene ExplicitVolumePercent accepts -1 (No Volume Override) and 0..100
(absolute Windows master-volume target). Existing Scene identity, reference and
SceneKind validation remain in place. No runtime volume code has changed.

TSceneAuthoringSnapshot now owns PresentationBaseVolumePercent. Use
NewSceneProject for a new project (empty Scenes, base 50, no invented revision).
Delphi Default(TSceneAuthoringSnapshot) is still a zero-initialized record and
therefore represents base 0, which is a valid explicit value. It is not the new
project creation API. No implicit replacement of existing volume values occurs.

There is no existing domain Scene creation contract. New-Scene default -1 is
therefore deferred to VOL-M02 when the editor creates authoring Scenes; raw
Default(TSceneDefinition) is unchanged. No Scene factory framework is added.

## Codec

SerializeSceneDocument writes PA.SceneProject projectFormatVersion 2, including
required root integer presentationBaseVolumePercent (0..100). Invalid project
base values are rejected, while incomplete Scene authoring drafts retain their
existing schema/authoring-diagnostic separation.

ParseSceneDocument reads versions 1 and 2. Version 1 has logical base 50 and its
Scene values are preserved exactly. Successful parsing exposes SourceFormatVersion;
failed parsing leaves no usable version or partial authoring document. Parsing
and loading do not rewrite files. Legacy PAConfiguration JSON is unaffected.

## File boundary and controller integration gap

LoadSceneProject returns the normalized absolute SourceFileName and the parsed
SourceFormatVersion. Ordinary SaveSceneProject rejects replacement of an existing
successfully readable v1 Scene Project, with a Save As error.

SaveSceneProjectAs takes the successful loaded source context, a distinct target
path and the edited authoring document. It always writes v2. It rejects the original
normalized path and holds the source open without write/delete sharing during the
operation, protecting it against replacement through alternate aliases as well.
It reuses the existing same-directory temporary-file and replacement logic.
Success or failure never mutates source context or edited document. The caller must
adopt the new path/version only after Success; failed Save As keeps the active data.
An existing different v1 project is also protected against replacement.

There is no Open/Save controller wired to the PO-authored editor yet. VOL-M02 must
retain loaded context while editing a separate snapshot, route the first save of
v1 through an explicit Save As dialog and this contract, then adopt/reload the v2
context only after success. Low-level serialization cannot enforce UI intent.
No controller, UI workflow, Forms, runtime or global IDE settings were changed.

## Verification

PAVolumeContractsTests covers boundaries -2/-1/0/50/100/101, new-project base 50,
v2 bases 0/50/100, invalid bases, version/malformed/schema errors, draft/order/
revision preservation, read-only v1 opening, explicit v2 Save As, original-path
rejection and deterministic failed Save As with a replacement sharing violation.
It also checks source/destination bytes, active state and temporary-file cleanup.

Regression suites: PASceneDomainTests, PASceneCompilerTests,
PASceneDocumentCodecTests, PASceneProjectFileStoreTests, PAConfigurationTests and
PADomainTests. Existing expectations that -1 is invalid now use -2 instead.

Build harnesses after calling the existing rsvars.bat:

    dcc64.exe -B -Q -CC -UDomain;Runtime;Persistence;Config -EWin64\Debug\<suite> -NUWin64\Debug\<suite> tests\<harness>.dpr

Use isolated suite directories. TEMP/TMP for file tests are set within Win64\Debug.
The legacy domain console harness receives a newline for its final Readln.
Application build uses the existing .dproj Debug/Win64 with MSBuild; output
properties are overridden for this invocation to Win64\Debug\app-build only.
### Observed results (2026-11-01)

All seven harnesses compiled with exit code 0 and completed with test exit code 0:

| Suite | Output directory under Win64\Debug | Passed | Failed |
| --- | --- | ---: | ---: |
| PAVolumeContractsTests | vol-m01 | 70 | 0 |
| PASceneDomainTests | m02a-regression | 30 | 0 |
| PASceneCompilerTests | m02b-regression | 23 | 0 |
| PASceneDocumentCodecTests | m03a-codec-tests | 149 | 0 |
| PASceneProjectFileStoreTests | m03b-file-store | 19 | 0 |
| PAConfigurationTests | legacy-config | 27 | 0 |
| PADomainTests | legacy-domain | 17 | 0 |

Total: 335 passing assertions/checks, 0 failures. The initial M02-A run exposed
three stale fixtures treating -1 as invalid; those fixtures now use -2 and the
suite passed after rebuilding. Scene creation default is deferred as stated above.

Exact shared compiler setup:

    call "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" >nul

Compiler: D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\dcc64.exe,
Delphi Win64 version 36.0. The harness command above uses its absolute path.

Application command, after that environment initialization:

    "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe" PresenterAssistant.dproj /t:Build /p:Config=Debug /p:Platform=Win64 /p:DCC_ExeOutput=Win64\Debug\app-build /p:DCC_DcuOutput=Win64\Debug\app-build /p:DelphiDCPOutput=Win64\Debug\app-build /p:DelphiHPPOutputPath=Win64\Debug\app-build /p:DelphiDLLOutputPath=Win64\Debug\app-build /v:minimal /nologo

Application build exit code: 0. Existing third-party warning W1075 at
VirtualTrees.Header.pas(280) remains. No application or PowerPoint was launched.
Scoped git diff --check: exit 0. No Git write operations were performed.
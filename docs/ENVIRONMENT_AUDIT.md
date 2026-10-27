# Presenter Assistant (PA) Environment Audit

## Audit scope

- Task: PA-001 — Environment Audit and Project Baseline
- Audit date: 2026-10-27
- Workspace: `E:\Programming\Tool\DemoFlow`
- Host: Windows 10 Home Single Language, version `10.0.19045`, 64-bit

This audit is documentation-only. No application source, project setting, registry
entry, system configuration, or external dependency was changed.

## Verified workspace baseline

The workspace directory exists and contains no files or subdirectories before the
audit documentation was created. In particular, no `.dpr`, `.dproj`, `.pas`,
`.dfm`, `.res`, `.rc`, configuration, test, resource, or application
documentation files were present. There is no `.github/copilot-instructions.md`.

The workspace is not a Git repository. `git status --short --branch` and
`git rev-parse --show-toplevel` both returned Git's fatal “not a git repository”
error. Consequently, there is no branch, commit history, tracked change set, or
untracked-file list to report for this workspace.

**Classification:** no Delphi application yet. This is an empty workspace, not an
initial project skeleton or a partially implemented Presenter Assistant.

## Delphi/RAD Studio evidence

The following installation was found:

- RAD Studio installation root: `D:\Program Files (x86)\Embarcadero\Studio\23.0\`
- IDE executable: `...\bin\bds.exe`
- Win32 compiler: `...\bin\dcc32.exe`
- Win64 compiler: `...\bin\dcc64.exe`
- Environment setup script: `...\bin\rsvars.bat`
- Registry key: `HKLM\SOFTWARE\WOW6432Node\Embarcadero\BDS\23.0`
- Registry `RootDir`: the installation root above
- Registry `ProductVersion`: `29`
- Registry `InstallLanguage`: `EN`

Both compilers reported version `36.0` and their target-specific banners:

- `Embarcadero Delphi for Win32 compiler version 36.0`
- `Embarcadero Delphi for Win64 compiler version 36.0`

The evidence is consistent with the requested RAD Studio/Delphi Athens toolchain,
but the exact installed edition, license state, patch level, and IDE project
personality were not independently verified. No project exists from which to
inspect compiler options or target settings.

### Framework and library evidence

The installation contains:

- `source\vcl`
- `source\rtl`
- `source\rtl\common\System.JSON.pas`
- `source\rtl\common\System.Win.ComObj.pas`
- `source\rtl\win\Winapi.Windows.pas`
- `source\vcl\Vcl.Forms.pas`
- `source\vcl\Vcl.Dialogs.pas`
- `lib\win32\release`
- `lib\win64\release`

This verifies that VCL, RTL JSON, COM helper, Windows API, and both Win32 and
Win64 library trees are installed. It does **not** verify that a future PA project
will compile, that a PowerPoint type library has been imported, or that a
third-party Core Audio, hook, logging, or test library is available.

No PowerPoint-specific Delphi import unit, Core Audio wrapper, logging package,
test framework, or other PA dependency was found in the installation paths
searched. Windows API declarations and COM can be used as implementation
building blocks, but the eventual dependency choice remains open.

## Build and target assessment

Win64 is the safest primary target candidate because:

1. The host operating system is 64-bit.
2. `dcc64.exe` is installed and executes.
3. Delphi `lib\win64\release` is present.
4. Microsoft Office PowerPoint was found at
   `C:\Program Files\Microsoft Office\root\Office16\POWERPNT.EXE`, indicating a
   64-bit Office installation path.

This is a recommendation, not a project change. No target setting was modified.
Win32 remains a possible compatibility target, but Office bitness, deployment
requirements, and any chosen native dependencies must be confirmed before
committing to a dual-target strategy.

`bds.exe` and both Delphi command-line compilers are discoverable. `msbuild.exe`
and `devenv.exe` were not found on the current PATH, and no `msbuild.exe` was
found under the RAD Studio installation searched. The presence of `rsvars.bat`
means a future command-line build environment may be initialized, but no build
was attempted because there is no project.

## PA-specific capability findings

| Area | Verified | Not verified / unresolved |
|---|---|---|
| VCL desktop UI | VCL source and Win32/Win64 libraries are installed | No PA form or project exists |
| JSON scenarios | `System.JSON.pas` is installed | Scenario schema, validation, navigation, and error policy do not exist |
| PowerPoint COM | `System.Win.ComObj.pas` is installed; 64-bit PowerPoint executable exists | COM apartment policy, typelib strategy, event sink lifetime, running-instance discovery, and Office automation behavior |
| Core Audio | Windows host is present | No audio device was returned by the queried WMI sound-device probe; endpoint enumeration, session/master-volume permissions, and a Delphi wrapper are unresolved |
| Global keyboard/mouse hooks | Windows API unit is installed | Hook architecture, callback lifetime, message pump, installation permissions, teardown, and hotkey conflicts |
| Window identification/activation | Windows API unit is installed | Stable matching rules, DPI/session boundaries, minimized windows, foreground restrictions, and activation failure behavior |
| Logging | No PA logging unit or library exists | Log format, rotation, privacy, and failure telemetry |
| Testing | No test files or framework were found | Unit, integration, and hardware/runtime test harness |

## Important technical risks

### PowerPoint COM and events

PowerPoint automation is sensitive to COM initialization mode, process bitness,
Office version, and whether the client attaches to an existing instance or
creates one. Event sinks require explicit connection-point lifetime management
and careful teardown when PowerPoint exits. Calls can block or fail while a modal
dialog, protected view, transition, or add-in is active. The design must define
timeouts, disconnection behavior, and user-visible failures rather than silently
continuing.

### Core Audio

Windows master-volume control generally involves the Core Audio MMDevice and
endpoint-volume COM interfaces. Device absence, default-device changes,
per-session volume versus endpoint volume, muted state, and notification
callbacks all require explicit handling. The current probe did not provide an
audio-device result, so real-device validation is pending.

### Global input hooks

Low-level keyboard and mouse hooks run across process and desktop boundaries and
must remain responsive. Callbacks should do minimal work and marshal actions to
the application thread. Installation failures, callback reentrancy, stuck-button
cleanup, security software interference, and guaranteed unhooking on shutdown
need dedicated tests.

### Window identification and activation

Titles are not stable identifiers. Matching should account for process,
class, executable path, and ownership where possible. `SetForegroundWindow`
can be restricted by Windows focus rules; minimized, elevated, virtual-desktop,
or different-session windows may not activate. Every activation attempt needs a
failure path and an observable diagnostic.

### JSON-driven scenario navigation

The scenario schema, versioning, required fields, unknown-field policy,
encoding, path handling, malformed-file behavior, and atomic navigation
semantics are unspecified. Invalid scenarios must produce actionable errors and
must not leave partially applied actions.

## Open environment limitations

- No application project exists, so compiler options and target settings cannot
  be verified.
- No Git repository exists in the workspace.
- The exact RAD Studio edition/license/update level is unresolved.
- No build or runtime verification is possible until a project and dependencies
  are supplied.
- PowerPoint executable presence is verified, but a live COM session was not
  exercised.
- No usable audio device was verified by the available probe.
- Presenter hardware, browser windows, display topology, permissions, and hook
  behavior were not tested.


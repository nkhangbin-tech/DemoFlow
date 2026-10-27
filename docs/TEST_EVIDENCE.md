# Presenter Assistant Test Evidence

## PA-001/PA-002/PA-002R/PA-003/PA-004A/PA-004B evidence

- Audit date: 2026-10-27
- Source implementation: **Complete for the minimal PA-003 skeleton**
- Command-line Win64 build verification: **Completed**
- Delphi IDE build verification: **Pending**
- Application runtime verification: **Pending**
- Automated test verification: **Pending**
- Hardware/integration verification: **Pending**
- PA-004A source implementation: **Complete**
- PA-004A command-line application build: **Completed**
- PA-004A domain harness build: **Completed**
- PA-004A domain tests executed: **Completed**
- PA-004A developer IDE/runtime verification: **Pending**
- PA-004B source implementation: **Complete**
- PA-004B command-line application build: **Completed**
- PA-004B configuration harness build: **Completed**
- PA-004B configuration tests executed: **Completed**
- PA-004B developer IDE/runtime verification: **Pending**
- PA-004C source implementation: **Complete**
- PA-004C command-line application build: **Completed**
- PA-004C logger harness build: **Completed**
- PA-004C logger harness execution: **Completed; exit code 0**
- PA-004C developer IDE/runtime verification: **Pending**
- PA-005A source implementation: **Complete**
- PA-005A command-line Win64 application build: **Completed**
- PA-005A automated bootstrap harness: **Not added; startup is VCL-owned and
  requires manual IDE/runtime verification**
- PA-005A developer IDE/runtime verification: **Pending**

PA-004A added only RTL-only domain contracts and pure volume helpers plus a
small console harness. It did not implement system tray behavior, PowerPoint,
Core Audio, input hooks, window tracking, browser activation, sequence routing,
JSON configuration, or logging.

## Exact commands and results

### Initial compiler attempt

```powershell
& $env:ComSpec /c 'call "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" >nul && cd /d E:\Programming\Tool\DemoFlow && dcc64.exe -B -Q -EWin64\Debug -NUWin64\Debug PresenterAssistant.dpr'
```

Result: **failed** with:

```text
uMainForm.pas(32) Fatal: F2039 Could not create output file 'Win64\Debug\uMainForm.dcu'
```

The generated-output directory did not yet exist.

### Resource and successful compiler build

```powershell
New-Item -ItemType Directory -Path 'E:\Programming\Tool\DemoFlow\Win64\Debug' -Force
& $env:ComSpec /c 'call "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" >nul && cd /d E:\Programming\Tool\DemoFlow && brcc32.exe -foPresenterAssistant.res PresenterAssistant.rc && dcc64.exe -B -Q -EWin64\Debug -NUWin64\Debug PresenterAssistant.dpr'
```

Result: **success**, compiler exit code `0`.

Observed compiler output included:

```text
Embarcadero Delphi for Win64 compiler version 36.0
48 lines, 0.19 seconds, 3044408 bytes code, 323004 bytes data.
CompilerExitCode=0
```

The build produced `Win64\Debug\PresenterAssistant.exe` and
`Win64\Debug\uMainForm.dcu`. The generated `Win64` directory is ignored by
`.gitignore`.

`msbuild.exe` was not found on PATH or under the searched RAD Studio
installation, so no Delphi-compatible MSBuild project build was attempted.

## PA-004A exact commands and observed results

```powershell
& $env:ComSpec /c 'call "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" >nul && cd /d E:\Programming\Tool\DemoFlow && dcc64.exe -B -Q -EWin64\Debug -NUWin64\Debug PresenterAssistant.dpr'
```

Result: **success**, Delphi Win64 compiler version `36.0`; the application
compiled with `Domain\PADomainTypes.pas`.

```powershell
& $env:ComSpec /c 'call "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" >nul && cd /d E:\Programming\Tool\DemoFlow && dcc64.exe -B -Q -CC -EWin64\Debug\tests -NUWin64\Debug\tests tests\PADomainTests.dpr'
& 'E:\Programming\Tool\DemoFlow\Win64\Debug\tests\PADomainTests.exe'
```

Result: The first invocation without a unit search path failed with
`F1026 File not found: '..\Domain\PADomainTypes.pas'`. The harness was then
compiled and run with the corrected command:

```powershell
& $env:ComSpec /c 'call "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" >nul && cd /d E:\Programming\Tool\DemoFlow && dcc64.exe -B -Q -CC -UDomain -EWin64\Debug\tests -NUWin64\Debug\tests tests\PADomainTests.dpr'
& 'E:\Programming\Tool\DemoFlow\Win64\Debug\tests\PADomainTests.exe'
```

Result: **success**. The corrected harness compiled and all boundary, offset,
clipping, and default-state tests passed with exit code `0`.

The PA-004A tests were run in this session. No Delphi IDE build or manual
application runtime test was performed in this session.

## PA-004B exact commands and observed results

```powershell
& $env:ComSpec /c 'call "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" >nul && cd /d E:\Programming\Tool\DemoFlow && dcc64.exe -B -Q -EWin64\Debug -NUWin64\Debug PresenterAssistant.dpr'
```

Result: **success**, Delphi Win64 compiler version `36.0`, exit code `0`.

```powershell
& $env:ComSpec /c 'call "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" >nul && cd /d E:\Programming\Tool\DemoFlow && dcc64.exe -B -Q -CC -UDomain;Config -EWin64\Debug\config-tests -NUWin64\Debug\config-tests tests\PAConfigurationTests.dpr'
& 'E:\Programming\Tool\DemoFlow\Win64\Debug\config-tests\PAConfigurationTests.exe'
```

Result: **success**, compiler exit code `0`, test process exit code `0`.
All configuration tests reported `PASS`, followed by
`All configuration tests passed.`

The first configuration test run exposed fixture/cleanup issues and exited `1`;
those test-only issues were corrected before the successful run above. The
successful run used only isolated temporary paths and cleaned them up.

No Delphi IDE build or manual application runtime test was performed in this
session.

## PA-004C exact commands and observed results

The logger unit was compiled as part of the main Win64 application:

```powershell
& $env:ComSpec /c 'call "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" >nul && cd /d E:\Programming\Tool\DemoFlow && dcc64.exe -B -Q -EWin64\Debug -NUWin64\Debug PresenterAssistant.dpr'
```

Result: **success**, Delphi Win64 compiler version `36.0`, exit code `0`.
The application compiled with `Infrastructure\PALogger.pas`.

The isolated RTL-only logger harness was compiled with:

```powershell
& $env:ComSpec /c 'call "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" >nul && cd /d E:\Programming\Tool\DemoFlow && dcc64.exe -B -Q -CC -UInfrastructure -EWin64\Debug\logger-tests -NUWin64\Debug\logger-tests tests\PALoggerTests.dpr'
```

Result: **success**, compiler exit code `0`.

The harness was executed with:

```powershell
& 'E:\Programming\Tool\DemoFlow\Win64\Debug\logger-tests\PALoggerTests.exe'
```

Result: **success**, process exit code `0`; all logger tests reported `PASS`,
followed by `All logger tests passed.` The tests used a temporary directory
and removed it after completion.

The logger harness uses `logger-test-data` below the executable directory and
removes it after completion. The writer-error case uses a directory path as
the configured log filename.
The logger records the resulting file-creation failure through
`WriteErrorCount` without raising an unhandled writer-thread exception.

The logger format is UTF-8 JSON Lines with ISO-8601 timestamps including
milliseconds, severity, category, string correlation ID, message, and
optional explicit exception fields. Query strings and fragments in HTTP/HTTPS
URLs are replaced before queue insertion. The logger does not attempt to
identify arbitrary secrets in free-form text.

## PA-005A build evidence

The integrated Win64 application was built with:

```powershell
& $env:ComSpec /c 'call "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" >nul && cd /d E:\Programming\Tool\DemoFlow && dcc64.exe -B -Q -UConfig;Domain;Infrastructure -EWin64\Debug -NUWin64\Debug PresenterAssistant.dpr'
```

Result: **success**, Delphi Win64 compiler version `36.0`, exit code `0`.

The application now resolves configuration and logs under
`%LOCALAPPDATA%\PresenterAssistant\`, displays the actual logger and
configuration results, enters safe mode for missing or invalid configuration,
and shuts down the logger through `Flush` and `Shutdown`. The non-personal
fixture is [PA005A-example-config.json](../tests/fixtures/PA005A-example-config.json).

## Collected environment evidence

| Check | Result | Interpretation |
|---|---|---|
| `dcc32.exe -?` | Passed; Win32 compiler version 36.0 printed help | Win32 compiler is callable |
| `dcc64.exe -?` | Passed; Win64 compiler version 36.0 printed help | Win64 compiler is callable |
| `bds.exe` lookup | Found under RAD Studio 23.0 `bin` | IDE executable is installed |
| `msbuild.exe` lookup | Not found | No standalone MSBuild was available on PATH or under the searched RAD Studio tree |
| `devenv.exe` lookup | Not found | Visual Studio IDE was not available via PATH |
| VCL/RTL source probes | VCL, JSON, COM, and Windows units found | Framework source is installed |
| PowerPoint path probe | 64-bit `POWERPNT.EXE` found | Office executable presence only; COM not tested |
| WMI sound-device probe | No device rows returned | Audio runtime capability remains unverified |
| Git status probe | Fatal: not a Git repository | No repository baseline is available |

The Git state changed after the PA-001 audit: the current workspace is on branch
`main` with no reported working-tree changes before PA-002 documentation was
written. The PA-001 row above is retained as historical evidence and is not
rewritten.

## Developer IDE and runtime checks still required

1. Open `PresenterAssistant.dproj` in RAD Studio / Delphi 12.3.
2. Confirm the active target is **Win64** in the project target selector.
3. Select the **Debug** configuration.
4. Choose **Project > Build All**.
5. Confirm the IDE reports no compilation errors.
6. Run the application.
7. Confirm the form caption is `Presenter Assistant`.
8. Confirm the form displays: “The application skeleton is running. No
   automation services are enabled.”
9. Click **Close** and confirm the process exits normally.

Record the IDE version, target/configuration, build result, and runtime result
before marking PA-003 complete.

## Required future evidence

Before PA is considered build- or runtime-ready, capture reproducible results
for at least:

1. A clean Win64 project build using the selected Delphi project file.
2. Unit tests for scenario parsing, validation, navigation, and error handling.
3. COM attach/launch, PowerPoint event, disconnect, and shutdown behavior.
4. Window matching and foreground activation failure cases.
5. Core Audio endpoint enumeration, volume/mute changes, and device changes.
6. Keyboard/mouse hook installation, event routing, and guaranteed cleanup.
7. Runtime tests with actual PowerPoint, browser windows, audio devices, and
   presenter hardware in the supported environment matrix.

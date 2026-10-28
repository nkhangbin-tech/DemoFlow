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
- PA-006A source implementation: **Complete**
- PA-006A Win64 probe build: **Completed**
- PA-006A PowerPoint runtime verification: **Developer-reported slideshow test complete; broader reconnect/termination cases remain pending**
- PA-006B1 source implementation: **Complete**
- PA-006B1 monitor harness build/run: **Completed; exit code 0**
- PA-006B1 focused monitor tests: **Completed; exit code 0**
- PA-006B1 live slideshow runtime verification: **Pending developer test**
- PA-007A source implementation: **Complete**
- PA-007A type-library import: **Completed from installed MSPPT.OLB**
- PA-007A deterministic state tests: **Completed; exit code 0**
- PA-007A live event delivery: **Accepted by developer-reported slideshow log**
- PA-007B production monitor source/build: **Completed; integrated live test pending**
- PA-007B deterministic monitor tests: **Completed; exit code 0**
- PA-007B main VCL build: **Completed; exit code 0**
- PA-008A source implementation: **Complete**
- PA-008A Core Audio declarations: **Verified against Windows SDK headers**
- PA-008A pure helper tests: **Completed; exit code 0**
- PA-008A Win64 probe build: **Completed; exit code 0**
- PA-008A local endpoint smoke test: **Completed; 3 active render endpoints,
  default console endpoint, scalar, and mute state read successfully**
- PA-008A developer identity/non-mutation review: **Pending**
- PA-008A executable separation: **Confirmed; diagnostic output contains
  endpoint records, while `PASS:` output is confined to the separate test
  executable**

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
The required dedicated output is
`Win64\Debug\event-probe\PAPowerPointEventProbe.exe`.

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

## PA-005B build and regression evidence

The PA-005B application was built with:

```powershell
& $env:ComSpec /c 'call "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" >nul && cd /d E:\Programming\Tool\DemoFlow && dcc64.exe -B -Q -UConfig;Domain;Infrastructure -EWin64\Debug2 -NUWin64\Debug2 PresenterAssistant.dpr'
```

Result: **success**, Delphi Win64 compiler version `36.0`, exit code `0`.
The standard `Win64\Debug` executable was locked by a running/external
process during this verification, so the build used the clean temporary
`Win64\Debug2` output directory.

Regression harnesses were compiled and executed from `Win64\Debug2`:

- `PADomainTests.exe`: exit code `0`; all domain tests passed.
- `PAConfigurationTests.exe`: exit code `0`; all configuration tests passed,
  including failed-reload preservation.
- `PALoggerTests.exe`: exit code `0`; all logger tests passed.

PA-005B manual tray, minimize, ordinary-close, reload-menu, explicit-exit,
and Windows session-end checks remain **pending developer verification**.

## PA-006A probe build and no-PowerPoint evidence

The standalone probe was built with:

```powershell
New-Item -ItemType Directory -Path 'E:\Programming\Tool\DemoFlow\Win64\Debug\tools' -Force
& $env:ComSpec /c 'call "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" >nul && cd /d E:\Programming\Tool\DemoFlow && dcc64.exe -B -Q -CC -EWin64\Debug\tools -NUWin64\Debug\tools tools\PAPowerPointProbe.dpr'
```

Result: **success**, Delphi Win64 compiler version `36.0`, exit code `0`.
Output executable:
`Win64\Debug\tools\PAPowerPointProbe.exe`.

The probe was also run for five seconds without a running PowerPoint
automation instance:

```powershell
& 'E:\Programming\Tool\DemoFlow\Win64\Debug\tools\PAPowerPointProbe.exe' 5
```

Observed result: repeated
`UNAVAILABLE PowerPoint.Application GetActiveObject hresult=800401E3`,
then `SUMMARY probe_complete`; process exit code `0`.

The attachment path was then changed from Delphi's exception-raising
`GetActiveOleObject` helper to the Windows `GetActiveObject` HRESULT API.
This prevents the expected no-instance condition from appearing as an
`EOleSysError` first-chance exception in the Delphi debugger.

During live attachment testing, the dispatch was also corrected to use an
explicit `varDispatch` variant with retained COM ownership. The probe then
reported `ATTACHED PowerPoint.Application` and
`CONNECTED slideshowWindows=0` for a five-second run, followed by
`SUMMARY probe_complete` and exit code `0`.

This verifies the no-instance/retry path and the live attachment path below.
The developer must still run the remaining manual cases in
[POWERPOINT_COM_PROBE.md](POWERPOINT_COM_PROBE.md) before PA-006B is considered
fully runtime-verified.

### Developer-reported animated slideshow evidence

The probe was rerun for 45 seconds while an animated slideshow was active.
The developer reported exit code `0` and the following observed transitions:

```text
ATTACHED PowerPoint.Application
CONNECTED slideshowWindows=0
TRANSITION slideshow_started
CONNECTED slideshowWindows=1 window=1 slideIndex=3 showPosition=0
CONNECTED slideshowWindows=1 window=1 slideIndex=3 showPosition=3
CONNECTED slideshowWindows=1 window=1 slideIndex=2 showPosition=0
CONNECTED slideshowWindows=1 window=1 slideIndex=2 showPosition=2
CONNECTED slideshowWindows=1 window=1 slideIndex=3 showPosition=0
CONNECTED slideshowWindows=1 window=1 slideIndex=3 showPosition=3
CONNECTED slideshowWindows=1 window=1 slideIndex=4 showPosition=0
CONNECTED slideshowWindows=1 window=1 slideIndex=4 showPosition=4
```

This confirms live attachment, slideshow start, slide navigation, and that
`SlideIndex` and `CurrentShowPosition` are reported as separate values.
Because this is developer-observed runtime evidence, it is not a substitute
for the remaining reconnect, slideshow termination, and multiple-window cases.

## PA-006B1 monitor evidence

The reusable monitor harness was built with:

```powershell
& $env:ComSpec /c 'call "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" >nul && cd /d E:\Programming\Tool\DemoFlow && dcc64.exe -B -Q -CC -UPowerPoint -EWin64\Debug\monitor-tests -NUWin64\Debug\monitor-tests tools\PAPowerPointMonitorProbe.dpr'
```

Result: **success**, Delphi Win64 compiler version `36.0`, exit code `0`.
The harness ran for five seconds and reported
`connected-no-show windows=0`, then `SUMMARY monitor_complete`, with process
exit code `0`.

The focused monitor harness was compiled and executed from the same output
directory. It verified interval clamping, explicit state names, snapshot
publication, bounded stop, and repeated stop; all tests passed with exit code
`0`.

## PA-006B2 VCL integration evidence

The main VCL application was rebuilt after integrating the reusable monitor
with a 250 ms VCL timer, truthful PowerPoint status labels, tray status
updates, and bounded monitor shutdown:

```powershell
& $env:ComSpec /c 'call "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" >nul && cd /d E:\Programming\Tool\DemoFlow && dcc64.exe -B -Q -NSSystem;Vcl;Winapi -UConfig;Domain;Infrastructure;PowerPoint -IConfig;Domain;Infrastructure;PowerPoint -EWin64\Debug2\ PresenterAssistant.dpr'
```

Result: **success**, Delphi Win64 compiler version `36.0`, exit code `0`.
The focused PA-006B1 monitor regression harness was rebuilt and executed after
the integration changes. All seven tests passed with exit code `0`.

The following remain developer verification items: Delphi IDE build and
runtime startup, live PowerPoint no-show/show/disconnect transitions, multiple
slideshow-window ambiguity, tray tooltip/status updates while the form is
hidden, and shutdown/session-end behavior. No runtime claim is made for those
cases here.

## PA-007A PowerPoint event probe evidence

The installed PowerPoint type library was imported with RAD Studio 12.3:

```powershell
& 'D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\tlibimp.exe' -P '-DE:\Programming\Tool\DemoFlow\tools\generated' 'C:\Program Files\Microsoft Office\root\Office16\MSPPT.OLB'
```

Result: **success**. The importer generated the project-owned
`PowerPoint_TLB.pas`, `Office_TLB.pas`, and `VBIDE_TLB.pas` declarations.
The imported declarations identify the PowerPoint `EApplication` outgoing
interface and the verified event signatures documented in
[POWERPOINT_EVENT_PROBE.md](POWERPOINT_EVENT_PROBE.md).

The standalone event probe was built with:

```powershell
& $env:ComSpec /c 'call "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" >nul && cd /d E:\Programming\Tool\DemoFlow && dcc64.exe -B -Q -CC -Utools;tools\generated -Itools;tools\generated -EWin64\Debug\event-probe\ tools\PAPowerPointEventProbe.dpr'
```

Result: **success**, Delphi Win64 compiler version `36.0`, exit code `0`.

The deterministic event-state harness was built and run with:

```powershell
& $env:ComSpec /c 'call "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" >nul && cd /d E:\Programming\Tool\DemoFlow && dcc64.exe -B -Q -CC -Utools -Itools -EWin64\Debug2\ tests\PAEventProbeStateTests.dpr && Win64\Debug2\PAEventProbeStateTests.exe'
```

Result: **success**, exit code `0`; all thirteen deterministic tests passed,
including event-source loss and idempotent shutdown/unsubscription state.

The probe was run for five seconds while an existing PowerPoint instance was
available but no slideshow was active:

```text
START durationSeconds=5 eventInterface=EApplication
EVENT_SINK_CONNECTED interface=EApplication
RECONCILIATION_COMPLETED windows=0 slideIndex=0 hasSlideIndex=False showPosition=0 hasShowPosition=False
EVENT_SINK_DISCONNECTED
SUMMARY probe_complete pollSequence=10 droppedEvents=0
```

Process exit code: `0`. This confirms existing-instance attachment,
connection-point setup, STA message pumping, read-only reconciliation, and
idempotent normal unsubscription. It does not prove that live PowerPoint
fires every event; the slideshow event procedure in
[POWERPOINT_EVENT_PROBE.md](POWERPOINT_EVENT_PROBE.md) remains pending
developer verification.

The event probe has a distinctive startup header and records
`SlideShowNextClick` separately from `SlideShowNextBuild`. It treats
`showPosition=0` as unavailable and reports the condition explicitly rather
than treating zero as a valid position.

The production polling monitor still copies `CurrentShowPosition` into its
snapshot and marks the field available without applying the event-probe
zero-value check. This is a separately identified improvement for the
production monitor; it was not changed under PA-007A-FIX. Its existing
per-observation exception handling publishes explicit fault/window error
text for transient COM/RPC failures rather than fabricating a slide.

The corrected dedicated probe was run with:

```powershell
& 'E:\Programming\Tool\DemoFlow\Win64\Debug\event-probe\PAPowerPointEventProbe.exe' 5
```

Observed output included:

```text
Presenter Assistant PowerPoint COM EVENT diagnostic probe
POWERPOINT_UNAVAILABLE GetActiveObject hresult=800401E3
EVENT_SINK_CONNECTED interface=EApplication
RECONCILIATION_COMPLETED windows=0 slideIndex=0 hasSlideIndex=False showPosition=0 hasShowPosition=False
EVENT_SINK_DISCONNECTED
SUMMARY probe_complete pollSequence=10 droppedEvents=0
```

The process exited with code `0`. This is a no-slideshow/attachment smoke
test only; it does not claim live delivery of the five PowerPoint events.

### PowerPoint disconnect cleanup fix

After developer-reported `EOleSysError: The object invoked has disconnected
from its clients` when PowerPoint exited, COM variant cleanup in the monitor
was hardened. Expected `EOleSysError` and `EVariantError` exceptions during
variant teardown are contained in the worker, and the monitor continues with
its normal fault/disconnected and reattachment state flow. The main Win64
application rebuilt successfully and all seven focused monitor tests passed
with exit code `0` after this fix. Live PowerPoint exit/reconnect verification
remains a developer runtime check.

The worker also has a final exception boundary: an unexpected automation or
RPC exception is converted into a sequenced fault snapshot rather than
escaping through the VCL application thread.

### PA-007B production integration evidence

The production monitor now uses the generated `PowerPoint_TLB` declarations
and `TPowerPointApplication` connection-point wrapper on its dedicated STA
worker. Its event callbacks only record bounded metadata and request later
reconciliation. The worker pumps Windows messages, disconnects the event sink
before releasing the application interface, and retries attachment on the
normal bounded polling cadence after a COM/RPC failure.

The monitor harness was built and run with:

```powershell
& $env:ComSpec /c 'call "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" >nul && cd /d E:\Programming\Tool\DemoFlow && dcc64.exe -B -Q -CC -UPowerPoint;tools\generated -Itools\generated -EWin64\Debug\monitor-tests -NUWin64\Debug\monitor-tests tests\PAPowerPointMonitorTests.dpr && Win64\Debug\monitor-tests\PAPowerPointMonitorTests.exe'
```

Result: build succeeded and all 10 checks passed with exit code `0`,
including zero/negative-position rejection, later valid-position restoration,
snapshot publication, bounded stop, and repeated stop. The separate PA-007A
event-state harness covers event ordering and post-callback reconciliation;
production event delivery remains a live runtime check.

The integrated VCL application was built with:

```powershell
& $env:ComSpec /c 'call "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" >nul && cd /d E:\Programming\Tool\DemoFlow && dcc64.exe -B -Q -CC -UPowerPoint;tools\generated -Itools\generated -EWin64\Debug\app-build -NUWin64\Debug\app-build PresenterAssistant.dpr'
```

Result: build succeeded with exit code `0`.

The standalone production-monitor probe was built and smoke-tested with:

```powershell
& $env:ComSpec /c 'call "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" >nul && cd /d E:\Programming\Tool\DemoFlow && dcc64.exe -B -Q -CC -UPowerPoint;tools\generated -Itools\generated -EWin64\Debug\monitor-probe -NUWin64\Debug\monitor-probe tools\PAPowerPointMonitorProbe.dpr && Win64\Debug\monitor-probe\PAPowerPointMonitorProbe.exe 5'
```

Result: build and run succeeded with exit code `0`; the no-slideshow smoke
output reported `connected-no-show`, `eventSequence=0`, and zero diagnostic
event counters.

The production monitor has not yet been run through the developer's complete
integrated slideshow, animation, PowerPoint-exit, and reattachment procedure.
Those are runtime checks and are not claimed by these deterministic results.

### PA-008A Core Audio probe evidence

The probe was built with:

```powershell
& $env:ComSpec /c 'call "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" >nul && cd /d E:\Programming\Tool\DemoFlow && dcc64.exe -B -Q -CC -UCoreAudio -EWin64\Debug\audio-probe -NUWin64\Debug\audio-probe tools\PACoreAudioProbe.dpr'
```

Compiler result: Delphi Win64 compiler version `36.0`, build succeeded, exit
code `0`.

The pure helper harness was built and run with:

```powershell
& $env:ComSpec /c 'call "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" >nul && cd /d E:\Programming\Tool\DemoFlow && dcc64.exe -B -Q -CC -UCoreAudio -EWin64\Debug\audio-tests -NUWin64\Debug\audio-tests tests\PACoreAudioProbeTests.dpr && Win64\Debug\audio-tests\PACoreAudioProbeTests.exe'
```

Result: 7 checks passed, exit code `0`, including scalar values `0.0`, `0.5`,
and `1.0`, out-of-range rejection, and explicit endpoint-state naming.

The local read-only probe run reported three active render endpoints, found the
default console endpoint, and read scalar/mute state for all three. The actual
diagnostic executable output was:

```text
PROBE_START name=PACoreAudioProbe
Presenter Assistant Windows Core Audio diagnostic probe
Read-only diagnostic; this utility will not change volume or mute state.
COM_INITIALIZED
DEFAULT_CONSOLE_ENDPOINT={0.0.0.00000000}.{f90bae51-14d4-48fe-8115-a8d41277e786}
ENDPOINT_COUNT=3
ENDPOINT index=0
  FRIENDLY_NAME=Headset Earphone (SRS-XB32 Hands-Free AG Audio)
  MASTER_VOLUME_SCALAR=0.112
  MASTER_VOLUME_DISPLAY_PERCENT=11
  MUTED=False
ENDPOINT index=1
  FRIENDLY_NAME=LG ULTRAFINE (NVIDIA High Definition Audio)
  MASTER_VOLUME_SCALAR=0.380
  MASTER_VOLUME_DISPLAY_PERCENT=38
  MUTED=False
ENDPOINT index=2
  FRIENDLY_NAME=Speakers (SRS-XB32 Stereo)
  MASTER_VOLUME_SCALAR=0.228
  MASTER_VOLUME_DISPLAY_PERCENT=23
  MUTED=False
SUMMARY comInitialized=True endpointFailures=0 defaultFound=True
PROBE_COMPLETE status=success
```

The probe exited with code `0`. This is direct endpoint enumeration evidence
from the current machine, not a claim that every target machine has an
accessible endpoint. The developer must still compare the reported default
friendly name and mute/volume state with Windows Sound settings and confirm
that no state changed.

The observed `PASS:` output is not diagnostic output. It is emitted by
`tests\PACoreAudioProbeTests.dpr`, whose executable is
`Win64\Debug\audio-tests\PACoreAudioProbeTests.exe`. The diagnostic entry point
is `tools\PACoreAudioProbe.dpr`, built as
`Win64\Debug\audio-probe\PACoreAudioProbe.exe`; its output begins with
`PROBE_START` and contains `ENDPOINT_COUNT`, `ENDPOINT`, and `SUMMARY` records.
The separate test executable was also rebuilt and exited with code `0`; its
`PASS:` output is not live endpoint evidence.

### PA-008B Production Core Audio service evidence

Source implementation:

- `Audio\PACoreAudioService.pas` owns Core Audio COM interfaces on a dedicated
  STA worker.
- `CoreAudio\PACoreAudioApi.pas` contains the shared MMDevice, endpoint-volume,
  endpoint-volume callback, and notification-client declarations.
- `tools\PAAudioServiceProbe.dpr` uses the public service API and is read-only
  by default. It supports explicit one-shot and `--continuous` modes.
- `tests\PAAudioServiceTests.dpr` covers deterministic service logic and
  lifecycle behavior without changing volume.

The service probe was built with:

```powershell
& $env:ComSpec /c 'call "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" >nul && cd /d E:\Programming\Tool\DemoFlow && dcc64.exe -B -Q -CC -UCoreAudio;Audio -EWin64\Debug\audio-service-probe -NUWin64\Debug\audio-service-probe tools\PAAudioServiceProbe.dpr'
```

The deterministic service harness was built and run with:

```powershell
& $env:ComSpec /c 'call "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" >nul && cd /d E:\Programming\Tool\DemoFlow && dcc64.exe -B -Q -CC -UCoreAudio;Audio -EWin64\Debug\audio-service-tests -NUWin64\Debug\audio-service-tests tests\PAAudioServiceTests.dpr && Win64\Debug\audio-service-tests\PAAudioServiceTests.exe'
```

Result: 17 checks passed, exit code `0`. The checks covered percentage
validation/conversion, explicit unavailable state names, request status names,
own/external event-context classification, initial snapshot absence, invalid
request rejection, repeated start/stop, and restart.
The final harness also covers unchanged-snapshot suppression semantics and
endpoint/volume change detection.

The main Win64 VCL application was rebuilt with:

```powershell
& $env:ComSpec /c 'call "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" >nul && cd /d E:\Programming\Tool\DemoFlow && dcc64.exe -B -Q -CC -Utools\generated;Config;Domain;Infrastructure;PowerPoint;CoreAudio;Audio -EWin64\Debug\app -NUWin64\Debug\app PresenterAssistant.dpr'
```

Result: Delphi Win64 compiler version `36.0`, build succeeded, exit code `0`.

The read-only service probe was run for five seconds:

```text
PROBE_START name=PAAudioServiceProbe
Presenter Assistant production Core Audio service probe
Default mode is read-only; no volume or mute change is requested.
SERVICE_STARTED volumeMode=callback-driven initialRead=once
SNAPSHOT sequence=3 state=available endpoints=3 endpointId={0.0.0.00000000}.{f90bae51-14d4-48fe-8115-a8d41277e786} friendlyName=Speakers (SRS-XB32 Stereo) hasVolume=TRUE displayPercent=23 muted=FALSE ownChange=FALSE ownCount=0 externalCount=0 event= error=
SNAPSHOT sequence=5 state=available endpoints=3 endpointId={0.0.0.00000000}.{f90bae51-14d4-48fe-8115-a8d41277e786} friendlyName=Speakers (SRS-XB32 Stereo) hasVolume=TRUE displayPercent=23 muted=FALSE ownChange=FALSE ownCount=0 externalCount=0 event= error=
SNAPSHOT sequence=7 state=available endpoints=3 endpointId={0.0.0.00000000}.{f90bae51-14d4-48fe-8115-a8d41277e786} friendlyName=Speakers (SRS-XB32 Stereo) hasVolume=TRUE displayPercent=23 muted=FALSE ownChange=FALSE ownCount=0 externalCount=0 event= error=
SNAPSHOT sequence=9 state=available endpoints=3 endpointId={0.0.0.00000000}.{f90bae51-14d4-48fe-8115-a8d41277e786} friendlyName=Speakers (SRS-XB32 Stereo) hasVolume=TRUE displayPercent=23 muted=FALSE ownChange=FALSE ownCount=0 externalCount=0 event= error=
SNAPSHOT sequence=11 state=available endpoints=3 endpointId={0.0.0.00000000}.{f90bae51-14d4-48fe-8115-a8d41277e786} friendlyName=Speakers (SRS-XB32 Stereo) hasVolume=TRUE displayPercent=23 muted=FALSE ownChange=FALSE ownCount=0 externalCount=0 event= error=
SHUTDOWN_COMPLETE status=success
PROBE_COMPLETE status=success
```

This is live read-only service evidence on the current machine. It does not
prove endpoint replacement recovery, external Windows volume-UI callbacks, or
successful volume setting. The `--set` probe option was not used.

The continuous manual command is:

```powershell
& 'E:\Programming\Tool\DemoFlow\Win64\Debug\audio-service-probe\PAAudioServiceProbe.exe' --continuous
```

No continuous interactive session was claimed as automated evidence in this
run. A redirected `echo.|` attempt was intentionally stopped because it does
not provide an interactive console Enter event. The user must run the command
from an interactive console and press Enter to stop it after observing volume
and default endpoint changes.

Existing regression results after PA-008B changes:

- Domain harness: passed, exit code `0`.
- Configuration harness: passed, exit code `0`.
- Logger harness: passed, exit code `0`.
- PowerPoint monitor harness: passed, exit code `0`.
- PowerPoint event-state harness: passed, exit code `0`.
- Continuous probe build: passed, exit code `0`; explicit one-shot probe run:
  passed, exit code `0`.

PA-008B-FIX3 verification:

- Focused audio service build: passed with `dcc64.exe`, exit code `0`.
- Focused audio service tests: passed, exit code `0`, including scalar-aware
  filtering, mute-only changes, unchanged suppression, and the reconciliation
  comparison seam.
- Main Win64 application build: passed with `dcc64.exe`, exit code `0`.
- Read-only one-shot probe: passed, exit code `0`; output reported
  `callbackRegistrationHr=00000000`, `source=reconciliation`, scalar, and
  reconciliation diagnostics. No `--set` mode was used.
- PowerPoint monitor regression build was not completed in this invocation
  because the generated `PowerPoint_TLB` unit path was not supplied; no source
  change was made to that subsystem.

The historical FIX3 diagnostics distinguished callback delivery from periodic
reconciliation. That polling path was removed by FIX9; the historical output
is retained as evidence of the earlier implementation only.

PA-008B-FIX4 diagnostic build:

- The prior probe executable at
  `Win64\Debug\audio-service-probe\PAAudioServiceProbe.exe` was timestamped
  11:23:15, after the prior FIX3 source timestamp, and contained the FIX3
  fields. It did not contain the FIX4 heartbeat.
- FIX4 adds the opt-in `DIAGNOSTIC_HEARTBEAT` mode. The read-only diagnostic
  run built from the current source reported successful scalar and mute reads
  (`00000000`) and callback registration (`00000000`). No live volume-change
  result has been claimed.

PA-008B-FIX5 diagnostic comparison:

- The heartbeat's original `getScalarHr` and `scalar` fields were confirmed
  to come from the snapshot populated by the worker's bound
  `GetMasterVolumeLevelScalar` call; they were not fresh calls made by the
  probe.
- Diagnostic mode now performs a separate activation of
  `IAudioEndpointVolume` for the current default endpoint on the same STA
  worker and reports `freshScalarHr`, `freshScalar`, `freshMuteHr`,
  `freshMuted`, and `freshEndpointId`.
- A read-only local run showed the bound and fresh paths agreeing at
  `0.93000001`, both scalar and mute HRESULTs `00000000`, and the same
  endpoint ID. This is an idle comparison only; no manual volume change was
  made during the run, so the runtime defect is not yet identified or claimed
  fixed.

PA-008B-FIX6 diagnostic endpoint coverage:

- The manual declaration matches the Windows SDK method order through
  `VolumeStepDown`; the SDK continues with `QueryHardwareSupport` and
  `GetVolumeRange`, which are not used by this service. The IID,
  `stdcall` convention, `out` scalar/mute parameters, `IMMDevice.Activate`
  flow, and callback method/registration declarations are consistent with the
  SDK contract.
- Diagnostic mode now reports all three default render roles and every active
  render endpoint, including endpoint ID, friendly name, scalar HRESULT/value,
  and mute HRESULT/value. These reads remain on the worker STA and are
  read-only.
- No live role/endpoint comparison has been performed in this invocation, so
  no runtime root cause or fix is claimed.

PA-008B-FIX7 verification:

- The previous continuous-mode exit was traced to `EnterWasPressed` treating
  any signaled standard-input handle as a console event source. FIX7 now
  requires `GetConsoleMode` to succeed before reading console input. One-shot
  duration logic remains unchanged, while continuous mode bypasses duration
  checks.
- The rebuilt continuous diagnostic probe was started with redirected output,
  remained alive after three seconds (`alive=True`), printed its startup and
  heartbeat output, and was then terminated explicitly by the test harness.
- No Microsoft C++ compiler or Windows SDK include tree was available:
  `cl`, `clang-cl`, and `msbuild` were not on PATH, and the expected Windows
  Kits include path was absent. No independent SDK verifier was built or
  claimed.

PA-008B-FIX8 correction:

- The callback payload declaration was corrected to the Windows SDK order:
  `GUID`, `BOOL bMuted`, `float fMasterVolume`, `UINT nChannels`, and channel
  volumes.
- `IAudioEndpointVolume.RegisterControlChangeNotify` and
  `UnregisterControlChangeNotify` now accept
  `IAudioEndpointVolumeCallback`, and the service passes the typed callback
  interface rather than an `IUnknown` cast. This is the minimal
  evidence-supported binding correction for callback delivery.
- Continuous probe termination now prints an explicit reason. The
  `GetConsoleMode` guard remains in place and duration checks remain limited to
  one-shot mode.
- FIX8 automated builds and tests do not prove live callback delivery. A live
  verification remains required.

The final live verification recorded below supersedes the FIX8-era pending
callback, volume-UI, endpoint-replacement, and shutdown evidence. The
asynchronous opt-in setting request remains intentionally untested live.

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

## PA-008B-FIX9 verification

- Removed the timer-driven reconciliation path from the production Core Audio
  worker. The worker performs one initial endpoint resolution/read, then
  resolves and rebinds only after a device/default-endpoint notification.
- Master scalar and mute state after binding are processed from
  `IAudioEndpointVolumeCallback`; the continuous diagnostic heartbeat reports
  cached state and does not perform a volume read.
- Focused audio service tests passed with `dcc64.exe` version 36.0.
- The read-only probe built successfully and a one-second diagnostic run
  completed with `source=initial-read`, successful scalar/mute HRESULTs,
  `callbackRegistrationHr=00000000`, and clean shutdown. No `--set` mode was
  used.
- The main Win64 application built successfully to
  `Win64\Debug\app\PresenterAssistant.exe`.
- `git diff --check` passed.
- Automated tests do not prove live callback delivery or default-device
  rebind. A manual continuous run must still switch the default output device
  and verify `source=endpoint-rebind`, the new endpoint identity, successful
  callback registration, and clean Enter-driven shutdown.

## PA-008B-FIX9-B verification

- Removed the diagnostic heartbeat's fresh endpoint activation, scalar/mute
  reads, default-role resolution, and active-endpoint enumeration.
- The rebuilt diagnostic heartbeat now reports `cached=TRUE`, snapshot
  sequence/state, cached endpoint identity, cached percentage/mute state,
  callback counters, source/event, registration status, and error only.
- Remaining production Core Audio reads are event-scoped:
  `Audio\PACoreAudioService.pas:444` activates the bound endpoint during
  startup or endpoint rebind; lines `454` and `455` register the callback;
  lines `554` and `559` perform the one scalar/mute read for that binding.
  `EnumAudioEndpoints` at line `605` and `GetDefaultAudioEndpoint` at line
  `611` run during initial startup or after a device/default-endpoint
  notification.
- No periodic scalar/mute polling remains in the production service or the
  service diagnostic probe. The separate PA-008A standalone probe retains its
  independent enumeration/read behavior by design.
- Focused audio tests, the diagnostic probe build, and the main Win64
  application build passed with Delphi `dcc64.exe` version 36.0.
- A read-only diagnostic probe run completed successfully and emitted no
  `getScalarHr`, `fresh*`, `roles[...]`, or `active[...]` heartbeat fields.
- `git diff --check` passed. No `--set` mode was executed.

## PA-008B final live verification

The user performed the following read-only live run:

```text
PAAudioServiceProbe.exe --continuous --diagnostics
```

The run verified:

- The initial endpoint read completed successfully.
- Master-volume changes on Speakers generated callback snapshots.
- The default endpoint changed among Speakers, LG ULTRAFINE, and Headset
  during the same process lifetime.
- Endpoint-rebind snapshots were published without restarting the service.
- Subsequent volume changes on Speakers and LG ULTRAFINE were detected through
  callbacks after rebinding.
- Diagnostic heartbeats reported `cached=TRUE` and no longer contained fresh
  scalar/mute reads or periodic endpoint enumeration.
- Enter terminated the probe cleanly with
  `SHUTDOWN_COMPLETE status=success`.

Counter scope observed and confirmed by the implementation:

- `callbackProcessed` tracks the callback sequence for the currently bound
  endpoint callback object. It resets when endpoint rebinding creates and
  registers a new callback object.
- `externalCount` counts callback notifications classified as external
  because their event context differs from the service's own context. The
  value is copied into the rebound snapshot and remains cumulative across
  endpoint changes.

This live evidence verifies callback-driven read-only monitoring and
event-triggered endpoint replacement recovery. It does not verify the
asynchronous `RequestMasterVolume` volume-setting API. That API remains
covered by deterministic request validation only, and no `--set` mode was
used.

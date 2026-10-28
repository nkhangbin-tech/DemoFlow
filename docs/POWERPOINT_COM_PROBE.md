# PowerPoint COM diagnostic probe

`PAPowerPointProbe.exe` is a standalone, read-only diagnostic utility for
PA-006A. It is not the production PowerPoint monitor and is not included in
the main VCL project.

## Build and run

Build it with the installed Delphi 12.3 Win64 compiler:

```powershell
New-Item -ItemType Directory -Path 'E:\Programming\Tool\DemoFlow\Win64\Debug\tools' -Force
& $env:ComSpec /c 'call "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" >nul && cd /d E:\Programming\Tool\DemoFlow && dcc64.exe -B -Q -CC -EWin64\Debug\tools -NUWin64\Debug\tools tools\PAPowerPointProbe.dpr'
```

Run for the default 45 seconds:

```powershell
& 'E:\Programming\Tool\DemoFlow\Win64\Debug\tools\PAPowerPointProbe.exe'
```

An optional duration in seconds is accepted and clamped to 5 through 600:

```powershell
& 'E:\Programming\Tool\DemoFlow\Win64\Debug\tools\PAPowerPointProbe.exe' 60
```

The probe uses `CoInitialize`, `CLSIDFromProgID`, and the Windows
`GetActiveObject` API, followed by an `IDispatch` query. The no-instance case
therefore returns an HRESULT such as `800401E3` instead of raising the
expected `EOleSysError` from the Delphi `GetActiveOleObject` helper. It never
launches or controls PowerPoint. A COM property call can block or fail while
Office is busy; the probe does not claim to provide a hard timeout around such
a call. The returned dispatch is retained as a dispatch variant with an
explicit reference-count transfer before late-bound property and collection
method calls.

## Manual cases

1. Start the probe with PowerPoint not running. Confirm repeated
   `UNAVAILABLE` messages and normal completion.
2. Leave PowerPoint running without a slideshow. Confirm
   `CONNECTED slideshowWindows=0`.
3. Start a harmless slideshow and advance/back up. Confirm separate
   `slideIndex` and `showPosition` values.
4. End the slideshow while PowerPoint remains open. Confirm
   `slideshow_ended` and a zero-window observation.
5. If practical, start another slideshow during the same run and confirm
   `slideshow_started`.
6. If the environment supports multiple slideshow windows, confirm each
   collection index is reported.
7. Close PowerPoint during a run only when safe. Confirm a connection error,
   reattachment attempts, and normal probe completion.
8. Use a custom show where show position can differ from document slide index.

The probe does not inspect slide notes or presentation paths, detect animation
builds, choose an authoritative window, or modify any presentation state.

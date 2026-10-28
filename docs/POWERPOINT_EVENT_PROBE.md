# PowerPoint COM event diagnostic probe

`PAPowerPointEventProbe.exe` is a standalone, read-only PA-007A diagnostic
utility. It attaches only to an existing PowerPoint instance, subscribes to
the verified `EApplication` connection-point events, pumps the STA message
queue, and compares event notifications with later polling observations. It
does not launch, activate, navigate, save, or close PowerPoint.

## Verified type-library source

The declarations are generated from the installed Office 16 type library:

```text
C:\Program Files\Microsoft Office\root\Office16\MSPPT.OLB
```

RAD Studio 12.3's `tlibimp.exe` generated the project-owned units in
`tools\generated`:

- `PowerPoint_TLB.pas`
- `Office_TLB.pas`
- `VBIDE_TLB.pas`

Import command:

```powershell
& 'D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\tlibimp.exe' -P '-DE:\Programming\Tool\DemoFlow\tools\generated' 'C:\Program Files\Microsoft Office\root\Office16\MSPPT.OLB'
```

The generated declarations identify:

- Type library: Microsoft PowerPoint 16.0 Object Library
- Application default interface `_Application`,
  `{91493442-5A91-11CF-8700-00AA0060263B}`
- Application outgoing event interface `EApplication`,
  `{914934C2-5A91-11CF-8700-00AA0060263B}`
- `SlideShowBegin(Wn: SlideShowWindow)`
- `SlideShowNextBuild(Wn: SlideShowWindow)` (DISPID 2012)
- `SlideShowNextSlide(Wn: SlideShowWindow)` (DISPID 2013)
- `SlideShowNextClick(Wn: SlideShowWindow; nEffect: Effect)` (DISPID 2019)
- `SlideShowEnd(Pres: PowerPointPresentation)` (DISPID 2014)

`SlideShowBegin` is DISPID 2011. The probe reports
`POWERPOINT_UNAVAILABLE` once per distinct attachment error while retrying.

The probe uses the generated `TPowerPointApplication` `TOleServer` wrapper.
It calls `ConnectTo` on an existing `_Application` interface obtained with
`GetActiveObject`; the wrapper performs connection-point advise and unadvise.

## Build and run

Build the probe:

```powershell
New-Item -ItemType Directory -Force -Path 'E:\Programming\Tool\DemoFlow\Win64\Debug\event-probe'
& $env:ComSpec /c 'call "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" >nul && cd /d E:\Programming\Tool\DemoFlow && dcc64.exe -B -Q -CC -Utools;tools\generated -Itools;tools\generated -EWin64\Debug\event-probe\ tools\PAPowerPointEventProbe.dpr'
```

Run for the default 45 seconds, or pass a duration from 5 through 600
seconds:

```powershell
& 'E:\Programming\Tool\DemoFlow\Win64\Debug\event-probe\PAPowerPointEventProbe.exe' 45
```

The probe initializes COM as an STA on its console thread and pumps Windows
messages without a busy loop. Event handlers only enqueue a compact event
record. Output formatting and reconciliation polling occur after the callback
returns. Event notifications invalidate the previous observation; they do not
assert that the announced slide or build is already visible.

Output distinguishes:

- `EVENT`
- `RECONCILIATION_REQUESTED`
- `RECONCILIATION_COMPLETED`
- `RECONCILIATION_FAILED`
- `EVENT_SINK_CONNECTED` and `EVENT_SINK_DISCONNECTED`

The event buffer is bounded at 128 records. Overflow is reported in the final
summary and is not treated as an authoritative event count. A failed
reconciliation clears the valid-observation flag; the probe never fabricates a
slide or build number. A returned `CurrentShowPosition` of zero is treated as
unavailable during a transition and reported with
`RECONCILIATION_POSITION_UNAVAILABLE reason=zero`.

## Event timing interpretation

PowerPoint documents `SlideShowNextSlide` as occurring immediately before the
next slide transition and `SlideShowNextBuild` as occurring before the animated
object becomes visible. Therefore the probe records the event first and reads
the later state only after the callback returns. A build event is not treated
as a unique authoritative animation/build cursor.

References:

- [SlideShowNextSlide](https://learn.microsoft.com/en-us/office/vba/api/powerpoint.application.slideshownextslide)
- [SlideShowNextBuild](https://learn.microsoft.com/en-us/office/vba/api/powerpoint.application.slideshownextbuild)

## Manual runtime procedure

1. Open PowerPoint with a harmless test presentation.
2. Start the event probe.
3. Confirm the startup header says
   `Presenter Assistant PowerPoint COM EVENT diagnostic probe`.
4. Start a slideshow and verify `SlideShowBegin`.
5. Advance through multiple click-triggered animation steps on one slide and
   inspect separate `SlideShowNextClick` and `SlideShowNextBuild` events.
6. Advance slides and compare `SlideShowNextSlide` with the subsequent
   reconciliation snapshot.
7. Move backward and forward several times.
8. End the slideshow and verify `SlideShowEnd` and a zero-window observation.
9. Continue until normal probe shutdown and event unsubscription.
10. If safe, close PowerPoint during observation and record sink loss or
   reconciliation failure.
11. Compare event timing with polling; do not treat event counts as state.

Live Office event delivery and timing remain developer runtime evidence. The
deterministic state harness does not prove that PowerPoint emits these events.

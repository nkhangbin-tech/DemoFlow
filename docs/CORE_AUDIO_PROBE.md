# PA-008A Core Audio Diagnostic Probe

## Scope

`PACoreAudioProbe.exe` is a standalone, read-only Windows Core Audio
diagnostic. It does not set endpoint volume, set mute, register notifications,
modify the main application, or control PowerPoint.

Run the executable from:

```text
Win64\Debug\audio-probe\PACoreAudioProbe.exe
```

The diagnostic entry point and the pure test entry point are intentionally
separate:

```text
Win64\Debug\audio-probe\PACoreAudioProbe.exe
Win64\Debug\audio-tests\PACoreAudioProbeTests.exe
```

The `PASS:` lines belong only to `PACoreAudioProbeTests.exe`. To keep a
console window open when launching the diagnostic by double-clicking, pass the
optional `--pause` argument:

```text
Win64\Debug\audio-probe\PACoreAudioProbe.exe --pause
```

When launched from an existing Command Prompt, no pause argument is needed.

## Verified API surface

The MMDevice and endpoint-volume declarations in
`CoreAudio\PACoreAudioApi.pas` were checked against the Windows SDK headers:

- `CLSID_MMDeviceEnumerator`
  `{BCDE0395-E52F-467C-8E3D-C4579291692E}`
- `IMMDeviceEnumerator`
  `{A95664D2-9614-4F35-A746-DE8DB63617E6}`
- `IMMDeviceCollection`
  `{0BD7A1BE-7A1A-44DB-8397-CC5392387B5E}`
- `IMMDevice`
  `{D666063F-1587-4E43-81F1-B948E807363F}`
- `IAudioEndpointVolume`
  `{5CDF2C82-841E-4546-9722-0CF74078229A}`

The declarations use the SDK vtable order for the methods needed by this
probe. `PROPVARIANT`, `IPropertyStore`, `TPropertyKey`, and
`PKEY_Device_FriendlyName` reuse the installed Delphi RTL units
`Winapi.ActiveX`, `Winapi.PropSys`, and `Winapi.Functiondiscovery`.

Authoritative API references:

- [IMMDeviceEnumerator](https://learn.microsoft.com/en-us/windows/win32/api/mmdeviceapi/nn-mmdeviceapi-immdeviceenumerator)
- [GetDefaultAudioEndpoint](https://learn.microsoft.com/en-us/windows/win32/api/mmdeviceapi/nf-mmdeviceapi-immdeviceenumerator-getdefaultaudioendpoint)
- [EnumAudioEndpoints](https://learn.microsoft.com/en-us/windows/win32/api/mmdeviceapi/nf-mmdeviceapi-immdeviceenumerator-enumaudioendpoints)
- [GetMasterVolumeLevelScalar](https://learn.microsoft.com/en-us/windows/win32/api/endpointvolume/nf-endpointvolume-iaudioendpointvolume-getmastervolumelevelscalar)
- [GetMute](https://learn.microsoft.com/en-us/windows/win32/api/endpointvolume/nf-endpointvolume-iaudioendpointvolume-getmute)

The probe calls `EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE)` and
`GetDefaultAudioEndpoint(eRender, eConsole)`. For each endpoint it reads the
ID, state, friendly name, master-volume scalar, and mute state. A display
percentage is only `Round(scalar * 100)`; it is not a claim about perceived
loudness.

## Build

From the repository root, initialize the RAD Studio environment and run:

```powershell
& $env:ComSpec /c 'call "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" >nul && cd /d E:\Programming\Tool\DemoFlow && dcc64.exe -B -Q -CC -UCoreAudio -EWin64\Debug\audio-probe -NUWin64\Debug\audio-probe tools\PACoreAudioProbe.dpr'
```

Pure helper tests:

```powershell
& $env:ComSpec /c 'call "D:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" >nul && cd /d E:\Programming\Tool\DemoFlow && dcc64.exe -B -Q -CC -UCoreAudio -EWin64\Debug\audio-tests -NUWin64\Debug\audio-tests tests\PACoreAudioProbeTests.dpr && Win64\Debug\audio-tests\PACoreAudioProbeTests.exe'
```

## Developer runtime procedure

1. Leave the Windows output device in its normal state.
2. Run `PACoreAudioProbe.exe`.
3. Confirm that active render endpoints are listed.
4. Confirm the default console endpoint identity.
5. Compare the friendly name with Windows Sound settings.
6. Compare mute state and scalar/display output with Windows.
7. Confirm that volume and mute state did not change.
8. If enumeration fails, retain the complete HRESULT output.

The expected diagnostic output begins with `PROBE_START` and ends with
`PROBE_COMPLETE`; it must not contain the unit-test `PASS:` messages.

Compilation proves only that the declarations and probe build. It does not
prove endpoint access on every machine. The PA-001 WMI query returned no rows;
this probe is the direct Core Audio verification required to resolve that
inconclusive result.

## Scope boundary

PA-008B will define the production endpoint service only after developer
runtime review of this probe. PA-009 volume rules and delta mode remain
separate and are not implemented here.

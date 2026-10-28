unit PACoreAudioApi;

interface

uses
  Winapi.ActiveX,
  Winapi.PropKey,
  Winapi.PropSys,
  Winapi.Windows;

const
  CLSID_MMDeviceEnumerator: TGUID =
    '{BCDE0395-E52F-467C-8E3D-C4579291692E}';
  IID_IMMDeviceEnumerator: TGUID =
    '{A95664D2-9614-4F35-A746-DE8DB63617E6}';
  IID_IMMDeviceCollection: TGUID =
    '{0BD7A1BE-7A1A-44DB-8397-CC5392387B5E}';
  IID_IMMDevice: TGUID =
    '{D666063F-1587-4E43-81F1-B948E807363F}';
  IID_IAudioEndpointVolume: TGUID =
    '{5CDF2C82-841E-4546-9722-0CF74078229A}';

  DEVICE_STATE_ACTIVE = $00000001;
  STGM_READ = $00000000;

type
  EDataFlow = (eRender, eCapture, eAll, eDataFlowCount);
  ERole = (eConsole, eMultimedia, eCommunications, eRoleCount);

  IMMDeviceCollection = interface;
  IMMDevice = interface;

  IMMDeviceEnumerator = interface(IUnknown)
    ['{A95664D2-9614-4F35-A746-DE8DB63617E6}']
    function EnumAudioEndpoints(DataFlow: EDataFlow;
      StateMask: DWORD; out Devices: IMMDeviceCollection): HRESULT; stdcall;
    function GetDefaultAudioEndpoint(DataFlow: EDataFlow; Role: ERole;
      out Endpoint: IMMDevice): HRESULT; stdcall;
    function GetDevice(DeviceId: PWideChar;
      out Device: IMMDevice): HRESULT; stdcall;
  end;

  IMMDeviceCollection = interface(IUnknown)
    ['{0BD7A1BE-7A1A-44DB-8397-CC5392387B5E}']
    function GetCount(out DeviceCount: UINT): HRESULT; stdcall;
    function Item(DeviceIndex: UINT;
      out Device: IMMDevice): HRESULT; stdcall;
  end;

  IMMDevice = interface(IUnknown)
    ['{D666063F-1587-4E43-81F1-B948E807363F}']
    function Activate(const InterfaceId: TGUID; ClassContext: DWORD;
      ActivationParameters: PPropVariant;
      out ActivatedInterface: IUnknown): HRESULT; stdcall;
    function OpenPropertyStore(StorageMode: DWORD;
      out Properties: IPropertyStore): HRESULT; stdcall;
    function GetId(out DeviceId: PWideChar): HRESULT; stdcall;
    function GetState(out State: DWORD): HRESULT; stdcall;
  end;

  IAudioEndpointVolume = interface(IUnknown)
    ['{5CDF2C82-841E-4546-9722-0CF74078229A}']
    function RegisterControlChangeNotify(Notify: IUnknown): HRESULT; stdcall;
    function UnregisterControlChangeNotify(Notify: IUnknown): HRESULT; stdcall;
    function GetChannelCount(out ChannelCount: UINT): HRESULT; stdcall;
    function SetMasterVolumeLevel(LevelDB: Single;
      EventContext: PGUID): HRESULT; stdcall;
    function SetMasterVolumeLevelScalar(Level: Single;
      EventContext: PGUID): HRESULT; stdcall;
    function GetMasterVolumeLevel(out LevelDB: Single): HRESULT; stdcall;
    function GetMasterVolumeLevelScalar(out Level: Single): HRESULT; stdcall;
    function SetChannelVolumeLevel(Channel: UINT; LevelDB: Single;
      EventContext: PGUID): HRESULT; stdcall;
    function SetChannelVolumeLevelScalar(Channel: UINT; Level: Single;
      EventContext: PGUID): HRESULT; stdcall;
    function GetChannelVolumeLevel(Channel: UINT;
      out LevelDB: Single): HRESULT; stdcall;
    function GetChannelVolumeLevelScalar(Channel: UINT;
      out Level: Single): HRESULT; stdcall;
    function SetMute(Mute: BOOL; EventContext: PGUID): HRESULT; stdcall;
    function GetMute(out Muted: BOOL): HRESULT; stdcall;
    function GetVolumeStepInfo(out Step, StepCount: UINT): HRESULT; stdcall;
    function VolumeStepUp(EventContext: PGUID): HRESULT; stdcall;
    function VolumeStepDown(EventContext: PGUID): HRESULT; stdcall;
  end;

function DeviceStateName(State: DWORD): string;
function ScalarToDisplayPercent(const Scalar: Single;
  out Percent: Integer): Boolean;

implementation

function DeviceStateName(State: DWORD): string;
begin
  case State of
    DEVICE_STATE_ACTIVE:
      Result := 'active';
    $00000002:
      Result := 'disabled';
    $00000004:
      Result := 'not-present';
    $00000008:
      Result := 'unplugged';
  else
    Result := 'unknown';
  end;
end;

function ScalarToDisplayPercent(const Scalar: Single;
  out Percent: Integer): Boolean;
begin
  Result := (Scalar >= 0.0) and (Scalar <= 1.0);
  if Result then
    Percent := Round(Scalar * 100.0)
  else
    Percent := 0;
end;

end.

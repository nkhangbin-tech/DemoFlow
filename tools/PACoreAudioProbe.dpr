program PACoreAudioProbe;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Winapi.ActiveX,
  Winapi.Functiondiscovery,
  Winapi.PropSys,
  Winapi.Windows,
  PACoreAudioApi in '..\CoreAudio\PACoreAudioApi.pas';

function HResultText(Value: HRESULT): string;
begin
  Result := IntToHex(Cardinal(Value), 8);
end;

function PauseRequested: Boolean;
begin
  Result := SameText(ParamStr(1), '--pause');
end;

procedure PauseForReview;
begin
  if PauseRequested then
  begin
    Writeln('PAUSED Press Enter to close.');
    Readln;
  end;
end;

function ReadFriendlyName(const Device: IMMDevice;
  out FriendlyName: string): Boolean;
var
  Store: IPropertyStore;
  Value: TPropVariant;
  ResultCode: HRESULT;
begin
  FriendlyName := '';
  Result := False;
  Value := Default(TPropVariant);
  ResultCode := Device.OpenPropertyStore(STGM_READ, Store);
  if Failed(ResultCode) then
    Exit;
  try
    ResultCode := Store.GetValue(PKEY_Device_FriendlyName, Value);
    if Succeeded(ResultCode) and (Value.vt = VT_LPWSTR) and
      (Value.pwszVal <> nil) then
    begin
      FriendlyName := Value.pwszVal;
      Result := FriendlyName <> '';
    end;
  finally
    PropVariantClear(Value);
  end;
end;

function ReadEndpointVolume(const Device: IMMDevice;
  out Scalar: Single; out Muted: Boolean): HRESULT;
var
  Unknown: IUnknown;
  Volume: IAudioEndpointVolume;
  MutedValue: BOOL;
begin
  Scalar := 0.0;
  Muted := False;
  Result := Device.Activate(IID_IAudioEndpointVolume, CLSCTX_ALL, nil,
    Unknown);
  if Failed(Result) then
    Exit;
  Result := Unknown.QueryInterface(IID_IAudioEndpointVolume, Volume);
  if Failed(Result) then
    Exit;
  Result := Volume.GetMasterVolumeLevelScalar(Scalar);
  if Failed(Result) then
    Exit;
  Result := Volume.GetMute(MutedValue);
  if Succeeded(Result) then
    Muted := MutedValue <> FALSE;
end;

procedure PrintEndpoint(const Device: IMMDevice;
  Index: Integer; const DefaultId: string; var FailureCount: Integer);
var
  DeviceId: PWideChar;
  DeviceIdText, FriendlyName: string;
  State: DWORD;
  ResultCode: HRESULT;
  Scalar: Single;
  Muted: Boolean;
  DisplayPercent: Integer;
  FormatSettings: TFormatSettings;
begin
  FormatSettings := TFormatSettings.Create('en-US');
  FormatSettings.DecimalSeparator := '.';
  DeviceId := nil;
  DeviceIdText := '';
  ResultCode := Device.GetId(DeviceId);
  if Succeeded(ResultCode) and (DeviceId <> nil) then
  begin
    DeviceIdText := DeviceId;
    CoTaskMemFree(DeviceId);
  end
  else
  begin
    Inc(FailureCount);
    Writeln('  ID UNAVAILABLE hresult=', HResultText(ResultCode));
  end;

  Writeln('ENDPOINT index=', Index);
  if DeviceIdText <> '' then
    Writeln('  ID=', DeviceIdText)
  else
    Writeln('  ID=UNAVAILABLE');

  ResultCode := Device.GetState(State);
  if Succeeded(ResultCode) then
    Writeln('  STATE=', DeviceStateName(State))
  else
  begin
    Inc(FailureCount);
    Writeln('  STATE UNAVAILABLE hresult=', HResultText(ResultCode));
  end;

  Writeln('  IS_DEFAULT_CONSOLE=',
    BoolToStr((DeviceIdText <> '') and (DeviceIdText = DefaultId), True));

  if ReadFriendlyName(Device, FriendlyName) then
    Writeln('  FRIENDLY_NAME=', FriendlyName)
  else
  begin
    Inc(FailureCount);
    Writeln('  FRIENDLY_NAME=UNAVAILABLE');
  end;

  ResultCode := ReadEndpointVolume(Device, Scalar, Muted);
  if Failed(ResultCode) then
  begin
    Inc(FailureCount);
    Writeln('  MASTER_VOLUME_SCALAR=UNAVAILABLE hresult=',
      HResultText(ResultCode));
    Writeln('  MUTED=UNAVAILABLE');
  end
  else if not ScalarToDisplayPercent(Scalar, DisplayPercent) then
  begin
    Inc(FailureCount);
    Writeln('  MASTER_VOLUME_SCALAR=UNAVAILABLE reason=out-of-range');
    Writeln('  MUTED=', BoolToStr(Muted, True));
  end
  else
  begin
    Writeln('  MASTER_VOLUME_SCALAR=',
      FormatFloat('0.000', Scalar, FormatSettings));
    Writeln('  MASTER_VOLUME_DISPLAY_PERCENT=', DisplayPercent);
    Writeln('  MUTED=', BoolToStr(Muted, True));
  end;
end;

var
  ComInitialized: Boolean;
  ResultCode: HRESULT;
  Enumerator: IMMDeviceEnumerator;
  Collection: IMMDeviceCollection;
  DefaultDevice: IMMDevice;
  Device: IMMDevice;
  DefaultIdPointer: PWideChar;
  DefaultId: string;
  Count, Index, FailureCount: Integer;
  DeviceCount: UINT;
begin
  ComInitialized := False;
  FailureCount := 0;
  DefaultId := '';
  Writeln('PROBE_START name=PACoreAudioProbe');
  Writeln('Presenter Assistant Windows Core Audio diagnostic probe');
  Writeln('Read-only diagnostic; this utility will not change volume or mute state.');
  try
    try
      ResultCode := CoInitializeEx(nil, COINIT_APARTMENTTHREADED);
      if Failed(ResultCode) then
      begin
        Writeln('COM_INITIALIZATION_FAILED hresult=', HResultText(ResultCode));
        Writeln('PROBE_COMPLETE status=failure');
        ExitCode := 1;
        Exit;
      end;
      ComInitialized := True;
      Writeln('COM_INITIALIZED');

      ResultCode := CoCreateInstance(CLSID_MMDeviceEnumerator, nil,
        CLSCTX_INPROC_SERVER, IID_IMMDeviceEnumerator, Enumerator);
      if Failed(ResultCode) then
      begin
        Writeln('ENUMERATOR_UNAVAILABLE hresult=', HResultText(ResultCode));
        Inc(FailureCount);
      end
      else
      begin
        DefaultIdPointer := nil;
        ResultCode := Enumerator.GetDefaultAudioEndpoint(eRender, eConsole,
          DefaultDevice);
        if Succeeded(ResultCode) and
          Succeeded(DefaultDevice.GetId(DefaultIdPointer)) and
          (DefaultIdPointer <> nil) then
        begin
          DefaultId := DefaultIdPointer;
          CoTaskMemFree(DefaultIdPointer);
          Writeln('DEFAULT_CONSOLE_ENDPOINT=', DefaultId);
        end
        else
        begin
          DefaultId := '';
          Inc(FailureCount);
          Writeln('DEFAULT_CONSOLE_ENDPOINT=UNAVAILABLE hresult=',
            HResultText(ResultCode));
        end;

        ResultCode := Enumerator.EnumAudioEndpoints(eRender,
          DEVICE_STATE_ACTIVE, Collection);
        if Failed(ResultCode) then
        begin
          Inc(FailureCount);
          Writeln('ENDPOINT_ENUMERATION_FAILED hresult=', HResultText(ResultCode));
        end
        else if Failed(Collection.GetCount(DeviceCount)) then
        begin
          Inc(FailureCount);
          Writeln('ENDPOINT_COUNT=UNAVAILABLE');
        end
        else
        begin
          Count := DeviceCount;
          Writeln('ENDPOINT_COUNT=', Count);
          if Count = 0 then
            Writeln('UNAVAILABLE no active render endpoints');
          for Index := 0 to Count - 1 do
          begin
            Device := nil;
            ResultCode := Collection.Item(Index, Device);
            if Failed(ResultCode) then
            begin
              Inc(FailureCount);
              Writeln('ENDPOINT index=', Index,
                ' ERROR hresult=', HResultText(ResultCode));
            end
            else
              PrintEndpoint(Device, Index, DefaultId, FailureCount);
          end;
        end;
      end;
      Writeln('SUMMARY comInitialized=', BoolToStr(ComInitialized, True),
        ' endpointFailures=', FailureCount,
        ' defaultFound=', BoolToStr(DefaultId <> '', True));
      ExitCode := Ord(FailureCount > 0);
    except
      on E: Exception do
      begin
        Writeln('ERROR ', E.ClassName, ': ', E.Message);
        ExitCode := 1;
      end;
    end;
    if ExitCode = 0 then
      Writeln('PROBE_COMPLETE status=success')
    else
      Writeln('PROBE_COMPLETE status=failure');
  finally
    if ComInitialized then
      CoUninitialize;
    PauseForReview;
  end;
  readln;
end.

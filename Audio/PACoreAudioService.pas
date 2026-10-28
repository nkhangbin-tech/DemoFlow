unit PACoreAudioService;

interface

uses
  PACoreAudioApi,
  System.Classes,
  System.SyncObjs,
  System.SysUtils,
  System.Variants,
  Winapi.ActiveX,
  Winapi.Functiondiscovery,
  Winapi.PropKey,
  Winapi.PropSys,
  Winapi.Windows;

type
  TAudioServiceState = (
    assStarting,
    assAvailable,
    assNoDefaultEndpoint,
    assUnavailable,
    assFaulted,
    assStopping,
    assStopped
  );

  TAudioVolumeRequestStatus = (
    avrsPending,
    avrsSucceeded,
    avrsFailed,
    avrsRejected
  );

  TAudioServiceSnapshot = record
    State: TAudioServiceState;
    ObservedAt: TDateTime;
    Sequence: UInt64;
    ActiveEndpointCount: Integer;
    HasDefaultEndpoint: Boolean;
    EndpointId: string;
    FriendlyName: string;
    DeviceState: DWORD;
    HasVolume: Boolean;
    Scalar: Single;
    DisplayPercent: Integer;
    Muted: Boolean;
    LastVolumeChangeWasOwn: Boolean;
    OwnVolumeChangeCount: UInt64;
    ExternalVolumeChangeCount: UInt64;
    LastEventName: string;
    LastObservationSource: string;
    CallbackRegistrationResult: HRESULT;
    ReconcileScalarResult: HRESULT;
    ReconcileMuteResult: HRESULT;
    FreshEndpointId: string;
    FreshScalarResult: HRESULT;
    FreshMuteResult: HRESULT;
    FreshHasVolume: Boolean;
    FreshScalar: Single;
    FreshMuted: Boolean;
    DiagnosticReport: string;
    CallbackReceivedCount: UInt64;
    CallbackProcessedCount: UInt64;
    HasLatestCallback: Boolean;
    LatestCallbackScalar: Single;
    LatestCallbackMuted: Boolean;
    ErrorText: string;
  end;

  TAudioVolumeRequestResult = record
    RequestId: UInt64;
    Status: TAudioVolumeRequestStatus;
    RequestedPercent: Integer;
    AppliedPercent: Integer;
    ErrorText: string;
    CompletedAt: TDateTime;
  end;

  TAudioVolumeRequest = record
    RequestId: UInt64;
    RequestedPercent: Integer;
  end;

  TAudioService = class
  private
    type
      TWorker = class(TThread)
      private
        FOwner: TAudioService;
        FEnumerator: IMMDeviceEnumerator;
        FEndpoint: IMMDevice;
        FVolume: IAudioEndpointVolume;
        FNotificationClient: IMMNotificationClient;
        FEndpointCallback: IAudioEndpointVolumeCallback;
        FNotificationObject: TObject;
        FEndpointCallbackObject: TObject;
        FCallbackRegistrationResult: HRESULT;
        FFreshEndpointId: string;
        FFreshScalarResult: HRESULT;
        FFreshMuteResult: HRESULT;
        FFreshHasVolume: Boolean;
        FFreshScalar: Single;
        FFreshMuted: Boolean;
        FDiagnosticReport: string;
            FCallbackUnregisterResult: HRESULT;
        FEndpointGeneration: UInt64;
        procedure Reconcile;
        function ProcessDeviceNotification: Boolean;
        procedure ProcessRequests;
        procedure ProcessVolumeNotification;
        procedure BindEndpoint(const Endpoint: IMMDevice);
        procedure UnbindEndpoint;
        procedure PublishBase(State: TAudioServiceState;
          const ErrorText: string);
        procedure PublishEndpoint(const Source: string);
        procedure PumpMessages;
        procedure ReleaseComObjects;
      protected
        procedure Execute; override;
      public
        constructor Create(AOwner: TAudioService);
      end;
    private
    FDiagnostics: Boolean;
    FLock: TObject;
    FWakeEvent: TEvent;
    FStoppedEvent: TEvent;
    FStopRequested: Boolean;
    FWorker: TWorker;
    FLatest: TAudioServiceSnapshot;
    FHasLatest: Boolean;
    FNextRequestId: UInt64;
    FEventContext: TGUID;
    FRequests: TArray<TAudioVolumeRequestResult>;
    FQueue: TArray<TAudioVolumeRequest>;
    procedure Publish(const Snapshot: TAudioServiceSnapshot);
    procedure SetRequestResult(RequestId: UInt64;
      Status: TAudioVolumeRequestStatus; AppliedPercent: Integer;
      const ErrorText: string);
    procedure RejectQueuedRequests(const ErrorText: string);
    function IsStopping: Boolean;
    function EnqueueRequest(const Request: TAudioVolumeRequest): Boolean;
  public
    constructor Create(EnableDiagnostics: Boolean = False);
    destructor Destroy; override;
    procedure Start;
    function Stop(TimeoutMs: Cardinal = 2000): Boolean;
    function TryGetLatest(out Snapshot: TAudioServiceSnapshot): Boolean;
    function RequestMasterVolume(Percent: Integer; out RequestId: UInt64;
      out ErrorText: string): Boolean;
    function TryGetRequestResult(RequestId: UInt64;
      out ResultValue: TAudioVolumeRequestResult): Boolean;
    property DiagnosticsEnabled: Boolean read FDiagnostics;
  end;

function AudioServiceStateName(State: TAudioServiceState): string;
function AudioVolumeRequestStatusName(
  Status: TAudioVolumeRequestStatus): string;
function IsValidVolumePercent(Percent: Integer): Boolean;
function VolumePercentToScalar(Percent: Integer; out Scalar: Single): Boolean;
function IsOwnAudioEventContext(const Context, OwnContext: TGUID): Boolean;
function AudioVolumeValuesMeaningfullyDifferent(
  Previous, Current: TAudioServiceSnapshot): Boolean;
function AudioSnapshotsMeaningfullyDifferent(
  const Previous, Current: TAudioServiceSnapshot): Boolean;

implementation

uses
  System.DateUtils;

const
  CLSCTX_INPROC_SERVER = 1;
  E_NOTFOUND_HRESULT = HRESULT($80070490);
  AUDCLNT_E_DEVICE_INVALIDATED_HRESULT = HRESULT($88890004);
type
  TAudioEndpointCallback = class(TInterfacedObject,
    IAudioEndpointVolumeCallback)
  private
    FSignal: TEvent;
    FPending: Boolean;
    FContext: TGUID;
    FScalar: Single;
    FMuted: Boolean;
    FReceivedCount: UInt64;
  public
    constructor Create(ASignal: TEvent);
    function OnNotify(NotificationData: PAudioVolumeNotificationData): HRESULT;
      stdcall;
    procedure Read(out Pending: Boolean; out Context: TGUID;
      out Scalar: Single; out Muted: Boolean; out ReceivedCount: UInt64);
  end;

  TAudioNotificationClient = class(TInterfacedObject,
    IMMNotificationClient)
  private
    FSignal: TEvent;
    FPending: Boolean;
  public
    constructor Create(ASignal: TEvent);
    function OnDeviceStateChanged(DeviceId: PWideChar;
      NewState: DWORD): HRESULT; stdcall;
    function OnDeviceAdded(DeviceId: PWideChar): HRESULT; stdcall;
    function OnDeviceRemoved(DeviceId: PWideChar): HRESULT; stdcall;
    function OnDefaultDeviceChanged(DataFlow: EDataFlow; Role: ERole;
      DefaultDeviceId: PWideChar): HRESULT; stdcall;
    function OnPropertyValueChanged(DeviceId: PWideChar;
      const Key: TPropertyKey): HRESULT; stdcall;
    procedure Read(out Pending: Boolean);
  end;

function AudioServiceStateName(State: TAudioServiceState): string;
begin
  case State of
    assStarting: Result := 'starting';
    assAvailable: Result := 'available';
    assNoDefaultEndpoint: Result := 'no-default-endpoint';
    assUnavailable: Result := 'temporarily-unavailable';
    assFaulted: Result := 'faulted';
    assStopping: Result := 'stopping';
  else
    Result := 'stopped';
  end;
end;

function AudioVolumeRequestStatusName(
  Status: TAudioVolumeRequestStatus): string;
begin
  case Status of
    avrsPending: Result := 'pending';
    avrsSucceeded: Result := 'succeeded';
    avrsFailed: Result := 'failed';
  else
    Result := 'rejected';
  end;
end;

function IsValidVolumePercent(Percent: Integer): Boolean;
begin
  Result := (Percent >= 0) and (Percent <= 100);
end;

function VolumePercentToScalar(Percent: Integer; out Scalar: Single): Boolean;
begin
  Result := IsValidVolumePercent(Percent);
  if Result then
    Scalar := Percent / 100.0
  else
    Scalar := 0.0;
end;

function IsOwnAudioEventContext(const Context, OwnContext: TGUID): Boolean;
begin
  Result := IsEqualGUID(Context, OwnContext);
end;

function AudioVolumeValuesMeaningfullyDifferent(
  Previous, Current: TAudioServiceSnapshot): Boolean;
const
  SCALAR_EPSILON = 0.0005;
begin
  Result :=
    (Previous.HasVolume <> Current.HasVolume) or
    (Previous.Muted <> Current.Muted) or
    (Previous.HasVolume and Current.HasVolume and
      (Abs(Previous.Scalar - Current.Scalar) >= SCALAR_EPSILON));
end;

function AudioSnapshotsMeaningfullyDifferent(
  const Previous, Current: TAudioServiceSnapshot): Boolean;
begin
  Result :=
    (Previous.State <> Current.State) or
    (Previous.ActiveEndpointCount <> Current.ActiveEndpointCount) or
    (Previous.HasDefaultEndpoint <> Current.HasDefaultEndpoint) or
    (Previous.EndpointId <> Current.EndpointId) or
    (Previous.FriendlyName <> Current.FriendlyName) or
    (Previous.DeviceState <> Current.DeviceState) or
    (Previous.HasVolume <> Current.HasVolume) or
    AudioVolumeValuesMeaningfullyDifferent(Previous, Current) or
    (Previous.DisplayPercent <> Current.DisplayPercent) or
    (Previous.Muted <> Current.Muted) or
    (Previous.LastVolumeChangeWasOwn <> Current.LastVolumeChangeWasOwn) or
    (Previous.OwnVolumeChangeCount <> Current.OwnVolumeChangeCount) or
    (Previous.ExternalVolumeChangeCount <> Current.ExternalVolumeChangeCount) or
    (Previous.LastEventName <> Current.LastEventName) or
    (Previous.LastObservationSource <> Current.LastObservationSource) or
    (Previous.CallbackRegistrationResult <>
      Current.CallbackRegistrationResult) or
    (Previous.ReconcileScalarResult <> Current.ReconcileScalarResult) or
    (Previous.ReconcileMuteResult <> Current.ReconcileMuteResult) or
    (Previous.FreshEndpointId <> Current.FreshEndpointId) or
    (Previous.FreshScalarResult <> Current.FreshScalarResult) or
    (Previous.FreshMuteResult <> Current.FreshMuteResult) or
    (Previous.FreshHasVolume <> Current.FreshHasVolume) or
    (Previous.FreshHasVolume and Current.FreshHasVolume and
      ((Abs(Previous.FreshScalar - Current.FreshScalar) >= 0.0005) or
       (Previous.FreshMuted <> Current.FreshMuted))) or
    (Previous.DiagnosticReport <> Current.DiagnosticReport) or
    (Previous.CallbackReceivedCount <> Current.CallbackReceivedCount) or
    (Previous.CallbackProcessedCount <> Current.CallbackProcessedCount) or
    (Previous.HasLatestCallback <> Current.HasLatestCallback) or
    (Previous.HasLatestCallback and
      ((Abs(Previous.LatestCallbackScalar - Current.LatestCallbackScalar) >=
        0.0005) or
       (Previous.LatestCallbackMuted <> Current.LatestCallbackMuted))) or
    (Previous.ErrorText <> Current.ErrorText);
end;

constructor TAudioEndpointCallback.Create(ASignal: TEvent);
begin
  inherited Create;
  FSignal := ASignal;
  FPending := False;
  FContext := GUID_NULL;
  FScalar := 0.0;
  FMuted := False;
  FReceivedCount := 0;
end;

function TAudioEndpointCallback.OnNotify(
  NotificationData: PAudioVolumeNotificationData): HRESULT;
begin
  if NotificationData <> nil then
  begin
    FContext := NotificationData^.Callback;
    FScalar := NotificationData^.MasterVolume;
    FMuted := NotificationData^.Muted;
    FPending := True;
    Inc(FReceivedCount);
  end;
  FSignal.SetEvent;
  Result := S_OK;
end;

procedure TAudioEndpointCallback.Read(out Pending: Boolean; out Context: TGUID;
  out Scalar: Single; out Muted: Boolean; out ReceivedCount: UInt64);
begin
  Pending := FPending;
  Context := FContext;
  Scalar := FScalar;
  Muted := FMuted;
  ReceivedCount := FReceivedCount;
  FPending := False;
end;

constructor TAudioNotificationClient.Create(ASignal: TEvent);
begin
  inherited Create;
  FSignal := ASignal;
  FPending := False;
end;

function TAudioNotificationClient.OnDeviceStateChanged(DeviceId: PWideChar;
  NewState: DWORD): HRESULT;
begin
  FPending := True;
  FSignal.SetEvent;
  Result := S_OK;
end;

function TAudioNotificationClient.OnDeviceAdded(DeviceId: PWideChar): HRESULT;
begin
  FPending := True;
  FSignal.SetEvent;
  Result := S_OK;
end;

function TAudioNotificationClient.OnDeviceRemoved(
  DeviceId: PWideChar): HRESULT;
begin
  FPending := True;
  FSignal.SetEvent;
  Result := S_OK;
end;

function TAudioNotificationClient.OnDefaultDeviceChanged(DataFlow: EDataFlow;
  Role: ERole; DefaultDeviceId: PWideChar): HRESULT;
begin
  if (DataFlow = eRender) and (Role = eConsole) then
  begin
    FPending := True;
    FSignal.SetEvent;
  end;
  Result := S_OK;
end;

function TAudioNotificationClient.OnPropertyValueChanged(DeviceId: PWideChar;
  const Key: TPropertyKey): HRESULT;
begin
  FPending := True;
  FSignal.SetEvent;
  Result := S_OK;
end;

procedure TAudioNotificationClient.Read(out Pending: Boolean);
begin
  Pending := FPending;
  FPending := False;
end;

constructor TAudioService.TWorker.Create(AOwner: TAudioService);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FOwner := AOwner;
end;

procedure TAudioService.TWorker.PublishBase(State: TAudioServiceState;
  const ErrorText: string);
var
  Snapshot: TAudioServiceSnapshot;
begin
  Snapshot := Default(TAudioServiceSnapshot);
  Snapshot.State := State;
  Snapshot.ObservedAt := Now;
  Snapshot.ErrorText := ErrorText;
  FOwner.Publish(Snapshot);
end;

procedure TAudioService.TWorker.UnbindEndpoint;
begin
  if FVolume <> nil then
  begin
    if FEndpointCallback <> nil then
      FCallbackUnregisterResult :=
        FVolume.UnregisterControlChangeNotify(FEndpointCallback);
    FVolume := nil;
  end;
  FEndpointCallback := nil;
  FEndpointCallbackObject := nil;
  FEndpoint := nil;
end;

procedure TAudioService.TWorker.BindEndpoint(const Endpoint: IMMDevice);
var
  Unknown: IUnknown;
  Callback: TAudioEndpointCallback;
  ResultCode: HRESULT;
begin
  UnbindEndpoint;
  FEndpoint := Endpoint;
  ResultCode := FEndpoint.Activate(IID_IAudioEndpointVolume,
    CLSCTX_INPROC_SERVER, nil, Unknown);
  if Failed(ResultCode) then
    raise Exception.CreateFmt('endpoint volume activation failed: %s',
      [IntToHex(Cardinal(ResultCode), 8)]);
  if Failed(Unknown.QueryInterface(IID_IAudioEndpointVolume, FVolume)) then
    raise Exception.Create('endpoint volume interface unavailable');
  Callback := TAudioEndpointCallback.Create(FOwner.FWakeEvent);
  FEndpointCallbackObject := Callback;
  FEndpointCallback := Callback;
  ResultCode := FVolume.RegisterControlChangeNotify(
    FEndpointCallback);
  FCallbackRegistrationResult := ResultCode;
  if Failed(ResultCode) then
  begin
    UnbindEndpoint;
    raise Exception.CreateFmt('endpoint callback registration failed: %s',
      [IntToHex(Cardinal(ResultCode), 8)]);
  end;
  Inc(FEndpointGeneration);
end;

procedure TAudioService.TWorker.PublishEndpoint(const Source: string);
var
  DeviceId: PWideChar;
  State: DWORD;
  Properties: IPropertyStore;
  Value: TPropVariant;
  FriendlyName: string;
  Scalar: Single;
  Muted: BOOL;
  Snapshot: TAudioServiceSnapshot;
  Prior: TAudioServiceSnapshot;
  ResultCode: HRESULT;
begin
  Snapshot := Default(TAudioServiceSnapshot);
  if FOwner.TryGetLatest(Prior) then
  begin
    Snapshot.OwnVolumeChangeCount := Prior.OwnVolumeChangeCount;
    Snapshot.ExternalVolumeChangeCount := Prior.ExternalVolumeChangeCount;
    Snapshot.LastVolumeChangeWasOwn := Prior.LastVolumeChangeWasOwn;
    Snapshot.LastEventName := Prior.LastEventName;
    Snapshot.LastObservationSource := Prior.LastObservationSource;
    Snapshot.CallbackRegistrationResult := Prior.CallbackRegistrationResult;
    Snapshot.ReconcileScalarResult := Prior.ReconcileScalarResult;
    Snapshot.ReconcileMuteResult := Prior.ReconcileMuteResult;
    Snapshot.FreshEndpointId := Prior.FreshEndpointId;
    Snapshot.FreshScalarResult := Prior.FreshScalarResult;
    Snapshot.FreshMuteResult := Prior.FreshMuteResult;
    Snapshot.FreshHasVolume := Prior.FreshHasVolume;
    Snapshot.FreshScalar := Prior.FreshScalar;
    Snapshot.FreshMuted := Prior.FreshMuted;
    Snapshot.DiagnosticReport := Prior.DiagnosticReport;
    Snapshot.CallbackReceivedCount := Prior.CallbackReceivedCount;
    Snapshot.CallbackProcessedCount := Prior.CallbackProcessedCount;
    Snapshot.HasLatestCallback := Prior.HasLatestCallback;
    Snapshot.LatestCallbackScalar := Prior.LatestCallbackScalar;
    Snapshot.LatestCallbackMuted := Prior.LatestCallbackMuted;
  end;
  Snapshot.State := assUnavailable;
  Snapshot.ObservedAt := Now;
  Snapshot.CallbackRegistrationResult := FCallbackRegistrationResult;
  Snapshot.FreshEndpointId := FFreshEndpointId;
  Snapshot.FreshScalarResult := FFreshScalarResult;
  Snapshot.FreshMuteResult := FFreshMuteResult;
  Snapshot.FreshHasVolume := FFreshHasVolume;
  Snapshot.FreshScalar := FFreshScalar;
  Snapshot.FreshMuted := FFreshMuted;
  Snapshot.DiagnosticReport := FDiagnosticReport;
  Snapshot.HasDefaultEndpoint := FEndpoint <> nil;
  if FEndpoint = nil then
  begin
    Snapshot.ErrorText := 'default endpoint is unavailable';
    FOwner.Publish(Snapshot);
    Exit;
  end;
  DeviceId := nil;
  ResultCode := FEndpoint.GetId(DeviceId);
  if Succeeded(ResultCode) then
  begin
    Snapshot.EndpointId := DeviceId;
    CoTaskMemFree(DeviceId);
  end
  else
    Snapshot.ErrorText := 'endpoint ID unavailable';
  State := 0;
  if Succeeded(FEndpoint.GetState(State)) then
  begin
    Snapshot.DeviceState := State;
    Snapshot.FriendlyName := '';
  end;
  if Snapshot.DeviceState = 0 then
    Snapshot.ErrorText := 'endpoint state unavailable';
  Properties := nil;
  if Succeeded(FEndpoint.OpenPropertyStore(STGM_READ, Properties)) then
  begin
    Value := Default(TPropVariant);
    try
      if Succeeded(Properties.GetValue(PKEY_Device_FriendlyName, Value)) and
        (Value.vt = VT_LPWSTR) and (Value.pwszVal <> nil) then
        FriendlyName := Value.pwszVal;
      Snapshot.FriendlyName := FriendlyName;
    finally
      PropVariantClear(Value);
    end;
  end;
  if Snapshot.FriendlyName = '' then
    Snapshot.ErrorText := 'friendly name unavailable';
  Scalar := 0.0;
  Muted := False;
  ResultCode := FVolume.GetMasterVolumeLevelScalar(Scalar);
  Snapshot.ReconcileScalarResult := ResultCode;
  if Succeeded(ResultCode) and
    ScalarToDisplayPercent(Scalar, Snapshot.DisplayPercent) then
  begin
    Snapshot.ReconcileMuteResult := FVolume.GetMute(Muted);
    Snapshot.HasVolume := Succeeded(Snapshot.ReconcileMuteResult);
    Snapshot.Scalar := Scalar;
    Snapshot.Muted := Muted;
    Snapshot.State := assAvailable;
    Snapshot.LastObservationSource := Source;
    if Source <> 'initial-read' then
      Snapshot.LastEventName := Source + '-volume-read';
  end
  else
    Snapshot.ErrorText := 'endpoint volume is unavailable';
  FOwner.Publish(Snapshot);
end;

procedure TAudioService.TWorker.Reconcile;
var
  Collection: IMMDeviceCollection;
  DefaultEndpoint: IMMDevice;
  Count: UINT;
  ResultCode: HRESULT;
  Snapshot: TAudioServiceSnapshot;
  CurrentId, DefaultId: PWideChar;
  CurrentIdText, DefaultIdText: string;
  Notification: TAudioNotificationClient;
  Rebound: Boolean;
begin
  if FEnumerator = nil then
  begin
    ResultCode := CoCreateInstance(CLSID_MMDeviceEnumerator, nil,
      CLSCTX_INPROC_SERVER, IID_IMMDeviceEnumerator, FEnumerator);
    if Failed(ResultCode) then
    begin
      PublishBase(assUnavailable, 'audio endpoint enumerator unavailable: ' +
        IntToHex(Cardinal(ResultCode), 8));
      Exit;
    end;
    Notification := TAudioNotificationClient.Create(FOwner.FWakeEvent);
    FNotificationClient := Notification;
    ResultCode := FEnumerator.RegisterEndpointNotificationCallback(
      FNotificationClient);
    if Failed(ResultCode) then
      raise Exception.CreateFmt('endpoint notification registration failed: %s',
        [IntToHex(Cardinal(ResultCode), 8)]);
    FNotificationObject := Notification;
  end;
  Collection := nil;
  ResultCode := FEnumerator.EnumAudioEndpoints(eRender,
    DEVICE_STATE_ACTIVE, Collection);
  if Succeeded(ResultCode) and Succeeded(Collection.GetCount(Count)) then
  else
    Count := 0;
  DefaultEndpoint := nil;
  ResultCode := FEnumerator.GetDefaultAudioEndpoint(eRender, eConsole,
    DefaultEndpoint);
  if Failed(ResultCode) then
  begin
    UnbindEndpoint;
    Snapshot := Default(TAudioServiceSnapshot);
    if (ResultCode = E_NOTFOUND_HRESULT) or
      (ResultCode = AUDCLNT_E_DEVICE_INVALIDATED_HRESULT) then
      Snapshot.State := assNoDefaultEndpoint
    else
      Snapshot.State := assUnavailable;
    Snapshot.ObservedAt := Now;
    Snapshot.ActiveEndpointCount := Count;
    Snapshot.ErrorText := 'default endpoint query failed: ' +
      IntToHex(Cardinal(ResultCode), 8);
    FOwner.Publish(Snapshot);
    Exit;
  end;
  CurrentIdText := '';
  CurrentId := nil;
  if FEndpoint <> nil then
    if Succeeded(FEndpoint.GetId(CurrentId)) then
    begin
      CurrentIdText := CurrentId;
      CoTaskMemFree(CurrentId);
    end;
  DefaultIdText := '';
  DefaultId := nil;
  if Succeeded(DefaultEndpoint.GetId(DefaultId)) then
  begin
    DefaultIdText := DefaultId;
    CoTaskMemFree(DefaultId);
  end;
  Rebound := CurrentIdText <> DefaultIdText;
  if Rebound then
    BindEndpoint(DefaultEndpoint);
  if not Rebound then
    Exit;
  if Rebound and (FEndpointGeneration > 1) then
    PublishEndpoint('endpoint-rebind')
  else
    PublishEndpoint('initial-read');
  if FOwner.TryGetLatest(Snapshot) then
  begin
    Snapshot.ActiveEndpointCount := Count;
    FOwner.Publish(Snapshot);
  end;
end;

function TAudioService.TWorker.ProcessDeviceNotification: Boolean;
var
  Client: TAudioNotificationClient;
  Pending: Boolean;
begin
  Result := False;
  if FNotificationObject = nil then
    Exit;
  Client := FNotificationObject as TAudioNotificationClient;
  Client.Read(Pending);
  Result := Pending;
end;

procedure TAudioService.TWorker.ProcessVolumeNotification;
var
  Callback: TAudioEndpointCallback;
  Pending: Boolean;
  Context: TGUID;
  Scalar: Single;
  Muted: Boolean;
  ReceivedCount: UInt64;
  Snapshot: TAudioServiceSnapshot;
begin
  if FEndpointCallbackObject = nil then
    Exit;
  Callback := FEndpointCallbackObject as TAudioEndpointCallback;
  Callback.Read(Pending, Context, Scalar, Muted, ReceivedCount);
  if not Pending then
    Exit;
  if FOwner.TryGetLatest(Snapshot) then
  begin
    Snapshot.LastVolumeChangeWasOwn :=
      IsOwnAudioEventContext(Context, FOwner.FEventContext);
    if Snapshot.LastVolumeChangeWasOwn then
      Inc(Snapshot.OwnVolumeChangeCount)
    else
      Inc(Snapshot.ExternalVolumeChangeCount);
    Snapshot.LastEventName := 'endpoint-volume-changed';
    Snapshot.ObservedAt := Now;
    if ScalarToDisplayPercent(Scalar, Snapshot.DisplayPercent) then
    begin
      Snapshot.HasVolume := True;
      Snapshot.Scalar := Scalar;
      Snapshot.Muted := Muted;
      Snapshot.ErrorText := '';
    end
    else
    begin
      Snapshot.HasVolume := False;
      Snapshot.ErrorText := 'volume notification contained an invalid scalar';
    end;
    Snapshot.LastObservationSource := 'callback';
    Snapshot.CallbackReceivedCount := ReceivedCount;
    Snapshot.CallbackProcessedCount := ReceivedCount;
    Snapshot.HasLatestCallback := True;
    Snapshot.LatestCallbackScalar := Scalar;
    Snapshot.LatestCallbackMuted := Muted;
    FOwner.Publish(Snapshot);
  end;
end;

procedure TAudioService.TWorker.ProcessRequests;
var
  Requests: TArray<TAudioVolumeRequest>;
  Request: TAudioVolumeRequest;
  Scalar: Single;
  ResultCode: HRESULT;
begin
  TMonitor.Enter(FOwner.FLock);
  try
    Requests := Copy(FOwner.FQueue);
    SetLength(FOwner.FQueue, 0);
  finally
    TMonitor.Exit(FOwner.FLock);
  end;
  for Request in Requests do
  begin
    if FVolume = nil then
    begin
      FOwner.SetRequestResult(Request.RequestId, avrsFailed, 0,
        'no default console endpoint is available');
      Continue;
    end;
    if not VolumePercentToScalar(Request.RequestedPercent, Scalar) then
    begin
      FOwner.SetRequestResult(Request.RequestId, avrsRejected, 0,
        'volume percentage must be an integer from 0 to 100');
      Continue;
    end;
    ResultCode := FVolume.SetMasterVolumeLevelScalar(Scalar,
      @FOwner.FEventContext);
    if Failed(ResultCode) then
      FOwner.SetRequestResult(Request.RequestId, avrsFailed, 0,
        'Core Audio volume request failed: ' +
        IntToHex(Cardinal(ResultCode), 8))
    else
      FOwner.SetRequestResult(Request.RequestId, avrsSucceeded,
        Request.RequestedPercent, '');
  end;
end;

procedure TAudioService.TWorker.PumpMessages;
var
  MessageData: TMsg;
begin
  while PeekMessage(MessageData, 0, 0, 0, PM_REMOVE) do
  begin
    TranslateMessage(MessageData);
    DispatchMessage(MessageData);
  end;
end;

procedure TAudioService.TWorker.ReleaseComObjects;
begin
  if FEnumerator <> nil then
    FEnumerator.UnregisterEndpointNotificationCallback(FNotificationClient);
  UnbindEndpoint;
  FNotificationClient := nil;
  FNotificationObject := nil;
  FEnumerator := nil;
end;

procedure TAudioService.TWorker.Execute;
var
  ComResult: HRESULT;
  ComInitialized: Boolean;
begin
  ComInitialized := False;
  try
    ComResult := CoInitializeEx(nil, COINIT_APARTMENTTHREADED);
    if Failed(ComResult) then
    begin
      PublishBase(assFaulted, 'COM initialization failed: ' +
        IntToHex(Cardinal(ComResult), 8));
      Exit;
    end;
    ComInitialized := True;
    PublishBase(assStarting, '');
    try
      Reconcile;
    except
      on E: Exception do
        PublishBase(assFaulted, E.ClassName + ': ' + E.Message);
    end;
    while not Terminated do
    begin
      if FOwner.IsStopping then
        Break;
      ProcessRequests;
      ProcessVolumeNotification;
      if ProcessDeviceNotification then
      begin
        try
          Reconcile;
        except
          on E: Exception do
            PublishBase(assFaulted, E.ClassName + ': ' + E.Message);
        end;
      end;
      PumpMessages;
      FOwner.FWakeEvent.ResetEvent;
      FOwner.FWakeEvent.WaitFor(100);
    end;
  finally
    FOwner.RejectQueuedRequests('audio service stopped before request completed');
    PublishBase(assStopping, '');
    ReleaseComObjects;
    if ComInitialized then
      CoUninitialize;
    PublishBase(assStopped, '');
    FOwner.FStoppedEvent.SetEvent;
  end;
end;

constructor TAudioService.Create(EnableDiagnostics: Boolean);
begin
  inherited Create;
  FDiagnostics := EnableDiagnostics;
  FLock := TObject.Create;
  FWakeEvent := TEvent.Create(nil, True, False, '');
  FStoppedEvent := TEvent.Create(nil, True, True, '');
  FLatest.State := assStopped;
  CreateGUID(FEventContext);
end;

destructor TAudioService.Destroy;
begin
  Stop(INFINITE);
  FStoppedEvent.Free;
  FWakeEvent.Free;
  FLock.Free;
  inherited;
end;

procedure TAudioService.RejectQueuedRequests(const ErrorText: string);
var
  Requests: TArray<TAudioVolumeRequest>;
  Request: TAudioVolumeRequest;
begin
  TMonitor.Enter(FLock);
  try
    Requests := Copy(FQueue);
    SetLength(FQueue, 0);
  finally
    TMonitor.Exit(FLock);
  end;
  for Request in Requests do
    SetRequestResult(Request.RequestId, avrsFailed, 0, ErrorText);
end;

procedure TAudioService.Start;
begin
  TMonitor.Enter(FLock);
  try
    if FWorker <> nil then
      Exit;
    FStopRequested := False;
    FStoppedEvent.ResetEvent;
    FWorker := TWorker.Create(Self);
    FWorker.Start;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TAudioService.Stop(TimeoutMs: Cardinal): Boolean;
var
  Worker: TWorker;
begin
  TMonitor.Enter(FLock);
  try
    Worker := FWorker;
    if Worker = nil then
      Exit(True);
    FStopRequested := True;
    FWakeEvent.SetEvent;
  finally
    TMonitor.Exit(FLock);
  end;
  Result := FStoppedEvent.WaitFor(TimeoutMs) = wrSignaled;
  if Result then
  begin
    Worker.WaitFor;
    TMonitor.Enter(FLock);
    try
      if FWorker = Worker then
        FWorker := nil;
    finally
      TMonitor.Exit(FLock);
    end;
    Worker.Free;
  end;
end;

function TAudioService.TryGetLatest(
  out Snapshot: TAudioServiceSnapshot): Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := FHasLatest;
    if Result then
      Snapshot := FLatest;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TAudioService.Publish(const Snapshot: TAudioServiceSnapshot);
var
  Published: TAudioServiceSnapshot;
begin
  Published := Snapshot;
  TMonitor.Enter(FLock);
  try
    Published.Sequence := FLatest.Sequence + 1;
    FLatest := Published;
    FHasLatest := True;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TAudioService.IsStopping: Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := FStopRequested;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TAudioService.EnqueueRequest(
  const Request: TAudioVolumeRequest): Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := (FWorker <> nil) and not FStopRequested;
    if Result then
    begin
      SetLength(FQueue, Length(FQueue) + 1);
      FQueue[High(FQueue)] := Request;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
  if Result then
    FWakeEvent.SetEvent;
end;

procedure TAudioService.SetRequestResult(RequestId: UInt64;
  Status: TAudioVolumeRequestStatus; AppliedPercent: Integer;
  const ErrorText: string);
var
  Index: Integer;
begin
  TMonitor.Enter(FLock);
  try
    for Index := 0 to High(FRequests) do
      if FRequests[Index].RequestId = RequestId then
      begin
        FRequests[Index].Status := Status;
        FRequests[Index].AppliedPercent := AppliedPercent;
        FRequests[Index].ErrorText := ErrorText;
        FRequests[Index].CompletedAt := Now;
        Exit;
      end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TAudioService.RequestMasterVolume(Percent: Integer;
  out RequestId: UInt64; out ErrorText: string): Boolean;
var
  Request: TAudioVolumeRequest;
  ResultRecord: TAudioVolumeRequestResult;
begin
  RequestId := 0;
  ErrorText := '';
  if not IsValidVolumePercent(Percent) then
  begin
    ErrorText := 'volume percentage must be an integer from 0 to 100';
    Exit(False);
  end;
  TMonitor.Enter(FLock);
  try
    if (FWorker = nil) or FStopRequested then
    begin
      ErrorText := 'audio service is not running';
      Exit(False);
    end;
    Inc(FNextRequestId);
    Request.RequestId := FNextRequestId;
    Request.RequestedPercent := Percent;
    RequestId := Request.RequestId;
    ResultRecord := Default(TAudioVolumeRequestResult);
    ResultRecord.RequestId := RequestId;
    ResultRecord.Status := avrsPending;
    ResultRecord.RequestedPercent := Percent;
    SetLength(FRequests, Length(FRequests) + 1);
    FRequests[High(FRequests)] := ResultRecord;
  finally
    TMonitor.Exit(FLock);
  end;
  Result := EnqueueRequest(Request);
  if not Result then
  begin
    ErrorText := 'audio service stopped before request was queued';
    SetRequestResult(RequestId, avrsRejected, 0, ErrorText);
  end;
  if Result then
    FWakeEvent.SetEvent;
end;

function TAudioService.TryGetRequestResult(RequestId: UInt64;
  out ResultValue: TAudioVolumeRequestResult): Boolean;
var
  Index: Integer;
begin
  TMonitor.Enter(FLock);
  try
    for Index := 0 to High(FRequests) do
      if FRequests[Index].RequestId = RequestId then
      begin
        ResultValue := FRequests[Index];
        Exit(True);
      end;
    ResultValue := Default(TAudioVolumeRequestResult);
    Result := False;
  finally
    TMonitor.Exit(FLock);
  end;
end;

end.

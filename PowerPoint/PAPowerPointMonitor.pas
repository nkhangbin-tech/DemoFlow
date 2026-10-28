unit PAPowerPointMonitor;

interface

uses
  System.Classes,
  System.SyncObjs,
  System.SysUtils,
  PowerPoint_TLB;

type
  TPowerPointMonitorState = (
    pmsDisconnected,
    pmsConnectedNoShow,
    pmsShowKnown,
    pmsShowUnknown,
    pmsAmbiguous,
    pmsFaulted,
    pmsStopped
  );

  TPowerPointWindowSnapshot = record
    CollectionIndex: Integer;
    HasSlideIndex: Boolean;
    SlideIndex: Integer;
    HasShowPosition: Boolean;
    ShowPosition: Integer;
    ErrorText: string;
  end;

  TPowerPointMonitorSnapshot = record
    State: TPowerPointMonitorState;
    ObservedAt: TDateTime;
    WindowCount: Integer;
    Windows: TArray<TPowerPointWindowSnapshot>;
    ErrorText: string;
    Sequence: UInt64;
    EventSequence: UInt64;
    LastEventName: string;
    BuildEventCount: UInt64;
    NextClickEventCount: UInt64;
  end;

  TPowerPointMonitor = class
  private
    type
      TWorker = class(TThread)
      private
        FOwner: TPowerPointMonitor;
        FPowerPoint: PowerPoint_TLB._Application;
        FEvents: PowerPoint_TLB.TPowerPointApplication;
        FReconciliationPending: Boolean;
        FEventSequence: UInt64;
        FLastEventName: string;
        FBuildEventCount: UInt64;
        FNextClickEventCount: UInt64;
        procedure RecordEvent(const EventName: string; IsBuild,
          IsNextClick: Boolean);
        procedure OnSlideShowBegin(ASender: TObject;
          const Wn: PowerPoint_TLB.SlideShowWindow);
        procedure OnSlideShowNextSlide(ASender: TObject;
          const Wn: PowerPoint_TLB.SlideShowWindow);
        procedure OnSlideShowNextBuild(ASender: TObject;
          const Wn: PowerPoint_TLB.SlideShowWindow);
        procedure OnSlideShowNextClick(ASender: TObject;
          const Wn: PowerPoint_TLB.SlideShowWindow;
          const EventEffect: PowerPoint_TLB.Effect);
        procedure OnSlideShowEnd(ASender: TObject;
          const Pres: PowerPoint_TLB.PowerPointPresentation);
        procedure DisconnectPowerPoint;
        function TryAttachPowerPoint: Boolean;
        procedure CopyEventState(var Snapshot: TPowerPointMonitorSnapshot);
      protected
        procedure Execute; override;
      public
        constructor Create(AOwner: TPowerPointMonitor);
      end;
  private
    FIntervalMs: Cardinal;
    FLock: TObject;
    FWakeEvent: TEvent;
    FStoppedEvent: TEvent;
    FStopRequested: Boolean;
    FWorker: TWorker;
    FLatest: TPowerPointMonitorSnapshot;
    FHasLatest: Boolean;
    procedure Publish(const Snapshot: TPowerPointMonitorSnapshot);
    procedure PublishFault(const ErrorText: string);
    procedure WorkerLoop;
    procedure SetStoppedSnapshot;
  public
    constructor Create(IntervalMs: Cardinal = 500);
    destructor Destroy; override;
    procedure Start;
    function Stop(TimeoutMs: Cardinal = 2000): Boolean;
    function TryGetLatest(out Snapshot: TPowerPointMonitorSnapshot): Boolean;
    property IntervalMs: Cardinal read FIntervalMs;
  end;

function PowerPointMonitorStateName(State: TPowerPointMonitorState): string;
function TryGetValidShowPosition(Candidate: Integer;
  out Position: Integer): Boolean;

implementation

uses
  System.DateUtils,
  System.Win.ComObj,
  System.Variants,
  Winapi.ActiveX,
  Winapi.Windows;

function PowerPointMonitorStateName(State: TPowerPointMonitorState): string;
begin
  case State of
    pmsDisconnected: Result := 'disconnected';
    pmsConnectedNoShow: Result := 'connected-no-show';
    pmsShowKnown: Result := 'show-known';
    pmsShowUnknown: Result := 'show-unknown';
    pmsAmbiguous: Result := 'ambiguous';
    pmsFaulted: Result := 'faulted';
  else
    Result := 'stopped';
  end;

end;

function TryGetValidShowPosition(Candidate: Integer;
  out Position: Integer): Boolean;
begin
  Result := Candidate > 0;
  if Result then
    Position := Candidate
  else
    Position := 0;
end;

function DispatchVariant(const Dispatch: IDispatch): OleVariant;
begin
  VarClear(Result);
  Dispatch._AddRef;
  TVarData(Result).VType := varDispatch;
  TVarData(Result).VDispatch := Pointer(Dispatch);
end;

procedure ClearVariant(var Value: OleVariant);
begin
  if VarIsEmpty(Value) then
    Exit;
  try
    VarClear(Value);
  except
    on E: Exception do
    begin
      TVarData(Value).VType := varEmpty;
      TVarData(Value).VPointer := nil;
    end;
  end;
end;

constructor TPowerPointMonitor.TWorker.Create(AOwner: TPowerPointMonitor);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FOwner := AOwner;
end;

procedure TPowerPointMonitor.TWorker.Execute;
begin
  try
    FOwner.WorkerLoop;
  except
    on E: Exception do
      FOwner.PublishFault(E.ClassName + ': ' + E.Message);
  end;
end;

procedure TPowerPointMonitor.TWorker.RecordEvent(const EventName: string;
  IsBuild, IsNextClick: Boolean);
begin
  Inc(FEventSequence);
  FLastEventName := EventName;
  FReconciliationPending := True;
  if IsBuild then
    Inc(FBuildEventCount);
  if IsNextClick then
    Inc(FNextClickEventCount);
end;

procedure TPowerPointMonitor.TWorker.OnSlideShowBegin(ASender: TObject;
  const Wn: SlideShowWindow);
begin
  RecordEvent('SlideShowBegin', False, False);
end;

procedure TPowerPointMonitor.TWorker.OnSlideShowNextSlide(ASender: TObject;
  const Wn: SlideShowWindow);
begin
  RecordEvent('SlideShowNextSlide', False, False);
end;

procedure TPowerPointMonitor.TWorker.OnSlideShowNextBuild(ASender: TObject;
  const Wn: SlideShowWindow);
begin
  RecordEvent('SlideShowNextBuild', True, False);
end;

procedure TPowerPointMonitor.TWorker.OnSlideShowNextClick(ASender: TObject;
  const Wn: SlideShowWindow; const EventEffect: Effect);
begin
  RecordEvent('SlideShowNextClick', False, True);
end;

procedure TPowerPointMonitor.TWorker.OnSlideShowEnd(ASender: TObject;
  const Pres: PowerPointPresentation);
begin
  RecordEvent('SlideShowEnd', False, False);
end;

procedure TPowerPointMonitor.TWorker.CopyEventState(
  var Snapshot: TPowerPointMonitorSnapshot);
begin
  Snapshot.EventSequence := FEventSequence;
  Snapshot.LastEventName := FLastEventName;
  Snapshot.BuildEventCount := FBuildEventCount;
  Snapshot.NextClickEventCount := FNextClickEventCount;
end;

procedure TPowerPointMonitor.TWorker.DisconnectPowerPoint;
begin
  if FEvents <> nil then
  begin
    FEvents.OnSlideShowBegin := nil;
    FEvents.OnSlideShowNextSlide := nil;
    FEvents.OnSlideShowNextBuild := nil;
    FEvents.OnSlideShowNextClick := nil;
    FEvents.OnSlideShowEnd := nil;
    try
      FEvents.Disconnect;
    except
      on E: Exception do
        FOwner.PublishFault('event sink disconnect failed: ' +
          E.ClassName + ': ' + E.Message);
    end;
    FreeAndNil(FEvents);
  end;
  FPowerPoint := nil;
  FReconciliationPending := False;
end;

function TPowerPointMonitor.TWorker.TryAttachPowerPoint: Boolean;
var
  ClassId: TCLSID;
  Unknown: IUnknown;
  ApplicationIntf: _Application;
begin
  Result := False;
  if FEvents <> nil then
    Exit(True);
  if Failed(CLSIDFromProgID('PowerPoint.Application', ClassId)) then
    Exit;
  if Failed(GetActiveObject(ClassId, nil, Unknown)) then
    Exit;
  if Failed(Unknown.QueryInterface(IID__Application, ApplicationIntf)) then
    Exit;
  try
    FPowerPoint := ApplicationIntf;
    FEvents := TPowerPointApplication.Create(nil);
    FEvents.OnSlideShowBegin := OnSlideShowBegin;
    FEvents.OnSlideShowNextSlide := OnSlideShowNextSlide;
    FEvents.OnSlideShowNextBuild := OnSlideShowNextBuild;
    FEvents.OnSlideShowNextClick := OnSlideShowNextClick;
    FEvents.OnSlideShowEnd := OnSlideShowEnd;
    FEvents.AutoQuit := False;
    FEvents.ConnectTo(FPowerPoint);
    Result := True;
  except
    on E: Exception do
    begin
      DisconnectPowerPoint;
      FOwner.PublishFault('event sink attach failed: ' +
        E.ClassName + ': ' + E.Message);
    end;
  end;
end;

constructor TPowerPointMonitor.Create(IntervalMs: Cardinal);
begin
  inherited Create;
  if IntervalMs < 100 then
    FIntervalMs := 100
  else if IntervalMs > 5000 then
    FIntervalMs := 5000
  else
    FIntervalMs := IntervalMs;
  FLock := TObject.Create;
  FWakeEvent := TEvent.Create(nil, True, False, '');
  FStoppedEvent := TEvent.Create(nil, True, True, '');
  FLatest.State := pmsStopped;
end;

destructor TPowerPointMonitor.Destroy;
begin
  Stop(2000);
  FStoppedEvent.Free;
  FWakeEvent.Free;
  FLock.Free;
  inherited;
end;

procedure TPowerPointMonitor.Start;
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

function TPowerPointMonitor.Stop(TimeoutMs: Cardinal): Boolean;
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
    SetStoppedSnapshot;
  end;
end;

function TPowerPointMonitor.TryGetLatest(
  out Snapshot: TPowerPointMonitorSnapshot): Boolean;
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

procedure TPowerPointMonitor.Publish(
  const Snapshot: TPowerPointMonitorSnapshot);
begin
  TMonitor.Enter(FLock);
  try
    FLatest := Snapshot;
    FHasLatest := True;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TPowerPointMonitor.PublishFault(const ErrorText: string);
var
  Snapshot: TPowerPointMonitorSnapshot;
begin
  Snapshot := Default(TPowerPointMonitorSnapshot);
  Snapshot.State := pmsFaulted;
  Snapshot.ObservedAt := Now;
  Snapshot.ErrorText := ErrorText;
  TMonitor.Enter(FLock);
  try
    Snapshot.Sequence := FLatest.Sequence + 1;
    FLatest := Snapshot;
    FHasLatest := True;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TPowerPointMonitor.SetStoppedSnapshot;
var
  Snapshot: TPowerPointMonitorSnapshot;
begin
  Snapshot := Default(TPowerPointMonitorSnapshot);
  Snapshot.State := pmsStopped;
  Snapshot.ObservedAt := Now;
  Publish(Snapshot);
end;

procedure TPowerPointMonitor.WorkerLoop;
var
  ComInitialized: Boolean;
  ComResult: HRESULT;
  Snapshot, LastPublished: TPowerPointMonitorSnapshot;
  Windows, Window, View, Slide: OleVariant;
  Count, Index: Integer;
  Changed, HasPublished: Boolean;
  WakeHandle: THandle;
  Msg: TMsg;
  DispatchResult: DWORD;
begin
  ComInitialized := False;
  FWorker.FPowerPoint := nil;
  FWorker.FEvents := nil;
  FWorker.FReconciliationPending := False;
  FWorker.FEventSequence := 0;
  FWorker.FLastEventName := '';
  FWorker.FBuildEventCount := 0;
  FWorker.FNextClickEventCount := 0;
  HasPublished := False;
  LastPublished := Default(TPowerPointMonitorSnapshot);
  try
    ComResult := CoInitialize(nil);
    if Failed(ComResult) then
    begin
      Snapshot := Default(TPowerPointMonitorSnapshot);
      Snapshot.State := pmsFaulted;
      Snapshot.ErrorText := 'COM initialization failed: ' +
        IntToHex(Cardinal(ComResult), 8);
      Publish(Snapshot);
      Exit;
    end;
    ComInitialized := True;
    while True do
    begin
      TMonitor.Enter(FLock);
      try
        if FStopRequested then
          Break;
      finally
        TMonitor.Exit(FLock);
      end;

      Snapshot := Default(TPowerPointMonitorSnapshot);
      Snapshot.ObservedAt := Now;
      if FWorker.FEvents = nil then
        FWorker.TryAttachPowerPoint;

      if FWorker.FEvents = nil then
        Snapshot.State := pmsDisconnected
      else
      try
        Windows := FWorker.FPowerPoint.SlideShowWindows;
        try
          Count := Windows.Count;
          Snapshot.WindowCount := Count;
          SetLength(Snapshot.Windows, Count);
          if Count = 0 then
            Snapshot.State := pmsConnectedNoShow
          else
          begin
            for Index := 1 to Count do
            begin
              Snapshot.Windows[Index - 1].CollectionIndex := Index;
              try
                Window := Windows.Item(Index);
                try
                  View := Window.View;
                  try
                    Slide := View.Slide;
                    try
                      Snapshot.Windows[Index - 1].SlideIndex :=
                        Slide.SlideIndex;
                      Snapshot.Windows[Index - 1].HasSlideIndex := True;
                    finally
                      ClearVariant(Slide);
                    end;
                    try
                      Snapshot.Windows[Index - 1].ShowPosition :=
                        View.CurrentShowPosition;
                      Snapshot.Windows[Index - 1].HasShowPosition :=
                        TryGetValidShowPosition(
                          Snapshot.Windows[Index - 1].ShowPosition,
                          Snapshot.Windows[Index - 1].ShowPosition);
                      if not Snapshot.Windows[Index - 1].HasShowPosition then
                        Snapshot.Windows[Index - 1].ErrorText :=
                          'show position unavailable: zero';
                    except
                      on E: Exception do
                        Snapshot.Windows[Index - 1].ErrorText :=
                          E.ClassName + ': ' + E.Message;
                    end;
                  finally
                    ClearVariant(View);
                  end;
                finally
                  ClearVariant(Window);
                end;
              except
                on E: Exception do
                  Snapshot.Windows[Index - 1].ErrorText :=
                    E.ClassName + ': ' + E.Message;
              end;
            end;
            if Count > 1 then
              Snapshot.State := pmsAmbiguous
            else if Snapshot.Windows[0].HasSlideIndex or
              Snapshot.Windows[0].HasShowPosition then
              Snapshot.State := pmsShowKnown
            else
              Snapshot.State := pmsShowUnknown;
          end;
        finally
          ClearVariant(Windows);
        end;
      except
        on E: Exception do
        begin
          Snapshot.State := pmsFaulted;
          Snapshot.ErrorText := E.ClassName + ': ' + E.Message;
          FWorker.DisconnectPowerPoint;
        end;
      end;
      FWorker.CopyEventState(Snapshot);

      Changed := not HasPublished or
        (Snapshot.State <> LastPublished.State);
      if not Changed then
        Changed := Snapshot.WindowCount <> LastPublished.WindowCount;
      if not Changed then
        Changed := Snapshot.ErrorText <> LastPublished.ErrorText;
      if not Changed then
        Changed := Snapshot.EventSequence <> LastPublished.EventSequence;
      if not Changed then
        Changed := Snapshot.LastEventName <> LastPublished.LastEventName;
      if not Changed then
        Changed := Snapshot.BuildEventCount <> LastPublished.BuildEventCount;
      if not Changed then
        Changed := Snapshot.NextClickEventCount <>
          LastPublished.NextClickEventCount;
      if not Changed then
        Changed := Length(Snapshot.Windows) <> Length(LastPublished.Windows);
      if not Changed and (Length(Snapshot.Windows) > 0) then
        Changed := (Snapshot.Windows[0].SlideIndex <>
          LastPublished.Windows[0].SlideIndex) or
          (Snapshot.Windows[0].ShowPosition <>
          LastPublished.Windows[0].ShowPosition);
      if Changed then
      begin
        Snapshot.Sequence := LastPublished.Sequence + 1;
        Publish(Snapshot);
        LastPublished := Snapshot;
        HasPublished := True;
      end;
      WakeHandle := FWakeEvent.Handle;
      DispatchResult := MsgWaitForMultipleObjects(1, WakeHandle,
        False, FIntervalMs, QS_ALLINPUT);
      if DispatchResult = WAIT_OBJECT_0 then
        FWakeEvent.ResetEvent
      else if DispatchResult = WAIT_OBJECT_0 + 1 then
        while PeekMessage(Msg, 0, 0, 0, PM_REMOVE) do
        begin
          TranslateMessage(Msg);
          DispatchMessage(Msg);
        end;
    end;
  finally
    FWorker.DisconnectPowerPoint;
    if ComInitialized then
      CoUninitialize;
    FStoppedEvent.SetEvent;
  end;
end;

end.

unit PAPowerPointMonitor;

interface

uses
  System.Classes,
  System.SyncObjs,
  System.SysUtils;

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
  end;

  TPowerPointMonitor = class
  private
    type
      TWorker = class(TThread)
      private
        FOwner: TPowerPointMonitor;
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
  PowerPoint: OleVariant;
  ClassId: TCLSID;
  Unknown: IUnknown;
  Dispatch: IDispatch;
  Snapshot, LastPublished: TPowerPointMonitorSnapshot;
  Windows, Window, View, Slide: OleVariant;
  Count, Index: Integer;
  Changed, Attached, HasPublished: Boolean;
  WaitResult: TWaitResult;
begin
  ComInitialized := False;
  PowerPoint := Unassigned;
  Attached := False;
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
      if not Attached then
      begin
        if Succeeded(CLSIDFromProgID('PowerPoint.Application', ClassId)) and
          Succeeded(GetActiveObject(ClassId, nil, Unknown)) and
          Succeeded(Unknown.QueryInterface(
            StringToGUID('{00020400-0000-0000-C000-000000000046}'),
            Dispatch)) then
        begin
          PowerPoint := DispatchVariant(Dispatch);
          Dispatch := nil;
          Attached := True;
        end;
      end;

      if not Attached then
        Snapshot.State := pmsDisconnected
      else
      try
        Windows := PowerPoint.SlideShowWindows;
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
                      Snapshot.Windows[Index - 1].HasShowPosition := True;
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
          ClearVariant(PowerPoint);
          Attached := False;
        end;
      end;

      Changed := not HasPublished or
        (Snapshot.State <> LastPublished.State);
      if not Changed then
        Changed := Snapshot.WindowCount <> LastPublished.WindowCount;
      if not Changed then
        Changed := Snapshot.ErrorText <> LastPublished.ErrorText;
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
      WaitResult := FWakeEvent.WaitFor(FIntervalMs);
      if WaitResult = wrSignaled then
        FWakeEvent.ResetEvent;
    end;
  finally
    ClearVariant(PowerPoint);
    if ComInitialized then
      CoUninitialize;
    FStoppedEvent.SetEvent;
  end;
end;

end.

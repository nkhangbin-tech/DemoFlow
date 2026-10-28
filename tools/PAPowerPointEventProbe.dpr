program PAPowerPointEventProbe;

{$APPTYPE CONSOLE}

uses
  System.Classes,
  System.DateUtils,
  System.SysUtils,
  Winapi.ActiveX,
  Winapi.Messages,
  Winapi.Windows,
  PowerPoint_TLB,
  PAEventProbeState;

type
  TEventProbe = class
  private
    FApplication: _Application;
    FEvents: TPowerPointApplication;
    FEventBuffer: array[0..127] of TProbeEvent;
    FEventCount: Integer;
    FDroppedEvents: Cardinal;
    FNextEventSequence: UInt64;
    FState: TProbeReconciliationState;
    FLastReportedSlideIndex: Integer;
    FLastReportedShowPosition: Integer;
    FLastReportedWindowCount: Integer;
    FLastReportedHasSlide: Boolean;
    FLastReportedHasPosition: Boolean;
    FHasReportedSnapshot: Boolean;
    FLastAttachAttempt: UInt64;
    FLastAttachDiagnostic: string;
    procedure RecordEvent(Kind: TProbeEventKind);
    procedure ProcessEvents;
    procedure OnSlideShowBegin(ASender: TObject; const Wn: SlideShowWindow);
    procedure OnSlideShowNextSlide(ASender: TObject;
      const Wn: SlideShowWindow);
    procedure OnSlideShowNextBuild(ASender: TObject;
      const Wn: SlideShowWindow);
    procedure OnSlideShowNextClick(ASender: TObject;
      const Wn: SlideShowWindow; const EventEffect: Effect);
    procedure OnSlideShowEnd(ASender: TObject;
      const Pres: PowerPointPresentation);
    function TryAttach: Boolean;
    procedure Detach;
    function Reconcile(out WindowCount, SlideIndex, ShowPosition: Integer;
      out HasSlide, HasPosition: Boolean): Boolean;
    procedure ReportSnapshot(WindowCount, SlideIndex, ShowPosition: Integer;
      HasSlide, HasPosition: Boolean);
    procedure Report(const Text: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Run(DurationSeconds: Cardinal);
  end;

function TimestampText(const Value: TDateTime): string;
begin
  Result := DateToISO8601(Value, True);
end;

function EventKindText(Kind: TProbeEventKind): string;
begin
  Result := ProbeEventName(Kind);
end;

constructor TEventProbe.Create;
begin
  inherited Create;
  InitializeProbeState(FState);
  FLastReportedWindowCount := -1;
end;

destructor TEventProbe.Destroy;
begin
  Detach;
  inherited Destroy;
end;

procedure TEventProbe.Report(const Text: string);
begin
  Writeln(TimestampText(Now), ' ', Text);
end;

procedure TEventProbe.RecordEvent(Kind: TProbeEventKind);
begin
  Inc(FNextEventSequence);
  if FEventCount < Length(FEventBuffer) then
  begin
    FEventBuffer[FEventCount].Kind := Kind;
    FEventBuffer[FEventCount].Sequence := FNextEventSequence;
    FEventBuffer[FEventCount].ObservedAt := Now;
    FEventBuffer[FEventCount].SinkConnected := FEvents <> nil;
    Inc(FEventCount);
  end
  else
    Inc(FDroppedEvents);
end;

procedure TEventProbe.OnSlideShowBegin(ASender: TObject;
  const Wn: SlideShowWindow);
begin
  RecordEvent(pekSlideShowBegin);
end;

procedure TEventProbe.OnSlideShowNextSlide(ASender: TObject;
  const Wn: SlideShowWindow);
begin
  RecordEvent(pekSlideShowNextSlide);
end;

procedure TEventProbe.OnSlideShowNextBuild(ASender: TObject;
  const Wn: SlideShowWindow);
begin
  RecordEvent(pekSlideShowNextBuild);
end;

procedure TEventProbe.OnSlideShowNextClick(ASender: TObject;
  const Wn: SlideShowWindow; const EventEffect: Effect);
begin
  RecordEvent(pekSlideShowNextClick);
end;

procedure TEventProbe.OnSlideShowEnd(ASender: TObject;
  const Pres: PowerPointPresentation);
begin
  RecordEvent(pekSlideShowEnd);
end;

procedure TEventProbe.ProcessEvents;
var
  Event: TProbeEvent;
  EventIndex: Integer;
begin
  for EventIndex := 0 to FEventCount - 1 do
  begin
    Event := FEventBuffer[EventIndex];
    if ApplyProbeEvent(FState, Event) then
    begin
      Writeln(TimestampText(Event.ObservedAt), ' EVENT sequence=',
        Event.Sequence, ' name=', EventKindText(Event.Kind),
        ' sinkConnected=', Event.SinkConnected);
      Report('RECONCILIATION_REQUESTED eventSequence=' +
        UIntToStr(Event.Sequence));
    end
    else
      Report('EVENT_IGNORED sequence=' + UIntToStr(Event.Sequence));
  end;
  FEventCount := 0;
end;

function TEventProbe.TryAttach: Boolean;
var
  ClassId: TCLSID;
  Unknown: IUnknown;
  ApplicationIntf: _Application;
  ResultCode: HRESULT;
  Diagnostic: string;
begin
  Result := False;
  if FEvents <> nil then
    Exit(True);
  if (GetTickCount64 - FLastAttachAttempt) < 500 then
    Exit;
  FLastAttachAttempt := GetTickCount64;
  ResultCode := CLSIDFromProgID('PowerPoint.Application', ClassId);
  if Failed(ResultCode) then
  begin
    Diagnostic := 'CLSIDFromProgID hresult=' +
      IntToHex(Cardinal(ResultCode), 8);
    if Diagnostic <> FLastAttachDiagnostic then
    begin
      Report('POWERPOINT_UNAVAILABLE ' + Diagnostic);
      FLastAttachDiagnostic := Diagnostic;
    end;
    Exit;
  end;
  ResultCode := GetActiveObject(ClassId, nil, Unknown);
  if Failed(ResultCode) then
  begin
    Diagnostic := 'GetActiveObject hresult=' +
      IntToHex(Cardinal(ResultCode), 8);
    if Diagnostic <> FLastAttachDiagnostic then
    begin
      Report('POWERPOINT_UNAVAILABLE ' + Diagnostic);
      FLastAttachDiagnostic := Diagnostic;
    end;
    Exit;
  end;
  ResultCode := Unknown.QueryInterface(IID__Application, ApplicationIntf);
  if Failed(ResultCode) then
  begin
    Diagnostic := 'QueryInterface hresult=' +
      IntToHex(Cardinal(ResultCode), 8);
    if Diagnostic <> FLastAttachDiagnostic then
    begin
      Report('POWERPOINT_UNAVAILABLE ' + Diagnostic);
      FLastAttachDiagnostic := Diagnostic;
    end;
    Exit;
  end;
  try
    FApplication := ApplicationIntf;
    FEvents := TPowerPointApplication.Create(nil);
    FEvents.OnSlideShowBegin := OnSlideShowBegin;
    FEvents.OnSlideShowNextSlide := OnSlideShowNextSlide;
    FEvents.OnSlideShowNextBuild := OnSlideShowNextBuild;
    FEvents.OnSlideShowNextClick := OnSlideShowNextClick;
    FEvents.OnSlideShowEnd := OnSlideShowEnd;
    FEvents.AutoQuit := False;
    FEvents.ConnectTo(FApplication);
    SetProbeSinkStatus(FState, True);
    FLastAttachDiagnostic := '';
    Report('EVENT_SINK_CONNECTED interface=EApplication');
    Result := True;
  except
    on E: Exception do
    begin
      Report('EVENT_SINK_FAILED ' + E.ClassName + ': ' + E.Message);
      Detach;
    end;
  end;
end;

procedure TEventProbe.Detach;
begin
  if FEvents <> nil then
  begin
    try
      FEvents.OnSlideShowBegin := nil;
      FEvents.OnSlideShowNextSlide := nil;
      FEvents.OnSlideShowNextBuild := nil;
      FEvents.OnSlideShowNextClick := nil;
      FEvents.OnSlideShowEnd := nil;
      FEvents.Disconnect;
    except
      on E: Exception do
        Report('EVENT_SINK_DISCONNECT_FAILED ' + E.ClassName + ': ' +
          E.Message);
    end;
    FreeAndNil(FEvents);
    FApplication := nil;
    SetProbeSinkStatus(FState, False);
    Report('EVENT_SINK_DISCONNECTED');
  end;
end;

function TEventProbe.Reconcile(out WindowCount, SlideIndex,
  ShowPosition: Integer; out HasSlide, HasPosition: Boolean): Boolean;
var
  Windows: SlideShowWindows;
  Window: SlideShowWindow;
  View: SlideShowView;
  Slide: PowerPointSlide;
begin
  Result := False;
  WindowCount := 0;
  SlideIndex := 0;
  ShowPosition := 0;
  HasSlide := False;
  HasPosition := False;
  if FApplication = nil then
    Exit;
  try
    Windows := FApplication.SlideShowWindows;
    WindowCount := Windows.Count;
    if WindowCount > 0 then
    begin
      Window := Windows.Item(1);
      View := Window.View;
      try
        try
          Slide := View.Slide;
          try
            SlideIndex := Slide.SlideIndex;
            HasSlide := True;
          finally
            Slide := nil;
          end;
        except
          on E: Exception do
            Report('RECONCILIATION_SLIDE_UNAVAILABLE ' + E.ClassName +
              ': ' + E.Message);
        end;
        try
          ShowPosition := View.CurrentShowPosition;
          if ShowPosition > 0 then
            HasPosition := True
          else
            Report('RECONCILIATION_POSITION_UNAVAILABLE reason=zero');
        except
          on E: Exception do
            Report('RECONCILIATION_POSITION_UNAVAILABLE ' + E.ClassName +
              ': ' + E.Message);
        end;
      finally
        View := nil;
        Window := nil;
      end;
    end;
    Result := True;
  except
    on E: Exception do
    begin
      Report('RECONCILIATION_FAILED ' + E.ClassName + ': ' + E.Message);
      Detach;
    end;
  end;
end;

procedure TEventProbe.ReportSnapshot(WindowCount, SlideIndex,
  ShowPosition: Integer; HasSlide, HasPosition: Boolean);
begin
  if FHasReportedSnapshot and (WindowCount = FLastReportedWindowCount) and
    (SlideIndex = FLastReportedSlideIndex) and
    (ShowPosition = FLastReportedShowPosition) and
    (HasSlide = FLastReportedHasSlide) and
    (HasPosition = FLastReportedHasPosition) then
    Exit;
  FHasReportedSnapshot := True;
  FLastReportedWindowCount := WindowCount;
  FLastReportedSlideIndex := SlideIndex;
  FLastReportedShowPosition := ShowPosition;
  FLastReportedHasSlide := HasSlide;
  FLastReportedHasPosition := HasPosition;
  Report('RECONCILIATION_COMPLETED windows=' + IntToStr(WindowCount) +
    ' slideIndex=' + IntToStr(SlideIndex) + ' hasSlideIndex=' +
    BoolToStr(HasSlide, True) + ' showPosition=' + IntToStr(ShowPosition) +
    ' hasShowPosition=' + BoolToStr(HasPosition, True));
end;

procedure TEventProbe.Run(DurationSeconds: Cardinal);
var
  StartTick: UInt64;
  LastPollTick: UInt64;
  Message: TMsg;
  WindowCount, SlideIndex, ShowPosition: Integer;
  HasSlide, HasPosition: Boolean;
  PollSequence: UInt64;
begin
  StartTick := GetTickCount64;
  LastPollTick := 0;
  PollSequence := 0;
  Writeln('Presenter Assistant PowerPoint COM EVENT diagnostic probe');
  Writeln('Read-only event subscription and reconciliation; duration=',
    DurationSeconds, ' seconds.');
  Writeln('This probe never launches, activates, navigates, saves, or closes PowerPoint.');
  Report('START durationSeconds=' + UIntToStr(DurationSeconds) +
    ' eventInterface=EApplication eventDispIDs=2011,2012,2013,2014,2019');
  while GetTickCount64 - StartTick < UInt64(DurationSeconds) * 1000 do
  begin
    if PeekMessage(Message, 0, 0, 0, PM_REMOVE) then
    begin
      if Message.message = WM_QUIT then
        Break;
      TranslateMessage(Message);
      DispatchMessage(Message);
      Continue;
    end;

    TryAttach;
    ProcessEvents;
    if GetTickCount64 - LastPollTick >= 500 then
    begin
      LastPollTick := GetTickCount64;
      Inc(PollSequence);
      if Reconcile(WindowCount, SlideIndex, ShowPosition, HasSlide,
        HasPosition) then
      begin
        if ApplyProbePollSuccess(FState, FState.LastEventSequence,
          SlideIndex, ShowPosition) then
          ReportSnapshot(WindowCount, SlideIndex, ShowPosition, HasSlide,
            HasPosition);
      end
      else
        ApplyProbePollFailure(FState);
    end;
    Sleep(10);
  end;
  ProcessEvents;
  Detach;
  MarkProbeShutdown(FState);
  Report('SUMMARY probe_complete pollSequence=' + UIntToStr(PollSequence) +
    ' droppedEvents=' + UIntToStr(FDroppedEvents));
end;

function ParseDuration: Cardinal;
var
  Requested: Integer;
begin
  Requested := StrToIntDef(ParamStr(1), 45);
  if Requested < 5 then
    Requested := 5;
  if Requested > 600 then
    Requested := 600;
  Result := Requested;
end;

var
  Probe: TEventProbe;

begin
  ExitCode := 0;
  if Failed(CoInitializeEx(nil, COINIT_APARTMENTTHREADED)) then
  begin
    Writeln('FATAL COM initialization failed');
    ExitCode := 1;
  end
  else
  begin
    try
      Probe := TEventProbe.Create;
      try
        Probe.Run(ParseDuration);
      finally
        Probe.Free;
      end;
    except
      on E: Exception do
      begin
        Writeln('FATAL ', E.ClassName, ': ', E.Message);
        ExitCode := 1;
      end;
    end;
    CoUninitialize;
  end;
end.

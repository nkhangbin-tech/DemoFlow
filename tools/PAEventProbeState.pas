unit PAEventProbeState;

interface

uses
  System.SysUtils;

type
  TProbeEventKind = (
    pekSlideShowBegin,
    pekSlideShowNextSlide,
    pekSlideShowNextBuild,
    pekSlideShowNextClick,
    pekSlideShowEnd
  );

  TProbeEvent = record
    Kind: TProbeEventKind;
    Sequence: UInt64;
    ObservedAt: TDateTime;
    SinkConnected: Boolean;
  end;

  TProbeReconciliationState = record
    LastEventSequence: UInt64;
    ReconciliationPending: Boolean;
    ObservationValid: Boolean;
    SinkConnected: Boolean;
    ShutdownComplete: Boolean;
    SlideIndex: Integer;
    ShowPosition: Integer;
  end;

procedure InitializeProbeState(out State: TProbeReconciliationState);
function ApplyProbeEvent(var State: TProbeReconciliationState;
  const Event: TProbeEvent): Boolean;
function ApplyProbePollSuccess(var State: TProbeReconciliationState;
  EventSequence: UInt64; SlideIndex, ShowPosition: Integer): Boolean;
procedure ApplyProbePollFailure(var State: TProbeReconciliationState);
procedure SetProbeSinkStatus(var State: TProbeReconciliationState;
  Connected: Boolean);
procedure MarkProbeShutdown(var State: TProbeReconciliationState);
function ProbeEventName(Kind: TProbeEventKind): string;

implementation

procedure InitializeProbeState(out State: TProbeReconciliationState);
begin
  State := Default(TProbeReconciliationState);
end;

function ApplyProbeEvent(var State: TProbeReconciliationState;
  const Event: TProbeEvent): Boolean;
begin
  if Event.Sequence <= State.LastEventSequence then
    Exit(False);
  State.LastEventSequence := Event.Sequence;
  State.ReconciliationPending := True;
  State.ObservationValid := False;
  Result := True;
end;

function ApplyProbePollSuccess(var State: TProbeReconciliationState;
  EventSequence: UInt64; SlideIndex, ShowPosition: Integer): Boolean;
begin
  if EventSequence < State.LastEventSequence then
    Exit(False);
  State.ReconciliationPending := False;
  State.ObservationValid := True;
  State.SlideIndex := SlideIndex;
  State.ShowPosition := ShowPosition;
  Result := True;
end;

procedure ApplyProbePollFailure(var State: TProbeReconciliationState);
begin
  State.ReconciliationPending := False;
  State.ObservationValid := False;
end;

procedure SetProbeSinkStatus(var State: TProbeReconciliationState;
  Connected: Boolean);
begin
  State.SinkConnected := Connected;
  if not Connected then
  begin
    State.ReconciliationPending := False;
    State.ObservationValid := False;
  end;
end;

procedure MarkProbeShutdown(var State: TProbeReconciliationState);
begin
  State.ShutdownComplete := True;
  State.SinkConnected := False;
  State.ReconciliationPending := False;
  State.ObservationValid := False;
end;

function ProbeEventName(Kind: TProbeEventKind): string;
begin
  case Kind of
    pekSlideShowBegin: Result := 'SlideShowBegin';
    pekSlideShowNextSlide: Result := 'SlideShowNextSlide';
    pekSlideShowNextBuild: Result := 'SlideShowNextBuild';
    pekSlideShowNextClick: Result := 'SlideShowNextClick';
    pekSlideShowEnd: Result := 'SlideShowEnd';
  else
    Result := 'Unknown';
  end;
end;

end.

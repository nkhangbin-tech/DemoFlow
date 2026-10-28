program PAEventProbeStateTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  PAEventProbeState;

procedure Check(Condition: Boolean; const Description: string);
begin
  if not Condition then
  begin
    Writeln('FAIL: ', Description);
    ExitCode := 1;
  end
  else
    Writeln('PASS: ', Description);
end;

var
  State: TProbeReconciliationState;
  Event: TProbeEvent;
begin
  ExitCode := 0;
  InitializeProbeState(State);
  Event.Kind := pekSlideShowNextSlide;
  Event.Sequence := 1;
  Event.ObservedAt := Now;
  Event.SinkConnected := True;
  Check(ApplyProbeEvent(State, Event), 'event sequence is accepted');
  Check(State.ReconciliationPending, 'event requests later reconciliation');
  Check(not State.ObservationValid, 'event invalidates cached observation');
  Check(ApplyProbePollSuccess(State, 1, 4, 2),
    'poll after callback accepts observation');
  Check(State.ObservationValid and (State.SlideIndex = 4) and
    (State.ShowPosition = 2), 'poll stores observed values');
  Event.Sequence := 1;
  Check(not ApplyProbeEvent(State, Event),
    'duplicate event does not replace state');
  Event.Sequence := 3;
  Check(ApplyProbeEvent(State, Event), 'later event is accepted');
  Check(not ApplyProbePollSuccess(State, 2, 5, 3),
    'out-of-order poll is rejected');
  ApplyProbePollFailure(State);
  Check(not State.ObservationValid, 'failed poll leaves state unknown');
  SetProbeSinkStatus(State, True);
  Check(State.SinkConnected, 'event source connection is tracked');
  SetProbeSinkStatus(State, False);
  Check(not State.SinkConnected and not State.ObservationValid,
    'event source loss invalidates cached state');
  MarkProbeShutdown(State);
  MarkProbeShutdown(State);
  Check(State.ShutdownComplete and not State.SinkConnected,
    'shutdown and unsubscription are idempotent');
  Check((ProbeEventName(pekSlideShowNextBuild) = 'SlideShowNextBuild') and
    (ProbeEventName(pekSlideShowNextClick) = 'SlideShowNextClick'),
    'event names are stable');
  if ExitCode = 0 then
    Writeln('All event probe state tests passed.')
  else
    Writeln('Event probe state tests failed.');
end.

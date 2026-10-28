program PAPowerPointMonitorTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  PAPowerPointMonitor;

procedure Check(Condition: Boolean; const Description: string);
begin
  if not Condition then
    raise Exception.Create('FAIL: ' + Description);
  Writeln('PASS: ', Description);
end;

var
  Monitor: TPowerPointMonitor;
  Snapshot: TPowerPointMonitorSnapshot;
  Position: Integer;
begin
  try
    Check(PowerPointMonitorStateName(pmsDisconnected) = 'disconnected',
      'disconnected state name');
    Check(PowerPointMonitorStateName(pmsAmbiguous) = 'ambiguous',
      'ambiguous state name');
    Check(not TryGetValidShowPosition(0, Position) and (Position = 0),
      'zero show position is unavailable');
    Check(not TryGetValidShowPosition(-1, Position) and (Position = 0),
      'negative show position is unavailable');
    Check(TryGetValidShowPosition(3, Position) and (Position = 3),
      'later valid show position restores availability');
    Monitor := TPowerPointMonitor.Create(10);
    try
      Check(Monitor.IntervalMs = 100, 'poll interval is safely clamped');
      Monitor.Start;
      Sleep(750);
      Check(Monitor.TryGetLatest(Snapshot), 'worker publishes a snapshot');
      Check(Snapshot.State in [pmsDisconnected, pmsConnectedNoShow,
        pmsShowKnown, pmsShowUnknown, pmsAmbiguous, pmsFaulted],
        'snapshot uses an explicit non-stopped state');
      Check(Monitor.Stop(2000), 'monitor stops within the bounded timeout');
      Check(Monitor.Stop(2000), 'repeated stop is safe');
    finally
      Monitor.Free;
    end;
    Writeln('All PowerPoint monitor tests passed.');
    ExitCode := 0;
  except
    on E: Exception do
    begin
      Writeln(E.Message);
      ExitCode := 1;
    end;
  end;
end.

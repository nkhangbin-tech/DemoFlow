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
begin
  try
    Check(PowerPointMonitorStateName(pmsDisconnected) = 'disconnected',
      'disconnected state name');
    Check(PowerPointMonitorStateName(pmsAmbiguous) = 'ambiguous',
      'ambiguous state name');
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

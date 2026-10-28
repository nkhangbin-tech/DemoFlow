program PAPowerPointMonitorProbe;

{$APPTYPE CONSOLE}

uses
  System.DateUtils,
  System.SysUtils,
  Winapi.Windows,
  PAPowerPointMonitor;

function DurationSeconds: Cardinal;
var
  Value: Integer;
begin
  Value := StrToIntDef(ParamStr(1), 45);
  if Value < 5 then Value := 5;
  if Value > 600 then Value := 600;
  Result := Value;
end;

var
  Monitor: TPowerPointMonitor;
  Snapshot, Last: TPowerPointMonitorSnapshot;
  StartTick: UInt64;
  Duration: Cardinal;
  Index: Integer;
begin
  try
    Duration := DurationSeconds;
    Monitor := TPowerPointMonitor.Create(500);
    try
      Monitor.Start;
      StartTick := GetTickCount64;
      Last.Sequence := 0;
      while GetTickCount64 - StartTick < UInt64(Duration) * 1000 do
      begin
        if Monitor.TryGetLatest(Snapshot) and
          (Snapshot.Sequence <> Last.Sequence) then
        begin
          Writeln(DateToISO8601(Snapshot.ObservedAt, True), ' ',
            PowerPointMonitorStateName(Snapshot.State),
            ' windows=', Snapshot.WindowCount,
            ' error=', Snapshot.ErrorText);
          for Index := 0 to High(Snapshot.Windows) do
            Writeln('  window=', Snapshot.Windows[Index].CollectionIndex,
              ' slideIndex=', Snapshot.Windows[Index].SlideIndex,
              ' hasSlideIndex=', Snapshot.Windows[Index].HasSlideIndex,
              ' showPosition=', Snapshot.Windows[Index].ShowPosition,
              ' hasShowPosition=', Snapshot.Windows[Index].HasShowPosition,
              ' error=', Snapshot.Windows[Index].ErrorText);
          Last := Snapshot;
        end;
        Sleep(100);
      end;
      Monitor.Stop(2000);
      Writeln('SUMMARY monitor_complete');
    finally
      Monitor.Free;
    end;
    ExitCode := 0;
  except
    on E: Exception do
    begin
      Writeln('FATAL ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.

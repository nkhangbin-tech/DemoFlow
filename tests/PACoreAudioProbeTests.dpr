program PACoreAudioProbeTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  PACoreAudioApi;

procedure Check(Condition: Boolean; const Description: string);
begin
  if not Condition then
    raise Exception.Create('FAIL: ' + Description);
  Writeln('PASS: ', Description);
end;

var
  Percent: Integer;
begin
  try
    Check(ScalarToDisplayPercent(0.0, Percent) and (Percent = 0),
      'zero scalar converts to zero percent');
    Check(ScalarToDisplayPercent(0.5, Percent) and (Percent = 50),
      'midrange scalar converts to display percent');
    Check(ScalarToDisplayPercent(1.0, Percent) and (Percent = 100),
      'maximum scalar converts to one hundred percent');
    Check(not ScalarToDisplayPercent(-0.01, Percent),
      'negative scalar is unavailable');
    Check(not ScalarToDisplayPercent(1.01, Percent),
      'scalar above one is unavailable');
    Check(DeviceStateName(DEVICE_STATE_ACTIVE) = 'active',
      'active endpoint state is named');
    Check(DeviceStateName($80000000) = 'unknown',
      'unknown endpoint state is explicit');
    Writeln('All Core Audio probe tests passed.');
    ExitCode := 0;
  except
    on E: Exception do
    begin
      Writeln(E.Message);
      ExitCode := 1;
    end;
  end;
end.

program PADomainTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  PADomainTypes in '..\Domain\PADomainTypes.pas';

var
  FailureCount: Integer;

procedure AssertEqual(const TestName: string; Expected, Actual: Integer);
begin
  if Expected <> Actual then
  begin
    Inc(FailureCount);
    Writeln('FAIL ', TestName, ': expected ', Expected, ', actual ', Actual);
  end
  else
    Writeln('PASS ', TestName);
end;

procedure AssertTrue(const TestName: string; Condition: Boolean);
begin
  if not Condition then
  begin
    Inc(FailureCount);
    Writeln('FAIL ', TestName);
  end
  else
    Writeln('PASS ', TestName);
end;

procedure RunTests;
var
  Observation: TPowerPointObservation;
  Audio: TAudioState;
begin
  AssertEqual('Clamp lower boundary', 0, ClampPercentage(0));
  AssertEqual('Clamp upper boundary', 100, ClampPercentage(100));
  AssertEqual('Effective nominal zero', 0, CalculateEffectiveVolume(0, 0));
  AssertEqual('Effective nominal maximum', 100,
    CalculateEffectiveVolume(100, 0));
  AssertEqual('Effective positive offset', 65,
    CalculateEffectiveVolume(50, 15));
  AssertEqual('Effective negative offset', 35,
    CalculateEffectiveVolume(50, -15));
  AssertEqual('Effective lower clipping', 0,
    CalculateEffectiveVolume(10, -20));
  AssertEqual('Effective upper clipping', 100,
    CalculateEffectiveVolume(90, 20));
  AssertEqual('Large positive offset clipping', 100,
    CalculateEffectiveVolume(100, MaxInt));
  AssertEqual('Large negative offset clipping', 0,
    CalculateEffectiveVolume(0, -MaxInt));

  Observation := Default(TPowerPointObservation);
  AssertTrue('Default PowerPoint connection is unknown',
    Observation.Connection = pcsUnknown);
  AssertTrue('Default slide index is unavailable',
    not Observation.HasSlideIndex);
  AssertTrue('Default show position is unavailable',
    not Observation.HasShowPosition);
  AssertTrue('Default build is unavailable',
    Observation.Build.Kind = bokUnavailable);

  Audio := Default(TAudioState);
  AssertTrue('Default audio endpoint availability is unknown',
    Audio.Availability = eaUnknown);
  AssertTrue('Default observed audio volume is unavailable',
    not Audio.HasObservedVolume);
  AssertEqual('Default audio delta offset', 0, Audio.DeltaOffsetPercent);
end;

begin
  FailureCount := 0;
  RunTests;
  if FailureCount <> 0 then
  begin
    Writeln(FailureCount, ' test(s) failed.');
    ExitCode := 1;
  end
  else
    Writeln('All domain tests passed.');
  Readln;
end.

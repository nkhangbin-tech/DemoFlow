program PAAudioServiceProbe;

{$APPTYPE CONSOLE}

uses
  System.DateUtils,
  System.SysUtils,
  Winapi.Windows,
  PACoreAudioService;

function HasOption(const Option: string): Boolean;
var
  Index: Integer;
begin
  Result := False;
  for Index := 1 to ParamCount do
    if SameText(ParamStr(Index), Option) then
      Exit(True);
end;

procedure PrintDiagnosticHeartbeat(const Snapshot: TAudioServiceSnapshot);
begin
  Writeln(DateToISO8601(Now, True),
    ' DIAGNOSTIC_HEARTBEAT cached=TRUE sequence=', Snapshot.Sequence,
    ' state=', AudioServiceStateName(Snapshot.State),
    ' endpointId=', Snapshot.EndpointId,
    ' friendlyName=', Snapshot.FriendlyName,
    ' displayPercent=', Snapshot.DisplayPercent,
    ' muted=', Snapshot.Muted,
    ' callbackReceived=', Snapshot.CallbackReceivedCount,
    ' callbackProcessed=', Snapshot.CallbackProcessedCount,
    ' latestCallback=', Snapshot.HasLatestCallback,
    ' source=', Snapshot.LastObservationSource,
    ' event=', Snapshot.LastEventName,
    ' registrationHr=', IntToHex(
      Cardinal(Snapshot.CallbackRegistrationResult), 8),
    ' error=', Snapshot.ErrorText);
end;

function DurationSeconds: Cardinal;
var
  Index: Integer;
  Value: Integer;
begin
  Value := 10;
  for Index := 1 to ParamCount do
    if TryStrToInt(ParamStr(Index), Value) then
      Break;
  if Value < 3 then
    Value := 3;
  if Value > 600 then
    Value := 600;
  Result := Value;
end;

function RequestedVolume(out Percent: Integer): Boolean;
var
  Index: Integer;
begin
  Result := False;
  Percent := 0;
  for Index := 1 to ParamCount - 1 do
    if SameText(ParamStr(Index), '--set') then
    begin
      Percent := StrToIntDef(ParamStr(Index + 1), -1);
      Result := True;
      Exit;
    end;
end;

function EnterWasPressed: Boolean;
var
  InputHandle: THandle;
  ConsoleMode: DWORD;
  NumberOfEvents: DWORD;
  NumberRead: DWORD;
  InputRecord: TInputRecord;
begin
  Result := False;
  InputHandle := GetStdHandle(STD_INPUT_HANDLE);
  if InputHandle = INVALID_HANDLE_VALUE then
    Exit;
  if not GetConsoleMode(InputHandle, ConsoleMode) then
    Exit;
  if WaitForSingleObject(InputHandle, 0) <> WAIT_OBJECT_0 then
    Exit;
  while PeekConsoleInput(InputHandle, InputRecord, 1, NumberOfEvents) and
    (NumberOfEvents > 0) do
  begin
    if not ReadConsoleInput(InputHandle, InputRecord, 1, NumberRead) then
      Exit;
    if (InputRecord.EventType = KEY_EVENT) and
      InputRecord.Event.KeyEvent.bKeyDown and
      (InputRecord.Event.KeyEvent.wVirtualKeyCode = VK_RETURN) then
      Exit(True);
  end;
end;

procedure PrintSnapshot(const Snapshot: TAudioServiceSnapshot);
begin
  Writeln(DateToISO8601(Snapshot.ObservedAt, True),
    ' SNAPSHOT sequence=', Snapshot.Sequence,
    ' state=', AudioServiceStateName(Snapshot.State),
    ' endpoints=', Snapshot.ActiveEndpointCount,
    ' endpointId=', Snapshot.EndpointId,
    ' friendlyName=', Snapshot.FriendlyName,
    ' hasVolume=', Snapshot.HasVolume,
    ' displayPercent=', Snapshot.DisplayPercent,
    ' muted=', Snapshot.Muted,
    ' ownChange=', Snapshot.LastVolumeChangeWasOwn,
    ' ownCount=', Snapshot.OwnVolumeChangeCount,
    ' externalCount=', Snapshot.ExternalVolumeChangeCount,
    ' source=', Snapshot.LastObservationSource,
    ' scalar=', Snapshot.Scalar:0:4,
    ' callbackRegistrationHr=',
      IntToHex(Cardinal(Snapshot.CallbackRegistrationResult), 8),
    ' callbackProcessed=', Snapshot.CallbackProcessedCount,
    ' event=', Snapshot.LastEventName,
    ' error=', Snapshot.ErrorText);
end;

var
  Service: TAudioService;
  Snapshot, LastPrinted: TAudioServiceSnapshot;
  RequestResult: TAudioVolumeRequestResult;
  RequestId: UInt64;
  StartTick: UInt64;
  Duration: Cardinal;
  SetPercent: Integer;
  ErrorText: string;
  Continuous: Boolean;
  HasPrintedSnapshot: Boolean;
  StopSucceeded: Boolean;
  Diagnostics: Boolean;
  NextDiagnosticTick: UInt64;
  TerminationReason: string;
begin
  Continuous := HasOption('--continuous');
  Diagnostics := HasOption('--diagnostics');
  TerminationReason := '';
  Writeln('PROBE_START name=PAAudioServiceProbe');
  Writeln('Presenter Assistant production Core Audio service probe');
  if Continuous then
    Writeln('MODE=continuous read-only; press Enter to stop.')
  else
    Writeln('MODE=one-shot read-only; no volume or mute change is requested.');
  try
    Duration := DurationSeconds;
    Service := TAudioService.Create(Diagnostics);
    try
      Service.Start;
      Writeln('SERVICE_STARTED volumeMode=callback-driven initialRead=once');
      if RequestedVolume(SetPercent) then
      begin
        Writeln('SET_REQUEST_OPT_IN percent=', SetPercent);
        if Service.RequestMasterVolume(SetPercent, RequestId, ErrorText) then
          Writeln('SET_REQUEST_ACCEPTED requestId=', RequestId)
        else
          Writeln('SET_REQUEST_REJECTED error=', ErrorText);
      end;
      HasPrintedSnapshot := False;
      StartTick := GetTickCount64;
      NextDiagnosticTick := StartTick;
      repeat
        if Service.TryGetLatest(Snapshot) and
          ((not HasPrintedSnapshot) or
           AudioSnapshotsMeaningfullyDifferent(LastPrinted, Snapshot)) then
        begin
          PrintSnapshot(Snapshot);
          LastPrinted := Snapshot;
          HasPrintedSnapshot := True;
        end;
        if Diagnostics and (GetTickCount64 >= NextDiagnosticTick) and
          Service.TryGetLatest(Snapshot) then
        begin
          PrintDiagnosticHeartbeat(Snapshot);
          NextDiagnosticTick := GetTickCount64 + 5000;
        end;
        if Continuous then
        begin
          if EnterWasPressed then
          begin
            TerminationReason := 'console-enter';
            Break;
          end;
        end
        else if GetTickCount64 - StartTick >= UInt64(Duration) * 1000 then
        begin
          TerminationReason := 'one-shot-duration';
          Break;
        end;
        Sleep(100);
      until False;
      if RequestedVolume(SetPercent) and
        Service.TryGetRequestResult(RequestId, RequestResult) then
        Writeln('SET_REQUEST_RESULT requestId=', RequestResult.RequestId,
          ' status=', AudioVolumeRequestStatusName(RequestResult.Status),
          ' appliedPercent=', RequestResult.AppliedPercent,
          ' error=', RequestResult.ErrorText);
      StopSucceeded := Service.Stop(2000);
      if TerminationReason = '' then
        TerminationReason := 'loop-ended-without-reason';
      Writeln('TERMINATION reason=', TerminationReason);
      if StopSucceeded then
        Writeln('SHUTDOWN_COMPLETE status=success')
      else
        Writeln('SHUTDOWN_COMPLETE status=timeout');
    finally
      Service.Free;
    end;
    Writeln('PROBE_COMPLETE status=success');
    ExitCode := 0;
  except
    on E: Exception do
    begin
      Writeln('PROBE_COMPLETE status=failure error=', E.ClassName, ': ',
        E.Message);
      ExitCode := 1;
    end;
  end;
end.

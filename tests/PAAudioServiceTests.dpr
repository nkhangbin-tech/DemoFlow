program PAAudioServiceTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  PACoreAudioApi,
  PACoreAudioService;

procedure Check(Condition: Boolean; const Description: string);
begin
  if not Condition then
    raise Exception.Create('FAIL: ' + Description);
  Writeln('PASS: ', Description);
end;

var
  Scalar: Single;
  Context, OwnContext: TGUID;
  Percent: Integer;
  Service: TAudioService;
  Snapshot, ChangedSnapshot: TAudioServiceSnapshot;
  RequestResult: TAudioVolumeRequestResult;
  RequestId: UInt64;
  ErrorText: string;
begin
  try
    Check(IsValidVolumePercent(0) and IsValidVolumePercent(100),
      'volume request accepts inclusive percentage boundaries');
    Check(not IsValidVolumePercent(-1) and not IsValidVolumePercent(101),
      'volume request rejects out-of-range percentages');
    Check(VolumePercentToScalar(23, Scalar) and (Abs(Scalar - 0.23) < 0.001),
      'volume percentage converts to scalar');
    Check(not ScalarToDisplayPercent(-0.1, Percent),
      'invalid scalar remains unavailable');
    Snapshot := Default(TAudioServiceSnapshot);
    Snapshot.State := assAvailable;
    ChangedSnapshot := Snapshot;
    Check(not AudioSnapshotsMeaningfullyDifferent(Snapshot, ChangedSnapshot),
      'identical snapshots are not reported as changed');
    ChangedSnapshot.EndpointId := 'changed-endpoint';
    Check(AudioSnapshotsMeaningfullyDifferent(Snapshot, ChangedSnapshot),
      'endpoint identity change is reported');
    ChangedSnapshot := Snapshot;
    Snapshot.HasVolume := True;
    Snapshot.Scalar := 0.234;
    ChangedSnapshot := Snapshot;
    ChangedSnapshot.Scalar := 0.236;
    Check(AudioVolumeValuesMeaningfullyDifferent(Snapshot, ChangedSnapshot),
      'small scalar change is reported even within same rounded percentage');
    Check(AudioSnapshotsMeaningfullyDifferent(Snapshot, ChangedSnapshot),
      'small scalar change is visible to snapshot filtering');
    ChangedSnapshot := Snapshot;
    ChangedSnapshot.Scalar := 0.50;
    ChangedSnapshot.DisplayPercent := 50;
    Check(AudioVolumeValuesMeaningfullyDifferent(Snapshot, ChangedSnapshot),
      'significant scalar and display change is reported');
    ChangedSnapshot := Snapshot;
    ChangedSnapshot.Muted := True;
    Check(AudioVolumeValuesMeaningfullyDifferent(Snapshot, ChangedSnapshot),
      'mute-only change is reported');
    ChangedSnapshot := Snapshot;
    Check(not AudioSnapshotsMeaningfullyDifferent(Snapshot, ChangedSnapshot),
      'unchanged volume snapshot is suppressed');
    ChangedSnapshot := Snapshot;
    ChangedSnapshot.DisplayPercent := 24;
    Check(AudioSnapshotsMeaningfullyDifferent(Snapshot, ChangedSnapshot),
      'volume change is reported');
    Check(AudioServiceStateName(assNoDefaultEndpoint) =
      'no-default-endpoint', 'no-default state is explicit');
    Check(AudioVolumeRequestStatusName(avrsPending) = 'pending',
      'pending request status is named');
    CreateGUID(OwnContext);
    Context := OwnContext;
    Check(IsOwnAudioEventContext(Context, OwnContext),
      'matching event context is classified as own');
    CreateGUID(Context);
    Check(not IsOwnAudioEventContext(Context, OwnContext),
      'different event context is classified as external');
    Service := TAudioService.Create;
    try
      Check(not Service.TryGetLatest(Snapshot),
        'initial snapshot is unavailable before start');
      Check(not Service.RequestMasterVolume(101, RequestId, ErrorText),
        'invalid request is rejected before enqueue');
      Check(not Service.TryGetRequestResult(999, RequestResult),
        'unknown request result is unavailable');
      Service.Start;
      Service.Start;
      Check(Service.Stop(2000), 'repeated start and stop is safe');
      Check(Service.Stop(2000), 'repeated stop is safe');
      Service.Start;
      Check(Service.Stop(2000), 'service can restart after stopping');
    finally
      Service.Free;
    end;
    Writeln('All Core Audio service tests passed.');
    ExitCode := 0;
  except
    on E: Exception do
    begin
      Writeln(E.Message);
      ExitCode := 1;
    end;
  end;
end.

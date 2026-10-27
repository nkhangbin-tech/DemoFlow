program PALoggerTests;

{$APPTYPE CONSOLE}

uses
  System.Classes,
  System.IOUtils,
  System.SysUtils,
  System.Threading,
  PALogger in '..\Infrastructure\PALogger.pas';

type
  TLoggingThread = class(TThread)
  private
    FLogger: TLogger;
    FIndex: Integer;
  protected
    procedure Execute; override;
  public
    constructor Create(Logger: TLogger; Index: Integer);
  end;

procedure TLoggingThread.Execute;
var
  Index: Integer;
begin
  for Index := 1 to 50 do
    FLogger.Log(lsInfo, Format('thread %d message %d', [FIndex, Index]),
      'worker', UInt64(FIndex * 1000 + Index));
end;

constructor TLoggingThread.Create(Logger: TLogger; Index: Integer);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FLogger := Logger;
  FIndex := Index;
end;

procedure Check(const Condition: Boolean; const Description: string);
begin
  if not Condition then
    raise Exception.Create('FAIL: ' + Description);
  Writeln('PASS: ', Description);
end;

function ReadText(const FileName: string): string;
begin
  Result := TFile.ReadAllText(FileName, TEncoding.UTF8);
end;

procedure RunTests;
var
  Root, LogName, LockedName, Content, Redacted: string;
  Logger, ErrorLogger, OverflowLogger, RotationLogger: TLogger;
  Threads: array of TLoggingThread;
  Index: Integer;
begin
  Root := TPath.Combine(ExtractFilePath(ParamStr(0)), 'logger-test-data');
  if TDirectory.Exists(Root) then
    TDirectory.Delete(Root, True);
  ForceDirectories(Root);
  LogName := TPath.Combine(Root, 'presenter.log');
  try
    Logger := TLogger.Create(LogName, 64, 1024 * 1024, 3);
    try
      Check(Logger.Log(lsDebug, 'debug message', 'test', 1), 'debug accepted');
      Check(Logger.Log(lsInfo, 'info message', 'test', 2), 'info accepted');
      Check(Logger.Log(lsWarning, 'warning message', 'test', 3),
        'warning accepted');
      Check(Logger.Log(lsError, 'error message', 'test', 4),
        'error accepted');
      Check(Logger.Log(lsCritical, 'critical message', 'test', 5,
        'EExample', 'exception details'), 'critical with exception accepted');
      Check(Logger.Log(lsInfo,
        'url https://example.test/watch?id=123&token=secret#fragment',
        'test', 6), 'URL message accepted');
      Check(Logger.Log(lsInfo, 'malformed https://[not valid?x=y', 'test', 7),
        'malformed URL accepted');
      Check(Logger.Log(lsInfo, 'line one' + #13#10 + 'line two', 'test', 8),
        'newline message accepted');
      Check(Logger.Flush(2000), 'flush completes within timeout');
      Check(Logger.Shutdown(2000), 'shutdown flushes and closes the log');
      Content := ReadText(LogName);
      Check(Pos('"severity":"DEBUG"', Content) > 0, 'severity is represented');
      Check(Pos('"category":"test"', Content) > 0, 'category is represented');
      Check(Pos('"correlationId":"5"', Content) > 0,
        'correlation ID is represented');
      Check(Pos('id=123', Content) = 0, 'URL query values are redacted');
      Check(Pos('token=secret', Content) = 0, 'URL secrets are redacted');
      Check(Pos('line one\r\nline two', Content) > 0,
        'newlines are escaped inside one structured entry');
    finally
      Logger.Shutdown(2000);
    end;

    Logger := TLogger.Create(TPath.Combine(Root, 'concurrent.log'), 512);
    SetLength(Threads, 4);
    for Index := 0 to High(Threads) do
    begin
      Threads[Index] := TLoggingThread.Create(Logger, Index);
      Threads[Index].Start;
    end;
    for Index := 0 to High(Threads) do
    begin
      Threads[Index].WaitFor;
      Threads[Index].Free;
    end;
    Check(Logger.Flush(10000), 'concurrent logger can flush');
    Check(Logger.Shutdown(2000), 'concurrent logger shuts down');

    OverflowLogger := TLogger.Create(TPath.Combine(Root, 'overflow.log'), 1);
    try
      for Index := 1 to 1000 do
        OverflowLogger.Log(lsDebug, StringOfChar('x', 1000));
      Check(OverflowLogger.DroppedCount > 0,
        'queue overflow drops messages and counts them');
      Check(OverflowLogger.Log(lsError, 'retained error'), 'error enqueue succeeds');
      OverflowLogger.Flush(2000);
    finally
      OverflowLogger.Shutdown(2000);
      Check(not OverflowLogger.Log(lsInfo, 'after shutdown'),
        'logging after shutdown returns false');
      Check(OverflowLogger.Shutdown(2000), 'shutdown is idempotent');
    end;

    LockedName := TPath.Combine(Root, 'locked');
    ForceDirectories(LockedName);
    ErrorLogger := TLogger.Create(LockedName);
    try
      ErrorLogger.Log(lsError, 'write failure');
      ErrorLogger.Flush(2000);
      Check(ErrorLogger.WriteErrorCount > 0,
        'writer errors are exposed without recursive logging');
    finally
      ErrorLogger.Shutdown(2000);
    end;

    RotationLogger := TLogger.Create(TPath.Combine(Root, 'rotate.log'), 16,
      200, 2);
    try
      for Index := 1 to 20 do
        RotationLogger.Log(lsInfo, StringOfChar('r', 80));
      Check(RotationLogger.Flush(2000), 'rotation logger flushes');
      Check(TFile.Exists(TPath.Combine(Root, 'rotate.log.1')),
        'rotation creates first retained log');
    finally
      RotationLogger.Shutdown(2000);
    end;
    Redacted := TLogger.RedactSensitive(
      'https://example.test/path?secret=one#part');
    Check(Pos('secret=one', Redacted) = 0, 'redaction helper is deterministic');
  finally
    TDirectory.Delete(Root, True);
  end;
end;

begin
  try
    RunTests;
    Writeln('All logger tests passed.');
    ExitCode := 0;
  except
    on E: Exception do
    begin
      Writeln(E.Message);
      ExitCode := 1;
    end;
  end;
  readln;
end.

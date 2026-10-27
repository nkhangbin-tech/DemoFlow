unit PALogger;

interface

uses
  System.Classes,
  System.SysUtils,
  System.SyncObjs;

type
  TLogSeverity = (
    lsDebug,
    lsInfo,
    lsWarning,
    lsError,
    lsCritical
  );

  TLogger = class;

  TLoggerWriterThread = class(TThread)
  private
    FLogger: TLogger;
  protected
    procedure Execute; override;
  public
    constructor Create(Logger: TLogger);
  end;

  TLogger = class
  private
    type
      TLogItem = class
        Severity: TLogSeverity;
        Category: string;
        CorrelationId: UInt64;
        MessageText: string;
        ExceptionClass: string;
        ExceptionMessage: string;
        Timestamp: TDateTime;
      end;
      TLogNode = class
        Item: TLogItem;
        Next: TLogNode;
      end;
  private
    FPath: string;
    FCapacity: Integer;
    FMaxBytes: Int64;
    FRetainedRotations: Integer;
    FQueueHead: TLogNode;
    FQueueTail: TLogNode;
    FQueueCount: Integer;
    FLock: TObject;
    FWakeEvent: TEvent;
    FEmptyEvent: TEvent;
    FStopRequested: Boolean;
    FStoppedEvent: TEvent;
    FWriter: TLoggerWriterThread;
    FDroppedCount: Integer;
    FWriteErrorCount: Integer;
    FLastWriteError: string;
    FWriteStream: TFileStream;
    FWriteBytes: Int64;
    FWriteDisabled: Boolean;
    function TryEnqueue(Item: TLogItem): Boolean;
    function TakeItem(out Item: TLogItem): Boolean;
    function RemoveLowestPriority(out Item: TLogItem): Boolean;
    function QueueIsEmpty: Boolean;
    procedure WriteItem(Item: TLogItem);
    procedure WriteLine(const Line: string);
    procedure RotateIfNeeded(AdditionalBytes: Integer);
    procedure RecordWriteError(const MessageText: string);
    procedure WriterLoop;
    procedure CloseStream;
    class function SeverityName(Severity: TLogSeverity): string; static;
    class function JsonEscape(const Value: string): string; static;
  public
    constructor Create(const FileName: string; Capacity: Integer = 256;
      MaxBytes: Int64 = 1048576; RetainedRotations: Integer = 3);
    destructor Destroy; override;
    function Log(Severity: TLogSeverity; const MessageText: string;
      const Category: string = ''; CorrelationId: UInt64 = 0;
      const ExceptionClass: string = '';
      const ExceptionMessage: string = ''): Boolean;
    function Flush(TimeoutMs: Cardinal = 2000): Boolean;
    function Shutdown(TimeoutMs: Cardinal = 2000): Boolean;
    class function RedactSensitive(const Value: string): string; static;
    property DroppedCount: Integer read FDroppedCount;
    property WriteErrorCount: Integer read FWriteErrorCount;
    property LastWriteError: string read FLastWriteError;
  end;

implementation

uses
  System.DateUtils,
  System.IOUtils,
  System.StrUtils,
  Winapi.Windows;

function SeverityRank(Severity: TLogSeverity): Integer;
begin
  Result := Ord(Severity);
end;

constructor TLoggerWriterThread.Create(Logger: TLogger);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FLogger := Logger;
end;

procedure TLoggerWriterThread.Execute;
begin
  try
    FLogger.WriterLoop;
  except
    on E: Exception do
      FLogger.RecordWriteError(E.Message);
  end;
end;

constructor TLogger.Create(const FileName: string; Capacity: Integer;
  MaxBytes: Int64; RetainedRotations: Integer);
begin
  inherited Create;
  if Capacity < 1 then
    raise EArgumentOutOfRangeException.Create('Logger capacity must be positive.');
  if MaxBytes < 1 then
    raise EArgumentOutOfRangeException.Create('Logger maximum size must be positive.');
  if RetainedRotations < 1 then
    raise EArgumentOutOfRangeException.Create('Logger retention must be positive.');
  FPath := FileName;
  FCapacity := Capacity;
  FMaxBytes := MaxBytes;
  FRetainedRotations := RetainedRotations;
  FLock := TObject.Create;
  FWakeEvent := TEvent.Create(nil, True, False, '');
  FEmptyEvent := TEvent.Create(nil, True, True, '');
  FStoppedEvent := TEvent.Create(nil, True, False, '');
  FWriter := nil;
  try
    try
      ForceDirectories(ExtractFileDir(FPath));
      if TDirectory.Exists(FPath) then
      begin
        FWriteDisabled := True;
        RecordWriteError('Configured log path is a directory.');
      end;
    except
      on E: Exception do
      begin
        FWriteDisabled := True;
        RecordWriteError(E.Message);
      end;
    end;
    FWriter := TLoggerWriterThread.Create(Self);
    FWriter.Start;
  except
    FStoppedEvent.SetEvent;
    FWriter.Free;
    FWriter := nil;
    FStoppedEvent.Free;
    FEmptyEvent.Free;
    FWakeEvent.Free;
    FLock.Free;
    raise;
  end;
end;

destructor TLogger.Destroy;
begin
  if not Shutdown(2000) and (FWriter <> nil) then
  begin
    FWriter.WaitFor;
    FWriter.Free;
    FWriter := nil;
  end;
  FStoppedEvent.Free;
  FEmptyEvent.Free;
  FWakeEvent.Free;
  FLock.Free;
  inherited;
end;

class function TLogger.SeverityName(Severity: TLogSeverity): string;
begin
  case Severity of
    lsDebug: Result := 'DEBUG';
    lsInfo: Result := 'INFO';
    lsWarning: Result := 'WARNING';
    lsError: Result := 'ERROR';
  else
    Result := 'CRITICAL';
  end;
end;

class function TLogger.JsonEscape(const Value: string): string;
var
  Character: Char;
begin
  Result := '';
  for Character in Value do
    case Character of
      '"': Result := Result + '\"';
      '\': Result := Result + '\\';
      #8: Result := Result + '\b';
      #9: Result := Result + '\t';
      #10: Result := Result + '\n';
      #12: Result := Result + '\f';
      #13: Result := Result + '\r';
    else
      if Ord(Character) < 32 then
        Result := Result + '\u' + IntToHex(Ord(Character), 4)
      else
        Result := Result + Character;
    end;
end;

class function TLogger.RedactSensitive(const Value: string): string;
var
  StartIndex, Cursor, SchemeLength, QueryIndex, FragmentIndex: Integer;
  Scheme, Candidate: string;
begin
  Result := Value;
  StartIndex := 1;
  while StartIndex <= Length(Result) do
  begin
    if StartsText('https://', Copy(Result, StartIndex, MaxInt)) then
    begin
      Scheme := 'https://';
      SchemeLength := Length(Scheme);
    end
    else if StartsText('http://', Copy(Result, StartIndex, MaxInt)) then
    begin
      Scheme := 'http://';
      SchemeLength := Length(Scheme);
    end
    else
    begin
      Inc(StartIndex);
      Continue;
    end;
    Cursor := StartIndex + SchemeLength;
    while (Cursor <= Length(Result)) and
      not CharInSet(Result[Cursor], [' ', #9, #10, #13, '"', '''', '<', '>',
      ')', ']', '}']) do
      Inc(Cursor);
    Candidate := Copy(Result, StartIndex, Cursor - StartIndex);
    QueryIndex := Pos('?', Candidate);
    FragmentIndex := Pos('#', Candidate);
    if (QueryIndex > 0) and (FragmentIndex > 0) then
      if FragmentIndex < QueryIndex then
        QueryIndex := FragmentIndex;
    if QueryIndex = 0 then
      QueryIndex := FragmentIndex;
    if QueryIndex > 0 then
    begin
      Candidate := Copy(Candidate, 1, QueryIndex - 1) + '?[redacted]';
      Delete(Result, StartIndex, Cursor - StartIndex);
      Insert(Candidate, Result, StartIndex);
      Cursor := StartIndex + Length(Candidate);
    end;
    StartIndex := Cursor;
  end;
end;

function TLogger.RemoveLowestPriority(out Item: TLogItem): Boolean;
var
  Node, Previous, Lowest, LowestPrevious: TLogNode;
begin
  Result := False;
  Item := nil;
  Node := FQueueHead;
  Previous := nil;
  Lowest := nil;
  LowestPrevious := nil;
  while Node <> nil do
  begin
    if (Lowest = nil) or
      (SeverityRank(Node.Item.Severity) < SeverityRank(Lowest.Item.Severity)) then
    begin
      Lowest := Node;
      LowestPrevious := Previous;
    end;
    Previous := Node;
    Node := Node.Next;
  end;
  if Lowest = nil then
    Exit;
  if LowestPrevious = nil then
    FQueueHead := Lowest.Next
  else
    LowestPrevious.Next := Lowest.Next;
  if FQueueTail = Lowest then
    FQueueTail := LowestPrevious;
  Dec(FQueueCount);
  Item := Lowest.Item;
  Lowest.Free;
  Result := True;
end;

function TLogger.TryEnqueue(Item: TLogItem): Boolean;
var
  Node: TLogNode;
  DroppedItem: TLogItem;
begin
  Result := False;
  TMonitor.Enter(FLock);
  try
    if FStopRequested then
      Exit;
    if FQueueCount >= FCapacity then
    begin
      if SeverityRank(Item.Severity) < SeverityRank(lsWarning) then
      begin
        TInterlocked.Increment(FDroppedCount);
        Exit;
      end;
      DroppedItem := nil;
      if not RemoveLowestPriority(DroppedItem) then
      begin
        TInterlocked.Increment(FDroppedCount);
        Exit;
      end;
      DroppedItem.Free;
      TInterlocked.Increment(FDroppedCount);
    end;
    Node := TLogNode.Create;
    Node.Item := Item;
    if FQueueTail = nil then
      FQueueHead := Node
    else
      FQueueTail.Next := Node;
    FQueueTail := Node;
    Inc(FQueueCount);
    FEmptyEvent.ResetEvent;
    FWakeEvent.SetEvent;
    Result := True;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TLogger.Log(Severity: TLogSeverity; const MessageText, Category: string;
  CorrelationId: UInt64; const ExceptionClass, ExceptionMessage: string): Boolean;
var
  Item: TLogItem;
begin
  Item := TLogItem.Create;
  Item.Severity := Severity;
  Item.Category := RedactSensitive(Category);
  Item.CorrelationId := CorrelationId;
  Item.MessageText := RedactSensitive(MessageText);
  Item.ExceptionClass := RedactSensitive(ExceptionClass);
  Item.ExceptionMessage := RedactSensitive(ExceptionMessage);
  Item.Timestamp := Now;
  Result := TryEnqueue(Item);
  if not Result then
    Item.Free;
end;

function TLogger.TakeItem(out Item: TLogItem): Boolean;
var
  Node: TLogNode;
begin
  TMonitor.Enter(FLock);
  try
    Node := FQueueHead;
    if Node = nil then
    begin
      Item := nil;
      Exit(False);
    end;
    FQueueHead := Node.Next;
    if FQueueTail = Node then
      FQueueTail := nil;
    Dec(FQueueCount);
    Item := Node.Item;
    Node.Free;
    Result := True;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TLogger.QueueIsEmpty: Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := FQueueCount = 0;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TLogger.RecordWriteError(const MessageText: string);
begin
  TInterlocked.Increment(FWriteErrorCount);
  TMonitor.Enter(FLock);
  try
    FLastWriteError := MessageText;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TLogger.CloseStream;
begin
  FreeAndNil(FWriteStream);
  FWriteBytes := 0;
end;

procedure TLogger.RotateIfNeeded(AdditionalBytes: Integer);
var
  Index: Integer;
  SourceName, TargetName: string;
begin
  if (FWriteStream = nil) or (FWriteBytes + AdditionalBytes <= FMaxBytes) then
    Exit;
  CloseStream;
  for Index := FRetainedRotations - 1 downto 1 do
  begin
    SourceName := FPath + '.' + IntToStr(Index);
    TargetName := FPath + '.' + IntToStr(Index + 1);
    if TFile.Exists(SourceName) then
      MoveFileEx(PChar(SourceName), PChar(TargetName), MOVEFILE_REPLACE_EXISTING);
  end;
  if TFile.Exists(FPath) then
    MoveFileEx(PChar(FPath), PChar(FPath + '.1'), MOVEFILE_REPLACE_EXISTING);
end;

procedure TLogger.WriteLine(const Line: string);
var
  Bytes: TBytes;
begin
  if FWriteDisabled then
    Exit;
  if FWriteStream = nil then
  begin
    ForceDirectories(ExtractFileDir(FPath));
    if TFile.Exists(FPath) then
      FWriteStream := TFileStream.Create(FPath, fmOpenReadWrite or fmShareDenyNone)
    else
      FWriteStream := TFileStream.Create(FPath, fmCreate or fmShareDenyNone);
    FWriteStream.Position := FWriteStream.Size;
    FWriteBytes := FWriteStream.Size;
  end;
  Bytes := TEncoding.UTF8.GetBytes(Line + sLineBreak);
  RotateIfNeeded(Length(Bytes));
  if FWriteStream = nil then
  begin
    if TFile.Exists(FPath) then
      FWriteStream := TFileStream.Create(FPath, fmOpenReadWrite or fmShareDenyNone)
    else
      FWriteStream := TFileStream.Create(FPath, fmCreate or fmShareDenyNone);
    FWriteStream.Position := FWriteStream.Size;
    FWriteBytes := FWriteStream.Size;
  end;
  FWriteStream.WriteBuffer(Bytes, Length(Bytes));
  FlushFileBuffers(FWriteStream.Handle);
  Inc(FWriteBytes, Length(Bytes));
end;

procedure TLogger.WriteItem(Item: TLogItem);
var
  Line: string;
begin
  Line := Format('{"timestamp":"%s","severity":"%s","category":"%s",' +
    '"correlationId":"%d","message":"%s"',
    [JsonEscape(DateToISO8601(Item.Timestamp, True)),
     SeverityName(Item.Severity), JsonEscape(Item.Category),
     Item.CorrelationId, JsonEscape(Item.MessageText)]);
  if Item.ExceptionClass <> '' then
    Line := Line + Format(',"exceptionClass":"%s","exceptionMessage":"%s"',
      [JsonEscape(Item.ExceptionClass), JsonEscape(Item.ExceptionMessage)]);
  Line := Line + '}';
  WriteLine(Line);
end;

procedure TLogger.WriterLoop;
var
  Item: TLogItem;
  WaitResult: TWaitResult;
begin
  try
    while True do
    begin
      while TakeItem(Item) do
      begin
        try
          WriteItem(Item);
        except
          on E: Exception do
            RecordWriteError(E.Message);
        end;
        Item.Free;
        if QueueIsEmpty then
          FEmptyEvent.SetEvent;
      end;
      TMonitor.Enter(FLock);
      try
        if FStopRequested and (FQueueCount = 0) then
          Break;
        FWakeEvent.ResetEvent;
      finally
        TMonitor.Exit(FLock);
      end;
      WaitResult := FWakeEvent.WaitFor(250);
      if WaitResult = wrError then
        RecordWriteError('Logger wake event failed.');
    end;
  finally
    CloseStream;
    FStoppedEvent.SetEvent;
  end;
end;

function TLogger.Flush(TimeoutMs: Cardinal): Boolean;
begin
  if FWriter = nil then
    Exit(True);
  if QueueIsEmpty then
    Exit(True);
  Result := FEmptyEvent.WaitFor(TimeoutMs) = wrSignaled;
end;

function TLogger.Shutdown(TimeoutMs: Cardinal): Boolean;
var
  Node: TLogNode;
begin
  if FWriter = nil then
    Exit(True);
  TMonitor.Enter(FLock);
  try
    FStopRequested := True;
    FWakeEvent.SetEvent;
  finally
    TMonitor.Exit(FLock);
  end;
  Result := FStoppedEvent.WaitFor(TimeoutMs) = wrSignaled;
  if Result then
  begin
    FWriter.WaitFor;
    FWriter.Free;
    FWriter := nil;
    TMonitor.Enter(FLock);
    try
      while FQueueHead <> nil do
      begin
        Node := FQueueHead;
        FQueueHead := Node.Next;
        Node.Item.Free;
        Node.Free;
      end;
      FQueueTail := nil;
      FQueueCount := 0;
      FEmptyEvent.SetEvent;
    finally
      TMonitor.Exit(FLock);
    end;
  end;
end;

end.

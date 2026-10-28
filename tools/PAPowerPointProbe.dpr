program PAPowerPointProbe;

{$APPTYPE CONSOLE}

uses
  System.Win.ComObj,
  System.DateUtils,
  System.SysUtils,
  System.Variants,
  Winapi.ActiveX,
  Winapi.Windows;

type
  TProbeSnapshot = record
    Connected: Boolean;
    WindowCount: Integer;
    Description: string;
  end;

function TimestampText: string;
begin
  Result := DateToISO8601(Now, True);
end;

procedure Report(const Text: string);
begin
  Writeln(TimestampText, ' ', Text);
end;

function TryVariantInteger(const Value: OleVariant; out Number: Integer): Boolean;
var
  Converted: Variant;
begin
  Result := False;
  Number := 0;
  if VarIsEmpty(Value) or VarIsNull(Value) then
    Exit;
  try
    Converted := VarAsType(Value, varInteger);
    Number := Converted;
    Result := True;
  except
    on E: Exception do
      Report('READ_ERROR field=integer value="' + E.Message + '"');
  end;
end;

procedure ClearVariant(var Value: OleVariant);
begin
  if not VarIsEmpty(Value) then
    VarClear(Value);
end;

function TryAttach(out PowerPoint: OleVariant; out ErrorText: string): Boolean;
var
  ClassId: TCLSID;
  Unknown: IUnknown;
  Dispatch: IDispatch;
  ResultCode: HRESULT;
begin
  PowerPoint := Unassigned;
  ErrorText := '';
  ResultCode := CLSIDFromProgID('PowerPoint.Application', ClassId);
  if Failed(ResultCode) then
  begin
    ErrorText := 'CLSIDFromProgID hresult=' +
      IntToHex(Cardinal(ResultCode), 8);
    Exit(False);
  end;
  ResultCode := GetActiveObject(ClassId, nil, Unknown);
  if Failed(ResultCode) then
  begin
    ErrorText := 'GetActiveObject hresult=' +
      IntToHex(Cardinal(ResultCode), 8);
    Exit(False);
  end;
  ResultCode := Unknown.QueryInterface(StringToGUID(
    '{00020400-0000-0000-C000-000000000046}'), Dispatch);
  if Failed(ResultCode) then
  begin
    ErrorText := 'QueryInterface(IDispatch) hresult=' +
      IntToHex(Cardinal(ResultCode), 8);
    Exit(False);
  end;
  Dispatch._AddRef;
  TVarData(PowerPoint).VType := varDispatch;
  TVarData(PowerPoint).VDispatch := Pointer(Dispatch);
  Dispatch := nil;
  Result := True;
end;

function ReadSnapshot(const PowerPoint: OleVariant;
  out Snapshot: TProbeSnapshot): Boolean;
var
  SlideShowWindows, SlideShowWindow, View, Slide: OleVariant;
  Count, Index, SlideIndex, ShowPosition: Integer;
  SlideError, PositionError: string;
  ItemText: string;
begin
  Snapshot.Connected := True;
  Snapshot.WindowCount := 0;
  Snapshot.Description := '';
  try
    SlideShowWindows := PowerPoint.SlideShowWindows;
    try
      Count := SlideShowWindows.Count;
      Snapshot.WindowCount := Count;
      if Count = 0 then
        Snapshot.Description := 'CONNECTED slideshowWindows=0'
      else
      begin
        Snapshot.Description := 'CONNECTED slideshowWindows=' +
          IntToStr(Count);
        for Index := 1 to Count do
        begin
          SlideShowWindow := SlideShowWindows.Item(Index);
          try
            View := SlideShowWindow.View;
            try
              Slide := View.Slide;
              try
                try
                  SlideIndex := Slide.SlideIndex;
                  ItemText := 'slideIndex=' + IntToStr(SlideIndex)
                except
                  on E: Exception do
                  begin
                    SlideError := E.ClassName + ': ' + E.Message;
                    ItemText := 'slideIndex=unavailable(' + SlideError + ')';
                  end;
                end;
                try
                  ShowPosition := View.CurrentShowPosition;
                  ItemText := ItemText + ' showPosition=' +
                    IntToStr(ShowPosition)
                except
                  on E: Exception do
                  begin
                    PositionError := E.ClassName + ': ' + E.Message;
                    ItemText := ItemText + ' showPosition=unavailable(' +
                      PositionError + ')';
                  end;
                end;
                Snapshot.Description := Snapshot.Description + ' window=' +
                  IntToStr(Index) + ' ' + ItemText;
              finally
                ClearVariant(Slide);
              end;
            finally
              ClearVariant(View);
            end;
          finally
            ClearVariant(SlideShowWindow);
          end;
        end;
      end;
    finally
      ClearVariant(SlideShowWindows);
    end;
    Result := True;
  except
    on E: Exception do
    begin
      Snapshot.Connected := False;
      Snapshot.Description := 'CONNECTION_ERROR ' + E.ClassName + ': ' +
        E.Message;
      Result := False;
    end;
  end;
end;

function ParseDuration: Cardinal;
var
  Requested: Integer;
begin
  Result := 45;
  if ParamCount < 1 then
    Exit;
  Requested := StrToIntDef(ParamStr(1), 45);
  if Requested < 5 then
    Requested := 5;
  if Requested > 600 then
    Requested := 600;
  Result := Requested;
end;

var
  PowerPoint: OleVariant;
  Snapshot, Previous: TProbeSnapshot;
  ComInitialized: Boolean;
  ComResult: HRESULT;
  StartTick: UInt64;
  DurationSeconds: Cardinal;
  ErrorText: string;
  Attached: Boolean;
begin
  DurationSeconds := ParseDuration;
  Writeln('Presenter Assistant PowerPoint COM diagnostic probe');
  Writeln('Read-only polling; duration=', DurationSeconds,
    ' seconds, interval=500 milliseconds.');
  Writeln('This probe never launches, activates, navigates, saves, or closes PowerPoint.');

  ComInitialized := False;
  try
    ComResult := CoInitialize(nil);
    if Failed(ComResult) then
    begin
      Report('FATAL COM_INITIALIZATION_FAILED hresult=' +
        IntToHex(Cardinal(ComResult), 8));
      ExitCode := 1;
      Exit;
    end;
    ComInitialized := True;
    Previous.Connected := False;
    Previous.WindowCount := -1;
    Previous.Description := '';
    Attached := False;
    StartTick := GetTickCount64;
    while GetTickCount64 - StartTick < UInt64(DurationSeconds) * 1000 do
    begin
      if not Attached then
      begin
        if TryAttach(PowerPoint, ErrorText) then
        begin
          Attached := True;
          Report('ATTACHED PowerPoint.Application');
        end
        else
        begin
          Report('UNAVAILABLE PowerPoint.Application ' + ErrorText);
          Sleep(500);
          Continue;
        end;
      end;
      if ReadSnapshot(PowerPoint, Snapshot) then
      begin
        if (Snapshot.Description <> Previous.Description) or
          (not Previous.Connected) then
        begin
          if (Snapshot.WindowCount > 0) and (Previous.WindowCount = 0) then
            Report('TRANSITION slideshow_started');
          if (Snapshot.WindowCount = 0) and (Previous.WindowCount > 0) then
            Report('TRANSITION slideshow_ended');
          Report(Snapshot.Description);
        end;
        Previous := Snapshot;
      end
      else
      begin
        Report(Snapshot.Description);
        ClearVariant(PowerPoint);
        Attached := False;
        Previous.Connected := False;
        Previous.WindowCount := -1;
        Previous.Description := '';
      end;
      Sleep(500);
    end;
    Report('SUMMARY probe_complete');
    ExitCode := 0;
  finally
    ClearVariant(PowerPoint);
    if ComInitialized then
      CoUninitialize;
  end;
  readln;
end.

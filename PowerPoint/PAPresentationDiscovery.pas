unit PAPresentationDiscovery;

interface
uses System.Classes;
type
  TPresentationCandidate = record
    WindowKey: NativeUInt;
    Title, FullName, FileName: string;
    SlideCount: Integer;
  end;
  TPresentationCandidates = TArray<TPresentationCandidate>;
// Typed PowerPoint DocumentWindow getter; do not late-bind HWND.
function ReadDocumentWindowKey(const Window: IDispatch): NativeUInt;
function DiscoverPresentations(out ErrorText: string): TPresentationCandidates;
function ResolvePresentation(const Candidate: TPresentationCandidate;
  out Current: TPresentationCandidate; out ErrorText: string): Boolean;
function SamePresentation(const A, B: TPresentationCandidate): Boolean;
function FindPresentation(const Items: TPresentationCandidates; const Candidate: TPresentationCandidate;
  out Current: TPresentationCandidate): Boolean;

implementation
uses System.SysUtils, System.Variants, System.Win.ComObj, Winapi.ActiveX,
  Winapi.Windows, PowerPoint_TLB;
function ReadDocumentWindowKey(const Window: IDispatch): NativeUInt;
var Document: PowerPoint_TLB.DocumentWindow;
begin
  // HWND is unavailable through this server's dispatch surface (including
  // dispid 2020). Query the imported dual interface and use its vtable getter.
  Document := Window as PowerPoint_TLB.DocumentWindow;
  Result := NativeUInt(Cardinal(Document.HWND_));
end;

function DiscoveryDiagnostic(const Member: string; WindowIndex: Integer;
  E: Exception): string;
begin
  Result := Format('PowerPoint window %d: %s failed (%s', [WindowIndex, Member, E.ClassName]);
  if E is EOleSysError then
    Result := Result + ', HRESULT=0x' + IntToHex(Cardinal(EOleSysError(E).ErrorCode), 8);
  Result := Result + '): ' + E.Message;
end;

type
  // Dedicated short-lived STA owns every discovery COM reference. No callbacks,
  // monitor state, live interface or COM Variant crosses the worker boundary.
  TDiscoveryWorker = class(TThread)
  public
    Candidates: TPresentationCandidates;
    ErrorText: string;
    procedure Execute; override;
  end;
procedure TDiscoveryWorker.Execute;
var
  HR: HRESULT;
  Id: TGUID;
  Unknown: IUnknown;
  App, Windows, Window, Pres: OleVariant;
  C: TPresentationCandidate;
  I, CurrentWindowIndex: Integer;
  Member: string;
begin
  CurrentWindowIndex := 0; Member := 'CoInitializeEx';
  HR := CoInitializeEx(nil, COINIT_APARTMENTTHREADED);
  if Failed(HR) then begin ErrorText := 'Cannot initialize PowerPoint discovery STA.'; Exit; end;
  try
    try
      Member := 'GetActiveObject';
      Id := StringToGUID('{91493441-5A91-11CF-8700-00AA0060263B}');
      if Failed(GetActiveObject(Id, nil, Unknown)) then Exit;
      App := Unknown as IDispatch;
      Member := 'Application.Windows';
      Windows := App.Windows; // Document windows only, never SlideShowWindows.
      Member := 'DocumentWindows.Count';
      for I := 1 to Windows.Count do
      begin
        CurrentWindowIndex := I;
        try
          Member := 'DocumentWindows.Item';
          Window := Windows.Item(I);
          Member := 'DocumentWindow.Presentation';
          Pres := Window.Presentation;
          Member := 'Presentation.Path';
          if string(Pres.Path) = '' then Continue; // Unsaved presentations excluded.
          C := Default(TPresentationCandidate);
          Member := 'DocumentWindow.HWND_ (typed interface)';
          C.WindowKey := ReadDocumentWindowKey(IDispatch(Window));
          Member := 'DocumentWindow.Caption';
          C.Title := Window.Caption;
          Member := 'Presentation.FullName';
          C.FullName := Pres.FullName;
          C.FileName := ExtractFileName(C.FullName);
          Member := 'Presentation.Slides.Count';
          C.SlideCount := Pres.Slides.Count;
          if (C.WindowKey <> 0) and (C.FileName <> '') and (C.SlideCount >= 0) then
          begin
            SetLength(Candidates, Length(Candidates) + 1);
            Candidates[High(Candidates)] := C;
          end;
        except
          on E: Exception do ErrorText := DiscoveryDiagnostic(Member, CurrentWindowIndex, E);
        end;
        VarClear(Pres); VarClear(Window);
      end;
    except
      on E: Exception do begin Candidates := nil; ErrorText := DiscoveryDiagnostic(Member, CurrentWindowIndex, E); end;
    end;
  finally
    VarClear(Pres); VarClear(Window); VarClear(Windows); VarClear(App);
    Unknown := nil;
    CoUninitialize;
  end;
end;
function DiscoverPresentations(out ErrorText: string): TPresentationCandidates;
var W: TDiscoveryWorker;
begin
  W := TDiscoveryWorker.Create(True);
  W.FreeOnTerminate := False;
  try
    W.Start; W.WaitFor;
    Result := Copy(W.Candidates); ErrorText := W.ErrorText;
  finally W.Free; end;
end;
function SamePresentation(const A, B: TPresentationCandidate): Boolean;
begin
  Result := (A.WindowKey = B.WindowKey) and SameText(A.FullName, B.FullName) and
    (A.SlideCount = B.SlideCount);
end;
function FindPresentation(const Items: TPresentationCandidates; const Candidate: TPresentationCandidate;
  out Current: TPresentationCandidate): Boolean;
var C: TPresentationCandidate;
begin
  Current := Default(TPresentationCandidate);
  for C in Items do
    if SamePresentation(Candidate, C) then begin Current := C; Exit(True); end;
  Result := False;
end;
function ResolvePresentation(const Candidate: TPresentationCandidate;
  out Current: TPresentationCandidate; out ErrorText: string): Boolean;
var Items: TPresentationCandidates;
begin
  Current := Default(TPresentationCandidate);
  Items := DiscoverPresentations(ErrorText);
  if FindPresentation(Items, Candidate, Current) then Exit(True);
  if ErrorText = '' then
    ErrorText := 'Selected PowerPoint window closed or presentation changed. Refresh and select again.';
  Result := False;
end;
end.

unit PASceneProjectSession;

interface

uses
  PASceneDomain, PASceneProjectFileStore, PAPresentationDiscovery;

type
  TProjectSaveStatus = (psSaved, psSaveAsRequired, psCancelled, psFailed);
  TProjectSaveResult = record
    Status: TProjectSaveStatus;
    ErrorMessage: string;
  end;

  // Owns authoring state only. No compiler, navigation, VCL or audio dependency.
  TSceneProjectSession = class
  private
    FDocument: TSceneAuthoringSnapshot;
    FSource: TSceneFileLoadResult;
    FSelectedIndex: Integer;
    FModified: Boolean;
    FHasActiveContext: Boolean;
    FPresentation: TPresentationCandidate;
    FLegacyBinding: Boolean;
    function GetSceneCount: Integer;
    function GetProjectBase: Integer;
    procedure SetProjectBase(Value: Integer);
    function GetActivePath: string;
    function GetSourceVersion: Integer;
    function GetHasSavedProject: Boolean;
    procedure AdoptSavedPath(const AbsolutePath: string);
  public
    constructor Create;
    procedure NewProject;
    // Called only after the UI confirms discard or completes Save successfully.
    procedure CloseProject;
    // Pure authoring eligibility, not the environmental Readiness Check.
    function CanEnterReadiness(HasPendingInspectorError: Boolean): Boolean;
    function GetDocument: TSceneAuthoringSnapshot;
    function GetScene(Index: Integer): TSceneDefinition;
    procedure SelectScene(Index: Integer);
    function AddScene(Kind: TSceneKind): Integer;
    procedure RemoveSelected;
    procedure MoveSelected(Delta: Integer);
    function TrySetSceneVolume(Index, Value: Integer): Boolean;
    function OpenProject(const FileName: string): TSceneFileLoadResult;
    function Save: TProjectSaveResult;
    // Empty target means cancellation; do not adopt path/version on failure.
    function SaveAs(const FileName: string): TProjectSaveResult;
    // Candidate is prepared off-session; adoption is the only replacement point.
    procedure AdoptCandidate(Candidate: TSceneProjectSession);
    procedure PrepareNew(const Presentation: TPresentationCandidate);
    function BindPresentation(const Presentation: TPresentationCandidate;
      ConfirmLegacy: Boolean; out ErrorText: string): Boolean;
    property HasActiveContext: Boolean read FHasActiveContext;
    property HasSavedProject: Boolean read GetHasSavedProject;
    property Presentation: TPresentationCandidate read FPresentation;
    property LegacyBinding: Boolean read FLegacyBinding;
    property SceneCount: Integer read GetSceneCount;
    property SelectedIndex: Integer read FSelectedIndex;
    property PresentationBaseVolumePercent: Integer read GetProjectBase write SetProjectBase;
    property ActivePath: string read GetActivePath;
    property SourceFormatVersion: Integer read GetSourceVersion;
    property Modified: Boolean read FModified;
  end;

function ActiveProjectSession: TSceneProjectSession;
function TryParseSceneVolumeText(const Text: string; out Value: Integer): Boolean;

implementation

uses
  System.SysUtils, System.IOUtils, PARecentProject;

var ApplicationSession: TSceneProjectSession;
function ActiveProjectSession: TSceneProjectSession;
begin
  if ApplicationSession = nil then ApplicationSession := TSceneProjectSession.Create;
  Result := ApplicationSession;
end;

function CopyDocument(const Value: TSceneAuthoringSnapshot): TSceneAuthoringSnapshot;
begin
  Result := Value;
  Result.Scenes := Copy(Value.Scenes);
end;

function TryParseSceneVolumeText(const Text: string; out Value: Integer): Boolean;
var
  S: string;
  C: Char;
begin
  S := Trim(Text);
  Value := 0;
  if S = '-1' then
  begin
    Value := -1;
    Exit(True);
  end;
  if S = '' then Exit(False);
  for C in S do
    if not CharInSet(C, ['0'..'9']) then Exit(False);
  Result := TryStrToInt(S, Value) and (Value >= 0) and (Value <= 100);
end;

constructor TSceneProjectSession.Create;
begin
  inherited Create;
  NewProject;
end;

procedure TSceneProjectSession.NewProject;
begin
  FHasActiveContext := False;
  FPresentation := Default(TPresentationCandidate);
  FLegacyBinding := False;
  FDocument := NewSceneProject;
  FSource := Default(TSceneFileLoadResult);
  FSelectedIndex := -1;
  FModified := False;
end;

procedure TSceneProjectSession.CloseProject;
begin
  // Reset only in-memory context. Saved files and the recent record are untouched.
  NewProject;
end;

function TSceneProjectSession.GetHasSavedProject: Boolean;
begin
  // A legacy binding has not persisted the current presentation context until
  // explicit Save As v3 succeeds. A displayed filename alone is never enough.
  Result := FHasActiveContext and FSource.Success and
    FSource.DocumentResult.Success and (FSource.SourceFileName <> '') and
    (FSource.DocumentResult.SourceFormatVersion = 3) and not FLegacyBinding;
end;

function TSceneProjectSession.CanEnterReadiness(HasPendingInspectorError: Boolean): Boolean;
begin
  Result := False;
  if HasPendingInspectorError or not FHasActiveContext or not HasSavedProject or
    FModified or (SceneCount = 0) then Exit;
  Result := Length(ValidateSceneList(FDocument)) = 0;
end;

function TSceneProjectSession.GetDocument: TSceneAuthoringSnapshot;
begin
  Result := CopyDocument(FDocument);
end;

function TSceneProjectSession.GetSceneCount: Integer;
begin
  Result := Length(FDocument.Scenes);
end;

function TSceneProjectSession.GetScene(Index: Integer): TSceneDefinition;
begin
  if (Index < 0) or (Index >= SceneCount) then
    raise ERangeError.Create('Scene index is out of range.');
  Result := FDocument.Scenes[Index];
end;

procedure TSceneProjectSession.SelectScene(Index: Integer);
begin
  if (Index < -1) or (Index >= SceneCount) then
    raise ERangeError.Create('Selected Scene index is out of range.');
  FSelectedIndex := Index;
end;

function TSceneProjectSession.AddScene(Kind: TSceneKind): Integer;
var
  Scene: TSceneDefinition;
begin
  if not (Kind in [skPowerPoint, skBrowser, skExternalApp]) then
    raise EArgumentException.Create('Unsupported new Scene kind.');
  Scene := Default(TSceneDefinition);
  Scene.SceneId := TGUID.NewGuid.ToString;
  Scene.SceneKind := Kind;
  Scene.ExplicitVolumePercent := -1;
  // Missing slide/targets remain an incomplete draft; never invent valid data.
  Result := FSelectedIndex + 1;
  Insert(Scene, FDocument.Scenes, Result);
  FSelectedIndex := Result;
  FModified := True;
end;

procedure TSceneProjectSession.RemoveSelected;
begin
  if FSelectedIndex < 0 then Exit;
  Delete(FDocument.Scenes, FSelectedIndex, 1);
  if FSelectedIndex >= SceneCount then FSelectedIndex := SceneCount - 1;
  FModified := True;
end;

procedure TSceneProjectSession.MoveSelected(Delta: Integer);
var
  Target: Integer;
  Scene: TSceneDefinition;
begin
  if (Delta <> -1) and (Delta <> 1) then
    raise EArgumentException.Create('Move must be one position.');
  if FSelectedIndex < 0 then Exit;
  Target := FSelectedIndex + Delta;
  if (Target < 0) or (Target >= SceneCount) then Exit;
  Scene := FDocument.Scenes[Target];
  FDocument.Scenes[Target] := FDocument.Scenes[FSelectedIndex];
  FDocument.Scenes[FSelectedIndex] := Scene;
  FSelectedIndex := Target;
  FModified := True;
end;

function TSceneProjectSession.TrySetSceneVolume(Index, Value: Integer): Boolean;
begin
  Result := (Index >= 0) and (Index < SceneCount) and (Value >= -1) and (Value <= 100);
  if not Result then Exit;
  if FDocument.Scenes[Index].ExplicitVolumePercent <> Value then
  begin
    FDocument.Scenes[Index].ExplicitVolumePercent := Value;
    FModified := True;
  end;
end;

function TSceneProjectSession.GetProjectBase: Integer;
begin
  Result := FDocument.PresentationBaseVolumePercent;
end;

procedure TSceneProjectSession.SetProjectBase(Value: Integer);
begin
  if (Value < 0) or (Value > 100) then
    raise EArgumentOutOfRangeException.Create('Project base volume must be 0..100.');
  if FDocument.PresentationBaseVolumePercent <> Value then
  begin
    FDocument.PresentationBaseVolumePercent := Value;
    FModified := True;
  end;
end;

function TSceneProjectSession.GetActivePath: string;
begin
  Result := FSource.SourceFileName;
end;

function TSceneProjectSession.GetSourceVersion: Integer;
begin
  Result := FSource.DocumentResult.SourceFormatVersion;
end;

function TSceneProjectSession.OpenProject(const FileName: string): TSceneFileLoadResult;
begin
  Result := LoadSceneProject(FileName);
  if not Result.Success then Exit;
  FHasActiveContext := False;
  FLegacyBinding := False;
  FPresentation := Default(TPresentationCandidate);
  FDocument := CopyDocument(Result.DocumentResult.Document);
  FSource := Result;
  FSource.DocumentResult.Document := CopyDocument(Result.DocumentResult.Document);
  FSelectedIndex := -1;
  FModified := False;
end;

procedure TSceneProjectSession.AdoptSavedPath(const AbsolutePath: string);
begin
  FSource := Default(TSceneFileLoadResult);
  FSource.Success := True;
  FSource.SourceFileName := AbsolutePath;
  FSource.DocumentResult.Success := True;
  FSource.DocumentResult.SourceFormatVersion := 2 + Ord(FDocument.PowerPointFileName <> '');
  FSource.DocumentResult.Document := CopyDocument(FDocument);
  FModified := False;
  RecordRecentProject(AbsolutePath);
end;

function TSceneProjectSession.Save: TProjectSaveResult;
var
  R: TSceneFileOperationResult;
begin
  Result := Default(TProjectSaveResult);
  if (ActivePath = '') or (SourceFormatVersion in [1, 2]) then
  begin
    Result.Status := psSaveAsRequired;
    Exit;
  end;
  R := SaveSceneProject(ActivePath, FDocument);
  if not R.Success then
  begin
    Result.Status := psFailed;
    Result.ErrorMessage := R.ErrorMessage;
    Exit;
  end;
  AdoptSavedPath(ActivePath);
  Result.Status := psSaved;
end;

function TSceneProjectSession.SaveAs(const FileName: string): TProjectSaveResult;
var
  Target: string;
  R: TSceneFileOperationResult;
begin
  Result := Default(TProjectSaveResult);
  if FileName = '' then
  begin
    Result.Status := psCancelled;
    Exit;
  end;
  try
    Target := TPath.GetFullPath(FileName);
    if FSource.Success then
      R := SaveSceneProjectAs(FSource, Target, FDocument)
    else
      R := SaveSceneProject(Target, FDocument);
    if not R.Success then
    begin
      Result.Status := psFailed;
      Result.ErrorMessage := R.ErrorMessage;
      Exit;
    end;
    AdoptSavedPath(Target);
    FLegacyBinding := False;
    Result.Status := psSaved;
  except
    on E: Exception do
    begin
      Result.Status := psFailed;
      Result.ErrorMessage := E.Message;
    end;
  end;
end;

procedure TSceneProjectSession.PrepareNew(const Presentation: TPresentationCandidate);
var I: Integer;
begin
  if (Presentation.WindowKey = 0) or (Presentation.FileName = '') or (Presentation.SlideCount < 0) then
    raise EArgumentException.Create('Invalid presentation candidate.');
  NewProject;
  FPresentation := Presentation;
  FDocument.PowerPointFileName := Presentation.FileName;
  FDocument.PowerPointSlideCount := Presentation.SlideCount;
  SetLength(FDocument.Scenes, Presentation.SlideCount);
  for I := 0 to High(FDocument.Scenes) do
  begin
    FDocument.Scenes[I].SceneId := TGUID.NewGuid.ToString;
    FDocument.Scenes[I].SceneKind := skPowerPoint;
    FDocument.Scenes[I].PowerPointLogicalSlide := I + 1;
    FDocument.Scenes[I].ExplicitVolumePercent := -1;
  end;
  FHasActiveContext := True;
  FModified := True;
end;
function TSceneProjectSession.BindPresentation(const Presentation: TPresentationCandidate;
  ConfirmLegacy: Boolean; out ErrorText: string): Boolean;
begin
  ErrorText := '';
  if not FSource.Success or (Presentation.WindowKey = 0) or
    (Presentation.FileName = '') or (Presentation.SlideCount < 0) then
  begin ErrorText := 'Loaded project and valid presentation required.'; Exit(False); end;
  if SourceFormatVersion = 3 then
  begin
    if not SameText(FDocument.PowerPointFileName, Presentation.FileName) then
    begin ErrorText := 'PowerPoint filename does not match this project.'; Exit(False); end;
    if FDocument.PowerPointSlideCount <> Presentation.SlideCount then
    begin ErrorText := 'PowerPoint slide count does not match this project.'; Exit(False); end;
  end
  else if not ConfirmLegacy then
  begin ErrorText := 'Legacy metadata cannot verify a match. Explicit confirmation required.'; Exit(False); end;
  FPresentation := Presentation;
  FLegacyBinding := SourceFormatVersion < 3;
  FDocument.PowerPointFileName := Presentation.FileName;
  FDocument.PowerPointSlideCount := Presentation.SlideCount;
  FHasActiveContext := True;
  Result := True;
end;
procedure TSceneProjectSession.AdoptCandidate(Candidate: TSceneProjectSession);
begin
  if (Candidate = nil) or not Candidate.HasActiveContext then
    raise EInvalidOpException.Create('Validated Active Project Context required.');
  FDocument := Candidate.GetDocument;
  FSource := Candidate.FSource;
  FSource.DocumentResult.Document := CopyDocument(Candidate.FSource.DocumentResult.Document);
  FPresentation := Candidate.FPresentation;
  FHasActiveContext := True;
  FLegacyBinding := Candidate.FLegacyBinding;
  FModified := Candidate.FModified;
  FSelectedIndex := -1;
end;
initialization
  ApplicationSession := nil;
finalization
  ApplicationSession.Free;
end.
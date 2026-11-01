program PASceneProjectFileStoreTests;

{$APPTYPE CONSOLE}

uses
  System.IOUtils,
  System.SysUtils,
  Winapi.Windows,
  PADomainTypes in '..\Domain\PADomainTypes.pas',
  PASceneDomain in '..\Domain\PASceneDomain.pas',
  PASceneDocumentCodec in '..\Persistence\PASceneDocumentCodec.pas',
  PASceneProjectFileStore in '..\Persistence\PASceneProjectFileStore.pas';

var
  FailureCount: Integer;
  TestCount: Integer;

procedure AssertTrue(const Name: string; Condition: Boolean);
begin
  Inc(TestCount);
  if not Condition then
  begin
    Inc(FailureCount);
    Writeln('FAIL ', Name);
  end
  else
    Writeln('PASS ', Name);
end;

function MakeScene(const Id: string; Kind: TSceneKind;
  Volume, Slide: Integer): TSceneDefinition;
begin
  Result := Default(TSceneDefinition);
  Result.SceneId := Id;
  Result.SceneKind := Kind;
  Result.ExplicitVolumePercent := Volume;
  Result.PowerPointLogicalSlide := Slide;
  if Kind = skBrowser then
    Result.BrowserTargetReference := 'browser-profile';
  if Kind = skExternalApp then
    Result.ExternalAppTargetReference := 'external-app';
end;

function MakeDocument: TSceneAuthoringSnapshot;
begin
  Result := Default(TSceneAuthoringSnapshot);
  Result.AuthoringRevision := 'file-store-revision';
  SetLength(Result.Scenes, 3);
  Result.Scenes[0] := MakeScene('ppt', skPowerPoint, 0, 3);
  Result.Scenes[1] := MakeScene('browser', skBrowser, 100, 0);
  Result.Scenes[2] := MakeScene('external', skExternalApp, 50, 0);
end;

function SameDocument(const Left, Right: TSceneAuthoringSnapshot): Boolean;
var
  Index: Integer;
begin
  Result := Left.AuthoringRevision = Right.AuthoringRevision;
  Result := Result and (Length(Left.Scenes) = Length(Right.Scenes));
  if not Result then
    Exit;
  for Index := 0 to High(Left.Scenes) do
    Result := Result and
      (Left.Scenes[Index].SceneId = Right.Scenes[Index].SceneId) and
      (Left.Scenes[Index].SceneKind = Right.Scenes[Index].SceneKind) and
      (Left.Scenes[Index].ExplicitVolumePercent =
        Right.Scenes[Index].ExplicitVolumePercent) and
      (Left.Scenes[Index].PowerPointLogicalSlide =
        Right.Scenes[Index].PowerPointLogicalSlide) and
      (Left.Scenes[Index].BrowserTargetReference =
        Right.Scenes[Index].BrowserTargetReference) and
      (Left.Scenes[Index].ExternalAppTargetReference =
        Right.Scenes[Index].ExternalAppTargetReference);
end;

function ReadBytes(const FileName: string): TBytes;
begin
  Result := TFile.ReadAllBytes(FileName);
end;

function SameBytes(const Left, Right: TBytes): Boolean;
var
  Index: Integer;
begin
  Result := Length(Left) = Length(Right);
  if not Result then
    Exit;
  for Index := 0 to High(Left) do
    if Left[Index] <> Right[Index] then
      Exit(False);
end;

procedure TestSaveLoad(const Directory: string);
var
  Document, Loaded: TSceneAuthoringSnapshot;
  FileName: string;
  SaveResult: TSceneFileOperationResult;
  LoadResult: TSceneFileLoadResult;
begin
  Document := MakeDocument;
  FileName := TPath.Combine(Directory, 'scene-project.json');
  SaveResult := SaveSceneProject(FileName, Document);
  AssertTrue('B01 Save succeeds', SaveResult.Success);
  AssertTrue('B01 destination exists', TFile.Exists(FileName));
  AssertTrue('B01 UTF-8 JSON contains document type',
    Pos('PA.SceneProject', TFile.ReadAllText(FileName, TEncoding.UTF8)) > 0);

  LoadResult := LoadSceneProject(FileName);
  Loaded := LoadResult.DocumentResult.Document;
  AssertTrue('B02 Load succeeds', LoadResult.Success);
  AssertTrue('B02 round-trip preserves document',
    LoadResult.Success and SameDocument(Document, Loaded));

  Document.AuthoringRevision := 'overwritten';
  Document.Scenes[0].SceneId := 'overwritten-scene';
  SaveResult := SaveSceneProject(FileName, Document);
  LoadResult := LoadSceneProject(FileName);
  AssertTrue('B07 existing destination overwrite succeeds',
    SaveResult.Success and LoadResult.Success and
    (LoadResult.DocumentResult.Document.AuthoringRevision = 'overwritten') and
    (LoadResult.DocumentResult.Document.Scenes[0].SceneId =
      'overwritten-scene'));
end;

procedure TestDrafts(const Directory: string);
var
  Document: TSceneAuthoringSnapshot;
  FileName: string;
  SaveResult: TSceneFileOperationResult;
  LoadResult: TSceneFileLoadResult;
begin
  FileName := TPath.Combine(Directory, 'draft.json');
  Document := Default(TSceneAuthoringSnapshot);
  SaveResult := SaveSceneProject(FileName, Document);
  LoadResult := LoadSceneProject(FileName);
  AssertTrue('B03 empty draft round-trips',
    SaveResult.Success and LoadResult.Success and
    (Length(LoadResult.DocumentResult.Document.Scenes) = 0));

  Document.AuthoringRevision := 'incomplete';
  SetLength(Document.Scenes, 1);
  Document.Scenes[0] := MakeScene('draft-scene', skPowerPoint, -1, 0);
  SaveResult := SaveSceneProject(FileName, Document);
  LoadResult := LoadSceneProject(FileName);
  AssertTrue('B03 incomplete draft round-trips without normalization',
    SaveResult.Success and LoadResult.Success and
    (LoadResult.DocumentResult.Document.Scenes[0].ExplicitVolumePercent = -1) and
    (Length(LoadResult.DocumentResult.AuthoringDiagnostics) > 0));
end;

procedure TestErrors(const Directory: string);
var
  FileName: string;
  LoadResult: TSceneFileLoadResult;
begin
  FileName := TPath.Combine(Directory, 'missing.json');
  LoadResult := LoadSceneProject(FileName);
  AssertTrue('B04 missing file fails clearly',
    (not LoadResult.Success) and (LoadResult.ErrorMessage <> ''));

  TFile.WriteAllText(FileName, '{', TEncoding.UTF8);
  LoadResult := LoadSceneProject(FileName);
  AssertTrue('B04 malformed file fails clearly',
    (not LoadResult.Success) and
    (Length(LoadResult.DocumentResult.SchemaDiagnostics) > 0) and
    (LoadResult.ErrorMessage <> ''));

  TFile.WriteAllText(FileName,
    '{"schemaVersion":1,"mode":"passThrough","audio":{},' +
    '"browserProfiles":[],"sequence":[]}', TEncoding.UTF8);
  LoadResult := LoadSceneProject(FileName);
  AssertTrue('B06 legacy JSON v1 is rejected',
    (not LoadResult.Success) and
    (Length(LoadResult.DocumentResult.SchemaDiagnostics) > 0));
end;

procedure TestFailedSavePreservesDestination(const Directory: string);
var
  Document: TSceneAuthoringSnapshot;
  FileName: string;
  Before, After: TBytes;
  SaveResult: TSceneFileOperationResult;
begin
  FileName := TPath.Combine(Directory, 'protected.json');
  TFile.WriteAllText(FileName, 'original-destination', TEncoding.UTF8);
  Before := ReadBytes(FileName);
  Document := MakeDocument;
  Document.Scenes[0].SceneKind := skUnknown;
  SaveResult := SaveSceneProject(FileName, Document);
  After := ReadBytes(FileName);
  AssertTrue('B05 failed Save reports failure',
    (not SaveResult.Success) and (SaveResult.ErrorMessage <> ''));
  AssertTrue('B05 failed Save preserves destination bytes',
    SameBytes(Before, After));
end;

procedure TestReplacementIOFailure(const Directory: string);
var
  TestDirectory, FileName, UnrelatedName: string;
  Before, UnrelatedBefore: TBytes;
  Document: TSceneAuthoringSnapshot;
  SaveResult: TSceneFileOperationResult;
  DestinationHandle: THandle;
begin
  TestDirectory := TPath.Combine(Directory, 'replacement-io-failure');
  TDirectory.CreateDirectory(TestDirectory);
  FileName := TPath.Combine(TestDirectory, 'destination.json');
  UnrelatedName := TPath.Combine(TestDirectory, 'unrelated.json');
  TFile.WriteAllText(FileName, 'original-destination', TEncoding.UTF8);
  TFile.WriteAllText(UnrelatedName, 'unrelated-project', TEncoding.UTF8);
  Before := ReadBytes(FileName);
  UnrelatedBefore := ReadBytes(UnrelatedName);
  Document := MakeDocument;
  // Validate serialization before inducing a replacement-stage I/O failure.
  SerializeSceneDocument(Document);
  // Omit FILE_SHARE_DELETE: ReplaceFile requires DELETE access to the
  // destination. The handle keeps this failure deterministic until closed.
  DestinationHandle := CreateFile(PWideChar(FileName), GENERIC_READ,
    FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL, 0);
  if DestinationHandle = INVALID_HANDLE_VALUE then
    RaiseLastOSError;
  try
    SaveResult := SaveSceneProject(FileName, Document);
  finally
    CloseHandle(DestinationHandle);
  end;
  AssertTrue('B08 replacement I/O failure uses existing error contract',
    (not SaveResult.Success) and
    (Pos('Scene Project could not be saved: ', SaveResult.ErrorMessage) = 1) and
    (Pos(SysErrorMessage(ERROR_SHARING_VIOLATION),
      SaveResult.ErrorMessage) > 0));
  AssertTrue('B08 replacement failure preserves destination bytes',
    SameBytes(Before, ReadBytes(FileName)));
  AssertTrue('B08 replacement failure cleans temporary files',
    Length(TDirectory.GetFiles(TestDirectory, '*.tmp')) = 0);
  AssertTrue('B08 replacement failure preserves unrelated project bytes',
    SameBytes(UnrelatedBefore, ReadBytes(UnrelatedName)));
  AssertTrue('B08 replacement failure leaves only original files',
    Length(TDirectory.GetFiles(TestDirectory)) = 2);
  SaveResult := SaveSceneProject(FileName, Document);
  AssertTrue('B08 replacement succeeds after destination handle closes',
    SaveResult.Success);
end;

procedure CleanupDirectory(const Directory: string);
begin
  if TDirectory.Exists(Directory) then
    TDirectory.Delete(Directory, True);
end;

var
  Directory: string;
begin
  FailureCount := 0;
  TestCount := 0;
  Directory := TPath.Combine(TPath.GetTempPath,
    'pa-m03b-' + StringReplace(TGUID.NewGuid.ToString, '{', '', []));
  TDirectory.CreateDirectory(Directory);
  try
    TestSaveLoad(Directory);
    TestDrafts(Directory);
    TestErrors(Directory);
    TestFailedSavePreservesDestination(Directory);
    TestReplacementIOFailure(Directory);
  finally
    CleanupDirectory(Directory);
  end;
  Writeln('Tests run: ', TestCount);
  Writeln('Failures: ', FailureCount);
  if FailureCount <> 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.

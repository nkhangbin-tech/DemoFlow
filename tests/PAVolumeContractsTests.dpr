program PAVolumeContractsTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.IOUtils,
  Winapi.Windows,
  PADomainTypes in '..\Domain\PADomainTypes.pas',
  PASceneDomain in '..\Domain\PASceneDomain.pas',
  PASceneDocumentCodec in '..\Persistence\PASceneDocumentCodec.pas',
  PASceneProjectFileStore in '..\Persistence\PASceneProjectFileStore.pas';

var
  TestCount, FailureCount: Integer;

procedure Check(const Name: string; Condition: Boolean);
begin
  Inc(TestCount);
  if Condition then
    Writeln('PASS ', Name)
  else
  begin
    Inc(FailureCount);
    Writeln('FAIL ', Name);
  end;
end;

function Draft: TSceneAuthoringSnapshot;
begin
  Result := NewSceneProject;
  Result.AuthoringRevision := 'caller-revision';
  SetLength(Result.Scenes, 2);
  Result.Scenes[0].SceneId := 'first';
  Result.Scenes[0].SceneKind := skPowerPoint;
  Result.Scenes[0].ExplicitVolumePercent := -1;
  // Missing slide and target are intentional editable draft data.
  Result.Scenes[1].SceneId := 'second';
  Result.Scenes[1].SceneKind := skExternalApp;
  Result.Scenes[1].ExplicitVolumePercent := 100;
end;

function V1Text(const Document: TSceneAuthoringSnapshot): string;
begin
  Result := StringReplace(SerializeSceneDocument(Document),
    '"projectFormatVersion":2', '"projectFormatVersion":1', []);
  Result := StringReplace(Result, '"presentationBaseVolumePercent":50,', '', []);
end;

function SameBytes(const A, B: TBytes): Boolean;
var
  I: Integer;
begin
  if Length(A) <> Length(B) then
    Exit(False);
  for I := 0 to High(A) do
    if A[I] <> B[I] then
      Exit(False);
  Result := True;
end;

procedure TestDomain;
const
  Values: array[0..5] of Integer = (-2, -1, 0, 50, 100, 101);
var
  D: TSceneAuthoringSnapshot;
  V: Integer;
begin
  D := NewSceneProject;
  Check('New project base is 50', D.PresentationBaseVolumePercent = 50);
  Check('New project is an empty editable draft', Length(D.Scenes) = 0);
  SetLength(D.Scenes, 1);
  D.Scenes[0].SceneId := 'valid';
  D.Scenes[0].SceneKind := skPowerPoint;
  D.Scenes[0].PowerPointLogicalSlide := 1;
  for V in Values do
  begin
    D.Scenes[0].ExplicitVolumePercent := V;
    Check('Scene volume boundary ' + IntToStr(V),
      (Length(ValidateSceneList(D)) = 0) = ((V >= -1) and (V <= 100)));
  end;
end;

procedure CheckInvalid(const Text, Name: string);
var
  P: TSceneDocumentResult;
begin
  P := ParseSceneDocument(Text);
  Check(Name + ' rejected', not P.Success);
  Check(Name + ' has schema diagnostics', Length(P.SchemaDiagnostics) > 0);
  Check(Name + ' has no usable partial document/version',
    (Length(P.Document.Scenes) = 0) and (P.SourceFormatVersion = 0));
end;

procedure TestCodec;
const
  Bases: array[0..2] of Integer = (0, 50, 100);
  InvalidBases: array[0..1] of Integer = (-1, 101);
  InvalidJSON: array[0..6] of string =
    ('-1', '101', '1.5', '"50"', 'null', 'true', '999999999999999999999999');
var
  D: TSceneAuthoringSnapshot;
  P: TSceneDocumentResult;
  V: Integer;
  Text, Bad, Token: string;
  Raised: Boolean;
begin
  D := Draft;
  for V in Bases do
  begin
    D.PresentationBaseVolumePercent := V;
    Text := SerializeSceneDocument(D);
    P := ParseSceneDocument(Text);
    Check('V2 base round-trip ' + IntToStr(V), P.Success and
      (P.SourceFormatVersion = 2) and
      (P.Document.PresentationBaseVolumePercent = V));
    Check('V2 preserves draft, order, revision, -1 and explicit 100', P.Success and
      (SerializeSceneDocument(P.Document) = Text) and
      (Length(P.AuthoringDiagnostics) > 0) and
      (P.Document.Scenes[0].ExplicitVolumePercent = -1) and
      (P.Document.Scenes[1].ExplicitVolumePercent = 100));
  end;
  for V in InvalidBases do
  begin
    D.PresentationBaseVolumePercent := V;
    Raised := False;
    try
      SerializeSceneDocument(D);
    except
      on E: EArgumentException do Raised := True;
    end;
    Check('Serializer rejects base ' + IntToStr(V), Raised);
  end;
  D := Draft;
  Text := SerializeSceneDocument(D);
  for Token in InvalidJSON do
  begin
    Bad := StringReplace(Text, '"presentationBaseVolumePercent":50',
      '"presentationBaseVolumePercent":' + Token, []);
    CheckInvalid(Bad, 'Invalid base ' + Token);
  end;
  CheckInvalid(StringReplace(Text, '"presentationBaseVolumePercent":50,', '', []),
    'Missing v2 base');
  CheckInvalid(StringReplace(Text, '"presentationBaseVolumePercent":50,',
    '"presentationBaseVolumePercent":50,"presentationBaseVolumePercent":50,', []),
    'Duplicate v2 base');
  CheckInvalid(StringReplace(Text, '"projectFormatVersion":2',
    '"projectFormatVersion":3', []), 'Unsupported version');
  CheckInvalid('{', 'Malformed document');
  // Old documents retain their explicit targets, not a new-scene default.
  D.Scenes[0].ExplicitVolumePercent := 0;
  Text := V1Text(D);
  P := ParseSceneDocument(Text);
  Check('V1 keeps version, logical base 50 and existing Scene volumes',
    P.Success and (P.SourceFormatVersion = 1) and
    (P.Document.PresentationBaseVolumePercent = 50) and
    (P.Document.Scenes[0].ExplicitVolumePercent = 0) and
    (P.Document.Scenes[1].ExplicitVolumePercent = 100));
  CheckInvalid(StringReplace(Text, '"projectFormatVersion":1,',
    '"projectFormatVersion":1,"presentationBaseVolumePercent":50,', []),
    'V1 does not accept a v2 field');
end;

procedure TestSaveAs(const Directory: string);
var
  SourceName, TargetName, MissingName, Text, ActiveBefore, SourceBefore: string;
  SourceBytes, TargetBytes: TBytes;
  D, Active: TSceneAuthoringSnapshot;
  Loaded, Saved, InvalidSource: TSceneFileLoadResult;
  R: TSceneFileOperationResult;
  Blocker: THandle;
begin
  SourceName := TPath.Combine(Directory, 'original-v1.json');
  TargetName := TPath.Combine(Directory, 'upgrade-v2.json');
  MissingName := TPath.Combine(Directory, 'missing\failure-v2.json');
  D := Draft;
  D.Scenes[0].ExplicitVolumePercent := 0;
  Text := V1Text(D);
  TFile.WriteAllText(SourceName, Text, TEncoding.UTF8);
  SourceBytes := TFile.ReadAllBytes(SourceName);
  Loaded := LoadSceneProject(SourceName);
  Check('Open v1 returns absolute source context and version', Loaded.Success and
    (Loaded.SourceFileName = TPath.GetFullPath(SourceName)) and
    (Loaded.DocumentResult.SourceFormatVersion = 1));
  Check('Open v1 leaves original bytes untouched',
    SameBytes(SourceBytes, TFile.ReadAllBytes(SourceName)));
  Active := Loaded.DocumentResult.Document;
  Active.Scenes := Copy(Loaded.DocumentResult.Document.Scenes);
  Active.Scenes[0].ExplicitVolumePercent := -1;
  Active.PresentationBaseVolumePercent := 100;
  Active.PowerPointFileName := 'confirmed.pptx';
  Active.PowerPointSlideCount := 3;
  ActiveBefore := SerializeSceneDocument(Active);
  SourceBefore := SerializeSceneDocument(Loaded.DocumentResult.Document);
  R := SaveSceneProject(SourceName, Active);
  Check('Ordinary Save refuses v1 replacement with a clear error',
    not R.Success and (Pos('Save As', R.ErrorMessage) > 0));
  R := SaveSceneProjectAs(Loaded, SourceName, Active);
  Check('Save As rejects original source path', not R.Success and (R.ErrorMessage <> ''));
  R := SaveSceneProjectAs(Loaded,
    TPath.Combine(Directory, '.\original-v1.json'), Active);
  Check('Save As rejects normalized source alias', not R.Success);
  Check('Denied saves preserve source and in-memory edits',
    SameBytes(SourceBytes, TFile.ReadAllBytes(SourceName)) and
    (SerializeSceneDocument(Active) = ActiveBefore));
  R := SaveSceneProjectAs(Loaded, MissingName, Active);
  Check('Save As missing destination directory fails clearly',
    not R.Success and (R.ErrorMessage <> '') and not TFile.Exists(MissingName));
  Check('Failed Save As preserves source context and active state',
    SameBytes(SourceBytes, TFile.ReadAllBytes(SourceName)) and
    (SerializeSceneDocument(Active) = ActiveBefore) and
    (SerializeSceneDocument(Loaded.DocumentResult.Document) = SourceBefore) and
    (Loaded.DocumentResult.SourceFormatVersion = 1));
  R := SaveSceneProjectAs(Loaded, TargetName, Active);
  Check('Explicit v1-to-v3 Save As succeeds', R.Success);
  Saved := LoadSceneProject(TargetName);
  Check('Save As writes v3 with edited base and incomplete draft intact',
    Saved.Success and (Saved.DocumentResult.SourceFormatVersion = 3) and
    (SerializeSceneDocument(Saved.DocumentResult.Document) = ActiveBefore));
  Check('Successful Save As preserves original v1 bytes and source context',
    SameBytes(SourceBytes, TFile.ReadAllBytes(SourceName)) and
    (Loaded.DocumentResult.SourceFormatVersion = 1) and
    (SerializeSceneDocument(Loaded.DocumentResult.Document) = SourceBefore));
  TargetBytes := TFile.ReadAllBytes(TargetName);
  Blocker := CreateFile(PWideChar(TargetName), GENERIC_READ,
    FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if Blocker = INVALID_HANDLE_VALUE then RaiseLastOSError;
  try
    R := SaveSceneProjectAs(Loaded, TargetName, Active);
  finally
    CloseHandle(Blocker);
  end;
  Check('Save As replacement I/O failure reports failure',
    not R.Success and (Pos(SysErrorMessage(ERROR_SHARING_VIOLATION), R.ErrorMessage) > 0));
  Check('Save As I/O failure preserves source, destination and active data',
    SameBytes(SourceBytes, TFile.ReadAllBytes(SourceName)) and
    SameBytes(TargetBytes, TFile.ReadAllBytes(TargetName)) and
    (SerializeSceneDocument(Active) = ActiveBefore));
  Check('Save As failure cleans temporary output',
    Length(TDirectory.GetFiles(Directory, '*.tmp')) = 0);
  Active.PresentationBaseVolumePercent := -1;
  R := SaveSceneProjectAs(Loaded, TargetName, Active);
  Check('Save As serialization failure leaves active invalid base unchanged',
    not R.Success and (Active.PresentationBaseVolumePercent = -1) and
    SameBytes(SourceBytes, TFile.ReadAllBytes(SourceName)) and
    SameBytes(TargetBytes, TFile.ReadAllBytes(TargetName)));
  InvalidSource := Default(TSceneFileLoadResult);
  R := SaveSceneProjectAs(InvalidSource, TargetName, D);
  Check('Save As rejects absent source context', not R.Success);
  Active := NewSceneProject;
  R := SaveSceneProject(TPath.Combine(Directory, 'new-v2.json'), Active);
  Saved := LoadSceneProject(TPath.Combine(Directory, 'new-v2.json'));
  Check('New project file is v2 base 50', R.Success and Saved.Success and
    (Saved.DocumentResult.SourceFormatVersion = 2) and
    (Saved.DocumentResult.Document.PresentationBaseVolumePercent = 50));
end;

var
  Directory: string;
begin
  TestCount := 0;
  FailureCount := 0;
  Directory := TPath.Combine(TPath.GetTempPath, 'pa-vol-m01-' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(Directory);
  try
    TestDomain;
    TestCodec;
    TestSaveAs(Directory);
  finally
    TDirectory.Delete(Directory, True);
  end;
  Writeln('Tests run: ', TestCount);
  Writeln('Failures: ', FailureCount);
  if FailureCount <> 0 then ExitCode := 1;
end.
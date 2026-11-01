program PASceneDocumentCodecTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.StrUtils,
  PADomainTypes in '..\Domain\PADomainTypes.pas',
  PASceneDomain in '..\Domain\PASceneDomain.pas',
  PASceneDocumentCodec in '..\Persistence\PASceneDocumentCodec.pas';

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
  Result := NewSceneProject;
  Result.AuthoringRevision := 'revision-9';
  SetLength(Result.Scenes, 3);
  Result.Scenes[0] := MakeScene('ppt', skPowerPoint, 0, 3);
  Result.Scenes[1] := MakeScene('browser', skBrowser, 100, 0);
  Result.Scenes[2] := MakeScene('external', skExternalApp, 50, 0);
end;

function HasSchemaPath(const Parsed: TSceneDocumentResult;
  const Path: string): Boolean;
var
  Diagnostic: TSceneSchemaDiagnostic;
begin
  Result := False;
  for Diagnostic in Parsed.SchemaDiagnostics do
    if Diagnostic.FieldPath = Path then
      Exit(True);
end;

function HasAuthoringField(const Parsed: TSceneDocumentResult;
  const FieldName: string): Boolean;
var
  Diagnostic: TSceneValidationDiagnostic;
begin
  Result := False;
  for Diagnostic in Parsed.AuthoringDiagnostics do
    if Diagnostic.FieldName = FieldName then
      Exit(True);
end;

function CopyDocument(const Source: TSceneAuthoringSnapshot):
  TSceneAuthoringSnapshot;
var
  Index: Integer;
begin
  Result.AuthoringRevision := Source.AuthoringRevision;
  Result.PresentationBaseVolumePercent := Source.PresentationBaseVolumePercent;
  SetLength(Result.Scenes, Length(Source.Scenes));
  for Index := 0 to High(Source.Scenes) do
    Result.Scenes[Index] := Source.Scenes[Index];
end;

function SameDocument(const Left, Right: TSceneAuthoringSnapshot): Boolean;
var
  Index: Integer;
begin
  Result := (Left.AuthoringRevision = Right.AuthoringRevision) and
    (Left.PresentationBaseVolumePercent = Right.PresentationBaseVolumePercent);
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

function HasNoDocument(const Parsed: TSceneDocumentResult): Boolean;
begin
  Result := (not Parsed.Success) and
    (Length(Parsed.Document.Scenes) = 0) and
    (Parsed.Document.AuthoringRevision = '');
end;

procedure AssertInvalidFixture(const Name, Text, Path: string;
  AllowEmpty: Boolean = False);
var
  Parsed: TSceneDocumentResult;
begin
  AssertTrue(Name + ' fixture is constructed',
    AllowEmpty or (Text <> ''));
  Parsed := ParseSceneDocument(Text);
  AssertTrue(Name + ' rejected', not Parsed.Success);
  AssertTrue(Name + ' diagnostic path', HasSchemaPath(Parsed, Path));
  AssertTrue(Name + ' has no partial document', HasNoDocument(Parsed));
end;

function CountOccurrences(const Text, Substring: string): Integer;
var
  Offset: Integer;
begin
  Result := 0;
  Offset := 1;
  while PosEx(Substring, Text, Offset) > 0 do
  begin
    Inc(Result);
    Offset := PosEx(Substring, Text, Offset) + Length(Substring);
  end;
end;

procedure AssertSubstitutionFixture(const Name, Base, OldValue, NewValue,
  Path: string; ExpectedCount: Integer);
var
  Text: string;
begin
  AssertTrue(Name + ' source occurrence count',
    CountOccurrences(Base, OldValue) = ExpectedCount);
  Text := StringReplace(Base, OldValue, NewValue, []);
  AssertTrue(Name + ' fixture changed', Text <> Base);
  AssertInvalidFixture(Name, Text, Path);
end;

procedure AssertSerializationFailure(const Name: string;
  const Document: TSceneAuthoringSnapshot);
var
  Before: TSceneAuthoringSnapshot;
  Raised: Boolean;
begin
  Before := CopyDocument(Document);
  Raised := False;
  try
    SerializeSceneDocument(Document);
  except
    on E: EArgumentException do
      Raised := True;
  end;
  AssertTrue(Name + ' raises EArgumentException', Raised);
  AssertTrue(Name + ' preserves input snapshot', SameDocument(Document, Before));
end;

procedure TestSerializationFailures;
var
  Document: TSceneAuthoringSnapshot;
begin
  Document := MakeDocument;
  Document.Scenes[0].SceneKind := skUnknown;
  AssertSerializationFailure('Unsupported skUnknown SceneKind in first Scene',
    Document);

  Document := MakeDocument;
  Document.Scenes[1].SceneKind := TSceneKind(99);
  AssertSerializationFailure(
    'Out-of-range SceneKind after one valid Scene', Document);

  Document := MakeDocument;
  Document.Scenes[2].SceneKind := skUnknown;
  AssertSerializationFailure(
    'Unsupported skUnknown SceneKind after multiple valid Scenes', Document);
end;

procedure TestRoundTrips;
var
  Document, Before, ParsedDocument: TSceneAuthoringSnapshot;
  Parsed: TSceneDocumentResult;
  Text, TextAgain: string;
begin
  Document := MakeDocument;
  Before := CopyDocument(Document);
  Text := SerializeSceneDocument(Document);
  Parsed := ParseSceneDocument(Text);
  ParsedDocument := Parsed.Document;
  AssertTrue('PowerPoint Scene round-trip', Parsed.Success and
    (ParsedDocument.Scenes[0].SceneKind = skPowerPoint));
  AssertTrue('Browser Scene round-trip', Parsed.Success and
    (ParsedDocument.Scenes[1].SceneKind = skBrowser));
  AssertTrue('ExternalApp Scene round-trip', Parsed.Success and
    (ParsedDocument.Scenes[2].SceneKind = skExternalApp));
  AssertTrue('All six Scene fields preserved',
    SameDocument(Document, ParsedDocument));
  AssertTrue('SceneId and revision preserved',
    (ParsedDocument.Scenes[0].SceneId = 'ppt') and
    (ParsedDocument.AuthoringRevision = 'revision-9'));
  AssertTrue('Scene ordering preserved',
    ParsedDocument.Scenes[1].SceneId = 'browser');
  AssertTrue('Volume boundaries preserved',
    (ParsedDocument.Scenes[0].ExplicitVolumePercent = 0) and
    (ParsedDocument.Scenes[1].ExplicitVolumePercent = 100));
  AssertTrue('Input snapshot remains unchanged',
    SameDocument(Document, Before));
  TextAgain := SerializeSceneDocument(Document);
  AssertTrue('Identical input serializes deterministically', Text = TextAgain);
end;

procedure TestDrafts;
var
  Document, ParsedDocument: TSceneAuthoringSnapshot;
  Parsed: TSceneDocumentResult;
begin
  Document := Default(TSceneAuthoringSnapshot);
  Document.AuthoringRevision := 'draft';
  SetLength(Document.Scenes, 1);
  Document.Scenes[0] := MakeScene('incomplete', skPowerPoint, -1, 0);
  Parsed := ParseSceneDocument(SerializeSceneDocument(Document));
  ParsedDocument := Parsed.Document;
  AssertTrue('No-override volume preserved without normalization',
    Parsed.Success and (ParsedDocument.Scenes[0].ExplicitVolumePercent = -1));
  AssertTrue('Incomplete editable draft round-trip',
    Parsed.Success and HasAuthoringField(Parsed, 'PowerPointLogicalSlide'));

  Document := Default(TSceneAuthoringSnapshot);
  Parsed := ParseSceneDocument(SerializeSceneDocument(Document));
  AssertTrue('Empty Scene List round-trip', Parsed.Success and
    (Length(Parsed.Document.Scenes) = 0));
end;

procedure TestSchemaFailures;
var
  Base: string;
begin
  Base := SerializeSceneDocument(MakeDocument);
  AssertInvalidFixture('Malformed JSON', '{', '');
  AssertInvalidFixture('Incorrect root type', '[]', '');
  AssertInvalidFixture('Truncated array', '[1', '');
  AssertInvalidFixture('Truncated scenes array',
    '{"documentType":"PA.SceneProject","projectFormatVersion":1,' +
    '"authoringRevision":"","scenes":[1', '');
  AssertInvalidFixture('Truncated nested array',
    '{"documentType":"PA.SceneProject","projectFormatVersion":1,' +
    '"authoringRevision":"","scenes":[[1', '');
  AssertInvalidFixture('Array missing terminator',
    '{"documentType":"PA.SceneProject","projectFormatVersion":1,' +
    '"authoringRevision":"","scenes":[1,2}', '');
  AssertInvalidFixture('Empty input', '', '', True);
  AssertInvalidFixture('Whitespace-only input', '  '#9#10, '');
  AssertSubstitutionFixture('Incorrect documentType', Base,
    'PA.SceneProject', 'Legacy', '/documentType', 1);
  AssertSubstitutionFixture('Unsupported document version', Base,
    '"projectFormatVersion":2', '"projectFormatVersion":4',
    '/projectFormatVersion', 1);
  AssertSubstitutionFixture('Missing required field', Base,
    '"authoringRevision":"revision-9",', '', '/authoringRevision', 1);
  AssertSubstitutionFixture('Wrong field type', Base,
    '"explicitVolumePercent":0', '"explicitVolumePercent":"zero"',
    '/scenes/0/explicitVolumePercent', 1);
  AssertSubstitutionFixture('Unknown property', Base,
    '"externalAppTargetReference":"external-app"',
    '"extra":1,"externalAppTargetReference":"external-app"',
    '/scenes/2/extra', 1);
  AssertInvalidFixture('Legacy JSON v1 document',
    '{"schemaVersion":1,"mode":"passThrough","audio":{},"browserProfiles":[],"sequence":[]}',
    '/documentType');
  AssertInvalidFixture('Duplicate root property',
    '{"documentType":"PA.SceneProject","documentType":"PA.SceneProject",' +
    '"projectFormatVersion":1,"authoringRevision":"","scenes":[]}',
    '/documentType');
  AssertInvalidFixture('Duplicate escaped root property',
    '{"documentType":"PA.SceneProject","\u0064ocumentType":"PA.SceneProject",' +
    '"projectFormatVersion":1,"authoringRevision":"","scenes":[]}',
    '/documentType');
  AssertInvalidFixture('Duplicate Scene property',
    '{"documentType":"PA.SceneProject","projectFormatVersion":1,' +
    '"authoringRevision":"","scenes":[{"sceneId":"a","sceneKind":"powerPoint",' +
    '"sceneKind":"browser","explicitVolumePercent":0,' +
    '"powerPointLogicalSlide":1,"browserTargetReference":"","externalAppTargetReference":""}]}',
    '/scenes/0/sceneKind');
  AssertSubstitutionFixture('Invalid SceneKind', Base,
    '"sceneKind":"powerPoint"', '"sceneKind":"invalid"',
    '/scenes/0/sceneKind', 1);
  AssertSubstitutionFixture('Integer overflow', Base,
    '"explicitVolumePercent":0',
    '"explicitVolumePercent":999999999999999999999999',
    '/scenes/0/explicitVolumePercent', 1);
  AssertSubstitutionFixture('Fractional number', Base,
    '"explicitVolumePercent":0', '"explicitVolumePercent":1.5',
    '/scenes/0/explicitVolumePercent', 1);
  AssertSubstitutionFixture('Exponent notation', Base,
    '"explicitVolumePercent":0', '"explicitVolumePercent":1e2',
    '/scenes/0/explicitVolumePercent', 1);
  AssertSubstitutionFixture('Negative project version', Base,
    '"projectFormatVersion":2', '"projectFormatVersion":-1',
    '/projectFormatVersion', 1);
  AssertSubstitutionFixture('Non-object Scene', Base, '"scenes":[',
    '"scenes":[1,', '/scenes/0', 1);
  AssertSubstitutionFixture('Missing Scene property', Base,
    '"browserTargetReference":"browser-profile",', '',
    '/scenes/1/browserTargetReference', 1);
  AssertInvalidFixture('Wrong root property type',
    '{"documentType":"PA.SceneProject","projectFormatVersion":1,' +
    '"authoringRevision":"","scenes":"not-an-array"}',
    '/scenes');
  AssertInvalidFixture('Multiple schema errors',
    '{"documentType":"Wrong","projectFormatVersion":1,' +
    '"authoringRevision":4,"scenes":[1]}', '/documentType');
end;

procedure TestDiagnosticSeparationAndOwnership;
var
  Document, Before: TSceneAuthoringSnapshot;
  Parsed: TSceneDocumentResult;
  Text: string;
begin
  Document := MakeDocument;
  Document.Scenes[0].PowerPointLogicalSlide := 0;
  Before := CopyDocument(Document);
  Text := SerializeSceneDocument(Document);
  Parsed := ParseSceneDocument(Text);
  AssertTrue('Schema and authoring diagnostics are separate',
    Parsed.Success and (Length(Parsed.SchemaDiagnostics) = 0) and
    HasAuthoringField(Parsed, 'PowerPointLogicalSlide'));
  Document.Scenes[0].SceneId := 'changed';
  Document.Scenes[1].BrowserTargetReference := 'changed-target';
  AssertTrue('Source mutation does not alter prior serialized data',
    Text = SerializeSceneDocument(Before));
  AssertTrue('Source mutation is independent after serialization',
    Text <> SerializeSceneDocument(Document));
end;

begin
  FailureCount := 0;
  TestCount := 0;
  TestSerializationFailures;
  TestRoundTrips;
  TestDrafts;
  TestSchemaFailures;
  TestDiagnosticSeparationAndOwnership;
  Writeln('Tests run: ', TestCount);
  Writeln('Failures: ', FailureCount);
  if FailureCount <> 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.

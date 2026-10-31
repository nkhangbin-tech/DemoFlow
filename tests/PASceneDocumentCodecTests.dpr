program PASceneDocumentCodecTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
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
  Result := Default(TSceneAuthoringSnapshot);
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
  SetLength(Result.Scenes, Length(Source.Scenes));
  for Index := 0 to High(Source.Scenes) do
    Result.Scenes[Index] := Source.Scenes[Index];
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
  AssertTrue('Out-of-range volume preserved without normalization',
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
  Base, Text: string;
  Parsed: TSceneDocumentResult;
begin
  Base := SerializeSceneDocument(MakeDocument);
  Parsed := ParseSceneDocument('{');
  AssertTrue('Malformed JSON rejected', not Parsed.Success);
  Parsed := ParseSceneDocument('[]');
  AssertTrue('Incorrect root type rejected', not Parsed.Success);
  Parsed := ParseSceneDocument(StringReplace(Base, 'PA.SceneProject',
    'Legacy', []));
  AssertTrue('Incorrect documentType rejected',
    HasSchemaPath(Parsed, '/documentType'));
  Parsed := ParseSceneDocument(StringReplace(Base, '"projectFormatVersion":1',
    '"projectFormatVersion":2', []));
  AssertTrue('Unsupported document version rejected',
    HasSchemaPath(Parsed, '/projectFormatVersion'));
  Parsed := ParseSceneDocument(StringReplace(Base, '"authoringRevision":"revision-9",',
    '', []));
  AssertTrue('Missing required field rejected',
    HasSchemaPath(Parsed, '/authoringRevision'));
  Parsed := ParseSceneDocument(StringReplace(Base, '"explicitVolumePercent":0',
    '"explicitVolumePercent":"zero"', []));
  AssertTrue('Wrong field type rejected',
    HasSchemaPath(Parsed, '/scenes/0/explicitVolumePercent'));
  Parsed := ParseSceneDocument(StringReplace(Base, '"externalAppTargetReference":"external-app"',
    '"extra":1,"externalAppTargetReference":"external-app"', []));
  AssertTrue('Unknown property rejected',
    HasSchemaPath(Parsed, '/scenes/2/extra'));
  Text := StringReplace(Base, '"schemaVersion":1', '"schemaVersion":1', []);
  Parsed := ParseSceneDocument(
    '{"schemaVersion":1,"mode":"passThrough","audio":{},"browserProfiles":[],"sequence":[]}');
  AssertTrue('Legacy JSON v1 document rejected',
    HasSchemaPath(Parsed, '/documentType'));
  AssertTrue('Schema failure has no partial document',
    Length(Parsed.Document.Scenes) = 0);
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

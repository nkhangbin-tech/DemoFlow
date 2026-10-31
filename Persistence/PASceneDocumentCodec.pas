unit PASceneDocumentCodec;

interface

uses
  PADomainTypes,
  PASceneDomain,
  System.JSON;

type
  TSceneSchemaDiagnostic = record
    Severity: TDiagnosticSeverity;
    FieldPath: string;
    Description: string;
  end;

  TSceneDocumentResult = record
    Success: Boolean;
    Document: TSceneAuthoringSnapshot;
    SchemaDiagnostics: TArray<TSceneSchemaDiagnostic>;
    AuthoringDiagnostics: TArray<TSceneValidationDiagnostic>;
  end;

function SerializeSceneDocument(
  const Document: TSceneAuthoringSnapshot): string;
function ParseSceneDocument(const Text: string): TSceneDocumentResult;

implementation

uses
  System.Classes,
  System.Generics.Collections,
  System.SysUtils;

const
  DocumentTypeName = 'PA.SceneProject';
  ProjectFormatVersion = 1;

procedure AddSchemaDiagnostic(
  var Diagnostics: TArray<TSceneSchemaDiagnostic>;
  const Path, Description: string);
var
  Index: Integer;
begin
  Index := Length(Diagnostics);
  SetLength(Diagnostics, Index + 1);
  Diagnostics[Index].Severity := dsError;
  Diagnostics[Index].FieldPath := Path;
  Diagnostics[Index].Description := Description;
end;

function HasSchemaErrors(
  const Diagnostics: TArray<TSceneSchemaDiagnostic>): Boolean;
begin
  Result := Length(Diagnostics) > 0;
end;

procedure CheckProperties(ObjectValue: TJSONObject; const Path: string;
  const Allowed: array of string;
  var Diagnostics: TArray<TSceneSchemaDiagnostic>);
var
  Pair: TJSONPair;
  AllowedProperty: string;
  Found: Boolean;
begin
  for Pair in ObjectValue do
  begin
    Found := False;
    for AllowedProperty in Allowed do
      if Pair.JsonString.Value = AllowedProperty then
        Found := True;
    if not Found then
      AddSchemaDiagnostic(Diagnostics,
        Path + '/' + Pair.JsonString.Value, 'Unknown property.');
  end;
end;

function RequiredValue(ObjectValue: TJSONObject; const Name, Path: string;
  var Diagnostics: TArray<TSceneSchemaDiagnostic>): TJSONValue;
begin
  Result := ObjectValue.GetValue(Name);
  if Result = nil then
    AddSchemaDiagnostic(Diagnostics, Path + '/' + Name,
      'Required property is missing.');
end;

function StringValue(Value: TJSONValue; const Path: string;
  var Diagnostics: TArray<TSceneSchemaDiagnostic>): string;
begin
  if not (Value is TJSONString) then
  begin
    AddSchemaDiagnostic(Diagnostics, Path, 'Expected a string.');
    Exit('');
  end;
  Result := TJSONString(Value).Value;
end;

function IntegerValue(Value: TJSONValue; const Path: string;
  var Diagnostics: TArray<TSceneSchemaDiagnostic>): Integer;
begin
  if not (Value is TJSONNumber) or
    not TryStrToInt(TJSONNumber(Value).Value, Result) then
  begin
    AddSchemaDiagnostic(Diagnostics, Path,
      'Expected an integer without a fractional component.');
    Exit(0);
  end;
end;

function ArrayValue(Value: TJSONValue; const Path: string;
  var Diagnostics: TArray<TSceneSchemaDiagnostic>): TJSONArray;
begin
  if not (Value is TJSONArray) then
  begin
    AddSchemaDiagnostic(Diagnostics, Path, 'Expected an array.');
    Exit(nil);
  end;
  Result := TJSONArray(Value);
end;

function SceneKindToText(Kind: TSceneKind): string;
begin
  case Kind of
    skPowerPoint:
      Result := 'powerPoint';
    skBrowser:
      Result := 'browser';
    skExternalApp:
      Result := 'externalApp';
  else
    raise EArgumentException.CreateFmt(
      'Unsupported SceneKind value %d.', [Ord(Kind)]);
  end;
end;

function SceneKindFromText(const Value, Path: string;
  var Diagnostics: TArray<TSceneSchemaDiagnostic>): TSceneKind;
begin
  if Value = 'powerPoint' then
    Exit(skPowerPoint);
  if Value = 'browser' then
    Exit(skBrowser);
  if Value = 'externalApp' then
    Exit(skExternalApp);
  AddSchemaDiagnostic(Diagnostics, Path,
    'Expected powerPoint, browser, or externalApp.');
  Result := skUnknown;
end;

function ParseScene(Value: TJSONValue; Index: Integer;
  var Diagnostics: TArray<TSceneSchemaDiagnostic>): TSceneDefinition;
var
  ObjectValue: TJSONObject;
  Prefix: string;
  FieldValue: TJSONValue;
begin
  Result := Default(TSceneDefinition);
  Prefix := Format('/scenes/%d', [Index]);
  if not (Value is TJSONObject) then
  begin
    AddSchemaDiagnostic(Diagnostics, Prefix, 'Expected an object.');
    Exit;
  end;
  ObjectValue := TJSONObject(Value);
  CheckProperties(ObjectValue, Prefix,
    ['sceneId', 'sceneKind', 'explicitVolumePercent',
     'powerPointLogicalSlide', 'browserTargetReference',
     'externalAppTargetReference'], Diagnostics);

  FieldValue := RequiredValue(ObjectValue, 'sceneId', Prefix, Diagnostics);
  if FieldValue <> nil then
    Result.SceneId := StringValue(FieldValue, Prefix + '/sceneId',
      Diagnostics);
  FieldValue := RequiredValue(ObjectValue, 'sceneKind', Prefix, Diagnostics);
  if FieldValue <> nil then
    Result.SceneKind := SceneKindFromText(
      StringValue(FieldValue, Prefix + '/sceneKind', Diagnostics),
      Prefix + '/sceneKind', Diagnostics);
  FieldValue := RequiredValue(ObjectValue, 'explicitVolumePercent',
    Prefix, Diagnostics);
  if FieldValue <> nil then
    Result.ExplicitVolumePercent := IntegerValue(FieldValue,
      Prefix + '/explicitVolumePercent', Diagnostics);
  FieldValue := RequiredValue(ObjectValue, 'powerPointLogicalSlide',
    Prefix, Diagnostics);
  if FieldValue <> nil then
    Result.PowerPointLogicalSlide := IntegerValue(FieldValue,
      Prefix + '/powerPointLogicalSlide', Diagnostics);
  FieldValue := RequiredValue(ObjectValue, 'browserTargetReference',
    Prefix, Diagnostics);
  if FieldValue <> nil then
    Result.BrowserTargetReference := StringValue(FieldValue,
      Prefix + '/browserTargetReference', Diagnostics);
  FieldValue := RequiredValue(ObjectValue, 'externalAppTargetReference',
    Prefix, Diagnostics);
  if FieldValue <> nil then
    Result.ExternalAppTargetReference := StringValue(FieldValue,
      Prefix + '/externalAppTargetReference', Diagnostics);
end;

function ParseJsonText(const Text: string;
  var Diagnostics: TArray<TSceneSchemaDiagnostic>): TJSONObject;
var
  Value: TJSONValue;
begin
  Result := nil;
  try
    Value := TJSONObject.ParseJSONValue(Text);
  except
    on E: Exception do
    begin
      AddSchemaDiagnostic(Diagnostics, '', 'Malformed JSON: ' + E.Message);
      Exit;
    end;
  end;
  if Value = nil then
  begin
    AddSchemaDiagnostic(Diagnostics, '', 'Malformed JSON.');
    Exit;
  end;
  if not (Value is TJSONObject) then
  begin
    AddSchemaDiagnostic(Diagnostics, '',
      'The document root must be a JSON object.');
    Value.Free;
    Exit;
  end;
  Result := TJSONObject(Value);
end;

function FindDuplicateProperties(const Text: string;
  var Diagnostics: TArray<TSceneSchemaDiagnostic>): Boolean;
var
  Position: Integer;
  DummyString: string;

  function ParseValue(const Path: string): Boolean; forward;

  function ParseString(out Value: string): Boolean;
  var
    Start: Integer;
  begin
    Result := False;
    if (Position > Length(Text)) or (Text[Position] <> '"') then
      Exit;
    Inc(Position);
    Start := Position;
    while Position <= Length(Text) do
    begin
      if Text[Position] = '\' then
        Inc(Position, 2)
      else if Text[Position] = '"' then
      begin
        Value := Copy(Text, Start, Position - Start);
        Inc(Position);
        Exit(True);
      end
      else
        Inc(Position);
    end;
  end;

  function DecodePropertyName(const RawValue: string): string;
  var
    ParsedValue: TJSONValue;
  begin
    ParsedValue := TJSONObject.ParseJSONValue('"' + RawValue + '"');
    try
      if ParsedValue is TJSONString then
        Result := TJSONString(ParsedValue).Value
      else
        Result := RawValue;
    finally
      ParsedValue.Free;
    end;
  end;

  procedure SkipWhitespace;
  begin
    while (Position <= Length(Text)) and
      CharInSet(Text[Position], [' ', #9, #10, #13]) do
      Inc(Position);
  end;

  function ParseObject(const Path: string): Boolean;
  var
    Names: TStringList;
    Name, MemberPath: string;
    First: Boolean;
  begin
    Result := False;
    if (Position > Length(Text)) or (Text[Position] <> '{') then
      Exit;
    Inc(Position);
    Names := TStringList.Create;
    try
      Names.Sorted := True;
      Names.Duplicates := dupIgnore;
      SkipWhitespace;
      First := True;
      while (Position <= Length(Text)) and (Text[Position] <> '}') do
      begin
        if not First then
        begin
          if Position > Length(Text) then
            Exit;
          if Text[Position] <> ',' then
            Exit;
          Inc(Position);
          SkipWhitespace;
        end;
        if not ParseString(Name) then
          Exit;
        Name := DecodePropertyName(Name);
        MemberPath := Path + '/' + Name;
        if Names.IndexOf(Name) >= 0 then
        begin
          AddSchemaDiagnostic(Diagnostics, MemberPath,
            'Duplicate property.');
          Result := True;
        end
        else
          Names.Add(Name);
        SkipWhitespace;
        if (Position > Length(Text)) or (Text[Position] <> ':') then
          Exit;
        Inc(Position);
        SkipWhitespace;
        if not ParseValue(MemberPath) then
          Exit;
        SkipWhitespace;
        First := False;
      end;
      if (Position > Length(Text)) or (Text[Position] <> '}') then
        Exit;
      Inc(Position);
      Result := True;
    finally
      Names.Free;
    end;
  end;

  function ParseArray(const Path: string): Boolean;
  var
    Index: Integer;
  begin
    Result := False;
    if (Position > Length(Text)) or (Text[Position] <> '[') then
      Exit;
    Inc(Position);
    SkipWhitespace;
    Index := 0;
    while (Position <= Length(Text)) and (Text[Position] <> ']') do
    begin
      if not ParseValue(Format('%s/%d', [Path, Index])) then
        Exit;
      Inc(Index);
      SkipWhitespace;
      if Position > Length(Text) then
        Exit;
      if Text[Position] = ',' then
      begin
        Inc(Position);
        SkipWhitespace;
      end
      else if Text[Position] <> ']' then
        Exit;
    end;
    if (Position > Length(Text)) or (Text[Position] <> ']') then
      Exit;
    Inc(Position);
    Result := True;
  end;

  function ParsePrimitive: Boolean;
  begin
    while (Position <= Length(Text)) and
      not CharInSet(Text[Position], [',', '}', ']', ' ', #9, #10, #13]) do
      Inc(Position);
    Result := True;
  end;

  function ParseValue(const Path: string): Boolean;
  begin
    SkipWhitespace;
    if Position > Length(Text) then
      Exit(False);
    case Text[Position] of
      '{':
        Result := ParseObject(Path);
      '[':
        Result := ParseArray(Path);
      '"':
        begin
          Result := ParseString(DummyString);
        end;
    else
      Result := ParsePrimitive;
    end;
  end;
begin
  Result := False;
  Position := 1;
  if ParseValue('') then
  begin
    SkipWhitespace;
    Result := Position > Length(Text);
  end;
end;

function NewObject: TJSONObject;
begin
  Result := TJSONObject.Create;
end;

function SceneToJson(const Scene: TSceneDefinition): TJSONObject;
begin
  if not (Scene.SceneKind in [skPowerPoint, skBrowser, skExternalApp]) then
    raise EArgumentException.CreateFmt(
      'Unsupported SceneKind value %d.', [Ord(Scene.SceneKind)]);
  Result := NewObject;
  Result.AddPair('sceneId', Scene.SceneId);
  Result.AddPair('sceneKind', SceneKindToText(Scene.SceneKind));
  Result.AddPair('explicitVolumePercent',
    TJSONNumber.Create(Scene.ExplicitVolumePercent));
  Result.AddPair('powerPointLogicalSlide',
    TJSONNumber.Create(Scene.PowerPointLogicalSlide));
  Result.AddPair('browserTargetReference', Scene.BrowserTargetReference);
  Result.AddPair('externalAppTargetReference',
    Scene.ExternalAppTargetReference);
end;

function SerializeSceneDocument(
  const Document: TSceneAuthoringSnapshot): string;
var
  Root: TJSONObject;
  Scenes: TJSONArray;
  Scene: TSceneDefinition;
begin
  Root := NewObject;
  try
    Root.AddPair('documentType', DocumentTypeName);
    Root.AddPair('projectFormatVersion',
      TJSONNumber.Create(ProjectFormatVersion));
    Root.AddPair('authoringRevision', Document.AuthoringRevision);
    Scenes := TJSONArray.Create;
    Root.AddPair('scenes', Scenes);
    for Scene in Document.Scenes do
      Scenes.AddElement(SceneToJson(Scene));
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

function ParseSceneDocument(const Text: string): TSceneDocumentResult;
var
  Root: TJSONObject;
  Value: TJSONValue;
  Version: Integer;
  Scenes: TJSONArray;
  Index: Integer;
begin
  Result := Default(TSceneDocumentResult);
  FindDuplicateProperties(Text, Result.SchemaDiagnostics);
  Root := ParseJsonText(Text, Result.SchemaDiagnostics);
  if Root = nil then
    Exit;
  try
    CheckProperties(Root, '',
      ['documentType', 'projectFormatVersion', 'authoringRevision',
       'scenes'], Result.SchemaDiagnostics);
    Value := RequiredValue(Root, 'documentType', '',
      Result.SchemaDiagnostics);
    if Value <> nil then
      if StringValue(Value, '/documentType',
        Result.SchemaDiagnostics) <> DocumentTypeName then
        AddSchemaDiagnostic(Result.SchemaDiagnostics, '/documentType',
          'Expected PA.SceneProject.');
    Value := RequiredValue(Root, 'projectFormatVersion', '',
      Result.SchemaDiagnostics);
    if Value <> nil then
    begin
      Version := IntegerValue(Value, '/projectFormatVersion',
        Result.SchemaDiagnostics);
      if Version <> ProjectFormatVersion then
        AddSchemaDiagnostic(Result.SchemaDiagnostics,
          '/projectFormatVersion', 'Only project format version 1 is supported.');
    end;
    Value := RequiredValue(Root, 'authoringRevision',
      '', Result.SchemaDiagnostics);
    if Value <> nil then
      Result.Document.AuthoringRevision := StringValue(Value,
        '/authoringRevision', Result.SchemaDiagnostics);
    Value := RequiredValue(Root, 'scenes', '', Result.SchemaDiagnostics);
    Scenes := nil;
    if Value <> nil then
      Scenes := ArrayValue(Value, '/scenes', Result.SchemaDiagnostics);
    if Scenes <> nil then
    begin
      SetLength(Result.Document.Scenes, Scenes.Count);
      for Index := 0 to Scenes.Count - 1 do
        Result.Document.Scenes[Index] := ParseScene(Scenes.Items[Index],
          Index, Result.SchemaDiagnostics);
    end;
    if HasSchemaErrors(Result.SchemaDiagnostics) then
    begin
      Result.Document := Default(TSceneAuthoringSnapshot);
      Exit;
    end;
    Result.AuthoringDiagnostics := ValidateSceneList(Result.Document);
    Result.Success := True;
  finally
    Root.Free;
  end;
end;

end.

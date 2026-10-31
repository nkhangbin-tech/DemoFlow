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
    Result := '';
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

function NewObject: TJSONObject;
begin
  Result := TJSONObject.Create;
end;

function SceneToJson(const Scene: TSceneDefinition): TJSONObject;
begin
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
    for Scene in Document.Scenes do
      Scenes.AddElement(SceneToJson(Scene));
    Root.AddPair('scenes', Scenes);
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

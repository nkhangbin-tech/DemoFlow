unit PASceneDomain;

interface

uses
  PADomainTypes;

type
  TSceneId = string;

  TSceneKind = (
    skUnknown,
    skPowerPoint,
    skBrowser,
    skExternalApp
  );

  TSceneDefinition = record
    SceneId: TSceneId;
    SceneKind: TSceneKind;
    // -1: no override; 0..100: absolute Windows master-volume target.
    ExplicitVolumePercent: Integer;
    // One-based logical slide number; physical Black Buffer placement is
    // resolved outside this authoring model.
    PowerPointLogicalSlide: Integer;
    BrowserTargetReference: string;
    ExternalAppTargetReference: string;
  end;

  TSceneAuthoringSnapshot = record
    Scenes: TArray<TSceneDefinition>;
    AuthoringRevision: string;
    PresentationBaseVolumePercent: Integer;
  end;

  TSceneValidationDiagnostic = record
    Severity: TDiagnosticSeverity;
    SceneIndex: Integer;
    SceneId: TSceneId;
    FieldName: string;
    Description: string;
  end;

// New project creation contract; a zero-initialized record still has base 0.
function NewSceneProject: TSceneAuthoringSnapshot;

function ValidateSceneList(
  const Snapshot: TSceneAuthoringSnapshot):
  TArray<TSceneValidationDiagnostic>;
function SceneKindName(Kind: TSceneKind): string;

implementation

uses
  System.SysUtils;

function NewSceneProject: TSceneAuthoringSnapshot;
begin
  Result := Default(TSceneAuthoringSnapshot);
  Result.PresentationBaseVolumePercent := 50;
end;

function SceneKindName(Kind: TSceneKind): string;
begin
  case Kind of
    skPowerPoint:
      Result := 'PowerPoint';
    skBrowser:
      Result := 'Browser';
    skExternalApp:
      Result := 'ExternalApp';
  else
    Result := 'Unknown';
  end;
end;

function ContainsControlCharacter(const Value: string): Boolean;
var
  Character: Char;
begin
  Result := False;
  for Character in Value do
    if (Ord(Character) < 32) or (Ord(Character) = 127) then
      Exit(True);
end;

function IsValidSceneId(const Value: TSceneId): Boolean;
begin
  Result := (Trim(Value) <> '') and not ContainsControlCharacter(Value);
end;

function IsPresentReference(const Value: string): Boolean;
begin
  Result := Trim(Value) <> '';
end;

procedure AddDiagnostic(
  var Diagnostics: TArray<TSceneValidationDiagnostic>;
  Severity: TDiagnosticSeverity;
  SceneIndex: Integer;
  const SceneId, FieldName, Description: string);
var
  Diagnostic: TSceneValidationDiagnostic;
begin
  Diagnostic := Default(TSceneValidationDiagnostic);
  Diagnostic.Severity := Severity;
  Diagnostic.SceneIndex := SceneIndex;
  Diagnostic.SceneId := SceneId;
  Diagnostic.FieldName := FieldName;
  Diagnostic.Description := Description;
  SetLength(Diagnostics, Length(Diagnostics) + 1);
  Diagnostics[High(Diagnostics)] := Diagnostic;
end;

function HasSceneId(
  const Scenes: TArray<TSceneDefinition>;
  CurrentIndex: Integer;
  const SceneId: TSceneId): Boolean;
var
  Index: Integer;
begin
  Result := False;
  for Index := 0 to CurrentIndex - 1 do
    if Scenes[Index].SceneId = SceneId then
      Exit(True);
end;

procedure ValidateScene(
  const Scenes: TArray<TSceneDefinition>;
  SceneIndex: Integer;
  var Diagnostics: TArray<TSceneValidationDiagnostic>);
var
  Scene: TSceneDefinition;
  KindIsKnown: Boolean;
begin
  Scene := Scenes[SceneIndex];
  if not IsValidSceneId(Scene.SceneId) then
    AddDiagnostic(Diagnostics, dsError, SceneIndex, Scene.SceneId, 'SceneId',
      'SceneId must be non-blank and contain no control characters.');
  if HasSceneId(Scenes, SceneIndex, Scene.SceneId) then
    AddDiagnostic(Diagnostics, dsError, SceneIndex, Scene.SceneId, 'SceneId',
      'SceneId must be unique within the ordered Scene List.');

  KindIsKnown := Scene.SceneKind in [skPowerPoint, skBrowser, skExternalApp];
  if not KindIsKnown then
    AddDiagnostic(Diagnostics, dsError, SceneIndex, Scene.SceneId,
      'SceneKind', 'SceneKind is unknown or unsupported.');

  if (Scene.ExplicitVolumePercent < -1) or
    (Scene.ExplicitVolumePercent > 100) then
    AddDiagnostic(Diagnostics, dsError, SceneIndex, Scene.SceneId,
      'ExplicitVolumePercent',
      'ExplicitVolumePercent must be -1 (no override) or an integer from 0 through 100.');

  case Scene.SceneKind of
    skPowerPoint:
      begin
        if Scene.PowerPointLogicalSlide <= 0 then
          AddDiagnostic(Diagnostics, dsError, SceneIndex, Scene.SceneId,
            'PowerPointLogicalSlide',
            'PowerPointLogicalSlide must be a positive one-based logical slide reference.');
        if IsPresentReference(Scene.BrowserTargetReference) then
          AddDiagnostic(Diagnostics, dsError, SceneIndex, Scene.SceneId,
            'BrowserTargetReference',
            'BrowserTargetReference is not valid for a PowerPoint Scene.');
        if IsPresentReference(Scene.ExternalAppTargetReference) then
          AddDiagnostic(Diagnostics, dsError, SceneIndex, Scene.SceneId,
            'ExternalAppTargetReference',
            'ExternalAppTargetReference is not valid for a PowerPoint Scene.');
      end;
    skBrowser:
      begin
        if not IsPresentReference(Scene.BrowserTargetReference) then
          AddDiagnostic(Diagnostics, dsError, SceneIndex, Scene.SceneId,
            'BrowserTargetReference',
            'BrowserTargetReference is required for a Browser Scene.');
        if Scene.PowerPointLogicalSlide <> 0 then
          AddDiagnostic(Diagnostics, dsError, SceneIndex, Scene.SceneId,
            'PowerPointLogicalSlide',
            'PowerPointLogicalSlide is not valid for a Browser Scene.');
        if IsPresentReference(Scene.ExternalAppTargetReference) then
          AddDiagnostic(Diagnostics, dsError, SceneIndex, Scene.SceneId,
            'ExternalAppTargetReference',
            'ExternalAppTargetReference is not valid for a Browser Scene.');
      end;
    skExternalApp:
      begin
        if not IsPresentReference(Scene.ExternalAppTargetReference) then
          AddDiagnostic(Diagnostics, dsError, SceneIndex, Scene.SceneId,
            'ExternalAppTargetReference',
            'ExternalAppTargetReference is required for an ExternalApp Scene.');
        if Scene.PowerPointLogicalSlide <> 0 then
          AddDiagnostic(Diagnostics, dsError, SceneIndex, Scene.SceneId,
            'PowerPointLogicalSlide',
            'PowerPointLogicalSlide is not valid for an ExternalApp Scene.');
        if IsPresentReference(Scene.BrowserTargetReference) then
          AddDiagnostic(Diagnostics, dsError, SceneIndex, Scene.SceneId,
            'BrowserTargetReference',
            'BrowserTargetReference is not valid for an ExternalApp Scene.');
      end;
  end;
end;

function ValidateSceneList(
  const Snapshot: TSceneAuthoringSnapshot):
  TArray<TSceneValidationDiagnostic>;
var
  Index: Integer;
begin
  Result := nil;
  for Index := 0 to High(Snapshot.Scenes) do
    ValidateScene(Snapshot.Scenes, Index, Result);
end;

end.

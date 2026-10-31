unit PASceneCompiler;

interface

uses
  PADomainTypes,
  PASceneDomain;

type
  TPhysicalResourceKind = (
    prkUnknown,
    prkPowerPointSlide,
    prkBlackBuffer
  );

  TPhysicalResourceDeclaration = record
    ResourceId: string;
    Kind: TPhysicalResourceKind;
    PhysicalSlideNumber: Integer;
  end;

  TScenePhysicalMapping = record
    SceneId: TSceneId;
    PhysicalResourceId: string;
  end;

  TSceneAdjacencyDeclaration = record
    SceneId: TSceneId;
    PreviousSceneId: TSceneId;
    NextSceneId: TSceneId;
  end;

  TSceneCompileRequest = record
    Scenes: TArray<TSceneDefinition>;
    SourceAuthoringRevision: string;
    ExpectedAuthoringRevision: string;
    PhysicalResources: TArray<TPhysicalResourceDeclaration>;
    PhysicalMappings: TArray<TScenePhysicalMapping>;
    Adjacencies: TArray<TSceneAdjacencyDeclaration>;
  end;

  TCompiledScene = record
    SceneId: TSceneId;
    SceneKind: TSceneKind;
    ExplicitVolumePercent: Integer;
    PowerPointLogicalSlide: Integer;
    BrowserTargetReference: string;
    ExternalAppTargetReference: string;
    PreviousSceneId: TSceneId;
    NextSceneId: TSceneId;
    PhysicalResourceId: string;
  end;

  TCompiledPhysicalResource = record
    ResourceId: string;
    Kind: TPhysicalResourceKind;
    PhysicalSlideNumber: Integer;
  end;

  TSceneCompileDiagnostic = record
    Severity: TDiagnosticSeverity;
    SceneIndex: Integer;
    SceneId: TSceneId;
    FieldName: string;
    Description: string;
  end;

  TCompiledRuntimeSnapshot = class
  private
    FAuthoringRevision: string;
    FScenes: TArray<TCompiledScene>;
    FPhysicalResources: TArray<TCompiledPhysicalResource>;
  public
    constructor Create(const AuthoringRevision: string;
      const Scenes: TArray<TCompiledScene>;
      const PhysicalResources: TArray<TCompiledPhysicalResource>);
    function SceneCount: Integer;
    function GetScene(Index: Integer): TCompiledScene;
    function GetPhysicalResource(Index: Integer): TCompiledPhysicalResource;
    function GetScenes: TArray<TCompiledScene>;
    function GetPhysicalResources: TArray<TCompiledPhysicalResource>;
    property AuthoringRevision: string read FAuthoringRevision;
  end;

  TSceneCompileResult = record
    Success: Boolean;
    Snapshot: TCompiledRuntimeSnapshot;
    Diagnostics: TArray<TSceneCompileDiagnostic>;
  end;

function CompileSceneList(
  const Request: TSceneCompileRequest): TSceneCompileResult;
function PhysicalResourceKindName(Kind: TPhysicalResourceKind): string;

implementation

uses
  System.SysUtils;

function PhysicalResourceKindName(Kind: TPhysicalResourceKind): string;
begin
  case Kind of
    prkPowerPointSlide:
      Result := 'PowerPointSlide';
    prkBlackBuffer:
      Result := 'BlackBuffer';
  else
    Result := 'Unknown';
  end;
end;

procedure AddDiagnostic(
  var Diagnostics: TArray<TSceneCompileDiagnostic>;
  SceneIndex: Integer;
  const SceneId, FieldName, Description: string);
var
  Diagnostic: TSceneCompileDiagnostic;
begin
  Diagnostic := Default(TSceneCompileDiagnostic);
  Diagnostic.Severity := dsError;
  Diagnostic.SceneIndex := SceneIndex;
  Diagnostic.SceneId := SceneId;
  Diagnostic.FieldName := FieldName;
  Diagnostic.Description := Description;
  SetLength(Diagnostics, Length(Diagnostics) + 1);
  Diagnostics[High(Diagnostics)] := Diagnostic;
end;

function FindResourceIndex(
  const Resources: TArray<TPhysicalResourceDeclaration>;
  const ResourceId: string): Integer;
begin
  for Result := 0 to High(Resources) do
    if Resources[Result].ResourceId = ResourceId then
      Exit;
  Result := -1;
end;

function FindMappingIndex(
  const Mappings: TArray<TScenePhysicalMapping>;
  const SceneId: string): Integer;
begin
  for Result := 0 to High(Mappings) do
    if Mappings[Result].SceneId = SceneId then
      Exit;
  Result := -1;
end;

function FindAdjacencyIndex(
  const Adjacencies: TArray<TSceneAdjacencyDeclaration>;
  const SceneId: string): Integer;
begin
  for Result := 0 to High(Adjacencies) do
    if Adjacencies[Result].SceneId = SceneId then
      Exit;
  Result := -1;
end;

function FindSceneIndex(const Scenes: TArray<TSceneDefinition>;
  const SceneId: string): Integer;
begin
  for Result := 0 to High(Scenes) do
    if Scenes[Result].SceneId = SceneId then
      Exit;
  Result := -1;
end;

function FindCompiledResourceIndex(
  const Resources: TArray<TCompiledPhysicalResource>;
  const ResourceId: string): Integer;
begin
  for Result := 0 to High(Resources) do
    if Resources[Result].ResourceId = ResourceId then
      Exit;
  Result := -1;
end;

function CopyStrings(const Value: TArray<TSceneDefinition>):
  TArray<TSceneDefinition>;
var
  Index: Integer;
begin
  SetLength(Result, Length(Value));
  for Index := 0 to High(Value) do
    Result[Index] := Value[Index];
end;

function ValidateRequest(const Request: TSceneCompileRequest;
  var Diagnostics: TArray<TSceneCompileDiagnostic>): Boolean;
var
  ValidationSnapshot: TSceneAuthoringSnapshot;
  ValidationDiagnostics: TArray<TSceneValidationDiagnostic>;
  Index, ResourceIndex, SceneIndex, MappingIndex, AdjacencyIndex: Integer;
  Scene: TSceneDefinition;
  Resource: TPhysicalResourceDeclaration;
  Mapping: TScenePhysicalMapping;
  Adjacency: TSceneAdjacencyDeclaration;
  ExpectedPrevious, ExpectedNext: string;
begin
  Result := True;
  if Trim(Request.ExpectedAuthoringRevision) = '' then
  begin
    AddDiagnostic(Diagnostics, -1, '', 'AuthoringRevision',
      'ExpectedAuthoringRevision is required for executable compilation.');
    Result := False;
  end;
  ValidationSnapshot := Default(TSceneAuthoringSnapshot);
  ValidationSnapshot.Scenes := CopyStrings(Request.Scenes);
  ValidationSnapshot.AuthoringRevision := Request.SourceAuthoringRevision;
  ValidationDiagnostics := ValidateSceneList(ValidationSnapshot);
  for Index := 0 to High(ValidationDiagnostics) do
  begin
    AddDiagnostic(Diagnostics, ValidationDiagnostics[Index].SceneIndex,
      ValidationDiagnostics[Index].SceneId,
      ValidationDiagnostics[Index].FieldName,
      ValidationDiagnostics[Index].Description);
    Result := False;
  end;
  if Length(Request.Scenes) = 0 then
  begin
    AddDiagnostic(Diagnostics, -1, '', 'Scenes',
      'An empty editable draft cannot compile as an executable snapshot.');
    Result := False;
  end;
  if Request.ExpectedAuthoringRevision <> Request.SourceAuthoringRevision then
  begin
    AddDiagnostic(Diagnostics, -1, '', 'AuthoringRevision',
      'ExpectedAuthoringRevision does not match the source revision.');
    Result := False;
  end;

  for Index := 0 to High(Request.PhysicalResources) do
  begin
    Resource := Request.PhysicalResources[Index];
    if Trim(Resource.ResourceId) = '' then
    begin
      AddDiagnostic(Diagnostics, -1, '', 'PhysicalResources',
        'Physical resource identity is required.');
      Result := False;
    end;
    if Resource.Kind = prkUnknown then
    begin
      AddDiagnostic(Diagnostics, -1, '', 'PhysicalResources',
        'Physical resource kind is unknown.');
      Result := False;
    end;
    if Resource.PhysicalSlideNumber <= 0 then
    begin
      AddDiagnostic(Diagnostics, -1, '', 'PhysicalResources',
        'Physical slide number must be positive.');
      Result := False;
    end;
    if FindResourceIndex(Request.PhysicalResources, Resource.ResourceId) <> Index then
    begin
      AddDiagnostic(Diagnostics, -1, '', 'PhysicalResources',
        'Physical resource identities must be unique.');
      Result := False;
    end;
    for ResourceIndex := 0 to Index - 1 do
      if Request.PhysicalResources[ResourceIndex].PhysicalSlideNumber =
        Resource.PhysicalSlideNumber then
      begin
        AddDiagnostic(Diagnostics, -1, '', 'PhysicalResources',
          'Physical slide numbers must be unique.');
        Result := False;
      end;
  end;

  for Index := 0 to High(Request.PhysicalMappings) do
  begin
    Mapping := Request.PhysicalMappings[Index];
    SceneIndex := FindSceneIndex(Request.Scenes, Mapping.SceneId);
    ResourceIndex := FindResourceIndex(Request.PhysicalResources,
      Mapping.PhysicalResourceId);
    if SceneIndex < 0 then
    begin
      AddDiagnostic(Diagnostics, -1, Mapping.SceneId, 'PhysicalMappings',
        'Physical mapping references an unknown SceneId.');
      Result := False;
    end;
    if ResourceIndex < 0 then
    begin
      AddDiagnostic(Diagnostics, SceneIndex, Mapping.SceneId,
        'PhysicalMappings', 'Physical mapping references an unknown resource.');
      Result := False;
    end;
    if FindMappingIndex(Request.PhysicalMappings, Mapping.SceneId) <> Index then
    begin
      AddDiagnostic(Diagnostics, SceneIndex, Mapping.SceneId,
        'PhysicalMappings', 'Each SceneId may have only one physical mapping.');
      Result := False;
    end;
  end;

  for Index := 0 to High(Request.Scenes) do
  begin
    Scene := Request.Scenes[Index];
    MappingIndex := FindMappingIndex(Request.PhysicalMappings, Scene.SceneId);
    if Scene.SceneKind in [skPowerPoint, skBrowser] then
    begin
      if MappingIndex < 0 then
      begin
        AddDiagnostic(Diagnostics, Index, Scene.SceneId, 'PhysicalMappings',
          'PowerPoint and Browser Scenes require an explicit physical mapping.');
        Result := False;
      end
      else
      begin
        ResourceIndex := FindResourceIndex(Request.PhysicalResources,
          Request.PhysicalMappings[MappingIndex].PhysicalResourceId);
        if ResourceIndex >= 0 then
        begin
          Resource := Request.PhysicalResources[ResourceIndex];
          if (Scene.SceneKind = skPowerPoint) and
            (Resource.Kind <> prkPowerPointSlide) then
          begin
            AddDiagnostic(Diagnostics, Index, Scene.SceneId,
              'PhysicalMappings',
              'PowerPoint Scenes must map to PowerPoint slide resources.');
            Result := False;
          end;
          if (Scene.SceneKind = skBrowser) and
            (Resource.Kind <> prkBlackBuffer) then
          begin
            AddDiagnostic(Diagnostics, Index, Scene.SceneId,
              'PhysicalMappings',
              'Browser Scenes must map to an explicitly declared Black Buffer.');
            Result := False;
          end;
        end;
      end;
    end
    else if MappingIndex >= 0 then
    begin
      AddDiagnostic(Diagnostics, Index, Scene.SceneId, 'PhysicalMappings',
        'ExternalApp Scenes do not accept an invented physical mapping policy.');
      Result := False;
    end;
  end;

  for Index := 0 to High(Request.Scenes) do
  begin
    Scene := Request.Scenes[Index];
    AdjacencyIndex := FindAdjacencyIndex(Request.Adjacencies, Scene.SceneId);
    if AdjacencyIndex < 0 then
    begin
      AddDiagnostic(Diagnostics, Index, Scene.SceneId, 'Adjacencies',
        'Each logical Scene requires an explicit adjacency declaration.');
      Result := False;
      Continue;
    end;
    Adjacency := Request.Adjacencies[AdjacencyIndex];
    if Index = 0 then
      ExpectedPrevious := ''
    else
      ExpectedPrevious := Request.Scenes[Index - 1].SceneId;
    if Index = High(Request.Scenes) then
      ExpectedNext := ''
    else
      ExpectedNext := Request.Scenes[Index + 1].SceneId;
    if (Adjacency.PreviousSceneId <> ExpectedPrevious) or
      (Adjacency.NextSceneId <> ExpectedNext) then
    begin
      AddDiagnostic(Diagnostics, Index, Scene.SceneId, 'Adjacencies',
        'Adjacency declaration does not match ordered logical Scene List.');
      Result := False;
    end;
  end;
  for Index := 0 to High(Request.Adjacencies) do
  begin
    if FindSceneIndex(Request.Scenes,
      Request.Adjacencies[Index].SceneId) < 0 then
    begin
      AddDiagnostic(Diagnostics, -1, Request.Adjacencies[Index].SceneId,
        'Adjacencies',
        'Adjacency declaration references an unknown logical SceneId.');
      Result := False;
    end;
    if FindAdjacencyIndex(Request.Adjacencies,
      Request.Adjacencies[Index].SceneId) <> Index then
    begin
      AddDiagnostic(Diagnostics, -1, Request.Adjacencies[Index].SceneId,
        'Adjacencies', 'Each SceneId may have only one adjacency declaration.');
      Result := False;
    end;
  end;
end;

constructor TCompiledRuntimeSnapshot.Create(const AuthoringRevision: string;
  const Scenes: TArray<TCompiledScene>;
  const PhysicalResources: TArray<TCompiledPhysicalResource>);
var
  Index: Integer;
begin
  inherited Create;
  FAuthoringRevision := AuthoringRevision;
  SetLength(FScenes, Length(Scenes));
  for Index := 0 to High(Scenes) do
    FScenes[Index] := Scenes[Index];
  SetLength(FPhysicalResources, Length(PhysicalResources));
  for Index := 0 to High(PhysicalResources) do
    FPhysicalResources[Index] := PhysicalResources[Index];
end;

function TCompiledRuntimeSnapshot.SceneCount: Integer;
begin
  Result := Length(FScenes);
end;

function TCompiledRuntimeSnapshot.GetScene(Index: Integer): TCompiledScene;
begin
  if (Index < 0) or (Index >= Length(FScenes)) then
    raise ERangeError.Create('Compiled Scene index is out of range.');
  Result := FScenes[Index];
end;

function TCompiledRuntimeSnapshot.GetPhysicalResource(
  Index: Integer): TCompiledPhysicalResource;
begin
  if (Index < 0) or (Index >= Length(FPhysicalResources)) then
    raise ERangeError.Create('Compiled physical resource index is out of range.');
  Result := FPhysicalResources[Index];
end;

function TCompiledRuntimeSnapshot.GetScenes: TArray<TCompiledScene>;
var
  Index: Integer;
begin
  SetLength(Result, Length(FScenes));
  for Index := 0 to High(FScenes) do
    Result[Index] := FScenes[Index];
end;

function TCompiledRuntimeSnapshot.GetPhysicalResources:
  TArray<TCompiledPhysicalResource>;
var
  Index: Integer;
begin
  SetLength(Result, Length(FPhysicalResources));
  for Index := 0 to High(FPhysicalResources) do
    Result[Index] := FPhysicalResources[Index];
end;

function CompileSceneList(
  const Request: TSceneCompileRequest): TSceneCompileResult;
var
  Diagnostics: TArray<TSceneCompileDiagnostic>;
  Scenes: TArray<TCompiledScene>;
  Resources: TArray<TCompiledPhysicalResource>;
  Index, MappingIndex, ResourceIndex, AdjacencyIndex: Integer;
begin
  Result := Default(TSceneCompileResult);
  if not ValidateRequest(Request, Diagnostics) then
  begin
    Result.Diagnostics := Diagnostics;
    Exit;
  end;
  SetLength(Resources, Length(Request.PhysicalResources));
  for Index := 0 to High(Resources) do
  begin
    Resources[Index].ResourceId := Request.PhysicalResources[Index].ResourceId;
    Resources[Index].Kind := Request.PhysicalResources[Index].Kind;
    Resources[Index].PhysicalSlideNumber :=
      Request.PhysicalResources[Index].PhysicalSlideNumber;
  end;
  SetLength(Scenes, Length(Request.Scenes));
  for Index := 0 to High(Scenes) do
  begin
    Scenes[Index].SceneId := Request.Scenes[Index].SceneId;
    Scenes[Index].SceneKind := Request.Scenes[Index].SceneKind;
    Scenes[Index].ExplicitVolumePercent :=
      Request.Scenes[Index].ExplicitVolumePercent;
    Scenes[Index].PowerPointLogicalSlide :=
      Request.Scenes[Index].PowerPointLogicalSlide;
    Scenes[Index].BrowserTargetReference :=
      Request.Scenes[Index].BrowserTargetReference;
    Scenes[Index].ExternalAppTargetReference :=
      Request.Scenes[Index].ExternalAppTargetReference;
    AdjacencyIndex := FindAdjacencyIndex(Request.Adjacencies,
      Request.Scenes[Index].SceneId);
    Scenes[Index].PreviousSceneId :=
      Request.Adjacencies[AdjacencyIndex].PreviousSceneId;
    Scenes[Index].NextSceneId :=
      Request.Adjacencies[AdjacencyIndex].NextSceneId;
    MappingIndex := FindMappingIndex(Request.PhysicalMappings,
      Request.Scenes[Index].SceneId);
    if MappingIndex >= 0 then
    begin
      ResourceIndex := FindResourceIndex(Request.PhysicalResources,
        Request.PhysicalMappings[MappingIndex].PhysicalResourceId);
      Scenes[Index].PhysicalResourceId :=
        Request.PhysicalResources[ResourceIndex].ResourceId;
    end;
  end;
  Result.Snapshot := TCompiledRuntimeSnapshot.Create(
    Request.ExpectedAuthoringRevision, Scenes, Resources);
  Result.Success := True;
end;

end.

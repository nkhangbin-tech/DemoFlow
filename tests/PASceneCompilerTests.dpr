program PASceneCompilerTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  PADomainTypes in '..\Domain\PADomainTypes.pas',
  PASceneDomain in '..\Domain\PASceneDomain.pas',
  PASceneCompiler in '..\Runtime\PASceneCompiler.pas';

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

function Scene(const Id: string; Kind: TSceneKind; Volume,
  Slide: Integer): TSceneDefinition;
begin
  Result := Default(TSceneDefinition);
  Result.SceneId := Id;
  Result.SceneKind := Kind;
  Result.ExplicitVolumePercent := Volume;
  Result.PowerPointLogicalSlide := Slide;
  if Kind = skBrowser then
    Result.BrowserTargetReference := 'browser-profile';
end;

function Resource(const Id: string; Kind: TPhysicalResourceKind;
  Slide: Integer): TPhysicalResourceDeclaration;
begin
  Result.ResourceId := Id;
  Result.Kind := Kind;
  Result.PhysicalSlideNumber := Slide;
end;

function Mapping(const SceneId, ResourceId: string): TScenePhysicalMapping;
begin
  Result.SceneId := SceneId;
  Result.PhysicalResourceId := ResourceId;
end;

function Adj(const Id, PreviousId, NextId: string):
  TSceneAdjacencyDeclaration;
begin
  Result.SceneId := Id;
  Result.PreviousSceneId := PreviousId;
  Result.NextSceneId := NextId;
end;

function MakeRequest: TSceneCompileRequest;
begin
  Result := Default(TSceneCompileRequest);
  Result.SourceAuthoringRevision := 'revision-7';
  Result.ExpectedAuthoringRevision := 'revision-7';
  SetLength(Result.Scenes, 4);
  Result.Scenes[0] := Scene('ppt-3', skPowerPoint, 30, 3);
  Result.Scenes[1] := Scene('ppt-4', skPowerPoint, 40, 4);
  Result.Scenes[2] := Scene('browser', skBrowser, 50, 0);
  Result.Scenes[3] := Scene('ppt-6', skPowerPoint, 60, 6);
  SetLength(Result.PhysicalResources, 4);
  Result.PhysicalResources[0] := Resource('physical-ppt-3',
    prkPowerPointSlide, 3);
  Result.PhysicalResources[1] := Resource('physical-ppt-4',
    prkPowerPointSlide, 4);
  Result.PhysicalResources[2] := Resource('physical-buffer-5',
    prkBlackBuffer, 5);
  Result.PhysicalResources[3] := Resource('physical-ppt-6',
    prkPowerPointSlide, 6);
  SetLength(Result.PhysicalMappings, 4);
  Result.PhysicalMappings[0] := Mapping('ppt-3', 'physical-ppt-3');
  Result.PhysicalMappings[1] := Mapping('ppt-4', 'physical-ppt-4');
  Result.PhysicalMappings[2] := Mapping('browser', 'physical-buffer-5');
  Result.PhysicalMappings[3] := Mapping('ppt-6', 'physical-ppt-6');
  SetLength(Result.Adjacencies, 4);
  Result.Adjacencies[0] := Adj('ppt-3', '', 'ppt-4');
  Result.Adjacencies[1] := Adj('ppt-4', 'ppt-3', 'browser');
  Result.Adjacencies[2] := Adj('browser', 'ppt-4', 'ppt-6');
  Result.Adjacencies[3] := Adj('ppt-6', 'browser', '');
end;

function HasError(const ResultValue: TSceneCompileResult;
  const FieldName: string): Boolean;
var
  Diagnostic: TSceneCompileDiagnostic;
begin
  Result := False;
  for Diagnostic in ResultValue.Diagnostics do
    if (Diagnostic.Severity = dsError) and
      (Diagnostic.FieldName = FieldName) then
      Exit(True);
end;

procedure FreeResult(var ResultValue: TSceneCompileResult);
begin
  ResultValue.Snapshot.Free;
  ResultValue.Snapshot := nil;
end;

procedure TestValidCompilation;
var
  Request: TSceneCompileRequest;
  Compiled: TSceneCompileResult;
  SceneValue, BufferValue: TCompiledScene;
  Physical: TCompiledPhysicalResource;
begin
  Request := MakeRequest;
  Compiled := CompileSceneList(Request);
  AssertTrue('Valid four-Scene compilation',
    Compiled.Success and (Compiled.Snapshot <> nil));
  AssertTrue('Four logical Scenes exclude Buffer',
    Compiled.Snapshot.SceneCount = 4);
  SceneValue := Compiled.Snapshot.GetScene(2);
  AssertTrue('Browser PREVIOUS resolves to PPT 4',
    SceneValue.PreviousSceneId = 'ppt-4');
  AssertTrue('Browser NEXT resolves to PPT 6',
    SceneValue.NextSceneId = 'ppt-6');
  AssertTrue('Browser maps to explicit Black Buffer',
    SceneValue.PhysicalResourceId = 'physical-buffer-5');
  Physical := Compiled.Snapshot.GetPhysicalResource(2);
  AssertTrue('Physical resource identity is distinct from logical slide',
    (Physical.Kind = prkBlackBuffer) and
    (Physical.PhysicalSlideNumber = 5) and
    (Physical.ResourceId <> SceneValue.SceneId));
  SceneValue := Compiled.Snapshot.GetScene(0);
  AssertTrue('Stable SceneId and logical order',
    (SceneValue.SceneId = 'ppt-3') and
    (SceneValue.PowerPointLogicalSlide = 3));
  BufferValue := Compiled.Snapshot.GetScene(1);
  AssertTrue('Compiled Scene preserves explicit volume',
    BufferValue.ExplicitVolumePercent = 40);
  AssertTrue('Compiled snapshot preserves revision',
    Compiled.Snapshot.AuthoringRevision = 'revision-7');
  FreeResult(Compiled);
end;

procedure TestFailures;
var
  Request: TSceneCompileRequest;
  Compiled: TSceneCompileResult;
begin
  Request := MakeRequest;
  Delete(Request.PhysicalResources, 2, 1);
  Compiled := CompileSceneList(Request);
  AssertTrue('Missing Buffer mapping rejected',
    (not Compiled.Success) and (Compiled.Snapshot = nil));
  FreeResult(Compiled);

  Request := MakeRequest;
  Request.PhysicalResources[3].ResourceId := 'physical-buffer-5';
  Compiled := CompileSceneList(Request);
  AssertTrue('Duplicate physical identity rejected',
    HasError(Compiled, 'PhysicalResources'));
  FreeResult(Compiled);

  Request := MakeRequest;
  Request.PhysicalMappings[2].PhysicalResourceId := 'physical-ppt-4';
  Compiled := CompileSceneList(Request);
  AssertTrue('Contradictory Browser mapping rejected',
    HasError(Compiled, 'PhysicalMappings'));
  FreeResult(Compiled);

  Request := MakeRequest;
  Request.ExpectedAuthoringRevision := 'other';
  Compiled := CompileSceneList(Request);
  AssertTrue('Revision mismatch rejected',
    HasError(Compiled, 'AuthoringRevision'));
  FreeResult(Compiled);

  Request := MakeRequest;
  Request.ExpectedAuthoringRevision := '';
  Compiled := CompileSceneList(Request);
  AssertTrue('Missing executable revision rejected',
    HasError(Compiled, 'AuthoringRevision'));
  FreeResult(Compiled);

  Request := MakeRequest;
  Request.Scenes[0].ExplicitVolumePercent := 101;
  Compiled := CompileSceneList(Request);
  AssertTrue('Invalid source Scene rejected',
    HasError(Compiled, 'ExplicitVolumePercent'));
  FreeResult(Compiled);

  Request := MakeRequest;
  SetLength(Request.Scenes, 0);
  SetLength(Request.PhysicalMappings, 0);
  SetLength(Request.Adjacencies, 0);
  Compiled := CompileSceneList(Request);
  AssertTrue('Empty editable draft cannot compile',
    (not Compiled.Success) and (Compiled.Snapshot = nil));
  FreeResult(Compiled);
end;

procedure TestOwnership;
var
  Request, Changed: TSceneCompileRequest;
  Compiled, Failed: TSceneCompileResult;
  Returned: TCompiledScene;
  ReturnedScenes: TArray<TCompiledScene>;
begin
  Request := MakeRequest;
  Compiled := CompileSceneList(Request);
  Changed := MakeRequest;
  Changed.Scenes[0].SceneId := 'changed-source';
  Changed.Scenes[1].ExplicitVolumePercent := 99;
  Returned := Compiled.Snapshot.GetScene(0);
  Returned.SceneId := 'changed-return';
  Returned.ExplicitVolumePercent := 1;
  ReturnedScenes := Compiled.Snapshot.GetScenes;
  ReturnedScenes[1].SceneId := 'changed-array';
  AssertTrue('Source mutation cannot change compiled data',
    (Compiled.Snapshot.GetScene(0).SceneId = 'ppt-3') and
    (Compiled.Snapshot.GetScene(1).ExplicitVolumePercent = 40));
  AssertTrue('Returned-data mutation cannot change compiled internals',
    (Compiled.Snapshot.GetScene(0).SceneId = 'ppt-3') and
    (Compiled.Snapshot.GetScene(1).SceneId = 'ppt-4'));

  Changed := MakeRequest;
  Changed.Scenes[0].ExplicitVolumePercent := 101;
  Failed := CompileSceneList(Changed);
  AssertTrue('Subsequent failure leaves prior snapshot unchanged',
    (not Failed.Success) and
    (Compiled.Snapshot.GetScene(0).ExplicitVolumePercent = 30));
  FreeResult(Failed);
  FreeResult(Compiled);
end;

procedure TestRecompileAndDeterminism;
var
  Request, Reordered: TSceneCompileRequest;
  First, Second: TSceneCompileResult;
begin
  Request := MakeRequest;
  First := CompileSceneList(Request);
  Reordered := MakeRequest;
  Reordered.Scenes[0] := Request.Scenes[1];
  Reordered.Scenes[1] := Request.Scenes[0];
  Reordered.Scenes[2] := Request.Scenes[2];
  Reordered.Scenes[3] := Request.Scenes[3];
  Reordered.Adjacencies[0] := Adj('ppt-4', '', 'ppt-3');
  Reordered.Adjacencies[1] := Adj('ppt-3', 'ppt-4', 'browser');
  Reordered.Adjacencies[2] := Adj('browser', 'ppt-3', 'ppt-6');
  Reordered.Adjacencies[3] := Adj('ppt-6', 'browser', '');
  Second := CompileSceneList(Reordered);
  AssertTrue('Reorder/recompile preserves SceneIds and updates adjacency',
    Second.Success and
    (Second.Snapshot.GetScene(0).SceneId = 'ppt-4') and
    (Second.Snapshot.GetScene(0).NextSceneId = 'ppt-3'));
  FreeResult(First);
  FreeResult(Second);

  First := CompileSceneList(Request);
  Second := CompileSceneList(Request);
  AssertTrue('Identical input produces deterministic results',
    First.Success and Second.Success and
    (First.Snapshot.AuthoringRevision = Second.Snapshot.AuthoringRevision) and
    (First.Snapshot.GetScene(2).PhysicalResourceId =
      Second.Snapshot.GetScene(2).PhysicalResourceId));
  FreeResult(First);
  FreeResult(Second);
end;

begin
  FailureCount := 0;
  TestCount := 0;
  TestValidCompilation;
  TestFailures;
  TestOwnership;
  TestRecompileAndDeterminism;
  Writeln('Tests run: ', TestCount);
  Writeln('Failures: ', FailureCount);
  if FailureCount <> 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.

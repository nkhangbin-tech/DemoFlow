program PASceneDomainTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  PADomainTypes in '..\Domain\PADomainTypes.pas',
  PASceneDomain in '..\Domain\PASceneDomain.pas';

var
  FailureCount: Integer;
  TestCount: Integer;

procedure AssertTrue(const TestName: string; Condition: Boolean);
begin
  Inc(TestCount);
  if not Condition then
  begin
    Inc(FailureCount);
    Writeln('FAIL ', TestName);
  end
  else
    Writeln('PASS ', TestName);
end;

function MakePowerPointScene(const Id: string;
  Volume, LogicalSlide: Integer): TSceneDefinition;
begin
  Result := Default(TSceneDefinition);
  Result.SceneId := Id;
  Result.SceneKind := skPowerPoint;
  Result.ExplicitVolumePercent := Volume;
  Result.PowerPointLogicalSlide := LogicalSlide;
end;

function MakeBrowserScene(const Id, Target: string;
  Volume: Integer): TSceneDefinition;
begin
  Result := Default(TSceneDefinition);
  Result.SceneId := Id;
  Result.SceneKind := skBrowser;
  Result.ExplicitVolumePercent := Volume;
  Result.BrowserTargetReference := Target;
end;

function MakeExternalAppScene(const Id, Target: string;
  Volume: Integer): TSceneDefinition;
begin
  Result := Default(TSceneDefinition);
  Result.SceneId := Id;
  Result.SceneKind := skExternalApp;
  Result.ExplicitVolumePercent := Volume;
  Result.ExternalAppTargetReference := Target;
end;

function SnapshotWithScene(const Scene: TSceneDefinition):
  TSceneAuthoringSnapshot;
begin
  Result := Default(TSceneAuthoringSnapshot);
  SetLength(Result.Scenes, 1);
  Result.Scenes[0] := Scene;
end;

function CopySnapshot(const Source: TSceneAuthoringSnapshot):
  TSceneAuthoringSnapshot;
var
  Index: Integer;
begin
  Result := Default(TSceneAuthoringSnapshot);
  Result.AuthoringRevision := Source.AuthoringRevision;
  Result.PresentationBaseVolumePercent := Source.PresentationBaseVolumePercent;
  SetLength(Result.Scenes, Length(Source.Scenes));
  for Index := 0 to High(Source.Scenes) do
    Result.Scenes[Index] := Source.Scenes[Index];
end;

function ScenesEqual(const Left, Right: TSceneDefinition): Boolean;
begin
  Result := (Left.SceneId = Right.SceneId) and
    (Left.SceneKind = Right.SceneKind) and
    (Left.ExplicitVolumePercent = Right.ExplicitVolumePercent) and
    (Left.PowerPointLogicalSlide = Right.PowerPointLogicalSlide) and
    (Left.BrowserTargetReference = Right.BrowserTargetReference) and
    (Left.ExternalAppTargetReference = Right.ExternalAppTargetReference);
end;

function SnapshotsEqual(const Left, Right: TSceneAuthoringSnapshot): Boolean;
var
  Index: Integer;
begin
  Result := (Left.AuthoringRevision = Right.AuthoringRevision) and
    (Left.PresentationBaseVolumePercent = Right.PresentationBaseVolumePercent) and
    (Length(Left.Scenes) = Length(Right.Scenes));
  if not Result then
    Exit;
  for Index := 0 to High(Left.Scenes) do
    if not ScenesEqual(Left.Scenes[Index], Right.Scenes[Index]) then
      Exit(False);
end;

function HasDiagnostic(const Diagnostics: TArray<TSceneValidationDiagnostic>;
  const FieldName, SceneId: string): Boolean;
var
  Diagnostic: TSceneValidationDiagnostic;
begin
  Result := False;
  for Diagnostic in Diagnostics do
    if (Diagnostic.FieldName = FieldName) and
      (Diagnostic.SceneId = SceneId) then
      Exit(True);
end;

function HasErrorDiagnostic(const Diagnostics: TArray<TSceneValidationDiagnostic>;
  SceneIndex: Integer; const FieldName, SceneId: string): Boolean;
var
  Diagnostic: TSceneValidationDiagnostic;
begin
  Result := False;
  for Diagnostic in Diagnostics do
    if (Diagnostic.Severity = dsError) and
      (Diagnostic.SceneIndex = SceneIndex) and
      (Diagnostic.FieldName = FieldName) and
      (Diagnostic.SceneId = SceneId) then
      Exit(True);
end;

function HasDescription(const Diagnostics: TArray<TSceneValidationDiagnostic>;
  const Text: string): Boolean;
var
  Diagnostic: TSceneValidationDiagnostic;
begin
  Result := False;
  for Diagnostic in Diagnostics do
    if Pos(Text, Diagnostic.Description) > 0 then
      Exit(True);
end;

function IsValid(const Snapshot: TSceneAuthoringSnapshot): Boolean;
begin
  Result := Length(ValidateSceneList(Snapshot)) = 0;
end;

procedure TestValidScenes;
var
  Snapshot: TSceneAuthoringSnapshot;
begin
  Snapshot := Default(TSceneAuthoringSnapshot);
  SetLength(Snapshot.Scenes, 3);
  Snapshot.Scenes[0] := MakePowerPointScene('ppt-intro', 50, 1);
  Snapshot.Scenes[1] := MakeBrowserScene('browser-demo', 'browser-profile',
    0);
  Snapshot.Scenes[2] := MakeExternalAppScene('external-demo', 'demo-app', 100);
  AssertTrue('Valid PowerPoint Scene', IsValid(Snapshot));
  AssertTrue('Valid Browser Scene', IsValid(SnapshotWithScene(
    Snapshot.Scenes[1])));
  AssertTrue('Valid ExternalApp Scene', IsValid(SnapshotWithScene(
    Snapshot.Scenes[2])));
end;

procedure TestVolumeValidation;
var
  Snapshot: TSceneAuthoringSnapshot;
begin
  Snapshot := Default(TSceneAuthoringSnapshot);
  SetLength(Snapshot.Scenes, 1);
  Snapshot.Scenes[0] := MakePowerPointScene('volume-zero', 0, 1);
  AssertTrue('Volume boundary 0 accepted', IsValid(Snapshot));
  Snapshot.Scenes[0] := MakePowerPointScene('volume-hundred', 100, 1);
  AssertTrue('Volume boundary 100 accepted', IsValid(Snapshot));
  Snapshot.Scenes[0] := MakePowerPointScene('volume-negative', -1, 1);
  AssertTrue('Volume -1 accepted as no override', IsValid(Snapshot));
  Snapshot.Scenes[0].ExplicitVolumePercent := -2;
  AssertTrue('Volume -2 rejected', not IsValid(Snapshot));
  Snapshot.Scenes[0].ExplicitVolumePercent := 50;
  AssertTrue('Volume 50 accepted', IsValid(Snapshot));
  Snapshot.Scenes[0] := MakePowerPointScene('volume-over', 101, 1);
  AssertTrue('Volume 101 rejected', not IsValid(Snapshot));
end;

procedure TestIdentityAndKindValidation;
var
  Snapshot: TSceneAuthoringSnapshot;
  Original: TSceneDefinition;
  Diagnostics: TArray<TSceneValidationDiagnostic>;
begin
  Snapshot := Default(TSceneAuthoringSnapshot);
  SetLength(Snapshot.Scenes, 2);
  Snapshot.Scenes[0] := MakePowerPointScene('same-id', 20, 1);
  Snapshot.Scenes[1] := MakePowerPointScene('same-id', 30, 2);
  AssertTrue('Duplicate SceneIds rejected',
    HasDiagnostic(ValidateSceneList(Snapshot), 'SceneId', 'same-id'));

  Original := Snapshot.Scenes[0];
  Snapshot.Scenes[0].SceneId := ' ';
  AssertTrue('Blank SceneId rejected', not IsValid(Snapshot));
  Snapshot.Scenes[0].SceneId := 'bad' + #1;
  AssertTrue('Invalid control-character SceneId rejected',
    not IsValid(Snapshot));
  Snapshot.Scenes[0].SceneId := 'bad' + #127;
  AssertTrue('ASCII DEL SceneId rejected', not IsValid(Snapshot));

  Snapshot.Scenes[0] := Original;
  Snapshot.Scenes[0].SceneKind := skUnknown;
  Diagnostics := ValidateSceneList(Snapshot);
  AssertTrue('Unknown SceneKind rejected',
    HasDiagnostic(Diagnostics, 'SceneKind', 'same-id'));
end;

procedure TestReferenceValidation;
var
  Snapshot: TSceneAuthoringSnapshot;
begin
  Snapshot := Default(TSceneAuthoringSnapshot);
  SetLength(Snapshot.Scenes, 1);
  Snapshot.Scenes[0] := MakePowerPointScene('missing-slide', 50, 0);
  AssertTrue('Missing PowerPoint slide rejected',
    HasDiagnostic(ValidateSceneList(Snapshot), 'PowerPointLogicalSlide',
      'missing-slide'));
  Snapshot.Scenes[0] := MakePowerPointScene('invalid-slide', 50, -1);
  AssertTrue('Invalid PowerPoint slide rejected', not IsValid(Snapshot));

  Snapshot.Scenes[0] := MakeBrowserScene('missing-browser', '', 50);
  AssertTrue('Missing Browser target rejected',
    HasDiagnostic(ValidateSceneList(Snapshot), 'BrowserTargetReference',
      'missing-browser'));
  Snapshot.Scenes[0] := MakeExternalAppScene('missing-external', '', 50);
  AssertTrue('Missing ExternalApp target rejected',
    HasDiagnostic(ValidateSceneList(Snapshot), 'ExternalAppTargetReference',
      'missing-external'));

  Snapshot.Scenes[0] := MakeBrowserScene('contradictory-browser',
    'browser-profile', 50);
  Snapshot.Scenes[0].PowerPointLogicalSlide := 2;
  AssertTrue('Contradictory Browser reference rejected',
    HasDescription(ValidateSceneList(Snapshot),
      'not valid for a Browser Scene'));
end;

procedure TestDiagnostics;
var
  Snapshot: TSceneAuthoringSnapshot;
  Diagnostics: TArray<TSceneValidationDiagnostic>;
begin
  Snapshot := Default(TSceneAuthoringSnapshot);
  SetLength(Snapshot.Scenes, 1);
  Snapshot.Scenes[0] := MakePowerPointScene('diagnostic-scene', -2, 1);
  Diagnostics := ValidateSceneList(Snapshot);
  AssertTrue('Diagnostics identify invalid Scene and field',
    HasErrorDiagnostic(Diagnostics, 0, 'ExplicitVolumePercent',
      'diagnostic-scene'));

  Snapshot := Default(TSceneAuthoringSnapshot);
  SetLength(Snapshot.Scenes, 1);
  Snapshot.Scenes[0].SceneId := ' ';
  Snapshot.Scenes[0].SceneKind := skUnknown;
  Snapshot.Scenes[0].ExplicitVolumePercent := -2;
  Diagnostics := ValidateSceneList(Snapshot);
  AssertTrue('Multi-error diagnostic count is predictable',
    Length(Diagnostics) = 3);
  AssertTrue('First diagnostic identifies SceneId error',
    (Diagnostics[0].SceneIndex = 0) and
    (Diagnostics[0].Severity = dsError) and
    (Diagnostics[0].FieldName = 'SceneId'));
  AssertTrue('Second diagnostic identifies SceneKind error',
    (Diagnostics[1].SceneIndex = 0) and
    (Diagnostics[1].Severity = dsError) and
    (Diagnostics[1].FieldName = 'SceneKind'));
  AssertTrue('Third diagnostic identifies volume error',
    (Diagnostics[2].SceneIndex = 0) and
    (Diagnostics[2].Severity = dsError) and
    (Diagnostics[2].FieldName = 'ExplicitVolumePercent'));
end;

procedure TestOrderingAndImmutability;
var
  Snapshot, Before, Input: TSceneAuthoringSnapshot;
  Diagnostics: TArray<TSceneValidationDiagnostic>;
begin
  Snapshot := Default(TSceneAuthoringSnapshot);
  SetLength(Snapshot.Scenes, 2);
  Snapshot.Scenes[0] := MakePowerPointScene('first', 10, 1);
  Snapshot.Scenes[1] := MakeExternalAppScene('second', 'external-target', 20);
  Snapshot.Scenes[1].ExternalAppTargetReference := 'external-target';
  Snapshot.AuthoringRevision := 'draft-revision-7';
  Before := CopySnapshot(Snapshot);
  Snapshot.Scenes[0] := Snapshot.Scenes[1];
  Snapshot.Scenes[1] := Before.Scenes[0];
  AssertTrue('SceneIds remain stable after reordering',
    (Snapshot.Scenes[0].SceneId = 'second') and
    (Snapshot.Scenes[1].SceneId = 'first'));
  Diagnostics := ValidateSceneList(Snapshot);
  AssertTrue('Validation returns no diagnostics for reordered valid list',
    Length(Diagnostics) = 0);

  Input := CopySnapshot(Before);
  ValidateSceneList(Input);
  AssertTrue('Valid input remains unchanged after validation',
    SnapshotsEqual(Input, Before));

  Input := CopySnapshot(Before);
  Input.Scenes[0].SceneId := 'invalid';
  Input.Scenes[0].SceneKind := skUnknown;
  Input.Scenes[0].ExplicitVolumePercent := 101;
  Input.Scenes[0].PowerPointLogicalSlide := 99;
  Input.Scenes[0].BrowserTargetReference := 'changed-browser';
  Input.Scenes[0].ExternalAppTargetReference := 'changed-external';
  Before := CopySnapshot(Input);
  ValidateSceneList(Input);
  AssertTrue('Invalid input remains unchanged after validation',
    SnapshotsEqual(Input, Before));
end;

procedure TestDraftAndRevision;
var
  Snapshot: TSceneAuthoringSnapshot;
begin
  Snapshot := Default(TSceneAuthoringSnapshot);
  Snapshot.AuthoringRevision := 'caller-token';
  AssertTrue('Empty Scene List represents an editable draft',
    IsValid(Snapshot));
  AssertTrue('AuthoringRevision is retained',
    Snapshot.AuthoringRevision = 'caller-token');
end;

begin
  FailureCount := 0;
  TestCount := 0;
  TestValidScenes;
  TestVolumeValidation;
  TestIdentityAndKindValidation;
  TestReferenceValidation;
  TestDiagnostics;
  TestOrderingAndImmutability;
  TestDraftAndRevision;
  Writeln('Tests run: ', TestCount);
  if FailureCount <> 0 then
  begin
    Writeln('Failures: ', FailureCount);
    ExitCode := 1;
  end
  else
  begin
    Writeln('Failures: 0');
    ExitCode := 0;
  end;
end.

program PAVolumeBaselineTests;
{$APPTYPE CONSOLE}
uses
  System.SysUtils,
  PADomainTypes in '..\Domain\PADomainTypes.pas',
  PASceneDomain in '..\Domain\PASceneDomain.pas',
  PASceneCompiler in '..\Runtime\PASceneCompiler.pas';
var
  TestCount, FailureCount: Integer;
procedure Check(const Name: string; Value: Boolean);
begin
  Inc(TestCount);
  if Value then Writeln('PASS ', Name)
  else begin Inc(FailureCount); Writeln('FAIL ', Name); end;
end;
function RequestFor(Base: Integer; const Volumes: array of Integer): TSceneCompileRequest;
var
  D: TSceneAuthoringSnapshot;
  I: Integer;
begin
  D := NewSceneProject;
  D.AuthoringRevision := 'baseline-revision';
  D.PresentationBaseVolumePercent := Base;
  SetLength(D.Scenes, Length(Volumes));
  for I := 0 to High(Volumes) do
  begin
    D.Scenes[I].SceneId := 'scene-' + IntToStr(I);
    D.Scenes[I].SceneKind := skExternalApp;
    D.Scenes[I].ExternalAppTargetReference := 'app';
    D.Scenes[I].ExplicitVolumePercent := Volumes[I];
  end;
  Result := NewSceneCompileRequest(D, D.AuthoringRevision);
  SetLength(Result.Adjacencies, Length(Volumes));
  for I := 0 to High(Volumes) do
  begin
    Result.Adjacencies[I].SceneId := D.Scenes[I].SceneId;
    if I > 0 then Result.Adjacencies[I].PreviousSceneId := D.Scenes[I-1].SceneId;
    if I < High(Volumes) then Result.Adjacencies[I].NextSceneId := D.Scenes[I+1].SceneId;
  end;
end;
procedure TestBaselines;
const
  Bases: array[0..2] of Integer = (0, 50, 100);
  Visits: array[0..5] of Integer = (3, 0, 2, 1, 2, 0);
var
  R: TSceneCompileRequest;
  C, Other: TSceneCompileResult;
  B, I, Expected: Integer;
  Returned: TArray<TCompiledScene>;
  Raised: Boolean;
begin
  for B in Bases do
  begin
    R := RequestFor(B, [-1, 0, -1, 100]);
    C := CompileSceneList(R);
    try
      Check('Validated base '+IntToStr(B), C.Success);
      Check('Compiled project base retained', C.Snapshot.PresentationBaseVolumePercent = B);
      Check('Initial -1 uses project base', C.Snapshot.GetActiveVolumeBaseline(0) = B);
      Check('Explicit zero is not no-override', C.Snapshot.GetActiveVolumeBaseline(1) = 0);
      Check('Later -1 preserves zero', C.Snapshot.GetActiveVolumeBaseline(2) = 0);
      Check('Explicit hundred replaces baseline', C.Snapshot.GetActiveVolumeBaseline(3) = 100);
      for I in Visits do
      begin
        if I = 0 then Expected := B
        else if I = 3 then Expected := 100 else Expected := 0;
        Check('Navigation-independent index '+IntToStr(I),
          C.Snapshot.GetActiveVolumeBaseline(I) = Expected);
      end;
      R.PresentationBaseVolumePercent := 99;
      R.Scenes[0].ExplicitVolumePercent := 10;
      Returned := C.Snapshot.GetScenes;
      Returned[0].ExplicitVolumePercent := 20;
      Check('Request and returned data cannot mutate compiled baseline',
        (C.Snapshot.GetActiveVolumeBaseline(0) = B) and
        (C.Snapshot.GetScene(0).ExplicitVolumePercent = -1) and
        (C.Snapshot.PresentationBaseVolumePercent = B));
      Raised := False;
      try C.Snapshot.GetActiveVolumeBaseline(-1); except on E: ERangeError do Raised := True; end;
      Check('Negative baseline index rejected', Raised);
      Raised := False;
      try C.Snapshot.GetActiveVolumeBaseline(4); except on E: ERangeError do Raised := True; end;
      Check('Past-end baseline index rejected', Raised);
    finally C.Snapshot.Free; end;
  end;
  R := RequestFor(50, [60, -1, -1, 0]);
  C := CompileSceneList(R);
  try
    Check('Mixed middle overrides inherited by position', C.Success and
      (C.Snapshot.GetActiveVolumeBaseline(0)=60) and
      (C.Snapshot.GetActiveVolumeBaseline(1)=60) and
      (C.Snapshot.GetActiveVolumeBaseline(2)=60) and
      (C.Snapshot.GetActiveVolumeBaseline(3)=0));
    R.ExpectedAuthoringRevision := 'mismatch';
    Other := CompileSceneList(R);
    try Check('Revision mismatch leaves existing snapshot untouched', not Other.Success and
      (Other.Snapshot=nil) and (C.Snapshot.GetActiveVolumeBaseline(2)=60));
    finally Other.Snapshot.Free; end;
  finally C.Snapshot.Free; end;
end;
procedure TestFailuresAndDefaults;
const BadBases: array[0..1] of Integer = (-1, 101);
var
  R: TSceneCompileRequest;
  C: TSceneCompileResult;
  S: TCompiledRuntimeSnapshot;
  Scenes: TArray<TCompiledScene>;
  D: TSceneAuthoringSnapshot;
  B: Integer;
  Raised: Boolean;
begin
  D := NewSceneProject;
  R := NewSceneCompileRequest(D, 'caller-revision');
  Check('Factory obtains default 50 from new project', R.PresentationBaseVolumePercent=50);
  Check('Factory preserves caller revision checks', (R.SourceAuthoringRevision='') and
    (R.ExpectedAuthoringRevision='caller-revision'));
  SetLength(D.Scenes,1);
  D.Scenes[0].SceneId := 'source';
  R := NewSceneCompileRequest(D,'caller-revision');
  R.Scenes[0].SceneId := 'changed-copy';
  Check('Compile request owns a copy of authoring Scenes', D.Scenes[0].SceneId='source');
  for B in BadBases do
  begin
    R := RequestFor(B, [-1]);
    C := CompileSceneList(R);
    try Check('Invalid project base rejected '+IntToStr(B), not C.Success and
      (C.Snapshot=nil) and (Length(C.Diagnostics)>0)); finally C.Snapshot.Free; end;
  end;
  R := RequestFor(50, [-2]);
  C := CompileSceneList(R);
  try Check('Unvalidated -2 Scene cannot compile', not C.Success and (C.Snapshot=nil));
  finally C.Snapshot.Free; end;
  R := RequestFor(50, [101]);
  C := CompileSceneList(R);
  try Check('Unvalidated 101 Scene cannot compile', not C.Success and (C.Snapshot=nil));
  finally C.Snapshot.Free; end;
  R := RequestFor(50, []);
  C := CompileSceneList(R);
  try Check('Empty authoring list cannot compile', not C.Success and (C.Snapshot=nil));
  finally C.Snapshot.Free; end;
  S := TCompiledRuntimeSnapshot.Create('empty', nil, nil);
  try
    Check('Empty direct snapshot has default base 50 and no Scenes',
      (S.SceneCount=0) and (S.PresentationBaseVolumePercent=50));
    Raised := False;
    try S.GetActiveVolumeBaseline(0); except on E: ERangeError do Raised := True; end;
    Check('Empty direct snapshot rejects baseline lookup', Raised);
  finally S.Free; end;
  SetLength(Scenes,1);
  Scenes[0].ExplicitVolumePercent := -2;
  Raised := False;
  try
    S := TCompiledRuntimeSnapshot.Create('invalid',Scenes,nil);
    S.Free;
  except on E: EArgumentOutOfRangeException do Raised := True; end;
  Check('Direct snapshot rejects invalid volume too', Raised);
end;
procedure CheckBaselines(const Name: string;
  Snapshot: TCompiledRuntimeSnapshot; const Expected: array of Integer);
var
  I: Integer;
begin
  Check(Name + ' Scene count', Snapshot.SceneCount = Length(Expected));
  if Snapshot.SceneCount <> Length(Expected) then Exit;
  for I := 0 to High(Expected) do
    Check(Name + ' at logical index ' + IntToStr(I),
      Snapshot.GetActiveVolumeBaseline(I) = Expected[I]);
end;

procedure TestOverrideAndNoOverrideRuns;
const
  Bases: array[0..2] of Integer = (0, 50, 100);
var
  B: Integer;
  R: TSceneCompileRequest;
  C: TSceneCompileResult;
begin
  for B in Bases do
  begin
    // Leading -1, adjacent 0/100 overrides, and a trailing -1 run.
    // Literal expected values deliberately do not repeat the production algorithm.
    R := RequestFor(B, [-1, -1, 0, 100, 0, 100, -1, -1]);
    C := CompileSceneList(R);
    try
      Check('Override/no-override run compiles for base ' + IntToStr(B), C.Success);
      if C.Success then
        CheckBaselines('Leading/consecutive/trailing run, base ' + IntToStr(B),
          C.Snapshot, [B, B, 0, 100, 0, 100, 100, 100]);
    finally C.Snapshot.Free; end;

    R := RequestFor(B, [-1, -1, -1]);
    C := CompileSceneList(R);
    try
      Check('All-no-override draft compiles for base ' + IntToStr(B), C.Success);
      if C.Success then
        CheckBaselines('All-no-override run, base ' + IntToStr(B),
          C.Snapshot, [B, B, B]);
    finally C.Snapshot.Free; end;
  end;
end;

procedure TestReorderedBaselineSnapshots;
const
  Order: array[0..3] of Integer = (3, 2, 0, 1);
var
  OriginalRequest, ReorderedRequest: TSceneCompileRequest;
  Project: TSceneAuthoringSnapshot;
  First, Second: TSceneCompileResult;
  Returned: TArray<TCompiledScene>;
  I: Integer;
begin
  OriginalRequest := RequestFor(50, [-1, 0, 100, -1]);
  First := CompileSceneList(OriginalRequest);
  try
    Check('Original order compiles before reorder', First.Success);
    if not First.Success then Exit;
    CheckBaselines('Original order before reorder', First.Snapshot, [50, 0, 100, 100]);

    Project := NewSceneProject;
    Project.PresentationBaseVolumePercent := 50;
    Project.AuthoringRevision := OriginalRequest.SourceAuthoringRevision;
    SetLength(Project.Scenes, Length(Order));
    for I := 0 to High(Order) do
      Project.Scenes[I] := OriginalRequest.Scenes[Order[I]];
    // Supply the project base through the approved project-copy factory.
    ReorderedRequest := NewSceneCompileRequest(Project, Project.AuthoringRevision);
    SetLength(ReorderedRequest.Adjacencies, Length(Order));
    for I := 0 to High(Order) do
    begin
      ReorderedRequest.Adjacencies[I].SceneId := Project.Scenes[I].SceneId;
      if I > 0 then
        ReorderedRequest.Adjacencies[I].PreviousSceneId := Project.Scenes[I-1].SceneId;
      if I < High(Order) then
        ReorderedRequest.Adjacencies[I].NextSceneId := Project.Scenes[I+1].SceneId;
    end;
    Second := CompileSceneList(ReorderedRequest);
    try
      Check('Reordered Scenes with updated adjacency compile', Second.Success);
      if not Second.Success then Exit;
      Check('Recompile creates a separate immutable snapshot', First.Snapshot <> Second.Snapshot);
      CheckBaselines('New logical order recalculates baseline', Second.Snapshot, [50, 100, 100, 0]);
      for I := 0 to High(Order) do
        Check('Reorder preserves SceneId and explicit volume at index ' + IntToStr(I),
          (Second.Snapshot.GetScene(I).SceneId = OriginalRequest.Scenes[Order[I]].SceneId) and
          (Second.Snapshot.GetScene(I).ExplicitVolumePercent =
            OriginalRequest.Scenes[Order[I]].ExplicitVolumePercent));
      Check('Same trailing no-override Scene now inherits project base at first position',
        (First.Snapshot.GetScene(3).SceneId = Second.Snapshot.GetScene(0).SceneId) and
        (First.Snapshot.GetActiveVolumeBaseline(3) = 100) and
        (Second.Snapshot.GetActiveVolumeBaseline(0) = 50));
      Check('Same leading no-override Scene now inherits preceding explicit hundred',
        (First.Snapshot.GetScene(0).SceneId = Second.Snapshot.GetScene(2).SceneId) and
        (First.Snapshot.GetActiveVolumeBaseline(0) = 50) and
        (Second.Snapshot.GetActiveVolumeBaseline(2) = 100));
      CheckBaselines('Original snapshot survives second compilation', First.Snapshot, [50, 0, 100, 100]);

      // Mutating both requests, their authoring source and returned copies must
      // not affect either already compiled snapshot or its positional cache.
      OriginalRequest.Scenes[2].ExplicitVolumePercent := 0;
      ReorderedRequest.Scenes[0].ExplicitVolumePercent := 0;
      ReorderedRequest.PresentationBaseVolumePercent := 0;
      Project.Scenes[0].SceneId := 'changed-after-compilation';
      Returned := First.Snapshot.GetScenes;
      Returned[0].ExplicitVolumePercent := 100;
      Returned := Second.Snapshot.GetScenes;
      Returned[0].ExplicitVolumePercent := 100;
      CheckBaselines('Original snapshot after caller mutations', First.Snapshot, [50, 0, 100, 100]);
      CheckBaselines('Reordered snapshot after caller mutations', Second.Snapshot, [50, 100, 100, 0]);
      Check('Both compiled bases and Scene identities remain unchanged',
        (First.Snapshot.PresentationBaseVolumePercent = 50) and
        (Second.Snapshot.PresentationBaseVolumePercent = 50) and
        (First.Snapshot.GetScene(0).SceneId = 'scene-0') and
        (Second.Snapshot.GetScene(0).SceneId = 'scene-3') and
        (First.Snapshot.GetScene(0).ExplicitVolumePercent = -1) and
        (Second.Snapshot.GetScene(0).ExplicitVolumePercent = -1));
      First.Snapshot.Free;
      First.Snapshot := nil;
      CheckBaselines('Second snapshot survives destruction of first', Second.Snapshot, [50, 100, 100, 0]);
    finally Second.Snapshot.Free; end;
  finally First.Snapshot.Free; end;
end;

procedure TestIndependentProjectBases;
var
  R: TSceneCompileRequest;
  First, Second: TSceneCompileResult;
begin
  R := RequestFor(0, [-1, -1]);
  First := CompileSceneList(R);
  try
    Check('Independent base-zero snapshot compiles', First.Success);
    if not First.Success then Exit;
    R := RequestFor(100, [-1, -1]);
    Second := CompileSceneList(R);
    try
      Check('Independent base-hundred snapshot compiles', Second.Success);
      if not Second.Success then Exit;
      CheckBaselines('Base-zero snapshot after base-hundred compilation', First.Snapshot, [0, 0]);
      CheckBaselines('Base-hundred snapshot', Second.Snapshot, [100, 100]);
      Check('Interleaved lookups cannot share baseline state',
        (Second.Snapshot.GetActiveVolumeBaseline(1) = 100) and
        (First.Snapshot.GetActiveVolumeBaseline(0) = 0) and
        (Second.Snapshot.GetActiveVolumeBaseline(0) = 100) and
        (First.Snapshot.GetActiveVolumeBaseline(1) = 0));
      Check('Different project bases remain immutable and distinct',
        (First.Snapshot.PresentationBaseVolumePercent = 0) and
        (Second.Snapshot.PresentationBaseVolumePercent = 100));
    finally Second.Snapshot.Free; end;
    CheckBaselines('First snapshot survives destruction of second', First.Snapshot, [0, 0]);
  finally First.Snapshot.Free; end;
end;

begin
  TestBaselines;
  TestFailuresAndDefaults;
  TestOverrideAndNoOverrideRuns;
  TestReorderedBaselineSnapshots;
  TestIndependentProjectBases;
  Writeln('Tests run: ',TestCount);
  Writeln('Failures: ',FailureCount);
  if FailureCount<>0 then ExitCode:=1;
end.
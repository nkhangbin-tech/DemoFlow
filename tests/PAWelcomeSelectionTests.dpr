program PAWelcomeSelectionTests;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.IOUtils, Vcl.Forms,
 PAPresentationDiscovery, PASceneDomain, PASceneDocumentCodec,
 PASceneProjectFileStore, PASceneProjectSession, PARecentProject, uWelcomeForm;
type
 TTestWelcome = class(TWelcomeForm)
 public
  Snapshot:TPresentationCandidates;
  ScanCount:Integer;
  function ScanPresentations(out ErrorText:string):TPresentationCandidates; override;
  procedure ChooseProject(const FileName:string);
 end;
function TTestWelcome.ScanPresentations(out ErrorText:string):TPresentationCandidates;
begin Inc(ScanCount); ErrorText:=''; Result:=Copy(Snapshot); end;
procedure TTestWelcome.ChooseProject(const FileName:string);
begin SelectProjectFile(FileName); end;
var N,F:Integer;
procedure Check(const Name:string; OK:Boolean);
begin Inc(N); if OK then Writeln('PASS ',Name) else begin Inc(F); Writeln('FAIL ',Name); end; end;
procedure ManualOpen(W:TTestWelcome; Index:Integer);
begin W.cboOpenPowerPoint.ItemIndex:=Index; W.cboOpenPowerPoint.OnChange(W.cboOpenPowerPoint); end;
procedure Run;
var W:TTestWelcome; P,Q,R:TPresentationCandidate; D:TSceneAuthoringSnapshot;
 Dir,V3,V1,V2,Other,S,Before,Err:string; I:Integer; Session:TSceneProjectSession;
begin
 Dir:=TPath.Combine(TPath.GetTempPath,'pa-ux02-'+TGUID.NewGuid.ToString);
 TDirectory.CreateDirectory(Dir);
 W:=TTestWelcome.Create(nil); Session:=TSceneProjectSession.Create;
 try
  Before:=SerializeSceneDocument(ActiveProjectSession.GetDocument);
  P:=Default(TPresentationCandidate); P.WindowKey:=10; P.Title:='Unrelated window caption';
  P.FullName:='C:\Deck.pptx'; P.FileName:='Deck.pptx'; P.SlideCount:=80;
  Q:=P; Q.WindowKey:=20; Q.Title:='Deck.pptx'; Q.FullName:='C:\Other.pptx'; Q.FileName:='Other.pptx';
  R:=P; R.WindowKey:=30; R.FullName:='D:\Deck.pptx';
  W.btnCreateRefresh.Click;
  Check('Create zero documents stays empty and disabled',(W.cboCreatePowerPoint.ItemIndex=-1)and not W.btnCreate.Enabled);
  W.Snapshot:=TArray<TPresentationCandidate>.Create(P); W.btnCreateRefresh.Click;
  Check('Create one document preselects first and enables',(W.cboCreatePowerPoint.ItemIndex=0)and W.btnCreate.Enabled);
  W.Snapshot:=TArray<TPresentationCandidate>.Create(P,Q); W.btnCreateRefresh.Click;
  Check('Create multiple documents selects first',(W.cboCreatePowerPoint.ItemIndex=0)and W.btnCreate.Enabled);
  W.cboCreatePowerPoint.ItemIndex:=1;
  W.Snapshot:=TArray<TPresentationCandidate>.Create(Q,P); W.btnCreateRefresh.Click;
  Check('Create refresh follows candidate identity through reorder',W.cboCreatePowerPoint.ItemIndex=0);
  W.Snapshot:=TArray<TPresentationCandidate>.Create(P); W.btnCreateRefresh.Click;
  Check('Create vanished selection falls back to first',(W.cboCreatePowerPoint.ItemIndex=0)and W.btnCreate.Enabled);
  W.Snapshot:=nil; W.btnCreateRefresh.Click;
  Check('Create disappearing last document disables action',(W.cboCreatePowerPoint.ItemIndex=-1)and not W.btnCreate.Enabled);
  D:=NewSceneProject; D.PowerPointFileName:='Deck.pptx'; D.PowerPointSlideCount:=80;
  D.AuthoringRevision:='unchanged'; V3:=TPath.Combine(Dir,'v3.json');
  TFile.WriteAllText(V3,SerializeSceneDocument(D),TEncoding.UTF8);
  Other:=TPath.Combine(Dir,'other-v3.json'); D.PowerPointFileName:='Other.pptx';
  TFile.WriteAllText(Other,SerializeSceneDocument(D),TEncoding.UTF8);
  W.Snapshot:=TArray<TPresentationCandidate>.Create(Q,P); W.ChooseProject(V3);
  Check('Open matches actual FileName, not caption',(W.cboOpenPowerPoint.ItemIndex=1)and W.btnOpen.Enabled);
  Check('Selecting project rescans discovery',W.ScanCount>0);
  ManualOpen(W,0); W.Snapshot:=TArray<TPresentationCandidate>.Create(P,Q); W.btnOpenRefresh.Click;
  Check('Open refresh retains explicit manual candidate through reorder',W.cboOpenPowerPoint.ItemIndex=1);
  W.Snapshot:=TArray<TPresentationCandidate>.Create(P); W.btnOpenRefresh.Click;
  Check('Vanished manual candidate re-evaluates unique project match',W.cboOpenPowerPoint.ItemIndex=0);
  W.Snapshot:=TArray<TPresentationCandidate>.Create(Q); W.btnOpenRefresh.Click;
  Check('Open no filename match is empty and disabled',(W.cboOpenPowerPoint.ItemIndex=-1)and not W.btnOpen.Enabled);
  W.Snapshot:=TArray<TPresentationCandidate>.Create(P,R); W.btnOpenRefresh.Click;
  Check('Open duplicate filename matches require manual selection',(W.cboOpenPowerPoint.ItemIndex=-1)and not W.btnOpen.Enabled);
  ManualOpen(W,1); W.Snapshot:=TArray<TPresentationCandidate>.Create(R,P); W.btnOpenRefresh.Click;
  Check('Duplicate filenames retain explicitly chosen document window',W.cboOpenPowerPoint.ItemIndex=0);
  W.ChooseProject(Other);
  Check('New v3 project does not inherit previous project manual candidate',W.cboOpenPowerPoint.ItemIndex=-1);
  W.Snapshot:=TArray<TPresentationCandidate>.Create(Q,P); W.ChooseProject(Other);
  Check('New v3 metadata gets its own unique match',W.cboOpenPowerPoint.ItemIndex=0);
  P.SlideCount:=79; W.Snapshot:=TArray<TPresentationCandidate>.Create(P); W.ChooseProject(V3);
  Check('Filename match with different SlideCount stays preselected',(W.cboOpenPowerPoint.ItemIndex=0)and W.btnOpen.Enabled);
  Check('Existing Open rejects slide-count mismatch',Session.OpenProject(V3).Success and not Session.BindPresentation(P,False,Err)and(Pos('slide count',Err)>0));
  Check('Mismatch never establishes an active context',not Session.HasActiveContext);
  P.SlideCount:=80; P.FileName:='dEcK.PpTx'; W.Snapshot:=TArray<TPresentationCandidate>.Create(P); W.btnOpenRefresh.Click;
  Check('Filename matching follows Windows case-insensitive convention',W.cboOpenPowerPoint.ItemIndex=0);
  Check('Matching candidate still requires successful binding',Session.BindPresentation(P,False,Err));
  D:=NewSceneProject; S:=SerializeSceneDocument(D);
  V2:=TPath.Combine(Dir,'v2.json'); TFile.WriteAllText(V2,S,TEncoding.UTF8);
  V1:=TPath.Combine(Dir,'v1.json');
  S:=StringReplace(S,'"projectFormatVersion":2','"projectFormatVersion":1',[]);
  S:=StringReplace(S,'"presentationBaseVolumePercent":50,','',[]);
  TFile.WriteAllText(V1,S,TEncoding.UTF8);
  for I:=1 to 2 do begin
   W.cboOpenPowerPoint.ItemIndex:=-1; W.cboOpenPowerPoint.OnChange(W.cboOpenPowerPoint);
   if I=1 then W.ChooseProject(V1) else W.ChooseProject(V2);
   Check('Legacy '+IntToStr(I)+' never guesses a PPT',(W.cboOpenPowerPoint.ItemIndex=-1)and not W.btnOpen.Enabled);
   ManualOpen(W,0); W.btnOpenRefresh.Click;
   Check('Legacy '+IntToStr(I)+' preserves explicit manual choice',W.cboOpenPowerPoint.ItemIndex=0);
   if I=1 then Session.OpenProject(V1) else Session.OpenProject(V2);
   Check('Legacy '+IntToStr(I)+' still requires affirmative confirmation',not Session.BindPresentation(P,False,Err));
  end;
  W.ChooseProject(V3); W.Snapshot:=TArray<TPresentationCandidate>.Create(Q,P);
  RecordRecentProject(V3); W.OnShow(W); W.btnReopen.Click;
  Check('Reopen uses unique FileName preselection',(W.edtProjectFile.Text=V3)and(W.cboOpenPowerPoint.ItemIndex=1)and W.btnOpen.Enabled);
  W.Snapshot:=TArray<TPresentationCandidate>.Create(P,R);
  W.OnShow(W); W.btnReopen.Click;
  Check('Reopen ambiguous filename stays unselected',(W.cboOpenPowerPoint.ItemIndex=-1)and not W.btnOpen.Enabled);
  RecordRecentProject(V1); W.OnShow(W); W.btnReopen.Click;
  Check('Reopen legacy does not guess a binding',(W.edtProjectFile.Text=V1)and(W.cboOpenPowerPoint.ItemIndex=-1));
  ManualOpen(W,1); W.btnReopen.Click;
  Check('Reopen same legacy preserves manual candidate',W.cboOpenPowerPoint.ItemIndex=1);
  Check('Preselection never creates or replaces active project',SerializeSceneDocument(ActiveProjectSession.GetDocument)=Before);
  W.ChooseProject(TPath.Combine(Dir,'missing.json'));
  Check('Project loading failure does not guess selection',(W.cboOpenPowerPoint.ItemIndex=-1)and not W.btnOpen.Enabled);
  Check('Project loading failure preserves active session',SerializeSceneDocument(ActiveProjectSession.GetDocument)=Before);
 finally W.Free; Session.Free; TDirectory.Delete(Dir,True); end;
end;
begin
 Application.Initialize;
 try Run; except on E:Exception do Check(E.ClassName+': '+E.Message,False); end;
 Writeln('Tests run: ',N); Writeln('Failures: ',F); if F<>0 then ExitCode:=1;
end.

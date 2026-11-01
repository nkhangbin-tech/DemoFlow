program PAWelcomeIntegrationTests;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.IOUtils, Winapi.Windows, Vcl.Forms,
 PASceneDomain, PASceneDocumentCodec, PASceneProjectFileStore, PASceneProjectSession,
 PAPresentationDiscovery, PARecentProject, uWelcomeForm, uSceneEditorForm;
var N,F:Integer;
procedure Check(const Name:string; OK:Boolean);
begin Inc(N); if OK then Writeln('PASS ',Name) else begin Inc(F); Writeln('FAIL ',Name); end; end;
procedure Run;
var P,Q,R:TPresentationCandidate; Items:TPresentationCandidates;
 A,B:TSceneProjectSession; D,E:TSceneAuthoringSnapshot; Parsed:TSceneDocumentResult;
 L:TSceneFileLoadResult; S,T,Dir,Source,Target,Err,Before:string; I:Integer;
 Saved:TProjectSaveResult; H:THandle; AliasPath,Worked:string; Original:TBytes;
 W:TWelcomeForm; Editor:TfrmSceneEditor; Raised:Boolean;
begin
 P:=Default(TPresentationCandidate); P.WindowKey:=10; P.Title:='Duplicate';
 P.FullName:='C:\Deck.pptx'; P.FileName:='Deck.pptx'; P.SlideCount:=3;
 Q:=P; Q.WindowKey:=20; Q.FullName:='D:\Deck.pptx';
 Check('No eligible documents',not FindPresentation(nil,P,R));
 Items:=TArray<TPresentationCandidate>.Create(Q,P);
 Check('Duplicate captions resolve by window and path',FindPresentation(Items,P,R) and(R.WindowKey=10));
 Items:=TArray<TPresentationCandidate>.Create(Q);
 Check('Closed selected window rejected',not FindPresentation(Items,P,R));
 Q:=P; Inc(Q.SlideCount); Items:=TArray<TPresentationCandidate>.Create(Q);
 Check('Changed slide count rejected',not FindPresentation(Items,P,R));
 Q:=P; Q.FullName:='C:\Other.pptx'; Items:=TArray<TPresentationCandidate>.Create(Q);
 Check('Changed document rejected',not FindPresentation(Items,P,R));
 A:=TSceneProjectSession.Create; B:=TSceneProjectSession.Create;
 Dir:=TPath.Combine(TPath.GetTempPath,'pa-welcome-'+TGUID.NewGuid.ToString);
 TDirectory.CreateDirectory(Dir);
 try
  A.PrepareNew(P); D:=A.GetDocument;
  Check('Create has context and dirty unsaved state',A.HasActiveContext and A.Modified and(A.ActivePath=''));
  Check('Project base 50 and N Scenes',(D.PresentationBaseVolumePercent=50)and(Length(D.Scenes)=3));
  for I:=0 to 2 do Check('Logical slide and volume '+IntToStr(I),
    (D.Scenes[I].PowerPointLogicalSlide=I+1)and(D.Scenes[I].SceneKind=skPowerPoint)and(D.Scenes[I].ExplicitVolumePercent=-1));
  S:=SerializeSceneDocument(D); Parsed:=ParseSceneDocument(S);
  Check('v3 metadata round trip',Parsed.Success and(Parsed.SourceFormatVersion=3)and(SerializeSceneDocument(Parsed.Document)=S));
  for T in ['"powerPointFileName":"Deck.pptx",','"powerPointSlideCount":3,'] do
    Check('Required v3 field '+T,not ParseSceneDocument(StringReplace(S,T,'',[])).Success);
  Check('Negative count rejected',not ParseSceneDocument(StringReplace(S,'"powerPointSlideCount":3','"powerPointSlideCount":-1',[])).Success);
  Check('Fractional count rejected',not ParseSceneDocument(StringReplace(S,'"powerPointSlideCount":3','"powerPointSlideCount":1.5',[])).Success);
  Check('Empty filename rejected',not ParseSceneDocument(StringReplace(S,'Deck.pptx','',[])).Success);
  Check('Path is not basename',not ParseSceneDocument(StringReplace(S,'Deck.pptx','dir/Deck.pptx',[])).Success);
  Check('Missing extension rejected',not ParseSceneDocument(StringReplace(S,'Deck.pptx','Deck',[])).Success);
  Check('Duplicate metadata rejected',not ParseSceneDocument(StringReplace(S,'"powerPointSlideCount":3','"powerPointSlideCount":3,"powerPointSlideCount":3',[])).Success);
  Check('Unknown v3 property rejected',not ParseSceneDocument(StringReplace(S,'"powerPointSlideCount":3','"powerPointSlideCount":3,"other":0',[])).Success);
  Check('Wrong metadata type rejected',not ParseSceneDocument(StringReplace(S,'"powerPointSlideCount":3','"powerPointSlideCount":"3"',[])).Success);
  Source:=TPath.Combine(Dir,'source.json'); Target:=TPath.Combine(Dir,'new.json');
  Check('Save new v3',A.SaveAs(Source).Status=psSaved);
  Check('Successful Save records one recent project',SameText(RecentProjectPath(Worked),Source)and(Worked<>''));
  L:=B.OpenProject(Source); Check('Load does not establish active context',L.Success and not B.HasActiveContext);
  Q:=P; Q.FileName:='Wrong.pptx'; Before:=SerializeSceneDocument(B.GetDocument);
  Check('Filename mismatch preserves candidate',not B.BindPresentation(Q,False,Err) and(SerializeSceneDocument(B.GetDocument)=Before));
  Q:=P; Inc(Q.SlideCount);
  Check('Slidecount mismatch rejected',not B.BindPresentation(Q,False,Err));
  Check('Matching v3 binding',B.BindPresentation(P,False,Err) and not B.LegacyBinding);
  B.SelectScene(0); B.TrySetSceneVolume(0,77); Before:=SerializeSceneDocument(B.GetDocument);
  L:=B.OpenProject(TPath.Combine(Dir,'missing.json'));
  Check('Failed open preserves active dirty state',not L.Success and B.HasActiveContext and B.Modified and(SerializeSceneDocument(B.GetDocument)=Before));
  Saved:=B.SaveAs(''); Check('Cancel preserves state',(Saved.Status=psCancelled)and B.Modified and(SerializeSceneDocument(B.GetDocument)=Before));
  Saved:=B.SaveAs(Source); Check('Same source Save As rejected',Saved.Status=psFailed);
  AliasPath:=TPath.Combine(Dir,'source-alias.json');
  if not CreateHardLink(PWideChar(AliasPath),PWideChar(Source),nil) then RaiseLastOSError;
  Saved:=B.SaveAs(AliasPath);
  Check('Hardlink alias source rejected',Saved.Status=psFailed);
  TFile.Delete(AliasPath);
  H:=CreateFile(PWideChar(Source),GENERIC_READ,FILE_SHARE_READ,nil,OPEN_EXISTING,0,0);
  try Saved:=B.Save; finally CloseHandle(H); end;
  Check('Failed save preserves active state',(Saved.Status=psFailed)and B.Modified and(SerializeSceneDocument(B.GetDocument)=Before));
  for I:=1 to 2 do
  begin
    E:=D; E.Scenes:=Copy(D.Scenes); E.PowerPointFileName:=''; E.PowerPointSlideCount:=0;
    E.Scenes[0].PowerPointLogicalSlide:=99; E.Scenes[1].ExplicitVolumePercent:=100;
    T:=SerializeSceneDocument(E);
    if I=1 then begin T:=StringReplace(T,'"projectFormatVersion":2','"projectFormatVersion":1',[]);
      T:=StringReplace(T,'"presentationBaseVolumePercent":50,','',[]); end;
    TFile.WriteAllText(Source,T,TEncoding.UTF8); Original:=TFile.ReadAllBytes(Source);
    L:=B.OpenProject(Source);
    Check('Legacy parse original format '+IntToStr(I),L.Success and(B.SourceFormatVersion=I)and(B.GetDocument.PowerPointFileName=''));
    Check('Ordinary file-store Save protects legacy '+IntToStr(I),not SaveSceneProject(Source,E).Success);
    Check('Unbound legacy Save As rejected '+IntToStr(I),not SaveSceneProjectAs(L,Target,E).Success);
    Check('Legacy rejects unconfirmed binding '+IntToStr(I),not B.BindPresentation(P,False,Err));
    Check('Legacy confirmation retains scenes '+IntToStr(I),B.BindPresentation(P,True,Err) and B.LegacyBinding and
      (B.GetScene(0).PowerPointLogicalSlide=99)and(B.GetScene(1).ExplicitVolumePercent=100));
    Check('Legacy ordinary Save blocked '+IntToStr(I),B.Save.Status=psSaveAsRequired);
    Before:=SerializeSceneDocument(B.GetDocument);
    Check('Legacy cancel preserves context '+IntToStr(I),(B.SaveAs('').Status=psCancelled)and(B.SourceFormatVersion=I)and(SerializeSceneDocument(B.GetDocument)=Before));
    Check('Legacy same-source rejected '+IntToStr(I),B.SaveAs(Source).Status=psFailed);
    Check('Legacy failure retains source version '+IntToStr(I),(B.SaveAs(TPath.Combine(Dir,'missing/fail.json')).Status=psFailed)and(B.SourceFormatVersion=I));
    if TFile.Exists(Target) then TFile.Delete(Target);
    Check('Legacy explicit Save As v3 '+IntToStr(I),(B.SaveAs(Target).Status=psSaved)and(B.SourceFormatVersion=3)and not B.LegacyBinding);
    Check('Original legacy bytes preserved '+IntToStr(I),TFile.ReadAllText(Source,TEncoding.UTF8)=T);
    Parsed:=ParseSceneDocument(TFile.ReadAllText(Target,TEncoding.UTF8));
    Check('Draft/order/revision preserved '+IntToStr(I),Parsed.Success and(SerializeSceneDocument(Parsed.Document)=Before));
  end;
  Q:=P; Q.SlideCount:=0;
  A.PrepareNew(Q); Check('Zero-slide project remains new dirty draft',A.HasActiveContext and A.Modified and(A.SceneCount=0));
  Before:=SerializeSceneDocument(A.GetDocument); Q.SlideCount:=-1; Raised:=False;
  try A.PrepareNew(Q); except on Ex:EArgumentException do Raised:=True; end;
  Check('Invalid Create candidate preserves active state',Raised and(SerializeSceneDocument(A.GetDocument)=Before));
  A.AdoptCandidate(B); Check('Candidate adoption detaches array',A.HasActiveContext and(A.SourceFormatVersion=3));
  B.TrySetSceneVolume(0,12); Check('No candidate alias after adoption',A.GetScene(0).ExplicitVolumePercent<>12);
  ActiveProjectSession.AdoptCandidate(A);
  W:=TWelcomeForm.Create(nil); Editor:=TfrmSceneEditor.Create(nil);
  try
    Check('Welcome selectors empty unselected',(W.cboCreatePowerPoint.Items.Count=0)and(W.cboOpenPowerPoint.ItemIndex=-1));
    Check('Initial entry buttons disabled',not W.btnCreate.Enabled and not W.btnOpen.Enabled and not W.btnReopen.Enabled);
    Check('Project path is read only',W.edtProjectFile.ReadOnly);
    Check('Designer resolves Create Refresh handler',W.MethodAddress('btnCreateRefreshClick')<>nil);
    Check('Shared application-owned session',Editor.Session=ActiveProjectSession);
    Check('Manual PPT menu unavailable',not Editor.miPowerPoint.Visible and not Editor.miPowerPoint.Enabled);
    I:=Editor.Session.SceneCount; Editor.AddScene(skPowerPoint);
    Check('Manual PPT insertion rejected',Editor.Session.SceneCount=I);
    Editor.SelectScene(0); Editor.AddScene(skBrowser);
    Check('Browser inserts after selected Scene',Editor.Session.GetScene(1).SceneKind=skBrowser);
    Editor.AddScene(skExternalApp); Check('External App allowed',Editor.Session.GetScene(2).SceneKind=skExternalApp);
    Check('Editor Open cannot bypass linking',not Editor.OpenProject(Source).Success);
  finally Editor.Free; W.Free; end;
 finally A.Free; B.Free; TDirectory.Delete(Dir,True); end;
end;
begin
 Application.Initialize;
 try Run; except on E:Exception do Check(E.ClassName+': '+E.Message,False); end;
 Writeln('Tests run: ',N); Writeln('Failures: ',F); if F<>0 then ExitCode:=1;
end.

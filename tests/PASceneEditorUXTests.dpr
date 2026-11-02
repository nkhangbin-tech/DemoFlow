program PASceneEditorUXTests;
{$APPTYPE CONSOLE}
uses
 System.SysUtils, System.IOUtils, System.Classes, Winapi.Windows,
 Vcl.Forms, Vcl.Controls, Vcl.StdCtrls,
 VirtualTrees, VirtualTrees.Types,
 PASceneDomain, PASceneDocumentCodec, PASceneProjectFileStore,
 PASceneProjectSession, PAPresentationDiscovery, PARecentProject, uSceneEditorForm;
type
 TTestEditor = class(TfrmSceneEditor)
 public
  Choice: TEditorCloseChoice;
  AcceptFile: Boolean;
  NextFile: string;
  PromptCount, PickerCount, ErrorCount, WelcomeCount: Integer;
  ActiveAtPrompt, NestedCloseBlocked: Boolean;
  ReenterClose: Boolean;
  function ChooseCloseAction: TEditorCloseChoice; override;
  function ChooseSaveAsFile(out FileName: string): Boolean; override;
  procedure PresentSaveError(const ErrorText: string); override;
  procedure ReturnToWelcome; override;
 end;
var N,F:Integer;
procedure Check(const Name:string; OK:Boolean);
begin
 Inc(N);
 if OK then Writeln('PASS ',Name) else begin Inc(F); Writeln('FAIL ',Name); end;
end;
function TTestEditor.ChooseCloseAction:TEditorCloseChoice;
var CanClose:Boolean;
begin
 Inc(PromptCount); ActiveAtPrompt:=Session.HasActiveContext;
 if ReenterClose then begin
  CanClose:=True; OnCloseQuery(Self,CanClose);
  NestedCloseBlocked:=not CanClose;
 end;
 Result:=Choice;
end;
function TTestEditor.ChooseSaveAsFile(out FileName:string):Boolean;
begin Inc(PickerCount); FileName:=NextFile; Result:=AcceptFile; end;
procedure TTestEditor.PresentSaveError(const ErrorText:string);
begin Inc(ErrorCount); Check('Failure reports a nonempty error',ErrorText<>''); end;
procedure TTestEditor.ReturnToWelcome;
begin
 Inc(WelcomeCount);
 Check('Return to Navigation Hub occurs only after context is closed',not Session.HasActiveContext);
end;
function CloseByX(Editor:TTestEditor):Boolean;
begin
 Result:=False;
 Editor.OnCloseQuery(Editor,Result); // Actual X-close decision handler, no modal UI in tests.
end;
function State(S:TSceneProjectSession):string;
begin Result:=SerializeSceneDocument(S.GetDocument); end;
function BytesEqual(const A,B:TBytes):Boolean;
var I:Integer;
begin
 if Length(A)<>Length(B) then Exit(False);
 for I:=0 to High(A) do if A[I]<>B[I] then Exit(False);
 Result:=True;
end;
function Candidate(Slides:Integer):TPresentationCandidate;
begin
 Result:=Default(TPresentationCandidate);
 Result.WindowKey:=1; Result.FileName:='Deck.pptx';
 Result.FullName:='C:\Deck.pptx'; Result.Title:='Deck.pptx'; Result.SlideCount:=Slides;
end;
function NewEditor(const SavedPath:string; Slides:Integer):TTestEditor;
begin
 ActiveProjectSession.NewProject;
 ActiveProjectSession.PrepareNew(Candidate(Slides));
 if SavedPath<>'' then
  Check('Fixture persists active v3 project',ActiveProjectSession.SaveAs(SavedPath).Status=psSaved);
 Result:=TTestEditor.Create(nil);
end;
procedure TestSelectionAndFormatting(const Directory:string);
var E:TTestEditor; Before,Id0,Id1,Text,Volume,LeftText:string;
 Scene:TSceneDefinition; V,Width:Integer;
begin
 E:=NewEditor(TPath.Combine(Directory,'selection.json'),2);
 try
  Before:=State(E.Session); Id0:=E.Session.GetScene(0).SceneId; Id1:=E.Session.GetScene(1).SceneId;
  Check('Opening chooses first Scene when no valid selection exists',
   (E.Session.SelectedIndex=0)and(E.vstScenes.FocusedNode=E.vstScenes.GetFirst)and
   (E.crpSceneDetails.ActiveCard=E.crdPowerPoint));
  Check('Initial selection never marks saved document Modified',not E.Session.Modified and(State(E.Session)=Before));
  E.SelectScene(1); E.OnShow(E);
  Check('Returning to same session preserves valid selection',
   (E.Session.SelectedIndex=1)and(E.vstScenes.FocusedNode=E.vstScenes.GetLast)and
   (E.edtExplicitVolume.Text='-1')and not E.Session.Modified);
  Check('Selection preserves identities and authoring revision',
   (E.Session.GetScene(0).SceneId=Id0)and(E.Session.GetScene(1).SceneId=Id1)and(State(E.Session)=Before));
  Check('PO hidden navigation/live controls remain hidden',
   not E.btnBackToWelcome.Visible and not E.btnStartLive.Visible);
  Check('Hidden Back button is not a navigation route',not Assigned(E.btnBackToWelcome.OnClick));
  Check('No new Readiness navigation handler installed',not Assigned(E.btnReadiness.OnClick));
  Scene:=E.Session.GetScene(0);
  LeftText:='1. PowerPoint '+#$00B7+' Slide 1';
  Check('PowerPoint left text is position, kind and logical slide',SceneListSceneText(Scene,0)=LeftText);
  E.vstScenes.OnGetText(E.vstScenes,E.vstScenes.GetFirst,0,ttNormal,Text);
  Check('Actual tree Scene callback omits GUIDs and separator',
   (Text=LeftText)and(Pos(Scene.SceneId,Text)=0)and(Pos('|',Text)=0));
  Check('Technical identity remains in Inspector',Pos(Id1,E.lblSceneId.Caption)>0);
  for V in [-1,0,50,100] do begin
   Scene.ExplicitVolumePercent:=V;
   if V=-1 then Volume:=#$2014 else Volume:=IntToStr(V)+'%';
   Check('Correct volume presentation '+IntToStr(V),SceneListVolumeText(Scene)=Volume);
  end;
  Scene.SceneKind:=skBrowser; Scene.SceneId:=StringOfChar('X',4096);
  Scene.BrowserTargetReference:=StringOfChar('R',4096);
  Check('Browser label is grounded kind without invented display name or GUID',
   SceneListSceneText(Scene,2)='3. Browser');
  Scene.SceneKind:=skExternalApp;
  Check('External App label uses approved kind name',SceneListSceneText(Scene,3)='4. External App');
  Check('Designer dependency remains explicit: tree has Scene and Volume columns',
   (E.vstScenes.Header.Columns.Count=2)and
   (E.vstScenes.Header.Columns[0].Alignment=taLeftJustify)and
   (E.vstScenes.Header.Columns[1].Alignment=taCenter));
  // Resize only the test instance, simulating the user's existing splitter.
  for Width in [380,560,420] do begin
   E.pnlSceneList.Width:=Width;
   E.vstScenes.OnGetText(E.vstScenes,E.vstScenes.GetFirst,0,ttNormal,Text);
   Check('Resize preserves two-column layout and Scene text '+IntToStr(Width),
    (Text=LeftText)and(E.vstScenes.Header.Columns.Count=2)and
    (E.vstScenes.Header.Columns[0].Alignment=taLeftJustify)and
    (E.vstScenes.Header.Columns[1].Alignment=taCenter)and
    (E.vstScenes.Header.AutoSizeIndex=0)and
    (hoAutoResize in E.vstScenes.Header.Options));
  end;
  E.SelectScene(0); E.AddScene(skBrowser);
  Check('Insertion remains immediately after selection with stable PowerPoint identities',
   (E.Session.SelectedIndex=1)and(E.Session.GetScene(0).SceneId=Id0)and
   (E.Session.GetScene(2).SceneId=Id1));
  E.btnMoveDown.Click; E.btnRemoveScene.Click;
  Check('Move/remove retain surviving Scene ids and order',
   (E.Session.SceneCount=2)and(E.Session.GetScene(0).SceneId=Id0)and(E.Session.GetScene(1).SceneId=Id1));
 finally E.Free; end;
 E:=NewEditor(TPath.Combine(Directory,'empty.json'),0);
 try
  Before:=State(E.Session); E.OnShow(E);
  Check('Empty project shows Empty Inspector with no selection',
   (E.Session.SceneCount=0)and(E.Session.SelectedIndex=-1)and
   (E.crpSceneDetails.ActiveCard=E.crdEmpty)and not E.edtExplicitVolume.Enabled);
  Check('Empty selection causes no false Modified state',not E.Session.Modified and(State(E.Session)=Before));
  Check('Empty saved project cannot enter Readiness',not E.btnReadiness.Enabled);
 finally E.Free; end;
end;
procedure TestReadinessAndVolume(const Directory:string);
var E:TTestEditor; Before,Path,Err:string; D:TSceneAuthoringSnapshot;
 L:TSceneFileLoadResult; Bytes:TBytes; V:Integer;
begin
 Path:=TPath.Combine(Directory,'gate.json');
 E:=NewEditor('',1);
 try
  E.lblDemoTitle.Caption:=Path;
  Check('Displayed filename does not make an unsaved project eligible',
   not E.Session.HasSavedProject and not E.btnReadiness.Enabled);
  E.AcceptFile:=True; E.NextFile:=Path; E.btnSave.Click;
  Check('Successful Save As enables authoring eligibility for valid project',
   E.Session.HasSavedProject and not E.Session.Modified and E.btnReadiness.Enabled);
  Check('Saved authoring gate distinguishes a pending Inspector error',
   E.Session.CanEnterReadiness(False)and not E.Session.CanEnterReadiness(True));
  Bytes:=TFile.ReadAllBytes(Path); Before:=State(E.Session);
  for V in [-2,101] do begin
   E.edtExplicitVolume.Text:=IntToStr(V);
   Check('Invalid volume blocks Readiness without changing model '+IntToStr(V),
    E.lblExplicitVolumeError.Visible and not E.btnReadiness.Enabled and
    not E.Session.Modified and(State(E.Session)=Before));
  end;
  E.btnSave.Click;
  Check('Pending invalid input blocks Save without rewriting bytes',
   (E.ErrorCount=1)and(E.PickerCount=1)and BytesEqual(Bytes,TFile.ReadAllBytes(Path))and(State(E.Session)=Before));
  E.edtExplicitVolume.Text:='-1';
  Check('No Override keeps placeholder zero out of model',
   (E.Session.GetScene(0).ExplicitVolumePercent=-1)and(E.trkExplicitVolume.Position=0)and E.btnReadiness.Enabled);
  E.edtExplicitVolume.Text:='0';
  Check('Explicit zero is distinct and makes saved project dirty',
   (E.Session.GetScene(0).ExplicitVolumePercent=0)and E.Session.Modified and not E.btnReadiness.Enabled);
  E.btnSave.Click;
  Check('Ordinary Save refreshes readiness eligibility',E.btnReadiness.Enabled and not E.Session.Modified);
  E.trkExplicitVolume.Position:=100; E.trkExplicitVolume.OnChange(E.trkExplicitVolume);
  Check('TrackBar synchronizes Edit/model and closes dirty eligibility gate',
   (E.edtExplicitVolume.Text='100')and(E.Session.GetScene(0).ExplicitVolumePercent=100)and not E.btnReadiness.Enabled);
  E.btnSave.Click; E.AddScene(skBrowser); E.btnSave.Click;
  Check('Saved incomplete authoring draft remains ineligible',
   E.Session.HasSavedProject and not E.Session.Modified and not E.btnReadiness.Enabled and
   (Length(ValidateSceneList(E.Session.GetDocument))>0));
  E.btnRemoveScene.Click; E.btnSave.Click;
  Check('Removing incomplete draft and saving restores eligibility',E.btnReadiness.Enabled);
  D:=E.Session.GetDocument; D.Scenes[0].ExplicitVolumePercent:=50;
  Path:=TPath.Combine(Directory,'adopted.json');
  Check('Adoption fixture persisted',SaveSceneProject(Path,D).Success);
  L:=E.Session.OpenProject(Path);
  Check('Unbound loaded document cannot enter readiness',L.Success and not E.Session.CanEnterReadiness(False));
  Check('Explicit binding succeeds for saved fixture',E.Session.BindPresentation(Candidate(1),False,Err));
  E.RefreshEditor;
  Check('Project adoption refresh selects first and recomputes eligibility',
   (E.Session.SelectedIndex=0)and(E.edtExplicitVolume.Text='50')and E.btnReadiness.Enabled);
  E.edtExplicitVolume.Text:='bad'; E.SelectScene(0);
  Check('Selection refresh discards invalid text without a model write',
   (E.edtExplicitVolume.Text='50')and not E.Session.Modified and E.btnReadiness.Enabled);
  E.Session.CloseProject; E.RefreshEditor;
  Check('Closed context disables authoring actions/gate',not E.Session.HasActiveContext and
   not E.Session.HasSavedProject and not E.btnReadiness.Enabled and(E.Session.SelectedIndex=-1));
 finally E.Free; end;
end;
procedure TestCloseTransitions(const Directory:string);
var E:TTestEditor; Path,Before,Worked,Recent:string;
 Bytes:TBytes; H:THandle; Closed:Boolean;
begin
 Path:=TPath.Combine(Directory,'clean-close.json');
 E:=NewEditor(Path,1);
 try
  Bytes:=TFile.ReadAllBytes(Path);
  Check('Clean X closes without a confirmation or hidden context',CloseByX(E)and
   (E.PromptCount=0)and(E.WelcomeCount=1)and not ActiveProjectSession.HasActiveContext);
  Check('Clean close preserves saved bytes',BytesEqual(Bytes,TFile.ReadAllBytes(Path)));
 finally E.Free; end;
 Path:=TPath.Combine(Directory,'cancel-close.json');
 E:=NewEditor(Path,1);
 try
  E.edtExplicitVolume.Text:='50'; E.Choice:=ecCancel; E.ReenterClose:=True;
  Before:=State(E.Session); Bytes:=TFile.ReadAllBytes(Path);
  Check('Modified + Cancel stays in Editor with draft/context intact',not CloseByX(E)and
   (E.PromptCount=1)and(E.WelcomeCount=0)and E.Session.HasActiveContext and
   E.Session.Modified and(State(E.Session)=Before));
  Check('Reentrant close cannot produce duplicate prompts',E.NestedCloseBlocked and(E.PromptCount=1));
  Check('Prompt occurs before resetting active session',E.ActiveAtPrompt);
  Check('Cancel never modifies saved bytes',BytesEqual(Bytes,TFile.ReadAllBytes(Path)));
 finally E.Free; end;
 Path:=TPath.Combine(Directory,'discard-close.json');
 E:=NewEditor(Path,1);
 try
  Bytes:=TFile.ReadAllBytes(Path); E.edtExplicitVolume.Text:='50'; E.Choice:=ecDiscard;
  Check('Modified + Don''t Save closes once and clears context',CloseByX(E)and
   (E.PromptCount=1)and(E.WelcomeCount=1)and not E.Session.HasActiveContext and(E.Session.SceneCount=0));
  Check('Don''t Save preserves persisted bytes',BytesEqual(Bytes,TFile.ReadAllBytes(Path)));
 finally E.Free; end;
 Path:=TPath.Combine(Directory,'save-close.json');
 E:=NewEditor(Path,1);
 try
  E.edtExplicitVolume.Text:='50'; E.Choice:=ecSave;
  Check('Modified + Save persists then closes without a second prompt',CloseByX(E)and
   (E.PromptCount=1)and(E.PickerCount=0)and(E.WelcomeCount=1)and not E.Session.HasActiveContext);
  Check('Saved close writes edited volume',LoadSceneProject(Path).DocumentResult.Document.Scenes[0].ExplicitVolumePercent=50);
  Recent:=RecentProjectPath(Worked);
  Check('Close keeps successful recent-project entry for Welcome Reopen',SameText(Recent,Path));
 finally E.Free; end;
 Path:=TPath.Combine(Directory,'failed-close.json');
 E:=NewEditor(Path,1);
 try
  E.edtExplicitVolume.Text:='100'; E.Choice:=ecSave;
  Before:=State(E.Session); Bytes:=TFile.ReadAllBytes(Path);
  H:=CreateFile(PWideChar(Path),GENERIC_READ,FILE_SHARE_READ or FILE_SHARE_WRITE,
    nil,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0);
  if H=INVALID_HANDLE_VALUE then RaiseLastOSError;
  try Closed:=CloseByX(E); finally CloseHandle(H); end;
  Check('Save I/O failure stays in Editor and preserves draft/context',not Closed and
   (E.PromptCount=1)and(E.ErrorCount=1)and(E.WelcomeCount=0)and E.Session.HasActiveContext and
   E.Session.Modified and(State(E.Session)=Before));
  Check('Save failure preserves bytes and cleans temporary output',
   BytesEqual(Bytes,TFile.ReadAllBytes(Path))and(Length(TDirectory.GetFiles(Directory,'*.tmp'))=0));
 finally E.Free; end;
 E:=NewEditor('',1);
 try
  E.Choice:=ecSave; E.AcceptFile:=False; Before:=State(E.Session);
  Check('Save As cancellation blocks close and preserves unsaved context',not CloseByX(E)and
   (E.PromptCount=1)and(E.PickerCount=1)and(E.ErrorCount=0)and(E.WelcomeCount=0)and
   E.Session.HasActiveContext and E.Session.Modified and(State(E.Session)=Before));
  E.AcceptFile:=True; E.NextFile:=TPath.Combine(Directory,'new-close.json');
  Check('New project Save As success permits close',CloseByX(E)and
   (E.PromptCount=2)and(E.PickerCount=2)and(E.WelcomeCount=1)and not E.Session.HasActiveContext);
 finally E.Free; end;
 E:=NewEditor(TPath.Combine(Directory,'invalid-close.json'),1);
 try
  E.edtExplicitVolume.Text:='101'; E.Choice:=ecSave;
  Before:=State(E.Session);
  Check('Invalid pending input is not silently discarded by close Save',not CloseByX(E)and
   (E.PromptCount=1)and(E.ErrorCount=1)and(E.PickerCount=0)and
   E.Session.HasActiveContext and(State(E.Session)=Before)and(E.edtExplicitVolume.Text='101'));
  E.Choice:=ecDiscard;
  Check('Explicit discard can close a pending invalid edit',CloseByX(E)and not E.Session.HasActiveContext);
 finally E.Free; end;
end;
procedure TestLegacyCloseSafeguards(const Directory:string);
var E:TTestEditor; D:TSceneAuthoringSnapshot; L:TSceneFileLoadResult;
 Source,Target,Text,Err,Before:string; Original:TBytes;
begin
 E:=NewEditor('',1);
 try
  D:=E.Session.GetDocument; Text:=SerializeSceneDocument(D);
  Text:=StringReplace(Text,'"projectFormatVersion":3','"projectFormatVersion":1',[]);
  Text:=StringReplace(Text,'"powerPointFileName":"Deck.pptx",','',[]);
  Text:=StringReplace(Text,'"powerPointSlideCount":1,','',[]);
  Text:=StringReplace(Text,'"presentationBaseVolumePercent":50,','',[]);
  Source:=TPath.Combine(Directory,'legacy-close-v1.json');
  Target:=TPath.Combine(Directory,'legacy-close-v3.json');
  TFile.WriteAllText(Source,Text,TEncoding.UTF8); Original:=TFile.ReadAllBytes(Source);
  L:=E.Session.OpenProject(Source);
  Check('Legacy close fixture opens v1',L.Success and(E.Session.SourceFormatVersion=1));
  Check('Legacy binding remains explicit',E.Session.BindPresentation(Candidate(1),True,Err));
  E.RefreshEditor;
  Check('Unpersisted legacy binding cannot enter readiness',not E.Session.HasSavedProject and not E.btnReadiness.Enabled);
  E.edtExplicitVolume.Text:='50'; Before:=State(E.Session);
  E.Choice:=ecSave; E.AcceptFile:=False;
  Check('Legacy close Save As cancellation preserves source/context/draft',not CloseByX(E)and
   (E.Session.SourceFormatVersion=1)and(State(E.Session)=Before)and E.Session.HasActiveContext and
   BytesEqual(Original,TFile.ReadAllBytes(Source)));
  E.AcceptFile:=True; E.NextFile:=TPath.Combine(Directory,'.\legacy-close-v1.json');
  Check('Legacy close rejects original normalized path',not CloseByX(E)and
   (E.ErrorCount=1)and E.Session.HasActiveContext and(State(E.Session)=Before)and
   BytesEqual(Original,TFile.ReadAllBytes(Source)));
  E.NextFile:=Target;
  Check('Legacy close only succeeds after explicit Save As v3',CloseByX(E)and
   (E.WelcomeCount=1)and not E.Session.HasActiveContext and BytesEqual(Original,TFile.ReadAllBytes(Source)));
  L:=LoadSceneProject(Target);
  Check('Legacy close Save As retains edited draft and v3 context in file',L.Success and
   (L.DocumentResult.SourceFormatVersion=3)and(SerializeSceneDocument(L.DocumentResult.Document)=Before));
 finally E.Free; end;
end;
var Directory:string;
begin
 Application.Initialize;
 Directory:=TPath.Combine(TPath.GetTempPath,'pa-editor-ux-'+TGUID.NewGuid.ToString);
 TDirectory.CreateDirectory(Directory);
 try
  try
   TestSelectionAndFormatting(Directory);
   TestReadinessAndVolume(Directory);
   TestCloseTransitions(Directory);
   TestLegacyCloseSafeguards(Directory);
  except on E:Exception do Check(E.ClassName+': '+E.Message,False); end;
 finally
  ActiveProjectSession.NewProject;
  TDirectory.Delete(Directory,True);
 end;
 Writeln('Tests run: ',N); Writeln('Failures: ',F);
 if F<>0 then ExitCode:=1;
end.

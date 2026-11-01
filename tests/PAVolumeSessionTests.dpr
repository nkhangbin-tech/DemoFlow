program PAVolumeSessionTests;
{$APPTYPE CONSOLE}
uses
 System.SysUtils, System.IOUtils, Winapi.Windows,
 PADomainTypes in '..\Domain\PADomainTypes.pas',
 PASceneDomain in '..\Domain\PASceneDomain.pas',
 PASceneDocumentCodec in '..\Persistence\PASceneDocumentCodec.pas',
 PASceneProjectFileStore in '..\Persistence\PASceneProjectFileStore.pas',
 PAPresentationDiscovery in '..\PowerPoint\PAPresentationDiscovery.pas',
 PASceneProjectSession in '..\Authoring\PASceneProjectSession.pas';
var TestCount, FailureCount: Integer;
procedure Check(const Name: string; Condition: Boolean);
begin
 Inc(TestCount);
 if Condition then Writeln('PASS ',Name)
 else begin Inc(FailureCount); Writeln('FAIL ',Name); end;
end;
function State(S: TSceneProjectSession): string;
begin Result := SerializeSceneDocument(S.GetDocument); end;
function BytesEqual(const A,B:TBytes):Boolean;
var I:Integer;
begin
 if Length(A)<>Length(B) then Exit(False);
 for I:=0 to High(A) do if A[I]<>B[I] then Exit(False);
 Result:=True;
end;
procedure TestSettingsAndScenes;
const Bases:array[0..2]of Integer=(0,50,100);
 BadBases:array[0..1]of Integer=(-1,101);
 Invalid:array[0..7]of string=('', '-2','101','1.5','abc','$50','+1','9999999999999999999');
var S:TSceneProjectSession; B,V,I:Integer; Raised:Boolean;
 A,BId,C,Inserted,Before,Text:string; D:TSceneAuthoringSnapshot;
 Kind:TSceneKind;
begin
 S:=TSceneProjectSession.Create;
 try
  Check('New session project default base 50',S.PresentationBaseVolumePercent=50);
  Check('New session has no active source or selection', (S.ActivePath='')and
   (S.SourceFormatVersion=0)and(S.SelectedIndex=-1)and not S.Modified);
  Check('New session Save requires explicit target',S.Save.Status=psSaveAsRequired);
  for B in Bases do begin S.PresentationBaseVolumePercent:=B;
   Check('Settings backend accepts '+IntToStr(B),S.PresentationBaseVolumePercent=B); end;
  Before:=State(S);
  for B in BadBases do begin
   Raised:=False;
   try S.PresentationBaseVolumePercent:=B;
   except on E:EArgumentOutOfRangeException do Raised:=True; end;
   Check('Settings backend rejects '+IntToStr(B),Raised and(State(S)=Before));
  end;
  S.NewProject;
  for Kind in [skPowerPoint,skBrowser,skExternalApp] do begin
   I:=S.AddScene(Kind);
   Check('New Scene kind defaults to no override '+SceneKindName(Kind),
    (S.GetScene(I).ExplicitVolumePercent=-1)and(S.GetScene(I).PowerPointLogicalSlide=0)and
    (S.GetScene(I).BrowserTargetReference='')and(S.GetScene(I).ExternalAppTargetReference=''));
  end;
  A:=S.GetScene(0).SceneId; BId:=S.GetScene(1).SceneId; C:=S.GetScene(2).SceneId;
  Check('SceneIds are nonempty and distinct', (A<>'')and(A<>BId)and(A<>C)and(BId<>C));
  S.SelectScene(0); S.AddScene(skBrowser); Inserted:=S.GetScene(1).SceneId;
  Check('Pinned Add inserts immediately after selected Scene',
   (S.SceneCount=4)and(S.SelectedIndex=1)and(S.GetScene(0).SceneId=A)and
   (S.GetScene(2).SceneId=BId)and(S.GetScene(3).SceneId=C));
  S.MoveSelected(1);
  Check('Move follows logical array order and stable SceneId',
   (S.SelectedIndex=2)and(S.GetScene(2).SceneId=Inserted)and(S.GetScene(1).SceneId=BId));
  S.RemoveSelected;
  Check('Remove preserves remaining order', (S.SceneCount=3)and
   (S.GetScene(0).SceneId=A)and(S.GetScene(1).SceneId=BId)and(S.GetScene(2).SceneId=C));
  Before:=State(S);
  S.SelectScene(0); S.MoveSelected(-1);
  Check('Move beyond first boundary does not mutate data',State(S)=Before);
  Check('Reject invalid volume and index',not S.TrySetSceneVolume(0,-2)and
   not S.TrySetSceneVolume(0,101)and not S.TrySetSceneVolume(-1,50)and
   not S.TrySetSceneVolume(3,50)and(State(S)=Before));
  D:=S.GetDocument; D.Scenes[0].ExplicitVolumePercent:=77;
  Check('Returned authoring snapshot is detached',S.GetScene(0).ExplicitVolumePercent=-1);
  Raised:=False;
  try S.SelectScene(99); except on E:ERangeError do Raised:=True; end;
  Check('Invalid selection preserves selected Scene',Raised and(S.SelectedIndex=0));
  S.NewProject; S.AddScene(skPowerPoint);
  Check('Empty-list Add explicitly inserts at zero',(S.SelectedIndex=0)and(S.SceneCount=1));
  S.RemoveSelected;
  Check('Remove last Scene clears selection',(S.SelectedIndex=-1)and(S.SceneCount=0));
  for Text in Invalid do
   Check('Invalid volume text rejected: '+Text,not TryParseSceneVolumeText(Text,V));
  Check('No Override text is -1, not zero',TryParseSceneVolumeText('-1',V)and(V=-1));
  Check('Explicit zero text remains zero',TryParseSceneVolumeText('0',V)and(V=0));
  Check('Explicit hundred text remains hundred',TryParseSceneVolumeText('100',V)and(V=100));
 finally S.Free; end;
end;
procedure TestDocumentWorkflow(const Directory:string);
var S:TSceneProjectSession; D,Expected:TSceneAuthoringSnapshot;
 Source,Target,Before,ActivePath:string; Original,TargetBefore:TBytes;
 P:TPresentationCandidate; Err:string;
 Loaded:TSceneFileLoadResult; R:TProjectSaveResult; H:THandle; I:Integer;
begin
 Source:=TPath.Combine(Directory,'original-v1.json');
 Target:=TPath.Combine(Directory,'saved-v2.json');
 D:=NewSceneProject; D.AuthoringRevision:='keep-this-revision';
 SetLength(D.Scenes,3);
 for I:=0 to 2 do begin
  D.Scenes[I].SceneId:='stable-'+IntToStr(I);
  D.Scenes[I].SceneKind:=TSceneKind(I+1);
  D.Scenes[I].ExplicitVolumePercent:=I*50;
 end;
 D.Scenes[1].BrowserTargetReference:='browser-reference';
 D.Scenes[2].ExternalAppTargetReference:='external-reference';
 Before:=StringReplace(SerializeSceneDocument(D),'"projectFormatVersion":2','"projectFormatVersion":1',[]);
 Before:=StringReplace(Before,'"presentationBaseVolumePercent":50,','',[]);
 TFile.WriteAllText(Source,Before,TEncoding.UTF8);
 Original:=TFile.ReadAllBytes(Source);
 S:=TSceneProjectSession.Create;
 try
  Loaded:=S.OpenProject(Source);
  Check('V1 Open retains base/version and never rewrites file',Loaded.Success and
   (S.PresentationBaseVolumePercent=50)and(S.SourceFormatVersion=1)and
   BytesEqual(Original,TFile.ReadAllBytes(Source)));
  P:=Default(TPresentationCandidate); P.WindowKey:=1; P.FileName:='confirmed.pptx';
  P.FullName:='C:\confirmed.pptx'; P.SlideCount:=3;
  Check('Legacy session binding requires confirmation',not S.BindPresentation(P,False,Err));
  Check('Legacy binding confirmed before Save As v3',S.BindPresentation(P,True,Err));
  Loaded.DocumentResult.Document.Scenes[0].SceneId:='changed-external-copy';
  Check('Open result cannot alias active document',S.GetScene(0).SceneId='stable-0');
  S.SelectScene(0); S.TrySetSceneVolume(0,-1); S.PresentationBaseVolumePercent:=100;
  Before:=State(S); ActivePath:=S.ActivePath;
  R:=S.Save;
  Check('Edited v1 first Save returns SaveAsRequired',R.Status=psSaveAsRequired);
  Check('Save gate preserves source and dirty active state',S.Modified and
   (State(S)=Before)and BytesEqual(Original,TFile.ReadAllBytes(Source)));
  R:=S.SaveAs('');
  Check('Cancel preserves all session context',(R.Status=psCancelled)and S.Modified and
   (S.ActivePath=ActivePath)and(S.SourceFormatVersion=1)and(S.SelectedIndex=0)and(State(S)=Before));
  R:=S.SaveAs(TPath.Combine(Directory,'.\original-v1.json'));
  Check('Save As rejects normalized original v1 path',(R.Status=psFailed)and
   (R.ErrorMessage<>'')and(State(S)=Before)and(S.SourceFormatVersion=1));
  R:=S.SaveAs(TPath.Combine(Directory,'missing\fail.json'));
  Check('Save As failure preserves path/version/state',(R.Status=psFailed)and
   (S.ActivePath=ActivePath)and(S.SourceFormatVersion=1)and S.Modified and(State(S)=Before));
  Loaded:=S.OpenProject(TPath.Combine(Directory,'absent.json'));
  Check('Failed Open preserves edits and context',not Loaded.Success and
   (State(S)=Before)and(S.ActivePath=ActivePath)and S.Modified);
  R:=S.SaveAs(Target);
  Check('Successful Save As adopts new v3 context',(R.Status=psSaved)and
   (S.ActivePath=TPath.GetFullPath(Target))and(S.SourceFormatVersion=3)and
   not S.Modified and(State(S)=Before));
  Check('Save As keeps original v1 bytes',BytesEqual(Original,TFile.ReadAllBytes(Source)));
  Loaded:=LoadSceneProject(Target);
  Check('V3 reopen preserves base and incomplete drafts',Loaded.Success and
   (Loaded.DocumentResult.SourceFormatVersion=3)and
   (SerializeSceneDocument(Loaded.DocumentResult.Document)=Before)and
   (Length(Loaded.DocumentResult.AuthoringDiagnostics)>0));
  S.TrySetSceneVolume(0,0); Before:=State(S); R:=S.Save;
  Check('Subsequent ordinary v3 Save retains active path',(R.Status=psSaved)and
   (S.ActivePath=TPath.GetFullPath(Target))and not S.Modified);
  Loaded:=S.OpenProject(Target);
  Check('V3 Open retains project base and Scene data',Loaded.Success and(State(S)=Before));
  S.SelectScene(1); Expected:=S.GetDocument;
  Expected.Scenes[0]:=S.GetScene(1); Expected.Scenes[1]:=S.GetScene(0);
  S.MoveSelected(-1);
  Check('Reordering preserves all Scene fields, base and revision',
   State(S)=SerializeSceneDocument(Expected));
  S.PresentationBaseVolumePercent:=0;
  Before:=State(S); TargetBefore:=TFile.ReadAllBytes(Target);
  H:=CreateFile(PWideChar(Target),GENERIC_READ,FILE_SHARE_READ or FILE_SHARE_WRITE,
   nil,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0);
  if H=INVALID_HANDLE_VALUE then RaiseLastOSError;
  try R:=S.Save; finally CloseHandle(H); end;
  Check('Locked v3 Save fails without losing edits/context',(R.Status=psFailed)and
   S.Modified and(State(S)=Before)and(S.SourceFormatVersion=3)and
   (S.ActivePath=TPath.GetFullPath(Target))and BytesEqual(TargetBefore,TFile.ReadAllBytes(Target)));
  Check('Failed save cleans temporary files',Length(TDirectory.GetFiles(Directory,'*.tmp'))=0);
  // Load original again and exercise Save As replacement I/O failure specifically.
  Loaded:=S.OpenProject(Source); S.BindPresentation(P,True,Err); S.SelectScene(0); S.TrySetSceneVolume(0,-1);
  Before:=State(S); ActivePath:=S.ActivePath;
  H:=CreateFile(PWideChar(Target),GENERIC_READ,FILE_SHARE_READ or FILE_SHARE_WRITE,
   nil,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0);
  if H=INVALID_HANDLE_VALUE then RaiseLastOSError;
  try R:=S.SaveAs(Target); finally CloseHandle(H); end;
  Check('V1 Save As I/O failure preserves source, target and session',
   (R.Status=psFailed)and S.Modified and(State(S)=Before)and
   (S.ActivePath=ActivePath)and(S.SourceFormatVersion=1)and
   BytesEqual(Original,TFile.ReadAllBytes(Source))and
   BytesEqual(TargetBefore,TFile.ReadAllBytes(Target)));
  Check('Save As I/O failure leaves no temporary files',Length(TDirectory.GetFiles(Directory,'*.tmp'))=0);
 finally S.Free; end;
end;
var Directory:string;
begin
 Directory:=TPath.Combine(TPath.GetTempPath,'pa-vol-m02-session-'+TGUID.NewGuid.ToString);
 TDirectory.CreateDirectory(Directory);
 try TestSettingsAndScenes; TestDocumentWorkflow(Directory);
 finally TDirectory.Delete(Directory,True); end;
 Writeln('Tests run: ',TestCount); Writeln('Failures: ',FailureCount);
 if FailureCount<>0 then ExitCode:=1;
end.
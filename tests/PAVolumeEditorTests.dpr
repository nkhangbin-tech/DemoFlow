program PAVolumeEditorTests;
{$APPTYPE CONSOLE}
uses
 System.SysUtils, System.IOUtils, Vcl.Forms, Vcl.Controls,
 PADomainTypes in '..\Domain\PADomainTypes.pas',
 PASceneDomain in '..\Domain\PASceneDomain.pas',
 PASceneDocumentCodec in '..\Persistence\PASceneDocumentCodec.pas',
 PASceneProjectFileStore in '..\Persistence\PASceneProjectFileStore.pas',
 PAPresentationDiscovery in '..\PowerPoint\PAPresentationDiscovery.pas',
 PASceneProjectSession in '..\Authoring\PASceneProjectSession.pas',
 uSceneEditorForm in '..\uSceneEditorForm.pas';
var TestCount,FailureCount:Integer;
procedure Check(const Name:string; Condition:Boolean);
begin
 Inc(TestCount);
 if Condition then Writeln('PASS ',Name)
 else begin Inc(FailureCount); Writeln('FAIL ',Name); end;
end;
procedure TestForm(const Directory:string);
var F:TfrmSceneEditor; A,B,C,Target,Before:string;
 P:TPresentationCandidate; Pending:TSceneProjectSession; ErrorText:string; Loaded:TSceneFileLoadResult;
 D,Expected:TSceneAuthoringSnapshot; R:TSceneFileOperationResult;
begin
 F:=TfrmSceneEditor.Create(nil);
 try
  Check('Actual PO DFM streams into VCL form',Assigned(F.vstScenes)and Assigned(F.crpSceneDetails));
  Check('Empty editor disables volume controls',not F.edtExplicitVolume.Enabled and
   not F.trkExplicitVolume.Enabled and(F.Session.SelectedIndex=-1));
  Check('Pinned Add remains bottom-aligned in left list',
   (F.pnlSceneActions.Parent=F.pnlSceneList)and(F.pnlSceneActions.Align=alBottom)and(F.btnAddNewScene.Parent=F.pnlSceneActions));
  Check('Manual PowerPoint insertion is unavailable',not F.miPowerPoint.Visible and not F.miPowerPoint.Enabled);
  P:=Default(TPresentationCandidate); P.WindowKey:=1; P.FileName:='test.pptx';
  P.FullName:='C:\test.pptx'; P.SlideCount:=1;
  F.Session.PrepareNew(P); F.SelectScene(0);
  A:=F.Session.GetScene(0).SceneId;
  Check('Presentation creates selected -1 Scene',(F.Session.SceneCount=1)and
   (F.Session.SelectedIndex=0)and(F.edtExplicitVolume.Text='-1')and
   (F.Session.GetScene(0).ExplicitVolumePercent=-1));
  Check('No Override has explicit display and bounded TrackBar',
   (F.sbSceneEditor.SimpleText='No Volume Override')and(F.trkExplicitVolume.Min=0)and
   (F.trkExplicitVolume.Max=100)and(F.trkExplicitVolume.Position=0));
  F.edtExplicitVolume.Text:='50';
  Check('Edit synchronizes model and TrackBar',
   (F.Session.GetScene(0).ExplicitVolumePercent=50)and(F.trkExplicitVolume.Position=50));
  F.trkExplicitVolume.Position:=100;
  // VCL property assignment does not necessarily send the user scroll notification.
  F.trkExplicitVolume.OnChange(F.trkExplicitVolume);
  Check('TrackBar user change synchronizes Edit and model',
   (F.edtExplicitVolume.Text='100')and(F.Session.GetScene(0).ExplicitVolumePercent=100));
  F.edtExplicitVolume.Text:='-1';
  Check('Switch back to No Override never writes placeholder zero',
   (F.Session.GetScene(0).ExplicitVolumePercent=-1)and(F.trkExplicitVolume.Position=0));
  F.edtExplicitVolume.Text:='101';
  Check('Invalid volume stays visible without corrupting model',
   F.lblExplicitVolumeError.Visible and(F.edtExplicitVolume.Text='101')and
   (F.Session.GetScene(0).ExplicitVolumePercent=-1));
  F.miBrowser.Click; B:=F.Session.GetScene(1).SceneId;
  Check('Browser menu defaults to -1 too',F.Session.GetScene(1).ExplicitVolumePercent=-1);
  F.edtExplicitVolume.Text:='0';
  F.miExternalApp.Click; C:=F.Session.GetScene(2).SceneId;
  Check('ExternalApp menu defaults to -1 too',F.Session.GetScene(2).ExplicitVolumePercent=-1);
  F.edtExplicitVolume.Text:='100';
  F.SelectScene(0);
  Check('Selecting no-override Scene keeps all other Scene values',
   (F.Session.GetScene(0).ExplicitVolumePercent=-1)and
   (F.Session.GetScene(1).ExplicitVolumePercent=0)and
   (F.Session.GetScene(2).ExplicitVolumePercent=100)and(F.edtExplicitVolume.Text='-1'));
  F.vstScenes.FocusedNode:=F.vstScenes.GetLast;
  Check('Actual tree focus updates inspector safely',
   (F.Session.SelectedIndex=2)and(F.edtExplicitVolume.Text='100')and
   (F.crpSceneDetails.ActiveCard=F.crdExternalApp)and
   (F.Session.GetScene(0).ExplicitVolumePercent=-1));
  F.edtExplicitVolume.Text:='bad';
  F.SelectScene(1);
  Check('Switching from invalid text never commits to next Scene',
   (F.edtExplicitVolume.Text='0')and(F.Session.GetScene(1).ExplicitVolumePercent=0)and
   (F.Session.GetScene(2).ExplicitVolumePercent=100)and not F.lblExplicitVolumeError.Visible);
  F.SelectScene(0); F.miBrowser.Click;
  Check('Menu insertion is immediately after selection with stable ids',
   (F.Session.SceneCount=4)and(F.Session.SelectedIndex=1)and
   (F.Session.GetScene(0).SceneId=A)and(F.Session.GetScene(2).SceneId=B)and
   (F.Session.GetScene(3).SceneId=C));
  F.btnMoveDown.Click;
  Check('Existing Move Down changes array order',
   (F.Session.SelectedIndex=2)and(F.Session.GetScene(1).SceneId=B));
  F.btnRemoveScene.Click;
  Check('Existing Remove preserves other Scene values',
   (F.Session.SceneCount=3)and(F.Session.GetScene(0).SceneId=A)and
   (F.Session.GetScene(1).SceneId=B)and(F.Session.GetScene(2).SceneId=C));
  // Load rich existing fields; volume selection/reorder must preserve all of them.
  D:=F.Session.GetDocument;
  D.AuthoringRevision:='unchanged';
  D.Scenes[0].PowerPointLogicalSlide:=7;
  D.Scenes[1].BrowserTargetReference:='existing-browser';
  D.Scenes[2].ExternalAppTargetReference:='existing-external';
  Target:=TPath.Combine(Directory,'rich-v2.json');
  R:=SaveSceneProject(Target,D);
  Check('Test fixture v2 saves',R.Success);
  Pending:=TSceneProjectSession.Create;
  try
   Loaded:=Pending.OpenProject(Target);
   Check('Editor direct Open cannot bypass relinking',not F.OpenProject(Target).Success);
   Check('Candidate loads and binds for editor',Loaded.Success and Pending.BindPresentation(P,False,ErrorText));
   F.Session.AdoptCandidate(Pending); F.RefreshEditor;
  finally Pending.Free; end;
  F.SelectScene(0);
  Check('PowerPoint selection maps to existing card and slide',
   (F.crpSceneDetails.ActiveCard=F.crdPowerPoint)and(F.edtPowerPointLogicalSlide.Text='7'));
  F.SelectScene(1);
  Check('Browser selection maps reference to existing inspector',
   (F.crpSceneDetails.ActiveCard=F.crdBrowser)and(F.cmbBrowserTarget.Text='existing-browser'));
  Before:=SerializeSceneDocument(F.Session.GetDocument);
  F.SelectScene(2); F.SelectScene(0);
  Check('Selecting and repopulating inspector leaves all fields unchanged',
   SerializeSceneDocument(F.Session.GetDocument)=Before);
  F.edtExplicitVolume.Text:='50'; D.Scenes[0].ExplicitVolumePercent:=50;
  Check('Volume edit only changes supported volume field',
   SerializeSceneDocument(F.Session.GetDocument)=SerializeSceneDocument(D));
  Expected:=D; Expected.Scenes:=Copy(D.Scenes);
  Expected.Scenes[0]:=D.Scenes[1]; Expected.Scenes[1]:=D.Scenes[0];
  F.btnMoveDown.Click;
  Check('UI reorder preserves all six fields and authoring revision',
   SerializeSceneDocument(F.Session.GetDocument)=SerializeSceneDocument(Expected));
 finally F.Free; end;
end;
var Directory:string;
begin
 Application.Initialize;
 Directory:=TPath.Combine(TPath.GetTempPath,'pa-vol-m02-editor-'+TGUID.NewGuid.ToString);
 TDirectory.CreateDirectory(Directory);
 try
  try TestForm(Directory);
  except on E:Exception do Check('Editor exception: '+E.ClassName+': '+E.Message,False); end;
 finally TDirectory.Delete(Directory,True); end;
 Writeln('Tests run: ',TestCount); Writeln('Failures: ',FailureCount);
 if FailureCount<>0 then ExitCode:=1;
end.
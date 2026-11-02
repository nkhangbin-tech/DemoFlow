program PAVolumeDisplayTests;
{$APPTYPE CONSOLE}
uses
 System.SysUtils, Vcl.Forms, VirtualTrees.Types,
 PASceneDomain, PASceneDocumentCodec, PASceneProjectSession,
 PAPresentationDiscovery, uSceneEditorForm;
var N,F:Integer; Editor:TfrmSceneEditor;
procedure Check(const Name:string; OK:Boolean);
begin
 Inc(N);
 if OK then Writeln('PASS ',Name) else begin Inc(F); Writeln('FAIL ',Name); end;
end;
procedure CheckDisplay(const Name:string; Volume:Integer; const Status:string);
var Cell:string;
begin
 Check(Name+' has neutral static label',Editor.lblExplicitVolume.Caption='Explicit Volume (%)');
 Check(Name+' dynamic status matches model',Editor.sbSceneEditor.SimpleText=Status);
 Check(Name+' committed value',Editor.Session.GetScene(Editor.Session.SelectedIndex).ExplicitVolumePercent=Volume);
 Editor.vstScenes.OnGetText(Editor.vstScenes,Editor.vstScenes.FocusedNode,1,ttNormal,Cell);
 if Volume=-1 then Check(Name+' row volume remains em dash',Cell=#$2014)
 else Check(Name+' row volume remains percentage',Cell=IntToStr(Volume)+'%');
end;
procedure Run;
var P:TPresentationCandidate; Before,OtherId,Err:string; Count:Integer;
begin
 ActiveProjectSession.NewProject;
 P:=Default(TPresentationCandidate); P.WindowKey:=1;
 P.FileName:='Display.pptx'; P.FullName:='C:\Display.pptx'; P.SlideCount:=2;
 ActiveProjectSession.PrepareNew(P);
 Editor:=TfrmSceneEditor.Create(nil);
 try
  Count:=Editor.vstScenes.Header.Columns.Count;
  CheckDisplay('Initial selection',-1,'No Volume Override');
  Editor.edtExplicitVolume.Text:='50';
  Writeln('Observed label: ',Editor.lblExplicitVolume.Caption);
  Writeln('Observed dynamic status: ',Editor.sbSceneEditor.SimpleText);
  CheckDisplay('Edit 50',50,'Absolute master-volume target: 50% (authoring only)');
  Check('No stale No Override claim in other status controls',
   (Pos('No Volume Override',Editor.lblModifiedStatus.Caption)=0)and
   (Pos('No Volume Override',Editor.lblDemoTitle.Caption)=0));
  Editor.edtExplicitVolume.Text:='0';
  CheckDisplay('Edit zero',0,'Absolute master-volume target: 0% (authoring only)');
  Editor.trkExplicitVolume.Position:=100;
  Editor.trkExplicitVolume.OnChange(Editor.trkExplicitVolume);
  CheckDisplay('TrackBar hundred',100,'Absolute master-volume target: 100% (authoring only)');
  Editor.edtExplicitVolume.Text:='-1';
  CheckDisplay('Edit no override',-1,'No Volume Override');
  Check('No Override placeholder does not commit zero',Editor.trkExplicitVolume.Position=0);
  Editor.SelectScene(1); Editor.edtExplicitVolume.Text:='50';
  OtherId:=Editor.Session.GetScene(1).SceneId;
  Editor.SelectScene(0);
  CheckDisplay('Return to no-override Scene',-1,'No Volume Override');
  Editor.vstScenes.FocusedNode:=Editor.vstScenes.GetLast;
  CheckDisplay('Tree selection returns to explicit Scene',50,
   'Absolute master-volume target: 50% (authoring only)');
  Before:=SerializeSceneDocument(Editor.Session.GetDocument);
  Editor.edtExplicitVolume.Text:='101'; Err:=Editor.lblExplicitVolumeError.Caption;
  Check('Invalid pending input stays visible and preserves validation feedback',
   Editor.lblExplicitVolumeError.Visible and(Err<>'')and(Editor.edtExplicitVolume.Text='101'));
  Check('Invalid pending value is not committed or advertised as a target',
   (SerializeSceneDocument(Editor.Session.GetDocument)=Before)and
   (Editor.sbSceneEditor.SimpleText='Absolute master-volume target: 50% (authoring only)')and
   not Editor.btnReadiness.Enabled);
  Editor.edtExplicitVolume.Text:='';
  Check('Empty pending edit retains current model status and error',
   Editor.lblExplicitVolumeError.Visible and(Editor.edtExplicitVolume.Text='')and
   (Editor.sbSceneEditor.SimpleText='Absolute master-volume target: 50% (authoring only)')and
   (SerializeSceneDocument(Editor.Session.GetDocument)=Before));
  Editor.RefreshEditor;
  CheckDisplay('Refresh after invalid text',50,'Absolute master-volume target: 50% (authoring only)');
  Check('Explicit refresh reloads committed value without a model write',
   (Editor.edtExplicitVolume.Text='50')and not Editor.lblExplicitVolumeError.Visible and
   (SerializeSceneDocument(Editor.Session.GetDocument)=Before));
  Editor.Session.TrySetSceneVolume(1,0); Editor.RefreshEditor;
  CheckDisplay('Refresh from current model',0,'Absolute master-volume target: 0% (authoring only)');
  Editor.edtExplicitVolume.Text:='-2';
  Check('Invalid -2 retains explicit zero status and error',
   Editor.lblExplicitVolumeError.Visible and(Editor.Session.GetScene(1).ExplicitVolumePercent=0)and
   (Editor.sbSceneEditor.SimpleText='Absolute master-volume target: 0% (authoring only)'));
  Editor.SelectScene(0);
  CheckDisplay('Selection after invalid input',-1,'No Volume Override');
  Check('Other Scene identity and volume survive selection/status updates',
   (Editor.Session.GetScene(1).SceneId=OtherId)and(Editor.Session.GetScene(1).ExplicitVolumePercent=0));
  Check('PO column configuration is not changed',Editor.vstScenes.Header.Columns.Count=Count);
  Editor.Session.CloseProject; Editor.RefreshEditor;
  Check('Empty Editor has neutral label and no stale selected-volume status',
   (Editor.lblExplicitVolume.Caption='Explicit Volume (%)')and
   (Editor.sbSceneEditor.SimpleText='No Scene selected'));
 finally Editor.Free; end;
end;
begin
 Application.Initialize;
 try Run; except on E:Exception do Check(E.ClassName+': '+E.Message,False); end;
 ActiveProjectSession.NewProject;
 Writeln('Tests run: ',N); Writeln('Failures: ',F);
 if F<>0 then ExitCode:=1;
end.

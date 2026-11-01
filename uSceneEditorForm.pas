unit uSceneEditorForm;

interface

uses
 System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls,
 Vcl.ComCtrls, Vcl.Menus, Vcl.WinXPanels, VirtualTrees,
 VirtualTrees.BaseTree, VirtualTrees.Types, PASceneDomain,
 PASceneProjectFileStore, PASceneProjectSession;

type
 TfrmSceneEditor = class(TForm)
  btnBackToWelcome: TButton;
  btnSave: TButton;
  btnReadiness: TButton;
  btnStartLive: TButton;
  lblDemoTitle: TLabel;
  lblModifiedStatus: TLabel;
  pnlHeader: TPanel;
  btnAddNewScene: TButton;
  btnRemoveScene: TButton;
  btnMoveUp: TButton;
  btnMoveDown: TButton;
  pnlSceneActions: TPanel;
  vstScenes: TVirtualStringTree;
  pnlSceneList: TPanel;
  lblEmpty: TLabel;
  crdEmpty: TCard;
  lblPowerPointTarget: TLabel;
  cmbPowerPointTarget: TComboBox;
  lblPowerPointTargetError: TLabel;
  lblPowerPointLogicalSlide: TLabel;
  edtPowerPointLogicalSlide: TEdit;
  lblPowerPointLogicalSlideError: TLabel;
  crdPowerPoint: TCard;
  lblBrowserTarget: TLabel;
  cmbBrowserTarget: TComboBox;
  lblBrowserTargetError: TLabel;
  crdBrowser: TCard;
  lblExternalAppTarget: TLabel;
  cmbExternalAppTarget: TComboBox;
  lblExternalAppTargetError: TLabel;
  crdExternalApp: TCard;
  crpSceneDetails: TCardPanel;
  lblCommonProperties: TLabel;
  lblExplicitVolume: TLabel;
  trkExplicitVolume: TTrackBar;
  edtExplicitVolume: TEdit;
  lblExplicitVolumeError: TLabel;
  pnlCommonProperties: TPanel;
  lblSceneDetails: TLabel;
  lblSceneId: TLabel;
  lblSceneKind: TLabel;
  pnlSceneIdentity: TPanel;
  pnlInspector: TPanel;
  splSceneInspector: TSplitter;
  pnlBody: TPanel;
  sbSceneEditor: TStatusBar;
  miPowerPoint: TMenuItem;
  miBrowser: TMenuItem;
  miExternalApp: TMenuItem;
  pmAddScene: TPopupMenu;
 private
  FSession: TSceneProjectSession;
  FUpdating: Boolean;
  FVolumeTextValid: Boolean;
  procedure UpdateInspector;
  procedure TreeGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
    Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
  procedure TreeFocusChanged(Sender: TBaseVirtualTree; Node: PVirtualNode;
    Column: TColumnIndex);
  procedure VolumeEditChanged(Sender: TObject);
  procedure VolumeTrackChanged(Sender: TObject);
  procedure AddMenuClick(Sender: TObject);
  procedure AddButtonClick(Sender: TObject);
  procedure RemoveClick(Sender: TObject);
  procedure MoveClick(Sender: TObject);
  procedure SaveClick(Sender: TObject);
  procedure BackClick(Sender: TObject);
  procedure EditorShow(Sender: TObject);
  procedure EditorCloseQuery(Sender: TObject; var CanClose: Boolean);
 public
  constructor Create(AOwner: TComponent); override;
  destructor Destroy; override;
  procedure RefreshEditor;
  procedure SelectScene(Index: Integer);
  procedure AddScene(Kind: TSceneKind);
  function OpenProject(const FileName: string): TSceneFileLoadResult;
  property Session: TSceneProjectSession read FSession;
 end;

var
 frmSceneEditor: TfrmSceneEditor;

implementation

uses
 System.SysUtils, System.Types, System.UITypes, Vcl.Dialogs, uWelcomeForm;

{$R *.dfm}

constructor TfrmSceneEditor.Create(AOwner: TComponent);
begin
 inherited Create(AOwner);
 FSession := ActiveProjectSession;
 OnShow := EditorShow;
 OnCloseQuery := EditorCloseQuery;
 btnBackToWelcome.OnClick := BackClick;
 miPowerPoint.Enabled := False;
 miPowerPoint.Visible := False;
 vstScenes.OnGetText := TreeGetText;
 vstScenes.OnFocusChanged := TreeFocusChanged;
 edtExplicitVolume.OnChange := VolumeEditChanged;
 trkExplicitVolume.OnChange := VolumeTrackChanged;
 btnAddNewScene.OnClick := AddButtonClick;
 miPowerPoint.OnClick := AddMenuClick;
 miBrowser.OnClick := AddMenuClick;
 miExternalApp.OnClick := AddMenuClick;
 btnRemoveScene.OnClick := RemoveClick;
 btnMoveUp.OnClick := MoveClick;
 btnMoveDown.OnClick := MoveClick;
 btnSave.OnClick := SaveClick;
 // Only bind existing controls. The PO-authored DFM remains byte-for-byte intact.
 trkExplicitVolume.Min := 0;
 trkExplicitVolume.Max := 100;
 lblExplicitVolume.Caption := 'Explicit Volume (%) | -1: No Volume Override';
 edtExplicitVolume.TextHint := '-1 = No Volume Override';
 cmbPowerPointTarget.Enabled := False; // No approved domain mapping for this field.
 cmbBrowserTarget.Enabled := False;
 cmbExternalAppTarget.Enabled := False;
 edtPowerPointLogicalSlide.ReadOnly := True; // Target editing is outside VOL-M02.
 RefreshEditor;
end;

destructor TfrmSceneEditor.Destroy;
begin
 FUpdating := True;
 if Assigned(vstScenes) then
 begin
  vstScenes.OnGetText := nil;
  vstScenes.OnFocusChanged := nil;
 end;
 // Application owns the shared authoring session.
 inherited Destroy;
end;

procedure TfrmSceneEditor.TreeGetText(Sender: TBaseVirtualTree;
 Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType;
 var CellText: string);
var
 Scene: TSceneDefinition;
 Volume: string;
begin
 CellText := '';
 if (Node = nil) or (Integer(Node.Index) >= FSession.SceneCount) then Exit;
 Scene := FSession.GetScene(Node.Index);
 if Scene.ExplicitVolumePercent = -1 then Volume := 'No Volume Override'
 else Volume := IntToStr(Scene.ExplicitVolumePercent) + '%';
 CellText := Format('%d. %s | %s | %s', [Node.Index + 1,
  SceneKindName(Scene.SceneKind), Scene.SceneId, Volume]);
end;

procedure TfrmSceneEditor.RefreshEditor;
var
 Node: PVirtualNode;
begin
 FUpdating := True;
 vstScenes.BeginUpdate;
 try
  // Nodes mirror logical array positions; they never own Scene data.
  vstScenes.Clear;
  vstScenes.RootNodeCount := FSession.SceneCount;
  Node := vstScenes.GetFirst;
  while Node <> nil do
  begin
   if Integer(Node.Index) = FSession.SelectedIndex then
   begin
    vstScenes.FocusedNode := Node;
    vstScenes.Selected[Node] := True;
    Break;
   end;
   Node := vstScenes.GetNextSibling(Node);
  end;
 finally
  vstScenes.EndUpdate;
  FUpdating := False;
 end;
 UpdateInspector;
end;

procedure TfrmSceneEditor.SelectScene(Index: Integer);
begin
 FSession.SelectScene(Index);
 RefreshEditor;
end;

procedure TfrmSceneEditor.TreeFocusChanged(Sender: TBaseVirtualTree;
 Node: PVirtualNode; Column: TColumnIndex);
begin
 if FUpdating then Exit;
 if Node = nil then FSession.SelectScene(-1)
 else FSession.SelectScene(Node.Index);
 // Never commit the old Edit.Text while selecting a different Scene.
 UpdateInspector;
end;

procedure TfrmSceneEditor.UpdateInspector;
var
 Scene: TSceneDefinition;
 HasSelection: Boolean;
begin
 FUpdating := True;
 try
  if FSession.ActivePath <> '' then lblDemoTitle.Caption := ExtractFileName(FSession.ActivePath)
  else if FSession.HasActiveContext then lblDemoTitle.Caption := 'New project - ' + FSession.Presentation.FileName;
  HasSelection := FSession.SelectedIndex >= 0;
  edtExplicitVolume.Enabled := HasSelection;
  trkExplicitVolume.Enabled := HasSelection;
  btnRemoveScene.Enabled := HasSelection;
  btnMoveUp.Enabled := HasSelection and (FSession.SelectedIndex > 0);
  btnMoveDown.Enabled := HasSelection and
   (FSession.SelectedIndex < FSession.SceneCount - 1);
  lblExplicitVolumeError.Visible := False;
  FVolumeTextValid := True;
  if FSession.Modified then lblModifiedStatus.Caption := 'Modified'
  else lblModifiedStatus.Caption := 'No unsaved changes';
  if not HasSelection then
  begin
   edtExplicitVolume.Text := '';
   trkExplicitVolume.Position := 0;
   lblSceneId.Caption := 'Scene ID: -';
   lblSceneKind.Caption := 'Scene Kind: -';
   crpSceneDetails.ActiveCard := crdEmpty;
   sbSceneEditor.SimpleText := 'No Scene selected';
   Exit;
  end;
  Scene := FSession.GetScene(FSession.SelectedIndex);
  lblSceneId.Caption := 'Scene ID: ' + Scene.SceneId;
  lblSceneKind.Caption := 'Scene Kind: ' + SceneKindName(Scene.SceneKind);
  edtExplicitVolume.Text := IntToStr(Scene.ExplicitVolumePercent);
  if Scene.ExplicitVolumePercent = -1 then
  begin
   trkExplicitVolume.Position := 0; // Visual placeholder only, never written to model.
   sbSceneEditor.SimpleText := 'No Volume Override';
  end
  else
  begin
   trkExplicitVolume.Position := Scene.ExplicitVolumePercent;
   sbSceneEditor.SimpleText := 'Absolute master-volume target: ' +
    IntToStr(Scene.ExplicitVolumePercent) + '% (authoring only)';
  end;
  case Scene.SceneKind of
   skPowerPoint: crpSceneDetails.ActiveCard := crdPowerPoint;
   skBrowser: crpSceneDetails.ActiveCard := crdBrowser;
   skExternalApp: crpSceneDetails.ActiveCard := crdExternalApp;
  else
   crpSceneDetails.ActiveCard := crdEmpty;
  end;
  if Scene.PowerPointLogicalSlide = 0 then edtPowerPointLogicalSlide.Text := ''
  else edtPowerPointLogicalSlide.Text := IntToStr(Scene.PowerPointLogicalSlide);
  cmbBrowserTarget.Items.Clear;
  if Scene.BrowserTargetReference <> '' then
   cmbBrowserTarget.ItemIndex := cmbBrowserTarget.Items.Add(Scene.BrowserTargetReference);
  cmbExternalAppTarget.Items.Clear;
  if Scene.ExternalAppTargetReference <> '' then
   cmbExternalAppTarget.ItemIndex := cmbExternalAppTarget.Items.Add(Scene.ExternalAppTargetReference);
 finally
  FUpdating := False;
 end;
end;

procedure TfrmSceneEditor.VolumeEditChanged(Sender: TObject);
var
 Value: Integer;
begin
 if FUpdating or (FSession.SelectedIndex < 0) then Exit;
 FVolumeTextValid := TryParseSceneVolumeText(edtExplicitVolume.Text, Value);
 lblExplicitVolumeError.Visible := not FVolumeTextValid;
 if not FVolumeTextValid then
 begin
  lblExplicitVolumeError.Caption := 'Use -1 (No Volume Override) or an integer 0..100.';
  Exit; // Invalid text stays visible; model is unchanged and Save is blocked.
 end;
 FSession.TrySetSceneVolume(FSession.SelectedIndex, Value);
 FUpdating := True;
 try
  if Value = -1 then trkExplicitVolume.Position := 0
  else trkExplicitVolume.Position := Value;
 finally
  FUpdating := False;
 end;
 if Value = -1 then sbSceneEditor.SimpleText := 'No Volume Override'
 else sbSceneEditor.SimpleText := 'Absolute master-volume target: ' + IntToStr(Value) + '% (authoring only)';
 if FSession.Modified then lblModifiedStatus.Caption := 'Modified';
 vstScenes.Invalidate;
end;

procedure TfrmSceneEditor.VolumeTrackChanged(Sender: TObject);
begin
 if FUpdating or (FSession.SelectedIndex < 0) then Exit;
 // The Edit handler is the single commit path for a user volume change.
 edtExplicitVolume.Text := IntToStr(trkExplicitVolume.Position);
end;

procedure TfrmSceneEditor.AddButtonClick(Sender: TObject);
var
 P: TPoint;
begin
 P := btnAddNewScene.ClientToScreen(Point(0, btnAddNewScene.Height));
 pmAddScene.Popup(P.X, P.Y);
end;

procedure TfrmSceneEditor.AddMenuClick(Sender: TObject);
begin
 if Sender = miBrowser then AddScene(skBrowser)
 else if Sender = miExternalApp then AddScene(skExternalApp);
end;

procedure TfrmSceneEditor.AddScene(Kind: TSceneKind);
begin
 if not FSession.HasActiveContext then Exit;
 if not (Kind in [skBrowser, skExternalApp]) then Exit;
 FSession.AddScene(Kind);
 RefreshEditor;
end;

procedure TfrmSceneEditor.RemoveClick(Sender: TObject);
begin
 FSession.RemoveSelected;
 RefreshEditor;
end;

procedure TfrmSceneEditor.MoveClick(Sender: TObject);
begin
 if Sender = btnMoveUp then FSession.MoveSelected(-1)
 else FSession.MoveSelected(1);
 RefreshEditor;
end;

function TfrmSceneEditor.OpenProject(const FileName: string): TSceneFileLoadResult;
begin
 Result := Default(TSceneFileLoadResult);
 Result.ErrorMessage := 'Open projects through Welcome PowerPoint relinking.';
end;

procedure TfrmSceneEditor.SaveClick(Sender: TObject);
var
 R: TProjectSaveResult;
 Dialog: TSaveDialog;
begin
 if not FVolumeTextValid then
 begin
  edtExplicitVolume.SetFocus;
  Exit;
 end;
 R := FSession.Save;
 if R.Status = psSaveAsRequired then
 begin
  Dialog := TSaveDialog.Create(Self);
  try
   Dialog.Title := 'Save As PA.SceneProject v3';
   Dialog.Filter := 'PA Scene Project (*.json)|*.json';
   Dialog.DefaultExt := 'json';
   Dialog.Options := Dialog.Options + [ofOverwritePrompt, ofPathMustExist];
   if Dialog.Execute then R := FSession.SaveAs(Dialog.FileName)
   else R := FSession.SaveAs('');
  finally
   Dialog.Free;
  end;
 end;
 if R.Status = psFailed then
  MessageDlg(R.ErrorMessage, mtError, [mbOK], 0)
 else if R.Status = psSaved then UpdateInspector;
end;

procedure TfrmSceneEditor.EditorShow(Sender: TObject);
begin
 if not FSession.HasActiveContext then
   raise EInvalidOpException.Create('Open or create a project through Welcome first.');
 RefreshEditor;
end;
procedure TfrmSceneEditor.BackClick(Sender: TObject);
begin
 // Keep the active document and unsaved edits; replacement is gated in Welcome.
 WelcomeForm.Show;
 Hide;
end;
procedure TfrmSceneEditor.EditorCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
 CanClose := True; // Closing hides this secondary Form, retaining application session.
 WelcomeForm.Show;
end;
end.

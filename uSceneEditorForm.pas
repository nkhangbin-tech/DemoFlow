unit uSceneEditorForm;

interface

uses
 System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls,
 Vcl.ComCtrls, Vcl.Menus, Vcl.WinXPanels, VirtualTrees,
 VirtualTrees.BaseTree, VirtualTrees.Types, PASceneDomain,
 PASceneProjectFileStore, PASceneProjectSession, VirtualTrees.BaseAncestorVCL,
  VirtualTrees.AncestorVCL;

type
 TEditorCloseChoice = (ecSave, ecDiscard, ecCancel);

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
  FClosingSession: Boolean;
  procedure UpdateInspector;
  procedure RefreshReadinessEligibility;
  procedure RefreshVolumeStatus;
  function PersistInspector: TProjectSaveResult;
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
  procedure EditorShow(Sender: TObject);
  procedure EditorCloseQuery(Sender: TObject; var CanClose: Boolean);
 protected
  function ChooseCloseAction: TEditorCloseChoice; virtual;
  function ChooseSaveAsFile(out FileName: string): Boolean; virtual;
  procedure PresentSaveError(const ErrorText: string); virtual;
  procedure ReturnToWelcome; virtual;
 public
  function TryCloseActiveSession: Boolean;
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

// Presentation-only strings; no identity or display-name persistence.
function SceneListSceneText(const Scene: TSceneDefinition; LogicalIndex: Integer): string;
function SceneListVolumeText(const Scene: TSceneDefinition): string;

implementation

uses
 System.SysUtils, System.Types, System.UITypes, Vcl.Dialogs, uWelcomeForm;

{$R *.dfm}

function SceneListSceneText(const Scene: TSceneDefinition; LogicalIndex: Integer): string;
var
 Kind: string;
begin
 case Scene.SceneKind of
  skPowerPoint: Kind := 'PowerPoint';
  skBrowser: Kind := 'Browser';
  skExternalApp: Kind := 'External App';
 else
  Kind := 'Unknown';
 end;
 Result := IntToStr(LogicalIndex + 1) + '. ' + Kind;
 if Scene.SceneKind = skPowerPoint then
  Result := Result + ' ' + #$00B7 + ' Slide ' + IntToStr(Scene.PowerPointLogicalSlide);
end;

function SceneListVolumeText(const Scene: TSceneDefinition): string;
begin
 if Scene.ExplicitVolumePercent = -1 then Result := #$2014
 else Result := IntToStr(Scene.ExplicitVolumePercent) + '%';
end;

constructor TfrmSceneEditor.Create(AOwner: TComponent);
begin
 inherited Create(AOwner);
 FSession := ActiveProjectSession;
 OnShow := EditorShow;
 OnCloseQuery := EditorCloseQuery;
 btnBackToWelcome.OnClick := nil; // Hidden button is not a second navigation route.
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
 lblExplicitVolume.Caption := 'Explicit Volume (%)';
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
begin
 CellText := '';
 if (Node = nil) or (Integer(Node.Index) >= FSession.SceneCount) then Exit;
 Scene := FSession.GetScene(Node.Index);
 if Column = 0 then CellText := SceneListSceneText(Scene, Node.Index)
 else if Column = 1 then CellText := SceneListVolumeText(Scene);
end;

procedure TfrmSceneEditor.RefreshEditor;
var
 Node: PVirtualNode;
begin
 // Selection is UI state only; never marks the authoring document Modified.
 if FSession.HasActiveContext and (FSession.SceneCount > 0) and
   ((FSession.SelectedIndex < 0) or (FSession.SelectedIndex >= FSession.SceneCount)) then
  FSession.SelectScene(0);
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
  else if FSession.HasActiveContext then lblDemoTitle.Caption := 'New project - ' + FSession.Presentation.FileName
  else lblDemoTitle.Caption := 'No active project';
  HasSelection := FSession.HasActiveContext and (FSession.SelectedIndex >= 0);
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
   Exit;
  end;
  Scene := FSession.GetScene(FSession.SelectedIndex);
  lblSceneId.Caption := 'Scene ID: ' + Scene.SceneId;
  lblSceneKind.Caption := 'Scene Kind: ' + SceneKindName(Scene.SceneKind);
  edtExplicitVolume.Text := IntToStr(Scene.ExplicitVolumePercent);
  if Scene.ExplicitVolumePercent = -1 then
   trkExplicitVolume.Position := 0 // Visual placeholder only; no model update.
  else
   trkExplicitVolume.Position := Scene.ExplicitVolumePercent;
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
  RefreshVolumeStatus;
  RefreshReadinessEligibility;
 end;
end;

procedure TfrmSceneEditor.RefreshVolumeStatus;
var
 Value: Integer;
begin
 // Read committed model data only. Never replace pending Edit text or its error.
 if not FSession.HasActiveContext or (FSession.SelectedIndex < 0) or
   (FSession.SelectedIndex >= FSession.SceneCount) then
 begin
  sbSceneEditor.SimpleText := 'No Scene selected';
  Exit;
 end;
 Value := FSession.GetScene(FSession.SelectedIndex).ExplicitVolumePercent;
 if Value = -1 then sbSceneEditor.SimpleText := 'No Volume Override'
 else if (Value >= 0) and (Value <= 100) then
  sbSceneEditor.SimpleText := 'Absolute master-volume target: ' +
   IntToStr(Value) + '% (authoring only)'
 else
  sbSceneEditor.SimpleText := 'Selected Scene has an invalid Explicit Volume value.';
end;

procedure TfrmSceneEditor.RefreshReadinessEligibility;
begin
 btnReadiness.Enabled := FSession.CanEnterReadiness(not FVolumeTextValid);
 // No approved Readiness destination exists; eligibility does not run checks.
end;

procedure TfrmSceneEditor.VolumeEditChanged(Sender: TObject);
var
 Value: Integer;
begin
 if FUpdating or (FSession.SelectedIndex < 0) then Exit;
 FVolumeTextValid := TryParseSceneVolumeText(edtExplicitVolume.Text, Value);
 lblExplicitVolumeError.Visible := not FVolumeTextValid;
 RefreshReadinessEligibility;
 if not FVolumeTextValid then
 begin
  lblExplicitVolumeError.Caption := 'Use -1 (No Volume Override) or an integer 0..100.';
  RefreshVolumeStatus;
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
 RefreshVolumeStatus;
 if FSession.Modified then lblModifiedStatus.Caption := 'Modified';
 vstScenes.Invalidate;
 RefreshReadinessEligibility;
end;

procedure TfrmSceneEditor.VolumeTrackChanged(Sender: TObject);
begin
 if FUpdating or (FSession.SelectedIndex < 0) then Exit;
 // The Edit handler is the single commit path for a user volume change.
 edtExplicitVolume.Text := IntToStr(trkExplicitVolume.Position);
 RefreshVolumeStatus;
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

function TfrmSceneEditor.ChooseSaveAsFile(out FileName: string): Boolean;
var
 Dialog: TSaveDialog;
begin
 FileName := '';
 Dialog := TSaveDialog.Create(Self);
 try
  Dialog.Title := 'Save As PA.SceneProject v3';
  Dialog.Filter := 'PA Scene Project (*.json)|*.json';
  Dialog.DefaultExt := 'json';
  Dialog.Options := Dialog.Options + [ofOverwritePrompt, ofPathMustExist];
  Result := Dialog.Execute;
  if Result then FileName := Dialog.FileName;
 finally
  Dialog.Free;
 end;
end;

procedure TfrmSceneEditor.PresentSaveError(const ErrorText: string);
begin
 MessageDlg(ErrorText, mtError, [mbOK], 0);
end;

function TfrmSceneEditor.PersistInspector: TProjectSaveResult;
var
 FileName: string;
begin
 Result := Default(TProjectSaveResult);
 if not FVolumeTextValid then
 begin
  Result.Status := psFailed;
  Result.ErrorMessage := 'Correct the invalid Explicit Volume before saving.';
  if Visible and edtExplicitVolume.CanFocus then edtExplicitVolume.SetFocus;
  RefreshReadinessEligibility;
  Exit;
 end;
 if not FSession.HasActiveContext then
 begin
  Result.Status := psFailed;
  Result.ErrorMessage := 'No active project to save.';
  Exit;
 end;
 Result := FSession.Save;
 if Result.Status = psSaveAsRequired then
 begin
  if ChooseSaveAsFile(FileName) then Result := FSession.SaveAs(FileName)
  else Result := FSession.SaveAs('');
 end;
 if Result.Status = psSaved then UpdateInspector
 else RefreshReadinessEligibility;
end;

procedure TfrmSceneEditor.SaveClick(Sender: TObject);
var
 R: TProjectSaveResult;
begin
 R := PersistInspector;
 if R.Status = psFailed then PresentSaveError(R.ErrorMessage);
end;

procedure TfrmSceneEditor.EditorShow(Sender: TObject);
begin
 if not FSession.HasActiveContext then
   raise EInvalidOpException.Create('Open or create a project through Welcome first.');
 RefreshEditor;
end;

function TfrmSceneEditor.ChooseCloseAction: TEditorCloseChoice;
var
 Answer: Integer;
begin
 Answer := TaskMessageDlg('Close project', 'Save changes before closing this project?',
  mtConfirmation, [mbYes, mbNo, mbCancel], 0, mbCancel, ['Save', 'Don''t Save', 'Cancel']);
 case Answer of
  mrYes: Result := ecSave;
  mrNo: Result := ecDiscard;
 else
  Result := ecCancel;
 end;
end;

function TfrmSceneEditor.TryCloseActiveSession: Boolean;
var
 R: TProjectSaveResult;
begin
 Result := False;
 if FClosingSession then Exit;
 FClosingSession := True;
 try
  if FSession.Modified or not FVolumeTextValid then
  begin
   case ChooseCloseAction of
    ecCancel: Exit;
    ecSave:
     begin
      R := PersistInspector; // Same Save/Save As path as the existing Save button.
      if R.Status <> psSaved then
      begin
       if R.Status = psFailed then PresentSaveError(R.ErrorMessage);
       Exit; // Preserve active context, draft, invalid input and selection.
      end;
     end;
    ecDiscard: ; // Explicitly confirmed; no write to a saved project.
   end;
  end;
  FSession.CloseProject;
  RefreshEditor;
  Result := True;
 finally
  FClosingSession := False;
 end;
end;

procedure TfrmSceneEditor.ReturnToWelcome;
begin
 if Assigned(WelcomeForm) then WelcomeForm.Show;
end;

procedure TfrmSceneEditor.EditorCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
 CanClose := TryCloseActiveSession;
 if CanClose then ReturnToWelcome;
end;

end.

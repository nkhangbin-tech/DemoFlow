unit uWelcomeForm;

interface

uses
  System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, PAPresentationDiscovery;

type
  TWelcomeForm = class(TForm)
    lblCreateHint: TLabel;
    lblCreatePpt: TLabel;
    cboCreatePowerPoint: TComboBox;
    btnCreateRefresh: TButton;
    lblCreateNoPowerPoint: TLabel;
    lblCreateError: TLabel;
    btnCreate: TButton;
    lblProjectFile: TLabel;
    edtProjectFile: TEdit;
    btnBrowse: TButton;
    lblOpenPpt: TLabel;
    cboOpenPowerPoint: TComboBox;
    btnOpenRefresh: TButton;
    lblOpenNoPowerPoint: TLabel;
    lblOpenError: TLabel;
    btnOpen: TButton;
    lblRecent0: TLabel;
    lblRecent1: TLabel;
    lblRecent2: TLabel;
    lblRecent3: TLabel;
    lblRecent4: TLabel;
    lblRecent5: TLabel;
    lblRecentRelink: TLabel;
    btnReopen: TButton;
    grpCreate: TGroupBox;
    grpOpen: TGroupBox;
    grpRecent: TGroupBox;
    lblStatus: TLabel;
    btnCancel: TButton;
    pnlFooter: TPanel;
    procedure btnCreateRefreshClick(Sender: TObject);
  private
    FCandidates: TPresentationCandidates;
    FRecentPath: string;
    FOpenSelectionManual: Boolean;
    FOpenSelectionProjectPath: string;
    procedure RefreshClick(Sender: TObject);
    procedure SelectionChanged(Sender: TObject);
    procedure BrowseClick(Sender: TObject);
    procedure CreateClick(Sender: TObject);
    procedure OpenClick(Sender: TObject);
    procedure ReopenClick(Sender: TObject);
    procedure CancelClick(Sender: TObject);
    procedure WelcomeShow(Sender: TObject);
    procedure LoadRecent;
    procedure EnterEditor;
    function AllowReplacement: Boolean;
  protected
    function ScanPresentations(out ErrorText: string): TPresentationCandidates; virtual;
    procedure SelectProjectFile(const FileName: string);
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  WelcomeForm: TWelcomeForm;

implementation
uses System.SysUtils, System.IOUtils, System.UITypes, Vcl.Dialogs,
  PASceneDomain, PASceneProjectFileStore, PASceneProjectSession, PARecentProject,
  uSceneEditorForm;

{$R *.dfm}

constructor TWelcomeForm.Create(AOwner: TComponent);
begin
  inherited;
  btnCreateRefresh.OnClick := btnCreateRefreshClick;
  btnOpenRefresh.OnClick := RefreshClick;
  cboCreatePowerPoint.OnChange := SelectionChanged;
  cboOpenPowerPoint.OnChange := SelectionChanged;
  btnBrowse.OnClick := BrowseClick;
  btnCreate.OnClick := CreateClick;
  btnOpen.OnClick := OpenClick;
  btnReopen.OnClick := ReopenClick;
  btnCancel.OnClick := CancelClick;
  OnShow := WelcomeShow;
end;
procedure TWelcomeForm.WelcomeShow(Sender: TObject);
begin
  RefreshClick(nil);
  LoadRecent;
end;
procedure TWelcomeForm.btnCreateRefreshClick(Sender: TObject);
begin
  RefreshClick(Sender);
end;

function TWelcomeForm.ScanPresentations(out ErrorText: string): TPresentationCandidates;
begin
  Result := DiscoverPresentations(ErrorText);
end;

procedure TWelcomeForm.SelectProjectFile(const FileName: string);
begin
  edtProjectFile.Text := FileName;
  RefreshClick(nil);
end;

procedure TWelcomeForm.RefreshClick(Sender: TObject);
var C, PreviousCreate, PreviousOpen: TPresentationCandidate;
  ErrorText: string;
  HadCreate, HadOpen, PreservedOpen: Boolean;
  CreateIndex, OpenIndex, MatchCount, MatchIndex, I: Integer;
  Loaded: TSceneFileLoadResult;
begin
  HadCreate := (cboCreatePowerPoint.ItemIndex >= 0) and
    (cboCreatePowerPoint.ItemIndex < Length(FCandidates));
  HadOpen := FOpenSelectionManual and (cboOpenPowerPoint.ItemIndex >= 0) and
    (cboOpenPowerPoint.ItemIndex < Length(FCandidates));
  PreviousCreate := Default(TPresentationCandidate);
  PreviousOpen := Default(TPresentationCandidate);
  if HadCreate then PreviousCreate := FCandidates[cboCreatePowerPoint.ItemIndex];
  if HadOpen then PreviousOpen := FCandidates[cboOpenPowerPoint.ItemIndex];
  btnCreate.Enabled := False; btnOpen.Enabled := False;
  cboCreatePowerPoint.Clear; cboOpenPowerPoint.Clear;
  FCandidates := ScanPresentations(ErrorText);
  CreateIndex := -1;
  for I := 0 to High(FCandidates) do
  begin
    C := FCandidates[I];
    cboCreatePowerPoint.Items.Add(C.Title);
    cboOpenPowerPoint.Items.Add(C.Title);
    if HadCreate and SamePresentation(PreviousCreate, C) then CreateIndex := I;
  end;
  if (CreateIndex < 0) and (Length(FCandidates) > 0) then CreateIndex := 0;
  cboCreatePowerPoint.ItemIndex := CreateIndex;

  Loaded := Default(TSceneFileLoadResult);
  if edtProjectFile.Text <> '' then Loaded := LoadSceneProject(edtProjectFile.Text);
  OpenIndex := -1; PreservedOpen := False;
  if Loaded.Success then
  begin
    // Preserve an explicit manual binding on Refresh. A newly chosen v3 project
    // uses its own metadata; legacy files never imply a metadata match.
    if HadOpen and ((Loaded.DocumentResult.SourceFormatVersion < 3) or
      SameText(FOpenSelectionProjectPath, edtProjectFile.Text)) then
      for I := 0 to High(FCandidates) do
        if SamePresentation(PreviousOpen, FCandidates[I]) then
        begin OpenIndex := I; PreservedOpen := True; Break; end;
    if (OpenIndex < 0) and (Loaded.DocumentResult.SourceFormatVersion = 3) then
    begin
      MatchCount := 0; MatchIndex := -1;
      for I := 0 to High(FCandidates) do
        if SameText(Loaded.DocumentResult.Document.PowerPointFileName,
          FCandidates[I].FileName) then
        begin Inc(MatchCount); MatchIndex := I; end;
      if MatchCount = 1 then OpenIndex := MatchIndex;
      // SlideCount is deliberately checked by Open, never by preselection.
    end;
  end;
  cboOpenPowerPoint.ItemIndex := OpenIndex;
  FOpenSelectionManual := PreservedOpen;
  FOpenSelectionProjectPath := edtProjectFile.Text;
  lblCreateNoPowerPoint.Visible := Length(FCandidates) = 0;
  lblOpenNoPowerPoint.Visible := Length(FCandidates) = 0;
  lblCreateError.Caption := ErrorText; lblOpenError.Caption := ErrorText;
  if (edtProjectFile.Text <> '') and not Loaded.Success then
    lblOpenError.Caption := Loaded.ErrorMessage;
  SelectionChanged(nil);
end;
procedure TWelcomeForm.SelectionChanged(Sender: TObject);
begin
  if Sender = cboOpenPowerPoint then
  begin
    FOpenSelectionManual := cboOpenPowerPoint.ItemIndex >= 0;
    FOpenSelectionProjectPath := edtProjectFile.Text;
  end;
  btnCreate.Enabled := (cboCreatePowerPoint.ItemIndex >= 0) and
    (cboCreatePowerPoint.ItemIndex < Length(FCandidates));
  btnOpen.Enabled := TFile.Exists(edtProjectFile.Text) and
    (cboOpenPowerPoint.ItemIndex >= 0) and (cboOpenPowerPoint.ItemIndex < Length(FCandidates));
end;
procedure TWelcomeForm.BrowseClick(Sender: TObject);
var D: TOpenDialog;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Filter := 'PA Scene Project (*.json)|*.json';
    D.Options := D.Options + [ofFileMustExist, ofPathMustExist];
    if D.Execute then SelectProjectFile(D.FileName);
  finally D.Free; end;
  SelectionChanged(nil);
end;
function TWelcomeForm.AllowReplacement: Boolean;
begin
  Result := not ActiveProjectSession.Modified;
  if not Result then
    Result := MessageDlg('Replace the active project and discard its unsaved changes?',
      mtWarning, [mbYes, mbNo], 0, mbNo) = mrYes;
end;
procedure TWelcomeForm.EnterEditor;
begin
  if not Assigned(frmSceneEditor) then frmSceneEditor := TfrmSceneEditor.Create(Application);
  frmSceneEditor.RefreshEditor;
  frmSceneEditor.Show;
  Hide;
end;
procedure TWelcomeForm.CreateClick(Sender: TObject);
var Current: TPresentationCandidate; ErrorText: string; Pending: TSceneProjectSession; I: Integer;
begin
  I := cboCreatePowerPoint.ItemIndex;
  if (I < 0) or (I >= Length(FCandidates)) then Exit;
  if not ResolvePresentation(FCandidates[I], Current, ErrorText) then
  begin lblCreateError.Caption := ErrorText; btnCreate.Enabled := False; Exit; end;
  Pending := TSceneProjectSession.Create;
  try
    try
      Pending.PrepareNew(Current);
      if not AllowReplacement then Exit;
      // Resolve again after the modal replacement decision.
      if not ResolvePresentation(FCandidates[I], Current, ErrorText) then
      begin lblCreateError.Caption := ErrorText; Exit; end;
      ActiveProjectSession.AdoptCandidate(Pending);
      EnterEditor;
    except on E: Exception do lblCreateError.Caption := E.Message; end;
  finally Pending.Free; end;
end;
procedure TWelcomeForm.OpenClick(Sender: TObject);
var Current, Selected: TPresentationCandidate; ErrorText: string;
  Pending: TSceneProjectSession; Loaded: TSceneFileLoadResult; ConfirmLegacy: Boolean; I: Integer;
begin
  I := cboOpenPowerPoint.ItemIndex;
  if (I < 0) or (I >= Length(FCandidates)) then Exit;
  Selected := FCandidates[I];
  if not ResolvePresentation(Selected, Current, ErrorText) then
  begin lblOpenError.Caption := ErrorText; btnOpen.Enabled := False; Exit; end;
  Pending := TSceneProjectSession.Create;
  try
    try
      Loaded := Pending.OpenProject(edtProjectFile.Text);
      if not Loaded.Success then begin lblOpenError.Caption := Loaded.ErrorMessage; Exit; end;
      ConfirmLegacy := False;
      if Loaded.DocumentResult.SourceFormatVersion < 3 then
      begin
        ConfirmLegacy := MessageDlg('Legacy project: stored metadata cannot verify filename + slide count.' +
          sLineBreak + 'Confirm binding to ' + Current.FileName + ' (' + IntToStr(Current.SlideCount) +
          ' slides)? Save As v3 is required to persist this binding.', mtWarning, [mbYes, mbNo], 0, mbNo) = mrYes;
        if not ConfirmLegacy then Exit;
      end;
      if not Pending.BindPresentation(Current, ConfirmLegacy, ErrorText) then
      begin lblOpenError.Caption := ErrorText; Exit; end;
      if not AllowReplacement then Exit;
      if not ResolvePresentation(Selected, Current, ErrorText) then
      begin lblOpenError.Caption := ErrorText; Exit; end;
      ActiveProjectSession.AdoptCandidate(Pending);
      RecordRecentProject(ActiveProjectSession.ActivePath);
      EnterEditor;
    except on E: Exception do lblOpenError.Caption := E.Message; end;
  finally Pending.Free; end;
end;
procedure TWelcomeForm.LoadRecent;
var Worked: string; Loaded: TSceneFileLoadResult; Scene: TSceneDefinition; ExternalCount: Integer;
begin
  FRecentPath := RecentProjectPath(Worked);
  btnReopen.Enabled := False;
  lblRecent0.Caption := 'Project name: --'; lblRecent1.Caption := 'Project file: --';
  lblRecent2.Caption := 'PowerPoint filename: --'; lblRecent3.Caption := 'Slide count: --';
  lblRecent4.Caption := 'External scene count: --'; lblRecent5.Caption := 'Last worked: --';
  if FRecentPath = '' then Exit;
  Loaded := LoadSceneProject(FRecentPath);
  if not Loaded.Success then begin FRecentPath := ''; Exit; end;
  lblRecent0.Caption := 'Project name: ' + ChangeFileExt(ExtractFileName(FRecentPath), '');
  lblRecent1.Caption := 'Project file: ' + FRecentPath;
  if Loaded.DocumentResult.SourceFormatVersion = 3 then
  begin
    lblRecent2.Caption := 'PowerPoint filename: ' + Loaded.DocumentResult.Document.PowerPointFileName;
    lblRecent3.Caption := 'Slide count: ' + IntToStr(Loaded.DocumentResult.Document.PowerPointSlideCount);
  end;
  ExternalCount := 0;
  for Scene in Loaded.DocumentResult.Document.Scenes do
    if Scene.SceneKind = skExternalApp then Inc(ExternalCount);
  lblRecent4.Caption := 'External scene count: ' + IntToStr(ExternalCount);
  lblRecent5.Caption := 'Last worked: ' + Worked;
  btnReopen.Enabled := True;
end;
procedure TWelcomeForm.ReopenClick(Sender: TObject);
begin
  if FRecentPath = '' then Exit;
  SelectProjectFile(FRecentPath);
  lblStatus.Caption := 'Review the PowerPoint selection, then Open.';
  if Visible and cboOpenPowerPoint.CanFocus then cboOpenPowerPoint.SetFocus;
end;
procedure TWelcomeForm.CancelClick(Sender: TObject);
begin
  if ActiveProjectSession.HasActiveContext then EnterEditor else Hide;
end;
end.

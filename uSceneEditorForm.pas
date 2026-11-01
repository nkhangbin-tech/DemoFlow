unit uSceneEditorForm;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.WinXPanels,
  Vcl.Menus, VirtualTrees, VirtualTrees.BaseAncestorVCL, VirtualTrees.BaseTree,
  VirtualTrees.AncestorVCL;

type
  // Alpha VS1-A: design-only; no domain/persistence/runtime integration.
  TfrmSceneEditor = class(TForm)
    pnlHeader: TPanel;
    lblDemoTitle: TLabel;
    lblProjectState: TLabel;
    btnSave: TButton;
    btnReadiness: TButton;
    btnStartLive: TButton;
    btnBackToWelcome: TButton;
    pnlStatus: TPanel;
    lblStatus: TLabel;
    pnlEditorBody: TPanel;
    splEditor: TSplitter;
    pnlSceneList: TPanel;
    pnlSceneListHeader: TPanel;
    lblSceneList: TLabel;
    lblSceneCount: TLabel;
    pnlSceneActions: TPanel;
    btnAddScene: TButton;
    btnRemoveScene: TButton;
    btnMoveSceneUp: TButton;
    btnMoveSceneDown: TButton;
    vstScenes: TVirtualStringTree;
    pnlInspector: TPanel;
    pnlInspectorHeader: TPanel;
    lblSceneDetails: TLabel;
    lblSceneId: TLabel;
    lblSceneKind: TLabel;
    pnlCommonProperties: TPanel;
    lblCommonProperties: TLabel;
    lblExplicitVolume: TLabel;
    trkExplicitVolume: TTrackBar;
    edtExplicitVolume: TEdit;
    lblExplicitVolumeError: TLabel;
    crpSceneDetails: TCardPanel;
    crdEmpty: TCard;
    lblSelectSceneHint: TLabel;
    lblEmptyDescription: TLabel;
    crdPowerPoint: TCard;
    lblPowerPointHeading: TLabel;
    lblLogicalSlide: TLabel;
    edtLogicalSlide: TEdit;
    lblLogicalSlideError: TLabel;
    crdBrowser: TCard;
    lblBrowserHeading: TLabel;
    lblBrowserTarget: TLabel;
    cboBrowserTarget: TComboBox;
    lblBrowserTargetError: TLabel;
    crdExternalApp: TCard;
    lblExternalAppHeading: TLabel;
    lblExternalAppTarget: TLabel;
    cboExternalAppTarget: TComboBox;
    lblExternalAppTargetError: TLabel;
    pmAddScene: TPopupMenu;
    miAddPowerPointScene: TMenuItem;
    miAddBrowserScene: TMenuItem;
    miAddExternalAppScene: TMenuItem;
  end;

var
  frmSceneEditor: TfrmSceneEditor;

implementation

{$R *.dfm}

end.

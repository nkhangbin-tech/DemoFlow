unit uSceneEditorForm;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  Vcl.ComCtrls,
  Vcl.WinXPanels,
  VirtualTrees, VirtualTrees.BaseAncestorVCL, VirtualTrees.BaseTree,
  VirtualTrees.AncestorVCL;

type
  // Alpha VS1-A: layout-only form. No scene/domain/persistence/runtime binding.
  TfrmSceneEditor = class(TForm)
    pnlHeader: TPanel;
    lblDemoTitle: TLabel;
    btnSave: TButton;
    btnReadiness: TButton;
    btnStartLive: TButton;
    pnlStatus: TPanel;
    lblStatus: TLabel;
    pnlEditorBody: TPanel;
    pnlSceneList: TPanel;
    pnlSceneListHeader: TPanel;
    lblSceneList: TLabel;
    vstScenes: TVirtualStringTree;
    pnlSceneActions: TPanel;
    btnAddScene: TButton;
    btnRemoveScene: TButton;
    btnMoveSceneUp: TButton;
    btnMoveSceneDown: TButton;
    splEditor: TSplitter;
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
    crpSceneDetails: TCardPanel;
    crdEmpty: TCard;
    lblSelectSceneHint: TLabel;
    crdPowerPoint: TCard;
    lblPowerPointHeading: TLabel;
    lblLogicalSlide: TLabel;
    edtLogicalSlide: TEdit;
    crdBrowser: TCard;
    lblBrowserHeading: TLabel;
    lblBrowserTarget: TLabel;
    edtBrowserTarget: TComboBox;
    crdExternalApp: TCard;
    lblExternalAppHeading: TLabel;
    lblExternalAppTarget: TLabel;
    edtExternalAppTarget: TComboBox;
    btnBackToWelcome: TButton;
    lblEmptyDescription: TLabel;
  end;

var
  frmSceneEditor:TfrmSceneEditor;
implementation

{$R *.dfm}

end.

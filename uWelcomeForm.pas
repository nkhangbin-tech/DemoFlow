unit uWelcomeForm;

interface

uses
  System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls;

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
  end;

var
  WelcomeForm: TWelcomeForm;

implementation

{$R *.dfm}

end.

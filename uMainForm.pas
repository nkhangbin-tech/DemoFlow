unit uMainForm;

interface

uses
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  System.Classes;

type
  TMainForm = class(TForm)
    StatusLabel: TLabel;
    CloseButton: TButton;
    procedure CloseButtonClick(Sender: TObject);
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

procedure TMainForm.CloseButtonClick(Sender: TObject);
begin
  Close;
end;

end.

unit uDemoCardForm;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.DateUtils,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ExtCtrls;

type
  TDemoInfo = record
    Title: string;
    PptxName: string;
    SceneCount: Integer;
    AppCount: Integer;
    Modified: TDateTime;
    FilePath: string;
  end;

type
  TOpenDemoEvent = procedure(const Info: TDemoInfo) of object;

  TDemoCardForm = class(TForm)
    Panel1: TPanel;
    lblTitle: TLabel;
    shpLine: TShape;
    lblPptx: TLabel;
    lblScenes: TLabel;
    lblModified: TLabel;
    btnOpen: TButton;

    procedure btnOpenClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Panel1MouseLeave(Sender: TObject);
    procedure Panel1MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);

  private
    FInfo: TDemoInfo;
    FOnOpenDemo: TOpenDemoEvent;
    procedure CardClick(Sender: TObject);
    procedure SetHighlighted(AValue: Boolean);
    procedure CardMouseEnter(Sender: TObject);
    procedure CardMouseLeave(Sender: TObject);
  public
    procedure LoadData(const AInfo: TDemoInfo);
    property OnOpenDemo: TOpenDemoEvent read FOnOpenDemo write FOnOpenDemo;
  end;

var DemoCardForm:TDemoCardForm;
implementation

{$R *.dfm}

procedure TDemoCardForm.FormCreate(Sender: TObject);
begin
  BorderStyle := bsNone;

  Color := clWhite;

  Panel1.Align := alClient;
  Panel1.BevelOuter := bvNone;

  OnClick := CardClick;

  Panel1.OnClick := CardClick;
  lblTitle.OnClick := CardClick;
  lblPptx.OnClick := CardClick;
  lblScenes.OnClick := CardClick;
  lblModified.OnClick := CardClick;

  //shpLine.OnClick := CardClick;
  Panel1.OnMouseEnter := CardMouseEnter;
  Panel1.OnMouseLeave := CardMouseLeave;

  lblTitle.OnMouseEnter := CardMouseEnter;
  lblTitle.OnMouseLeave := CardMouseLeave;

  lblPptx.OnMouseEnter := CardMouseEnter;
  lblPptx.OnMouseLeave := CardMouseLeave;

  lblScenes.OnMouseEnter := CardMouseEnter;
  lblScenes.OnMouseLeave := CardMouseLeave;

  lblModified.OnMouseEnter := CardMouseEnter;
  lblModified.OnMouseLeave := CardMouseLeave;

  btnOpen.OnMouseEnter := CardMouseEnter;
  btnOpen.OnMouseLeave := CardMouseLeave;
end;

procedure TDemoCardForm.LoadData(const AInfo: TDemoInfo);
begin
  FInfo := AInfo;

  lblTitle.Caption := '📊 ' + AInfo.Title;
  lblPptx.Caption  := '• PPTX: ' + AInfo.PptxName;
  lblScenes.Caption:= Format('• %d Scenes | %d Apps',
                      [AInfo.SceneCount, AInfo.AppCount]);
  lblModified.Caption := '• Sửa: ' +
             FormatDateTime('dd/mm/yyyy', AInfo.Modified);
end;

procedure TDemoCardForm.SetHighlighted(AValue: Boolean);
begin
  if AValue then
  begin
    Color := $00FAF3E8;          // nền hover
    Panel1.Color := $00FAF3E8;

    Panel1.BevelOuter := bvRaised;
    Panel1.BevelWidth := 2;

    lblTitle.Font.Color := $00C06000;
  end
  else
  begin
    Color := clWhite;
    Panel1.Color := clWhite;
    Panel1.BevelOuter := bvNone;
    lblTitle.Font.Color := clBlack;
  end;
end;

procedure TDemoCardForm.Panel1MouseLeave(Sender: TObject);
begin
  panel1.Color:=clBtnFace
end;

procedure TDemoCardForm.Panel1MouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
  panel1.Color:=clBlue;
end;

procedure TDemoCardForm.btnOpenClick(Sender: TObject);
begin
  if Assigned(FOnOpenDemo) then
    begin
     FOnOpenDemo(FInfo);
     SetHighlighted(False);
    end;
end;

procedure TDemoCardForm.CardClick(Sender: TObject);
begin
  btnOpen.Click;
end;

procedure TDemoCardForm.CardMouseEnter(Sender: TObject);
begin
  SetHighlighted(True);
end;

procedure TDemoCardForm.CardMouseLeave(Sender: TObject);
begin
  var
  P: TPoint;
begin
  GetCursorPos(P);
  P := ScreenToClient(P);

  if not PtInRect(ClientRect, P) then
    SetHighlighted(False);
end;
end;

end.

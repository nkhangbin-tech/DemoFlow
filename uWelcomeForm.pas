unit uWelcomeForm;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.Math,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Dialogs,

  uDemoCardForm;

type
  TWelcomeForm = class(TForm)
    FlowPanel1: TFlowPanel;

    procedure FormResize(Sender: TObject);
    procedure FormShow(Sender: TObject);

  private
    FFiles: TArray<TDemoInfo>;

    procedure OpenDemo(const Info: TDemoInfo);

  public
    procedure ClearCards;
    procedure RebuildCards(const Files: TArray<TDemoInfo>);
  end;

var
  WelcomeForm: TWelcomeForm;

implementation

{$R *.dfm}

procedure TWelcomeForm.ClearCards;
var
  I: Integer;
begin
  for I := FlowPanel1.ControlCount - 1 downto 0 do
    FlowPanel1.Controls[I].Free;
end;

procedure TWelcomeForm.OpenDemo(const Info: TDemoInfo);
begin
  ShowMessage(
    'Demo được chọn:' + sLineBreak +
    Info.Title + sLineBreak +
    Info.FilePath);
end;

procedure TWelcomeForm.RebuildCards(
  const Files: TArray<TDemoInfo>);
var
  I: Integer;
  Cols: Integer;
  CardW: Integer;
  CardH: Integer;
  Gap: Integer;
  Card: TDemoCardForm;
begin

  FFiles := Files;

  ClearCards;

  case Length(Files) of
    0..2:
      Cols := 1;

    3..6:
      Cols := 2;

  else
      Cols := 3;
  end;

  Gap := 12;
  CardH := 220;

  CardW :=
    (FlowPanel1.ClientWidth div Cols)
    - Gap * 2;

  if CardW < 250 then
    CardW := 250;

  FlowPanel1.AutoWrap := True;
  FlowPanel1.FlowStyle := fsLeftRightTopBottom;

  for I := 0 to High(Files) do
  begin
    Card := TDemoCardForm.Create(Self);

    Card.Parent := FlowPanel1;

    Card.BorderStyle := bsNone;

    Card.Width := CardW;
    Card.Height := CardH;

    Card.Margins.Left := Gap div 2;
    Card.Margins.Top := Gap div 2;
    Card.Margins.Right := Gap div 2;
    Card.Margins.Bottom := Gap div 2;

    Card.AlignWithMargins := True;

    Card.LoadData(Files[I]);

    Card.OnOpenDemo := OpenDemo;

    Card.Show;
  end;
end;

procedure TWelcomeForm.FormResize(Sender: TObject);
begin
  if Length(FFiles) > 0 then
    RebuildCards(FFiles);
end;

procedure TWelcomeForm.FormShow(Sender: TObject);
begin
 var
  Data: TArray<TDemoInfo>;
 begin
  
  SetLength(Data, 6);

  // Card 1
  Data[0].Title      := 'Hội thảo AI 2026';
  Data[0].PptxName   := 'Gioi_thieu_AI.pptx';
  Data[0].SceneCount := 12;
  Data[0].AppCount   := 3;
  Data[0].Modified   := EncodeDate(2026, 10, 28);
  Data[0].FilePath   := 'D:\Demo\AI2026';

  // Card 2
  Data[1].Title      := 'Ra mắt SP X';
  Data[1].PptxName   := 'SanPhamX.pptx';
  Data[1].SceneCount := 8;
  Data[1].AppCount   := 2;
  Data[1].Modified   := EncodeDate(2026, 10, 25);
  Data[1].FilePath   := 'D:\Demo\ProductX';

  // Card 3
  Data[2].Title      := 'Cloud Migration';
  Data[2].PptxName   := 'CloudMigration.pptx';
  Data[2].SceneCount := 15;
  Data[2].AppCount   := 4;
  Data[2].Modified   := EncodeDate(2026, 10, 20);
  Data[2].FilePath   := 'D:\Demo\Cloud';

  // Card 4
  Data[3].Title      := 'Copilot for Sales';
  Data[3].PptxName   := 'CopilotSales.pptx';
  Data[3].SceneCount := 10;
  Data[3].AppCount   := 3;
  Data[3].Modified   := EncodeDate(2026, 10, 18);
  Data[3].FilePath   := 'D:\Demo\CopilotSales';

  // Card 5
  Data[4].Title      := 'Dynamics 365 Demo';
  Data[4].PptxName   := 'Dynamics365.pptx';
  Data[4].SceneCount := 14;
  Data[4].AppCount   := 5;
  Data[4].Modified   := EncodeDate(2026, 10, 15);
  Data[4].FilePath   := 'D:\Demo\Dynamics365';

  // Card 6
  Data[5].Title      := 'Power Platform';
  Data[5].PptxName   := 'PowerPlatform.pptx';
  Data[5].SceneCount := 9;
  Data[5].AppCount   := 4;
  Data[5].Modified   := EncodeDate(2026, 10, 12);
  Data[5].FilePath   := 'D:\Demo\PowerPlatform';

  RebuildCards(Data);
 end;
end;
end.

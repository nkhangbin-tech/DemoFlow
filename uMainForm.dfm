object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'Presenter Assistant'
  ClientHeight = 180
  ClientWidth = 460
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  PixelsPerInch = 96
  TextHeight = 13
  object StatusLabel: TLabel
    Left = 24
    Top = 28
    Width = 400
    Height = 32
    AutoSize = False
    Caption = 'The application skeleton is running. No automation services are enabled.'
    WordWrap = True
  end
  object CloseButton: TButton
    Left = 184
    Top = 112
    Width = 92
    Height = 29
    Caption = 'Close'
    TabOrder = 0
    OnClick = CloseButtonClick
  end
end

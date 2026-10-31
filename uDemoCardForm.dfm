object DemoCardForm: TDemoCardForm
  Left = 0
  Top = 0
  BorderIcons = []
  BorderStyle = bsNone
  Caption = 'DemoCardForm'
  ClientHeight = 206
  ClientWidth = 324
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poDesigned
  OnCreate = FormCreate
  TextHeight = 15
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 324
    Height = 206
    Align = alClient
    TabOrder = 0
    OnMouseLeave = Panel1MouseLeave
    OnMouseMove = Panel1MouseMove
    ExplicitTop = 8
    object lblTitle: TLabel
      Left = 25
      Top = 16
      Width = 57
      Height = 25
      Caption = 'lblTitle'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -19
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object shpLine: TShape
      Left = 24
      Top = 47
      Width = 281
      Height = 1
    end
    object lblPptx: TLabel
      Left = 24
      Top = 63
      Width = 58
      Height = 25
      Caption = 'lblPptx'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -19
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object lblScenes: TLabel
      Left = 24
      Top = 94
      Width = 79
      Height = 25
      Caption = 'lblScenes'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -19
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object lblModified: TLabel
      Left = 24
      Top = 125
      Width = 97
      Height = 25
      Caption = 'lblModified'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -19
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object btnOpen: TButton
      Left = 25
      Top = 168
      Width = 75
      Height = 25
      Caption = 'btnOpen'
      TabOrder = 0
      OnClick = btnOpenClick
    end
  end
end

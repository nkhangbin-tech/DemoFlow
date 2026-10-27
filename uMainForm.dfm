object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'Presenter Assistant'
  ClientHeight = 270
  ClientWidth = 620
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
  OnClose = FormClose
  OnCreate = FormCreate
  OnResize = FormResize
  object StatusLabel: TLabel
    Left = 24
    Top = 28
    Width = 560
    Height = 32
    AutoSize = False
    Caption = 'Application status: starting'
    WordWrap = True
  end
  object LoggerStatusLabel: TLabel
    Left = 24
    Top = 68
    Width = 560
    Height = 17
    Caption = 'Logger: not initialized'
  end
  object ConfigurationStatusLabel: TLabel
    Left = 24
    Top = 92
    Width = 560
    Height = 17
    Caption = 'Configuration: not loaded'
  end
  object SafeModeStatusLabel: TLabel
    Left = 24
    Top = 116
    Width = 560
    Height = 17
    Caption = 'Safe mode: evaluating'
  end
  object ConfigurationPathLabel: TLabel
    Left = 24
    Top = 140
    Width = 560
    Height = 32
    AutoSize = False
    Caption = 'Configuration path: resolving'
    WordWrap = True
  end
  object DiagnosticLabel: TLabel
    Left = 24
    Top = 180
    Width = 560
    Height = 32
    AutoSize = False
    Caption = 'Startup diagnostic: pending'
    WordWrap = True
  end
  object CloseButton: TButton
    Left = 264
    Top = 226
    Width = 92
    Height = 29
    Caption = 'Hide to tray'
    TabOrder = 0
    OnClick = CloseButtonClick
  end
  object TrayPopupMenu: TPopupMenu
    Left = 24
    Top = 224
    object ShowMenuItem: TMenuItem
      Caption = 'Show Presenter Assistant'
      OnClick = ShowMenuItemClick
    end
    object ReloadMenuItem: TMenuItem
      Caption = 'Reload Configuration'
      OnClick = ReloadMenuItemClick
    end
    object StatusMenuItem: TMenuItem
      Caption = 'Status: starting'
      Enabled = False
    end
    object ServicesMenuItem: TMenuItem
      Caption = 'Automation services are not implemented'
      Enabled = False
    end
    object TraySeparator: TMenuItem
      Caption = '-'
    end
    object ExitMenuItem: TMenuItem
      Caption = 'Exit'
      OnClick = ExitMenuItemClick
    end
  end
  object TrayIcon: TTrayIcon
    PopupMenu = TrayPopupMenu
    Visible = False
    OnDblClick = TrayIconDblClick
    Left = 72
    Top = 224
  end
end

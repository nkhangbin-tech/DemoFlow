object WelcomeForm: TWelcomeForm
  Caption = 'Presenter Assistant - Welcome'
  ClientWidth = 1120
  ClientHeight = 760
  Constraints.MinWidth = 1136
  Constraints.MinHeight = 799
  Position = poScreenCenter
  Font.Name = 'Segoe UI'
  Font.Height = -13
  PixelsPerInch = 96
  TextHeight = 17
  object grpCreate: TGroupBox
    Left = 20
    Top = 20
    Width = 532
    Height = 320
    Caption = 'Create New Project'
  object lblCreateHint: TLabel
    Left = 20
    Top = 32
    Width = 480
    Height = 24
    AutoSize = False
    Caption = 'Choose an open PowerPoint document window.'
  end
  object lblCreatePpt: TLabel
    Left = 20
    Top = 76
    Width = 480
    Height = 24
    AutoSize = False
    Caption = 'PowerPoint document window'
  end
  object cboCreatePowerPoint: TComboBox
    Left = 20
    Top = 108
    Width = 355
    Height = 25
    Style = csDropDownList
    ItemIndex = -1
    Anchors = [akLeft, akTop, akRight]
  end
  object btnCreateRefresh: TButton
    Left = 396
    Top = 104
    Width = 100
    Height = 32
    Caption = 'Refresh'
    Enabled = True
    OnClick = btnCreateRefreshClick
  end
  object lblCreateNoPowerPoint: TLabel
    Left = 20
    Top = 156
    Width = 480
    Height = 24
    AutoSize = False
    Caption = 'No PowerPoint document windows available.'
  end
  object lblCreateError: TLabel
    Left = 20
    Top = 196
    Width = 480
    Height = 24
    AutoSize = False
    Caption = ''
  end
  object btnCreate: TButton
    Left = 396
    Top = 264
    Width = 100
    Height = 32
    Caption = 'Create'
    Enabled = False
  end
  end
  object grpOpen: TGroupBox
    Left = 568
    Top = 20
    Width = 532
    Height = 320
    Caption = 'Open Existing Project'
    Anchors = [akLeft, akTop, akRight]
  object lblProjectFile: TLabel
    Left = 20
    Top = 32
    Width = 480
    Height = 24
    AutoSize = False
    Caption = 'Project file'
  end
  object edtProjectFile: TEdit
    Left = 20
    Top = 64
    Width = 355
    Height = 25
    ReadOnly = True
    Anchors = [akLeft, akTop, akRight]
  end
  object btnBrowse: TButton
    Left = 396
    Top = 60
    Width = 100
    Height = 32
    Caption = 'Browse...'
    Enabled = True
  end
  object lblOpenPpt: TLabel
    Left = 20
    Top = 112
    Width = 480
    Height = 24
    AutoSize = False
    Caption = 'Link to currently open PowerPoint document window'
  end
  object cboOpenPowerPoint: TComboBox
    Left = 20
    Top = 144
    Width = 355
    Height = 25
    Style = csDropDownList
    ItemIndex = -1
    Anchors = [akLeft, akTop, akRight]
  end
  object btnOpenRefresh: TButton
    Left = 396
    Top = 140
    Width = 100
    Height = 32
    Caption = 'Refresh'
    Enabled = True
  end
  object lblOpenNoPowerPoint: TLabel
    Left = 20
    Top = 184
    Width = 480
    Height = 24
    AutoSize = False
    Caption = 'No PowerPoint document windows available.'
  end
  object lblOpenError: TLabel
    Left = 20
    Top = 220
    Width = 480
    Height = 24
    AutoSize = False
    Caption = ''
  end
  object btnOpen: TButton
    Left = 396
    Top = 264
    Width = 100
    Height = 32
    Caption = 'Open'
    Enabled = False
  end
  end
  object grpRecent: TGroupBox
    Left = 20
    Top = 356
    Width = 1080
    Height = 280
    Caption = 'Recent Project'
    Anchors = [akLeft, akTop, akRight]
  object lblRecent0: TLabel
    Left = 20
    Top = 32
    Width = 480
    Height = 24
    AutoSize = False
    Caption = 'Project name: --'
  end
  object lblRecent1: TLabel
    Left = 20
    Top = 62
    Width = 480
    Height = 24
    AutoSize = False
    Caption = 'Project file: --'
  end
  object lblRecent2: TLabel
    Left = 20
    Top = 92
    Width = 480
    Height = 24
    AutoSize = False
    Caption = 'PowerPoint filename: --'
  end
  object lblRecent3: TLabel
    Left = 20
    Top = 122
    Width = 480
    Height = 24
    AutoSize = False
    Caption = 'Slide count: --'
  end
  object lblRecent4: TLabel
    Left = 20
    Top = 152
    Width = 480
    Height = 24
    AutoSize = False
    Caption = 'External scene count: --'
  end
  object lblRecent5: TLabel
    Left = 20
    Top = 182
    Width = 480
    Height = 24
    AutoSize = False
    Caption = 'Last worked: --'
  end
  object lblRecentRelink: TLabel
    Left = 20
    Top = 224
    Width = 880
    Height = 24
    Caption = 'Reopen requires PowerPoint relinking and a filename + slide count match.'
  end
  object btnReopen: TButton
    Left = 936
    Top = 220
    Width = 100
    Height = 32
    Caption = 'Reopen'
    Enabled = False
  end
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 696
    Width = 1120
    Height = 64
    Align = alBottom
    BevelOuter = bvNone
  object lblStatus: TLabel
    Left = 20
    Top = 22
    Width = 850
    Height = 24
    Caption = 'Select a project action to begin.'
  end
  object btnCancel: TButton
    Left = 996
    Top = 16
    Width = 104
    Height = 32
    Caption = 'Cancel'
    Cancel = True
    Anchors = [akTop, akRight]
  end
  end
end

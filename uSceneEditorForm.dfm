object frmSceneEditor: TfrmSceneEditor
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu, biMaximize]
  Caption = 'Presenter Assistant - Alpha VS1-A UI Draft v0.3'
  ClientHeight = 781
  ClientWidth = 1264
  Color = clBtnFace
  Constraints.MinHeight = 700
  Constraints.MinWidth = 1100
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  TextHeight = 17
  object pnlHeader: TPanel
    Left = 0
    Top = 0
    Width = 1264
    Height = 96
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    ExplicitWidth = 1258
    object lblDemoTitle: TLabel
      Left = 12
      Top = 20
      Width = 152
      Height = 17
      Caption = 'Demo: Presenter Assistant'
    end
    object lblModifiedStatus: TLabel
      Left = 650
      Top = 20
      Width = 126
      Height = 17
      Caption = 'Modified (UI preview)'
    end
    object btnBackToWelcome: TButton
      Left = 14
      Top = 43
      Width = 150
      Height = 30
      Caption = 'Back to Welcome'
      TabOrder = 0
      Visible = False
    end
    object btnSave: TButton
      Left = 964
      Top = 15
      Width = 110
      Height = 30
      Caption = 'Save'
      TabOrder = 1
    end
    object btnReadiness: TButton
      Left = 1140
      Top = 12
      Width = 110
      Height = 30
      Caption = 'Readiness'
      TabOrder = 2
    end
    object btnStartLive: TButton
      Left = 252
      Top = 43
      Width = 110
      Height = 30
      Caption = 'Start Live'
      TabOrder = 3
      Visible = False
    end
  end
  object pnlBody: TPanel
    Left = 0
    Top = 96
    Width = 1264
    Height = 663
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    ExplicitWidth = 1258
    ExplicitHeight = 646
    object splSceneInspector: TSplitter
      Left = 420
      Top = 0
      Width = 6
      Height = 663
      MinSize = 380
      ExplicitHeight = 650
    end
    object pnlSceneList: TPanel
      Left = 0
      Top = 0
      Width = 420
      Height = 663
      Align = alLeft
      BevelOuter = bvNone
      Constraints.MinWidth = 380
      TabOrder = 0
      ExplicitHeight = 646
      object pnlSceneActions: TPanel
        Left = 0
        Top = 563
        Width = 420
        Height = 100
        Align = alBottom
        BevelOuter = bvNone
        TabOrder = 0
        ExplicitTop = 546
        object btnAddNewScene: TButton
          Left = 12
          Top = 8
          Width = 180
          Height = 30
          Caption = 'Add New Scene'
          PopupMenu = pmAddScene
          TabOrder = 0
        end
        object btnRemoveScene: TButton
          Left = 12
          Top = 56
          Width = 110
          Height = 30
          Caption = 'Remove'
          TabOrder = 1
        end
        object btnMoveUp: TButton
          Left = 132
          Top = 56
          Width = 110
          Height = 30
          Caption = 'Move Up'
          TabOrder = 2
        end
        object btnMoveDown: TButton
          Left = 252
          Top = 56
          Width = 110
          Height = 30
          Caption = 'Move Down'
          TabOrder = 3
        end
      end
      object vstScenes: TVirtualStringTree
        Left = 0
        Top = 0
        Width = 420
        Height = 563
        Align = alClient
        DefaultNodeHeight = 21
        Header.AutoSizeIndex = 0
        Header.Height = 21
        Header.Options = [hoAutoResize, hoColumnResize, hoVisible]
        Header.Style = hsFlatButtons
        TabOrder = 1
        Touch.InteractiveGestures = [igPan, igPressAndTap]
        Touch.InteractiveGestureOptions = [igoPanSingleFingerHorizontal, igoPanSingleFingerVertical, igoPanInertia, igoPanGutter, igoParentPassthrough]
        ExplicitTop = 2
        Columns = <
          item
            Position = 0
            Text = 'Scenes'
            Width = 336
          end
          item
            Alignment = taCenter
            BiDiMode = bdRightToLeft
            CaptionAlignment = taCenter
            MaxWidth = 100
            MinWidth = 64
            Options = [coAllowClick, coDraggable, coEnabled, coParentColor, coResizable, coShowDropMark, coVisible, coAllowFocus, coUseCaptionAlignment, coEditable, coStyleColor]
            Position = 1
            Text = 'vol'
            Width = 80
          end>
      end
    end
    object pnlInspector: TPanel
      Left = 426
      Top = 0
      Width = 838
      Height = 663
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 1
      ExplicitWidth = 832
      ExplicitHeight = 646
      object pnlSceneIdentity: TPanel
        Left = 0
        Top = 0
        Width = 838
        Height = 86
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 0
        ExplicitWidth = 832
        object lblSceneDetails: TLabel
          Left = 20
          Top = 6
          Width = 77
          Height = 17
          Caption = 'Scene Details'
        end
        object lblSceneId: TLabel
          Left = 20
          Top = 32
          Width = 62
          Height = 17
          Caption = 'Scene ID: -'
        end
        object lblSceneKind: TLabel
          Left = 20
          Top = 58
          Width = 76
          Height = 17
          Caption = 'Scene Kind: -'
        end
      end
      object pnlCommonProperties: TPanel
        Left = 0
        Top = 543
        Width = 838
        Height = 120
        Align = alBottom
        BevelOuter = bvNone
        TabOrder = 1
        ExplicitTop = 526
        ExplicitWidth = 832
        DesignSize = (
          838
          120)
        object lblCommonProperties: TLabel
          Left = 20
          Top = 8
          Width = 117
          Height = 17
          Caption = 'Common Properties'
        end
        object lblExplicitVolume: TLabel
          Left = 20
          Top = 34
          Width = 110
          Height = 17
          Caption = 'Explicit Volume (%)'
        end
        object lblExplicitVolumeError: TLabel
          Left = 20
          Top = 102
          Width = 113
          Height = 17
          Caption = 'Validation message'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clRed
          Font.Height = -13
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
          Visible = False
        end
        object trkExplicitVolume: TTrackBar
          Left = 16
          Top = 62
          Width = 518
          Height = 40
          Anchors = [akLeft, akTop, akRight]
          Enabled = False
          Max = 100
          Frequency = 10
          TabOrder = 0
          ExplicitWidth = 512
        end
        object edtExplicitVolume: TEdit
          Left = 568
          Top = 58
          Width = 70
          Height = 25
          Anchors = [akTop, akRight]
          Enabled = False
          TabOrder = 1
          ExplicitLeft = 562
        end
      end
      object crpSceneDetails: TCardPanel
        Left = 0
        Top = 86
        Width = 838
        Height = 457
        Align = alClient
        ActiveCard = crdEmpty
        BevelOuter = bvNone
        TabOrder = 2
        ExplicitWidth = 832
        ExplicitHeight = 440
        object crdEmpty: TCard
          Left = 0
          Top = 0
          Width = 838
          Height = 457
          CardIndex = 0
          TabOrder = 0
          ExplicitWidth = 832
          ExplicitHeight = 440
          object lblEmpty: TLabel
            Left = 20
            Top = 24
            Width = 213
            Height = 17
            Caption = 'Select a Scene to view its properties.'
          end
        end
        object crdPowerPoint: TCard
          Left = 0
          Top = 0
          Width = 838
          Height = 457
          CardIndex = 1
          TabOrder = 1
          DesignSize = (
            838
            457)
          object lblPowerPointTarget: TLabel
            Left = 20
            Top = 24
            Width = 163
            Height = 17
            Caption = 'PowerPoint target reference'
          end
          object lblPowerPointTargetError: TLabel
            Left = 20
            Top = 82
            Width = 113
            Height = 17
            Caption = 'Validation message'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clRed
            Font.Height = -13
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            Visible = False
          end
          object lblPowerPointLogicalSlide: TLabel
            Left = 20
            Top = 116
            Width = 134
            Height = 17
            Caption = 'PowerPointLogicalSlide'
          end
          object lblPowerPointLogicalSlideError: TLabel
            Left = 20
            Top = 174
            Width = 113
            Height = 17
            Caption = 'Validation message'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clRed
            Font.Height = -13
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            Visible = False
          end
          object cmbPowerPointTarget: TComboBox
            Left = 20
            Top = 50
            Width = 538
            Height = 25
            Style = csDropDownList
            Anchors = [akLeft, akTop, akRight]
            TabOrder = 0
          end
          object edtPowerPointLogicalSlide: TEdit
            Left = 20
            Top = 142
            Width = 160
            Height = 25
            TabOrder = 1
          end
        end
        object crdBrowser: TCard
          Left = 0
          Top = 0
          Width = 838
          Height = 457
          CardIndex = 2
          TabOrder = 2
          DesignSize = (
            838
            457)
          object lblBrowserTarget: TLabel
            Left = 20
            Top = 24
            Width = 145
            Height = 17
            Caption = 'Browser target reference'
          end
          object lblBrowserTargetError: TLabel
            Left = 20
            Top = 82
            Width = 113
            Height = 17
            Caption = 'Validation message'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clRed
            Font.Height = -13
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            Visible = False
          end
          object cmbBrowserTarget: TComboBox
            Left = 20
            Top = 50
            Width = 538
            Height = 25
            Style = csDropDownList
            Anchors = [akLeft, akTop, akRight]
            TabOrder = 0
          end
        end
        object crdExternalApp: TCard
          Left = 0
          Top = 0
          Width = 838
          Height = 457
          CardIndex = 3
          TabOrder = 3
          DesignSize = (
            838
            457)
          object lblExternalAppTarget: TLabel
            Left = 20
            Top = 24
            Width = 168
            Height = 17
            Caption = 'ExternalApp target reference'
          end
          object lblExternalAppTargetError: TLabel
            Left = 20
            Top = 82
            Width = 113
            Height = 17
            Caption = 'Validation message'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clRed
            Font.Height = -13
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            Visible = False
          end
          object cmbExternalAppTarget: TComboBox
            Left = 20
            Top = 50
            Width = 538
            Height = 25
            Style = csDropDownList
            Anchors = [akLeft, akTop, akRight]
            TabOrder = 0
          end
        end
      end
    end
  end
  object sbSceneEditor: TStatusBar
    Left = 0
    Top = 759
    Width = 1264
    Height = 22
    Panels = <>
    SimplePanel = True
    SimpleText = 'Alpha VS1-A | UI Draft v0.3 | No scene selected'
    ExplicitTop = 742
    ExplicitWidth = 1258
  end
  object pmAddScene: TPopupMenu
    Left = 64
    Top = 160
    object miPowerPoint: TMenuItem
      Caption = 'PowerPoint'
    end
    object miBrowser: TMenuItem
      Caption = 'Browser'
    end
    object miExternalApp: TMenuItem
      Caption = 'External App'
    end
  end
end

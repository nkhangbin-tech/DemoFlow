object frmSceneEditor: TfrmSceneEditor
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu, biMaximize]
  Caption = 'Scene List Editor - Alpha VS1-A (UI Draft v0.2)'
  ClientHeight = 820
  ClientWidth = 1280
  Color = clBtnFace
  Constraints.MinHeight = 600
  Constraints.MinWidth = 1040
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
    Width = 1280
    Height = 76
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    ExplicitWidth = 1274
    DesignSize = (
      1280
      76)
    object lblDemoTitle: TLabel
      Left = 182
      Top = 20
      Width = 261
      Height = 25
      Caption = 'Scene List Editor  /  Demo Title'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -18
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object lblProjectState: TLabel
      Left = 182
      Top = 51
      Width = 78
      Height = 17
      Caption = 'Not modified'
    end
    object btnSave: TButton
      Left = 810
      Top = 17
      Width = 102
      Height = 36
      Anchors = [akTop, akRight]
      Caption = 'Save'
      TabOrder = 3
      ExplicitLeft = 804
    end
    object btnReadiness: TButton
      Left = 922
      Top = 17
      Width = 132
      Height = 36
      Anchors = [akTop, akRight]
      Caption = 'Readiness'
      TabOrder = 1
      ExplicitLeft = 916
    end
    object btnStartLive: TButton
      Left = 1062
      Top = 17
      Width = 142
      Height = 37
      Anchors = [akTop, akRight]
      Caption = 'Start Live'
      Enabled = False
      TabOrder = 2
      ExplicitLeft = 1056
    end
    object btnBackToWelcome: TButton
      Left = 18
      Top = 19
      Width = 150
      Height = 36
      Caption = 'Back to Welcome'
      TabOrder = 0
    end
  end
  object pnlStatus: TPanel
    Left = 0
    Top = 792
    Width = 1280
    Height = 28
    Align = alBottom
    BevelOuter = bvLowered
    TabOrder = 1
    ExplicitTop = 775
    ExplicitWidth = 1274
    object lblStatus: TLabel
      Left = 12
      Top = 6
      Width = 356
      Height = 17
      Caption = 'Alpha VS1-A UI layout only - no scene data or event handlers'
    end
  end
  object pnlEditorBody: TPanel
    Left = 0
    Top = 76
    Width = 1280
    Height = 716
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 2
    ExplicitWidth = 1274
    ExplicitHeight = 699
    object splEditor: TSplitter
      Left = 430
      Top = 0
      Width = 6
      Height = 716
      MinSize = 280
    end
    object pnlSceneList: TPanel
      Left = 0
      Top = 0
      Width = 430
      Height = 716
      Align = alLeft
      BevelOuter = bvNone
      TabOrder = 0
      ExplicitHeight = 699
      object pnlSceneListHeader: TPanel
        Left = 0
        Top = 0
        Width = 430
        Height = 48
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 0
        DesignSize = (
          430
          48)
        object lblSceneList: TLabel
          Left = 16
          Top = 13
          Width = 75
          Height = 21
          Caption = 'Scene List'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -16
          Font.Name = 'Segoe UI'
          Font.Style = [fsBold]
          ParentFont = False
        end
        object lblSceneCount: TLabel
          Left = 350
          Top = 16
          Width = 51
          Height = 17
          Anchors = [akTop, akRight]
          Caption = '0 Scenes'
        end
      end
      object pnlSceneActions: TPanel
        Left = 0
        Top = 604
        Width = 430
        Height = 112
        Align = alBottom
        BevelOuter = bvNone
        TabOrder = 1
        ExplicitTop = 587
        DesignSize = (
          430
          112)
        object btnAddScene: TButton
          Left = 12
          Top = 8
          Width = 406
          Height = 42
          Anchors = [akLeft, akTop, akRight]
          Caption = '+ Add New Scene  (v)'
          TabOrder = 0
        end
        object btnRemoveScene: TButton
          Left = 12
          Top = 61
          Width = 104
          Height = 36
          Caption = 'Remove'
          Enabled = False
          TabOrder = 1
        end
        object btnMoveSceneUp: TButton
          Left = 128
          Top = 61
          Width = 104
          Height = 36
          Caption = 'Move Up'
          Enabled = False
          TabOrder = 2
        end
        object btnMoveSceneDown: TButton
          Left = 314
          Top = 61
          Width = 104
          Height = 36
          Anchors = [akTop, akRight]
          Caption = 'Move Down'
          Enabled = False
          TabOrder = 3
        end
      end
      object vstScenes: TVirtualStringTree
        Left = 0
        Top = 48
        Width = 430
        Height = 556
        Align = alClient
        DefaultNodeHeight = 21
        Header.AutoSizeIndex = 0
        Header.Height = 21
        Header.Options = [hoColumnResize, hoDrag, hoVisible]
        TabOrder = 2
        Touch.InteractiveGestures = [igPan, igPressAndTap]
        Touch.InteractiveGestureOptions = [igoPanSingleFingerHorizontal, igoPanSingleFingerVertical, igoPanInertia, igoPanGutter, igoParentPassthrough]
        Columns = <
          item
            Position = 0
            Text = 'Scenes'
            Width = 390
          end>
      end
    end
    object pnlInspector: TPanel
      Left = 436
      Top = 0
      Width = 844
      Height = 716
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 1
      ExplicitWidth = 838
      ExplicitHeight = 699
      object pnlInspectorHeader: TPanel
        Left = 0
        Top = 0
        Width = 844
        Height = 94
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 0
        ExplicitWidth = 838
        object lblSceneDetails: TLabel
          Left = 20
          Top = 12
          Width = 113
          Height = 25
          Caption = 'Scene Details'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -18
          Font.Name = 'Segoe UI'
          Font.Style = [fsBold]
          ParentFont = False
        end
        object lblSceneId: TLabel
          Left = 20
          Top = 48
          Width = 62
          Height = 17
          Caption = 'Scene ID: -'
        end
        object lblSceneKind: TLabel
          Left = 180
          Top = 48
          Width = 77
          Height = 17
          Caption = 'Scene Type: -'
        end
      end
      object pnlCommonProperties: TPanel
        Left = 0
        Top = 584
        Width = 844
        Height = 132
        Align = alBottom
        BevelOuter = bvNone
        TabOrder = 1
        ExplicitTop = 567
        ExplicitWidth = 838
        DesignSize = (
          844
          132)
        object lblCommonProperties: TLabel
          Left = 20
          Top = 12
          Width = 152
          Height = 21
          Caption = 'Common Properties'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -16
          Font.Name = 'Segoe UI'
          Font.Style = [fsBold]
          ParentFont = False
        end
        object lblExplicitVolume: TLabel
          Left = 20
          Top = 46
          Width = 209
          Height = 17
          Caption = 'Windows Master Volume (%)  0-100'
        end
        object lblExplicitVolumeError: TLabel
          Left = 20
          Top = 115
          Width = 174
          Height = 17
          Caption = 'Enter a volume from 0 to 100.'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clRed
          Font.Height = -13
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
          Visible = False
        end
        object trkExplicitVolume: TTrackBar
          Left = 14
          Top = 72
          Width = 705
          Height = 42
          Anchors = [akLeft, akTop, akRight]
          Max = 100
          Frequency = 10
          Position = 50
          TabOrder = 0
          ExplicitWidth = 699
        end
        object edtExplicitVolume: TEdit
          Left = 744
          Top = 69
          Width = 65
          Height = 25
          Anchors = [akTop, akRight]
          NumbersOnly = True
          TabOrder = 1
          Text = '50'
          ExplicitLeft = 738
        end
      end
      object crpSceneDetails: TCardPanel
        Left = 0
        Top = 94
        Width = 844
        Height = 490
        Align = alClient
        ActiveCard = crdEmpty
        BevelOuter = bvNone
        TabOrder = 2
        ExplicitWidth = 838
        ExplicitHeight = 473
        object crdEmpty: TCard
          Left = 0
          Top = 0
          Width = 844
          Height = 490
          Caption = 'Empty'
          CardIndex = 0
          TabOrder = 0
          ExplicitWidth = 838
          ExplicitHeight = 473
          object lblSelectSceneHint: TLabel
            Left = 24
            Top = 28
            Width = 107
            Height = 17
            Caption = 'No scene selected'
          end
          object lblEmptyDescription: TLabel
            Left = 26
            Top = 63
            Width = 278
            Height = 17
            Caption = 'Select a scene from the list or add a new scene.'
          end
        end
        object crdPowerPoint: TCard
          Left = 0
          Top = 0
          Width = 844
          Height = 490
          Caption = 'PowerPoint'
          CardIndex = 1
          TabOrder = 1
          object lblPowerPointHeading: TLabel
            Left = 24
            Top = 24
            Width = 138
            Height = 21
            Caption = 'PowerPoint Scene'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -16
            Font.Name = 'Segoe UI'
            Font.Style = [fsBold]
            ParentFont = False
          end
          object lblLogicalSlide: TLabel
            Left = 24
            Top = 74
            Width = 142
            Height = 17
            Caption = 'PowerPoint Logical Slide'
          end
          object lblLogicalSlideError: TLabel
            Left = 24
            Top = 135
            Width = 148
            Height = 17
            Caption = 'Enter a valid logical slide.'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clRed
            Font.Height = -13
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            Visible = False
          end
          object edtLogicalSlide: TEdit
            Left = 24
            Top = 99
            Width = 190
            Height = 25
            NumbersOnly = True
            TabOrder = 0
          end
        end
        object crdBrowser: TCard
          Left = 0
          Top = 0
          Width = 844
          Height = 490
          Caption = 'Browser'
          CardIndex = 2
          TabOrder = 2
          DesignSize = (
            844
            490)
          object lblBrowserHeading: TLabel
            Left = 24
            Top = 24
            Width = 110
            Height = 21
            Caption = 'Browser Scene'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -16
            Font.Name = 'Segoe UI'
            Font.Style = [fsBold]
            ParentFont = False
          end
          object lblBrowserTarget: TLabel
            Left = 24
            Top = 74
            Width = 150
            Height = 17
            Caption = 'Browser Target Reference'
          end
          object lblBrowserTargetError: TLabel
            Left = 24
            Top = 135
            Width = 180
            Height = 17
            Caption = 'Please select a Browser Target.'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clRed
            Font.Height = -13
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            Visible = False
          end
          object cboBrowserTarget: TComboBox
            Left = 24
            Top = 99
            Width = 590
            Height = 25
            Style = csDropDownList
            Anchors = [akLeft, akTop, akRight]
            TabOrder = 0
          end
        end
        object crdExternalApp: TCard
          Left = 0
          Top = 0
          Width = 844
          Height = 490
          Caption = 'External App'
          CardIndex = 3
          TabOrder = 3
          DesignSize = (
            844
            490)
          object lblExternalAppHeading: TLabel
            Left = 24
            Top = 24
            Width = 147
            Height = 21
            Caption = 'External App Scene'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -16
            Font.Name = 'Segoe UI'
            Font.Style = [fsBold]
            ParentFont = False
          end
          object lblExternalAppTarget: TLabel
            Left = 24
            Top = 74
            Width = 177
            Height = 17
            Caption = 'External App Target Reference'
          end
          object lblExternalAppTargetError: TLabel
            Left = 24
            Top = 135
            Width = 214
            Height = 17
            Caption = 'Please select an External App Target.'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clRed
            Font.Height = -13
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            Visible = False
          end
          object cboExternalAppTarget: TComboBox
            Left = 24
            Top = 99
            Width = 590
            Height = 25
            Style = csDropDownList
            Anchors = [akLeft, akTop, akRight]
            TabOrder = 0
          end
        end
      end
    end
  end
  object pmAddScene: TPopupMenu
    Left = 32
    Top = 120
    object miAddPowerPointScene: TMenuItem
      Caption = 'PowerPoint Scene'
    end
    object miAddBrowserScene: TMenuItem
      Caption = 'Browser Scene'
    end
    object miAddExternalAppScene: TMenuItem
      Caption = 'External App Scene'
    end
  end
end

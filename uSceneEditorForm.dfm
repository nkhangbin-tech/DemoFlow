object frmSceneEditor: TfrmSceneEditor
  Left = 0
  Top = 0
  Caption = 'Scene List Editor - Alpha VS1-A (Layout Draft)'
  ClientHeight = 804
  ClientWidth = 1165
  Color = clBtnFace
  Constraints.MinHeight = 540
  Constraints.MinWidth = 840
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
    Width = 1165
    Height = 76
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    ExplicitWidth = 1159
    DesignSize = (
      1165
      76)
    object lblDemoTitle: TLabel
      Left = 290
      Top = 30
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
    object btnSave: TButton
      Left = 701
      Top = 17
      Width = 102
      Height = 36
      Anchors = [akTop, akRight]
      Caption = 'Save'
      TabOrder = 3
      ExplicitLeft = 695
    end
    object btnReadiness: TButton
      Left = 813
      Top = 17
      Width = 132
      Height = 36
      Anchors = [akTop, akRight]
      Caption = 'Readiness'
      TabOrder = 1
      ExplicitLeft = 807
    end
    object btnStartLive: TButton
      Left = 953
      Top = 17
      Width = 142
      Height = 37
      Anchors = [akTop, akRight]
      Caption = 'Start Live'
      Enabled = False
      TabOrder = 2
      ExplicitLeft = 947
    end
    object btnBackToWelcome: TButton
      Left = 18
      Top = 19
      Width = 130
      Height = 36
      Caption = 'Back'
      TabOrder = 0
    end
  end
  object pnlStatus: TPanel
    Left = 0
    Top = 776
    Width = 1165
    Height = 28
    Align = alBottom
    BevelOuter = bvLowered
    TabOrder = 1
    ExplicitTop = 759
    ExplicitWidth = 1159
    object lblStatus: TLabel
      Left = 12
      Top = 6
      Width = 364
      Height = 17
      Caption = 'Alpha VS1-A layout draft - no scene data or actions connected'
    end
  end
  object pnlEditorBody: TPanel
    Left = 0
    Top = 76
    Width = 1165
    Height = 700
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 2
    ExplicitWidth = 1159
    ExplicitHeight = 683
    object splEditor: TSplitter
      Left = 430
      Top = 0
      Width = 6
      Height = 700
      MinSize = 280
      ExplicitHeight = 656
    end
    object pnlSceneList: TPanel
      Left = 0
      Top = 0
      Width = 430
      Height = 700
      Align = alLeft
      BevelOuter = bvNone
      TabOrder = 0
      ExplicitHeight = 683
      object pnlSceneListHeader: TPanel
        Left = 0
        Top = 0
        Width = 430
        Height = 48
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 0
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
      end
      object pnlSceneActions: TPanel
        Left = 0
        Top = 636
        Width = 430
        Height = 64
        Align = alBottom
        BevelOuter = bvNone
        TabOrder = 1
        ExplicitTop = 619
        DesignSize = (
          430
          64)
        object btnAddScene: TButton
          Left = 12
          Top = 13
          Width = 146
          Height = 38
          Caption = '+ Add New Scene'
          TabOrder = 0
        end
        object btnRemoveScene: TButton
          Left = 169
          Top = 13
          Width = 88
          Height = 38
          Caption = 'Remove'
          Enabled = False
          TabOrder = 1
        end
        object btnMoveSceneUp: TButton
          Left = 270
          Top = 13
          Width = 65
          Height = 38
          Anchors = [akTop, akRight]
          Caption = 'Up'
          Enabled = False
          TabOrder = 2
        end
        object btnMoveSceneDown: TButton
          Left = 347
          Top = 13
          Width = 70
          Height = 38
          Anchors = [akTop, akRight]
          Caption = 'Down'
          Enabled = False
          TabOrder = 3
        end
      end
      object vstScenes: TVirtualStringTree
        Left = 0
        Top = 48
        Width = 430
        Height = 588
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
      Width = 729
      Height = 700
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 1
      ExplicitWidth = 723
      ExplicitHeight = 683
      object pnlInspectorHeader: TPanel
        Left = 0
        Top = 0
        Width = 729
        Height = 94
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 0
        ExplicitWidth = 723
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
        Top = 568
        Width = 729
        Height = 132
        Align = alBottom
        BevelOuter = bvNone
        TabOrder = 1
        ExplicitTop = 551
        ExplicitWidth = 723
        DesignSize = (
          729
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
          Width = 236
          Height = 17
          Caption = 'Explicit Volume (Windows master, 0-100)'
        end
        object trkExplicitVolume: TTrackBar
          Left = 14
          Top = 72
          Width = 505
          Height = 42
          Anchors = [akLeft, akTop, akRight]
          Max = 100
          Frequency = 10
          Position = 50
          TabOrder = 0
          ExplicitWidth = 499
        end
        object edtExplicitVolume: TEdit
          Left = 542
          Top = 77
          Width = 65
          Height = 25
          Anchors = [akTop, akRight]
          NumbersOnly = True
          TabOrder = 1
          Text = '50'
          ExplicitLeft = 536
        end
      end
      object crpSceneDetails: TCardPanel
        Left = 0
        Top = 94
        Width = 729
        Height = 474
        Align = alClient
        ActiveCard = crdEmpty
        BevelOuter = bvNone
        TabOrder = 2
        ExplicitWidth = 723
        ExplicitHeight = 457
        object crdEmpty: TCard
          Left = 0
          Top = 0
          Width = 729
          Height = 474
          Caption = 'Empty'
          CardIndex = 0
          TabOrder = 0
          ExplicitWidth = 723
          ExplicitHeight = 457
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
          Width = 729
          Height = 474
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
          object edtLogicalSlide: TEdit
            Left = 24
            Top = 99
            Width = 190
            Height = 25
            TabOrder = 0
          end
        end
        object crdBrowser: TCard
          Left = 0
          Top = 0
          Width = 729
          Height = 474
          Caption = 'Browser'
          CardIndex = 2
          TabOrder = 2
          DesignSize = (
            729
            474)
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
          object edtBrowserTarget: TComboBox
            Left = 24
            Top = 99
            Width = 445
            Height = 25
            Style = csDropDownList
            Anchors = [akLeft, akTop, akRight]
            TabOrder = 0
          end
        end
        object crdExternalApp: TCard
          Left = 0
          Top = 0
          Width = 729
          Height = 474
          Caption = 'External App'
          CardIndex = 3
          TabOrder = 3
          DesignSize = (
            729
            474)
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
          object edtExternalAppTarget: TComboBox
            Left = 24
            Top = 99
            Width = 445
            Height = 25
            Style = csDropDownList
            Anchors = [akLeft, akTop, akRight]
            TabOrder = 0
          end
        end
      end
    end
  end
end

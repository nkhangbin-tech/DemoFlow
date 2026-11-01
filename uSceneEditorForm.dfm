object frmSceneEditor: TfrmSceneEditor
Left = 0
Top = 0
Width = 1280
Height = 820
BorderStyle = bsSizeable
BorderIcons = [biSystemMenu, biMaximize]
Caption = 'Presenter Assistant - Alpha VS1-A UI Draft v0.3'
Position = poScreenCenter
WindowState = wsNormal
Constraints.MinWidth = 1100
Constraints.MinHeight = 700
Font.Name = 'Segoe UI'
Font.Height = -13
PixelsPerInch = 96
object pnlHeader: TPanel
Left = 0
Top = 0
Width = 1264
Height = 96
Align = alTop
BevelOuter = bvNone
object btnBackToWelcome: TButton
Left = 16
Top = 12
Width = 150
Height = 30
Caption = 'Back to Welcome'

end
object btnSave: TButton
Left = 180
Top = 12
Width = 110
Height = 30
Caption = 'Save'

end
object btnReadiness: TButton
Left = 300
Top = 12
Width = 110
Height = 30
Caption = 'Readiness'

end
object btnStartLive: TButton
Left = 420
Top = 12
Width = 110
Height = 30
Caption = 'Start Live'

end
object lblDemoTitle: TLabel
Left = 20
Top = 54
Width = 420
Height = 20
Caption = 'Demo: Presenter Assistant'

end
object lblModifiedStatus: TLabel
Left = 650
Top = 20
Width = 300
Height = 20
Caption = 'Modified (UI preview)'

end
end
object pnlBody: TPanel
Left = 0
Top = 96
Width = 1264
Height = 650
Align = alClient
BevelOuter = bvNone
object pnlSceneList: TPanel
Left = 0
Top = 0
Width = 420
Height = 650
Align = alLeft
BevelOuter = bvNone
Constraints.MinWidth = 380
object pnlSceneActions: TPanel
Left = 0
Top = 550
Width = 420
Height = 100
Align = alBottom
BevelOuter = bvNone
object btnAddNewScene: TButton
Left = 12
Top = 8
Width = 180
Height = 30
Caption = 'Add New Scene'
PopupMenu = pmAddScene

end
object btnRemoveScene: TButton
Left = 12
Top = 56
Width = 110
Height = 30
Caption = 'Remove'

end
object btnMoveUp: TButton
Left = 132
Top = 56
Width = 110
Height = 30
Caption = 'Move Up'

end
object btnMoveDown: TButton
Left = 252
Top = 56
Width = 110
Height = 30
Caption = 'Move Down'

end
end
object vstScenes: TVirtualStringTree
Left = 0
Top = 0
Width = 420
Height = 550
Align = alClient
Header.AutoSizeIndex = 0
Header.MainColumn = 0
Header.Options = [hoAutoResize, hoColumnResize, hoVisible]
Columns = <
 item
 Position = 0
 Width = 420
 Text = 'Scenes'
 end>

end
end
object splSceneInspector: TSplitter
Left = 420
Top = 0
Width = 6
Height = 650
MinSize = 380

end
object pnlInspector: TPanel
Left = 426
Top = 0
Width = 838
Height = 650
Align = alClient
BevelOuter = bvNone
object pnlSceneIdentity: TPanel
Left = 0
Top = 0
Width = 800
Height = 86
Align = alTop
BevelOuter = bvNone
object lblSceneDetails: TLabel
Left = 20
Top = 6
Width = 420
Height = 20
Caption = 'Scene Details'

end
object lblSceneId: TLabel
Left = 20
Top = 32
Width = 420
Height = 20
Caption = 'Scene ID: -'

end
object lblSceneKind: TLabel
Left = 20
Top = 58
Width = 420
Height = 20
Caption = 'Scene Kind: -'

end
end
object pnlCommonProperties: TPanel
Left = 0
Top = 536
Width = 800
Height = 120
Align = alBottom
Visible = True
BevelOuter = bvNone
object lblCommonProperties: TLabel
Left = 20
Top = 8
Width = 420
Height = 20
Caption = 'Common Properties'

end
object lblExplicitVolume: TLabel
Left = 20
Top = 34
Width = 420
Height = 20
Caption = 'Explicit Volume (%)'

end
object trkExplicitVolume: TTrackBar
Left = 16
Top = 62
Width = 480
Height = 40
Enabled = False
Max = 100
Frequency = 10
Anchors = [akLeft, akTop, akRight]

end
object edtExplicitVolume: TEdit
Left = 530
Top = 58
Width = 70
Height = 25
Enabled = False
Text = ''
Anchors = [akTop, akRight]

end
object lblExplicitVolumeError: TLabel
Left = 20
Top = 102
Width = 450
Height = 18
Caption = 'Validation message'
Visible = False
Font.Color = clRed
ParentFont = False

end
end
object crpSceneDetails: TCardPanel
Left = 0
Top = 86
Width = 800
Height = 450
Align = alClient
ActiveCard = crdEmpty
BevelOuter = bvNone
object crdEmpty: TCard
Left = 0
Top = 0
Width = 800
Height = 450
CardIndex = 0
TabOrder = 0
object lblEmpty: TLabel
Left = 20
Top = 24
Width = 420
Height = 20
Caption = 'Select a Scene to view its properties.'

end
end
object crdPowerPoint: TCard
Left = 0
Top = 0
Width = 800
Height = 450
CardIndex = 1
TabOrder = 1
object lblPowerPointTarget: TLabel
Left = 20
Top = 24
Width = 420
Height = 20
Caption = 'PowerPoint target reference'

end
object cmbPowerPointTarget: TComboBox
Left = 20
Top = 50
Width = 500
Height = 25
Style = csDropDownList
Anchors = [akLeft, akTop, akRight]

end
object lblPowerPointTargetError: TLabel
Left = 20
Top = 82
Width = 450
Height = 18
Caption = 'Validation message'
Visible = False
Font.Color = clRed
ParentFont = False

end
object lblPowerPointLogicalSlide: TLabel
Left = 20
Top = 116
Width = 420
Height = 20
Caption = 'PowerPointLogicalSlide'

end
object edtPowerPointLogicalSlide: TEdit
Left = 20
Top = 142
Width = 160
Height = 25
Text = ''

end
object lblPowerPointLogicalSlideError: TLabel
Left = 20
Top = 174
Width = 450
Height = 18
Caption = 'Validation message'
Visible = False
Font.Color = clRed
ParentFont = False

end
end
object crdBrowser: TCard
Left = 0
Top = 0
Width = 800
Height = 450
CardIndex = 2
TabOrder = 2
object lblBrowserTarget: TLabel
Left = 20
Top = 24
Width = 420
Height = 20
Caption = 'Browser target reference'

end
object cmbBrowserTarget: TComboBox
Left = 20
Top = 50
Width = 500
Height = 25
Style = csDropDownList
Anchors = [akLeft, akTop, akRight]

end
object lblBrowserTargetError: TLabel
Left = 20
Top = 82
Width = 450
Height = 18
Caption = 'Validation message'
Visible = False
Font.Color = clRed
ParentFont = False

end
end
object crdExternalApp: TCard
Left = 0
Top = 0
Width = 800
Height = 450
CardIndex = 3
TabOrder = 3
object lblExternalAppTarget: TLabel
Left = 20
Top = 24
Width = 420
Height = 20
Caption = 'ExternalApp target reference'

end
object cmbExternalAppTarget: TComboBox
Left = 20
Top = 50
Width = 500
Height = 25
Style = csDropDownList
Anchors = [akLeft, akTop, akRight]

end
object lblExternalAppTargetError: TLabel
Left = 20
Top = 82
Width = 450
Height = 18
Caption = 'Validation message'
Visible = False
Font.Color = clRed
ParentFont = False

end
end
end
end
end
object sbSceneEditor: TStatusBar
Left = 0
Top = 746
Width = 1264
Height = 22
SimplePanel = True
SimpleText = 'Alpha VS1-A | UI Draft v0.3 | No scene selected'

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

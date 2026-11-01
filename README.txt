Alpha VS1-A Scene List Editor UI Draft v0.2

Source: User-supplied Delphi 12 .dfm (Pasted text.txt), edited into a layout-only prototype.
Approved layout choices represented here:
- Dedicated form TfrmSceneEditor; global variable frmSceneEditor declared.
- Windowed, nominal ClientWidth=1280 and ClientHeight=820 at design DPI; resizable/maximizable.
- Desktop authoring UI; no special TV mode.
- TVirtualStringTree single column (icon/order/name rendering is DEFERRED to logic).
- Scene Actions: Add New Scene on TOP row, Remove/Move Up/Move Down on BOTTOM row.
- Popup menu with PowerPoint/Browser/External App items. Menu wiring is DEFERRED.
- Inspector TCardPanel with four cards; Browser/External targets use csDropDownList TComboBox.
- Common Volume pinned to bottom; TTrackBar + TEdit with Edit raised slightly.
- Validation labels declared, invisible by default.
- No runtime actions, event handlers, persistence, or scene data.

WARNING: Hand-authored DFM/PAS, not Delphi-compiled/verified in this environment.
Open the .pas in Delphi 12 and use Design view; check Object Inspector/Structure and resolve any
version-specific DFM property differences. This draft does not modify your GitHub repository.

Deferred: Presenter Notes, Entry/Exit triggers, Landmark; scene CRUD/reorder business semantics,
scene name source, target catalog contract, menu opening, High DPI runtime behavior and
live/runtime orchestration. Do not treat placeholders as persisted scene properties.

Reference screenshot commit: 696f3da7a8d5a2b3e152441ea975800774da0709

PA Alpha VS1-A / Scene List Editor — Delphi Form Designer draft

Files:
- uSceneEditorForm.pas
- uSceneEditorForm.dfm

Scope:
- New standalone VCL Form (TfrmSceneEditor)
- Split Scene List / Detail Inspector
- TVirtualStringTree placeholder with no data/events
- Pinned Add New Scene action (no logic)
- TCardPanel with Empty, PowerPoint, Browser, External App cards
- Common Explicit Volume controls outside TCardPanel (0..100)
- No Domain, Persistence, Runtime, legacy configuration integration
- No Presenter Notes, Entry/Exit triggers, Landmark persistence assumptions

Requirements:
- Delphi version with Vcl.WinXPanels (TCardPanel/TCard)
- Virtual Treeview package installed (VirtualTrees / TVirtualStringTree)

Usage:
1. Place both .pas and .dfm in the same directory in your local workspace.
2. In Delphi IDE use File > Open and select uSceneEditorForm.pas.
3. Switch to Design view. Inspect panel alignment and active card.
4. Do NOT add this form to your main app's auto-create list yet.
5. No event handlers are connected. Buttons do not change data or scene kinds.

Note: This is a hand-authored draft, not compiled or opened in Delphi IDE here.
In case of version-specific .dfm property errors, use View as Text and remove/adjust
the reported property, then save again using your own Delphi IDE.
This draft intentionally does not alter existing repository files.

Reference:
review/pa-development at commit 696f3da7a8d5a2b3e152441ea975800774da0709
The screenshots at that commit were references, not a claim this draft is implemented.

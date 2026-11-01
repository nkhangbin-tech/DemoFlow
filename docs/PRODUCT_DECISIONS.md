# PA product decisions — WELCOME-VNEXT-M01

Authority: explicit PO Implementation Authorization in this session on 2026-11-01, together with the attached Final Bounded Welcome Integration Assignment. Its historical CODING NOT AUTHORIZED header was superseded by that explicit execution authorization. No additional product approvals are inferred here.

Source baseline: review/pa-development at 07741d12b3d340c46761b30cdb84532a69c092fa; uncommitted PO Scene Editor layout and VOL-M02 code are part of the inspected local integration baseline.

| Decision | Decision status | Approved scope |
| --- | --- | --- |
| Welcome Launcher vNext UI baseline | APPROVED | Existing Welcome PAS/DFM control layout, Anchors and placement; conventional VCL only. |
| WELCOME-VNEXT-M01 | AUTHORIZED FOR IMPLEMENTATION AND VERIFICATION | Welcome -> explicit presentation selection -> prepared candidate -> active application session -> Scene Editor. No Git operations authorized. |
| WELCOME-ARCH-01 | APPROVED | PA.SceneProject v3 adds project-level PowerPoint basename and slide count; existing Scene fields, revision and base-volume semantics retained. |
| WELCOME-COMPAT-01 | APPROVED | v1/v2 require explicit presentation selection and affirmative legacy binding confirmation; never represent that binding as a verified metadata match; explicit Save As v3 to a different safe destination. |
| PowerPoint-first creation | APPROVED | One PowerPoint Scene per logical slide; volume -1; base 50. Add New Scene offers Browser and External App only. Existing project Scenes are never regenerated on Open. |
| Recent Project | APPROVED | Exactly one independent latest successful saved/opened project entry; Reopen always routes through explicit PowerPoint relinking and the Open compatibility gate. |
| Active Project Session | APPROVED | Application-owned authoring document, source path/version, presentation binding, dirty/new/loaded states; candidate preparation before adoption; explicit confirmation before discarding edits. |
| Presentation Base Settings UI | DEFERRED | PO design required; existing backend base-volume interface retained. |
| Exact PowerPoint identity / slide synchronization / SlideID redesign | DEFERRED | This milestone uses document-window key plus revalidation; persisted matching is filename + slide count only. |
| Runtime Controller / Core Audio effects / VOL-M03 | OUT OF SCOPE | No implementation authorization in this assignment. |

Implementation/build/test evidence is recorded separately in WELCOME_VNEXT_M01_REPORT.md. APPROVED and AUTHORIZED above describe PO decisions, not LIVE VERIFIED or ACCEPTED status. No live acceptance has been supplied for this integration.

## WELCOME-UX-02 — Smart PowerPoint ComboBox Preselection

Status: PO AUTHORIZED — IMPLEMENT AND VERIFY (explicit PO assignment in this session). Supersedes the earlier empty/unselected entry policy after discovery, within the existing layout only. Preselection never confirms a binding or invokes Create/Open. Create selects the first eligible candidate, retaining a still-valid selection on Refresh. Open/Reopen v3 preselect only one uniquely matching actual presentation FileName; SlideCount remains an Open validation gate. A still-valid manual selection is retained on Refresh. Legacy v1/v2 never infer metadata matches and retain explicit binding confirmation. No schema, runtime, Core Audio or persistence-semantic changes authorized by this decision.

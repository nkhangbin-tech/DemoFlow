# Sequence Screen List and Configuration Schema

## Version and file policy

The configuration is a UTF-8 JSON object with required `schemaVersion` and
`sequence`. Version `1` is the only accepted version. There is no implicit
major/minor compatibility: any value other than integer `1` is rejected with
the path `/schemaVersion`.

Unknown properties are validation errors, not warnings. This prevents
misspelled safety-critical options from being silently ignored. Validation
returns path-specific errors and warnings; any error prevents activation.
Warnings do not prevent activation. A failed reload preserves the last valid
in-memory configuration and enters a visible diagnostic state.

Write replacement to a sibling temporary file, flush and close it, replace the
original atomically, and retain the last valid configuration if replacement or
validation fails. A malformed or absent first-run configuration starts in safe
mode with no active sequence and an actionable diagnostic; it does not invent
presentation values.

## Shape

Values below illustrate types and relationships, not a required scenario:

```json
{
  "schemaVersion": 1,
  "mode": "passThrough",
  "audio": {
    "enabled": true,
    "deltaMode": true,
    "contextMaxAgeMs": 3000,
    "rules": [
      {
        "id": "slide-3-browser-a",
        "priority": 20,
        "slide": { "kind": "slideIndex", "value": 3 },
        "foreground": { "kind": "browser", "profileId": "browser-a" },
        "levelPercent": 35
      },
      {
        "id": "any-slide-powerpoint",
        "priority": 1,
        "slide": { "kind": "wildcard" },
        "foreground": { "kind": "powerPointSlideshow" },
        "levelPercent": 60
      }
    ]
  },
  "browserProfiles": [
    { "id": "browser-a", "executable": "browser.exe",
      "className": "Chrome_WidgetWin_1", "titlePattern": ".*",
      "url": null, "launchUrl": false, "activate": true, "autoplay": false }
  ],
  "sequence": [
    {
      "id": "screen-3",
      "kind": "powerPoint",
      "slide": { "kind": "slideIndex", "value": 3 },
      "build": null,
      "next": "browser-a-screen",
      "previous": "buffer"
    },
    {
      "id": "buffer",
      "kind": "powerPoint",
      "slide": { "kind": "slideIndex", "value": 4 },
      "build": null,
      "next": "browser-a-screen",
      "previous": "screen-3"
    },
    {
      "id": "browser-a-screen",
      "kind": "browser",
      "browserProfile": "browser-a",
      "next": "screen-3",
      "previous": "screen-3",
      "browserReturn": "screen-3"
    }
  ]
}
```

## Browser profile fields

Browser profiles require stable `id`, `executable`, `className`, and non-empty
`titlePattern` values. `url` is optional; `launchUrl`, `activate`, and
`autoplay` are independent options. Version 1 treats `titlePattern` as an
opaque non-empty matching pattern because the schema does not define a regular
expression dialect. The configuration layer therefore validates presence and
type but does not compile or interpret the pattern.

## Sequence fields and matching

- `sequence[].id`: non-empty stable string, unique case-sensitively.
- `kind`: `powerPoint` or `browser`.
- A PowerPoint `slide` selector is required and is one of:
  - `{ "kind": "slideIndex", "value": positive integer }`
  - `{ "kind": "showPosition", "value": positive integer }`
  - `{ "kind": "wildcard" }`, only when the entry also has a disambiguating
    rule approved by validation.
- If an entry needs both identifiers, `slide` may be an object with
  `slideIndex` and `showPosition`. Both supplied values must match the same
  snapshot; a conflict is `Unreconciled`.
- A configured `build` is a non-negative logical step. It is not proof that
  PowerPoint exposes that animation state. A snapshot carries
  `ObservedBuildState = Verified(value)`, `Unavailable`, or `Ambiguous`.
  An entry requiring a build matches only `Verified` state; otherwise it is
  `Unreconciled`.
- Browser entries require an existing `browserProfile`.

Matching is explicit and deterministic. The adapter reports actual
`Slide.SlideIndex` and `SlideShowView.CurrentShowPosition` separately. The
sequence engine filters candidates by the configured selector, then by
verified build when required. Exactly one candidate produces a cursor. Zero or
multiple candidates produces `Unreconciled`; it never guesses.

## Transition semantics

- `next` is the sole target for Next.
- `previous` is the ordinary target for Previous.
- On a browser entry, `browserReturn`, when present, overrides `previous` for
  Previous. When absent, `previous` is used.
- `browserReturn` may point directly to a PowerPoint entry and thereby skip a
  buffer/blank entry. No slide number or destination is hard-coded.
- References must exist. Self-transitions are rejected unless an explicit
  future schema field authorizes them; version 1 authorizes none.
- A browser entry must define `next` and `previous` or `browserReturn` so both
  commands have deterministic behavior.

In pass-through mode, the cursor is advisory and advances only when actual
state uniquely matches an entry. In intercept-and-route mode, Next/Previous
requires a known current entry and a declared target. An unknown or stale
current state makes the action unavailable and preserves ordinary input.

While a browser is foreground, the controller retains the latest valid
PowerPoint context. `contextMaxAgeMs` defines its freshness limit. Before the
limit, it may select a volume rule but never authorizes PowerPoint routing;
after the limit it is stale and cannot select an entry-specific rule or route.
Returning to PowerPoint always triggers fresh reconciliation.

## Foreground and volume rules

Each rule has a stable `id`, integer `priority >= 0`, a slide selector, a
foreground selector, and `levelPercent` in `0..100`.

Foreground selectors are:

- `powerPointSlideshow`
- `powerPointEditor`
- `browser` with optional `profileId`
- `other`
- `unknown`
- `wildcard`

Slide selectors are actual slide index, active-slideshow position, logical
sequence entry (`{ "kind": "entryId", "value": "screen-3" }`), or wildcard.
An entry selector is allowed only when the PowerPoint context has uniquely
matched that entry. A browser foreground uses the last valid PowerPoint
context subject to the freshness rule above.

The matching order is deterministic:

1. Discard rules whose slide or foreground selector does not match.
2. Select the greatest explicit `priority`.
3. If tied, select the rule with the greatest specificity score:
   exact slide index/show position/entry = 3, wildcard slide = 0; exact browser
   profile = 2, foreground kind without profile = 1, wildcard = 0.
4. If priority and specificity still tie, validation rejects the configuration
   as ambiguous.

If no rule matches, PA preserves the current endpoint volume and emits a
diagnostic. Unknown PowerPoint or foreground state cannot match a specific
slide rule; only an explicit `unknown` rule may apply.

## Delta mode

Delta mode models distinct values:

- `NominalVolume`: selected rule's configured percentage.
- `DeltaOffset`: presenter adjustment in percentage points.
- `EffectiveTarget`: `Clamp(NominalVolume + DeltaOffset, 0, 100)`.
- `ObservedActual`: latest endpoint scalar converted to percentage.
- `ActiveRuleId` and `EndpointGeneration`.
- `LastCommandContext`: a unique context value supplied with PA's endpoint
  command.

On a confirmed rule selection, PA sends `EffectiveTarget` with a unique
`LastCommandContext`. A notification carrying that same context is a PA-origin
notification and updates `ObservedActual` without changing `DeltaOffset`.
Repeated or delayed notifications with that context are idempotent.

When a notification has a different/empty context and the endpoint is stable,
PA treats it as an external adjustment. It recalculates
`DeltaOffset = ObservedActual - NominalVolume` for the currently active rule,
clamped to the supported offset range, and records the new baseline. It does
not apply the same external event more than once by notification identity.
This is the selected policy for preserving manual adjustments.

Authoritative cases:

| Situation | Result |
|---|---|
| Slide changes but selected rule does not | No new command; preserve target and offset |
| Active rule changes | Select new nominal; apply existing offset once |
| No rule matches | Preserve actual volume; retain offset and active-rule state |
| PowerPoint/foreground becomes unknown | No specific rule; preserve volume |
| Endpoint disappears/replaced | Reset endpoint generation and observed baseline; re-enumerate; no write until a valid endpoint and rule exist |
| Repeated/delayed PA notification | Ignore for offset calculation by command context/idempotency |
| Manual adjustment under an active rule | Recalculate offset from external notification; future nominal rules use it |

If the endpoint API cannot return a usable event context, the implementation
must not infer manual adjustment from notifications; it must disable delta
updates, preserve absolute-mode safety, and report the limitation.

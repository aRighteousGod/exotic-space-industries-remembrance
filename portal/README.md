# ESIR portal workbench

The public page is being rebuilt in batches. The first batch covers sweeping radar,
the water turret, the Auric inoculation vat, gates, and Spidertron upgrades and
weapon controls. The remaining features stay in the queue until their behavior,
copy and footage have been reviewed.

## Current status: waiting for manual footage

The automatic pilot capture effort was stopped at the user's request on
2026-10-19. Preserve the framework and feature queue; do not resume automatic
capture unless requested. No pilot media has been approved or published.
See [the pilot handoff](batches/001-pilots.STATUS.md) for retained work and known
fixture issues.

The user will record gameplay. Keep original recordings unchanged, then use the
shared style for trimming, GUI crops, captions, WebP conversion and review. The
current renderer expects native screenshot manifests; manual video import is a
future adaptation, not an implemented command.

For recording, use a steady camera and dark editor tiles, with real terrain only
where needed. Close the **ESIR rebuild activity window before every take and GUI
capture**, and close it again if it reappears. Leave enough time to read controls
and see the result. Record at native resolution and keep the original video file.

## Sources

- `content.json`: introduction, listing summary, categories and closing text.
- `features.json`: feature IDs, plain-language copy, source ownership and queue.
- `coverage.json`: generated source map, including unresolved areas. File coverage
  is not a claim that all features have been identified or demonstrated.
- `style.json`: shared colors, type, dimensions and export settings.
- `batches/`: ordered, reproducible capture selections.
- `media/`: reviewed WebP demonstrations, posters and receipts.
- `MOD_PORTAL.md` and `SUMMARY.txt`: generated publication drafts.

Use [the portal skill](../.codex/skills/esir-mod-portal/SKILL.md) for writing and review.
The portal uses simple player-facing language. Keep lore in the game and in clearly
labeled flavor passages where it helps; explain actions and results directly here.

## Automatic capture tools (retained, inactive)

Requires Python with Pillow animated-WebP support, Windows fonts from `style.json`,
and the installed Factorio 2.0.77 client. The capture driver defaults to the local
managed dependency seed `.factorio-qc/fmqc/mods-live` and genuine-player save
`.factorio-qc/wtr/final-player/fixture.zip`. These are local prerequisites, not
downloaded by the script. The batch names its save explicitly. The driver accepts
`-FactorioPath` when called directly. Do not replace a missing seed with a fabricated
player and label it graphical evidence.

```powershell
powershell -File scripts/invoke-esir-dev.ps1 -Task portal-plan
powershell -File scripts/invoke-esir-dev.ps1 -Task portal-capture
powershell -File scripts/invoke-esir-dev.ps1 -Task portal-render
powershell -File scripts/invoke-esir-dev.ps1 -Task portal-validate
powershell -File scripts/invoke-esir-dev.ps1 -Task portal-page
```

Supply `-Path portal/batches/<batch>.json` for another batch. `portal-page` validates
the current batch before assembly. It creates the local review page under
`output/portal-media/<batch>/index.html`; only media with a recorded editorial review
is promoted. Machine validation never approves its own visuals.

After inspection, record the reviewer, batch, media hashes, notes and each verdict
in `portal/batches/<batch>.review.json`, then run:

```powershell
python -B scripts/portal-media/portal_media.py review --batch portal/batches/001-pilots.json --review-file portal/batches/001-pilots.review.json
```

The review command accepts `reviewed` or `needs-revision` for each feature and
rejects a review of different media. Rerendering resets candidate review to pending.

Native GUI details use `gui_crop: [left, top, right, bottom]` in source pixels.
For larger panels, `gui_views` can cut between crops using `at_ms` within a
continuous GUI segment, or select a crop using `match_caption`. An optional
`caption` explains that view. Inspect these coordinates at the batch's capture
resolution. Crops preserve real controls and readouts; they do not rebuild the UI.

The isolated native helper lives in `scripts/portal-media/native/`. It creates
demonstration scenes and calls production handlers. Its bridge is appended only to
the staged main mod, never the working gameplay source. Headless `-Probe` runs are
useful for scenario debugging and cannot be rendered as connected-player footage.

## Add a batch

1. Choose related pending features. Read their implementation and confirm what a
   player can actually do, dependencies, important limits and accepted names.
2. Give each feature a short title, one-sentence result and a short explanation.
   Record source paths or a conceptual model, and resolve attribution separately.
3. Choose a display family below. Add the scene to the native helper and list it in
   a batch. New feature IDs need real scenario code; a queue entry is not a capture.
4. Prove the expected behavior in a probe, then capture the graphical client.
5. Render and inspect the beginning, actions, GUI, result and loop transition.
   Check at 800 and 390 CSS pixels wide. Record the review and export again if needed.
6. Assemble the local page, report bytes, and leave unresolved coverage visible.

| Family | Show first | Show next | Evidence to keep |
| --- | --- | --- | --- |
| GUI | Machine in context | Open panel, action, result | Correct native panel and changed state |
| Complex process | Inputs and placement | Stages, output, useful status | Actual phase changes and outputs |
| Turret | Supply, coverage and target | Attack, outcome, controls | Real shots and damage or extinguished fire |
| Scripted module | Where the option applies | Same situation with the effect active | Production handler and observed effect |
| Network | Clearly identified endpoints | Route, transfer, status | Items or energy arriving at the destination |
| Production | A compact working chain | Materials entering and output leaving | Native recipe and inventory changes |
| Upgrade | Baseline vehicle or machine | Research, changed capability | Before/after prototype and control state |
| Option | What the setting changes | Matched comparison | Effective setting and an observable difference |
| Environment | Cause in its surroundings | Visible change over time | Timing, terrain or entity changes |

Use dark editor tiles as the shared background. Add real terrain only where the
mechanic needs it, such as the vat's wetland basin. Disable both entity and decorative
autoplace and clear existing decorations. Keep each working setup compact.

Use native gameplay at normal speed for combat. Label time-lapse from source ticks,
and label still reading holds. Never speed up the underlying recipes or manufacture
a successful result for the camera. Off-screen fixture supplies belong in receipts.

The local preview is not the Mod Portal. Hosted image availability and actual
animated-WebP playback still require a Portal preview before publication. No command
here uploads media or edits the live listing.

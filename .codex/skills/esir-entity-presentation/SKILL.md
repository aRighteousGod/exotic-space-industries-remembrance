---
name: esir-entity-presentation
description: "Integrate and review ESIR custom death explosions, hit effects, interaction sounds, and Factoriopedia scenes when adding, removing, renaming, or materially changing entities, operational variants, or shipping entity assets. Use for relevant prototype and asset integration work; draft-only rendering or export does not require gameplay edits."
---

# ESIR Entity Presentation

Check both death coverage and player-facing presentation for each affected entity.
Existing inheritance can satisfy either contract; an explicit registry entry is not
required everywhere. Keep changes within the requested entity family and preserve
authored behavior.

## Identify bodies and owners

- Map the canonical prototype, placing item/chassis, hidden operational variants,
  generated clones, and support helpers. Hidden does not necessarily mean helper.
  Decide applicability separately for death effects and player-facing presentation.
- Trace [data-final-fixes.lua](../../../exotic-space-industries-remembrance/data-final-fixes.lua)
  and the affected source/finalizer. Currently entity presentation precedes death
  assignment, which precedes spider finalization and flamethrower fuel-shell
  generation. Inspect final fields after every relevant late mutation and clone.
- For renames/removals, reconcile exact names, prefixes, registry entries, generated
  references, and focused QC expectations in their existing owners. Keep optional
  dependency guards scoped; use [dependency intelligence](../esir-dependency-intel/SKILL.md)
  when compatibility is involved.

## Death coverage

Read the [death contract](../../esir/blueprints/death-explosions.md#contract) and
[death-explosions.lua](../../../exotic-space-industries-remembrance/scripts/data-final-updates/death-explosions.lua).
Keep assignment catalogs and effect definitions in those owners.

- Check `death_candidate`, scoped ownership, supported prototype types, and
  `operational_exact`; do not broadly admit hidden helpers to cover one real body.
- Confirm family and footprint selection. Exact assignments precede prefixes and
  heuristics. Verify exact bespoke deaths and supplements before replacing a
  generic core; preserve native train breakup and authored death behavior.
- Preserve existing `dying_trigger_effect` entries and gameplay payloads. Check
  separate expiry paths such as a combat robot's `destroy_action`; death coverage
  alone does not establish expiry coverage. Cosmetic updates must retain attacks,
  mine activation, lifetime, loot, corpses, and mining behavior.
- Assign canonical bodies before their descendants are copied, then verify the
  resulting variants. Independent proxies need their own applicability decision.
- For additive sprite reuse, follow the
  [ANISETRON visual example](../../esir/blueprints/death-explosions.md#anisetron-visual):
  retain the existing family profile and supplement it once with a visual-only
  explosion. Copy the intended animation layers and motion without importing the
  donor's damage, created effects, sound, smoke, or light. Do not modify a shared
  family core to customize a single entity.
- Trace the actual application branch for a supplement: `apply_family` returns
  early for `exact_dying_explosion_overrides`, before the ordinary exact-effect
  append. An `effects_for_exact` entry alone is insufficient on that branch;
  wire a narrowly scoped append and verify the final effect occurs exactly once.

## Player-facing presentation

Use [entity-presentation.lua](../../../exotic-space-industries-remembrance/scripts/data-final-updates/entity-presentation.lua)
and its [machine](../../../exotic-space-industries-remembrance/scripts/data-final-updates/entity-presentation-machines.lua)
or [combat](../../../exotic-space-industries-remembrance/scripts/data-final-updates/entity-presentation-combat.lua)
registry. These own `damaged_trigger_effect`, `open_sound`, `close_sound`, and
`factoriopedia_simulation`; death fields belong to the death subsystem.
Read the [presentation contract](../../esir/blueprints/entity-presentation.md#contract)
before changing the registry interface or scene lifecycle.

- Inspect each applicable field on the final prototype. The registry applies
  explicit rows and fills unset values. Preserve appropriate source/inherited
  values; use `force.<field> = true` only for the specific field that needs replacing.
  An inherited vanilla scene may depict the wrong entity despite being nonempty.
- Trace registry row builders through to `api.entity`: confirm they forward the
  selected fields and per-field `force` option. Adding an option to a row has no
  effect if its builder ignores it; avoid forcing an entire group to fix one row.
- Missing or hidden prototypes, including those hidden from Factoriopedia, can be
  skipped even with an explicit row. A curated `operational = true` entry can admit
  a hidden selectable real body; it does not change visibility or admit nonselectable
  helpers. Prefer verified source inheritance and omit independent hidden-shell
  scenes. Inspect the filter rather than assuming registration proves coverage.
  Not every entity needs all four fields.
- Build scenes around the actual body, placement context, resources, energy,
  companions, and camera framing. Runtime/helper art may need a deliberate custom
  scene or documented omission; merely creating the canonical body can be blank.
  Use existing scene factories and installed vanilla helpers where suitable.
- Consult [Factorio docs](../factorio-lua-docs/SKILL.md) for API questions and
  [vanilla prototype libraries](../factorio-vanilla-prototype-libs/SKILL.md) for
  helper semantics. Keep substantive contract changes aligned with
  [conceptual blueprints](../esir-conceptual-blueprints/SKILL.md).

## Verify and report

- For prototype changes, start with the [ESIR wrapper](../esir-dev/SKILL.md):
  `powershell -ExecutionPolicy Bypass -File scripts/invoke-esir-dev.ps1 -Task qc-fast`.
  Use `qc-assets` for asset wiring and `qc-runtime` when runtime/helper behavior changes.
  Use live source and the relevant mod/startup profile; keep generated evidence in
  registered ignored staging under the existing housekeeping workflow.
- Inspect `EI death explosion audit:` messages and final-data fields for every
  affected body and generated variant. The pass's own audit occurs before later
  cloning; absence of warnings does not prove descendant coverage.
- Run the existing [death checker](../../../scripts/qc/death-explosions/check-data.py)
  against the matching final-data dump:
  `python -B scripts/qc/death-explosions/check-data.py <dump.json> --output <report.json>`.
  It is a focused regression fixture with specific entities/dependencies, not a
  universal coverage audit. Extend relevant expectations when adding coverage;
  do not claim a new entity was checked merely because this fixture passed.
- `--inventory-only` records a snapshot. The checker's current `--baseline` path
  specifically expects the historical baseline before the Incinerator expiry
  supplement, then adds that effect for comparison. Do not feed it an arbitrary
  pre-change/current snapshot as a generic regression baseline. Without that mode,
  do not claim its baseline-dependent payload/helper comparisons were executed.
- Review affected Factoriopedia scenes in the engine before claiming visual
  verification. Scene setup can silently fail inside protected calls even when
  loading succeeds. Final data proves wiring, not framing, visible activity, or
  death-animation appearance. Report visual checks separately.
- Use the [focused presentation fixture](../../../scripts/qc/entity-presentation/README.md)
  for final-field, inheritance and exact native scene-content checks. The scene
  factory forwards `update` for preview-only lifecycle work; it does not create
  companions from option tables, so explicitly construct needed helpers in
  `post_init`. Scene-content captures do not prove the encyclopedia GUI layout.
- For each affected entity or equivalent variant family, report both subsystems as
  **updated**, **inherited and verified**, or **intentionally excluded**, with a short
  reason and evidence. Mark pending/unverified conclusions explicitly; do not use
  "inherited and verified" for an unchecked assumption. Group shared results to
  keep the report concise.

Draft-only rendering/export ends with staged evidence and integration notes.
Apply this routine when shipping assets or wiring prototypes is in scope; it does
not authorize expanding a draft request into gameplay edits or a whole-mod backfill.

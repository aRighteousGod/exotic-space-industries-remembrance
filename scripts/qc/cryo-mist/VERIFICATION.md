# Cold mist verification — 2026-10-26

Implementation: ESIR 1.3.41, unchanged version. The unchanged Cryo-container mist
asset ships in the main mod; its CREDITS.md records snouz, Hurricane046, the
published graphics attribution, pinned revision, original path and SHA256.

Evidence payload: `.factorio-qc/cm-6e0d6572`, managed run
`6c40e1b423e94966bcb642baacfc2c30`, Factorio **2.0.77**, real Nonstandard Beacons
**1.4.2**. See README.md for isolation boundaries and repeatable commands.

## Prototype and engine acceptance

- Complete before/after comparison of 17 final prototype records passed. Changes
  are limited to the three mist entries, removed broad lights, explicit zero
  source flicker, and specified Factoriopedia scene upkeep. Recipes, consumption,
  effects, original body/antenna/indicator graphics, sounds, death effects and
  other presentation fields are preserved. Selected unaffected lighting consumers
  are included in the comparison.
- The native fixture passed **54 checks** over **28 placements**: working machines,
  hypercooler starvation/output blocking/no power/disable, supplied/depleted/
  deconstruction-marked beacons, all cardinal orientations, no-module beacons,
  and a compact six-beacon group. Input, power and deconstruction stop/restart,
  plus real source cleanup after destruction, passed.
- A real localhost-server checkpoint was saved at tick 700. Reload at tick 701
  retained the marker and working sources; **57 post-reload checks** passed.
- All three production Factoriopedia init/update scripts produced working native
  scenes. Copper and iron scenes explicitly create their existing source helpers.
  The hypercooler keeps its nitrogen-production scene and now enables that recipe
  on the preview force and maintains power/input/output space.
- Source PNG SHA256 matched
  `341e2cae41f220872ea1f708531bded1485c8d75962a82d72ded1fd170cbbeb0`;
  RGBA atlas geometry is 2048 × 2048 with 60 frames of 256 × 256.

## Rendered acceptance

Native capture review is recorded here after the Visual and Check phases finish.
The full graphics load exceeded available memory. The disposable visual fixture
therefore retains exact cooling-body graphics at high quality and substitutes
transparent frames for unrelated ESIR artwork. Gameplay prototypes are captured
before this render-only substitution; shipping files are never changed by it.

## Repository checks and limits

Doctor, focused syntax/diff checks, and the final blueprint audit passed (zero
blueprint findings). The broad `qc-assets` wrapper did **not** pass: it reported
existing encoding findings in `scripts/qc/singularity-lance/angular-results.json`,
`temp/anisetron-tracking-fix/blueprint-final.json`, and
`temp/storage-audit-c/evidence-link-update.json`. Python cache write/path failures
also produced advisory warnings. These unrelated files were left untouched.

Focused native fixtures isolate unrelated runtime controls. Their receipts do not
establish whole-mod runtime health, multiplayer client behavior, or Factoriopedia
window navigation/layout. Native preview scene contents are checked separately.

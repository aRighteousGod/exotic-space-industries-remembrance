# Robot progression verification

The historical fleet results below used Wraithline at 5 kJ/tile and Architectum
at 2.5 kJ/tile. Their movement costs have since been restored to 10 and 5 kJ/tile,
respectively; the completion-time ratios below have not been remeasured at those costs.

After restoring those costs, a focused Factorio 2.0.77 `--create` run passed the
existing final-prototype assertions for all four bots, both fleet conversions and
death/hit/sound/Factoriopedia fields. Evidence is retained in
`.factorio-qc/managed/be31b1d6d6`. This check did not repeat the fleet timing matrix
or rendered visual review. Broad preflight and `qc-fast` remained unsuccessful;
`qc-fast` reported unrelated encoding findings and a 260-character staged module
path. The focused run used shorter staging and loaded successfully.

Engine: Factorio 2.0.77. Main mod version: 1.3.41 (unchanged).
Run: `.factorio-qc/managed/219bddf9e8474e37a421a6ce8fb84ff1`.
Pre-feature robot source: `747d349e3ab693e2acb436fe9a51cf9fbb9eda1d`.
The fixture ran the staged live gameplay with its normal controls and declared
dependency profile, including the optional minigun pack present in the worktree.

## Functional and final-data results

- Candidate passed 80 runtime assertions and all 16 fleet comparisons.
- Final snapshot comparison passed 77 checks: previous robot tiers, direct and
  recycling recipes, Advanced bots prerequisites/costs, and existing presentation
  fields stayed unchanged. Conversion data assertions verified the selected stats,
  costs, flags, quality support, two-layer icons, visibility and unlock ownership.
- A same-version pre-feature save gained both conversion recipes through native
  prototype refresh with Advanced bots already researched. An existing Wraithline
  retained its entity identity. A fresh force remained locked until that technology
  was marked researched through the native API, then gained both recipes.
- Native assemblers crafted each conversion at normal and rare quality, consuming
  exactly one donor, four processing units and four engines per output. Each yielded
  one matching-quality bot. Productivity modules were rejected.
- Twenty depleted bots of each family completed native recharging at identical
  advanced roboports. Wraithline's larger retained battery takes longer to refill;
  no claim of uniformly shorter individual recharge visits is made.
- A real local server checkpoint retained both unlocks and all four crafted outputs;
  reload passed with 51 cumulative assertions in the save fixture.

## Measured fleet results

All fleets contained 20 normal-quality bots. Both 32- and 128-tile origin distances
were checked with no worker bonuses and with +100% speed / +3 cargo bonuses.
Elapsed times were sampled every 30 ticks. See README for jobs and geometry.

| Workload | Advanced fleet completion speedup, all four comparisons |
| --- | ---: |
| Deliver 2,000 iron plates | 2.73-3.16x |
| Build 200 walls | 2.35-2.53x |
| Deconstruct 200 walls | 2.31-2.68x |
| Reach and repair 40 walls | 1.17-1.89x |

These are controlled completion-time results, not whole-base UPS measurements or
universal throughput guarantees. Ports received identical fixture power; working
robots used their native batteries and charging behavior. Repairs retain the
native repair rate, so the improvement includes faster travel to the work.

## Evidence and broader checks

The payload's `script-output` contains `robot-runtime.json`,
`robot-final-comparison.json`, `robot-save.json`, `robot-reload.json` and before/after
final snapshots. `recipe-audit.json` used fresh recipe snapshots, unchanged item
prototypes from the retained October 18 dump, and companion icon baseline 1.1.27.
The conservative icon audit leaves dynamic recipes for native visual review.

Focused Lua syntax, Python syntax, PowerShell parsing and whitespace checks passed.
The blueprint audit reports no robot findings; its remaining three missing-primary
findings are in the unrelated `minigun-turret-HD` pack.

The required broad `preflight` and `qc-fast` wrapper attempts were blocked by an
existing long-path fixture under `output/minigun-firing-offline-tests/long-paths`.
`qc-fast` also reported existing encoding findings in
`scripts/qc/singularity-lance/angular-results.json` and
`temp/anisetron-tracking-fix/blueprint-final.json`. No unrelated files were repaired.
The focused native runs supply the robot-specific engine evidence instead.

## Visual acceptance remains open

Hidden normal-play clients initialized the native player but did not advance the
capture ticks. Explicit unpausing did not resolve it. A hidden 900-frame graphics
benchmark also initialized the player and exited normally without screenshots.
These attempts do not establish visual acceptance. All task-launched clients
were closed. The user chose to finish with headless evidence and leave visual
acceptance open; no visible-client retry was launched. Final presentation fields
are inherited and verified; rendered GUI layout and scene appearance remain
unverified. The managed run is closed with a warning status and its evidence retained.
The optional `-Phase Visual -ShowVisualWindow` retry remains available for a future
visual acceptance session.

## Later donor-icon refinement

Both direct recipes and both fleet conversions now use enlarged donor artwork
with eight dark silhouette outline layers, an upper-left target icon and a
bottom-right donor foreground. The donor scale is 0.32 and its shift is {4.8, 4.8}.
Focused Lua execution checked all four donor mappings, outline layers and slot
bounds; Lua syntax and whitespace checks passed. These later cosmetic changes
were not included in the native run above, which used the original two-layer
conversion icons. Rendered appearance remains unverified.

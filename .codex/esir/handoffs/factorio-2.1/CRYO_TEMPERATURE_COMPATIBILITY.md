# Cryo-container temperature compatibility / 2026-10-28

The reported error rejects `ei-empty-cryo-container-ammoniacal-solution` because
its -50 C product is outside the final fluid's 15-100 C range. An isolated exact
Factorio 2.1.23 fixture reproduced that error before the fix. The user subsequently
confirmed that this is another player's setup and reported Space Age Galore as
the trigger. Upstream source inspection matches the reported range exactly; the
player's precise package version and complete mod selection remain unknown.
The earlier reviewed K2 failure involved a different fluid, `kr-ammonia`, with a
25 C minimum.

## Space Age Galore source confirmation

Inspected Project Galore commit `85e1e446e63621f2f67ec7669bbc1f572ef00992`
(Space Age Galore source metadata 1.6.14). Its
[fluid overrides](https://github.com/JTnadrooi/Project-Galore/blob/85e1e446e63621f2f67ec7669bbc1f572ef00992/space_age_galore/overrides/overrides.lua#L27-L35)
apply these changes when the corresponding startup settings are enabled:

| Setting | Fluid | Default/minimum | Maximum |
|---|---|---:|---:|
| `vgal-ammoniacal-solution-temp-override` | `ammoniacal-solution` | 15 C | 100 C |
| `vgal-ammonia-temp-override` | `ammonia` | 15 C | 450 C |

[Space Age Galore's data.lua](https://github.com/JTnadrooi/Project-Galore/blob/85e1e446e63621f2f67ec7669bbc1f572ef00992/space_age_galore/data.lua#L39-L41)
loads these overrides in the initial data stage. ESIR's repair runs in
data-final-fixes, so it sees both changed ranges regardless of initial-stage mod
ordering. With both overrides enabled, both affected cryo pairs use exactly 15 C
for filling and emptying. No additional dependency, mod-specific branch or source
change is needed. The follow-up native fixture below now verifies these exact
overrides together, including their initial data stage. It does not load the
complete Space Age Galore package or the player's mod set.

## Behavior and scope

`prototypes/cryo-containers.lua` now checks the nine existing transfer pairs
during finalization, after ESIR's compatibility passes. A valid selected output
temperature is preserved. If it falls outside the actual output fluid's final
range, both emptying output and matching filling input use that fluid's
`default_temperature`, which Factorio also defines as its minimum. Stale input
minimum/maximum constraints are cleared in that repaired pair; filling still
requires exactly the selected temperature. No arbitrary-temperature filling or
free heating/cooling is introduced.

| Configuration | Ammoniacal solution | Ammonia |
|---|---:|---:|
| Core ESIR | -50 C, unchanged | -35 C, unchanged |
| Fixture reproducing changed ranges | 15 C in both directions | 25 C in both directions, using a replacement fluid ID |
| Fixture with both Galore overrides | 15 C in both directions | 15 C in both directions, original ammonia ID |

The registry remains closed. Fluid quantity, item/recipe identities, one-second
transfer time, unlocks, productivity/quality/recycling restrictions and all other
product metadata are preserved. No runtime state, event, remote API, setting,
locale or migration is added. Existing filled containers keep their identities;
emptying follows the valid temperature of the active mod configuration.

The conceptual model, current changelog and upgrade synopsis describe the fix.
The reusable exact-engine fixture is `scripts/qc/factorio-2.1/cryo-temperature/`.
This is a narrow compatibility correction, not acceptance of full Krastorio 2
progression, optional combinations or save migration.

## Verification

Evidence root: `.factorio-qc/cryo-temp-20261028/`.

- `before-run.log`: native reproduction of the exact -50 versus 15-100 error.
- `baseline.json`: native fill/empty round trips for all nine core fluids.
- `mutated.json`: native fill/empty round trips under the changed-range and
  replacement-fluid fixture. Both runs passed: **18 round trips at 1,000 units
  each**, with **four wrong-temperature rejection checks** across the two cases.
- Final-data assertions verify all nine pairs, quantities, transfer flags and
  the expected fixed temperatures. Runtime checks verify returned containers,
  conserved fluid quantity/temperature and rejection of another representable
  temperature where the fluid's range permits the comparison.
- `verification.json`: exact engine, result counts and accepted source hash.
  Lua syntax and diff checks pass; the conceptual-blueprint audit reports zero
  findings across 65 models and 208 owned sources.

The original verification receipt predates the Space Age Galore identification;
its `external_modifier_identified=false` records knowledge at test time. That
historical receipt remains unchanged. The production source SHA-256 still
matches its accepted value.

### Both Galore overrides / current 1.4.1 source

Follow-up evidence: `.factorio-qc/cryo-galore-20261028/verification.json`,
`engine/galore-create.factorio.log`, `engine/galore-roundtrip.factorio.log`, and
`engine/script-output/cryo-temperature.json`.

- Exact installed executable and engine data: Factorio 2.1.23; main ESIR 1.4.1.
- A separate fixture applies both inspected Galore fluid overrides in data.lua.
  Native final-data assertions pass for all nine transfer pairs. Logs explicitly
  record ammoniacal solution -50 -> 15 C and ammonia -35 -> 15 C.
- Fresh-save creation and 600 native ticks pass. All nine fill/empty round trips
  preserve 1,000 units and return the empty container; both affected fluids
  remain exactly 15 C. Three wrong-temperature checks pass, including rejection
  of 16 C input for both affected recipes.
- Together with the earlier unchanged-core and replacement-fluid runs, there are
  27 accepted native round trips and seven wrong-temperature rejection checks.
- The first follow-up staging attempt ran out of disk space before engine
  execution. Staging then reused the 23 preserved dependency archives through
  hard links; the retry passed. That staging failure is separate from gameplay
  results. Installation settings and mod selection were untouched.

The current worktree already selected version 1.4.1; this task did not bump it.
The cryo correction's changelog entry now belongs to that current version.

An initial runtime fixture attempt omitted unlocking its test recipes; it failed
before crafting. The corrected fixture explicitly enables its own transfer
recipes. Diagnostic logs remain separate from accepted results.

No rendered, multiplayer, performance, audio or complete Galore/K2 compatibility
acceptance is claimed. Changes are local; package rebuilding and installation
remain with the user.

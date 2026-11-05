# Detached gate estimator — 2026-11-04

Implemented for ESIR **1.4.03**, without changing the mod version. The gate console
opens an independent, draggable calculator. It reads a gate only when opening the
first scenario or explicitly loading a snapshot; calculations do not change cargo,
energy, circuit settings or gate operation.

## Delivered behavior

- Item selection; stack/deposit quantity, stress and distance sliders; sender quality;
  sending/receiving planet slots. A complete planet pair locks distance to the existing
  starmap cache without generating planet surfaces. Identical planets mean one surface.
- Live substituted calculations for burden, distance, quality, transfer energy,
  energy per item, stress, cooldown, receiver saturation and upkeep, with tooltips.
- Input rate in items/s or items/min, available power in MW or GW, and editable initial
  energy, stress, cooldown and saturation. Native hardware limits and a fixed service
  cadence come from the source gate and current dispatcher population.
- Explicit Run for 1/5/15/60-minute projections, one pinned comparison baseline,
  two selectable charts, a time cursor and a summary. Metrics cover energy,
  stress/saturation, cooldown/transfer interval, delivered/offered throughput,
  upstream/inventory queues and transfer/upkeep power.
- Shared live gate arithmetic, including final integer energy rounding. Projections
  preserve eager stack transfers, stack merging, cooldown input locking, whole-stack
  affordability and receiver saturation. Stack quantity limits deposits; it does not
  force a gate to wait for or transfer exactly that quantity.
- At most 1,000 simulated ticks per game tick across all jobs and 240 bins per trace.
  Edits and closing cancel work. Closed/completed calculators do no recurring simulation.
  Reload and configuration repair preserve drafts/baselines, rebuild open windows and
  invalidate unfinished jobs and previous results.
- All eight locales have 97 matching keys and placeholder sets. French, Polish and
  Russian terminology follows the existing gate names and stress/cooling captions.

The simulation assumes one enabled sender, one item, constant offered supply and
available power, an available route, and automatic removal of output and residue.
Cargo/upstream queues start empty. It excludes inserter motion, spoilage, damage,
circuit changes, competing senders/network consumers and moving platform routes.
Waiting causes overlap and must not be summed as a partition of elapsed time.

## Source ownership

- [Estimator UI and job lifecycle](../../../exotic-space-industries-remembrance/scripts/control/gate-estimator.lua)
- [Shared arithmetic](../../../exotic-space-industries-remembrance/lib/gate-calculations.lua)
- [Bounded projection](../../../exotic-space-industries-remembrance/lib/gate-projection.lua)
- [Private chart canvas](../../../exotic-space-industries-remembrance/lib/gate-estimator-chart.lua)
- [Gate contract](../blueprints/gate.md#estimator)
- [Native estimator fixture](../../../scripts/qc/gate-quality/estimator.lua)

`control.lua` remains the sole dispatcher. The force-hidden chart surface is excluded
from ordinary surface pickers, world ecology setup and restriction census. The mass
table remains in the gate owner. No new setting or public remote interface was added.

## Verification

Exact engine: **Factorio 2.1.24**, using the registered `gate-quality` suite and the
development dependency selection. No broad/full QC was run.

| Profile | Candidate | Graphical checkpoint | Reload | Configuration |
| --- | ---: | ---: | ---: | ---: |
| Quality enabled | 339 passed | 339 passed | 56 passed | 56 passed |
| Quality disabled | 98 passed | 98 passed | 46 passed | 46 passed |

Final targeted wrapper: `c14ebd8f19fe4cccbc843e5a15750aae`, **ok**.

- [Wrapper receipt](../../../.factorio-qc/managed/c14ebd8f19fe4cccbc843e5a15750aae/result.json)
- [Quality-enabled receipt](../../../.factorio-qc/managed/e8391ee887804c23866b41011a17d98d/final-result.json)
- [Quality-disabled receipt](../../../.factorio-qc/managed/df081ae5f1d742b08f0da80979ea75f2/final-result.json)

Focused quick iteration also passed both profiles under wrapper
`0e1ca0c110804dbea81075be9b3e7b15` (335/98 candidate assertions). The final targeted
run includes the additional launcher and input-repair assertions.

Projection parity compares delivered cargo, buffered cargo, upstream backlog,
energy, stress, receiver saturation and cooldown against live gate functions in
three controlled native-world scenarios with supplied ticks and power. This is
not a measurement of an actual electrical network or inserter throughput.
Independent formula, conservation, resumability and zero-supply checks also pass.
Existing quality, partial-transfer, energy, residue, real-inserter cooldown and
persistence assertions remain in the same suite.

GUI assertions exercise the console launcher dispatch, unchanged `player.opened`,
read-only snapshots, planet locking/clearing, native selectors, unit conversion,
invalid-input recovery, missing baseline prototypes, current stack-size limits,
cancellation, render-player restrictions and retained baselines. The checkpoint
saves an open estimator with unfinished work; reload/configuration prove that its
draft survives while the job and previous plots are invalidated.

Scoped static checks and `git diff --check` passed. The blueprint audit has no gate
findings; its two pre-existing findings concern reciprocal ownership of
`scripts/data-final-updates/beacon-profiles.lua` in the beacon model.

The only changes after the engine run were French/Polish/Russian terminology and
this evidence note. Locale key/placeholder/UTF-8 checks and scoped static checks were
repeated afterward. Runtime Lua, fixtures and the inspected English strings did
not change after acceptance.

## Rendered evidence and limits

Inspected actual English captures at **1280×720, 75% UI scale**. The 24-tile camera
canvas fits horizontally and vertically; the lower chart and summary are reached
through the native scroll pane. Calculation text wraps within its column.

- [Calculation](../../../.factorio-qc/managed/e8391ee887804c23866b41011a17d98d/rendered/estimator-calculation.png)
- [Energy and stress](../../../.factorio-qc/managed/e8391ee887804c23866b41011a17d98d/rendered/estimator-projections.png)
- [Cooldown and queues](../../../.factorio-qc/managed/e8391ee887804c23866b41011a17d98d/rendered/estimator-cooldown-queue.png)
- [Scrolled summary](../../../.factorio-qc/managed/e8391ee887804c23866b41011a17d98d/rendered/estimator-summary.png)
- [Tooltip text proof](../../../.factorio-qc/managed/e8391ee887804c23866b41011a17d98d/rendered/estimator-tooltips.png)

The tooltip proof renders the real localized tooltip strings in a bounded fixture
panel; it does not claim native mouse-hover coverage. The test executor also
constructed the GUI at 1920×1080/100%, but that is native-state evidence, not a
second rendered layout review. Other locales have structural/terminology checks,
not rendered acceptance or independent native-speaker review. No two-client
multiplayer session was run; player-restricted render properties were asserted.

All task-owned native runs are closed in the artifact registry. Final captures and
compressed evidence remain in their managed directories; earlier failed evidence
was retained. Unrelated spreadsheet inspection/lock files were left untouched.

Reproduce with:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-esir-dev.ps1 -Task qc-quick -Suite gate-quality -TestProfile default,quality-disabled
powershell -ExecutionPolicy Bypass -File scripts/invoke-esir-dev.ps1 -Task qc-targeted -Suite gate-quality
```

## Follow-up: interface-scale graph fit

The initial camera fit was only visually verified at 75%. At 200%, the widget
grew while the rendered chart remained small. Camera zoom now uses physical
widget width (logical width times `player.display_scale`), with the native
48-pixels-per-tile camera projection. Existing display-change rebuilds refit both
plots without rerunning the simulation.

Factorio 2.1.24 rendered evidence was inspected at 3840×2160 / 200% in managed run
`188690da4d584fc4833901f77117ae74` (graphical checkpoint and reload passed). The
private capture used explicit 200% scaling; the native render log confirms the
actual resolution and scale. Its retained `scale-capture-driver.py` records the
isolated config/launch overrides; the standard runner was not edited.

The standard targeted default-profile run `00ee65321f85472d90e926b4907623b0`
passed static, candidate, graphical checkpoint, reload and configuration checks.
Its native evidence is `37dd76099a3d41cba7d6e4041f394b70`; the fresh 1280×720 / 75%
capture was also inspected. Screenshots are retained in each native run's
`rendered` directory. Both runs closed successfully. The mod version is unchanged.

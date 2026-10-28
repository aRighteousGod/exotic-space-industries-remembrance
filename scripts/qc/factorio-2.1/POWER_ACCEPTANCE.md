# Focused 2.1 power acceptance

Use short ignored junctions beneath the protected upgrade run. These scripts stage
private gameplay copies and helpers; they do not change the installed mod selection,
published 2.0 packages or actual player saves. `stage_owner.py` records source hashes.

## Solar consumer boundary

`stage_solar.py --run <short-path> --version 2.0|2.1` stages the unchanged solar
tower with controlled hidden fluid at 9/10/11 C, initial tower heat 20/900 C and
isolated/connected heat-pipe cases. Run `run_staged.py` for 6,002 ticks with marker
`SOLAR BOUNDARY COMPLETE`, selecting the exact historical executable for 2.0.
The report contains twelve cases and three snapshots each. Below 10 C, 2.0 rejects
storage while 2.1 retains it without consuming; heat and admitted consumption match.

## Turbine owner and GUI

`stage_turbine.py --run <short-path>` copies the current core. Its private creation
fault returns nil before the native create call. `--refresh` updates only this
fixture's owner, control bridge and helper; it is not a general core refresh.
Run `run_staged.py` for 41 ticks with marker `TURBINE ACTORS COMPLETE`. The checks
cover state flags, queued/burning fuel, connected fluid, creation failure, helper
destruction/rebuild, tags, native clone and paste.

Use `native_client.py` with the fresh seed, marker `turbine-client.json` and checkpoint
`_autosave-turbine-accepted.zip`. Reload that actual checkpoint with marker
`turbine-client-reload.json` and checkpoint `_autosave-turbine-client-reloaded.zip`.
The reload verifies native old-window/new-console handoff, current-console close,
reopening and body/proxy ownership. Inspect the 1600x1000 screenshots separately;
GUI assertions do not prove rendered readability. The bridge's GUI ordering trace
is private and is not a production profiler or multiplayer test.

## Historical turbine donor

`stage_turbine_migration.py --version 2.0 --mode donor --run <short-path> --seed`
creates the 2.0 seed. Run `save_checkpoint.py` to obtain `_autosave-turbine-donor.zip`.
Stage another path with `--version 2.1 --mode migration`, load that donor through
`save_checkpoint.py`, then refresh the target helper to `--mode reload` and load
the real migrated save again. Both target phases compare 41 fields and advance
another 600 ticks. The exact donor's accepted native overflow delta is explicitly
recorded, then strict conservation resumes for the second save/reload.

## Loaded native electrical networks

`stage_power_output.py --run <short-path> --version 2.0|2.1` stages unchanged
generators and a private electrical load. Run `run_staged.py` for 1,802 ticks with
marker `POWER OUTPUT COMPLETE`. Five bodies, normal/rare quality and five demand
states make 50 isolated networks. After 600 warm-up ticks, two 600-tick windows
check generated electricity, delivery to the load, fluid consumption or coal
consumption including the in-progress burning reserve. Fluid is topped up by the
fixture; this is not pipeline-throughput or upstream fuel-production acceptance.

Electrical statistics count generation as entity **output** and load delivery as
entity **input**. Generator lookups must include quality; the unqualified aggregate
counts do not substitute for a quality-specific lookup. Earlier fixture failures
are retained and do not represent production-source defects.

The final 2.1 run passes 300 checks. The 2.0 run deliberately records four negative
power checks: its rare solid burner underproduces at full/overloaded demand.
Use `--native-burner` on two separate paths to reproduce this with only Base,
Quality (and its required 2.1 Recycler dependency), a minimal 12 MW/efficiency-3
burner and the private load. There is no ESIR source or asset in that reproduction.

`compare_power_output.py --before <20-report> --after <21-report>
--native-before <native-20-report> --native-after <native-21-report>
--output <audit-json>` validates all 100 measurement windows. It accepts the
historical negative assertions only at their exact recorded values and requires
the changed core measurements to equal the independent native reproduction.
This is a documented native engine difference, not a prototype rebalance or a
general tolerance waiver. The 2.0 driver receipt remains failed; the comparison
receipt distinguishes that negative evidence from the 2.1 acceptance pass.

## Fusion recipes, state and lifecycle

`stage_fusion.py --run <short-path> --version 2.0|2.1 --mode recipes`
stages all 135 fuel recipes. Run `run_staged.py` for 402 ticks with marker
`FUSION RECIPES COMPLETE`, selecting the historical executable for 2.0.
The fixture blocks each native output until tick 121, releases it, and measures
one ordinary craft per recipe. `compare_fusion.py` normalizes only validated
deterministic probability-field representations and requires exact equality
for all remaining case fields. Each engine passes 1,053 assertions.

Use `--mode donor --seed` on 2.0 and `save_checkpoint.py` to obtain the populated
fusion donor. On 2.1, `--mode migration` checks 121 state fields immediately and
after 600 ticks; `--mode reload --refresh` checks the saved migrated state for a
second 600 ticks. Manual fallbacks deliberately differ from the circuit-selected
recipe, making accidental reconstruction from the active recipe detectable.
The first failing receipt is retained; current configuration repair preserves
native reactors, fluids, progress, quality, control choices and owned wire proxies.

`--mode actors` and `run_staged.py` for 200 ticks with marker
`FUSION ACTORS COMPLETE` exercise native construction/destruction, circuit commands,
partial fallbacks, neutron-collector disable/recovery, settings paste, helper
recreation/reconnection and orphan cleanup. Twenty assertions pass, including
zero pending work after the last reactor is removed.

Use `--mode gui --seed` with `native_client.py`, marker `fusion-client.json` and
checkpoint `_autosave-fusion-client.zip`; reload with `fusion-client-reload.json`
and `_autosave-fusion-client-reload.zip`. Inspect the resulting screenshots
separately. These native widget callbacks are automated, not physical mouse input.

## Engine-only overflow reproduction

`stage_native_generator.py` enables only Base and the private reproducer, with
one 400-unit generator buffer and one 100-unit pipe per case. The 2.0 donor contains
100/200/230 total units. Its `--mode prepare` experiment adds a second pipe before
saving; this demonstrates the capacity boundary and is **not a required upgrade
step**. The user accepted the native overflow limit. Preserve the unprepared
negative report before the prepared run overwrites its stable output filename.

A successful checkpoint-driver exit means the experiment was captured, not that
fluid conservation passed. Inspect each report's `conserved` field. The unprepared
230-unit case deliberately records false in 2.1. No ESIR balance change, general
fluid escrow, automatic preparation or player prerequisite is implemented.

The maintained [upgrade synopsis](../../../.codex/esir/handoffs/factorio-2.1/UPGRADE_SYNOPSIS.md)
records accepted runs, hashes, static/native/render distinctions and remaining
fusion-control, integrated networks, audio, manual interaction, multiplayer and
performance gates.

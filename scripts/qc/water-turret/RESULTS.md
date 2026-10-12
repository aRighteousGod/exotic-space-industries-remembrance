# A. S. H. Sentry event index acceptance

Engine: **Factorio 2.0.77**. Recorded 2026-10-12. Evidence below was collected
before the scoped delivery commit; repository history records the delivery.

The creation-hook gate passed before the runtime index was implemented. Supported
fires notify ESIR through their preserved-and-extended `created_effect`;
no periodic discovery or polling recovery fallback was introduced.

## Sources and reproduction

Managed run: `9f2e5fb7caf94e7d9ac06cac1377873b`, payload
`.factorio-qc/wtr/event-index-20261012`. The [runner instructions](README.md)
describe the creation, index, transition and performance profiles.

Gameplay acceptance used the current full working pack, including its concurrent
unrelated changes. Performance used a captured pre-change dirty main pack
(`baseline/`) and that same pack with only this water implementation overlaid
(`candidate/`). Both performance copies retain version 1.3.40; the live main pack
advanced independently to 1.3.42. Dependencies and other gameplay sources match
between the performance pair. This avoids comparing unrelated concurrent work.

Generate machine-readable timing summaries from retained logs:

```powershell
python -B scripts/qc/water-turret/summarize-performance.py .factorio-qc/wtr/event-index-20261012
```

## Behavior results

| Profile | Result | Evidence |
|---|---:|---|
| Creation, fuel adaptation enabled | 40/40 | `gate/script-output/water-qc.json` |
| Creation, fuel adaptation disabled | 40/40 | `noadapt/script-output/water-qc.json` |
| Existing gameplay and smooth aiming | 107/107 | `acceptance/script-output/water-qc.json` |
| Event index, first-nearby | 613/613 | `index-first/script-output/water-qc.json` |
| Event index, nearest | 613/613 | `index-nearest/script-output/water-qc.json` |
| Ordinary reload during queued aiming | 607/607 | `reload-report.json` |
| Pre-index save upgraded to current state | 35/35 | `upgrade/script-output/water-qc.json` |
| Five paired performance scenes | All pass | `b-*/` and `c-*/script-output/water-qc.json` |

The creation profiles silently create all 30 supported final fire prototypes,
including ESIR thermal and weapon variants. They also exercise native weapon
stream impacts, natural tree spread, sticker spread, refuelling/merging without
duplicate identities, stable destruction registration and preservation of prior
creation effects. Final-data assertions require one private hook on every
supported fire and none on excluded fires, under both adaptation settings.
The specific ecology and rupture gameplay producers were not simulated end to
end; their final fire prototypes were tested through scripted creation.

The index profiles use **192 simultaneous aimers**, with observed service gaps
up to **7 ticks**. They verify elapsed rotation allowances, skipped intermediate
orientations under backlog, alignment, fresh cooldowns, no pause/cooldown credit,
and no extra pulse during catch-up. Existing acceptance checks cover shortest-arc
wraparound in both directions, fixed ground direction and pipe connections,
water consumption, native enemy priorities, acid protection and handheld impacts.

The index fixture also checks the 32 hot / 8 cold slices / 512 combined cold
visits / 32 wake / 1 bootstrap-query limits; a 600-fire population with 450
removals and births/removals during compaction; exact range rejection inside a
covered chunk; negative chunk boundaries and neighbor coverage after deletion;
quality range; readiness recovery; notified movement; coverage expansion;
import-helper reconciliation; repair and surface teardown. Available idle turrets
settle to zero recurring acquisition and zero discovery queries.

Ordinary reload used the **unchanged staged mods and configuration**. It preserved
target, generation, pulse deadline and aiming checkpoint. A separately staged
old-schema save exercised real configuration migration, preserving preferences,
valid helper entities and their charge, and pulse deadlines while resetting
derived queues/index/checkpoints. Restaging a changed fixture before an ordinary
reload was rejected as a test setup: it triggers configuration repair and is not
equivalent to normal save/load. The corrected unchanged-mod reload passed.

## Performance

Each scene uses 128 turrets, 2,000 warmup ticks and 6,000 measured updater ticks.
Whole-engine timing uses the 5,999 warmed rows between the initial and final
diagnostic calls. Times are **milliseconds per tick; lower is better**.
Water time includes the updater plus creation/destruction receivers. Engine time
includes the whole simulation and instrumentation overhead.

| Scene | Water baseline | Water candidate | Engine mean baseline | Engine mean candidate | Engine p95 baseline | Engine p95 candidate |
|---|---:|---:|---:|---:|---:|---:|
| Dry idle | 0.1305 | 0.0875 | 0.5435 | 0.4897 | 0.9130 | 0.6488 |
| Wet idle | 0.1335 | 0.1111 | 0.5515 | 0.5227 | 0.9186 | 0.7007 |
| Dense overlapping defenses | 1.2497 | 0.7495 | 1.7763 | 1.3971 | 3.4507 | 2.5939 |
| Dispersed defenses | 0.2731 | 0.2656 | 0.7318 | 0.7815 | 2.0124 | 1.4244 |
| Fire bursts | 0.7024 | 0.4967 | 1.1797 | 1.1145 | 2.4927 | 2.4076 |

Candidate creation/destruction receiver time was 0.0171 ms/tick in dense,
0.0194 in dispersed and 0.0116 in burst; idle scenes had none. Every candidate
scene performed **zero discovery queries after warmup**. Both idle scenes also
performed zero cold acquisition, wake visits and hot services, while continuing
the independent 15-tick electrical guard. The baseline made 6,400 queries in
each idle scene, 12,924 dense, 9,600 dispersed and 9,450 burst.

Dispersed timing was repeated three times per implementation, using the same
staged fixture/mods with separate write-data directories (`b-repeat`, `c-repeat`):

| Dispersed repeat | Baseline engine mean | Candidate engine mean | Baseline p95 | Candidate p95 |
|---|---:|---:|---:|---:|
| 1 | 0.7087 | 0.7866 | 1.9517 | 1.4289 |
| 2 | 0.7086 | 0.7889 | 1.9321 | 1.4392 |
| 3 | 0.7554 | 0.7922 | 2.0223 | 1.4398 |
| Mean of runs | 0.7242 | 0.7892 | 1.9687 | 1.4360 |

This is a reproducible tradeoff in this fixture: **about 9% higher whole-engine
mean time, with about 27% lower p95 time** for dispersed defenses. The original
water-only measurement fell slightly, so it is not sufficient to claim a total
simulation speedup. Repeated engine breakdowns show most of the difference in
the aggregate game-update measurement, with a smaller GC increase; they do not
isolate a single cause. The implementation is not an across-the-board speedup.

All dispersed runs launch 6,400 pulses in the measurement window. Dense and
burst candidates respond sooner and launch more pulses (11,183 vs 8,848 dense;
7,316 vs 5,533 burst), so those comparisons include different resulting activity.
There are no cross-turret reservations. Synthetic local timings are not a
multiplayer or general UPS guarantee.

A measured initial idle regression was fixed by caching immutable prototype and
quality range during coverage setup instead of materializing attack-parameter
tables every electrical guard. The table above uses the corrected implementation;
the original measurement remains in `pre-range-cache-dry*` evidence.

## Static checks and limits

The scoped 1.3.42 delivery candidate was exported from its private Git index and
tested separately: **107/107 gameplay checks and 613/613 nearest-index checks
passed** on 2.0.77. Its water source, settings, dispatcher and data-hook wiring
matched the reviewed candidate; unrelated working-tree edits were excluded.
Candidate Lua syntax, water blueprint backlinks and staged whitespace passed.
These delivery reports are under `.factorio-qc/wtd/`.

- Lua syntax passed for changed production/glue and QC Lua; the headless runs
  provide actual Factorio runtime validation.
- All seven firefighting locale files passed strict duplicate-key parsing, UTF-8
  checks, new targeting-key coverage and obsolete interval-key removal.
- Blueprint audit had no water-model findings. Its remaining three findings
  concern missing primary markers in the unrelated minigun companion.
- Fire cloning returns nil in this engine. The gate records that unsupported
  operation; explicit clone-event admission remains wired.
- Surface import coverage invokes the production handler, not a complete engine
  export/import round trip. No new multiplayer or visual-art acceptance is claimed.
- Saved backlog probes cover hot aiming, not a partial nearest scan or active
  compaction builder across reload. Mutation/mirroring is tested, but there is no
  separate assertion for an old nearest view completing after publication.
- New pause-credit tests use electrical loss/resume. Freezing, recipe disable,
  deconstruction and a mid-turn native enemy arrival share the readiness path
  but were not individually induced in this new catch-up fixture. Connected-player
  GUI/paste/blueprint cases were not rerun in the headless 107-case profile.
- Arbitrary silent relocation of an existing fire remains outside the event
  contract. Notified relocation and destroy/recreate paths are supported.
- Nearest selection uses a bounded acquisition snapshot. Later births do not
  preempt a retained valid target. If the best candidate dies after its slot was
  visited, a destruction wake retries acquisition; immediate runner-up handoff
  is not guaranteed while the wake queue is backlogged.
- Creation bursts, electrical checks, impact processing and an individual seed
  query are outside the fixed queue service limits. Exact coverage tests at cell
  boundaries can still visit multiple cached circles; budgets are not CPU caps.
- Singularity Lance and flex-radar checks were skipped as requested. No broad
  preflight or unrelated cleanup was used to describe this subsystem as passing.

Early long-path staging and restaged-reload attempts were diagnosed and superseded
by the passing short-path and unchanged-mod runs above. Task-owned companion
junctions are unlinked nonrecursively at managed closeout; source companions and
all unrelated work remain untouched.

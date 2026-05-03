# Severance Array QC Helper

Use this helper when ESIR work needs a dense, repeatable Severance Array benchmark instead of testing the scythe path in a normal combat save.

## Canonical Asset

- Helper mod folder: [`../assets/zzz-severance-array-qc_0.0.1`](../assets/zzz-severance-array-qc_0.0.1)
- Main helper file: [`../assets/zzz-severance-array-qc_0.0.1/control.lua`](../assets/zzz-severance-array-qc_0.0.1/control.lua)

## What It Builds

- A dedicated `severance-array-qc` surface with normal resources and enemies cleared from the authored area
- A `12 x 8` grid of `ei-severance-array` turrets with substations and an electric energy interface
- Dense enemy lanes in front of the turrets, mixing behemoth and big units with static worm/spawner targets
- Periodic enemy top-ups so long benchmarks do not decay into an empty scene too early

The helper also includes a data-final patch that gives `ei-severance-array` a short QC cooldown and low energy pressure. Shipped direct damage is runtime-owned and cached from the force's laser damage modifier; visible endpoint witnesses schedule the hit fire, scorch, sticker, splash, and direct impact, while overload fallback preserves direct alpha without spending extra visual/effect budget. The helper applies a large laser damage modifier to keep the authored scene in the intended extreme-alpha regime without touching shipped source files.

## Important Behavior

- It emits structured `SEVERANCE_ARRAY_QC ...` log lines and mirrors them into `severance-array-qc.jsonl` under script output.
- It exposes its own helper remote interface, `zzz-severance-array-qc`, with:
  - `rebuild(options)`
  - `get_status(label)`
  - `write_report(label)`
  - `spawn_wave(static_only)`
- It probes the main QC remote interface `exotic-industries-qc` for:
  - `reset_severance_array_runtime(reason, tick)`
  - `configure_severance_array_qc(config)`
  - `service_severance_array_qc(limit)`
  - `get_severance_array_qc_snapshot()`
- If those main hooks are missing, the helper still builds the combat scene and records `missing-remote:*` status in the JSONL output.
- Timing validation reads flexible scythe fields from the main snapshot and reports:
  - `target_p95_ms = 1`
  - `aim_p95_ms = 0.5`
  - `p95_under_target`
  - `p95_at_aim`
  - `max_under_target`
- For Factorio builds where `LuaProfiler` is only renderable through the engine log, parse `SEVERANCE_ARRAY_PROFILE ... elapsed=...` lines from `factorio-current.log` for the authoritative active updater timing.

## Staging Steps

1. Copy `assets/zzz-severance-array-qc_0.0.1` into `.factorio-qc/fmqc/mods-live/`.
2. Add or enable the `zzz-severance-array-qc` entry in `.factorio-qc/fmqc/mods-live/mod-list.json`.
3. Create the save with the normal Factorio executable, for example:
   - `factorio.exe --create .factorio-qc\\severance-array.zip --mod-directory .factorio-qc\\fmqc\\mods-live`
4. Keep the helper staged for direct helper-aware playback, for example:
   - `factorio.exe --mod-directory .factorio-qc\\fmqc\\mods-live --disable-audio --benchmark .factorio-qc\\severance-array.zip --benchmark-ticks 3600 --benchmark-runs 1`
5. Inspect the active write-data script output for `severance-array-qc.jsonl`, plus the benchmark stdout for whole-run UPS timing.
6. Disable or remove the helper again before unrelated QC runs.

## Main Mod Hook Contract

The helper can run without main hooks, but p95/max scythe acceptance requires the main mod to expose `exotic-industries-qc.get_severance_array_qc_snapshot()`.

Preferred snapshot shape:

```lua
{
  tick = game.tick,
  scythe_update = {
    sample_count = 123,
    p95_ms = 0.42,
    max_ms = 0.78,
  },
  severance_array = {
    pending = 0,
    pending_damage = 0,
    pending_visual_slices = 0,
    active_visual_jobs = 0,
    native_damage = 0,
    scripted_base_damage = 540,
    impact_effect_delay_ticks = 2,
  },
}
```

`reset_severance_array_runtime(reason, tick)`, `configure_severance_array_qc(config)`, and `service_severance_array_qc(limit)` are optional but recommended for deterministic save generation, profiling enablement, and early warmup snapshots. The helper calls `configure_severance_array_qc({reset = true, qc_enabled = true, profiling_enabled = true})` after building the authored scene.

## Scope

This helper is QC-only. Do not ship it inside the released mod packs.

# Singularity Lance QC Helper

Use this helper when ESIR work needs a dense, repeatable Singularity Lance benchmark instead of testing the weapon path in a normal combat save.

## Canonical Asset

- Helper mod folder: [`../assets/zzz-singularity-lance-qc_0.0.1`](../assets/zzz-singularity-lance-qc_0.0.1)
- Main helper file: [`../assets/zzz-singularity-lance-qc_0.0.1/control.lua`](../assets/zzz-singularity-lance-qc_0.0.1/control.lua)

## What It Builds

- A dedicated `singularity-lance-qc` surface with normal resources and enemies cleared from the authored area
- A `12 x 8` grid of `ei-singularity-lance` turrets with substations and an electric energy interface
- Dense enemy lanes in front of the turrets, mixing behemoth and big units with static worm/spawner targets
- Periodic enemy top-ups so long benchmarks do not decay into an empty scene too early

The helper also includes a data-final patch that gives `ei-singularity-lance` a short QC cooldown and low energy pressure. Shipped direct damage is runtime-owned and cached from the force's laser damage modifier; visible endpoint witnesses schedule the hit fire, scorch, sticker, splash, and direct impact, while overload fallback preserves direct alpha without spending extra visual/effect budget. The helper applies a large laser damage modifier to keep the authored scene in the intended extreme-alpha regime without touching shipped source files.

## Important Behavior

- It emits structured `SINGULARITY_LANCE_QC ...` log lines and mirrors them into `singularity-lance-qc.jsonl` under script output.
- It exposes its own helper remote interface, `zzz-singularity-lance-qc`, with:
  - `rebuild(options)`
  - `get_status(label)`
  - `write_report(label)`
  - `spawn_wave(static_only)`
- It probes the main QC remote interface `exotic-industries-qc` for:
  - `reset_singularity_lance_runtime(reason, tick)`
  - `configure_singularity_lance_qc(config)`
  - `service_singularity_lance_qc(limit)`
  - `get_singularity_lance_qc_snapshot()`
- If those main hooks are missing, the helper still builds the combat scene and records `missing-remote:*` status in the JSONL output.
- Timing validation reads flexible Singularity Lance fields from the main snapshot and reports:
  - `target_p95_ms = 1`
  - `aim_p95_ms = 0.5`
  - `p95_under_target`
  - `p95_at_aim`
  - `max_under_target`
- For Factorio builds where `LuaProfiler` is only renderable through the engine log, parse `SINGULARITY_LANCE_PROFILE ... elapsed=...` lines from `factorio-current.log` for the authoritative active updater timing.

## Staging Steps

1. Copy `assets/zzz-singularity-lance-qc_0.0.1` into `.factorio-qc/fmqc/mods-live/`.
2. Add or enable the `zzz-singularity-lance-qc` entry in `.factorio-qc/fmqc/mods-live/mod-list.json`.
3. Create the save with the normal Factorio executable, for example:
   - `factorio.exe --create .factorio-qc\\singularity-lance.zip --mod-directory .factorio-qc\\fmqc\\mods-live`
4. Keep the helper staged for direct helper-aware playback, for example:
   - `factorio.exe --mod-directory .factorio-qc\\fmqc\\mods-live --disable-audio --benchmark .factorio-qc\\singularity-lance.zip --benchmark-ticks 3600 --benchmark-runs 1`
5. Inspect the active write-data script output for `singularity-lance-qc.jsonl`, plus the benchmark stdout for whole-run UPS timing.
6. Disable or remove the helper again before unrelated QC runs.

## Main Mod Hook Contract

The helper can run without main hooks, but p95/max acceptance requires the main mod to expose `exotic-industries-qc.get_singularity_lance_qc_snapshot()`.

Preferred snapshot shape:

```lua
{
  tick = game.tick,
  singularity_lance = {
    sample_count = 123,
    p95_ms = 0.42,
    max_ms = 0.78,
  },
  singularity_lance = {
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

`reset_singularity_lance_runtime(reason, tick)`, `configure_singularity_lance_qc(config)`, and `service_singularity_lance_qc(limit)` are optional but recommended for deterministic save generation, profiling enablement, and early warmup snapshots. The helper calls `configure_singularity_lance_qc({reset = true, qc_enabled = true, profiling_enabled = true})` after building the authored scene.

## Scope

This helper is QC-only. Do not ship it inside the released mod packs.

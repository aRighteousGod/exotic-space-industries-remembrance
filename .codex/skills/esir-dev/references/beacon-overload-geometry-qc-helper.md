# Beacon Overload Geometry QC Helper

Use this helper for deterministic Factorio 2.0.77 coverage of beacon overload topology, lifecycle events, and receiver geometry.

## Canonical Asset

- Helper mod folder: [`../assets/zzz-beacon-overload-geometry-qc_0.0.1`](../assets/zzz-beacon-overload-geometry-qc_0.0.1)
- Main helper file: [`../assets/zzz-beacon-overload-geometry-qc_0.0.1/control.lua`](../assets/zzz-beacon-overload-geometry-qc_0.0.1/control.lua)

## Coverage

The helper builds 20 isolated layouts on `nauvis` and one temporary-surface layout. It covers:

- machine-first placement followed by the fifth ordinary beacon;
- `LuaEntity.destroy` with and without `raise_destroy`, script mining, and death;
- same-tick remove/re-add, replacement with an excluded beacon, and multi-beacon removal;
- machine-before-beacon destruction ordering;
- weighted, excluded, edge-overlap, long-range, and `uses_beacon_effects=false` cases;
- cloned beacons and machines;
- raised beacon and machine teleports, including old-link release and destination recount;
- a cross-surface raised-event payload simulation;
- cancelled deconstruction;
- temporary-surface deletion;
- overload disable/re-enable, ignored construction and raised teleport while disabled, and legacy graph reseeding through the existing world rebuild.

Factorio 2.0 does not permit building entities to teleport across surfaces. The cross-surface case therefore uses `script.raise_script_teleported` with a different `old_surface_index` after moving the beacon without raising; this exercises ESIR's cross-surface event contract without claiming the engine performed an unsupported building teleport.

## Assertions and Output

The helper registers weighted and excluded beacon rules through the public `exotic-industries` compatibility interface. It reads topology-only QA state through the existing internal `exotic-industries-qc` bridge.

Every stable checkpoint asserts:

- the engine-reported beacon list and count;
- ESIR's weighted count, overload flag, and icon presence;
- machine `active` state;
- exact linked-beacon count, object-destruction registration, and queue membership;
- global beacon, machine, relationship, queue, and registration counters.

The multi-removal scenario also asserts one cumulative machine-queue enqueue. The final tick emits an aggregate record and raises a hard error if any authored action, checkpoint, or invariant failed, so targeted QC cannot silently pass an `all_pass=false` log.

Structured records use the `BEACON_OVERLOAD_GEOMETRY_QC` log prefix and are mirrored to `beacon-overload-geometry-qc.jsonl` when script-output writes are available. The final aggregate is emitted at relative tick `3500`; run at least `3600` ticks.

## Staging and Running

1. Recreate the ignored scenario save after helper topology changes:
   - `factorio.exe --create .factorio-qc\beacon-overload-geometry.zip --mod-directory .factorio-qc\fmqc\mods-live`
2. Run one warm-up plus five measured executions:
   - `powershell -ExecutionPolicy Bypass -File .\scripts\invoke-esir-dev.ps1 -Task runtime-benchmark -SaveId beacon-overload-geometry -WarmupRuns 1 -BenchmarkRuns 5 -BenchmarkTicks 3600`
3. Inspect the aggregate record and structured log for invalid-object errors, stranded icons, non-empty queues, duplicate edges, and stale registrations.

Repo-side runtime benchmarking restages and enables the helper from the save catalog. Disable or remove it before unrelated direct QC runs. This helper is QA-only and must not ship in release mod packs.

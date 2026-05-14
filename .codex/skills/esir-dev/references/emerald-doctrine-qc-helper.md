# Emerald Doctrine QC Helper

Use `.codex/skills/esir-dev/assets/zzz-emerald-doctrine-qc_0.0.1` when a focused Emerald Apocalypse tank doctrine sandbox is useful.

The helper builds a small isolated surface with one Emerald Apocalypse hover tank, ammo, fuel, and behemoth enemies, researches the finite doctrine suite for its QC force, enables the ESIR Emerald tank QC counters, then writes checkpoint snapshots to `script-output/emerald-doctrine-qc.jsonl`.

Remote helpers:

- `remote.call("zzz-emerald-doctrine-qc", "rebuild")`
- `remote.call("zzz-emerald-doctrine-qc", "snapshot")`

The helper is intentionally lightweight. It does not replace in-game feel checks for charge timing, shield reprisal, hover drift, split wake, branch scars, or unsealed impacts; it gives future agents a deterministic bridge into the existing `exotic-industries-qc` Emerald tank runtime snapshot methods.

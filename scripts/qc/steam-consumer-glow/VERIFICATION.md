# Steam consumer glow verification — 2026-10-27

Accepted on Factorio **2.0.77** with live ESIR source at version **1.3.42**.
This task did not change the version. Reproduction is in [README.md](README.md).

## Final data

Three native profiles passed: the pre-fix baseline, fixed source with Pyric
Radiance enabled, and fixed source with Pyric Radiance disabled. The baseline
retains the earlier inserter and pump fix and removes only this task's six new
light fields in private staging.

Final-stage enumeration found exactly ten ESIR fluid energy sources filtered to
ordinary steam; no additional generated variants were present in this mod set.
Both fixed profiles explicitly set minimum and maximum flicker intensity to zero
for all ten. Complete prototype comparison allowed exactly six added
`energy_source.light_flicker` fields: miner, quarry, surface harvester, assembler,
crusher and loader. All ten complete consumer prototypes match between Pyric On
and Off. Consumption, efficiency, emissions, connections, graphics and presentation
definitions compare unchanged against the baseline.

The critical-steam turbine, basic and advanced steam locomotives, and basic
locomotive placement variant compare unchanged across all three profiles.
Their authored lighting remains outside this fix. The miner, quarry and surface
harvester's inherited graphics contain circuit-connector glow layers but no
separate working-light emitter; the connector layers remain intact.

## Native operation and visual review

- **120 state checks passed:** ten entities, working and steam-starved, across
  three headless and three graphical profiles.
- Every working capture reports native `working` status and positive extracted,
  crafted, transferred or pumped output/progress. Every starved capture reports
  `no_input_fluid`, zero energy and zero activity.
- **60 native nighttime screenshots** were captured and visually reviewed through
  two labeled contact sheets. The baseline reproduces the bright working light on
  the miner, quarry, surface harvester, assembler and crusher. Fixed On/Off images
  show no accidental energy-source illumination on any of the ten consumers.
  Working poses and the offshore pump's steam plume remain visible.
- Existing death effects are inherited and verified unchanged for all ten.
  Damage effects, interaction sounds and Factoriopedia definitions are inherited
  and verified unchanged for the nine entities which already have them. The
  steam loader's pre-existing absent damage/audio/scene fields remain absent;
  adding those is intentionally outside this cosmetic fix.
- Scoped `git diff --check`, Python AST parsing and PowerShell syntax parsing
  passed. The native profiles validate the changed Lua in the engine.

These are isolated native machine scenes using original entity graphics and
energy sources. The assembler fixture uses a deterministic item recipe added
after snapshots. Other mods' runtime controls are disabled only in private staging.
This is not full-mod runtime, multiplayer, saved-game or Factoriopedia GUI testing.

## Evidence and harness notes

Task-owned ignored evidence: `.factorio-qc/st-fa0a6cc7/`.
Managed run: `6c96feafa13d487d9e530c8ff5fcc2aa`.
The `script-output/steam-glow/` subdirectory contains the three complete final-data
snapshots, six native-state receipts, `acceptance.json`, 60 PNGs and
`review-1.png` / `review-2.png`.

The initial On graphical invocation produced all screenshots and its fresh native
receipt, then logged a normal automatic exit. Its launcher incorrectly reported
failure because the process handle had not been retained for reading ExitCode.
The runner now retains that handle; the subsequent baseline and Off graphical
invocations passed normally. No native assertion or image was waived.

The standard `qc-fast` wrapper was attempted and remains blocked by an unrelated
old `ml-ba1f9d1d/pycache-final` path, plus existing encoding findings in
`scripts/qc/singularity-lance/angular-results.json` and two `temp/` JSON files.
Failed wrapper run: `404a29f6b7de4c6486bc4f607daf7ab8`. Focused native validation
above passed independently; broad QC is not claimed clean.

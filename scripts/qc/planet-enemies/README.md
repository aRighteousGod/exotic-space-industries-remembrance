# Planetary enemy controls QC

These fixtures run against Factorio 2.0.77 and the resolved ESIR dependency profile.
They are staging-only additions; none belongs in the shipping mod dispatcher.

- `generation.lua` runs unchanged against a frozen pre-change main pack and the
  candidate. It creates unassociated native-settings surfaces, so runtime removal
  cannot conceal a generation defect. Two seeds cover defaults, Off, independent
  zero sliders, low/high frequency and size, extreme combinations and isolation.
  Every case samples 9,409 positions and round-trips native map exchange strings.
  Default, Off and high cases also generate chunks and record nests/territories.
- `runtime.lua` exercises actual creation effects, whole segmented units, vault
  death/player mining/robot mining, egg spoilage and raft death/loot, custom hostile
  forces, existing-enemy preservation, a stale surface, a 2,600-record queue burst,
  serialization and Gaia's full reforge lifecycle.
- `data.lua` captures final control/planet records and selected affected body
  fields. `check.py` compares those against a frozen full data dump, including
  combat, death effects, sounds, Factoriopedia and existing creation effects.
- `isolation.lua` separately compares native Nauvis nest/worm positions with the
  Vulcanus explosive and Aquilo cold controls disabled, across both seeds.
- `engine.ps1` runs the isolated engine with fresh-report checks and a timeout.

V2 adds these focused fixtures:

- `v2-generation.lua` compares all six planet defaults against frozen v1, then
  exercises all six Nauvis families independently and together. Two seeds, nine
  individual variants per family, every high-frequency pair, and three all-family
  combinations produce 156 cases. `check-v2-generation.py` checks exact default
  noise/nests/territories, Off, native exchange strings and mixed-family isolation.
  The approved Factorio 2.0 seed workaround is part of the candidate, not the
  frozen baseline. Original blobs, terrain restrictions and starting exclusions
  remain; only adjusted families' spot seeds change.
- `v2-runtime.lua` exercises all affected bodies, native editor widgets through
  the real dispatcher, validation/conflicts/permissions, pending-to-live targets,
  remembered positive values, exact Toxic infection callbacks, Arachnid terrain
  replacement, explicit summons, migration and bounded owned-raft restoration.
  It is an ordinary benchmark fixture; its local setup is not a reload fixture.
- `v2-persistence.lua` uses a storage-backed phase and a real server checkpoint.
  It preserves the raft restoration queue, an unsubmitted draft and sparse future
  planet overrides, then checks native creation and Gaia's in-flight revision
  merge. It also writes and reads back every global editor field.
- `shared-snappers.lua` runs with `ab-enable-nest=false`, verifies shared ordinary
  nests still contain snappers and that ordinary policy governs their births,
  and exports final data for the complete roster/weight comparison.

Prepare isolated directories with `scripts/invoke-control-ups-qc.ps1 -PrepareOnly`,
following the repository housekeeping registration contract. Use a frozen main
pack as `-BaselineSource`, the desired main pack as `-SourceRoot`, and an installed
dependency seed containing enabled Graphics 6. Pass `-BridgePath` with the fixture.
The runtime fixture requires `-CaptureConfiguration` to preserve the original load
handler; append `data.lua` to the staged main pack's `data-final-fixes.lua` too.
For `v2-runtime.lua` and `v2-persistence.lua`, enable the administration startup
gate only in the isolated staged settings file. A forced bool setting must also
be hidden in Factorio 2.0.77. For `shared-snappers.lua`, similarly force and hide
`ab-enable-nest=false` only after asserting production left it selectable.

```powershell
# Native generation: run once per isolated baseline/candidate directory.
powershell -ExecutionPolicy Bypass -File scripts/qc/planet-enemies/engine.ps1 `
  -RunDirectory <run> -Mode runtime -Tag generation -Ticks 200 `
  -Report planet-enemies-generation.json

# Lifecycle, then reload the save made while removals are pending.
powershell -ExecutionPolicy Bypass -File scripts/qc/planet-enemies/engine.ps1 `
  -RunDirectory <candidate-runtime-run> -Tag lifecycle -Ticks 1800
powershell -ExecutionPolicy Bypass -File scripts/qc/planet-enemies/engine.ps1 `
  -RunDirectory <candidate-runtime-run> -Mode save -Tag checkpoint
powershell -ExecutionPolicy Bypass -File scripts/qc/planet-enemies/engine.ps1 `
  -RunDirectory <candidate-runtime-run> -Tag reload -Ticks 1800 `
  -SavePath <candidate-runtime-run>/saves/planet-enemies-pending.zip

python scripts/qc/planet-enemies/check.py <baseline-generation.json> <candidate-generation.json> `
  --snapshot <planet-enemies-final-data.json> --baseline-dump <baseline-data-raw-dump.json> `
  --output <acceptance.json>

# V2 generation: frozen v1 produces 12 default cases; v2 produces 156 cases.
powershell -ExecutionPolicy Bypass -File scripts/qc/planet-enemies/engine.ps1 `
  -RunDirectory <v2-generation-run> -Ticks 160 -Tag v2-generation `
  -Report enemy-v2-generation.json
python scripts/qc/planet-enemies/check-v2-generation.py <v1-defaults.json> `
  <v2-generation.json> <v2-generation-checks.json>

# V2 editor and persistence use separate staged bridges.
powershell -ExecutionPolicy Bypass -File scripts/qc/planet-enemies/engine.ps1 `
  -RunDirectory <v2-runtime-run> -Ticks 30 -Tag v2-runtime -Report planet-enemies-v2.json
powershell -ExecutionPolicy Bypass -File scripts/qc/planet-enemies/engine.ps1 `
  -RunDirectory <v2-persistence-run> -Mode save -Tag v2-checkpoint
powershell -ExecutionPolicy Bypass -File scripts/qc/planet-enemies/engine.ps1 `
  -RunDirectory <v2-persistence-run> -Ticks 1800 -Tag v2-reload `
  -SavePath <v2-persistence-run>/saves/planet-enemies-pending.zip `
  -Report enemy-v2-persistence.json
```

Native menu interaction is a separate check. Resolved prototype records and
exchange-string round trips do not establish the visual layout or mouse behavior.
See [verification.md](verification.md) for the recorded implementation run.

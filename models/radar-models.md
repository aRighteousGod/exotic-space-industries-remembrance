# Sweeping radar model sources

These are the approved **#1 / E1 Split-Trough Watcher** and **#8 / S4 Fourfold
Interrogator** models. The GLBs preserve maximum-detail Meshy geometry and embedded
textures. The Blender files contain the prepared fixed-base/rotating-upper rigs;
the Phased-array file also contains white-panel and red-core emission.

| Chassis | Original GLB | Prepared animated Blender model |
|---|---|---|
| Sweeping radar | [sweeping-radar.glb](sweeping-radar.glb) | [sweeping-radar.blend](sweeping-radar.blend) |
| Phased-array radar | [phased-array-radar.glb](phased-array-radar.glb) | [phased-array-radar.blend](phased-array-radar.blend) |

Only these four paths use Git LFS. Install Git LFS and run `git lfs pull` after
cloning if they contain pointer text instead of model data. No existing model
history is migrated. File sizes, SHA-256 hashes, mechanical partitions and
self-contained/rotation verification are in [radar-models.json](radar-models.json).

The original working files remain under ignored `output/meshy/`. To restore the
generator's expected layout from a fresh checkout, run from the repository root:

```powershell
foreach ($radarAsset in 'sweeping-radar','phased-array-radar') {
    $radarRoot = Join-Path 'output/meshy' $radarAsset
    New-Item -ItemType Directory -Force -Path "$radarRoot/source","$radarRoot/prepared" | Out-Null
    Copy-Item "models/$radarAsset.glb" "$radarRoot/source/attempt-01.glb"
    Copy-Item "models/$radarAsset.blend" "$radarRoot/prepared/$radarAsset.blend"
    $radarManifest = Get-Content models/radar-models.json -Raw | ConvertFrom-Json
    $radarEntry = $radarManifest.assets | Where-Object asset -eq $radarAsset
    $radarSplitJson = $radarEntry.mechanical_split | ConvertTo-Json -Depth 12
    [IO.File]::WriteAllText((Join-Path $radarRoot 'prepared/mechanical-split.json'), $radarSplitJson, [Text.UTF8Encoding]::new($false))
}
```

The continuous rotor cycle spans frames 1–64 and closes at 65. The fixed base
and visible lower cables remain stationary. Both files were opened in Blender
5.1 from this directory, checked for embedded textures and external libraries,
and tested for fixed-base transforms, rotor movement and loop closure.

The [asset dossier](../.codex/esir/asset-generators/sweeping-radar/README.md)
documents generation, preparation, 256-facing rendering, repacking and known
review limits. Superseded #3, raw frame sets and the render archive remain local.
These model sources do not change the shipping prototypes' placeholder art.

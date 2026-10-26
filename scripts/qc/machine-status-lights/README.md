# Production machine lighting acceptance

Run `scripts/invoke-machine-status-light-qc.ps1 -Phase Stage` from the repository.
The returned short managed directory is supplied as `-RunDirectory` below:

Stage regenerates lens masks into the managed `lens-art/` evidence directory and
compares their hashes with the shipping masks. It does not promote or alter art.

```powershell
foreach ($mode in @('baseline', 'original', 'status', 'off')) {
    powershell -ExecutionPolicy Bypass -File scripts/invoke-machine-status-light-qc.ps1 -Phase Data -Mode $mode -RunDirectory <run>
}
foreach ($bnl in @('disabled', 'enabled', 'custom')) {
    foreach ($mode in @('baseline', 'original', 'off', 'status')) {
        powershell -ExecutionPolicy Bypass -File scripts/invoke-machine-status-light-qc.ps1 -Phase Data -Mode $mode -Bottleneck $bnl -RunDirectory <run>
    }
}
foreach ($arc in @('off', 'static', 'soft', 'reduced')) {
    powershell -ExecutionPolicy Bypass -File scripts/invoke-machine-status-light-qc.ps1 -Phase Data -Mode status -ArcPreset $arc -Focus smelters -RunDirectory <run>
}
powershell -ExecutionPolicy Bypass -File scripts/invoke-machine-status-light-qc.ps1 -Phase Visual -Mode status -RunDirectory <run>
powershell -ExecutionPolicy Bypass -File scripts/invoke-machine-status-light-qc.ps1 -Phase Visual -Mode off -RunDirectory <run>
powershell -ExecutionPolicy Bypass -File scripts/invoke-machine-status-light-qc.ps1 -Phase Visual -Mode original -RunDirectory <run>
powershell -ExecutionPolicy Bypass -File scripts/invoke-machine-status-light-qc.ps1 -Phase Visual -Mode status -ArcPreset off -Focus smelters -RunDirectory <run>
powershell -ExecutionPolicy Bypass -File scripts/invoke-machine-status-light-qc.ps1 -Phase Finish -RunDirectory <run>
```

`-SeedMods` on Stage copies a private dependency seed without mutating it. Only
immutable assets and archives without runtime controls share file storage. Main
pack sources and mutable controls receive private copies, then the main pack is
refreshed from the live repository. This is suitable for retained prior QC seeds.

`-PreparedMods` on Stage reuses a **task-owned private QC staging directory** via
a short junction. It refreshes the main pack and isolates staged runtime controls;
it must never point at a player's installation, shared dependency seed, or source.
The short path avoids the long `require` failures of deeper Windows QC staging.
Keep the supplying run protected while the junction is in use. Runtime can retry
an existing save after a fixture-control correction without repeating creation.

The baseline disables both the early Bottleneck hook and the finalizer in the staged main pack. Each real
startup mode is then selected through the companion's settings stage. Before any
fixture recipe adapter, final data records complete prototypes for 28 targets,
6 present excluded bodies, and 2 preserved absences in the current default profile.
The checker compares every remaining field, including energy, animations, process
glows, death effects, interaction sounds, and Factoriopedia scenes.

The runtime fixture retains native machine IDs, speed, graphics, energy sources,
and fluid boxes. Only categories/fixed recipes are adapted to a deterministic short
item recipe after the snapshot. Other mod controls are disabled in copied staging.
This isolates native lighting; it is not multiplayer or full-mod runtime acceptance.

Each building is placed in seven state columns (left to right): working, no recipe,
missing input, full output, script-disabled, no energy, low power. Non-electric
machines omit low power. Rows request north/east/south/west. Some native machines
normalize those requests to north; reports record the actual direction and require
it to match the unmodified baseline. There are 764 state/placement cases per mode.
Power is supplied through the actual energy source: bio matter for the bio reactor,
heat for the HTR, coal for the burner assembler, steam for the two steam machines,
and isolated electrical networks, with a deliberately limited supply for low power.

After steady captures, the 20 indicator bodies undergo real circuit disable/resume
and energy loss/restoration, output blockage/recovery, and electrical shortage/recovery,
giving 156 transition checks per mode. Graphical runs
record native status again at capture time. Status produces 112 day/night atlases
at normal and double zoom, plus 156 night transition images. Off and Original each
produce 28 normal-zoom night atlases for pixel comparisons. Captures require the
graphical executable; headless execution does not establish their appearance.

Review indicator alignment, the paired neutral lenses, green/red/yellow/orange
colors and size from the native captures, and compare
Status against Off to establish darkness without energy, including no fuel and
low temperature. The checker requires fresh, decodable captures. Static/final-data
assertions alone cannot prove that a light is visible, centered, or correctly colored.

Status also captures a brightness comparison against Assembler-Reskin's native
AM1/2/3 additive status sprites. Five representative bodies at five intensities,
working and idle, yield 80 cases and four day/night/zoom images. Run `calibrate.py`
with the run directory to crop the actual rendered lamps and measure their cores.

`-Bottleneck absent|disabled|enabled|custom` selects isolated compatibility profiles.
The installed 2.0-compatible archives are pinned to BNL 1.3.4 and flib 0.16.5.
Run Data baseline/original/off/status for each profile, then `check-bottleneck.py`
with the run directory. Profile names prevent evidence overwrites. The custom
profile forces all BNL colors cyan; ESIR's own fixed palette must remain unchanged.
Fixture boolean/color settings are hidden so Factorio honors their forced values;
the final-data fixture asserts the actual BNL enable value before saving evidence.
The helper captures flags during data-updates and seeds an unrelated preexisting
ignore flag. Baseline comparisons subtract only expected lights/lenses and BNL's
omitted indicators. Native power fixtures use actual isolated networks, because
filled buffers alone do not establish the renderer's satisfied-power state.

Stage freezes the data entrypoints from the private main-pack snapshot. Later
phases refresh only this subsystem's source and assets; concurrent unrelated
checkout edits must not change one side of a comparison. Re-stage deliberately
when changing that baseline. Captures require sufficient GPU/RAM and optional
atlas-cache space; private staging defaults to `cache-sprite-atlas=false` to avoid
large disk cache writes.
The graphical benchmark allows 1600 frames and rejects a clean exit
without a freshly written final transition receipt. `-TransitionsOnly` retries
transition captures while preserving already complete scene atlases; use a full
Visual pass after changing lens assets. Screenshot writes are serialized to bound
GPU/memory use. Finish requires the compatibility and arc-preset profiles above.
The fixture disables Freeplay's intro and exits its initial cutscene on the first
tick. Otherwise the welcome dialog pauses graphical playback around tick 720,
preventing later output/power transitions despite successful headless checks.
The source methods differ, so compare perceived readability as well as brightness;
an emitted glow cannot reproduce an additive sprite exactly.

## Smelter extension

Pass `-Focus smelters` to every phase to limit runtime scenes to the arc furnace,
plasma heater and molten-metal caster while retaining final prototype comparisons
for all 28 targets. Furnaces select their recipe natively and report `no_ingredients`
when empty; the caster retains the assembler's explicit recipe semantics.

Run Data for baseline, Original, Status and Off with the default arc preset. Then run Data
for Status with each `-ArcPreset off`, `static`, `soft`, and `reduced`. This covers
seven native profiles, 588 state cases and 168 transition checks when all use
smelter focus. The full-matrix recipe above retains 764 states/156 transitions
for its three main modes and 84/24 for the four extra arc presets.
Visual is required for Status/default arc, Status/arc Off and Off/default arc:
75 images including 48 transition snapshots. Inspect the generated `review/`
body, lamp and transition sheets before Finish. Finish runs `check-smelters.py`
and `review-smelters.py` and closes the managed record only after both pass.

This focused pass verifies all five arc presets and all three production modes;
it does not claim to execute the full 15-combination Cartesian product. The full
28-body runtime fixture remains available with the default `-Focus all`.

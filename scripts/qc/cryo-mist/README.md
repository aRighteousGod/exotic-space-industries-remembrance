# Cold mist acceptance

The focused fixture uses Factorio 2.0.77 with real Nonstandard Beacons 1.4.2
control code. Other dependency and ESIR runtime controls are isolated in private
copies. This proves native mist state/lifecycle, not whole-mod runtime or multiplayer.
The live main pack is refreshed on every invocation. Existing dependency assets
are read-only seeds; incompatible optional Minigun 2.1 packs are disabled.

Register a fresh short payload using `Register-EsirArtifactRun` from
`scripts/esir-housekeeping.ps1`, then copy a compatible dependency seed using
`scripts/qc/machine-status-lights/stage.py <seed> <run>/m`. Before modifying the
production sources, preserve their original relative paths under `<run>/baseline`:
`data-final-fixes.lua`, `prototypes/computer-age/cooler.lua`, and
`scripts/data-final-updates/{fuel-glow,entity-presentation-machines}.lua`.
The baseline is task-specific pre-change evidence, not arbitrary Git HEAD.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-cryo-mist-qc.ps1 -RunDirectory <run> -Phase Data -Mode baseline
powershell -ExecutionPolicy Bypass -File scripts/invoke-cryo-mist-qc.ps1 -RunDirectory <run> -Phase Data
powershell -ExecutionPolicy Bypass -File scripts/invoke-cryo-mist-qc.ps1 -RunDirectory <run> -Phase Runtime
powershell -ExecutionPolicy Bypass -File scripts/invoke-cryo-mist-qc.ps1 -RunDirectory <run> -Phase Reload
powershell -ExecutionPolicy Bypass -File scripts/invoke-cryo-mist-qc.ps1 -RunDirectory <run> -Phase Visual
powershell -ExecutionPolicy Bypass -File scripts/invoke-cryo-mist-qc.ps1 -RunDirectory <run> -Phase Check
```

Snapshots compare entire affected prototypes and selected unaffected consumers,
including recipes, body art, energy sources, death effects, hit effects and sounds.
Only mist, the removed lights and narrowly specified preview changes may differ.
There are 28 native placements: all requested stopped states, working cardinal
orientations, beacons without modules, and a six-beacon compact group. Transitions
cover input loss/restoration, disable/deconstruction/cancel, power loss/restoration,
and actual NSB helper cleanup. Runtime uses a private localhost server to write a
real working checkpoint (benchmark mode suppresses saves);
Reload opens it and asserts the stored state and native helpers still work.

The three exact production Factoriopedia init/update strings execute in separate
native surfaces with only a camera/surface facade. A freshly created force must
enable the nitrogen recipe for the furnace to select it; the hypercooler preview
also replenishes its electric buffer and nitrogen input and clears its output.
The scene keeps its original recipe, camera and body. These captures establish
native scene contents, not the encyclopedia window or navigation.

Graphical acceptance includes 61 samples over a full 400-tick mist loop for every
body and the group, by day and night (488 loop captures), plus steady states,
transitions and previews. Check produces eight animated WebP reviews and a static
day/night sheet under `<run>/review`. Inspect these before closing the managed run.
The source PNG remains byte-identical; review crops/animations are evidence only.
The disposable render configuration uses high graphics quality with low video-memory
usage and texture compression. After recording the full final snapshot, the visual
fixture blanks unrelated ESIR sprites to keep atlas memory bounded. The five cooling
bodies retain their exact final graphics, including antennas, shadows and pipes;
terrain and UI stay intact. Shipping files and native gameplay fields are untouched.

The sheet deliberately ships in the main gameplay mod for now. See its
`CREDITS.md` for Cryo-container/snouz and Hurricane046 attribution, source commit,
graphics license as published upstream, and SHA256. No refrigerator dependency,
code, chest, audio, new gameplay helper, runtime handler or state is imported.

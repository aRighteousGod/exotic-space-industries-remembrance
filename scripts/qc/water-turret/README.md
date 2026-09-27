# ESIR firefighting acceptance

Run against installed Factorio **2.0.77**. `invoke-water-turret-qc.ps1` stages a copied
gameplay pack, linked dependency archives and graphics companions under
`.factorio-qc/wtr/`. It never changes the installed mod list or original saves.
The standalone `extinguisher` is enabled only in the old baseline profile.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-water-turret-qc.ps1 -DumpOnly
powershell -ExecutionPolicy Bypass -File scripts/invoke-water-turret-qc.ps1
powershell -ExecutionPolicy Bypass -File scripts/invoke-water-turret-qc.ps1 -PlayerSave -SaveInput '<disposable player save>' -RunName player
powershell -ExecutionPolicy Bypass -File scripts/invoke-water-turret-qc.ps1 -Performance -1
powershell -ExecutionPolicy Bypass -File scripts/invoke-water-turret-qc.ps1 -Performance 1000
powershell -ExecutionPolicy Bypass -File scripts/invoke-water-turret-qc.ps1 -Muzzle -RunName muzzle
powershell -ExecutionPolicy Bypass -File scripts/invoke-water-turret-qc.ps1 -Visual -RunName visual
```

`-ReuseFixture` skips creation of an existing untouched fixture save; benchmark
mode never writes its runtime changes back. Performance profiles use an actual
electrical grid and record only the water module's update time over 6,000 warmed
ticks in `script-output/water-profile.txt`. Run timing profiles separately from
other Factorio work. `-1` is the empty-registry comparison.

The runtime cases cover native enemy acquisition, zero damage, friendly exclusion,
single/repeated/expired slow, measured water consumption, mode priorities,
launch-time fire policy, one impact per pulse, acid exclusion, manual extinguisher
impact, circuit disable/enable, input refilling while combat is script-disabled,
both independently fed grid ports in all four placed directions, unchanged
connections during head aiming, rejection of an adjacent wrong-row pipe,
quality range, blackout reserve, clone preferences, helper repair and teleport,
teardown, and configuration rebuild. The player profile additionally exercises
real relative GUI elements through the production handlers, settings paste,
blueprint tags and ghost revival, stale elements and foreign-force editing.
It is an automated handler/widget check, not a visual or mouse-input test.

## Save transitions

The development baseline is preserved in
`.factorio-qc/wtr-baseline-source/exotic-space-industries-remembrance`.
It was copied from the dirty working pack before the water implementation, then
only the seven early extinguisher ownership edits were reversed. This retains
unrelated in-progress work; a clean `git archive` would not be equivalent.
The source extinguisher archive is `extinguisher_2.0.0.zip`; its SHA-256 and asset
provenance are recorded in the shipping extinguisher graphics directory.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-water-turret-qc.ps1 -Baseline -Save
powershell -ExecutionPolicy Bypass -File scripts/invoke-water-turret-qc.ps1 -SaveInput '.factorio-qc/wtr/old/saves/water-transition.zip' -Save
powershell -ExecutionPolicy Bypass -File scripts/invoke-water-turret-qc.ps1 -SaveInput '.factorio-qc/wtr/new-load/saves/water-transition.zip' -RunName reload
powershell -ExecutionPolicy Bypass -File scripts/invoke-water-turret-qc.ps1 -Save -RunName water-save
powershell -ExecutionPolicy Bypass -File scripts/invoke-water-turret-qc.ps1 -SaveInput '.factorio-qc/wtr/water-save/saves/water-transition.zip' -RunName water-reload
powershell -ExecutionPolicy Bypass -File scripts/invoke-water-turret-qc.ps1 -SaveInput '.factorio-qc/wtr/water-save/saves/water-transition.zip' -ForceConfig -RunName water-config
```

Saving uses a temporary private local server because benchmark mode cannot
persist changes. The runner stops only the process it launched after its saved
ZIP is readable. The migration asserts equipped/loose/stored items, quality,
exactly 37 rounds remaining in partial canisters, recipe assignments, researched
and unresearched forces, removal of old residue, and removal of the external mod.
The new migration filename is absent from the old snapshot.

The muzzle profile calibrates an explicit stream origin, then isolates barrel
length, center shift, delivery offset and the final model values in eight aim
directions. Native impact events report the source entity position; launch
effects report the elevated/projected muzzle. Final geometry assertions use
the latter, including the pivot height in the aiming vector, within 0.02 tile.
The visual profile runs the graphics benchmark with the local Steam client and
takes eight screenshots of four base placements connected to ordinary pipes.
Only its own benchmark process is managed; unrelated Factorio processes remain
untouched. Screenshots are under `script-output/water-art/`.

Reports are `script-output/water-qc.json`. All cases must pass; engine failures
are fatal. Lifecycle rebuilds use the current game tick only where the engine
provides no event tick (`on_init` / `on_configuration_changed`); ordinary event
handlers pass their event tick through. Normal reload and forced configuration
reload both verify that scheduled power guards resume.

## Art handoff

Gameplay is now wired to the generated base/head, shadow and owner-mask sheets.
The selected reference is `output/meshy/water-turret/concepts/09-pipework-bastion-v2.png`:
the left backpack pipe enters the circular platform. The latest user decision
makes that platform, backpack, pipe and head one rotating assembly; only the
structure below the platform and external pipe connections remain stationary.
Final art must replace the temporary layers, retain separate
stationary base / 64-direction upper assembly / shadow / neutral owner-color mask roles,
and agree with the stream muzzle position. Run asset checks after promotion.
Both 2x2 and 3x3 models were prepared; 3x3 was selected for centered side ports
and readable platform detail. The current grid acceptance fixture covers 3x3,
with native engine-positioned collars and covers. Earlier 2x2 evidence is retained
under the `ports` run; the selected layout passed again under `ports-3x3`.

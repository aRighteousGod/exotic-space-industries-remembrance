# Administration integration QC

Use the installed Factorio **2.0.77** engine and a disposable seed with a real
connected player. Factorio's runtime API cannot manufacture LuaPlayers.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-admin-tools-qc.ps1 `
  -RunName lifecycle -PlayerSave .factorio-qc/wtr/final-player/fixture.zip -Ticks 1200
powershell -ExecutionPolicy Bypass -File scripts/invoke-admin-tools-qc.ps1 `
  -Disabled -RunName disabled -PlayerSave .factorio-qc/wtr/final-player/fixture.zip
```

The driver copies current gameplay sources and the seed into ignored staging,
adds an isolated fixture bridge, and checks the resulting JSON. It never updates
the source save or installed mod list. Its setup deliberately changes a disposable
force, creates surfaces/entities, completes research, and reforges fixture Gaia.
Do not install the helper in a valuable save.

`control.lua` covers default gating, legacy command availability, authorization,
all twelve page constructors, and two invocations of every registered repair.
[PRESERVATION.md](PRESERVATION.md) distinguishes this broad invocation coverage
from actual active-state preservation probes in `preservation.lua`.

`features.lua` tests native infinite/finite research, repeated explicit infinite
selection, actor demotion before queued work, prototype-disabled research,
existing/new/nonplanet peaceful defaults, actual Gaia reforge policy restoration,
native pollution/spores and all eight exposed rupture variants at 20/100/500 MJ.
Its native iron-chest victims can take fire damage; stone walls are intentionally
unsuitable because their native fire resistance can completely prevent it.
`defaults-and-position.lua` verifies that promotion/opening leaves native modes
off, preserves dragged window position through refresh/navigation/recreation,
and services/cancels optional visible-only auto-refresh timers and intervals.
`targeting.lua` checks real remote-controller/cursor/ghost restoration and manual
self-teleportation, cancellation and demotion during selection.

`camera.lua` covers native target validation, explicit zoom controls and permission
loss cleanup. `placement.lua` verifies item grants into full/partly full inventories,
quality and force through steam placement wrappers, native rail identity and
collision-safe ordinary placement. `world-gui.lua` and `world-callbacks.lua` test
the active job chooser, pollution presets, resource yield readouts, dynamic planet
rows and synchronous build-callback cancellation/demotion. The permission fixture
checks deletion of a native restriction overlay and later external group ownership.

The test completes only when the final staged feature checks have drained. Results
are under `.factorio-qc/admin-<RunName>/script-output/admin-qc.json`; setup/timing
logs accompany them. Fixture timing includes deliberate setup and is not a UPS
measurement. `-Visual` can capture full-mod screenshots with isolated complete
graphics archives, but a benchmark-graphics run retains the seed's native display
dimensions; use the dedicated responsive client fixture for exact resolution and
scale acceptance.

Additional focused fixtures:

- [Player state and genuine offline recovery](../admin-tools-player/README.md).
- [Bounded world work and iterator save/load](../admin-world/README.md).
- Populated whole-engine comparisons use `scripts/invoke-control-populated-benchmark.ps1`
  with matching uninstrumented profiles and alternating warmup-discarded runs.

All reported scopes must distinguish native connected-player lifecycle coverage,
rendered visual checks, multiple-viewer behavior, GUI work counts and whole-engine
timing. A single saved native player does not prove two-player multiplayer.

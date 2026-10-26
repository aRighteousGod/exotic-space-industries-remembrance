# Rocket launch pollution acceptance

Run from the repository root with the installed Factorio **2.0.77** client:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-rocket-pollution-qc.ps1 -SaveReload
```

The runner uses the existing control-UPS staging helper and local dependency seed
(`.factorio-qc/wtr/player/fixture.zip` and `.factorio-qc/fmqc/mods-live`). It copies
the current gameplay source, enables Graphics 6, excludes the optional Minigun HD
sidecar, and registers a short managed output directory. Native filesystem aliases
keep the graphical loader below Windows path limits. No installed mod or player
save is changed. Each engine process has private write-data and mods directories.

`control.lua` launches real rockets on separate surfaces and a shared surface.
The staged-only bridge instruments actual `pollute` and `create_trivial_smoke`
calls. Physical pollution deltas and native source statistics must agree; graph
updates made during a completion event are checked on the following tick, when
the engine flushes statistics.

The scenarios cover all four visual styles, all five pollution curves, zero
pollution, repeated and concurrent launches, destruction before ignition/during
engine start/during flight/after silo closure/during confirmed pad smoke, slow
and fast rockets, admin repair, three legacy queue forms, late legacy adoption,
confirmation without a silo, missing ordered records, and a lost pending index
with a paid ledger retained by smoke. An injected mismatched order while a real
rocket is airborne checks detached ownership and replacement rejection. This
last identity test is controlled interference, not a second native rocket in
the same silo: forcing early native reconstruction violates a 2.0.77 engine
assertion. Ordinary native repeated launches and concurrent silos are separate
scenarios.

Every tick checks source statistics against physical emissions. Ordered launches
must produce no particles or pollution before ignition; emission starts with
exactly one tick's share, follows the cumulative ten-tick target, and settles to
the captured budget at confirmation. Interrupted launches cannot produce further
particles or emissions. Legacy orphan jobs are retired. Retaliation is checked
under Impossible difficulty on ordinary, peaceful, and no-enemies surfaces.

`-SaveReload` starts a private local server on `127.0.0.1:34449`, saves checkpoints
before ignition, during emission, and after confirmation, then replays each to
completion. This validates serialization and shared-record identity; it does not
claim a multiplayer peer/desync test. Only task-owned processes are stopped.

For graphical acceptance, add `-Visual`. The isolated client captures ignition
frames and opens the native production window. Select its **Pollution** tab and
inspect the rocket-part icon, localized heading, and graph trace. Screenshots and
`ready.json` appear under `n/script-output/rocket-visual`. After actual review,
write `n/visual-reviewed.json` containing the findings; the runner waits up to ten
minutes, then closes its client. A headless report cannot substitute for this
review. Completed runs are registered and closed through normal retention.

`verification.md` records the accepted run, event timings, and evidence limits.

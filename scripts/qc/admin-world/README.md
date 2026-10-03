# Admin world native acceptance fixture

Run `powershell -ExecutionPolicy Bypass -File scripts/invoke-admin-world-qc.ps1`.
The default seed is the ignored `.factorio-qc/wtr/final-player/fixture.zip`; use
`-SeedSave <path>` for another disposable save containing a real player at index 1.
Factorio cannot create LuaPlayers through the runtime API. The seed is copied and
never modified in place.

The driver stages live sources, a minimal Space Age test mod, an isolated config
and write-data root under `.factorio-qc/admin-world`, and local-only server port
34391. It saves an active iterator job, closes only its owned headless process after
the checkpoint ZIP is complete, then reloads that save for 1,000 benchmark ticks.
Use `-Mode stage|server|reload` for individual phases. Results and copied Lua hashes
stay in the ignored run directory. Fixture timings are not a whole-factory UPS claim.

The fixture uses native surfaces, forces, entities, fluids, chunk requests, charts,
LuaChunkIterator objects and the existing real player. Dispatcher saturation clones
already-admitted jobs solely to reach global limits; it does not prove concurrent
multi-player admission or GUI behavior. Renamed vanilla fire/smoke prototypes keep
the fixture small; visual parity with full ESIR is outside this fixture. A native
off-grid collision-free container prototype supplies distinct targets for the
rupture admission limit; production creates no helper entity.

See [ACCEPTANCE.md](ACCEPTANCE.md) for the observed 2.0.77 results and scope.

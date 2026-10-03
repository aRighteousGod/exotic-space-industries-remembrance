# Native runtime GUI verification

Final functional run: **28/28 checks passed** on installed Factorio **2.0.77**. This uses one actual connected player retained from `.factorio-qc/wtr/final-player/fixture.zip` with `--benchmark --disable-migration-window`.

The current shipping source was replayed on **2026-10-02** in a fresh
`.factorio-qc/cu/g/agfinal2` profile: **28/28 checks passed**, with one connected
native player. Evidence is its `script-output/admin-gui-native.json`,
`native-stdout.txt`, `manifest.json` and `staged-only-changes.json`. This replay
includes the neutron per-pass shared snapshot and the final neutron/matter
closed-viewer early returns. Native panel opening and all existing assertions
still pass; it does not directly count neutron/matter assignments or establish
two simultaneous viewers.

| Current replay source | SHA-256 |
| --- | --- |
| Neutron collector | `AAC36AC0275F5965B9E89961A00952D2B5C4A1C322811F2495832455D8E11D1D` |
| Matter stabilizer | `32CBF40C8E3C5271F64BC8FEE8E42DE3A6F0C8C014A94A7B7665557C3AE47614` |

Both source hashes matched shipping and the tested copies. The previous replay
in `agfinal` passed27/28: its sole failure was the fixture's obsolete
`session.diagnostic_text` assertion after diagnostics became structured native
labels. The corrected fixture checks a valid overview and the role label;
shipping diagnostics code was unchanged. Both runs remain retained. Staged-only
admin enablement and the radar overlay export follow the replay instructions
below. All functional setup remains excluded from performance evidence.

This 19-owner replay predates the subsequent console position/auto-refresh
changes. Those console changes passed the separate final 362-check integration
and 65-check native responsive fixtures; the existing GUI owner sources above
were unchanged by that follow-up.

Evidence:

- `.factorio-qc/cu/g/admin-gui-native-v1/script-output/admin-gui-native.json`
- `.factorio-qc/cu/g/admin-gui-native-v1/native-fifth-stdout.txt`
- Replay bridge: `scripts/qc/admin-tools/gui-native.lua`
- Staged source/dependency manifest: `.factorio-qc/cu/g/admin-gui-native-v1/manifest.json` (records initial staged source; subsequent test-only edits and the two spider corrections are described below).

The fixture covers all **19 existing GUI owners**, plus the new administration console and camera helper. Native entity GUI routes open fueler, matter, neutron, auric, black-hole, gate, combustion, fusion, railgun, orbital scanner, orbital logistics, Emerald Apocalypse, water turret, spider vehicle and radar panels. Matrix opens through its actual wire proxy, crystal through its detached native-shell readout, alien confirmation through its owner callback, and EM through its persistent panel entry point.

Measured assertions include:

- Closed EM dirty refresh calls the registry-summary provider **zero times**.
- Closed black-hole and matrix GUI refresh calls perform **zero snapshot queries**, including matrix capacity, stored power and max-I/O getters.
- Open EM dirty refresh calls it **once** for the one native viewer; a second updater call with no dirty work adds no summary call.
- Water and spider control changes retain the same native GUI root object and update controls correctly.
- All 12 administration pages build successfully; untouched defaults enter drafts, quality selector defaults are populated, read-only diagnostics works, and drafts/root survive page navigation.
- Radar unchanged geometry/heading retains the same valid coverage and beam rendering objects. Changed beam heading replaces only its beam objects while retaining coverage. Closed radar GUI reports no tick work.
- Camera binds directly to a real native entity and owner-scoped close destroys its root and removes its window record.

Native execution exposed two spider edge cases missed by syntax parsing:

1. A child named `locked` conflicts with the built-in `LuaGuiElement.locked` property. `output/gui-native-fixes.patch` renames it `locked_note`.
2. An upstream assault chassis can expose extra ammo slots before queued replacement, so `catalog.slot_group` can return nil. `output/gui-spider-slot-fix.patch` uses its native chassis label for unclassified slots while retaining actual numeric indices. The final run deliberately opens that upstream chassis and passes.

The first and second failure JSONs remain alongside `third-results.json` (22/22 pass before adding four more owner checks). The only fixture bug was a geometry require attempted after load; it was moved to top-level parsing. Staged test instrumentation exports radar overlay refresh and sets admin startup default true; shipping source was not edited by this sidecar.

Limits: this is headless engine-backed lifecycle/API/identity coverage, not visual/mouse review, two-player multiplayer testing, or a proof that all 19 owners perform zero GUI assignments in every idle condition. The two-viewer shared-summary behavior is source-audited. A separate local LAN attempt initialized two clients, but the installed Steam build bound both to one Steam identity and the second replaced the first; it did not establish two simultaneous viewers. Functional timing includes setup and must not be cited as UPS performance. The completed uninstrumented comparison is documented in `POPULATED-BENCHMARK.md`: baseline median15.602265ms/tick versus frozen candidate15.615204ms/tick (+0.083%), with overlapping ranges and mixed paired directions. It did not demonstrate a consistent whole-factory UPS improvement. Its disabled-toolkit/no-open-panel scope and later inactive follow-ups are stated explicitly.


## Source audit of all existing runtime GUI owners

This is a source audit of scheduling and refresh behavior, separate from the native assertions above. The existing runtime owners were inspected against their live code and conceptual blueprints; generated inventories were used only as maps.

| Owner | Refresh contract reviewed |
| --- | --- |
| EM trains | One scalar summary per viewed surface per dirty fanout; display signature; no registry summary without an open panel. |
| Water turret | Event-driven preferences; retains same-entity root and named controls. |
| Spider vehicles | Same native entity and slot layout retains root; displayed signature and optional readout visibility; native proxy/chassis replacement rebuilds. |
| Sweeping radar | Open viewer map; one viewer per tick with15-tick minimum; static coverage retained when only beam heading changes; unchanged render objects retained. |
| Orbital scanner | Only affected-bank viewers refresh; one shared power/wiring summary per bank within fanout; changed-property writes. |
| Emerald Apocalypse | Displayed shard/doctrine signature guards caption, style and tags. |
| Black hole | Open-viewer guard and shared machine snapshot; displayed-state signature. |
| Induction matrix | Open-viewer guard, per-matrix snapshot and same native proxy target; paired matrix helper lifecycle remains authoritative. |
| Fusion reactor | Open-viewer shared snapshot/signature; mode/recipe and heat state remains owned by the gameplay runtime. |
| Railgun cooling | Open-viewer snapshot/signature; cached helpers and native fluid state remain owned by cooling runtime. |
| Gate | Open-viewer map; one shared snapshot per gate/fanout; cached GUI elements and displayed projection. |
| Matter stabilizer | Delayed dirty buckets; viewers grouped by machine; one snapshot per group; display signature. |
| Neutron collector | Delayed dirty sessions with pending-tick and displayed signature guards; one snapshot per collector within each due service pass; closed-viewer early return. Current native panel lifecycle passed in the final28-check replay; multiple-viewer sharing remains source-audited. |
| Crystal accumulator | Combined render signature/topology guard; UI due buckets; detached and relative lifecycle retained. |
| Auric vat | Delayed session snapshot, signature and separate feedback expiry; placement guide wakes from explicit intent/viewport changes. |
| Orbital logistics | Affected-cohort fanout; shared entity/silo lookup context and cohort projection comparison. |
| Fueler | Explicit open/click refreshes only; no periodic GUI work. |
| Combustion turbine | Explicit open/control/native-shell retarget; same-entity/layout root reuse; no periodic GUI work. |
| Alien system | Explicit confirmation/modal create/destroy; no periodic GUI updater; currency checked at action time. |

Informatron is an additional information interface, not one of these19 interactive owner panels. ESIR supplies its content on requested page callbacks; no ESIR Informatron polling loop was introduced.

The admin console and camera helper are additional new owners, with their own dirty/cadence contracts. Their build, root retention and native binding assertions above cover only the tested paths. Neither the source audit nor the28 native assertions prove zero native queries/assignments across every owner under every multiplayer state.

## Replaying the headless GUI assertions

The bridge is appended to a **staged copy** of ESIR's `control.lua` so it can use the existing owner locals. It is not a shipped runtime module. Use a connected-player save: Factorio2.0.77 has no `game.create_player` API, and a playerless headless map cannot supply real GUI objects.

1. Use `scripts/invoke-control-ups-qc.ps1 -PrepareOnly` with a fresh RunName, an explicit connected-player `-SaveInput`, the compatible full dependency seed, and `-BridgePath scripts/qc/admin-tools/gui-native.lua`. `-BaselineSource` may point at the shipping source for this functional lane; it is not a timing comparison.
2. Only in the staged ESIR settings, enable `ei-admin-tools-enabled`. Export `gui._qc_overlay=refresh_overlay` immediately before the staged sweeping-radar GUI module's final `return gui`. Preserve shipping source and startup defaults.
3. Run the installed2.0.77 executable with the staged config/mod directory, `--disable-migration-window --benchmark <connected-save> --benchmark-ticks 180 --benchmark-runs 1`. Use `Start-Process -WindowStyle Hidden` for unattended runs.
4. Require `script-output/admin-gui-native.json` to contain `all_pass=true`, all expected checks and a connected native player. Retain the stdout, staged manifest and any staged-only exports alongside the result.

The checked-in `gui-native-results.json` is the compact evidence snapshot for the28-check run, not a claim that every later source snapshot was tested. Re-run after material GUI changes. Whole-engine timing uses a separate uninstrumented alternating baseline/candidate lane and must not include this setup bridge.

## Final closed-service checks

The 2026-10-02 full integration replay passed 12 additional assertions for neutron
and matter panels. With no viewers, service retains the same empty scheduling
bucket and does not advance the last GUI service tick. Stale scheduling is cleared
once; subsequent calls remain idle. Missing GUI state remains absent. These are
native owner-service assertions in `preservation.lua`, with gameplay roots restored
after the isolated fixture probes.

These changes postdate the original frozen populated comparison and can execute
in a closed-panel factory workload. That earlier timing result measures its
recorded source snapshot, not these final source bytes.

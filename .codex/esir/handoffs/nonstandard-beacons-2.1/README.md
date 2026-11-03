# Historical Nonstandard Beacons Continued handoff (superseded)

**Superseded by the existing ESIR 1.4.0 / Factorio 2.1.23 integration. Do not apply this
patch over the current port.** ESIR already declares NSBC and both replacement families.
The captured `esir-integration.patch` and `manifest.json` remain unchanged historical
evidence. [Current acceptance](CURRENT_ACCEPTANCE.md) links the new source snapshot,
native-event candidate tests and retained validation artifacts.

The remainder of this document describes the original deferred handoff and its historical
application gate. Statements about the then-active 2.0 checkout and pending actuator port
are historical, not instructions for ESIR 1.4.0.

## Application gate

1. Complete ESIR's separate Factorio 2.1 port and dependency migration.
2. Review the standalone fork's docs/validation.md and resolve release blockers.
3. Refresh/rebase this patch against that actual 2.1 source.
4. Run git apply --check esir-integration.patch against the rebased source.
5. Apply after review, refresh the dependency catalog and run the integration matrix.

A clean application against this snapshot does not certify applicability to the future
port. The patch changes neither ESIR's version nor its factorio_version.

## Behavior and invariants

Copper and Iron form one replacement family, with Copper to Iron the default upgrade.
Alien and Warp form another, with Alien to Warp the default. Both permit eligible quality
changes. Ruined Alien containers remain excluded.

Copper to Iron raises overload weight from **1 to 2** and can overload an existing layout.
Recipes, costs, slots, ranges, consumption, graphics, source lighting, Alien repair event
ordering, overload weighting and diminishing-return behavior remain authored by ESIR.

## Validation after rebasing

Use isolated Factorio2.1.23-or-approved-newer executable/data, PEREL>=1.2.2 and the fork.
Run scripts/invoke-esir-dev.ps1 -Task preflight, then adapt the engine/mod/save paths in
scripts/invoke-beacon-profile-qc.ps1 -Transition -Geometry and
scripts/invoke-alien-beacon-repair-qc.ps1 before running them for2.1 acceptance.
Those focused runners currently target the installed2.0 engine.

Cover both pairs in both directions, qualities, module overflow, fuel/fluid preservation,
robot/platform upgrades, repaired Alien upgrades, weighted-count4-to-5-to-4 transitions,
profile curves and range changes. Verify rendered hover/clicked information, open-window
updates without world hover, remote rotation, simultaneous viewers and save/reload.

Full ESIR2.1 acceptance remains pending until that port exists. In particular, the current
overload module writes LuaEntity.active inside a protected call; the ESIR2.1 port must
migrate that removed API before its activation behavior can be accepted.

## Provenance

Captured snapshot: `69de9263e90b52bc17986b6db6535aec414d09da`. The patch has six files:
dependency metadata, three beacon prototype owners, the beacon model and its index.
ESIR version 1.3.41 and Factorio 2.0 declarations remain unchanged.

The isolated 2.1.23 fixture passed 112 assertions using actual snapshot profile,
overload-count and Alien-repair modules: six profile curves, native receiver effects,
weighted count 4→5→4, both families' tier/quality handoffs, ranges/exemptions, and six
Alien repairs with one build event/source each. Fixture art replaces full ESIR graphics;
unrelated content is omitted. This does not close the full integration application gate.

From the separate fork checkout, reproduce with explicit isolated paths:

```powershell
python -B scripts/esir_fixture.py --engine $engine --output "$evidence/esir-fixture" --perel $perel --esir $esir --handoff "$esir/.codex/esir/handoffs/nonstandard-beacons-2.1" --save "$evidence/gui-de-125/user/saves/_autosave-nsbc-player-fixture.zip"
```

Here `$engine` is the isolated 2.1.23 executable, `$evidence` the evidence directory,
`$perel` the released 1.2.2 archive and `$esir` the ESIR checkout. Run the standalone
graphical fixture first for its player-bearing seed. This runner applies the patch only
to its own snapshot. Rebase onto the completed ESIR 2.1 port before applying there.

manifest.json records the snapshot revision, pre/post file hashes, patch hash, fork
provenance and evidence. The patch contains only task-specific changes against that
snapshot, excluding unrelated dirty-worktree work. This folder is outside shipping
mod folders and automatic deployment. The standalone report is docs/validation.md
in the separate nonstandard-beacons-continued checkout.

# ESIR 1.4.0 / NSBC native-event acceptance

This is the current integration record for Factorio **2.1.23**, ESIR **1.4.0** and
unreleased NSBC **1.0.0 / storage schema 2**. The historical `esir-integration.patch`
and `manifest.json` beside this file are preserved unchanged. **Do not reapply them.**
The current checkout already declares the continuation and both replacement families.

The [NSBC acceptance report](../../../../../nonstandard-beacons-continued/docs/native-events-acceptance.md)
describes implementation, migration, performance, commands, evidence and limitations.
[The current acceptance manifest](current-acceptance-manifest.json) records the source snapshot, dependency lock,
original handoff hashes, package hash and final receipts. Raw evidence is retained under
[the managed run](../../../../.factorio-qc/managed/b84842298b0e44cd81909b250c7f1f4c).

NSBC now uses the internal recipe's native completion event, with validated manager
ownership and idempotent controller conversion. It preserves real source state, pauses,
escrow, pending work and surplus energy. The circuit signal and public API remain stable;
PEREL's released minimum remains 1.2.2. Original MIT/personal material is retained, with
upstream's native-event idea credited and continuation changes disclosed as AI-assisted.

ESIR's authored recipes, costs, slots, ranges, consumption, graphics/source lighting,
repair event ordering, diminishing-return profiles and overload weights are unchanged.
Copper ↔ Iron and Alien ↔ Warp allow eligible quality changes; ruined Alien structures
remain excluded. Default upgrades remain Copper → Iron and Alien → Warp.
**Copper → Iron increases overload weight from 1 to 2 and can disable a layout that
previously had weighted count 4.** The current 2.1 overload actuator is
`disabled_by_script`; the full-core fixture verifies actual disabling at 5 and recovery
at 4. Alien and Warp remain exempt.

Current native acceptance includes 8 tier/quality handoffs, 12 player and 26 robot/platform cases,
6 repairs followed by Alien upgrades, populated ESIR migration and second reload,
schema conversion and controller faults. Controlled full ESIR nitrogen depletion is
4.9999988079/s (Copper) and 9.9999976158/s (Iron), matching the authored 5/s and 10/s.
The fixed-seed power fixture settles at zero events; 20-run paired medians are
77.7095 ms baseline and 74.312 ms candidate for the same 381-tick workload.

The full ESIR client additionally passes 128 native blueprint transform cases and the
normal/remote/editor rotation guards. The global ownership audit reconciles 131 beacons
and 262 helpers, with zero orphan or multiply owned helpers. Nine standalone rendered
panel runs cover English/German/Japanese at 100/125/150%; two actual full-core clients
pass simultaneous views/actions and disconnect/rejoin. The fresh 31-file ZIP includes
all eight locales and passes archive-only fresh-save, populated upstream 1.4.2 and 2.0.0
adoption, and second-load checks. Package SHA-256:
`1174687b34279f467fae7ee702872ebbf20c24687d540bcfb89be0182b149e97`.

Concurrent media edits removed an acid-turret spark sprite still referenced by the
captured source, blocking late graphical reload attempts. The private test stage was
restored from its captured source; all 493 recorded main-source hashes match the
successful accepted run. Strict native save/reload preserved every source/controller
ID. A private media overlay restored only the missing sprite from the captured Git
revision, and the final graphical reload passed (`reload-media-final-02.receipt.json`)
with the same recorded source hashes and preserved source/controller IDs. The live
checkout and media remain untouched. The manifest keeps the earlier blocked attempts
separate from successful evidence.

Graphical/multiplayer/package results and exact hashes are in the final manifest and
NSBC report. Scripted native player actions, actual rendering and actual network
clients are separate evidence from physical input. Physical keyboard/mouse and the
complete blueprint-library UI path remain unperformed. All eight locale CFGs are
checked and packaged; rendered English/German/Japanese checks are not native-language
certification. No version bump, installed selection change, publication or PR is part
of this work.

The managed run is closed and classified as protected evidence. Its retention snapshot
refused staged directory junctions and records a housekeeping error; this is separate
from the passing acceptance receipts. No evidence, linked target or live source was
deleted. `housekeeping-closeout.json` records that distinction.

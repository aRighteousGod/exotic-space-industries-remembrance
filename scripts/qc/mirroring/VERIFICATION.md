# Mirroring repair verification

The repair adds exactly 18 crafting-machine opt-ins and replaces the steam oil
pumpjack's inherited flipped graphics with a deep copy of its authored graphics.
No placed-entity migration, runtime scheduler, setting, locale key or version
change belongs to this patch. The changelog entry remains under **1.4.01**.

## Native acceptance: Factorio 2.1.24

The original standard profile used ESIR 1.4.01 and dependency lock
`2cd48f3ccd5714e74b78386ce49019298e9dcff354c0180da51d93f62c27a8c2`.
Managed run: `89c7335484884fd7b9c3211ff66e5709`.

| Check | Quality enabled | Quality disabled |
| --- | ---: | ---: |
| Complete final prototypes compared | 123 | 118 |
| Expected field changes, and no others | 19 | 19 |
| Empty native flip cases per baseline/candidate | 984 | 944 |
| Loaded native cases per baseline/candidate | 536 | 536 |
| Candidate assertions | 7,204 | 7,164 |
| Mirrored blueprint build/revival/copy cases | 144 | 144 |
| Loaded mirrored entities preserved through save/reload | 18 | 18 |
| Conflicting-fluid attempts | 147 | 147 |
| Conflicting-fluid pairs kept separate for 600 ticks | 15 | 15 |
| Actual crane belt-lane delivery cases | 32 | 32 |
| Robot small-to-large crane upgrades within those cases | 8 | 8 |
| Native heat-connection/transfer cases | 16 | 16 |
| Loaded symmetric-furnace reflection/return cases | 24 | 24 |

All checks in this table passed. Both axes and all four cardinal directions are
covered. Negative controls reproduce all 18 blocked blueprint eligibilities;
candidate eligibility is true for every one. Four empty machines can return a
native no-op while their recipe-dependent fluid boxes are disabled; their loaded
and blueprint cases pass.

Loaded cases preserve indexed fluid identities, quantities and temperatures,
including the auric vat's internal marker. The engine can permit a geometric flip
beside an incompatible fluid while keeping the fluid systems disconnected. The
fixture checks actual fluid isolation, rather than incorrectly requiring every
such operation to return false.

The full-prototype comparison permits only `use_mirroring` on the 18 named
machines and `graphics_set_flipped` on the pumpjack. Geometry, migration flags,
crane reach/speed/stack fields, graphics, working effects, status overlays,
connectors, death effects, sounds and Factoriopedia fields otherwise compare
unchanged. The existing thermal-furnace restriction remains deliberately deferred.

## Historical donor and persistence

Managed donor run: `063506ba4ba04bcea6ede96f09cf98a7`.
The user-supplied Windows archive contains actual **2.0.77**; its SHA-256 is
`ad36e0591e336400e731d5b400038e37c8361fdc71c76c0f6db96ee31741b4c2`.
All 35 historical package hashes match the preserved 1.3.41 selection.
Current 2.1 source was never loaded by the old engine.

The donor contains 352 requested direction/mirroring cases across 44 prototypes:
the 18 repaired machines, 12 inserters and 14 drills. Some 2.0 prototypes normalize
the requested direction or mirrored state; receipts retain the actual resulting
state, rather than claiming all requests created distinct layouts.

Unpatched and repaired 2.1.24 produce **identical post-upgrade states in all 352
cases**. A native loopback server saved the repaired upgrade; loading that actual
ZIP preserves all 352 resulting states exactly.

Strict 2.0-to-2.1 parity is **288/352**, with 64 pre-existing differences reproduced
identically by the unpatched control:

- Eight orientations each of the burner mining drill, burner quarry, steam miner
  and steam quarry have changed lateral drop offsets.
- Eight crusher cases have ammonia temperature normalization from -33 to -35.
- Eight cases each of the advanced chemical plant, auric vat and excavator lose
  the selected historical recipe/fluid state during the broader upgrade.

These are a boundary on historical parity, not repaired or introduced by this
mirroring patch. `check-legacy.py` requires the exact baseline/candidate/reload
comparison and records the differences in `historical-boundary.json`.
No attempt was made to reconstruct orientations already lost in player saves.

## Rendered acceptance

The fixture captures original machine artwork with native recipes, power,
fluids, heat, circuit wires and working effects. It reduces unrelated combat,
corpse, spider and drill atlases only in private staging, after capturing final
prototype data. Required target artwork, pipes, covers and smoke are retained.

The completed inventory contains **133 native PNGs**: 57 eight-state overviews
(19 bodies in covered-port, connected-pipe and night scenes) and 76 day/night
closeups. All **456 recorded scene states** report working status and actual
crafting/mining progress. The 19 per-machine review sheets and three cover sheets
were inspected for normal/mirrored ports, covers, wire attachment, working effects
and lights. Both steam-pumpjack states retain ESIR artwork. Its existing single
authored body and native port geometry are preserved.

Graphical evidence uses Quality enabled; the two-profile native comparison checks
the same authored presentation fields with Quality disabled. Static frames do
not establish frame-by-frame animation parity or unrelated entity artwork.

## Boundaries and concurrent work

The live checkout advanced to 1.4.02 and switched back to original Armoured Biters
during this task. Those concurrent edits and the new version heading were
preserved. A separate fresh managed run,
`f13fd9a6cbd94afb88a9578a48b4fe2d`, repeated the entire candidate native suite with
Quality enabled and disabled against **1.4.02**, using dependency lock
`8f509c61cfebdcca625577ad4ed14f2b491e1c4cf1a63260d8ca78f09130161a`.
Both passed with the same counts above. All 123/118 complete assessed prototypes
are identical to the accepted candidate snapshots, including presentation.
`current-profile.json` records that comparison separately from historical evidence.

Blueprint construction and recipe copy/paste use native Lua APIs. Physical GUI
hotkeys and a multiplayer peer/desynchronization run are not covered. Optional
dependency combinations outside the standard profile are unverified.

Repo doctor passed on 2.1.24. Broad preflight retained one unrelated existing
encoding finding at `scripts/qc/singularity-lance/angular-results.json`
(`mojibake-suspected`); the remaining preflight checks passed.

## Retained evidence and cleanup

- Original native/render/history evidence:
  [protected evidence](../../../.factorio-qc/managed/89c7335484884fd7b9c3211ff66e5709/protected-evidence/).
  The storage validator marked this wrapper run failed because the source
  changelog changed during concurrent release work. Its focused native receipts
  passed; 198 selected files were copied with hashes without bypassing the
  cleanup guard.
- Fresh 1.4.02 acceptance:
  [current profile](../../../.factorio-qc/managed/f13fd9a6cbd94afb88a9578a48b4fe2d/selected/mirroring-20261030-205420-85f1b9/script-output/mirroring/current-profile.json).
  The managed run completed and compacted successfully.
- Historical donor:
  [legacy run](../../../.factorio-qc/managed/063506ba4ba04bcea6ede96f09cf98a7/).
  Native completion succeeded; cleanup remains protected after a Windows
  long-path error in the extracted old engine. The user's downloaded ZIP is
  untouched.

An initial unsuccessful staging attempt, `e0b9b16927de447189b2e6fd6c676a72`,
also remains closed/protected. No unrelated output was cleaned up.

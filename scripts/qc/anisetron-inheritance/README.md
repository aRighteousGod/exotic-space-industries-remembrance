# ANISETRON Lance inheritance fixture

Factorio 2.0.77 helper mod, installed only in isolated staging by
`scripts/invoke-anisetron-qc.ps1`. Every burst starts through native ammunition
consumption. The bridge observes state and rebuilds derived visuals; it does not
manufacture payment or damage.

The default 2700-tick run checks exact per-tick packets for levels 0–4, both
channels, ammo quality, laser research, two consecutive charges and source removal.
Independent edge cases cover incision caps/deduplication, Wound expiry and quick
resupply, diplomacy, research snapshots, missed Testament opportunities, fixed
collapse positions and force-merge attribution. `-Save` captures active v3 work;
`-Resume` continues the same event ledger across configuration/fidelity changes.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 -FixtureSource scripts/qc/anisetron-inheritance -RunName inheritance-standard -RuntimeTicks 2700 -Fidelity standard
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 -FixtureSource scripts/qc/anisetron-inheritance -RunName inheritance-save -Save
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 -FixtureSource scripts/qc/anisetron-inheritance -RunName inheritance-replay -Resume -RuntimeTicks 2600 -Fidelity off -SaveInput .factorio-qc/anisetron/inheritance-save/saves/anisetron-transition.zip
```

`options-range.lua` runs 128 native manual/automatic cases across eight headings,
normal/rare vehicles, normal/rare ammo and small/16-tile targets. The oversized
diagonal automatic cases expose a native spatial-search limitation: translating
the same geometry by half a chunk changes automatic acquisition, while manual
native firing accepts the box-distance boundary. `options-range-probe.lua`
records both boxes and positions over a longer interval; do not hide this finding
by fabricating an opener or widening paid mechanical range.

`-Visual -RuntimeTicks 430` creates separate actual day/night surfaces and records
39 normal-zoom frames per fire/motion/light combination. It exercises all four
upgrades and movement through straight travel, turning, coasting and stopping.
The two admission checks are not a mechanical or pixel-alignment certification.
Use `build_previews.py` to encode unchanged native-size captures as WebP clips.

The generic native, timing, tracking and mobility fixtures remain separate
regressions. Source/art hashes and current outcomes belong in the retained
verification report; historical snapshots are not evidence of a new run.

See [current implementation verification](verification.md) for engine results,
the native automatic-acquisition boundary, final captures and QC cleanup evidence.

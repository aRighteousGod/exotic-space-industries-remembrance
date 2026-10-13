# Indexed HD default artwork

Main 1.3.43 and Graphics 6 1.0.1 use the finalized HD geometry at 64 px/tile,
scale 0.5, with a shared 256-entry entity palette and no dithering. The internal
`sd` profile key remains the default-package slot; it no longer means SD density.
The optional `minigun-turret-HD` 1.0.0 keeps its original full-color PNGs, public
API and standalone gameplay. All 64 combined HD shadow PNGs are copied unchanged.

The original compiler, emitter and finalizer remain the lossless source pipeline.
Do not change their exact-pixel gates to approve lossy assets. The derivative
has separate palette, alpha, native and archive receipts; original native
evidence certifies its inherited geometry rather than its quantized colors.

## Reproduce

Install `imagequant==1.1.5` into a task-local tool directory; its wheel contains
libimagequant 2.15.1. Pillow and numpy versions are recorded in source-contract.json.
Run the following from the repository root, choosing fresh output directories:

```powershell
python .codex/esir/asset-generators/minigun-turret/convert_indexed_hd.py --repo . --metadata output/minigun-implementation/finalized-minigun/graphics-data.json --output output/minigun-implementation/indexed-replay/converted --tool-path output/minigun-implementation/palette-study-001/tools
python .codex/esir/asset-generators/minigun-turret/stage_indexed_profile.py --repo . --conversion output/minigun-implementation/indexed-replay/converted --source output/minigun-implementation/holding/sd-32px-before-quantized-hd/graphics-data.lua --output output/minigun-implementation/indexed-replay/profile
```

The converter samples every cell: base once, upper in all 256 directions and
four rotor strips in all 256x28 physical cells. Each cell contributes at most
1,600 evenly distributed visible pixels. One frozen RGBA palette serves all
entity files; item and research icons train separate palettes from all visible
pixels. Fully transparent pixels map to the reserved transparent entry. Opaque
pixels map only to opaque entries. If an icon trains only near-opaque entries,
the highest-opacity color range is made opaque before freezing its palette.
Intermediate alpha and RGB are intentionally quantized. No dithering is used.

PNG encoding compares DEFLATE levels 6 and 9 and retains the smaller result.
Decoded RGBA equality against the quantized candidate, PNG dimensions, original
color chunks and source hashes are verified. All source and output hashes,
palettes and settings are recorded. Interrupted runs resume only with matching
generator/input contracts and verified completed output hashes.

## Promotion and validation

The retained original 84-file SD set and old metadata are protected source
backups in `output/minigun-implementation/holding/sd-32px-before-quantized-hd/`.
Keep this holding folder out of disposable-output retention. Read RESTORE.md
before rollback. Promote the complete generated family and matching default
profile together; retain the factory's single 6/32 presentation translation.
Do not alter launch fields, casing geometry, native sequences or combat timing.

`indexed-fixture/invoke.ps1` runs a short isolated Factorio 2.0.77 comparison.
It copies the shipping main factory verbatim and explicitly chooses default
and full-color profiles. Exact launch-map equality uses saved original Lua
metadata; saved JSON is also checked with a 1e-10 roundtrip tolerance. The
standalone donor supplies identical combat fields to both visual clones.
This is not a full main-mod gameplay load or a repeated 256-direction firing matrix.

`review_indexed.py` assembles shipping default/full-color and retained SD art for
parked/running, file-boundary and fractional-scale review. It also writes a
lossless three-way spin-up WebP with playback slowed for inspection.

`package_indexed.py` builds complete main/G6 archives from their current source
trees. Supply the dossier with baseline.json and the completed conversion path.
It checks 135 indexed PNGs plus 64 unchanged LA shadows, complete membership,
unchanged unrelated G6 baseline assets and unchanged full-color HD pack. It
verifies source/ZIP hashes, exact inventory, CRC integrity and <256,000,000 bytes.
The older measure/audit/finalizer scripts describe historical lossless releases;
they must not be used as the acceptance gate for this derivative.

Current evidence, sizes, paths and native scope are recorded in
`output/minigun-implementation/indexed-hd-001/` and the operational STATUS.md.
ZIPs are staged only. No live installation, Git commit or publication is implied.

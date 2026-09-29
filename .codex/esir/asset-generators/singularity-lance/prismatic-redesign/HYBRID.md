# Full Hybrid additions

Replay from the repository root:

```powershell
python -B .codex/esir/asset-generators/singularity-lance/prismatic-redesign/hybrid.py
python -B .codex/esir/asset-generators/singularity-lance/prismatic-redesign/validate_production.py --shipping
```

`hybrid.py` imports the unchanged `production.py` and `generate.py`. It stages only
eight additional PNGs under `output/meshy/lance-prismatic-liturgy/hybrid/factorio-export`.
Promotion into the main pack is a separate copy step. `hybrid-manifest.json` records
the approved dimensions, frame counts, core ratios, and hashes.

The normal and Testament concentrated warnings retain the original spiraling
prismatic material and add a stationary core boundary. Normal core/outer radii
are 1.5/4; Testament radii are 3/6. The boundary is composited after the original
void so it remains visible in Lean. The normal impact adds a crystalline central
flash; Testament adds an inner annulus without filling its dark aperture.

The echo aliases the original Testament warning and impact sheets at radius 5.
Its warning runs at ticks 30–59 and its terminal cross begins at tick 60. The first
impact remains visible above the echo warning at ticks 30–41. The staged 72-frame
timeline shows this overlap at four times slower than gameplay.

All four new sequences are 256×256 frames in six-column strips, with 30 warning
frames and 12 impact frames. Separate semantic/glow sheets add 42 MiB of raw RGBA
atlas storage (21 MiB for semantic-only Lean); this is not a measured GPU allocation.
Beam branches reuse the existing periodic native material at 0.65 scale and retain
the original impact bloom and native terrain masks. No new particles or tracking
loop are required. All 36 legacy production PNGs remain byte-identical.

The generator verifies distinct frames, finite alpha edges, and bright inner
boundaries in early, middle, and late warning frames. Review `hybrid-board.png`,
`hybrid-timeline.webp`, and the timeline stills at normal scale. Gameplay acceptance
remains the user's manual review: crystal alignment, connected forks, warning
readability, 30/60-tick impacts, lighting, and dense-scene noise in day/night and
Lean/Standard. Headless validation and these composites do not establish that
in-game acceptance.

Runtime schema 12 uses the new concentrated animation names only for new packets.
Schema-11 paid packets retain their original single impact and animation names.
Technology emblems, prerequisite/science identities, and graphics-pack dependencies
are unchanged; all eight new PNGs ship inside the main pack.

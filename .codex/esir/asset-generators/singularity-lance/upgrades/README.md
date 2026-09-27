# Singularity Lance upgrade art

`generate.py` extends ESIR's procedural lance effect family with deterministic
Pillow drawing. No AI raster source or companion graphics-pack revision is used.

Run from the repository root:

```powershell
python .codex/esir/asset-generators/singularity-lance/upgrades/generate.py --output output/singularity-lance-upgrades
```

Review `preview.png` and the four animation strips before promotion. Shipping PNGs
live in the main mod's `graphics/singularity-lance-upgrades/` directory. The preview
is staging-only. Each combat asset has a transparent semantic layer and a separate
glow layer; Lean loads the semantic layer alone. The four 256px technology emblems
reuse the gameplay silhouettes, with a common machined octagonal surround.

Contracts:

- Beam strips: 256×64, horizontal, runtime-stretched to the actual segment; one
  rendering object per lance. Testament substitutes its dark seam and broad rim.
- Wound sigils: 128×128 at 0.5 scale, split / branched / broken ring. Rendering
  follows the entity and expires after the configured Wound timeout.
- Warnings: 192×192 frames, 6 columns, 30 frames at one frame/tick.
- Impacts: 192×192 frames, 6 columns, 12 frames at one frame/tick.
- Collapse radius scales the authored six-tile-wide animation. The dark disk and
  terminal cross distinguish Testament independently of tint.

The runtime owns geometry and timing. Artwork owns neither damage nor victim
selection. Headless load checks establish prototype validity. The user elected to
perform gameplay visual acceptance manually for this change; no captured gameplay
verification is claimed. The checklist is in `scripts/qc/singularity-lance/README.md`.

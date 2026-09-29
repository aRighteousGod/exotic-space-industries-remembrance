# Prismatic Liturgy: dedicated beam origins

The regular beam already has its own opening. Axial and Testament previously
borrowed that opening while replacing the head, tail and body. These dedicated
source apertures establish each upgraded material before it joins the beam.

- Axial: a broad prismatic aperture, swept cyan collar and hot central axis.
- Testament: a wider dark throat, white/violet lip and animated spectral banks.
- Animated caustics, traveling gold knots and chromatic streamers share the
  approved body palette and 16-frame / 0.55-speed cycle.
- Four new transparent PNGs: semantic and optional additive-soft glow for each
  source. Frames are 192 x 160, 4 columns, 16 frames; scale 0.34, branch scale 0.65.
- Adds 7.5 MiB raw RGBA atlas data (3.75 MiB semantic-only). This is not a measured
  GPU allocation. Runtime, entity counts, four-segment budget, ground lighting,
  body/head/tail sheets and the original impact bloom are unchanged.

Replay from the repository root:

```powershell
python -B .codex/esir/asset-generators/singularity-lance/prismatic-redesign/origin.py
```

Default staging: `output/meshy/lance-prismatic-liturgy/origins/`.
`factorio-export/` contains the sheets. `origin-board.png` shows key frames and
day/Lean plus night/Standard material comparisons at scale 0.34.
`origin-motion.webp` uses all 16 actual frames at 61 ms/frame (about twice slow).
Previews illustrate material continuity, not the engine's exact cap placement.

The generator checks unique frames, transparent outer edges, a larger silhouette
than the prior narrow tail, and Testament's opaque dark throat. The manifest
records image hashes and per-frame checks. Generation is deterministic and does
not edit existing art or promote files automatically.

Production wiring uses `graphics_set.beam.start` only. The native branch clone
scales this same material with the rest of its graphics. The regular and impact
beams keep the original opening. Data-stage QC checks this split, semantic/glow
selection, frame timing, scaled branch starts, unchanged segment art, impact
blooms and native ground lights. No late presentation pass owns these hidden
beam graphics, so no global presentation registry change is needed.

Manual gameplay review: origin remains attached to the crystal in every firing
direction; each aperture narrows into its own body without a gap; the shared
starts at the fork are readable without excessive brightness; verify Lean and
Standard in day/night and dense fire. The user elected to perform this review.

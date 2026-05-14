# ei-singularity-lance-base-render

GLB-derived single-frame pyramid base and base-shadow source for the Singularity Lance.

The old shipped base sheet repeated one static frame across a `64` frame grid. The current source render clips the supplied Prism GLB just below the thin crystal support cylinder, adds a tiny axis-aligned faceted cap at the pyramid tip, and renders clean `768x768` single-frame body/shadow sheets through the Factorio preset. The cap is rendered as a body-only overlay so it fills the clipped tip without casting a contact shadow onto the pyramid surface or into the separate shadow sheet.

Source GLB:

`C:\Users\Theorun\Documents\Development\Meshy_AI_Prism_of_the_Ancients_0503175722_texture.glb`

## Usage

```powershell
python .\.codex\esir\asset-generators\singularity-lance\base-render\generate_singularity_lance_base.py
```

Inspect:

`output/meshy/ei-singularity-lance-base-render/previews/`

Promote after approval:

```powershell
python .\.codex\esir\asset-generators\singularity-lance\base-render\generate_singularity_lance_base.py --promote
```

After promoting, rerun the rune glow generator because it derives its mask from the body sheet:

```powershell
python .\.codex\esir\asset-generators\singularity-lance\rune-glow\generate_singularity_lance_rune_glow.py --promote
```

## Output

- `ei-singularity-lance.png`
- `ei-singularity-lance_base-shadow.png`

Both are transparent `768x768` single-frame PNGs.

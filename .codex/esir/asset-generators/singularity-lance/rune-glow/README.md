# ei-singularity-lance-rune-glow

2D procedural rune-glow overlay for the Singularity Lance pyramid faces.

The generator derives a rune-only mask from the shipped body sheet, then emits a transparent animated glow overlay. It does not repaint or overwrite the base body art.

## Usage

```powershell
python .\.codex\esir\asset-generators\singularity-lance\rune-glow\generate_singularity_lance_rune_glow.py
```

Inspect the staged previews under:

`output/meshy/ei-singularity-lance-rune-glow/previews/`

After approval, promote the generated sheet:

```powershell
python .\.codex\esir\asset-generators\singularity-lance\rune-glow\generate_singularity_lance_rune_glow.py --promote
```

## Output

- `singularity-lance-rune-glow.png`

The sheet uses `768x768` frames, `64` frames, `8` columns, and `8` rows. Staged output lands under `output/meshy/ei-singularity-lance-rune-glow/`; `--promote` copies the approved sheet to `exotic-space-industries-remembrance/graphics/entities/singularity-lance/`.

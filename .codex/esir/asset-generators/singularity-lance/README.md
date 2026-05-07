# Singularity Lance Asset Generators

Promoted from `output/` so the procedural sources can be committed while keeping generated asset staging ignored.

## Generators

- `prismatic-beam/generate_prismatic_beam.py`: attack beam, caps, and impact prism sheets.
- `chromatic-afterburn/generate_chromatic_afterburn.py`: hit fire, sticker, and scorchmark sheets.
- `icons/generate_singularity_lance_icons.py`: item and technology icon source/overlay generation.
- `crystal-link/generate_crystal_link.py`: separate base-to-crystal connector sheet, sourced from the chromatic beam style but promoted to `graphics/entities/singularity-lance/crystal-link/`.
- `death-implosion/generate_singularity_lance_death_implosion.py`: 2D procedural black-violet death implosion sheets, promoted to `graphics/entities/singularity-lance/death/`.

## Output Policy

- Keep `output/meshy/ei-singularity-lance-*` ignored.
- Commit final promoted PNGs only from the mod graphics folders.
- Commit generator scripts and hand-written notes here.
- Leave generated manifests, snippets, frame strips, previews, and reports in `output/` unless a specific provenance artifact is intentionally promoted.

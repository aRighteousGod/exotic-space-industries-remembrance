# Output Audit 2026-05-05

`output/` is untracked scratch and is now broadly ignored by `.gitignore`.

## Kept Ignored

- `output/meshy/`: generated Meshy/Blender/export staging, including render frames, GLBs, BLEND files, preview PNGs, snippets, manifests, logs, and galleries.
- `output/tesla-run-mods/`: cached dependency/helper mods for QC runs.
- `output/imagegen/*.png`, `output/codex-image-gallery.html`, image server logs, and preview smoke run data.

## Promoted To Commit-Safe Paths

- `output/meshy/ei-severance-array-prismatic-beam/source/generate_prismatic_beam.py`
- `output/meshy/ei-severance-array-chromatic-afterburn/source/generate_chromatic_afterburn.py`
- `output/meshy/ei-severance-array-crystal-link/source/generate_crystal_link.py`
- `output/meshy/ei-severance-array-icons/source/generate_severance_array_icons.py`
- `output/meshy/ei-severance-array-prismatic-beam/factorio-export/README.md`
- `output/imagegen/gaia-relic-debris-prompts.md`

## Notes

Generated reports/manifests under `output/meshy/ei-severance-array-*/` are useful for local review, but remain ignored by default. The shipped graphics live under `exotic-space-industries-remembrance/graphics/...`.


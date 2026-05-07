# ESIR Asset Generators

Checked-in source scripts for reproducible generated art live here. Generated sheets, previews, manifests, galleries, logs, and run caches belong under the ignored `output/` tree.

Run these commands from the repository root:

```powershell
python .codex/esir/asset-generators/singularity-lance/prismatic-beam/generate_prismatic_beam.py
python .codex/esir/asset-generators/singularity-lance/chromatic-afterburn/generate_chromatic_afterburn.py
python .codex/esir/asset-generators/singularity-lance/icons/generate_singularity_lance_icons.py
python .codex/esir/asset-generators/singularity-lance/crystal-link/generate_crystal_link.py --promote
```

The scripts write staged artifacts to `output/meshy/<asset-name>/`. Scripts that support promotion copy approved PNGs into the mod graphics folders explicitly; otherwise, treat `output/` as disposable scratch.

Generated icon underlays and overlays should stay as separate transparent PNG files and be wired through Factorio `icons` layers in prototype code. Emit a flattened composite only as a preview artifact unless the asset intentionally has no reusable layers.

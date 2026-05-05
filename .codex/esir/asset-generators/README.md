# ESIR Asset Generators

Checked-in source scripts for reproducible generated art live here. Generated sheets, previews, manifests, galleries, logs, and run caches belong under the ignored `output/` tree.

Run these commands from the repository root:

```powershell
python .codex/esir/asset-generators/severance-array/prismatic-beam/generate_prismatic_beam.py
python .codex/esir/asset-generators/severance-array/chromatic-afterburn/generate_chromatic_afterburn.py
python .codex/esir/asset-generators/severance-array/icons/generate_severance_array_icons.py
python .codex/esir/asset-generators/severance-array/crystal-link/generate_crystal_link.py --promote
```

The scripts write staged artifacts to `output/meshy/<asset-name>/`. Scripts that support promotion copy approved PNGs into the mod graphics folders explicitly; otherwise, treat `output/` as disposable scratch.


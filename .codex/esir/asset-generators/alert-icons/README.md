# ESIR alert icon sets

All 27 catalogue identities have four built-in art sets. Their 108 shipping PNGs
ship in Graphics 6 under `graphics/gui/alerts/`. The shared
handler selects artwork per player without changing alert identity or permissions.

| Set | Shipping PNGs | Durable sources |
| --- | --- | --- |
| Original | `<id>.png` | Existing `sources/<id>.svg`, unchanged; `sources/original/manifest.json` records preservation hashes |
| SVG | `svg/<id>.png` | Editable `sources/svg/<id>.svg` |
| Rendered | `rendered/<id>.png` | Untouched 1254px `sources/rendered/<id>.png` |
| Vanilla | `vanilla/<id>.png` | Editable flat pictograms in `sources/vanilla/<id>.svg` |

Rendered remains the built-in default. Its source images use built-in imagegen with
a physical 3D appearance, **not Blender/model renders**. There are no fabricated SVG wrappers.
Exact prompts live in `../../art-prompts/alert-icons/rendered/`.
`sources/rendered/provenance.json` links prompts, originals, both framing-correction
inputs/prompts, generation evidence and hashes. Export is reproducible; rerunning
an image prompt is not claimed to reproduce the same generated source image.

Original's historical generator is retained as
`sources/original/legacy-generator.py.txt`. Do not execute it: its old preview mode
wrote shipping files. The supported exporter cannot target Original or its masters.

## Named export and promotion

`sigils.py` owns cast-metal geometry; `vanilla.py` owns the flat triangle pictograms.
The Vanilla family was drawn from scratch using installed Factorio 2.0.77 alerts
as style references. No vanilla game PNGs are copied into the mod. `generate.py` supports editable polygons, polylines,
ellipses and diagonal material gradients, rejecting unsupported SVG elements.
Pillow is the only external dependency. Use `python -B` to avoid bytecode caches.
Register task-owned ignored staging through housekeeping first.

```powershell
python -B .codex/esir/asset-generators/alert-icons/generate.py --set svg `
  --staging-dir output/alert-icons/svg --svg-dir .codex/esir/asset-generators/alert-icons/sources/svg
python -B .codex/esir/asset-generators/alert-icons/generate.py --set rendered `
  --staging-dir output/alert-icons/rendered --raster-dir .codex/esir/asset-generators/alert-icons/sources/rendered
python -B .codex/esir/asset-generators/alert-icons/generate.py --set vanilla `
  --staging-dir output/alert-icons/vanilla

# Review before authorized promotion. Only the explicitly named set is replaced.
python -B .codex/esir/asset-generators/alert-icons/generate.py --set svg `
  --staging-dir output/alert-icons/svg --ship
python -B .codex/esir/asset-generators/alert-icons/generate.py --set rendered `
  --staging-dir output/alert-icons/rendered --ship
python -B .codex/esir/asset-generators/alert-icons/generate.py --set vanilla `
  --staging-dir output/alert-icons/vanilla --ship
```

Omit `--svg-dir` to regenerate geometry. `--pilot` exports ten diagnostic icons;
pilots cannot ship. Optional `--before-dir` and `--terrain-reference` add context.
Rendered export crops the alpha >= 32 subject, fits within 108px using Lanczos,
and centers it on transparent 128px RGBA. Untouched raster sources remain separate.

`--set svg|rendered|vanilla` is mandatory. `--ship` never regenerates; it verifies the named
stage, all 27 IDs, generator hashes, PNG hashes and real source hashes. Wrong-set,
partial, stale and tampered manifests fail before copying. Other sets remain
unchanged. Each named source directory retains its `export-manifest.json`.
Previews/intermediates belong in ignored staging, never shipping directories.

## Review and verification

Judge 16/24px before 32/64px; inspect grayscale and silhouettes. Prefer one dominant
silhouette and one secondary cue, with substantial gaps rather than a universal
plaque. SVG faces occupy about 100px, relief about 108-112px; critical features are
generally 12-16 source pixels. Machinery uses upper-left lighting, pale ceramic,
charcoal and steel. Damage uses amber/red, recovery green/teal, decay earth tones.
Natural subjects should retain botanical/geological identity. Watch thin gate
conductors, horizontal pipe fragments and dark terrain at small sizes.

Vanilla intentionally uses a shared triangle with a dark pictogram. Use flat
red/amber for hazards, cyan for cryogenic alerts, green for recovery and tan for
aging/decay. Judge the interior marks in color and grayscale: alpha silhouettes
share the triangle and cannot distinguish categories. Keep dark geometry inset
from all three edges; avoid material shading, tiny detail and secondary badges.

`compare.py` produces a three- or four-way HTML gallery and color/grayscale/silhouette
sheets from `--original`, `--svg-png`, `--rendered` raw originals, and `--output`.
Add `--vanilla <png-directory>` for the fourth set and actual-size small-icon sheets.
Its normalization matches the exporter. Optional `--terrain` must be a clean
native screenshot; a fallback backdrop is not gameplay readability evidence.
CSS pixel size still depends on browser zoom and display scaling.

```powershell
python -B scripts/qc/alerts/audit.py
python -B scripts/qc/alerts/icon-assets.py --stage output/alert-icons/svg `
  --rendered-stage output/alert-icons/rendered --vanilla-stage output/alert-icons/vanilla `
  --work-dir output/alert-icons/export-checks
```

The audit covers all 108 Graphics 6 assets, source types and hashes, selector/signals,
catalogue settings and native-call ownership. Export fixtures cover reproducibility
and invalid promotions. Native `scripts/qc/alerts/icon-visual/` fixtures remain
separate evidence. Report static, native screenshot and multiplayer coverage
separately; source/asset checks do not prove native UI behavior.

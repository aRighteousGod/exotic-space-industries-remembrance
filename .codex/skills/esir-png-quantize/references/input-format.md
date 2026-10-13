# Palette conversion input

The scripts read JSON version 1. `source_root` is resolved relative to the spec
file; all asset paths below it use forward slashes. Keep the spec outside both the
source and output directories when convenient. The source and output must not
contain one another, and the spec must not be inside the output.

```json
{
  "version": 1,
  "source_root": "source",
  "groups": [
    {
      "name": "machine",
      "samples_per_cell": 1600,
      "files": [
        {"path": "body.png", "cell": [128, 128]},
        {"path": "rotor.png", "cell": [128, 128]}
      ]
    },
    {"name": "icon", "samples_per_cell": "all", "files": ["icon.png"]}
  ],
  "copy": [{"path": "shadow.png", "cell": [128, 128]}],
  "previews": [{
    "name": "running",
    "canvas": [160, 160],
    "scale": 2,
    "frames": [
      {"duration_ms": 150, "layers": [
        {"path": "shadow.png", "cell": 0, "at": [16, 16], "opacity": 0.5},
        {"path": "body.png", "cell": 0, "at": [16, 16]},
        {"path": "rotor.png", "cell": 0, "at": [16, 16]}
      ]},
      {"duration_ms": 150, "layers": [
        {"path": "shadow.png", "cell": 0, "at": [16, 16], "opacity": 0.5},
        {"path": "body.png", "cell": 0, "at": [16, 16]},
        {"path": "rotor.png", "cell": 1, "at": [16, 16]}
      ]}
    ]
  }]
}
```

## Groups and sampling

- `groups` and `copy` are arrays; at least one file is required. Group names use
  lowercase letters, digits, underscores or hyphens, beginning with a letter/digit.
- A file is either a relative PNG path or `{ "path": "...", "cell": [width, height] }`.
  A path appears exactly once across all groups and copies. Windows aliases, traversal,
  escaping symlinks and case-insensitive collisions are rejected.
- Omit `cell` to use the whole image. Cell dimensions must divide the sheet exactly.
  Cells are row-major from the top left, including empty atlas cells.
- `samples_per_cell` defaults to 1600. `"all"` includes every visible pixel.
  Sampling visits files in declared order and cells in row-major order, selecting
  evenly spaced visible pixels. Padding at alpha zero contributes no training samples.
- Shared groups must have matching color interpretation metadata. Missing metadata
  differs from an explicit profile; the tool does not infer equivalence or convert
  color spaces. Normalize sources separately if that is actually intended.
- Quantized inputs support 8-bit RGB/RGBA and PNG palette indices of 1, 2, 4 or 8 bits.
  Sixteen-bit and animated PNG inputs are unsupported. Protected copies may also be
  grayscale/LA; they remain byte-identical. ICC profiles on color inputs must be RGB.

All palettes contain at most 256 RGBA combinations, including transparency variations.
Opaque and transparent endpoints are detected from the complete images, before
sampling. Empty groups use a single transparent entry. Translucent-only artwork is
not forced opaque. If a mixed group needs opaque entries missing from initial
training, the tool reserves up to 32 colors learned from actual opaque samples and
retrains within the total budget; its palette report records this fallback.

## Comparisons

Without `previews`, each file gets a sheet showing its first, middle and last cells
on dark and light backgrounds. Contact sheets cap the displayed cell size at 640
pixels and label the display scale; this does not resize the converted asset.

For assembled previews, `canvas` and `at` use source pixels; `at` is the layer's
top-left position. Layers are drawn in declared order with ordinary alpha-over.
`cell` defaults to 0, `at` to `[0, 0]`, and `opacity` to 1. Layers must fit the canvas.
Explicit shadow opacity is a preview aid, not native shadow calibration.

`scale` changes only the final comparison display (default 1, range >0 to 8).
Integer magnification uses nearest-neighbor; fractional scales use bilinear filtering.
`duration_ms` defaults to 100 and must be 1–60000. Multiple frames emit a lossless
looping WebP and a first/middle/last contact sheet. Duplicate WebP frames may be
merged by the encoder while retaining their duration. The tool does not infer
direction order, frame sequences, native timings, shifts or firing coordinates.

## Run and resume

Install only into a task-local directory, or reuse an existing compatible one:

```powershell
python -m pip install --target output/png-quantize-tools imagequant==1.1.5 Pillow numpy
```

If Pillow/numpy are not already on the Python path, use a task-local virtual
environment instead and invoke its Python for all three scripts. `--tool-path`
loads the imagequant backend; Pillow/numpy are imported before command parsing.

Run `quantize_pngs.py --spec <json> --output <directory> --dry-run` first. This
validates inputs and prints counts without creating output or loading imagequant.
Remove `--dry-run` to convert. Add `--tool-path <pip-target>` when needed.
Existing nonempty output requires `--resume`.

The conversion directory contains:

- `assets/`: indexed PNGs and byte-identical copies, with source-relative names.
- `palettes/`: frozen RGBA palettes, training statistics and palette hash contracts.
- `source-contract.json`: exact spec hash, sources, versions, settings and script hashes.
- `receipts/`: each completed file's palette/source contract, hashes, sizes and alpha changes.
- `conversion-report.json`: complete inventory and measured byte totals.

The encoder compares PNG DEFLATE levels 6 and 9 and keeps the smaller result.
Decoded RGBA equality is checked against the quantized candidate. `sRGB`, `gAMA`,
`cHRM` and ICC chunks are preserved. RGB differences under alpha zero are immaterial
and may be normalized. This is still a lossy derivative, not a source-pixel match.
Indexed output can be larger for small or already compact inputs. Compare measured
totals before choosing a derivative; the converter does not substitute source files
silently when the requested indexed encoding grows.

Resume verifies frozen palette hashes as well as sources and tools. Do not change
the palette, input spec or receipts mid-run. Interrupted `.partial` outputs are
replaced atomically; completed files with invalid hashes and unknown files stop the
run. A changed spec or tool version requires a fresh output directory.

## Focused validation

```powershell
python -B .codex/skills/esir-png-quantize/scripts/validate_skill.py --output output/png-quantize-validation/new-run --tool-path output/png-quantize-tools
```

To add the small existing-art example, also pass
`--minigun-root minigun-turret-HD` and
`--minigun-metadata output/minigun-implementation/finalized-minigun/graphics-data.json`.
It crops direction 96 across the 28 physical poses, preserves the four rotor layers,
and compares spin-up using declared frames. These are fixture inputs, not shipping
replacements or a new production palette.

The initial implementation's retained local evidence is under
`output/png-quantize-skill-validation/final/`: `validation-report.json`, a replayable
`minigun.json`, `minigun-source-hashes.json`, and `minigun-preview/` PNG/WebP comparisons.
That directory is ignored review evidence and may be absent in another checkout;
the command above regenerates it from available sources. No Factorio launch is
needed to validate this offline tool.

---
name: esir-rolling-stock-render
description: "Use when Codex should render or wire ESIR Factorio train and rolling-stock body sprites, especially elevated-rail sloped train sprites, rolling_stock_template.blend, susanne_0.0.1.zip precedent, Spritter spritesheet packing, normal/sloped frame contracts, or prototype RotatedSprite metadata for locomotives, cargo wagons, fluid wagons, or train bodies."
---

# ESIR Rolling Stock Render

Use this skill for the special train-body render path. It is not the generic Factorio preset renderer: ESIR train bodies use the repo-root `rolling_stock_template.blend`, the Susanne train precedent, and `spritter.exe` sheet packing.

## Template Contract

- Use repo-root `rolling_stock_template.blend`.
- Parent the actual model to `RollingStockStretchedRotator`. Treat that object as the magic rotator and do not apply its transform to the child model.
- Keep raw rendered frames under ignored `output/`.
- Prefer a reusable script or wrapper under `.codex/esir/asset-generators/nuclear-trains/` when present before writing ad hoc Blender commands.
- Render with Blender in background mode.
- Use no-prefix graphics directory and sheet roots for shipped main-pack train sprites; keep `ei-*` only in locomotive/wagon prototype names and promotion markers.
- Keep the raw render envelope large enough for the full tilt/stretch animation. For the current ESIR Goliath and Black Ark GLBs, use `800px` frames with camera ortho scale `12.5` unless a fresh margin probe proves a smaller envelope is safe. Raising resolution and ortho scale together preserves roughly the same pixel density while adding world-space headroom.

Frame contract:

- Normal rotations: frames `0..255`.
- Sloped rotations: frames `256..415`.
- Sloped banks: `256..295`, `296..335`, `336..375`, `376..415`.

## Model Orientation

Keep the child model in the template's local orientation. For the GLBs used in this workflow, the long axis imported on local X, so the child needed local Z rotation `-90` before rendering. Verify orientation before full renders:

- Normal frame `0` and frame `64` should match Susanne's green-front convention from `susanne_0.0.1.zip`.
- Inspect quick contact sheets for frame `0`, `64`, and slope bank boundaries before committing to a full 416-frame render.

## Spritter Packing

Use repo-root `spritter.exe` version `1.8.1`. Use trailing folder separators on Windows and keep `--layout-mode fill-row`; the layout matters for Factorio metadata.

Normal body:

```powershell
.\spritter.exe spritesheet -l -m 8 -w 4 --layout-mode fill-row <normal-folder>\ <graphics-folder>\
```

Sloped body:

```powershell
.\spritter.exe spritesheet -l -m 5 -w 4 --layout-mode fill-row <sloped-folder>\ <graphics-folder>\
```

Spritter writes metadata and sheets such as:

- `body.lua` and `sloped.lua`
- `body-0.png` through `body-7.png`
- `sloped-0.png` through `sloped-7.png`

After Spritter, add a small transparent per-cell padding pass when using ESIR's wrapper. `pad-spritter-sheets.py --padding 16` expands `width`/`height` and keeps `scale`/`shift` unchanged because the original cell is pasted into the center of the padded cell.

Use `spritter optimize --lossy --group` only in-place on generated or promoted copies. Do not run it on source or hand-authored assets.

## Lighting Style

The template path's useful look comes from broad environment fill and material normalization, not from harsh brightness pushes.

- `render-rolling-stock-template.ps1` defaults to `WorldStrengthScale = 3.0`, `AreaFillEnergy = 0`, `Resolution = 800`, `OrthoScale = 12.5`, metallic `0`, roughness `0.78`, and `--force-opaque`.
- For generic preset renders of dark vehicle-like assets, use `$meshy-blender-spritesheet` / `$esir-asset-pipeline` with `--lighting-profile rail-fill` or the pipeline `compare` command before final renders.
- Treat `gamma-rescue` as an exceptional readability rescue, not the rail-car default. It can bleach black shells, glass, prismatic, or high-emission materials.
- Lighting comparisons report `clip250_pct`; values above `3%` need review and values around `5%` should be rejected unless deliberately approved.

## Prototype Shape

Follow the Susanne precedent for this workflow:

- Use direct `pictures.rotated` and `pictures.sloped` as `RotatedSprite` tables.
- Use no layers, masks, shadows, or lights unless a later deliberate render proves that need.
- Set `slope_angle_between_frames = 1.25`.
- Set `slope_back_equals_front = false`.
- Use full `256` normal directions and `160` sloped directions for cargo too.

Avoid old custom slope math and mirrored cargo `128/80` direction shortcuts when using the template/Spritter workflow. Use full `256/160` unless a deliberate test proves otherwise.

For ESIR prototypes, `require("__mod__/graphics/entities/.../body")` can load Spritter metadata. Build the generated 0-based filenames into a 1-based Lua array when the prototype expects Lua sequences.

## Verification

- Inspect normal frames `0` and `64` for front convention and model orientation.
- Inspect slope bank boundary frames around `256`, `295`, `296`, `335`, `336`, `375`, `376`, and `415`.
- Validate Spritter metadata, sheet names, frame counts, and dimensions before wiring prototypes.
- Reject any raw render frame whose alpha bounds touch an image edge. Edge contact there means the source was clipped, and Spritter cannot recover the lost pixels. Packed Spritter cells may be tightly cropped by design; use the raw-frame edge check as the authority for clipping.
- Run `powershell -ExecutionPolicy Bypass -File .\scripts\invoke-esir-dev.ps1 -Task qc-assets` after graphics or prototype asset wiring.
- Add any narrower ESIR checks that match the touched Lua/prototype files.

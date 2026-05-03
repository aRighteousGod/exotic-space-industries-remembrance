# Pipeline Options

## Full Meshy To Sprite

Use when the user wants a new asset from text or image:

1. Use `$meshy-api` or the `meshy` MCP server to create a GLB.
2. Download the successful task output into `output/meshy/<asset>/`.
3. Run `render_spritesheet.py` on the GLB.
4. Inspect the transparent sheet before committing to any graphics path.

## Existing Model To Sprite

Use when the user already has a model:

```powershell
& "C:\Program Files\Blender Foundation\Blender 4.4\blender.exe" --background `
  --python .codex/skills/meshy-blender-spritesheet/scripts/render_spritesheet.py -- `
  --base-dir . `
  --input path\to\model.glb `
  --output-sheet output/meshy/model-sheet.png `
  --directions 8 `
  --frame-size 256
```

Add `--factorio-preset-defaults` when the user wants to bias the scripted render toward the local `factorioRenderingPreset_v4.blend` reference. That switches default scripted values to 384px cells, an 8x8/64-frame sheet, 8 columns, Cycles, and 256 samples unless the command explicitly overrides those flags.

## Local Factorio Rendering Preset

The repo root contains two reference assets:

- `factorioRenderingPreset_v4.blend`: interactive Blender reference with transparent Cycles output, object/shadow/light/mask render passes, an orthographic camera, upper-left lighting, lower-right shadows, and the `Rotation by Frames & Directions` empty.
- `Render.zip`: sample packed output from that preset. Its `Render/.Sheets/` folder contains `object_0.png`, `object_shadow_0.png`, `object_mask_0.png`, and several light/glare variants.

Use the `.blend` for manual composition and pass layout study. Use `$esir-factorio-asset-export` `render-bundle` mode for `Render.zip`; it stages the bundled sheets and emits layered Lua snippets without touching mod graphics.

Use `render_factorio_preset.py` when Codex should drive the `.blend` automatically:

```powershell
& "C:\Program Files\Blender Foundation\Blender 4.4\blender.exe" --background `
  --python .codex/skills/meshy-blender-spritesheet/scripts/render_factorio_preset.py -- `
  --preset-blend factorioRenderingPreset_v4.blend `
  --input output/meshy/ei-example/model.glb `
  --asset-name ei-example `
  --output-dir output/meshy/ei-example/Render `
  --auto-prep `
  --prep-origin-mode ground `
  --frames 64 `
  --directions 4 `
  --animation-frames 16 `
  --passes object,shadow,light-alpha-reduced,light-alpha,mask `
  --material-report `
  --warn-alpha-materials `
  --pack-sheets
```

Preset renderer behavior:

- It imports GLB/GLTF/OBJ/FBX, links imported meshes into `Object > Normal`, and preserves the `Scene` collection.
- It registers and sets the preset driver properties (`factorio_animationFrames`, `factorio_directions`, `factorio_oScale`, and `factorio_tilesize`) plus legacy `frames`/`dir` custom props so background renders do not depend on the UI panel being active.
- It replaces the `Rotation by Frames & Directions` driver with the documented direction formula before rendering.
- `--auto-prep` performs conservative imported-model cleanup before placement: removes imported cameras and empty meshes, can apply mesh scale, can normalize to a grounded origin, and records the result in the manifest. It avoids decimation, mesh joining, rebaking, and broad material rewrites.
- It unmutes only the selected compositor file-output passes. Defaults are `object,shadow,light-alpha-reduced,light-alpha,mask`; optional passes include `light`, `light-glared`, `light-glared-alpha`, and `water-reflection`.
- `--quality smoke` uses low Cycles samples for quick validation; `--quality final` uses higher preset-style samples.
- `--unit-directions 16|32` switches the rotation empty to the documented unit formula: `radians(-initial_angle - ((frame - 1) // animation_frames) * 360 / unit_directions)`.
- `--pack-sheets` writes preset-compatible `Render/.Sheets` PNGs for direct export staging.
- `--preflight-only` writes a manifest and skips render. Use it to validate required collections, selected compositor nodes, light groups, framing margins, footprint estimates, and material alpha/emission risks before spending a full Cycles render.

Incorporated notes from the saved Notion guide (`C:\Users\Theorun\Documents\3D model to Factorio sprites v2 _ Notion.htm`):

- Put the main mesh in `Object > Normal`.
- Use `Ground Dirt` for scattered dirt/contact shadow when useful; scale it if the object is large.
- Put object lights under `Lights on`; keep sun lights out of that collection.
- Put pipes in `Pipe` when using the preset pipe helpers.
- Leave `Scene` alone.
- Change canvas size through the preset UI: `Orthographic Scale` / tile size / `Set Resolution`; then test with `F12` for clipping.
- Use compositor output paths like `///Render/{export_type}` when saving a preset `.blend` under the repo so the export structure matches `Render.zip`.
- Assign object lights to the `Lights` Light Group for glow/light pass exports.

Known `.blend` caveats:

- Blender may warn that the file was saved by a newer binary.
- The embedded `Factorio` text block is a UI helper script and is skipped unless scripts are enabled.
- The source `.blend` can still print legacy driver warnings while loading or shutting down; automated manifests report whether the active rotator driver was replaced successfully.
- In automated mode, prefer output under `output/meshy/<asset>/Render/`; then feed that folder into `$esir-factorio-asset-export render-bundle`.

## MCP-Assisted Blender Pass

Use when the model needs manual-looking composition fixes:

1. Open Blender normally.
2. In the viewport sidebar, open `BlenderMCP`.
3. Click `Connect to MCP server`.
4. Use the `blender` MCP server for scene inspection, import checks, material adjustment, camera experiments, or screenshots.
5. Save a `.blend` under `output/meshy/`.
6. Use deterministic background rendering for the final spritesheet.

## Installed Integrations

- Meshy MCP server: global Codex MCP server `meshy`.
- Blender MCP server: global Codex MCP server `blender`.
- Blender MCP add-on: installed in Blender 4.4 user add-ons as `blender-mcp-addon`.
- Meshy Blender add-on: installed in Blender 4.4 user extensions as `bl_ext.user_default.meshy`.
- Meshy Blender ZIP cache: `%USERPROFILE%\.codex\tools\meshy-blender-plugin-v0.6.0.zip`.

## Safety Notes

- Blender MCP can execute arbitrary Python in Blender; use it only on working copies and save before large changes.
- Meshy Blender Bridge may prompt for local Blender user-preference auth; prefer Meshy MCP or `$meshy-api` with `MESHY_API_KEY` for Codex workflows. Do not paste keys into chat, Blender files, repo files, scripts, or Codex config.
- Meshy web-to-Blender bridge uses a local HTTP bridge; if it fails, use direct GLB download through Meshy MCP or `$meshy-api`.
- Keep temporary sheets in `tmp/` or `output/meshy/`; both are ignored by this repo.

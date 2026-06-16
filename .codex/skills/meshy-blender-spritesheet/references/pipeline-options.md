# Pipeline Options

## Full Meshy To Sprite

Use when the user wants a new asset from text or image:

1. Use `$meshy-api` or the `meshy` MCP server to create a GLB.
2. Download the successful task output into `output/meshy/<asset>/`.
3. Run `render_factorio_preset.py` on the GLB using `factorioRenderingPreset_v4.blend`.
4. Inspect the preset sheet bundle before committing to any graphics path.

`output/meshy/<asset>/` is ignored staging. Durable prompt notes belong in `.codex/esir/art-prompts/`; reusable generators and asset-specific reproduction scripts belong in `.codex/esir/asset-generators/`.

## Existing Model To Preset Sprite

Use when the user already has a model:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" --background `
  --python .codex/skills/meshy-blender-spritesheet/scripts/render_factorio_preset.py -- `
  --preset-blend factorioRenderingPreset_v4.blend `
  --input path\to\model.glb `
  --asset-name model `
  --output-dir output/meshy/model/Render `
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

Use `render_spritesheet.py --factorio-preset-defaults` only when the user explicitly requests a non-preset draft or when debugging/import-isolating that renderer. No-credit smoke tests should still use `render_factorio_preset.py --test-cube`. Do not invent alternate lighting, camera, or shadow defaults for ESIR Factorio-bound assets.

For clipping prevention, keep the default auto-ortho behavior and set an explicit `--min-alpha-margin` for the draft. This reproduces the manual preset loop of raising Orthographic Scale only until the object fits, while preserving the final scale and all attempts in the manifest. Use `--no-auto-ortho-scale` only when comparing manual framing.

## Local Factorio Rendering Preset

The repo root contains two reference assets:

- `factorioRenderingPreset_v4.blend`: interactive Blender reference with transparent Cycles output, object/shadow/light/mask render passes, an orthographic camera, upper-left lighting, lower-right shadows, and the `Rotation by Frames & Directions` empty.
- `Render.zip`: sample packed output from that preset. Its `Render/.Sheets/` folder contains `object_0.png`, `object_shadow_0.png`, `object_mask_0.png`, and several light/glare variants.

Use the `.blend` for manual composition and pass layout study by default. Use `$esir-factorio-asset-export` `render-bundle` mode for `Render.zip`; it stages the bundled sheets and emits layered Lua snippets without touching mod graphics.

Use `render_factorio_preset.py` when Codex should drive the `.blend` automatically:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" --background `
  --python .codex/skills/meshy-blender-spritesheet/scripts/render_factorio_preset.py -- `
  --preset-blend factorioRenderingPreset_v4.blend `
  --input output/meshy/example/model.glb `
  --asset-name example `
  --output-dir output/meshy/example/Render `
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
- It unmutes only the selected compositor file-output passes. Defaults are `object,shadow,light-alpha-reduced,light-alpha,mask`; extra passes such as `light`, `light-glared`, `light-glared-alpha`, and `water-reflection` are additions to the preset pass set, not replacements for base/shadow/light/mask.
- `--quality smoke` uses low Cycles samples for quick validation while still using the preset's camera, lighting, shadows, compositor passes, and sheet layout; `--quality final` uses higher preset-style samples.
- `--unit-directions 16|32` switches the rotation empty to the documented unit formula: `radians(-initial_angle - ((frame - 1) // animation_frames) * 360 / unit_directions)`.
- `--pack-sheets` writes preset-compatible `Render/.Sheets` PNGs for direct export staging.
- `--preflight-only` writes a manifest and skips render. Use it to validate required collections, selected compositor nodes, light groups, framing margins, footprint estimates, and material alpha/emission risks before spending a full Cycles render.

## Runtime Tint Mask Outputs

Use runtime-tint masks for owner-readability only: turrets, vehicles, rolling stock, train stops/remotes, force-facing logistics/control devices, and ownership-critical entities. Avoid them for neutral terrain, decoratives, resources, ruins, pure environmental/alien forms, or assets whose baked ESIR chromatic identity should remain fixed.

For assets that need force/player-colored regions:

- Reserve readable trim, panels, sigils, lenses, or bands as named model parts/materials such as `team_color`, `force_trim`, or `color_mask`.
- Render the preset `mask` pass with the same frame size, frame count, direction count, shift, scale, and sheet layout as the base.
- Keep the mask neutral/white and separate from base, shadow, glow, and light passes.
- Stage `object_mask_0.png` through `$esir-factorio-asset-export`; do not assume it is wired until export/prototype guidance explicitly promotes it as a runtime-tint layer.
- In Factorio sprite/animation tables, the promoted layer should carry `flags = {"mask"}` and `apply_runtime_tint = true`; put these on the actual layer entry when `layers` exists.
- Use `tint_as_overlay = true` only after visual QA confirms overlay blending is wanted. Use static `tint` for fixed-color art, and `rendering.draw_sprite{tint=...}` or `rendering.draw_animation{tint=...}` for script-rendered effects.

Treat `FluidWagonColorMask` by yeahtoast as a read-only precedent for retrofitting rolling-stock masks with `flags = {"mask"}` and `apply_runtime_tint = true`, including sloped graphics where the prototype uses them. Do not copy third-party art or code into ESIR.

Incorporated notes from the saved Notion guide (`C:\Users\Theorun\Documents\3D model to Factorio sprites v2 _ Notion.htm`):

- Put the main mesh in `Object > Normal`.
- Use `Ground Dirt` for scattered dirt/contact shadow when useful; scale it if the object is large.
- Put object lights under `Lights on`; keep sun lights out of that collection.
- Put pipes in `Pipe` when using the preset pipe helpers.
- Leave `Scene` alone.
- Change canvas size through the preset UI: `Orthographic Scale` / tile size / `Set Resolution`; then test with `F12` for clipping. The embedded `factorio.set_resolution` operator only recalculates output resolution from the camera's orthographic scale and tile size; it does not inspect model bounds or choose a new ortho scale. The scripted preset renderer does perform a preflight fit and records `auto_ortho_attempts`.
- Use compositor output paths like `///Render/{export_type}` when saving a preset `.blend` under the repo so the export structure matches `Render.zip`.
- Assign object lights to the `Lights` Light Group for glow/light pass exports.

Known `.blend` caveats:

- Blender may warn that the file was saved by a newer binary.
- The embedded `Factorio` text block is a UI helper script and is skipped unless scripts are enabled.
- The source `.blend` can still print legacy driver warnings while loading or shutting down; automated manifests report whether the active rotator driver was replaced successfully.
- In automated mode, prefer output under `output/meshy/<asset>/Render/` with no leading `ei-` for main-pack graphics; then feed that folder into `$esir-factorio-asset-export render-bundle` with explicit prototype metadata when needed.

## MCP-Assisted Blender Pass

Use when the model needs manual-looking composition fixes:

1. Open Blender normally.
2. In the viewport sidebar, open `BlenderMCP`.
3. Click `Connect to MCP server`.
4. Use the `blender` MCP server for scene inspection, import checks, material adjustment, camera experiments, or screenshots.
5. Save a `.blend` under `output/meshy/`.
6. Use deterministic preset background rendering for the final spritesheet.

## Installed Integrations

- Meshy MCP server: global Codex MCP server `meshy`.
- Blender MCP server: global Codex MCP server `blender`.
- Blender MCP add-on: installed in Blender 5.1 user add-ons as `blender-mcp-addon`.
- Meshy Blender add-on: installed in Blender 5.1 user extensions as `bl_ext.user_default.meshy`.
- Meshy Blender ZIP cache: `%USERPROFILE%\.codex\tools\meshy-blender-plugin-v0.6.0.zip`.

## Safety Notes

- Blender MCP can execute arbitrary Python in Blender; use it only on working copies and save before large changes.
- Meshy Blender Bridge may prompt for local Blender user-preference auth; prefer Meshy MCP or `$meshy-api` with `MESHY_API_KEY` for Codex workflows. Do not paste keys into chat, Blender files, repo files, scripts, or Codex config.
- Meshy web-to-Blender bridge uses a local HTTP bridge; if it fails, use direct GLB download through Meshy MCP or `$meshy-api`.
- Keep temporary sheets in `tmp/` or `output/meshy/`; both are ignored by this repo. Do not keep the only copy of a reusable generator or hand-written prompt in either scratch folder.

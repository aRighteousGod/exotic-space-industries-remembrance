---
name: meshy-blender-spritesheet
description: "Use when Codex should turn Meshy-generated models or existing Blender-compatible 3D assets into Factorio/ESIR-ready transparent sprite frames, directional spritesheets, preview renders, or Blender inspection workflows using Meshy MCP, Blender MCP, and deterministic background Blender rendering."
---

# Meshy Blender Spritesheet

Use this skill for the Meshy -> Blender -> Factorio-preset spritesheet path. It assumes Meshy MCP is configured as `meshy`, Blender MCP is configured as `blender`, and Blender 5.1 is installed at `C:\Program Files\Blender Foundation\Blender 5.1\blender.exe`.

## Options

- **Full pipeline**: use `$meshy-api` or Meshy MCP to create/download a GLB under `output/meshy/`, then render it with this skill.
- **Blender-only**: start from an existing `.glb`, `.gltf`, `.obj`, or `.fbx` and render through the local Factorio preset.
- **MCP-assisted**: open Blender, use the `BlenderMCP` sidebar button to connect, inspect or tune the model through Blender MCP, then use the deterministic renderer for final output.
- **Local Factorio preset**: default ESIR render path, including quick verification. Use `render_factorio_preset.py` to drive `factorioRenderingPreset_v4.blend`; use `render_spritesheet.py` only for explicit non-preset requests or renderer-tool debugging.

## Hard Rules

- Never store Meshy keys in Blender files, repo files, scripts, or Codex config.
- Use `MESHY_API_KEY` through Meshy MCP or the `$meshy-api` REST helper.
- Treat Meshy generation as credit-consuming unless explicitly using a documented test mode.
- Keep generated models and render outputs under ignored `output/meshy/` or `tmp/` unless the user specifies a shipping path.
- Keep reusable generator scripts, asset-specific replay notes, and hand-written prompts out of `output/`: use `.codex/esir/asset-generators/` for generators/notes and `.codex/esir/art-prompts/` for prompt provenance.
- Do not replace production sprites in `exotic-space-industries-remembrance/graphics/` until the user approves the generated sheet.
- For ESIR Factorio-bound spritesheets, do not invent camera, lighting, shadow, or pass layouts. Use the local Factorio preset conventions for final, draft, smoke, and preflight work unless the user specifically requests a non-preset render or the task is debugging the non-preset renderer itself.
- Add runtime-tint mask regions only for owner-readability: turrets, vehicles, rolling stock, train stops/remotes, force-facing logistics/control devices, and ownership-critical entities. Preserve baked ESIR color for neutral terrain, decoratives, resources, ruins, pure environmental/alien forms, and deliberately chromatic assets.
- When a runtime-tint region is needed, keep it as named material or object groups such as `team_color`, `force_trim`, or `color_mask` and render it through the preset `mask` pass as a separate sheet. Do not merge it into base, shadow, glow, or light output.

## Workflow

1. Generate or locate a GLB. Prefer GLB because Meshy embeds textures and Blender imports it cleanly.
2. If Blender inspection is needed, open Blender, press `N`, open the `BlenderMCP` tab, and click `Connect to MCP server`; then use the Codex `blender` MCP tools after restart/reload.
3. Render the preset sheet from the repo root:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" --background `
  --python .codex/skills/meshy-blender-spritesheet/scripts/render_factorio_preset.py -- `
  --preset-blend factorioRenderingPreset_v4.blend `
  --input output/meshy/MODEL.glb `
  --asset-name MODEL `
  --output-dir output/meshy/MODEL/Render `
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

4. Use the lower-level scripted renderer only when the user asks for a non-preset experiment or the task is debugging/import-isolating that renderer. This is not the ESIR smoke-test path:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" --background `
  --python .codex/skills/meshy-blender-spritesheet/scripts/render_spritesheet.py -- `
  --base-dir . `
  --input output/meshy/MODEL.glb `
  --output-sheet output/meshy/MODEL-sheet.png `
  --factorio-preset-defaults `
  --min-alpha-margin 16 `
  --fail-alpha-margin
```

5. Inspect the sheet visually before shipping it. If the model reads as zoomed out, too low-resolution, or black-on-transparent with weak contrast, render at least one tighter/brighter preset variant before staging.
6. If it is destined for Factorio, stage it through `$esir-factorio-asset-export` `render-bundle` before any mod wiring.

## Render Defaults

- `factorioRenderingPreset_v4.blend` uses transparent Cycles output, 384px frames, 64-frame/8x8 sample sheets, upper-left lighting, lower-right shadows, and object/shadow/light/mask passes.
- The preset's embedded `Factorio` script provides a `Set Resolution` operator: it sets render resolution to `camera.data.ortho_scale * factorio_tilesize`. It does not auto-fit object bounds by itself; scripted preset renders now auto-raise ortho from preflight unless `--no-auto-ortho-scale` is passed.
- `render_factorio_preset.py` opens the preset, imports GLB/GLTF/OBJ/FBX, links meshes into `Object > Normal`, sets the preset props, replaces the rotator driver with the documented direction formula, unmutes selected compositor file-output passes, renders into `output/meshy/<asset>/Render/`, and can pack `.Sheets`.
- The preset `mask` pass produces `object_mask_0.png`/ColorMask-style output. Treat it as evidence until export review classifies it as a runtime-tint mask, manual post-processing source, or unused mask sheet.
- Use `--preflight-only` before expensive renders to check preset collections, selected compositor outputs, light groups, framing margins, footprint estimates, and material alpha/emission risks. Add `--fail-framing-risk`, `--fail-missing-light-group`, or `--fail-alpha-risk` when the gate should be strict.
- Use `--auto-prep` for conservative imported-model cleanup before preset placement: remove imported cameras/empty meshes, optionally delete named or unmaterialed helper meshes, normalize origin/size, optionally apply scale, and record the cleanup in the manifest. It does not decimate, join, rebake, or rewrite silhouettes.
- The optional `water-reflection` pass writes `WaterReflection.png`; stage it through `render-bundle` and emit it only when the target prototype should include `water_reflection`.
- The companion `Render.zip` is not a model source; stage its `.Sheets` output, or raw `Render/Object/*.png` folders, with `$esir-factorio-asset-export` `render-bundle` mode.
- `render_spritesheet.py` is a secondary diagnostic renderer for explicit non-preset requests, renderer-tool debugging, or import isolation. When it is used around ESIR assets, pass `--factorio-preset-defaults`, keep auto-ortho fitting enabled, and do not treat it as the smoke or final art path.

## Verification Command

Use the preset test cube to verify Blender rendering without Meshy credits:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" --background `
  --python .codex/skills/meshy-blender-spritesheet/scripts/render_factorio_preset.py -- `
  --preset-blend factorioRenderingPreset_v4.blend `
  --test-cube `
  --asset-name test-cube `
  --output-dir tmp/meshy-blender-spritesheet/test-cube-Render `
  --passes object,shadow,light-alpha-reduced,light-alpha,mask `
  --quality smoke `
  --pack-sheets
```

---
name: meshy-blender-spritesheet
description: "Use when Codex should turn Meshy-generated models or existing Blender-compatible 3D assets into Factorio/ESIR-ready transparent sprite frames, directional spritesheets, preview renders, or Blender inspection workflows using Meshy MCP, Blender MCP, and deterministic background Blender rendering."
---

# Meshy Blender Spritesheet

Use this skill for the Meshy -> Blender -> spritesheet path. It assumes Meshy MCP is configured as `meshy`, Blender MCP is configured as `blender`, and Blender 4.4 is installed at `C:\Program Files\Blender Foundation\Blender 4.4\blender.exe`.

## Options

- **Full pipeline**: use `$meshy-api` or Meshy MCP to create/download a GLB under `output/meshy/`, then render it with this skill.
- **Blender-only**: start from an existing `.glb`, `.gltf`, `.obj`, or `.fbx` and render frames/sheet directly.
- **MCP-assisted**: open Blender, use the `BlenderMCP` sidebar button to connect, inspect or tune the model through Blender MCP, then use the deterministic renderer for final output.
- **Local Factorio preset**: use `render_factorio_preset.py` to drive `factorioRenderingPreset_v4.blend` directly, or pass `--factorio-preset-defaults` for scripted 384px, 8x8/64-frame, Cycles-based drafts.

## Hard Rules

- Never store Meshy keys in Blender files, repo files, scripts, or Codex config.
- Use `MESHY_API_KEY` through Meshy MCP or the `$meshy-api` REST helper.
- Treat Meshy generation as credit-consuming unless explicitly using a documented test mode.
- Keep generated models and render outputs under ignored `output/meshy/` or `tmp/` unless the user specifies a shipping path.
- Keep reusable generator scripts, asset-specific replay notes, and hand-written prompts out of `output/`: use `.codex/esir/asset-generators/` for generators/notes and `.codex/esir/art-prompts/` for prompt provenance.
- Do not replace production sprites in `exotic-space-industries-remembrance/graphics/` until the user approves the generated sheet.

## Workflow

1. Generate or locate a GLB. Prefer GLB because Meshy embeds textures and Blender imports it cleanly.
2. If Blender inspection is needed, open Blender, press `N`, open the `BlenderMCP` tab, and click `Connect to MCP server`; then use the Codex `blender` MCP tools after restart/reload.
3. Render the deterministic sheet from the repo root:

```powershell
& "C:\Program Files\Blender Foundation\Blender 4.4\blender.exe" --background `
  --python .codex/skills/meshy-blender-spritesheet/scripts/render_spritesheet.py -- `
  --base-dir . `
  --input output/meshy/MODEL.glb `
  --output-sheet output/meshy/MODEL-sheet.png `
  --directions 8 `
  --frame-size 384 `
  --ortho-scale 2.0 `
  --min-alpha-margin 16 `
  --exposure 0.7 `
  --world-strength 0.05 `
  --key-energy 900 `
  --fill-energy 220 `
  --padding 0
```

4. For maximum-fidelity preset drafts, run the preset-aware renderer:

```powershell
& "C:\Program Files\Blender Foundation\Blender 4.4\blender.exe" --background `
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

5. For lower-touch preset-like drafts, add `--factorio-preset-defaults` to `render_spritesheet.py`; expect a slower Cycles render.
6. Inspect the sheet visually before shipping it. If the model reads as zoomed out, too low-resolution, or black-on-transparent with weak contrast, render at least one tighter/brighter variant before staging.
7. If it is destined for Factorio, stage it through `$esir-factorio-asset-export` before any mod wiring.

## Render Defaults

- Direction order is a clockwise camera orbit in one row.
- Default camera is orthographic, transparent, elevated 60 degrees, with first yaw at 45 degrees.
- Default render engine is EEVEE Next with transparent PNG output.
- For Meshy image-to-3D models, bounds fitting is on by default. Start quick ESIR tests with `--ortho-scale 2.0` and `--min-alpha-margin 16` at `--frame-size 384` when the silhouette matters; the manifest records each ortho retry and per-frame alpha margins. Use `--no-auto-ortho-scale` only for deliberate manual comparison renders.
- Dark Meshy materials often collapse against Factorio-style shadows/checker previews. For quick renders, try `--exposure 0.7`, `--world-strength 0.05`, `--key-energy 900`, and `--fill-energy 220`; for higher-fidelity drafts, use the preset renderer's object/shadow/light passes and material/light reports.
- The script writes individual frame PNGs and a `.manifest.json` next to the sheet.
- `factorioRenderingPreset_v4.blend` uses transparent Cycles output, 384px frames, 64-frame/8x8 sample sheets, upper-left lighting, lower-right shadows, and object/shadow/light/mask passes.
- The preset's embedded `Factorio` script provides a `Set Resolution` operator: it sets render resolution to `camera.data.ortho_scale * factorio_tilesize`. It does not auto-fit object bounds by itself; scripted preset renders now auto-raise ortho from preflight unless `--no-auto-ortho-scale` is passed.
- `render_factorio_preset.py` opens the preset, imports GLB/GLTF/OBJ/FBX, links meshes into `Object > Normal`, sets the preset props, replaces the rotator driver with the documented direction formula, unmutes selected compositor file-output passes, renders into `output/meshy/<asset>/Render/`, and can pack `.Sheets`.
- Use `--preflight-only` before expensive renders to check preset collections, selected compositor outputs, light groups, framing margins, footprint estimates, and material alpha/emission risks. Add `--fail-framing-risk`, `--fail-missing-light-group`, or `--fail-alpha-risk` when the gate should be strict.
- Use `--auto-prep` for conservative imported-model cleanup before preset placement: remove imported cameras/empty meshes, normalize origin/size, optionally apply scale, and record the cleanup in the manifest. It does not decimate, join, rebake, or rewrite silhouettes.
- The optional `water-reflection` pass writes `WaterReflection.png`; stage it through `render-bundle` and emit it only when the target prototype should include `water_reflection`.
- The companion `Render.zip` is not a model source; stage its `.Sheets` output, or raw `Render/Object/*.png` folders, with `$esir-factorio-asset-export` `render-bundle` mode.

## Verification Command

Use the built-in test cube to verify Blender rendering without Meshy credits:

```powershell
& "C:\Program Files\Blender Foundation\Blender 4.4\blender.exe" --background `
  --python .codex/skills/meshy-blender-spritesheet/scripts/render_spritesheet.py -- `
  --base-dir . `
  --test-cube `
  --output-sheet tmp/meshy-blender-spritesheet/test-cube-sheet.png `
  --directions 4 `
  --frame-size 64
```

---
name: blender-procedural-animation
description: "Use when Codex should create, inspect, or render Blender procedural animations for non-human assets, ESIR machines, crystals, gates, orbitals, props, Meshy GLBs, animation spritesheets, or Factorio-ready transparent frame sheets."
---

# Blender Procedural Animation

Use this skill when an asset should move without relying on humanoid auto-rigging. It is the preferred path for ESIR machines, gates, crystals, reactors, drones, orbitals, ritual mechanisms, environmental motion, and Meshy-generated props that need readable animation.

## Options

- **Import and animate**: load a `.glb`, `.gltf`, `.obj`, or `.fbx`, apply a procedural motion preset, then render transparent animation frames.
- **Generated test asset**: create a Blender-only test rig for machine, crystal, gate, or orbiting-part motion.
- **MCP-assisted tuning**: use the configured Blender MCP server for scene inspection, material edits, object naming, and motion experiments, then use the deterministic renderer for final output.
- **Factorio handoff**: send the rendered sheet and manifest to `$esir-factorio-asset-export`.
- **Local Factorio preset**: default ESIR animation-export contract, including quick verification. Use `factorioRenderingPreset_v4.blend` conventions for manual work and pass `--factorio-preset-defaults` for scripted exports unless the user explicitly requests a non-preset experiment or the task is debugging the renderer itself.

## Hard Rules

- Keep generated `.blend`, frame, sheet, and manifest outputs under ignored `output/meshy/` or `tmp/` unless the user explicitly gives a shipping path.
- Keep durable procedural generator scripts or asset-specific reproduction notes under `.codex/esir/asset-generators/`, not under `output/`.
- Do not edit ESIR prototypes or replace mod graphics from this skill. Use `$esir-factorio-asset-export` first.
- Prefer procedural transforms, object naming, constraints, drivers, and simple generated helper geometry before trying creature auto-rigging.
- Keep animation loops readable at Factorio scale: strong silhouette, limited micro-motion, clean frame count, no tiny detail as the only motion cue.
- Use Factorio-style lighting by default: highlights come from the upper-left of the rendered sprite and generated draft shadows fall lower-right.
- Keep shadows as separate staged sheets for Factorio-bound animation exports so `$esir-factorio-asset-export` can emit `draw_as_shadow` layers. Omit them only when the user explicitly asks for no shadow.
- If an animated asset needs force/player-colored regions for owner-readability, animate and render the `team_color`, `force_trim`, or `color_mask` parts as a separate neutral mask sheet with the same frame count, direction count, frame size, shift, scale, and loop timing as the base. Do not add runtime-tint masks to neutral environmental/alien forms or deliberately baked ESIR chromatic assets.
- Keep enough orthographic margin for all animated poses. The procedural renderer auto-fits `--ortho-scale` against per-frame alpha bounds by default, including extra margin for generated lower-right shadow sheets. Inspect manifest `warnings` and `alpha_bounds`; use `--no-auto-ortho-scale` only for deliberate manual tests.
- For main-pack shipping graphics, use no-prefix render/staged names such as `example`; pass `ei-*` later as explicit prototype metadata when exporting or promoting.
- Treat Blender MCP as an inspection/tuning surface; deterministic background rendering should produce final sheets.

## Presets

- `spin`: rotate the whole asset.
- `bob`: vertical sine motion.
- `pulse`: scale/emphasis pulse for the whole asset or named core objects.
- `orbit`: rotate named orbiters or generated orbiting parts.
- `machine`: counter-rotating rings, pulsing core, orbiting details.
- `crystal`: slow spin, float, and pulse.
- `gate`: opening/closing side parts plus rotating rings.
- `all`: broad combined motion for stress-testing.
- `none`: render frames without procedural motion.

Read `references/procedural-patterns.md` when choosing motion design, object naming, Factorio preset usage, or sheet layout.

## Command

Run from the repo root with Blender:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" --background `
  --python .codex/skills/blender-procedural-animation/scripts/procedural_animation_sheet.py -- `
  --base-dir . `
  --input output/meshy/MODEL.glb `
  --preset machine `
  --output-sheet output/meshy/MODEL/MODEL-animation.png `
  --frames 16 `
  --frame-size 256 `
  --columns 4 `
  --factorio-preset-defaults `
  --ortho-scale 2.8 `
  --min-alpha-margin 16 `
  --fail-alpha-margin `
  --shadow-sheet output/meshy/MODEL/MODEL-animation-shadow.png
```

Keep `--factorio-preset-defaults` for ESIR Factorio-bound animation sheets, including smoke checks. Drop it only for an explicitly requested non-preset draft or when debugging the procedural renderer itself.

No-credit preset-default verification:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" --background `
  --python .codex/skills/blender-procedural-animation/scripts/procedural_animation_sheet.py -- `
  --base-dir . `
  --test-asset machine `
  --preset machine `
  --output-sheet tmp/blender-procedural-animation/test-machine.png `
  --factorio-preset-defaults `
  --frames 8 `
  --columns 4 `
  --shadow-sheet tmp/blender-procedural-animation/test-machine-shadow.png
```

## Output

The script writes:

- individual transparent frame PNGs
- packed animation sheet PNG
- `.manifest.json` with frame size, frame count, direction count, columns, preset, camera, and render settings
- `alpha_bounds`, `auto_ortho_attempts`, final `ortho_scale`, and margin warnings when any pose approaches a frame edge
- lower-right transparent shadow sheet when `--shadow-sheet` is provided; Factorio-bound runs should provide it unless explicitly no-shadow
- optional `.blend` if `--save-blend` is provided

For ESIR, inspect the sheet, then stage it with:

```powershell
python .codex/skills/esir-factorio-asset-export/scripts/export_factorio_asset.py machine `
  --asset-name example `
  --sheet output/meshy/example/base.png `
  --working-sheet output/meshy/example/example-animation.png `
  --working-manifest output/meshy/example/example-animation.manifest.json `
  --target-prototype-name ei-example `
  --working-frame-count 16 `
  --working-line-length 4 `
  --scale 0.35 `
  --shift 0,-0.2
```

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
- **Local Factorio preset**: use `factorioRenderingPreset_v4.blend` for manual high-fidelity animation exports, or pass `--factorio-preset-defaults` for scripted 384px, 8x8/64-frame, Cycles-based drafts.

## Hard Rules

- Keep generated `.blend`, frame, sheet, and manifest outputs under `output/meshy/` or `tmp/` unless the user explicitly gives a shipping path.
- Do not edit ESIR prototypes or replace mod graphics from this skill. Use `$esir-factorio-asset-export` first.
- Prefer procedural transforms, object naming, constraints, drivers, and simple generated helper geometry before trying creature auto-rigging.
- Keep animation loops readable at Factorio scale: strong silhouette, limited micro-motion, clean frame count, no tiny detail as the only motion cue.
- Use Factorio-style lighting by default: highlights come from the upper-left of the rendered sprite and generated draft shadows fall lower-right.
- Keep shadows as separate staged sheets when possible so `$esir-factorio-asset-export` can emit `draw_as_shadow` layers.
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
& "C:\Program Files\Blender Foundation\Blender 4.4\blender.exe" --background `
  --python .codex/skills/blender-procedural-animation/scripts/procedural_animation_sheet.py -- `
  --base-dir . `
  --input output/meshy/MODEL.glb `
  --preset machine `
  --output-sheet output/meshy/MODEL/MODEL-animation.png `
  --frames 16 `
  --frame-size 256 `
  --columns 4 `
  --shadow-sheet output/meshy/MODEL/MODEL-animation-shadow.png
```

Add `--factorio-preset-defaults` when the scripted render should match the local Factorio rendering preset defaults more closely. This is slower than the EEVEE draft path.

No-credit verification:

```powershell
& "C:\Program Files\Blender Foundation\Blender 4.4\blender.exe" --background `
  --python .codex/skills/blender-procedural-animation/scripts/procedural_animation_sheet.py -- `
  --base-dir . `
  --test-asset machine `
  --preset machine `
  --output-sheet tmp/blender-procedural-animation/test-machine.png `
  --frames 8 `
  --frame-size 96 `
  --columns 4 `
  --shadow-sheet tmp/blender-procedural-animation/test-machine-shadow.png
```

## Output

The script writes:

- individual transparent frame PNGs
- packed animation sheet PNG
- `.manifest.json` with frame size, frame count, direction count, columns, preset, camera, and render settings
- optional lower-right transparent shadow sheet when `--shadow-sheet` is provided
- optional `.blend` if `--save-blend` is provided

For ESIR, inspect the sheet, then stage it with:

```powershell
python .codex/skills/esir-factorio-asset-export/scripts/export_factorio_asset.py machine `
  --asset-name ei-example `
  --sheet output/meshy/example/base.png `
  --working-sheet output/meshy/example/example-animation.png `
  --working-manifest output/meshy/example/example-animation.manifest.json `
  --working-frame-count 16 `
  --working-line-length 4 `
  --scale 0.35 `
  --shift 0,-0.2
```

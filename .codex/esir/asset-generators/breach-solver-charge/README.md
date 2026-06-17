# Breach Solver Charge Asset

Source model:

- `models/breach-solver-charge.glb`

Generated outputs:

- `exotic-space-industries-remembrance-graphics-4/graphics/entities/breach-solver-charge/breach-solver-charge-projectile.png`
- `exotic-space-industries-remembrance-graphics-4/graphics/entities/breach-solver-charge/breach-solver-charge-projectile-shadow.png`
- `exotic-space-industries-remembrance-graphics-4/graphics/items/breach-solver-charge.png`

Render command:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" --background `
  --python .codex\skills\meshy-blender-spritesheet\scripts\render_factorio_preset.py -- `
  --preset-blend factorioRenderingPreset_v4.blend `
  --input models\breach-solver-charge.glb `
  --asset-name breach-solver-charge `
  --output-dir output\meshy\breach-solver-charge\Render `
  --passes object,shadow `
  --quality final `
  --samples 32 `
  --frames 16 `
  --directions 1 `
  --animation-frames 16 `
  --grid 8x2 `
  --resolution 64 `
  --ortho-scale 3.1 `
  --no-auto-ortho-scale `
  --auto-prep `
  --prep-origin-mode ground `
  --prep-alpha-mode force-opaque `
  --spin-object Mesh_0 `
  --spin-axis z `
  --spin-degrees 360 `
  --spin-frames 16 `
  --material-report `
  --warn-alpha-materials `
  --pack-sheets
```

Icon source render:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" --background `
  --python .codex\skills\meshy-blender-spritesheet\scripts\render_factorio_preset.py -- `
  --preset-blend factorioRenderingPreset_v4.blend `
  --input models\breach-solver-charge.glb `
  --asset-name breach-solver-charge-icon `
  --output-dir output\meshy\breach-solver-charge\IconRender `
  --passes object `
  --quality final `
  --samples 64 `
  --frames 1 `
  --directions 1 `
  --animation-frames 1 `
  --grid 1x1 `
  --resolution 512 `
  --ortho-scale 3.1 `
  --no-auto-ortho-scale `
  --auto-prep `
  --prep-origin-mode ground `
  --prep-alpha-mode force-opaque `
  --material-report `
  --warn-alpha-materials `
  --pack-sheets
```

Icon strip command:

```powershell
python .codex\skills\esir-item-icon-prep\scripts\build_factorio_item_icon.py `
  --source output\meshy\breach-solver-charge\IconRender\Object\0001.png `
  --output exotic-space-industries-remembrance-graphics-4\graphics\items\breach-solver-charge.png `
  --preview output\meshy\breach-solver-charge\breach-solver-charge-icon-preview-128.png
```

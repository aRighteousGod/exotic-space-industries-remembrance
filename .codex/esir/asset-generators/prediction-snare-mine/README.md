# Prediction Snare Mine Asset

Source model:

- `models/prediction-snare-mine.glb`

Generated outputs:

- `exotic-space-industries-remembrance-graphics-4/graphics/entities/prediction-snare-mine/prediction-snare-mine.png`
- `exotic-space-industries-remembrance-graphics-4/graphics/entities/prediction-snare-mine/prediction-snare-mine-shadow.png`
- `exotic-space-industries-remembrance-graphics-4/graphics/entities/prediction-snare-mine/prediction-snare-mine-glow.png`
- `exotic-space-industries-remembrance-graphics-4/graphics/items/prediction-snare-mine.png`
- `exotic-space-industries-remembrance-graphics-4/graphics/items/prediction-snare-mine-glow.png`

Entity render command:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" --background `
  --python .codex\skills\meshy-blender-spritesheet\scripts\render_factorio_preset.py -- `
  --preset-blend factorioRenderingPreset_v4.blend `
  --input models\prediction-snare-mine.glb `
  --asset-name prediction-snare-mine `
  --output-dir output\meshy\prediction-snare-mine\Render `
  --passes object,shadow `
  --quality final `
  --samples 48 `
  --frames 1 `
  --directions 1 `
  --animation-frames 1 `
  --grid 1x1 `
  --resolution 128 `
  --ortho-scale 3.1 `
  --no-auto-ortho-scale `
  --auto-prep `
  --prep-origin-mode ground `
  --prep-alpha-mode force-opaque `
  --material-report `
  --warn-alpha-materials `
  --pack-sheets
```

Icon source render:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" --background `
  --python .codex\skills\meshy-blender-spritesheet\scripts\render_factorio_preset.py -- `
  --preset-blend factorioRenderingPreset_v4.blend `
  --input models\prediction-snare-mine.glb `
  --asset-name prediction-snare-mine-icon `
  --output-dir output\meshy\prediction-snare-mine\IconRender `
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
  --source output\meshy\prediction-snare-mine\IconRender\Object\0001.png `
  --output exotic-space-industries-remembrance-graphics-4\graphics\items\prediction-snare-mine.png `
  --preview output\meshy\prediction-snare-mine\prediction-snare-mine-icon-preview-128.png
```

Pack, derive the central teal glow layers, and promote the entity sheets plus
item glow strip:

```powershell
python .codex\esir\asset-generators\prediction-snare-mine\derive_prediction_snare_assets.py `
  --repo-root . `
  --promote
```

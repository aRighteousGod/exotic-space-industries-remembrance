# Pipeline Spec

The orchestrator accepts JSON by default and YAML when PyYAML is installed. JSON is the most portable choice.

## Top Level

```json
{
  "asset_name": "threshold-array",
  "graphics_name": "threshold-array",
  "prototype_name": "ei-threshold-array",
  "kind": "machine",
  "output_root": "output/meshy/threshold-array",
  "model_path": "output/meshy/threshold-array/model.glb",
  "model_glob": "output/meshy/threshold-array/*.glb",
  "blender": {
    "exe": "C:/Program Files/Blender Foundation/Blender 5.1/blender.exe"
  },
  "factorio_render_preset": {
    "blend": "factorioRenderingPreset_v4.blend",
    "render_bundle": "Render.zip"
  }
}
```

- `asset_name`: required pipeline/job key. For main-pack shipping graphics, prefer the no-prefix graphics root such as `threshold-array`.
- `graphics_name`: staged filename and final graphics directory root. Defaults to `asset_name` with a leading `ei-` removed.
- `prototype_name`: intended Factorio prototype identity. It may keep `ei-*`, for example `ei-threshold-array`.
- `kind`: `entity`, `machine`, `icon`, `concept`, or a descriptive string.
- `output_root`: defaults to `output/meshy/<graphics_name>`.
- `model_path`: preferred input model for render steps.
- `model_glob`: fallback search when a Meshy download produced a new GLB.
- `factorio_render_preset`: paths for local preset files. The `render_preset` step opens the preset in background Blender and writes outputs under the asset root; it does not modify the source `.blend`. Factorio-bound spritesheet specs should include this block unless the task is explicitly non-preset.

`output_root` is ignored generated staging. Keep reusable generators, reproduction scripts, and hand-written asset notes under `.codex/esir/asset-generators/`; keep prompt text under `.codex/esir/art-prompts/`; keep approved shipped PNGs under the appropriate mod graphics folder.

Runtime color masks default to owner-readability only: turrets, vehicles, rolling stock, train stops/remotes, force-facing logistics/control devices, and ownership-critical entities. Preserve baked ESIR color on neutral terrain, decoratives, resources, ruins, pure environmental/alien forms, and deliberately chromatic assets.

## Meshy

Use `meshy.enabled = false` for local-only jobs. Use `dry_run` before spending credits.

Simplified workflows:

```json
"meshy": {
  "enabled": false,
  "workflow": "text-3d-preview",
  "prompt": "black sigil industrial threshold array, readable Factorio silhouette",
  "negative_prompt": "tiny text, soft blob, unreadable silhouette",
  "art_style": "realistic",
  "target_format": "glb",
  "should_remesh": true,
  "target_polycount": 50000,
  "poll": true,
  "download": true,
  "output_dir": "{output_root}/meshy-task"
}
```

Maximum-control workflow:

```json
"meshy": {
  "enabled": true,
  "args": [
    "create",
    "text-3d",
    "--payload-file",
    "{output_root}/payload.json",
    "--poll",
    "--download",
    "--format",
    "glb",
    "--output-dir",
    "{output_root}/meshy-task"
  ]
}
```

`args` is passed directly to `.codex/skills/meshy-api/scripts/meshy_rest.py`.

When a generated asset needs force/player-colored regions, put that requirement in the prompt as separate neutral material groups or readable trim named `team_color`, `force_trim`, or `color_mask`. Do not ask Meshy to recolor the whole object for team color.

## Static Render

```json
"render_static": {
  "enabled": true,
  "input": "{model_path}",
  "output_sheet": "{output_root}/renders/{graphics_name}-static.png",
  "directions": 8,
  "frame_size": 384,
  "columns": 8,
  "padding": 0,
  "elevation": 60,
  "yaw_offset": 45,
  "ortho_scale": 2.0,
  "auto_ortho_scale": true,
  "min_alpha_margin": 16,
  "fail_alpha_margin": true,
  "exposure": 0.7,
  "world_strength": 0.05,
  "key_energy": 900,
  "fill_energy": 220,
  "engine": "eevee",
  "samples": 64
}
```

Uses `$meshy-blender-spritesheet`.

If `render_static` is used for an explicitly non-preset diagnostic, set `"factorio_preset_defaults": true` so scripted values still follow the preset as closely as that secondary renderer allows. Do not use `render_static` as the normal smoke or final path for Factorio-bound assets; use `render_preset` with `"quality": "smoke"` for quick checks.

For Meshy image-to-3D assets, auto fitting is on by default. Keep `"auto_ortho_scale": true` or omit it, set `"min_alpha_margin": 16`, and use `"fail_alpha_margin": true` so the renderer expands the orthographic scale until no frame touches the canvas edge. The manifest records `auto_ortho_attempts`, final `ortho_scale`, and per-frame `alpha_bounds`. Set `"auto_ortho_scale": false` only for manual framing comparisons.

## Procedural Animation

```json
"render_procedural": {
  "enabled": true,
  "input": "{model_path}",
  "test_asset": null,
  "preset": "gate",
  "output_sheet": "{output_root}/renders/{graphics_name}-animation.png",
  "shadow_sheet": "{output_root}/renders/{graphics_name}-animation-shadow.png",
  "frames": 16,
  "directions": 1,
  "columns": 4,
  "frame_size": 256,
  "ortho_scale": 2.8,
  "auto_ortho_scale": true,
  "auto_ortho_step": 1.12,
  "auto_ortho_max": 8.0,
  "min_alpha_margin": 16,
  "fail_alpha_margin": true,
  "direction_mode": "rotate-object",
  "shadow_offset": "18,12",
  "shadow_alpha": 0.42
}
```

Uses `$blender-procedural-animation`. Its defaults preserve Factorio-style upper-left lighting and lower-right shadows, and auto-fit all frames against alpha margins before packing the sheet. When `shadow_sheet` is set, the effective margin also accounts for the configured lower-right shadow offset.

Set `"factorio_preset_defaults": true` for scripted animation drafts and quick checks so they match the local preset conventions as closely as the procedural renderer allows.

## Preset Render

```json
"render_preset": {
  "enabled": true,
  "preset_blend": "{factorio_render_preset.blend}",
  "input": "{model_path}",
  "output_dir": "{output_root}/Render",
  "manifest": "{output_root}/Render/factorio-preset-render-manifest.json",
  "frames": 64,
  "directions": 4,
  "animation_frames": 16,
  "ortho_scale": 6,
  "tile_size": 64,
  "passes": ["object", "shadow", "light-alpha-reduced", "light-alpha", "mask"],
  "quality": "smoke",
  "lighting_profile": "preset-default",
  "pack_sheets": true,
  "preflight_only": false,
  "preflight_margin": 0.12,
  "auto_ortho_scale": true,
  "auto_ortho_step": 1.04,
  "auto_ortho_max": 12.0,
  "fail_framing_risk": true,
  "material_report": true,
  "warn_alpha_materials": true,
  "footprint_tiles": "3x3",
  "auto_prep": false,
  "prep_origin_mode": "center",
  "prep_target_size": 2.0,
  "prep_alpha_mode": "report",
  "prep_vehicle_material_lift": false,
  "preset_sun_energy_scale": 1.0,
  "preset_world_strength_scale": 1.0,
  "preset_view_exposure_offset": 0.0,
  "preset_view_gamma": null
}
```

Uses `$meshy-blender-spritesheet` `render_factorio_preset.py`. It opens `factorioRenderingPreset_v4.blend`, imports the model, links meshes into `Object > Normal`, configures the preset driver properties, unmutes selected compositor outputs, and renders into `output/meshy/<asset>/Render/`.

Set `"quality": "final"` for higher Cycles samples. Use `"unit_directions": 16` or `32` plus `"animation_frames"` for direction-major unit layouts. Optional passes include `light`, `light-glared`, `light-glared-alpha`, and `water-reflection`.

Preflight options let the preset act as a material/framing gate before rendering: `"preflight_only": true`, `"preflight_margin"`, `"auto_ortho_scale"`, `"auto_ortho_max"`, `"fail_framing_risk"`, `"require_light_group"`, `"fail_missing_light_group"`, `"material_report"`, `"warn_alpha_materials"`, and `"fail_alpha_risk"`. Scripted preset renders auto-fit from camera-plane bounds by default and record `auto_ortho_attempts`; set `"auto_ortho_scale": false` only for manual preset parity tests.

Auto-prep is conservative and preset-only. Set `"auto_prep": true` to remove imported cameras/empty meshes, normalize to `"prep_target_size"`, and record cleanup in the render manifest. Optional flags include `"prep_origin_mode": "center|ground"`, `"prep_apply_scale"`, `"prep_delete_empty_meshes"`, `"prep_remove_imported_cameras"`, and `"prep_alpha_mode": "report|force-opaque"`.

Lighting profiles are opt-in. Use `"lighting_profile": "rail-fill"` as the normal dark-vehicle profile: `sun=1.40`, `world=3.00`, vehicle material lift, metallic `0`, roughness `0.76`, base color gamma `0.74`, and value `1.08`. Use `"gamma-rescue"` only after preview approval for assets that remain too dark; it sets `sun=1.50` and view gamma `1.50` and can wash out black shells or high-emission surfaces. Direct numeric lighting/material fields override profile defaults when present.

The preset `mask` pass produces `object_mask_0.png`/ColorMask-style output. Treat it as unclassified evidence until export review marks it as a runtime-tint mask, manual post-processing source, or unused sheet.

## Lighting Compare

```json
"lighting_compare": {
  "enabled": true,
  "profiles": ["preset-default", "rail-fill", "gamma-rescue"],
  "output_dir": "{output_root}/lighting-compare",
  "report": "{output_root}/lighting-compare/lighting-compare-report.json",
  "html": "{output_root}/lighting-compare/lighting-compare-report.html",
  "frames": 8,
  "directions": 8,
  "animation_frames": 1,
  "passes": ["object", "shadow", "light-alpha-reduced", "mask"],
  "quality": "smoke",
  "pack_sheets": true,
  "grid": "8x1",
  "warn_clip250_pct": 3.0,
  "reject_clip250_pct": 5.0
}
```

Run with `run_asset_pipeline.py compare --spec <spec>`. The command renders preview variants, writes JSON and HTML, and reports active-alpha mean/median luma, p95/p99 luma, `clip250_pct`, edge-touching tiles, blank tiles, and warnings. It does not auto-select or lock a final profile; set `render_preset.lighting_profile` explicitly for final renders.

## Factorio Export

```json
"export": {
  "enabled": true,
  "mode": "machine",
  "sheet": "{render_static.output_sheet}",
  "render_manifest": "{render_static.manifest}",
  "working_sheet": "{render_procedural.output_sheet}",
  "working_manifest": "{render_procedural.manifest}",
  "working_shadow_sheet": "{render_procedural.shadow_sheet}",
  "scale": 0.35,
  "shift": "0,-0.2",
  "filename_root": "{graphics_name}",
  "snippet_template": "assembling-machine",
  "target_prototype_type": "assembling-machine",
  "target_prototype_name": "{prototype_name}",
  "target_field": "graphics_set",
  "animation_speed": 0.6,
  "output_dir": "{output_root}/factorio-export"
}
```

Modes are `entity`, `machine`, `icon`, and `render-bundle`, matching `$esir-factorio-asset-export`.

Prototype-aware snippet fields are metadata and comments, not automatic wiring. Use `filename_root`/`graphics_name` for staged PNG names and `snippet_template`, `target_prototype_type`, `target_prototype_name`, and `target_field` to make staged snippets and promotion hints line up with the intended prototype.

Preset bundle export:

```json
"export": {
  "enabled": true,
  "mode": "render-bundle",
  "bundle": "Render.zip",
  "prototype_mode": "machine",
  "line_length": 8,
  "frame_count": 64,
  "direction_count": 1,
  "light_layer": "glow",
  "scale": 0.35,
  "shift": "0,-0.2",
  "output_dir": "{output_root}/factorio-export"
}
```

Use this when Blender has already exported the preset's `Render/.Sheets` passes. The exporter stages base, shadow, mask, light/glare, and water-reflection PNGs and emits a draft layered snippet. Mask sheets are not automatically wired as runtime-tint layers; classify them before promotion.

If `export.mode = "render-bundle"` and `export.bundle` is omitted, the orchestrator uses `{render_preset.output_dir}`. Set `"pack_raw_frames": true` to pack raw preset frame folders with safe PIL logic:

```json
"export": {
  "enabled": true,
  "mode": "render-bundle",
  "prototype_mode": "machine",
  "pack_raw_frames": true,
  "grid": "8x8",
  "line_length": 8,
  "frame_count": 64,
  "emit_water_reflection": true,
  "scale": 0.35,
  "shift": "0,-0.2",
  "output_dir": "{output_root}/factorio-export"
}
```

The orchestrator also supplies `{render_preset.manifest}` to the exporter, so `render-bundle` can infer direction-major values from the preset run. For a 4-direction/16-frame preset render, snippets should emit `frame_count = 16` and `direction_count = 4`, not a flat 64-frame animation.

If a mask is promoted as a runtime-tint layer, the prototype layer should match the base dimensions, frame count, direction count, shift, and scale, and carry `flags = {"mask"}` plus `apply_runtime_tint = true` on the actual layer. Use `tint_as_overlay = true` only after visual QA confirms overlay blending is intended. Use static `tint` for fixed-color art and runtime `rendering.draw_sprite{tint=...}`/`rendering.draw_animation{tint=...}` for script-rendered effects.

## Promotion

```json
"promotion": {
  "enabled": false,
  "manifest": "{export.output_dir}/{graphics_name}.factorio-asset-manifest.json",
  "copy_assets": false,
  "graphics_destination": "exotic-space-industries-remembrance/graphics/entity/{graphics_name}",
  "apply_prototype": false,
  "prototype_file": "",
  "prototype_type": "assembling-machine",
  "prototype_name": "{prototype_name}",
  "field": "graphics_set",
  "expected_asset_count": null,
  "require_prototype_identity": true,
  "prototype_integration": "marker",
  "execute": false
}
```

Promotion is disabled by default, excluded from `--steps all`, and dry-run unless `"execute": true` is used on an explicit `--steps promotion` run. Copying assets requires an explicit graphics destination. Prototype patching requires a marker-delimited block and never performs broad Lua rewriting. Use `"prototype_integration": "data-raw-assignment"` when the marker block should receive a guarded `data.raw["type"]["name"].field = ...` assignment.

## Preset Notes

Findings incorporated from `factorioRenderingPreset_v4.blend`, `Render.zip`, and the saved Notion guide in `C:\Users\Theorun\Documents\3D model to Factorio sprites v2 _ Notion.htm`:

- Main mesh goes in `Object > Normal`.
- Object lights go in `Lights on` and need the `Lights` light group for glow/light exports.
- Runtime-tint regions should stay as separate `team_color`, `force_trim`, or `color_mask` parts/materials and be exported through the mask pass, not baked into base, shadow, glow, or light.
- `Scene` should be left alone; `Ground Dirt` can remain or be scaled for contact/shadow.
- Canvas changes should go through the preset sidebar's `Orthographic Scale` and `Set Resolution`, then tested with `F12`; the preset operator syncs resolution from the chosen ortho scale/tile size and does not auto-fit object bounds. The scripted preset step adds its own preflight auto-fit layer around that template behavior.
- Repo-compatible compositor output uses paths shaped like `///Render/{export_type}`.
- Simple animations should avoid duplicating frame one as the last frame.
- Directional/unit animation can use a driver like `radians(-initial_angle - ((frame - 1) // frame_count) * 360 / direction_count)`.
- The sample bundle is 8x8, 64 frames, 384px cells, with base/shadow/light/mask/glare passes.

## QA

```json
"qa": {
  "enabled": true,
  "require_alpha": true,
  "require_shadow_lower_right": true,
  "min_alpha_pixels": 8,
  "check_paths": [
    "{render_static.output_sheet}",
    "{render_procedural.output_sheet}",
    "{render_procedural.shadow_sheet}"
  ]
}
```

QA checks dimensions, alpha bounds, missing files, manifest readability, and draft shadow offset.

Additional visual QA:

- Missing files, invalid JSON, empty alpha, and invalid sheet layouts are errors.
- Clipping margins, blank tiles, bbox variance, base/shadow/glow/mask dimension mismatch, shadow centroid direction, unclassified `object_mask_0.png`, and duplicate first/last frames are warnings.
- Set `contact_sheet_dir` to write bbox overlay previews for sheet checks.

## Style And Registry

```json
"style": {
  "enabled": true,
  "target_paths": [],
  "baseline_globs": ["exotic-space-industries-remembrance/graphics/**/*.png"],
  "max_baseline_images": 120,
  "warn_luma_delta": 45,
  "warn_saturation_delta": 0.35,
  "warn_edge_density_delta": 0.12,
  "output": "{output_root}/style/style-report.json"
},
"registry": {
  "enabled": true,
  "path": "output/meshy/asset-index.json",
  "roots": ["output/meshy"]
},
"gallery": {
  "enabled": true,
  "output": "{output_root}/approval-gallery.html",
  "include_snippet": true
}
```

Style analysis is warning-only. It collects PNGs from `style.target_paths` and the export manifest, samples local ESIR graphics as a baseline, then reports alpha coverage, luma, saturation, and edge-density deltas.

The registry is manifest-first and safe to rerun. It records staged PNG paths, roles, hashes, dimensions, QA status, and a preserved `manual` object for human review status, notes, and tags.

The gallery is a static HTML approval surface over the export manifest, QA warnings, snippets, and preview PNGs. It is written only on non-dry-run pipeline executions.

## Regression Baselines

```json
"regression": {
  "enabled": true,
  "baseline": "output/meshy/asset-regression-baselines.json",
  "output": "{output_root}/qa/regression-report.json",
  "warn_luma_delta": 30,
  "warn_alpha_coverage_delta": 0.18,
  "fail_dimension_change": true
}
```

Regression checks run inside QA. They compare current staged PNG metrics against a previous style report, registry, or regression report and warn on hash, luma, or alpha drift. Dimension changes can be treated as errors.

## Variants And Cost

```json
"variants": [
  {
    "name": "low-glow",
    "overrides": {
      "asset_name": "example-low-glow",
      "graphics_name": "example-low-glow",
      "prototype_name": "ei-example-low-glow",
      "output_root": "output/meshy/example/variants/low-glow",
      "export": {"light_layer": "none"}
    }
  }
]
```

Run variants sequentially with `run_asset_pipeline.py batch --spec ... --steps ...`. Child specs and dossiers are written under `<output_root>/batch/<variant>/`.

Use `run_asset_pipeline.py estimate --spec ...` before long render batches. The estimator reports frames, passes, resolution, samples, and total megapixel-samples for static, procedural, and preset renders.

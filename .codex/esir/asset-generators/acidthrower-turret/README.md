# Acidthrower comparison generator

Draft bundle: `D:/CodexArtifacts/esir-acidthrower-20261008`.
Run commands from the ESIR repository root. Blender 5.1 and the checked-in Factorio rendering preset are required. Python with Pillow builds the comparison gallery.

## Source and ownership

- Meshy 7.1 task: `01a11d1d-a8eb-7486-b6ea-3f44d90b6fc8`.
- One image-to-3D generation: 4K geometry, 8K texture, PBR, no remesh; 40 credits.
- Original source GLB SHA256: `2fcd937fb916338948b46ff9390a3bd0994ca8e2cda0a16c83bf34179262fafd`.
- The fixed pedestal and complete rotating upper were separated locally in Blender. Original embedded texture bytes are preserved. Both exports retain a shared assembly origin.
- Eight upper directions and four base facings are comparison drafts. Production sprite wiring is pending base selection.

## Replay existing source

Copy these scripts into the draft bundle root before replaying. The scripts do not call Meshy or spend credits.

```powershell
$env:ESIR_ACID_STAGING_ROOT = 'D:/CodexArtifacts/esir-acidthrower-20261008'
& 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' --factory-startup --background --python-exit-code 1 --python "$env:ESIR_ACID_STAGING_ROOT/prepare_model.py"
powershell -ExecutionPolicy Bypass -File "$env:ESIR_ACID_STAGING_ROOT/invoke-comparison-renders.ps1"
python "$env:ESIR_ACID_STAGING_ROOT/build_comparisons.py" --root $env:ESIR_ACID_STAGING_ROOT
python "$env:ESIR_ACID_STAGING_ROOT/check_models.py" --root $env:ESIR_ACID_STAGING_ROOT
```

Replaying preparation and rendering overwrites only the generated files in this task bundle. `source/attempt-01.glb` is read-only to these scripts.

## Latest review requirement

Exterior pipe connectors on the new base must be symmetrical across its longitudinal centerline: matching positions, heights, collar sizes and orientations. Preserve the existing 2x3 gameplay footprint and calibrate the native fluid connection positions before promotion. This correction is recorded but has not been applied to the generated base.

Focused existing-base preview: `comparisons/existing-base-focused.png`. Four facings: `comparisons/existing-base-four-views.png`. The existing-base images are draft composites; native occlusion, firing origin, attachment and shadow calibration remain pending.

## Verification

The fitted existing-base preview scales the 3D upper to 75% around its bearing and aligns centered aims with all four base facings. The restricted arc animation sweeps +/-48 degrees, matching the current 96-degree total firing arc. Replay it after the original source preparation:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:ESIR_ACID_STAGING_ROOT/invoke-fitted-render.ps1"
python "$env:ESIR_ACID_STAGING_ROOT/build_fitted_previews.py" --root $env:ESIR_ACID_STAGING_ROOT
```

`fitted-preview-qa.json` records scale, legal arc samples, alpha margins and verified actual frame poses. The renderer asserts each driver angle before rendering.

`comparison-qa.json` verifies all 40 raw object/shadow frames, dimensions and alpha margins. `model-integrity.json` verifies GLB structure, source hash, identical upper/base geometry and transforms between exports, and byte-identical embedded textures. These checks do not establish production readiness or in-engine visual correctness.

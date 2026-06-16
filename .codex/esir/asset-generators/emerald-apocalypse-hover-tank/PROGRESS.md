# Emerald Apocalypse Hover Tank Progress

## Current Render
- Main tank render is running from the approved no-cap source:
  `output/meshy/emerald-apocalypse-hover-tank/prepared/emerald-apocalypse-hover-tank-prepared-bright-v7-vertextrim.glb`
- Output directory:
  `output/meshy/emerald-apocalypse-hover-tank/Render-final-64-v7-ultra/`
- Blender PID at launch: `45136`
- Settings: Factorio preset, auto ortho, 64 directions, 1536px frames, 4096 Cycles samples, denoise enabled, OPTIX, passes `object,shadow,light-alpha-reduced,light-alpha,mask`, packed as `4x4` sheets.
- Previous 512-sample run was intentionally stopped and should not be treated as final:
  `output/meshy/emerald-apocalypse-hover-tank/Render-final-64-v7-hq/`

## Approved Geometry Candidate
- Use `v7-vertextrim` only.
- Rejected: cap-restoration path. User said it looked horrible. Do not use `--restore-muzzle-crystal-cap`.
- Rejected: gentle trim v3/v6 variants where the thin barrel cylinder remained.
- Approved v7 properties:
  - Thin forward cylinder absent in preview.
  - Thick faceted crystal muzzle preserved.
  - No fake cap.
  - Factorio preset and auto-ortho verified.
- Approval preview:
  `output/meshy/emerald-apocalypse-hover-tank/previews/v7-approval-center-auto-8dir/`
- Barrel QC strip:
  `output/meshy/emerald-apocalypse-hover-tank/previews/v7-approval-center-auto-8dir/v7-barrel-qc-strip.png`
- Agent QC: Aristotle and Godel both passed the v7 candidate for expensive render.

## Main Tank Render Follow-Up
- Monitor `Render-final-64-v7-ultra/Object/*.png` until 64 frames complete.
- After completion, verify:
  - Object, Shadow, Light A, Light A Reduced, and ColorMask each have 64 nonzero frames.
  - Manifest confirms 1536 resolution, 4096 samples, denoising enabled, OPTIX, auto-ortho scale `7.075318989000823`, grid `4x4`.
  - Packed sheets exist under `.Sheets` and remain at 6144x6144 per 4x4 sheet.
  - Barrel side/front frames still show no thin cylinder.
  - Shadow frames align with object frames.

## Crystal Glow Overlay Plan
- Do not rely on generic `Light A` output; imported material has no separate light-group glow object, so those frames are effectively black.
- Added dedicated generator:
  `.codex/esir/asset-generators/emerald-apocalypse-hover-tank/isolate_emerald_crystal_overlay.py`
- Intended source:
  `output/meshy/emerald-apocalypse-hover-tank/prepared/emerald-apocalypse-hover-tank-prepared-bright-v7-vertextrim.glb`
- Next steps:
  1. Run the isolation generator to create a crystal-only GLB and manifest.
  2. Render a low-cost 8-direction crystal-only preview through the same Factorio preset.
  3. Create crystal overlay QC strip/full preview.
  4. Spawn 2 read-only QC agents to check all major crystals are present and no chunks are missing.
  5. Only after QC passes, render the 64-direction crystal overlay with matching final frame count/orientation/framing.

## Code/Prototype Status
- Prototype/data/runtime implementation has been added for `ei-emerald-apocalypse-hover-tank`.
- `qc-fast` and preflight passed earlier after prototype/runtime implementation.
- Final integration still needs a post-render asset staging pass before production graphics wiring.

## Crystal Overlay Checkpoint
- Created first crystal-only overlay candidate:
  `output/meshy/emerald-apocalypse-hover-tank/prepared/emerald-apocalypse-hover-tank-crystal-overlay-v1.glb`
- Manifest:
  `output/meshy/emerald-apocalypse-hover-tank/prepared/emerald-apocalypse-hover-tank-crystal-overlay-v1.manifest.json`
- Retained faces: `95456`
- Next: render 8-direction preview and inspect for missing crystal chunks before full overlay render.

## Crystal Overlay V2 Checkpoint
- V1 preview showed the risk of chipped/missing crystal chunks because it selected bright faces within islands.
- Updated `isolate_emerald_crystal_overlay.py` with `--keep-whole-components` default enabled.
- Created complete-island overlay candidate:
  `output/meshy/emerald-apocalypse-hover-tank/prepared/emerald-apocalypse-hover-tank-crystal-overlay-v2-complete-islands.glb`
- Manifest:
  `output/meshy/emerald-apocalypse-hover-tank/prepared/emerald-apocalypse-hover-tank-crystal-overlay-v2-complete-islands.manifest.json`
- Retained faces: `177982`
- Next: render V2 8-direction preview and QC it instead of V1.

## Crystal Overlay V3 Checkpoint
- V2 complete-island overlay was too broad: it included green rings/panels along with crystals.
- Added `--crystal-only-geometry` gates for 3D compact/faceted islands.
- Created stricter crystal-only candidate:
  `output/meshy/emerald-apocalypse-hover-tank/prepared/emerald-apocalypse-hover-tank-crystal-overlay-v3-crystal-only.glb`
- Manifest:
  `output/meshy/emerald-apocalypse-hover-tank/prepared/emerald-apocalypse-hover-tank-crystal-overlay-v3-crystal-only.manifest.json`
- Retained faces: `134644`
- V3 command used complete islands plus crystal-only geometry gates: min center z 0.55, min thickness 0.026, min normal spread 0.08, max major/minor 7.4, min mid/major 0.14.
- Next: render V3 preview and QC V3 if it avoids missing chunks without dragging in low rings/panels.

## Crystal Overlay V4 Checkpoint
- Agent QC rejected V3 because crystals were present but non-crystal barrel/panel/housing chunks still leaked into the overlay.
- Updated `isolate_emerald_crystal_overlay.py` with `--trim-boxy-components` and stricter face-level trimming for broad boxy islands.
- V4 goal: keep whole true crystal islands, but trim broad casing/panel islands down to high-emerald faces only.

## Crystal Overlay V4 Candidate
- Created V4 trimmed-crystal overlay candidate:
  `output/meshy/emerald-apocalypse-hover-tank/prepared/emerald-apocalypse-hover-tank-crystal-overlay-v4-trimmed-crystals.glb`
- Manifest:
  `output/meshy/emerald-apocalypse-hover-tank/prepared/emerald-apocalypse-hover-tank-crystal-overlay-v4-trimmed-crystals.manifest.json`
- Retained faces: `88235`
- Next: render object-only V4 preview and compare with V3/agent concerns.

## Crystal Overlay V5 Strategy
- Geometry-isolation V4 still leaked barrel casing because Meshy texture/geometry islands mix crystal and housing surfaces.
- Added pixel-derived overlay generator:
  `.codex/esir/asset-generators/emerald-apocalypse-hover-tank/generate_crystal_glow_overlay_from_object.py`
- Rationale: derive the overlay from final object pixels so it is perfectly aligned, includes visible crystal/glass chunks, and cannot include hidden or bronze/black casing geometry.
- Testing first on the approved 8-direction v7 preview before applying it to final 64-direction ultra frames.

## V5 Pixel Overlay QC
- Created V5 preview/comparison from approved 8-direction object frames:
  `output/meshy/emerald-apocalypse-hover-tank/previews/crystal-overlay-v5-pixel-derived-comparison-strip.png`
- V5 captures emerald/cyan visible surfaces from object pixels, so no hidden geometry or bronze/black casing can leak into the overlay.
- Spawned Hume and Carver for V5 QC. Awaiting pass/fail before applying V5 settings to the final 64-frame ultra render.

## V5 Pixel Overlay QC Result
- Hume: PASS/use V5; do not make it large-crystals-only because glass/panel glow improves readability.
- Carver: PASS as aligned mask source, but lower alpha/soften for game use so large crystals do not flatten into solid mint shapes.
- Final overlay plan: apply V5 pixel-derived mask to final ultra object frames after the main render completes, with lower alpha settings than the preview.

## Main Render Monitor
- Main ultra render check: 42/64 nonzero frames in Object, Shadow, Light A, Light A Reduced, and ColorMask.
- Blender PID `45136` still running.
- Once complete, wait for process exit so pack-sheets can finish before validating `.Sheets` output.

## Main Render Monitor
- Main ultra render check: 48/64 nonzero frames in all five render passes.
- Blender PID `45136` still running normally.
- V5 final overlay will be generated from final Object frames with softer shipping settings after all 64 frames and sheets complete.

## Final Soft Glow Overlay
- Generated final softened V5 pixel-derived overlay from ultra Object frames:
  `output/meshy/emerald-apocalypse-hover-tank/Render-final-64-v7-ultra/Emerald Glow/`
- Manifest:
  `output/meshy/emerald-apocalypse-hover-tank/Render-final-64-v7-ultra/emerald-crystal-glow-overlay.manifest.json`
- Packed sheets were written into:
  `output/meshy/emerald-apocalypse-hover-tank/Render-final-64-v7-ultra/.Sheets/emerald_crystal_glow*.png`
- Settings: same V5 mask thresholds, softer alpha (`alpha_scale 0.96`, `core_alpha 0.52`, `halo_alpha 0.18`, `halo_radius 2.2`).

## Final Asset Render Checkpoint
- Blender main render exited after completing all frames and packing sheets.
- Main render output:
  `output/meshy/emerald-apocalypse-hover-tank/Render-final-64-v7-ultra/`
- Validation:
  - Object, Shadow, Light A, Light A Reduced, and ColorMask each have 64 nonzero 1536x1536 frames.
  - Packed main sheets: 20 total, 4 sheets per pass, each 6144x6144.
  - Final object margins: no edge-touching frames, minimum object margin 197px.
  - Final barrel side views checked: thin cylinder absent, thick muzzle crystal intact.
  - Final softened emerald glow overlay: 64 frames + 4 packed 6144x6144 sheets.
- Validation files:
  `final-render-validation.json`
  `final-object-margin-validation.json`
  `emerald-crystal-glow-overlay-validation.json`
- Preview/QC strips:
  `emerald-crystal-glow-overlay-final-comparison-strip.png`
  `final-object-shadow-qc-strip.png`

## Verification Checkpoint
- `git diff --check` completed with only LF/CRLF conversion warnings; no whitespace errors.
- `scripts\invoke-esir-dev.ps1 -Task qc-fast` completed with exit code 0 and overall `warning`.
- QC warnings are the existing cached run-mod drift / advisory missing-prototype logs; no errors were reported.
- QC summary path: `.factorio-qc/fmqc/latest-summary.json`

## Main Mod Graphics Promotion
- Promoted approved shipping sheets into:
  `exotic-space-industries-remembrance/graphics/entities/emerald-apocalypse-hover-tank/`
- Promoted layers: Object base, Object Shadow, and final softened `emerald_crystal_glow` overlay.
- Left diagnostic preset sheets (`object_lightA`, `object_lightAR`, `object_mask`) in `output/` only; they are retained as evidence but are not wired into the shipping prototype.
- Updated `prototypes/exotic-age/emerald-apocalypse-hover-tank.lua` to use 64-direction 1536px stripe layers from the main mod graphics path, including the crystal glow overlay and shadow layer.
- Removed inherited vanilla tank turret/light animation from the Emerald tank visual stack to avoid mismatched overlay sprites.

## Hover Emitter Foot Alignment
- Added generated 64-direction hover-foot offset table:
  `exotic-space-industries-remembrance/lib/emerald-apocalypse-hover-tank-hover-offsets.lua`
- Generator:
  `.codex/esir/asset-generators/emerald-apocalypse-hover-tank/generate_hover_emitter_offsets.py`
- The table has exactly four emitters per direction, matching the four physical hover feet.
- Source foot picks are the four visible low circular pad components from the approved v7 final render component inspection.
- Runtime now snaps `LuaEntity.orientation` to the same 64-direction lattice as the vehicle body animation and uses the table for emitter placement, falling back to the old four local anchors only if table data is malformed.
- QC overlay strip:
  `output/meshy/emerald-apocalypse-hover-tank/hover-emitter-offsets-qc-strip.png`

## Main Mod Graphics QC
- `scripts\invoke-esir-dev.ps1 -Task qc-fast` completed with exit code 0 after graphics promotion.
- Overall status remains `warning` due to the same cached run-mod drift / advisory missing-prototype logs; no new load errors were reported for the promoted tank sheets or prototype wiring.
- QC summary path: `.factorio-qc/fmqc/latest-summary.json`

## Fixed Equipment Duplication Fix
- Fixed runtime grid enforcement in `scripts/control/emerald-apocalypse-hover-tank.lua`.
- Cause: `LuaEquipmentGrid::get_contents()` returns quality-count arrays in Factorio 2.0, but the old guard treated it as a name-keyed dictionary, so each repair pass thought the core and shield were missing and inserted more copies.
- New behavior: inspect concrete `grid.equipment` handles, keep exactly one fixed fusion core and one fixed aegis shield, move them to `{0,0}` / `{6,0}` when possible, insert only when absent, and remove any old duplicates without returning hidden fixed items to inventory.
- `scripts\invoke-esir-dev.ps1 -Task qc-fast` completed with exit code 0 after the fix; overall status remains `warning` from the existing cached run-mod/advisory warnings only.

## Brightness Correction Trial
- Added replayable post-process script:
  `.codex/esir/asset-generators/emerald-apocalypse-hover-tank/brighten_emerald_apocalypse_object.py`
- Input: final ultra `Object/*.png` frames from `Render-final-64-v7-ultra`; alpha, shadow, and custom crystal glow are preserved.
- Generated three candidate base-pass variants in:
  `output/meshy/emerald-apocalypse-hover-tank/brightness-correction/`
- Candidate luma results:
  - `v1-moderate`: mean luma `79.31`
  - `v2-strong`: mean luma `93.27`
  - `v3-apex`: mean luma `106.37`
- Comparison preview:
  `output/meshy/emerald-apocalypse-hover-tank/brightness-correction/emerald-apocalypse-brightness-correction-comparison-strip.png`
- Promoted `v2-strong` packed sheets into:
  `exotic-space-industries-remembrance/graphics/entities/emerald-apocalypse-hover-tank/object_bright_v2-strong*.png`
- Updated `prototypes/exotic-age/emerald-apocalypse-hover-tank.lua` to use `object_bright_v2-strong` as the base layer while keeping the original object sheets available for rollback.
- `scripts\invoke-esir-dev.ps1 -Task qc-fast` completed with exit code 0 after wiring `v2-strong`; overall status remains `warning` from the existing cached run-mod/advisory warnings only.

## Hover Hum Sound Update
- Updated `prototypes/exotic-age/emerald-apocalypse-hover-tank.lua` so the tank uses the same Graphics 4 `sounds/gaian-saucer-hum.ogg` asset as the Gaian saucer.
- Tank profile is deeper and heavier than the saucer: active sound `speed = 0.72`, idle sound `speed = 0.66`, with higher active/idle volume and wider audible distance.
- `scripts\invoke-esir-dev.ps1 -Task qc-fast` completed with exit code 0 after the sound update; overall status remains `warning` from existing cached run-mod/advisory warnings only.

## Object Lighting Rerender Attempt
- Goal: replace disliked `object_bright_v2-strong` post-process base sheets with a Blender/Factorio-preset lighting rerender while preserving existing `object_shadow` and `emerald_crystal_glow` sheets.
- Added renderer options to `.codex/skills/meshy-blender-spritesheet/scripts/render_factorio_preset.py`:
  `--preset-sun-energy-scale` and `--preset-world-strength-scale`.
- Defaults are both `1.0`; existing render commands should remain visually unchanged unless the new flags are passed.
- Rerender contract: source `prepared-bright-v7-vertextrim.glb`, `object` pass only, fixed ortho scale `7.075318989000823`, no auto-ortho changes, 1536px final frames, 64 directions, 4x4 packed sheets.
- Preflight for `sun-150` passed with fixed ortho/framing and recorded lighting adjustments in the manifest.
- Preview batch started with three profiles: `sun-125`, `sun-150`, and `sun-150-world-110`; preview renders use 8 directions, object pass only, fixed ortho/framing, and 1536px frames.
- Initial preview metrics showed `sun-150` remains too dark for the goal: mean opaque luma ~61.8 versus original dark ~55.2 and disliked postprocess `v2-strong` ~93.2.
- `sun-150-world-110` matched `sun-150` numerically, so the preset world color lift is not a useful lever for this asset. Extending lighting-only preview matrix with stronger sun profiles before final render.
- `sun-300` preview reached mean opaque luma ~76.7 but raised max RGB>=250 clipping to ~5.19%, so pure sun scaling is not a safe final lever.
- QC agents recommend a controlled Blender view exposure preview next: render-time exposure should lift midtones without inventing a new material pass or pushing direct sun hard enough to flatten crystals.
- Added `--preset-view-exposure-offset` to the preset renderer for this controlled test; default is `0.0`, so existing render commands stay unchanged.
- Exposure previews were still inefficient: `sun150-exp035` mean ~69.6 / clip ~3.4%, `sun150-exp050` mean ~73.1 / clip ~4.1%.
- Added `--preset-view-gamma` for a render-time midtone curve test. This is still Blender output, not a post-render PNG rewrite; default leaves the preset gamma unchanged.
- `sun150-gamma082` darkened the render in Blender (`mean ~49.3`), so Blender view gamma moves opposite the initial PIL-style intuition for this output path. Testing gamma above `1.0` next.
- `sun150-gamma125` is the first promising lighting/color-management candidate: mean ~77.5 with max clipping ~1.81%, close to `sun-300` brightness but without the severe crystal clipping. Testing `gamma 1.5` to see whether it reaches in-game readability.
- `sun150-gamma150` passed preview QC:
  - mean opaque luma ~91.3, median ~86.8
  - max RGB>=250 clipping ~1.89%
  - no edge touches
  - visually close to `postprocess-v2` readability without `sun-300` crystal blowout
- QC agents approved `sun150-gamma150` for the expensive object-only final render with conditions:
  source `prepared-bright-v7-vertextrim.glb`, fixed ortho `7.075318989000823`, no auto-ortho, 1536px, 64 directions, 4x4 sheets, `--preset-sun-energy-scale 1.5`, `--preset-view-gamma 1.5`, no exposure lift, world scale `1.0`.
- Final object-only rerender started in hidden Blender process:
  `output/meshy/emerald-apocalypse-hover-tank/Render-final-64-v8-lit-gamma150/`
- Final command/PID/log breadcrumbs:
  - `blender-final-render.command.txt`
  - `blender-final-render.pid.txt`
  - `blender-final-render.stdout.log`
  - `blender-final-render.stderr.log`
- Final render settings: object pass only, 64 directions, 1536px frames, 8192 samples, OPTIX, denoise, persistent data, fixed v7 ortho/framing, `sun=1.5`, `gamma=1.5`.

## Object Lighting Rerender Completion
- Final object-only rerender completed successfully:
  `output/meshy/emerald-apocalypse-hover-tank/Render-final-64-v8-lit-gamma150/`
- Output: 64 Object frames, 4 packed 6144x6144 sheets, manifest written.
- Final QC metrics:
  - 64/64 nontransparent frames
  - 0 edge touches
  - mean opaque luma ~91.36, median ~86.77
  - max RGB>=250 clipping ~1.887%
  - min bbox width ~48.50%, max bbox height ~63.41%
- Final QC metrics path:
  `output/meshy/emerald-apocalypse-hover-tank/Render-final-64-v8-lit-gamma150/final-qc/object_lit_v8_metrics.json`
- Promoted the final Object sheets into main mod graphics as `object_lit_v8_*.png`.
- Updated `prototypes/exotic-age/emerald-apocalypse-hover-tank.lua` to use `TANK_BASE_PREFIX = "object_lit_v8"`.
- Existing `object_shadow_*` and `emerald_crystal_glow_*` sheets were not regenerated or replaced.
- `scripts\invoke-esir-dev.ps1 -Task qc-fast` completed with exit code 0 after promotion; overall status remains `warning` from existing cached run-mod drift and advisory missing-prototype logs.
- QC data dump confirms Factorio prototype wiring uses:
  `__exotic-space-industries-remembrance__/graphics/entities/emerald-apocalypse-hover-tank/object_lit_v8_*.png`
- `object_bright_v2-strong` is no longer referenced by ESIR Lua/locale files; it remains only as historical progress text and rollback PNGs.

## Runtime Beam Range Refinement
- Updated `scripts/control/emerald-apocalypse-hover-tank.lua` so `on_script_trigger_effect` passes the script event into charge start.
- The charge now records `aim_range` from `event.target_position` projected onto the tank's fixed-forward barrel vector, clamped to the 96 tile cannon range.
- Final damage filtering and the rendered emerald discharge line both use the stored per-shot range, so a shorter forward click no longer damages or draws out to max range.
- Existing pending-charge saves without `aim_range` retain the old full-range fallback.
- `scripts\invoke-esir-dev.ps1 -Task preflight` completed `ok`.
- `scripts\invoke-esir-dev.ps1 -Task qc-fast` completed with exit code 0; overall status remains `warning` from existing cached run-mod drift plus the existing `max-underground-distance` setting warning.

## Cannon Effects V2 Implementation
- Added deterministic v2 effect generator:
  `.codex/esir/asset-generators/emerald-apocalypse-hover-tank/generate_emerald_apocalypse_effects_v2.py`
- Generated staged v2 sheets and manifest in:
  `output/meshy/emerald-apocalypse-hover-tank/effects-v2/`
- QA summary from the v2 manifest:
  - `chargeup`, `muzzle-flash`, `impact`, `hit-flash`, `scorchmark`, and `shield-pulse` have all frames nonempty and no edge-touching frames.
  - `beam-body`, `beam-head`, and `beam-tail` touch left/right edges intentionally for beam tiling.
- Promoted approved v2 effect PNGs into:
  `exotic-space-industries-remembrance/graphics/entities/emerald-apocalypse-hover-tank/effects/`
- Added cosmetic prototypes:
  `ei-emerald-apocalypse-chargeup`, `ei-emerald-apocalypse-muzzle-flash`, `ei-emerald-apocalypse-beam`, `ei-emerald-collapse-impact`, `ei-emerald-collapse-hit-flash`, `ei-emerald-collapse-scorchmark`, and `ei-emerald-shield-pulse`.
- Runtime now keeps damage/aim/cooldown/recoil unchanged while replacing placeholder charge/fire/shield circles with:
  barrel charge animation, muzzle flash, cosmetic beam entity, endpoint implosion, endpoint scorchmark, capped per-target hit flashes, and animated shield pulse.
- Added QC counters for the new visual path:
  `chargeup_visuals`, `muzzle_flashes`, `beam_visuals`, `impact_effects`, `hit_flashes`, `scorchmarks_created`, and `visual_failures`.
- `scripts\invoke-esir-dev.ps1 -Task preflight` completed `ok`.
- `scripts\invoke-esir-dev.ps1 -Task qc-fast` completed with exit code 0; overall status remains `warning` from existing cached run-mod drift plus the existing `max-underground-distance` setting warning.
- Data dump confirms all new visual prototypes are present in `data.raw`.

## Shield Pulse V3 Idle-Orbit Coverage
- Added `shield-pulse-v3` to the deterministic effect generator as a `768x768`, 48-frame sheet.
- Generated staged v3 shield sheets and a shield-only v3 manifest in:
  `output/meshy/emerald-apocalypse-hover-tank/effects-v3/`
- QA summary:
  - base sheet is `6144x4608`, with all 48 frames nonempty and no edge-touching frames.
  - base visible bounds are about `630-661px` wide and `434-454px` tall per frame.
  - glow sheet has no edge-touching frames after bloom.
- Promoted:
  `emerald-apocalypse-hover-tank-shield-pulse-v3.png`
  and `emerald-apocalypse-hover-tank-shield-pulse-v3-glow.png`
  into the main mod graphics effects folder.
- Runtime/prototype wiring now keeps the stable `ei-emerald-shield-pulse` animation name, points it at the v3 files, declares `768x768`, and uses runtime scale `0.72` with a 48-tick lifetime.
- The older v2 shield pulse PNGs remain only as unreferenced rollback/comparison artifacts; ESIR Lua now references the v3 filenames.
- Updated `effects/shield.provenance.json` to the promoted v3 contract so future asset QA does not validate against the stale `384x384` draft spec.

## Sprite Reduction Pass
- Backed up current high-resolution Emerald Apocalypse hover tank body/effect PNGs to:
  `temp/emerald-apocalypse-hover-tank/sprite-reduction-backup/`
- Backup includes `RESTORE.md` and `backup-manifest.json`; `temp/` is repo-ignored and not part of the shipped mod package.
- Downsampled active shipping sprites in place:
  - tank body sheets: `6144x6144` sheets / `1536px` frames to `3072x3072` sheets / `768px` frames.
  - effects: all active effect sheets downsampled by 50% linear size.
- Updated prototype/runtime scale compensation:
  - tank body `TANK_FRAME_SIZE = 768`, `TANK_SCALE = 0.7`.
  - chargeup, muzzle flash, hit flash, beam, impact, scorchmark, and shield pulse frame sizes/scales doubled back to the same in-game visual footprint.
- File-size checkpoint:
  - active Emerald body/effect PNGs reduced from about `111.06 MiB` to about `39.97 MiB`.
  - body layers reduced from about `82.50 MiB` to about `18.58 MiB`.
  - effects reduced from about `28.56 MiB` to about `21.39 MiB`.
- Comparison strips:
  `output/meshy/emerald-apocalypse-hover-tank/downsample-768/body-1536-vs-768-comparison-strip.png`
  and
  `output/meshy/emerald-apocalypse-hover-tank/downsample-768/effects-hires-vs-reduced-comparison-strip.png`
- `scripts\invoke-esir-dev.ps1 -Task preflight` completed `ok`.
- `scripts\invoke-esir-dev.ps1 -Task qc-fast` completed with exit code 0; overall status remains `warning` from existing cached run-mod drift and existing advisory prototype logs.
- Data dump confirms the tank layers load as `768x768` at scale `0.7`; chargeup/muzzle/hit/shield animations and beam/impact/scorch prototypes load with the reduced frame dimensions and compensating scales.

## Endpoint Apocalypse v3
- Regenerated endpoint-only impact and scorchmark sheets from `generate_emerald_apocalypse_effects_v2.py` with version `v3-endpoint-apocalypse`.
- Staged outputs:
  `output/meshy/emerald-apocalypse-hover-tank/effects-v3-endpoint-apocalypse/`
- QA summary:
  - impact base/glow sheets are `6144x6144`, 64 frames, `768x768` frames, no empty frames, no edge-touching alpha.
  - scorchmark base/glow sheets are `768x768`, 1 frame, no empty frames, no edge-touching alpha.
- Promoted same-name replacements into:
  `exotic-space-industries-remembrance/graphics/entities/emerald-apocalypse-hover-tank/effects/`
- Runtime now adds a hostile-only endpoint collapse damage pass: 18 tile radius, `ei-plasma`, 1,000,000 center damage falling to 200,000 at the edge.
- Prototype wiring now loads the endpoint impact and scorchmark as `768x768` art at scale `1.5`, matching the 36-tile-wide damage footprint.

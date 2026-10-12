# Revision 03 acceptance

Status: applied to the local ESIR worktree. No commit, push, package deployment or live-save mutation was requested or performed. No additional Meshy credits were used for revision 03.

## Production contract

- Seven atlases: base diffuse/shadow/owner mask/glow; head diffuse/shadow/glow.
- 256 head directions, 1.40625-degree world-yaw spacing, 16 by 16 sheet. Four base placement directions.
- The diffuse head is identical across native animation states. Only isolated green accent pixels use the glow layer.
- Glow is enabled while prepared, starting attack, attacking, ending attack and rotating back to rest. Head and tank accents turn off together for folding/folded states.
- Original vanilla pipe covers and their shadows use the native fluid box. There is no custom collar or pipe sprite in the production turret. Connected pipe entities are present only in the labelled connection-test fixture.
- Base/tanks, native covers, base glow and head use the normal `object` layer with secondary orders 1/2/3/4. The former lower base layer let ordinary rear neighbors overpaint the tall tanks. This draw-order repair retains all geometry, atlas pixels, scale and offset values.
- The low deck was fitted to the two-tile width and the preset's ground-plane projection was corrected after placement yaw. Tank and bearing shapes stay rigid. Head shifts and muzzle centres follow the corrected bearing.
- The final alignment refinement changes Lua offsets only: the complete assembly moves 0.18 tile rearward per placement. The reviewed model and all seven sprite files remain unchanged for this refinement; sprite scale stays 0.5. The rejected sidewall-edit attempt was undone before any render frame was written.
- Selection/collision boxes, existing 2-by-3 footprint, ports, buffers, activation ratio, range, attack payload, +/-48-degree arc and rotation/state speeds are preserved.

## Evidence

- `sprite-qa.json`: seven losslessly packed raw-frame atlases, actual frame-angle checks, alpha/crop bounds with at least eight pixels of margin, and shipping hashes.
- `geometry-qa.json`: shared-origin assembled/head-only geometry identity, 97 whole-degree mechanical clearance samples from -48 through +48, no tested intersections outside the deliberate 0.025-tile bearing-contact band. These are model-space checks; the gallery and native captures additionally check the placement-specific render correction.
- `native-muzzle-qa.json`: Factorio 2.0.77 final-prototype assertions and twelve real native launch-position probes, four facings by three aim angles. Final measured maximum error is 0.0288173 tile, approximately 0.92 native pixel.
- `native-visual-qa.json`: 88 fresh native captures, 21 distinct consecutive fine-aim housing crops, and native shutdown-state markers. Head and tank accents stay lit through ending-attack/rotate-for-folding, then both switch off in folding/folded states. The night green threshold excludes dim reflected paint.
- `gallery/native-draw-order.png`: four-facing previous/corrected comparisons with real pipes in valid adjacent positions north and south. The helper baseline changes only the old layer/order fields, leaving art and positioning identical.
- `gallery/native/capped-1.png` through `capped-4.png`: actual production prototype, original vanilla covers, no external pipes, targets, acid streams or diagnostic markers.
- `gallery/native/connected-1.png` through `connected-4.png`: separate connection test with ordinary pipe entities.
- `gallery/native-shutdown.gif`: helper-only white marker identifies the engine's current animation state. These markers do not exist on the production prototype.

Run `scripts/invoke-acid-art-qc.ps1 -Visual` from the repo root, then `review_native.py` to refresh the native evidence. The harness rejects stale reports, missing captures and failed launch probes. It recreates a Freeplay fixture with its introduction disabled, preventing the intro modal from silently pausing capture updates.

The draw-order acceptance run used `-Visual -ReuseFixture -GraphicsQuality medium` while another Factorio instance was open. The first high-quality attempt crashed during atlas allocation before the fixture ran; Windows also reported an allocation failure. The retry completed all 88 captures and every assertion. Texture quality affects this isolated capture run only; shipping atlases and the user's game settings are unchanged.

The follow-up full `--dump-data` reached the prototype checksum but failed writing its JSON to C: with `No space left on device`; the resulting zero-byte file is not acceptance evidence. The successful graphical run's final data-stage assertions independently checked the actual turret's object layers, 1/2/3/4 order, native covers, 256 directions and preserved gameplay fields before the native visual and launch probes ran.

The focused engine and graphics checks pass. The broader `qc-assets` wrapper's asset section passed, but its aggregate status was blocked by existing unrelated encoding findings in `scripts/qc/singularity-lance/angular-results.json` and `temp/anisetron-tracking-fix/blueprint-final.json`. Those files were left unchanged. Do not report the entire repository preflight as clean.

The final offset-only refinement preserves all seven atlas SHA256 hashes. Its rear ground bound is 1.49535 tiles, inside the existing 1.5-tile half-footprint. The model was restored from its pre-trial Blender backup; no rejected sidewall modification remains in the active exports.

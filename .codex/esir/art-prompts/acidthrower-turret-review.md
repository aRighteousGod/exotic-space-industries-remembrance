# Acidthrower model review

2026-10-08. Draft artifacts: `D:/CodexArtifacts/esir-acidthrower-20261008`.

## User requirement: symmetric exterior pipe connectors

The new base's exterior pipe connectors must be symmetrical across its longitudinal centerline. Match the left/right connector position, height, collar diameter and orientation. Retain the existing 2x3 gameplay footprint and calibrate the connectors to the native fluid connection positions before promoting the base.

This is a required correction to the new-base draft. The current generated geometry has not yet been repaired for this requirement.

## Current review view

The user requested a focused view of the new upper assembly on the existing acidthrower base. `comparisons/existing-base-focused.png` shows that combination, with four placement facings in `comparisons/existing-base-four-views.png`.

The upper model is the same geometry used in the complete and base-free GLBs. The existing base is composed from the installed Factorio 2.0.77 sprites, using corrected dimensions and shifts. Attachment follows the native model-origin contract. This is a composited draft; engine attachment, occlusion, firing origin and shadow calibration remain pending.

Final base choice is open. Deployment animation, 64-direction upper sheets, owner-color masks and engine firing checks follow selection.

## Smaller upper and forward firing arc

The user requested a smaller upper, with the base and upper facing the same direction and respecting the in-game firing arc. The fitted preview uniformly scales the upper to 75% in Blender around its bearing contact plane, preserving that attachment anchor. Centered north/east/south/west aims match the corresponding base facing.

The current acid prototype's `turn_range = (1/3)*0.8` and the most recent available final dump confirm a 96-degree total firing arc, or +/-48 degrees around the placed base's facing. `comparisons/existing-base-fitted-firing-arc.gif` uses only that restricted north-facing arc. It replaces the full-yaw inspection as the gameplay-facing review animation.

`comparisons/existing-base-fitted-focused.png` is the fitted south-facing view. Four aligned facings are in `comparisons/existing-base-fitted-four-views.png`; a matched-size comparison is in `comparisons/existing-base-fitted-size-comparison.png`.

The renderer verifies each actual driver angle before rendering and records it in `comparison-renders/head-fitted/verified-frame-poses.json`. These checks validate the draft frame poses, not in-engine occlusion or firing alignment.

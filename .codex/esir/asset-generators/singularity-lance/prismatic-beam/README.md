# ei-singularity-lance-prismatic-beam

Staged procedural Prismatic Core beam draft for the Singularity Lance.

This folder is a dry-run asset stage only. It does not modify shipped graphics or prototypes.

## Contents

- `ei-singularity-lance-beam-body.png`: tileable 16-frame body sheet, `256x96` frames, `4x4`.
- `ei-singularity-lance-beam-head.png`: 16-frame leading cap sheet, `192x160` frames, `4x4`.
- `ei-singularity-lance-beam-tail.png`: 16-frame dissipating cap sheet, `192x160` frames, `4x4`.
- `*-glow.png`: additive companion sheets for the same frames.
- `ei-singularity-lance-impact-prism.png`: optional 24-frame impact bloom, `256x256` frames, `6x4`.
- `ei-singularity-lance-prismatic-beam.prototype-snippet.lua`: draft helper/snippet for later prototype promotion.
- `ei-singularity-lance-prismatic-beam.factorio-asset-manifest.json`: dimensions, warnings, preview references, and promotion notes.

## Promotion Notes

If approved, copy the PNG files into:

`exotic-space-industries-remembrance/graphics/entities/singularity-lance/beam/`

Then adapt `prototypes/alien-system/singularity-lance.lua` so the visible `ei-singularity-lance-beam` and
`ei-singularity-lance-impact-beam` use the custom `graphics_set.beam`. Leave
`ei-singularity-lance-trigger-beam` unchanged because it carries the hidden script effect.

The existing purple tint helpers should not be applied to these custom prismatic sprites; the color is baked
into the transparent sheets.

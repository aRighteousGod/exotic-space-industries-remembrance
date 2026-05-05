# ei-severance-array-prismatic-beam

Staged procedural Prismatic Core beam draft for the Severance Array.

This folder is a dry-run asset stage only. It does not modify shipped graphics or prototypes.

## Contents

- `ei-severance-array-beam-body.png`: tileable 16-frame body sheet, `256x96` frames, `4x4`.
- `ei-severance-array-beam-head.png`: 16-frame leading cap sheet, `192x160` frames, `4x4`.
- `ei-severance-array-beam-tail.png`: 16-frame dissipating cap sheet, `192x160` frames, `4x4`.
- `*-glow.png`: additive companion sheets for the same frames.
- `ei-severance-array-impact-prism.png`: optional 24-frame impact bloom, `256x256` frames, `6x4`.
- `ei-severance-array-prismatic-beam.prototype-snippet.lua`: draft helper/snippet for later prototype promotion.
- `ei-severance-array-prismatic-beam.factorio-asset-manifest.json`: dimensions, warnings, preview references, and promotion notes.

## Promotion Notes

If approved, copy the PNG files into:

`exotic-space-industries-remembrance/graphics/entities/severance-array/beam/`

Then adapt `prototypes/quantum-age/severance-array.lua` so the visible `ei-severance-array-beam` and
`ei-severance-array-impact-beam` use the custom `graphics_set.beam`. Leave
`ei-severance-array-trigger-beam` unchanged because it carries the hidden script effect.

The existing purple tint helpers should not be applied to these custom prismatic sprites; the color is baked
into the transparent sheets.

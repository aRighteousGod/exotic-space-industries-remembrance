# Military 5 Fire Assets

Reproducible Blender import/render scripts for the Incinerator combat robot and
Inferno grenade assets.

Source models:

- `models/incinerator-bot.glb`
- `models/inferno-grenade.glb`
- `models/inferno-grenade-fragment.glb`

Primary outputs are staged under `output/meshy/military-5-fire/` before being
promoted into `exotic-space-industries-remembrance/graphics/`.

The Incinerator model already includes textured orange exhaust detail on the
bottom of its feet, so this generator does not add extra procedural flame
geometry. The pack step extracts those orange foot pixels into a same-layout
glow sheet for Factorio's night rendering.

The capsule item icon is not owned by this generator; it is prepared from
approved source art and stored at `graphics/items/incinerator-capsule.png`.
The spawned combat robot gets its own icon, `graphics/items/incinerator.png`,
derived from the Incinerator bot sprite sheet.

Incinerator directions are rendered north-first and clockwise for Factorio's
`RotatedAnimation` order. The pack step also applies a modest brightness lift so
the black metal survives at in-game scale.

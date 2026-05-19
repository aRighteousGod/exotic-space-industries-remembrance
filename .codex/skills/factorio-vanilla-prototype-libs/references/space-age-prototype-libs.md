# Space Age Prototype Libs

Survey source: `C:\Program Files (x86)\Steam\steamapps\common\Factorio\data\space-age\prototypes` from Factorio 2.0.76.

Space Age has no `data/space-age/lualib` directory. Treat these as data/prototype-stage modules supplied by the `space-age` mod, and only import them when ESIR's dependency surface makes Space Age available.

## Common ESIR Imports

- `__space-age__.prototypes.entity.sounds`: Space Age entity, enemy, machine, and ambient sound tables. ESIR uses it in asteroid work.
- `__space-age__.prototypes.item_sounds`: Space Age item sound tables. ESIR uses it in asteroid item work.
- `__space-age__.prototypes.item-effects`: item effect capsule/sticker helper data. ESIR uses it for asteroid item definitions.
- `__space-age__.prototypes.factoriopedia-simulations`: Space Age simulation definitions. ESIR uses it in `prototypes/more-asteroids.lua`.
- `__space-age__.prototypes.planet.asteroid-spawn-definitions`: route/asteroid probability helpers and route constants. ESIR Gaia uses this surface for asteroid spawn definitions.
- `__space-age__/prototypes/planet/planet-map-gen`: returns the Base map-gen table extended with Space Age planet map-gen functions. ESIR Gaia extends this table with its own planet map-gen function.

## Planet, Route, And Procession Helpers

- `planet/asteroid-spawn-definitions.lua`: returns `asteroid_functions` with route constants, asteroid ratios, probability interpolation helpers, and `spawn_definitions(data, planet)`.
- `planet/planet-map-gen.lua`: extends Base `planet_map_gen` with `vulcanus()`, `gleba()`, `fulgora()`, and `aquilo()`.
- `planet/general/general-functions.lua`: returns helpers for rocket parts, pod overlays, pod animations, jet bursts, and simple table concatenation for procession data.
- `planet/general/*`: returns procession layer/audio/space-layer tables used by platform-to-planet and planet-to-platform sequences.

Use these when ESIR needs to stay aligned with Space Age route, planet, cargo-pod, or procession data. Re-check live files for signatures before adding new custom planet behavior.

## Entity, Item, Particle, And Tile Helpers

- `entity/sounds.lua`: returns Space Age `sounds` table for machines, enemies, weapons, and environmental entities.
- `entity/explosion-animations.lua`: returns asteroid explosion animation helpers for chunk/small/medium/big/huge asteroids plus magma eruption.
- `entity/cargo-pod-catalogue.lua`: returns Space Age cargo-pod catalogue data.
- `entity/space-enemy-autoplace-utils.lua`: wraps Base enemy autoplace helpers for Gleba spawner placement.
- `entity/gleba-ai-settings.lua`: returns shared Gleba enemy AI settings.
- `item-effects.lua`: returns Space Age item effect tables for capsule/effect style item definitions.
- `item_sounds.lua`: returns Space Age item sound tables.
- `particle-animations.lua`: adds lava, asteroid, pentapod, demolisher, Gleba vegetation, and related particle picture helpers.
- `tile/tile-sounds.lua`: returns Space Age walking/driving/building/landing/ambient tile sound groups.
- `tile/tile-pollution-values.lua`: returns merged Base and Space Age tile pollution values.
- `tile/tile-trigger-effects.lua`: extends Base trigger effects with Space Age tile variants such as hot lava.

## Graphics Precedent

Space Age has many picture modules for machines and weapons, including asteroid collector, biochamber, crusher, cryogenic plant, electromagnetic plant, foundry, fusion system, and railgun turret pictures.

Use them as read-only precedent for:

- layer ordering and shadow/light/mask conventions
- `util.sprite_load` option shape
- graphics_set structure
- working visualisations and status lamp placement
- frozen graphics variants

Avoid importing or copying large picture modules just to borrow asset paths. Prefer ESIR asset pipeline skills for new art and Factorio Lua docs for exact prototype fields.

## Re-Check Commands

```powershell
$sa = 'C:\Program Files (x86)\Steam\steamapps\common\Factorio\data\space-age\prototypes'
rg --no-heading --line-number 'asteroid_functions\.|planet_map_gen\.|return item_effects|return sounds|return space_age_item_sounds' $sa -g '*.lua'
rg --no-heading --line-number '__space-age__\.prototypes|__space-age__/prototypes' exotic-space-industries-remembrance -g '*.lua'
```

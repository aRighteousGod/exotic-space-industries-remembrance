# Base Prototype Libs

Survey source: `C:\Program Files (x86)\Steam\steamapps\common\Factorio\data\base\prototypes` from Factorio 2.0.76.

Use Base prototype helper modules when ESIR wants canonical vanilla shapes for data-stage sounds, effects, graphics metadata, tile behavior, simulation snippets, or planet/procession tables. Re-check the live file before relying on exact table keys.

## Common ESIR Imports

- `__base__.prototypes.entity.sounds` or `__base__/prototypes/entity/sounds`: canonical entity and enemy sound tables/functions. ESIR imports it globally in `data.lua` and locally in turret/combinator prototypes.
- `__base__.prototypes.entity.hit-effects`: hit effect helpers such as entity, wall, biter, rock, and flying robot effects. ESIR imports it in `data.lua`, `orbital-combinator.lua`, `sawblade-turret.lua`, and camp-fire prototypes.
- `__base__.prototypes.item_sounds`: common item inventory/drop sound tables. ESIR imports it in `data.lua` and asteroid/item work.
- `__base__.prototypes.item-tints`: vanilla item tint constants. ESIR imports it in `data.lua` and asteroid item work.
- `__base__.prototypes.factoriopedia-simulations`: vanilla Factoriopedia simulation definitions. ESIR imports it in `data.lua`.
- `__base__.prototypes.decorative.decorative-trigger-effects`: decorative trigger-effect helpers. ESIR uses it for camp-fire style environmental effects.
- `__base__.prototypes.entity.combinator-pictures`: installs combinator picture globals used by vanilla combinator prototypes. ESIR uses it for orbital combinator/cohort prototype construction.

## Entity And Effect Helpers

- `entity/sounds.lua`: returns a `sounds` table for deconstruction, robot, explosion, biter, spitter, worm, and many entity loop/open/close sounds.
- `entity/hit-effects.lua`: returns a `hit_effects` table for generic entities, taller entities, walls, biters, rocks, and flying robots.
- `entity/explosion-animations.lua`: returns explosion animation helpers for gunshots, hit/dust/small/medium/big/nuke explosions, shockwaves, laser bubbles, and artillery muzzle flash.
- `entity/smoke-animations.lua`: returns smoke animation helpers such as trivial smoke, fast smoke, nuke smoke, and fire smoke.
- `particle-animations.lua`: returns particle picture helpers for metal, wood, vegetation, shell, stone, copper, iron, dust, water, blood, sparks, and similar debris.
- `fire-util.lua`: returns fire picture/smoke/burnt-patch helpers and can add common fire graphics/effects to fire prototypes.
- `entity/movement-triggers.lua`: returns large movement trigger tables for footsteps, particles, and tile interaction effects.
- `entity/rocket-projectile-pictures.lua`: returns rocket projectile animation/shadow/smoke picture helpers.
- `entity/cargo-pod-catalogue.lua`: returns base cargo-pod catalogue data.

Use these helpers when matching vanilla data shape is more important than ESIR-specific policy. Use `ei_lib` for ESIR-owned mutation or normalization around those tables.

## Tile, Planet, And Simulation Helpers

- `tile/tile-sounds.lua`: returns walking, driving, building, and ambient tile sound groups, including parameterized oil/water sound helpers.
- `tile/tile-collision-masks.lua`: returns collision-mask helpers for out-of-map, water, shallow water, ground, lava, oil ocean, and meltable tiles.
- `tile/tile-graphics.lua`: returns vanilla tile graphics tables and spritesheet layout conventions.
- `tile/tile-trigger-effects.lua`: returns tile trigger effects for sand, dirt, grass, concrete, water, lab tiles, and related surfaces.
- `planet/planet-map-gen.lua`: returns `planet_map_gen` with `nauvis()`.
- `planet/procession-style.lua`, `procession-graphic-catalogue-types.lua`, and `procession-audio-catalogue-types.lua`: return procession metadata tables used by route/cargo-pod sequences.
- `factoriopedia-simulations.lua` and `tips-and-tricks-simulations.lua`: return simulation definition tables; use as data-stage precedent, not runtime control logic.

## Re-Check Commands

```powershell
$base = 'C:\Program Files (x86)\Steam\steamapps\common\Factorio\data\base\prototypes'
rg --no-heading --line-number 'return sounds|return hit_effects|return item_sounds|return item_tints|return fireutil' $base -g '*.lua'
rg --no-heading --line-number '__base__\.prototypes|__base__/prototypes' exotic-space-industries-remembrance -g '*.lua'
```

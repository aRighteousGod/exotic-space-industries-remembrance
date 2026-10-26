<a id="contract"></a>
# Worker robot progression and fleet conversion

Wraithline and Architectum are quantum-age upgrades to Obelisk and Spearling.
Native robot prototypes own performance; there is no scripted movement,
payload handling, persistent state, or scheduling.

## Implementation sources

- [robots.lua](../../../exotic-space-industries-remembrance/prototypes/electricity-age/robots.lua)
- [final-recipe-fixes.lua](../../../exotic-space-industries-remembrance/scripts/data-final-updates/final-recipe-fixes.lua)

## Native performance

| Robot | Payload | Tiles/tick | Movement energy | Flight energy/tick | Battery | Health |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Obelisk | 25 | 0.10 | 6.25 kJ | 2.25 kJ | 25 MJ | 1,400 |
| Wraithline | 30 | 0.30 | 10 kJ | 0.1 kJ | 200 MJ | 2,100 |
| Spearling | 5 | 0.10 | 10 kJ | 0.1 kJ | 25 MJ | 1,400 |
| Architectum | 10 | 0.24 | 5 kJ | 0.1 kJ | 50 MJ | 2,100 |

Base values precede native research and quality. Charging thresholds and depleted
speed multipliers are unchanged. Native construction job scheduling means payload
is not a promise of proportional build speed.

<a id="conversion"></a>
## Conversion and recycling ownership

`bot_conversions` adds two four-second crafting recipes. Each consumes one matching
middle-tier bot, four processing units and four advanced bot engines and returns one
advanced bot. `ei-advanced-bots` unlocks both alongside the unchanged direct recipes.
Conversions prohibit productivity, decomposition and intermediate hand crafting;
native quality is allowed. `auto_recycle = false` leaves recycling ownership with
the direct recipes, including ESIR's late recycling pass. Both routes make the same item.

The shared final recipe pass normally re-enables decomposition on ESIR recipes.
It explicitly exempts these two conversion names while retaining its existing
signal visibility and result-unlock policy. This exception must survive before
the subsequent recycling pass runs.

That shared owner also retains its established recipe normalization, productivity
allowlist, material-alias merges, compatibility unlocks, barrel capacity adjustments,
selected item stacking rules and startup science-yield adjustments. The robot
change affects only the two decomposition opt-outs; those broader behaviors are
not rebalanced by this contract.

Names compose existing localized target and donor names separated by a left arrow.
The target icon and donor corner badge distinguish adjacent recipe choices.

## Lifecycle and presentation

Factorio refreshes recipes and technology effects when prototypes change. Already
researched forces gain conversions through that native load path, without a custom
migration or global recipe reset. Existing entities and items retain their identities.
Presentation and death finalizers retain ownership of effects, sounds and scenes.

## Verification

Run blueprint/preflight checks, `qc-fast`, and `scripts/invoke-robot-progression-qc.ps1`.
Check fresh and upgraded saves, quality crafting, recycling and presentation.
Compare 20 normal-quality bots per fleet over 32- and 128-tile routes with equal
research and infrastructure, including delivery, construction, deconstruction,
repairs and charging. Report visual captures separately from headless evidence.

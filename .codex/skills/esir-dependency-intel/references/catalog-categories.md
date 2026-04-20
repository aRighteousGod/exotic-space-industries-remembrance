# Dependency Categories

- `runtime-integration`: runtime/control touchpoints driven by `control.lua` or `scripts/control`
- `prototype-integration`: data-stage touchpoints driven by `scripts/data-updates` or `scripts/data-final-updates`
- `planet-content`: hidden-optional content or planet integrations that ESIR conditionally patches
- `remote-interface`: explicit remote interface bridges, checks, or calls involving external mods
- `media-pack`: shallow metadata entries for ESIR graphics and soundtrack companion packs

CLI category mapping:

- `runtime` -> `runtime-integration`
- `prototype` -> `prototype-integration`
- `planet` -> `planet-content`
- `remote` -> `remote-interface`
- `media` -> `media-pack`

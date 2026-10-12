# Minigun Turret HD delivery

The new identity is `minigun-turret-HD` 1.0.0. Main uses version 1.3.42 and
declares the renamed pack as its first optional dependency. Graphics 6 remains
the complete SD pack; its item-icon revision is included beside the new ZIPs.

Without main, the pack adds `minigun-turret-hd` entity, item, recipe and technology.
Base games use chemical-tier research and ordinary materials. Space Age uses
metallurgic research and tungsten. The turret can be crafted on any planet.
With main, the HD pack adds no duplicate content.

The user's final balance correction takes precedence over the original plan:
bullet damage multiplier is 1. The original native turret fires at its one-shot
per-tick cap despite a nominal 0.25 cooldown. Standalone cooldown is 1 / 0.9,
giving 54 shots per second against the original's 60 in the measured steady window.
Main gameplay is unchanged. Research bonuses match the gun turret.

The graphics, complete HD shadows, calibrated launch map and enlarged item icon
are retained. Shipping metadata omits private paths and development reports.
Seven locales use short functional text. GPL-3.0-or-later and sound credits remain.

`validation.json` records all three successful Factorio 2.0.77 data loads and
their final prototype values. The base-only case explicitly disables all expansion
mods because Factorio otherwise enables newly discovered built-ins by default.
`package-report.json` records exact inventories and archive hashes. Historical
render/firing acceptance reports have not been rewritten for the rename.

The short visual check uses `invoke-firing-check.ps1` after the shared engine is
free. Its isolated rig supplies electricity and piercing magazines, captures
preparation, firing, folding and native inventory/entity/research windows, and
compares the revised cooldown with the original in a steady firing window.

The ZIPs are staged for later installation. Replace the main ZIP with 1.3.42,
enable `minigun-turret-HD`, and disable the previous HD entry. Graphics 6 is needed
by main, not by standalone games. No entity or storage migration is performed.

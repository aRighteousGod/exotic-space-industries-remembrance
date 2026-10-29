# Requested graphics cleanup / 2026-10-28

| Asset | Before | After | Bytes removed |
|---|---|---|---:|
| EM locomotive temporary sheets | Graphics 2 `graphics/entities/em_trains/em-locomotive-temp_1.png` and `_2.png` | Removed; current non-temporary sheets retained | 13,798,827 |
| EM wagon temporary sheets | Graphics 2 `graphics/entities/em_trains/em-wagon-temp_1.png` and `_2.png` | Removed; current non-temporary sheets retained | 14,478,737 |
| Original gatling sheets | Graphics 3 `graphics/entities/gatling-turret/gatling-place.png` and `gatling-sheet.png` | Removed; current Graphics-6 turret art retained | 4,347,163 |
| Shared sticker spark | Graphics 3 `graphics/entities/acid-turret/acid-flame/spark.png` | Moved unchanged to `graphics/effects/stickers/spark.png`; obsolete folder removed | 0 |
| Legacy nuclear locomotive light cone | Graphics 3 `graphics/entities/nuclear_locomotive/nuclear_locomotive_light_cone_280x400.png` | Moved unchanged to Graphics 5 `graphics/entities/nuclear-locomotive/nuclear_locomotive_light_cone_280x400.png` | 0 |

Net source reduction: **32,624,727 bytes (31.11 MiB)** from six removed PNGs.
The two relocated PNGs preserve their exact bytes. The retained legacy nuclear
light cone is not currently selected; Goliath still uses its existing Graphics-5
`hid-light-cone.png`. Its relocation does not replace the current headlight.

## Behavior and ownership

The spark remains active in poison, rocket and exotic-ammunition stickers.
Four path substitutions across `acid.lua`, `exotic-magazine-effects.lua` and
`rocket-ammo-effects.lua` point consumers to the new location. Source comparison
permits only those substitutions: pixels, animation dimensions/timing, tints,
damage, durations, slowing, identities and all gameplay fields are unchanged.

There are no runtime, migration, settings, remote-interface or locale changes.
Existing saves retain the same entities and effects. Death and entity presentation
remain inherited from the unchanged current definitions. The acidthrower model
and retirement note now identify the shared sprite's location. Versions remain
Graphics 2/3/5 **1.1.0**, main ESIR **1.4.0**.

## Verification and delivery boundary

Evidence: `.factorio-qc/graphics-prune-20261028/`. `before.json` confirms every
removed or moved PNG matched its committed original before editing;
`verification.json` records exact removals, relocation hashes and source parity.
Production Lua has no remaining references to retired filenames/paths. A
literal-reference scan of 146 installed external archives from enabled mod
families (2,034 Lua members, including retained versions) found no references to
the removed train/gatling files or former spark path. This does not cover every
third-party mod published elsewhere.

Wrapper structural asset checks pass with no asset warnings/errors. Its overall
result retains the unrelated historical mojibake finding in
`scripts/qc/singularity-lance/angular-results.json`; that evidence is unchanged.
The final Factorio 2.1.23 run completes with no engine errors (existing advisory
mod-log warnings remain). The focused final-data check passes: all **2,799**
Graphics 1-6 PNG/audio paths resolve, all **13** shared-spark sticker definitions
select the relocated image, no retired path remains, the gatling selects
Graphics 6, and the nuclear locomotive retains `hid-light-cone.png`.
`qc-fast-final.json` identifies the accepted engine dump; the earlier `qc-fast.json`
is an intermediate snapshot taken before both ammunition path updates and is not
the final acceptance result. `scripts/qc/acid-jet/check.py` now expects the new
spark location; its Python syntax passes. Only paths changed in production Lua.
No new rendered, multiplayer, performance or audio acceptance is claimed.

This source cleanup follows the previously accepted release candidates. Existing
packaged/installed ZIPs and their historical hashes remain unchanged; main ESIR
and Graphics 2, 3 and 5 must be rebuilt together to deliver it. The user explicitly
owns that rebuild. Earlier release
reconciliation remains evidence for its recorded candidate, not this later source
state. No version bump, upload, commit or push is part of this cleanup.

## Mod Portal executable-file cleanup

Following the upload rejection, all six source graphics packs were scanned
recursively. The two remaining Python files, Graphics-3
`graphics/icons/generate_mip.py` and `graphics/tech/generate_mip.py`, were moved
byte-for-byte into `.codex/esir/asset-generators/legacy-mipmaps/` with distinct
filenames and usage notes. The glow generator and Python caches were already
absent when this scan began; existing deletions were preserved.

The final scan covers 3,711 files and finds no `.exe`, `.bat`, `.ps1`, `.sh`,
`.py`, `.pyc`, `.pyo`, `.cmd`, `.com`, `.dll`, `.msi`, `.scr` or `__pycache__`
content in any graphics pack. Preserved generator syntax and relocation hashes
pass. This changes development-file placement only; image assets and gameplay
are unchanged. Rebuilding remains with the user.

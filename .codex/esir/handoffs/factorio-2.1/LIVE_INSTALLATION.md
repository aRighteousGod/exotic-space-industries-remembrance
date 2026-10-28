# Real Factorio 2.1 installation — 2026-10-28

Status: accepted. The Steam Factorio **2.1.23** executable loaded the real mod
directory, created a fresh test save and completed **600 ticks** with the
user’s configuration. Existing player saves were not opened or migrated.

Target: `C:\Users\Theorun\AppData\Roaming\Factorio\mods`.

**95 enabled mods:** 90 external ZIPs plus Base, Space Age, Quality, Recycler
and Elevated Rails. **33 archives added, nine replaced with verified backups,
48 already identical.** All 827 selection records remain explicit; old archives
were neither removed nor quarantined. The original list had 817 records.

ESIR is **1.4.0**, the six graphics packs and two soundtracks are **1.1.0**,
and Deer Continued, Enhanced Walls Continued and Nonstandard Beacons Continued
are **1.0.0**. Main ZIP SHA-256:
`a8fb077a851004e409a74c0450872bddfdee16a4b121dd2f3f2be90509f94822`.

The follow-up native-travel decision rebuilds only ESIR 1.4.0: Rocket silo no
longer grants personal rocket travel; the first Vulcanus, Gleba or Fulgora
discovery does. Existing discovered research grants the permission during the
1.3.41-to-1.4.0 migration. No player save had loaded the interim 1.4.0 build, so
no correction for that build was added. The previous main ZIP is backed up under
`.factorio-qc/pt21/live/before/replaced-archives/`. The original installation
actions below remain historical; this follow-up replaces one main ZIP and retains
89 identical external archives. Current real-folder validation is recorded in
`.factorio-qc/pt21/live/installed-validation.receipt.json`; initial installation
and rollback evidence remain under `.factorio-qc/lv21/`.

## Identity replacements

| Previous ID | Installed ID | Version |
|---|---|---|
| `ArmouredBiters` | `ArmouredBiters21Compat` | 2.0.7 |
| `atan-air-scrubbing` | `air-scrubber` | 0.2.9 |
| `atan-ash` | `atan-ash-fork` | 1.0.1 |
| `doeworks-deer` | `doeworks-deer-continued` | 1.0.0 |
| `enhanced-walls` | `enhanced-walls-continued` | 1.0.0 |
| `zzz-nonstandard-beacons` | `zzz-nonstandard-beacons-continued` | 1.0.0 |
| `celestial-weather` | `celestial-weather-updated` | 1.5.1 |
| `heat_glow` | `heat_glow-temp-21-patch` | 2.0.6 |
| `PipeVisualizer-Updated` | `PipeVisualizer-2-1-Support` | 2.4.51 |
| `even-distribution` | `even-distribution-fork` | 2.1.2 |

## Disabled entries

- `data-utils`: No 2.1 release; no selected mod requires it.
- `prismatic-belts-space-age`: Obsolete separate asset pack; selected Prismatic Belts 3.1.3 supplies Space Age support.
- `recipe-icons-improvement-for-esir`: User explicitly selected disable for now; no published 2.1 release.

Construction Drones Forked **1.1.18 remains enabled**. ESIR’s two electric
drill upgrades now inherit the vanilla drill’s complete collision policy after
the fork and hover-layer passes. Final masks match, and actual vanilla → advanced
→ superior replacements pass at normal and rare quality (four replacements).
No mining speed, recipe, productivity, quality or circuit value changes. Source,
migration and presentation scope are in the Construction Drones entry of
[UPGRADE_SYNOPSIS.md](UPGRADE_SYNOPSIS.md).

## Configuration and preservation

The isolated engine pruned records for archives absent from its staging folder.
Copying that shortened list initially exposed an unlisted old `4k_planets`
archive and a dependency cycle in the real folder. The installer was corrected
to rebuild from the preserved original list and explicitly disable every
unselected installed ID. The repaired real-folder load passes. No archive move
was necessary; the initial failed log and shortened list are retained.

Factorio also rewrites its native configuration: it removes redundant version
pins and converts the settings header from 2.0.77 to 2.1.23. The selected versions
are the highest compatible installed releases; package hashes and all versions
reported by script-loading log entries match the tested selection. Exact ZIP
versions and hashes remain locked in LIVE_INSTALLATION.json.

**All 3,706 existing preference entries are preserved in meaning:** 3,705 are
unchanged; Milestones’ Boolean `milestones_compact_list=false` is converted to
its new string choice `off`, avoiding the new `auto` default. No original entry
was removed. Updated mods add 61 default entries. The second real-folder run
leaves the converted settings bytes stable. The original 2.0 file is backed up
byte-for-byte; the live file is intentionally no longer byte-identical. The
read-only audit uses the official [settings file format](https://wiki.factorio.com/Mod_settings_file_format)
and [PropertyTree format](https://wiki.factorio.com/Property_tree).

Protected backup/evidence root: `.factorio-qc/lv21/` (registered and pinned).
`before/mod-list.json` and `before/mod-settings.dat` are the untouched originals;
`before/replaced-archives/` holds all nine replaced same-name ZIPs. The broader
1.3.41 baseline, exact 2.0 dependency lock and four donor saves remain in the
original protected upgrade run. Do not restore the old selection under 2.1:
rollback pairs that configuration with the preserved 2.0 engine and packages.

For a deliberate rollback with Factorio closed, restore the original two
configuration files and nine backed-up same-name archives, and select the
preserved 2.0.77 installation. New 2.1-only archives can remain disabled.
All source/destination names and before/after hashes are in the installation
receipt. No rollback or existing-save conversion was performed.

## Evidence and limits

- `selection-02.receipt.json`: isolated full configuration, fresh save and 600 ticks.
- `drill-compatibility-03.receipt.json` and fixture: matching masks and four native replacements.
- `installed-validation.receipt.json`: actual Steam executable and real mod folder, fresh save and 600 ticks.
- `settings-conversion.receipt.json`: all existing preferences accounted for and 61 new defaults enumerated.
- `core25/packages-01.receipt.json` and `packages-final-data.receipt.json`: rebuilt main ZIP in the 35-archive core selection, all 24 crystal contracts and approved gameplay fields.
- `installation.receipt.json`: exact copy/replacement actions and rollback hashes.

These are native startup, runtime, replacement and static data checks. Existing
player saves, optional-content progression, rendered interaction, audio and
broad multiplayer behavior are not newly certified by this installation check.
The upgrade synopsis retains their separate evidence and limits. Nothing was
uploaded, committed or pushed.

## Exact installed external versions

Every SHA-256, source path, transitive requirement and evidence hash is recorded
in [LIVE_INSTALLATION.json](LIVE_INSTALLATION.json).

| Mod ID | Version |
|---|---|
| `Accumulator-V2` | 1.0.8 |
| `Arachnids_enemy` | 1.2.1 |
| `ArmouredBiters21Compat` | 2.0.7 |
| `AsphaltRoadsPatched` | 1.5.0 |
| `Assembler-Reskin` | 1.0.4 |
| `Better_Starmap_Background` | 2.4.1 |
| `Cold_biters` | 2.3.0 |
| `Construction_Drones_Forked` | 1.1.18 |
| `CursorEnhancements` | 2.3.1 |
| `DisplayPlatesForked` | 1.7.0 |
| `EditorExtensions` | 2.6.1 |
| `Electric_flying_enemies` | 0.2.1 |
| `Explosive_biters` | 2.4.0 |
| `ExtraZoom` | 3.1.0 |
| `FasterStart` | 2.1.0 |
| `Fill4Me` | 1.0.2 |
| `FilterHelper` | 0.2.29 |
| `Flare Stack` | 4.3.1 |
| `FluidWagonColorMask` | 2.1.0 |
| `Inter-Platform-Logistics` | 2.1.2 |
| `Kruise_Kontrol_Updated` | 0.4.1 |
| `Mad-Faxtorio` | 1.1.1 |
| `Milestones` | 1.5.2 |
| `Mined-Inserters-Dont-Leave-Items` | 1.0.3 |
| `PipeVisualizer-2-1-Support` | 2.4.51 |
| `PollutionCombinator-JamieFork` | 1.2.0 |
| `Pro-Flashlight` | 1.5.9 |
| `Return-Inserter` | 1.0.0 |
| `Robot256Lib` | 2.1.4 |
| `SolarMatrix` | 1.0.9 |
| `SteampunkLamp` | 1.0.4 |
| `Toxic_biters` | 2.1.0 |
| `UndergroundIndicatorsFixed` | 1.4.1 |
| `advanced_spaceship_repair` | 2.1.0 |
| `agricultural-tower-placement-helper` | 1.1.0 |
| `air-scrubber` | 0.2.9 |
| `assault_spidertron_V2` | 2.3.12 |
| `atan-ash-fork` | 1.0.1 |
| `belt-direction-indicator` | 1.0.2 |
| `belt-visualizer` | 2.1.4 |
| `better-victory-screen` | 2.1.1 |
| `birdengineer` | 1.0.2 |
| `cargo-ships-floating-electric-pole` | 2.1.0 |
| `cargo-ships-oil-rig` | 2.1.2 |
| `celestial-weather-updated` | 1.5.1 |
| `ch-concentrated-solar` | 0.6.0 |
| `circuit-connector-placement-helper` | 1.3.0 |
| `colorful_biochamber` | 1.1.5 |
| `configurable-valves` | 2.0.2 |
| `disco-science-lite` | 0.6.2 |
| `doeworks-deer-continued` | 1.0.0 |
| `elevated-pipes` | 1.5.0 |
| `enhanced-shadows` | 1.0.6 |
| `enhanced-walls-continued` | 1.0.0 |
| `erm_starcraft_music` | 2.1.1 |
| `even-distribution-fork` | 2.1.2 |
| `even-pickier-dollies` | 3.2.0 |
| `exotic-space-industries-remembrance` | 1.4.0 |
| `exotic-space-industries-remembrance-graphics-1` | 1.1.0 |
| `exotic-space-industries-remembrance-graphics-2` | 1.1.0 |
| `exotic-space-industries-remembrance-graphics-3` | 1.1.0 |
| `exotic-space-industries-remembrance-graphics-4` | 1.1.0 |
| `exotic-space-industries-remembrance-graphics-5` | 1.1.0 |
| `exotic-space-industries-remembrance-graphics-6` | 1.1.0 |
| `exotic-space-industries-remembrance-soundtrack-1` | 1.1.0 |
| `exotic-space-industries-remembrance-soundtrack-2` | 1.1.0 |
| `factorioplus-assets-turrets` | 1.0.0 |
| `factorioplus-assets-vehicles` | 1.0.1 |
| `far-reach` | 2.1.0 |
| `faster-roads` | 1.0.0 |
| `flib` | 0.17.2 |
| `gvv` | 0.6.0 |
| `heat_glow-temp-21-patch` | 2.0.6 |
| `informatron` | 0.5.0 |
| `k2-steel-pipes` | 2.2.0 |
| `koboldengineer` | 1.0.2 |
| `light-overhaul` | 0.3.0 |
| `load-spreader` | 2.0.0 |
| `mferrari_graphics_pack_1` | 0.0.5 |
| `notice-me-senpai` | 1.1.0 |
| `perel` | 1.2.2 |
| `prismatic-belts` | 3.1.3 |
| `reskins-sprite-utils` | 0.2.1 |
| `rp_art_util` | 3.0.0 |
| `rp_steam_intermediates` | 1.0.0 |
| `rp_steam_roboports` | 2.1.0 |
| `textplates` | 0.8.0 |
| `valves-lib` | 2.0.0 |
| `zeus-wrath` | 1.0.6 |
| `zzz-nonstandard-beacons-continued` | 1.0.0 |

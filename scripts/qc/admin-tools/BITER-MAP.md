# Biter map visibility investigation

Verified against installed Factorio **2.0.77 build 84539**, 2026-10-02. The reported missing control concerns the **M-map display/layer menu**.

## Confirmed unit-visibility owner

Installed **Fire Lights 0.14.0** adds `not-on-map` to live units when its startup setting **Hide Enemy Units On Maps** (`fl-disable-unit-onmap`) is enabled. This setting defaults to true.

The exact installed archive is `%APPDATA%/Factorio/mods/fire-lights_0.14.0.zip`, SHA-256 `b555a4f76c3f322c7b2fcad4aa6466d8cc340074ce4d7f6d1515d1022a97ed9b`. Its `settings.lua` declares the option; `data/settings.lua` reads it; `data-final-fixes.lua:49-53` applies `add_flags(..., "not-on-map")` to all `unit`, `spider-unit`, and `spider-leg` prototypes. Its English locale names the setting and explains removal of enemy-unit markers from the map/minimap. ESIR source searches found no writer adding this flag to ordinary live biters or spitters. Vanilla corpse flags are unrelated.

The actual installed startup settings were read, rather than inferred from the default. Initial inspection decoded `fl-disable-unit-onmap=true` from the native one-entry `value` dictionary in `mod-settings.dat` (key offset 17358, boolean payload offset 17394; SHA-256 `eafc06bfc12272ed23621dd4f15e01c1b26861d74466c06defde2c61f016a590`). A final read-only recheck found the same setting **false**, with file SHA-256 `3cbe5b35fa028c110a843d170b87be272130f40a70dd9c91d9911be67039112c`. The investigation's fixture drivers did not modify or copy back to the installed profile; the actor responsible for that intervening change was not established.

The supported correction is to disable this Fire Lights startup option and reload Factorio's prototypes. The latest saved option is already off; the state of an independently running game was not inspected. No ESIR override or blanket flag removal is required.

## Native engine evidence

The complete ESIR dependency fixture **h2** finished successfully. Its native report identifies ESIR 1.3.40, Fire Lights 0.14.0, DataUtils 0.10.2, and actual hide-units setting true. All eight normal live biter/spitter prototypes had `not-on-map=true`; `biter-spawner` and `small-worm-turret` had the flag false. All ten requested entities were created.

The accepted minimal pair **mh2 / mv2** used identical actual native profiles: base / Space Age / quality / elevated rails 2.0.77, Fire Lights 0.14.0, DataUtils 0.10.2, and the disposable probe. ESIR and its asset packs were absent from this pair.

| Check | Hide units true: mh2 | Hide units false: mv2 |
|---|---|---|
| Eight live biter/spitter flags | all true | all false |
| Nest / worm flags | false / false | false / false |
| Entity creation | 10/10 | 10/10 |
| Low zoom | 1/16, native chart mode 2 | 1/16, native chart mode 2 |
| Native map-layer panel | 11 buttons | identical 11 buttons |
| High zoom | 1, detailed remote-view mode 3 | 1, detailed remote-view mode 3 |

Both low-zoom fixtures explicitly assert `player.render_mode == defines.render_mode.chart`. Their native GUI layer panel, screenshot bounds `(1652,183)-(1909,307)`, is **pixel-identical: zero differing pixels**. The separate `show-non-standard-map-info=false` captures also produce identical panels. Changing Fire Lights' unit flags therefore **does not remove a native M-map layer button** in this tested profile.

The native layer panel appears below **Add tag / Add ping** in chart mode and is absent from detailed, zoomed-in remote view. This explains the panel's general zoom-dependent visibility; it does not identify a remembered biter-specific button.

## The remembered biter layer control

Installed 2.0.77 `MapViewSettings`, the English `[gui-map-view-settings]` locale block, and native map-layer utility sprites expose networks, turret coverage, pollution, station/player names, tags, worker robots, signals, recipes, and pipelines. They expose **no enemy/biter layer field or button**. A read-only scan of installed mod runtime/GUI code found no active provider removing such a control. Official changelog/forum searches did not establish a native version in which an enemy toggle was removed.

`show-non-standard-map-info` is undocumented in the installed API; its name is not evidence that it is an enemy toggle. The installed profile had it true, and changing it did not change the paired native layer panels. `LuaPlayer.map_view_settings` is write-only in 2.0.77; the fixture used its setter and never treated a read as valid.

The historical control's original provider remains **unidentified**. The confirmed result is that Fire Lights owns invisible unit markers and does not conditionally remove the tested native layer controls. No native UI override was added.

## Evidence and capture limits

Accepted reports and images are ignored fixture artifacts:

- `.factorio-qc/bm/h2/script-output/biter-map-probe.json`: complete ESIR profile and native unit flags.
- `.factorio-qc/bm/mh2/script-output/biter-map-probe.json`: true-setting minimal profile, flags, and chart assertions.
- `.factorio-qc/bm/mv2/script-output/biter-map-probe.json`: false-setting matching profile, flags, and chart assertions.
- `.factorio-qc/bm/{mh2,mv2}/script-output/map-chart.png`: paired native chart GUI overlays.
- `.factorio-qc/bm/{mh2,mv2}/script-output/map-chart-nonstandard-off.png`: paired legacy-field comparison.
- `output/admin-implementation/biter-map-comparison.json`: actual profile equality, flag values, and pixel comparison.
- `output/admin-implementation/invoke-biter-map-probe.ps1` and `biter-map-probe/`: isolated fixture driver and replay sources.

`game.take_screenshot` renders detailed world terrain even while the player is in chart mode; its GUI overlay reflects the actual native chart controls. The reports independently assert chart mode. An OS capture of the owned hidden client was attempted, but it exposed no capturable main window handle. No actual desktop or flat-map-background capture is claimed. mh2's first driver result rejected that optional capture after a valid native completion; its report and screenshots are complete. The driver now reports that limitation as a warning.

The earlier h2 zoom-0.2 images were detailed remote view and were not accepted as a chart comparison. The full-profile false-setting v1 run timed out during asset loading and supplied no runtime evidence. All investigation-owned engines were stopped; unknown Factorio processes were preserved. No live settings, saves, mod list, or shipping gameplay source were changed by these probes.

Primary references:

- [2.0.77 EntityPrototypeFlags](https://lua-api.factorio.com/2.0.77/types/EntityPrototypeFlags.html)
- [2.0.77 MapViewSettings](https://lua-api.factorio.com/2.0.77/concepts/MapViewSettings.html)
- [2.0.77 LuaPlayer.map_view_settings](https://lua-api.factorio.com/2.0.77/classes/LuaPlayer.html#map_view_settings)
- [2.0.77 LuaGameScript.take_screenshot](https://lua-api.factorio.com/2.0.77/classes/LuaGameScript.html#take_screenshot)
- [Official forum: historical map-view-settings API controls](https://forums.factorio.com/viewtopic.php?p=550012)
- [Fire Lights mod page](https://mods.factorio.com/mod/fire-lights) (the exact installed 0.14.0 source above is the version-specific evidence).

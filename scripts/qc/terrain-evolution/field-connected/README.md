# Illustrated Ecology native fixture

This focused helper requires a real
connected graphical client and the current upgraded terrain GUI/field report.
It does not modify the existing V2 native-alert scenario. Transient native-property
and row-array proxies deliberately add overhead to the first instrumented services;
that phase must not be used for performance timing. The separate profiling tail
restores the actual compose and snapshot functions and times naturally admitted
ordinary GUI refreshes without proxy construction or independent invariant checks.

Run from the repository root, with other Factorio instances closed:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/qc/terrain-evolution/run-field-report.ps1 -Locale en -OutputRoot .factorio-qc/efr1/en
powershell -ExecutionPolicy Bypass -File scripts/qc/terrain-evolution/run-field-report.ps1 -Locale ja -OutputRoot .factorio-qc/efr1/ja
powershell -ExecutionPolicy Bypass -File scripts/qc/terrain-evolution/run-field-report.ps1 -Locale ru -OutputRoot .factorio-qc/efr1/ru
powershell -ExecutionPolicy Bypass -File scripts/qc/terrain-evolution/run-field-report.ps1 -Locale de -OutputRoot .factorio-qc/efr1/de
powershell -ExecutionPolicy Bypass -File scripts/qc/terrain-evolution/run-field-report.ps1 -Locale en -Scale 2 -OutputRoot .factorio-qc/efr1/s2
```

The runner stages the current source with a copied fixture save, matching helper
locale and private INI. `run-admin.ps1` reads `terrain-admin-qc.json`. The fixture
gates on the actual client locale, 1280x720 viewport and requested display scale.
Override `-SeedMods` and `-SaveInput` for another isolated dependency seed/save.
Use `-Quick` to keep the two-world/lifecycle checks and eight instrumented
refreshes while omitting the hundred-refresh profiling tail.

The English config requests fifty independently instrumented native admissions and
one hundred unwrapped natural refreshes. Set `instrumented_services=8`,
`profiled_services=0`, and `all_planets=false` for shorter JA/RU/DE translation
runs. The English tail requires about one hundred simulation seconds. It never
forces a refresh deadline. Native profiling records use `ECOLOGY_FIELD_PROFILE`
lines; no whole-engine or rendered-frame performance claim follows from them.

`all_planets=true` captures all six associated worlds; false still captures Nauvis
and Fulgora. Every run additionally captures frozen and permanent daylight on
Nauvis, rapid A-B-A remote viewing, first-use retirement of an older saved GUI
layout, and a remote utility surface. Factorio's native permanent-day setter also
holds time; the fixture checks the resulting flags instead of assuming those two
setters are independent. Each case submits top,
middle and bottom captures. The helper uses `game.planets[name].create_surface()`
only in explicit fixture setup; later report interactions must preserve surface
count. Native requests translate the actual visible captions and tooltips, with
eight translation submissions per helper tick.

After the captures, the fixture renames its viewed utility surface through the
native setter, begins partial Advanced population, returns to Simple on Nauvis,
and queues deletion of that utility. Real lifecycle events must update the surface
catalog; Simple must become ready without completing Advanced. Only the explicitly
created unassociated fixture utility is deleted, and the expected surface count
then decreases by exactly one.

All scenario time/calendar edits are confined to the copied fixture save; held
and permanent flags are restored afterward. The real field observer must preserve native light
fields and Fulgora controller state within every compose call. The native GUI
update is required to perform at most eight property assignments and thirty-two
binding inspections per admitted call, with handles restored before returning.
No proxy survives a tick or save boundary.

Japanese, Russian and German runs also use the field-guide button to open native
Informatron and verify the Ecology window closes. The final close waits 180 ticks
and requires no report compositions or public
snapshots. The separate seasonal launcher may continue its own cheap updates.
Static locale parity remains necessary: native translation success can conceal
English fallback. This fixture does not prove mouse interactions, native
multiplayer, or whole-engine performance. The scale-two run exercises the stacked
layout; other display sizes and scales still need separate acceptance.

Zero-duration light segments must be invisible: native progress-bar borders can
remain visible at width zero. Rendering checks wait for both the current caption
and segment bindings, rather than treating a fresh composition as proof that all
of its widgets are already drawn. Static construction on open or one-time layout
replacement is separate from the eight-dynamic-write refresh allowance.

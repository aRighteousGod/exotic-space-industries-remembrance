# Combat doctrine acceptance fixtures

Run `scripts/invoke-combat-doctrines-qc.ps1` against installed Factorio 2.0.77.
The driver stages ESIR and dependencies under ignored `.factorio-qc/pr-bd`.
Only that staged copy receives snapshot hooks; shipping dispatchers are untouched.

Final `data.raw` assertions compare complete impact payloads, source effects,
launch multiplicity, stable helpers, capacity, geometry, travel, terrain floors
and presentation isolation. The matrix covers ten doctrines per system and four
toggle combinations. Native firing uses disposable receivers and real ammunition.
Reports distinguish engine simulation evidence from graphical scene review.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-combat-doctrines-qc.ps1 -Matrix
powershell -ExecutionPolicy Bypass -File scripts/invoke-combat-doctrines-qc.ps1 -Runtime -Ballistic needle-oath
powershell -ExecutionPolicy Bypass -File scripts/invoke-combat-doctrines-qc.ps1 -Transition
powershell -ExecutionPolicy Bypass -File scripts/invoke-combat-doctrines-qc.ps1 -Visual -Pyric apotheosis
powershell -ExecutionPolicy Bypass -File scripts/invoke-combat-doctrines-qc.ps1 -Visual -PyricDisabled
powershell -ExecutionPolicy Bypass -File scripts/invoke-combat-doctrines-qc.ps1 -Performance -Ballistic needle-oath
powershell -ExecutionPolicy Bypass -File scripts/invoke-combat-doctrines-qc.ps1 -Performance -BallisticDisabled
powershell -ExecutionPolicy Bypass -File scripts/invoke-combat-doctrines-qc.ps1 -Performance -MissScene
powershell -ExecutionPolicy Bypass -File scripts/invoke-combat-doctrines-qc.ps1 -Performance -MissScene -Ballistic terminal-barrage
powershell -ExecutionPolicy Bypass -File scripts/invoke-combat-doctrines-qc.ps1 -Performance -MissScene -BallisticDisabled
powershell -ExecutionPolicy Bypass -File scripts/invoke-combat-doctrines-qc.ps1 -Rendering -Pyric apotheosis -Ballistic needle-oath
powershell -ExecutionPolicy Bypass -File scripts/invoke-combat-doctrines-qc.ps1 -Rendering -PyricDisabled -Ballistic needle-oath
powershell -ExecutionPolicy Bypass -File scripts/invoke-combat-doctrines-qc.ps1 -Compatibility
powershell -ExecutionPolicy Bypass -File scripts/invoke-combat-doctrines-qc.ps1 -Overlap
```

The firing fixture runs 109 isolated cases: all eleven magazines and four shotgun
families, ammunition and turret research modifiers, quality, Defender, finalized
spider machine guns, three force-interception policies, all five quality range
boundaries, both real ESIR shotgun turrets and handheld firing by native characters.
Needle Oath isolates exact impacts;
Tempered also exercises default scatter. Launch/impact script effects exist only
in the staged fixture. Headless source flashes bypass visibility only to count
one creation per discharge; graphical runs retain native visibility.

Native penetration continues through targets it kills, then stops at a surviving
target. Fragile neutral receivers isolate that condition without automatic turret
retargeting. Save transitions rebuild startup data from Terminal Barrage/Apotheosis
into disabled and Tempered modes, reload an unchanged disabled save, fire exact
saved magazine contents and complete a saved private projectile once. The saved
projectile is fired by a legendary native turret with ammunition and turret damage
bonuses; its one impact retains research modifiers and quality after startup changes.

Graphical scenes include fuel flames/streams/stickers, ordinary explosion and
muzzle effects, three visible projectile lanes and a real silo launch. The driver
creates a short staging junction for Windows asset-path limits and supplies the
installed Steam application identity. It launches and stops only its own process.
Screenshot timing includes a same-tick muzzle frame and later tracer positions.
Capture frames distort render timing; the render CSV is diagnostic evidence,
not a clean GPU performance comparison.
The separate Rendering mode uses the 100-turret scene, a fixed spectator view and
no screenshots to assess native rendering cost with equal projectile simulation.
The native frame interval can remain display-limited; report CPU timing and the
limit explicitly instead of treating the GPU-frame column as isolated GPU work.

Simulation benchmarks run 100 native turrets for 3,600 ticks, three times, without
rendering or per-shot QC observation scripts. Compare otherwise equal enabled and
disabled scenes. This is a bounded projectile simulation measurement, not a claim
about an entire factory's UPS.
`-MissScene` uses narrow receivers assigned farther downrange to exercise scatter
and retained projectile travel. Native acquisition and interception still apply;
the scene does not guarantee every shot travels the assigned distance. Its single
snapshot reports discharged rounds, native hits and active projectiles. Pending
projectiles make that hit count unsuitable as a final accuracy percentage.
Compare the default and Terminal Barrage scenes with the disabled baseline to
separate short-hit cost from the larger population of travelling missed shots.

Overlap QC stages the two actual optional counterparts and their shared utility
dependency from the local installed mod directory. All four integrated toggle
combinations enter through native singleplayer initialization with a connected
player. Test-only staged logging counts each real production `player.print` branch;
the native graphical fixture translates all twenty shared descriptions and both
warning strings. Initial SP entry is covered; MP client
join/rejoin and repeated SP reload are distinct lifecycle checks.

Compatibility fixtures cover an external wide shotgun that exceeds the travel
interval under strong doctrines, mixed supported/unsupported source branches,
and two instant deliveries with launch probability and repetition. Every direct
delivery retains its complete impact/source payload without squared repetition.

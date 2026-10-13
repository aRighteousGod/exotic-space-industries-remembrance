# Combat doctrine acceptance fixtures

`-RangeLimits` omits the synthetic 90-range consumer. Its final-data oracle checks
both travel endpoints, and its 117 native cases remove the intended receiver only
after launch, observe each round from its creation position through native expiry,
and assert disappearance before cleanup. It covers all eleven magazines, all four
shells through both ESIR turrets, Defender, finalized spider machine guns and five
quality boundaries, plus mixed weapon/ammunition qualities and handheld guns.
Remote receivers and nests must receive no damage. Native expiry executes each
round's terminal payload once; it is not silent destruction.

Factorio 2.0.77 multiplies delivery travel by firing-weapon quality. The shared
normal-quality baseline includes weapon reach and conservative muzzle allowance;
deviation uses the doctrine's physical extra-travel budget divided by the maximum
supported quality multiplier. Lower qualities receive no more than that budget.
Current maximum-quality ceilings are 77.55/90.55 tiles for bullets and
35.128125/48.128125 for pellets in Tempered/Terminal Barrage. Defender retains its
normal 30-tile floor, giving maximum-quality ceilings 48/61 tiles.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-combat-doctrines-qc.ps1 -RangeLimits -Matrix
powershell -ExecutionPolicy Bypass -File scripts/invoke-combat-doctrines-qc.ps1 -RangeLimits -Overlap
powershell -ExecutionPolicy Bypass -File scripts/invoke-combat-doctrines-qc.ps1 -RangeLimits -Performance -PyricDisabled
```

For a before/after simulation comparison, add `-BaselineSource <directory>` to the
last command. That directory supplies `ballistic-divergence-before.lua` and
`ballistic-divergence-config-before.lua` captured from the pre-change source.
Both versions fire the same 100 real turrets at collision-free native receivers,
assert zero hits, sample settled projectile populations at 1,000/2,000/3,500 ticks,
and run three 3,600-tick headless benchmarks with identical observer overhead.
This measures the fixture's simulation, separately from rendering and factory UPS.
New runs are registered before staging and closed after successful checks;
staged junctions are unlinked before retention snapshots. `-ReuseRun` remains an
explicit unmanaged diagnostic mode and does not adopt historical artifacts.
Use `-DependencySeed <verified mod directory>` when the shared seed is unavailable;
the override is recorded in reproduction metadata and must be engine compatible.
Add `-DataOnly` to run only final-data assertions, including all overlap states,
without replaying a graphical/native firing scene.
`-Transition -BaselineSource <directory>` creates the source save with pre-change
code, then loads current code. Its receiver moves from a valid native launch at
120 tiles to 200 before saving, beyond the new Tempered ceiling, so the saved
shot must retain its old native range and deliver its research/quality payload.

Locale QC (`scripts/invoke-combat-doctrines-qc.ps1 -Locales`) opens both actual
Informatron pages in all seven shipped languages, checks their menu/title lookups
and fourteen labels, and requires the displayed doctrine rows to match the shared
configuration. Each native client translates 44 captions, including both composed
startup tooltips, overlap warnings and enabled/disabled wording. A static audit
rejects missing per-language keys, duplicate definitions, damaged UTF-8, changed
constants and parameter/tag drift; native success could conceal English fallback.
Use `-Locales -Languages en` for a focused run, or add the existing toggle/profile
options to verify selected-doctrine status. Reports and GUI captures remain in the
disposable run directory.

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
powershell -ExecutionPolicy Bypass -File scripts/invoke-combat-doctrines-qc.ps1 -Overlap -Ballistic saturation
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
data snapshots before and after the early compatibility bridge check all eight
exotic magazine capacities, copied trajectory scalars and complete payload
preservation. Late snapshots check disabled isolation or integrated conversion;
select Saturation to verify its capacity multiplier applies exactly once.
Native spider discharge observations are checked separately before comparing
complete ammunition behavior with the pre-conversion baseline.
the native graphical fixture translates all twenty shared descriptions and both
warning strings. Initial SP entry is covered; MP client
join/rejoin and repeated SP reload are distinct lifecycle checks.

Compatibility fixtures cover an external wide shotgun that exceeds the travel
interval under strong doctrines and must be clamped, stalled pellets and scripted
branches that retain stable helpers, inherited bullet speed/turning/default range,
mixed supported/unsupported source branches,
and two instant deliveries with launch probability and repetition. Every direct
delivery retains its complete impact/source payload without squared repetition.

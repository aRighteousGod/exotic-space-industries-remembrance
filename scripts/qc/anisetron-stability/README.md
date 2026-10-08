# ANISETRON hover, movement and attachment regression

This isolated Factorio 2.0.77 fixture uses a copied player seed and native
Spidertron driving. The runner stages the actual ESIR source and an observer
bridge; experiments override only the isolated helper's prototypes/options.
No engine process writes the original save or installed mod files.

```powershell
# Final long movement matrix; one manual driver, eight headings and five profiles.
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 -RunName stability-floor50 -FixtureSource scripts/qc/anisetron-stability -FixtureOptions scripts/qc/anisetron-stability/options-floor50.lua -RuntimeTicks 20100 -Fidelity off

# Actual crystal roots, all eight headings, day/night, cruise and stopping.
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 -RunName stability-roots -FixtureSource scripts/qc/anisetron-stability -FixtureOptions scripts/qc/anisetron-stability/options-effects.lua -Visual -RuntimeTicks 630

# Keep both moving beam ends on screen through turns and stopping.
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 -RunName stability-moving-ends -FixtureSource scripts/qc/anisetron-stability -FixtureOptions scripts/qc/anisetron-stability/options-moving-emitters.lua -Visual -RuntimeTicks 630

# Reproduce the original user's vehicle state and enabled mod set, on a copy.
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 -RunName stability-ass-sustained -FixtureSource scripts/qc/anisetron-stability -FixtureOptions scripts/qc/anisetron-stability/options-ass-sustained.lua -SaveInput "$env:APPDATA/Factorio/saves/ass.zip" -InstalledMods -RuntimeTicks 12100
```

`options-public.lua` tests unmodified, equipped, armed, slowed, and armed/slowed
public vehicles for 20,000 ticks. It includes 10,000 uninterrupted travel ticks,
repeated shallow turns, reversals, stopping and restarting. The long matrix
contains one manually driven actor; the other actors use native autopilot.
`options-floor50.lua` moves that manual driver to the no-fire slowed case and
sets the isolated modifier floor to .50. It does not override a paid record or
damage packet. `options-floor.lua` retains the diagnostic .20/.35/.50/.75/1
sequence. The other named options preserve unsuccessful prototype experiments;
they are not shipping alternatives or acceptance results.

`options-bob*.lua` and `measure_bob.py` measure actual body pixels at different
native bob speeds, including next-tick native displacement. The effects profile
uses separate actors for motion and combat, while `options-moving-emitters.lua`
adds moving/turning combat with nearby targets. Its target teleports are a
deliberate geometry fixture, not native enemy-behavior validation. Real native
moving enemies remain covered by the separate tracking regression.

`options-ass*.lua` reads and drives the damaged existing vehicle. The sustained
profile holds walking input for 12,000 ticks and changes heading every 1,800
ticks without release. It retains the old .08 bob for reproduction and restores
health to 471 only if incoming combat would otherwise take it below 100, so an
incidental death cannot end the observation. It records that fixture limitation.
These scripted input writes cannot certify the behavior of physical held keys.
The separate [live observer](../anisetron-live-observer/README.md) records those
inputs without writing them or changing movement.

Screenshots, saves and full per-tick output remain ignored under `.factorio-qc`.
See [verification](verification.md) for measured results and unresolved evidence.

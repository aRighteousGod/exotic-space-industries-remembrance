# ANISETRON hover and laser regression

This fixture runs the shipping controller in Factorio 2.0.77 through the existing
`scripts/invoke-anisetron-qc.ps1` wrapper. Its remote bridge is appended only to
the staged mod. It never fabricates paid contracts or overrides vehicle position
or speed; native entities, ammunition, research and control inputs drive the test.

It checks native-paid 320/160 contacts, quality, laser damage tiers 5/6/7/8,
ordinary lab completion during a paid burst, exhaustion, saved damage policy,
and six stable chromatic beam variants. An isolated movement lane applies eleven
installed slowing sticker types with and without a damage event, including an
equipped citadel, then checks recovery. The source health is restored to isolate
movement; the separate existing mobility fixture verifies original damage.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 -RunName hover-research -FixtureSource scripts/qc/anisetron-hover-combat -Fidelity off
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 -RunName hover-glow -FixtureSource scripts/qc/anisetron-hover-combat -Visual -RuntimeTicks 250 -Fidelity standard
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 -RunName hover-oldtech -FixtureSource scripts/qc/anisetron-hover-combat -FixtureOptions scripts/qc/anisetron-hover-combat/old-category.lua -Save -Fidelity standard
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 -RunName hover-upgrade -FixtureSource scripts/qc/anisetron-hover-combat -Resume -SaveInput .factorio-qc/anisetron/hover-oldtech/saves/anisetron-transition.zip -RuntimeTicks 2200 -Fidelity off
```

The old-category option deliberately omits only ANISETRON's newly added research
effects from the staged prototypes. Its saved forces have real completed laser
research. Loading current prototypes must restore ANISETRON's research bonus
while preserving old paid damage and deadlines. Factorio itself recalculates
technology effects on configuration changes, so arbitrary script-set modifiers
are observed rather than required to survive that boundary. A separate in-session
rebuild check ensures ANISETRON leaves an unrelated custom bullet modifier intact.
This is a constructed migration
seed; the genuine historical rare-v2 save is replayed separately by the main
fixture, using its saved damage rather than current coefficients.

Native damage is float32. Per-packet comparisons tolerate .001 damage and full
charge totals .01; packet counts and ammunition payments are exact integers.
Day/night screenshots are written under the graphics run's `script-output`.
Reports and before/after stall evidence stay in ignored `.factorio-qc/anisetron`.
See [verification](verification.md) for current results and limitations.

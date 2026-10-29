# Cryo temperature compatibility fixture

Exact Factorio 2.1.23 fixture for the reported ammoniacal-solution recipe error.
Stage with `scripts/qc/factorio-2.1/invoke-core.ps1` and a private copy of this
fixture. In its private `test-config.lua`, select both `mutate=false` and
`galore=false` for unchanged core behavior, `mutate=true` for the replacement-fluid
reproduction, or `galore=true` for both Space Age Galore temperature overrides.
The two mutation modes are mutually exclusive. Keep
`assert_final=true` for acceptance; `false` allows the unfixed engine error to
surface during reproduction.

The mutation occurs in data-updates after ESIR declaration. It raises ammoniacal
solution's legal range to 15-100 C and replaces the ammonia transfer fluid with a
fixture-only 25-100 C fluid. No K2 code is simulated beyond those explicit fluid
changes; this fixture does not certify full Krastorio compatibility.

The Galore mode instead changes the original fluids in data.lua: ammoniacal
solution to 15-100 C and ammonia to 15-450 C, with ammonia's gas threshold -33 C.
This reproduces the exact inspected upstream override values and stage. Both
cryo pairs must fill and empty at 15 C. It does not load the full Galore package
or certify its other recipes/progression; provenance is in the fixture data.lua
and the upgrade handoff's CRYO_TEMPERATURE_COMPATIBILITY.md report.

Create a fresh save and benchmark it for 600 ticks. Final-data assertions check
all nine pairs, unchanged quantities/identities, one-second operations and
productivity/quality/recycling restrictions. Native assemblers perform nine
fill/empty round trips and reject a different valid temperature where the fluid
range permits that check. `script-output/cryo-temperature.json` records quantities,
temperatures and the exact engine version. No installed configuration is changed.

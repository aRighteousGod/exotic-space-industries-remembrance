# Steam consumer energy-source glow

Focused Factorio 2.0.77 final-data, activity and nighttime regression fixture for
the ten current ESIR ordinary-steam consumers. This does not alter shipping
graphics, gameplay, runtime logic or other mods' lighting.

Register a private ignored run with `Register-EsirArtifactRun` from
`scripts/esir-housekeeping.ps1` (workflow `steam-consumer-glow`, engine `2.0.77`).
Use a short `.factorio-qc/st-<unique-id>` payload. Point the first invocation at a
dependency seed previously staged by the ESIR QC wrapper:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/qc/steam-consumer-glow/run.ps1 -RunDirectory <run> -Mode baseline -SeedMods <seed>
powershell -ExecutionPolicy Bypass -File scripts/qc/steam-consumer-glow/run.ps1 -RunDirectory <run> -Mode on
powershell -ExecutionPolicy Bypass -File scripts/qc/steam-consumer-glow/run.ps1 -RunDirectory <run> -Mode off
python -B scripts/qc/steam-consumer-glow/check.py <run>
# Repeat each of baseline/on/off with -Visual to collect 60 native screenshots.
python -B scripts/qc/steam-consumer-glow/check.py <run> --visual
```

`baseline` removes only the six newly added zero-intensity fields in private
copies; the earlier inserter/pump fixes remain. `on` and `off` explicitly select
Pyric Radiance through startup defaults and discard private saved settings.
All profiles copy live gameplay source and run the same installed dependencies.
Copies of runtime controls are isolated; immutable dependency assets may share
hardlinks. Source folders and installed mods are never modified.

The helper depends on every enabled mod so its snapshot captures final prototypes.
It discovers every ESIR fluid energy source filtered to ordinary `steam`, asserts
the suppression, and retains complete prototypes in native mod-data. `--create`
loads and validates those prototypes; `on_init` writes the compact final-data
receipt. Comparison permits exactly six added `energy_source.light_flicker`
fields, including across Pyric profiles. Locomotives and the critical-steam
turbine are recorded as unchanged exclusions. Death, damage, sound and native
Factoriopedia definitions are also checked.

Native activity uses actual extracted items, transferred items, crafted progress,
oil output and offshore-pump telemetry. The pump has a connected output pipe.
Every energy source receives steam through its filtered energy fluid box; starved
cases receive none. Screenshots assert working/no-input-fluid status, positive
activity for working bodies and zero activity/energy for starved bodies. Fixture
assemblers use a deterministic item recipe added after the prototype snapshot;
their shipping graphics and energy source are retained. These are controlled
native machine scenes, not full-mod runtime or Factoriopedia GUI acceptance.

Review the PNGs separately: file presence and prototype checks alone do not prove
appearance. Close only this task's registered runs after retaining the acceptance
receipt and any reviewed contact sheets.

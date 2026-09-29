# Beacon diminishing-return acceptance

Run from the Factorio 2.0 checkout:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-beacon-profile-qc.ps1 -Transition -Geometry
python -B scripts/qc/beacon-profiles/check-results.py .factorio-qc/bp/<timestamp> --transitions
```

The runner freezes gameplay source in `.factorio-qc/bp/<timestamp>`, shares graphics through junctions, and seeds dependency archives from the usual QC cache. It does not deploy mods or modify user saves. `-Profiles strict` narrows the disabled-mode matrix; both enabled-mode probes still run. `-ReuseRun <path>` reuses an existing frozen gameplay copy and refreshes only the QC helper. Omit it to validate new production edits. `-ResumeTransitions -ReuseRun <path>` resumes the three save transitions from that run's saved `on-gentle` factory without repeating the curve matrix.

## Coverage

- Six disabled-mode presets and enabled mode with Gentle/Saturating selected.
- Settings visibility, enabled/Strict defaults, adjacent order, and the six-value list before the helper forces its test settings.
- Final `data.raw` assertions for 4096 entries, full single-beacon strength, independent numerical samples, decreasing positive multipliers, and total counting.
- A snapshot around the production pass proves that only profiles/counters and descriptions on the four owned beacons change. Every other beacon field and foreign beacon remains identical.
- 25 actual receiver layouts per case: 1/2/4/8/16 of each ESIR tier; legendary Iron; four mixed-tier/vanilla/third-party layouts. All five effect channels are compared with engine values, allowing native effect quantization.
- Runtime snapshots assert machine active state, overload flags/icons, and empty disabled-mode relationships/registrations. Existing inactive tracked-machine caches may remain after disabling. QA supplies beacon energy directly where applicable; after Nonstandard Beacons discovers the isolated entities during migration, QA supplies its actual hidden fluid/burner sources through its read-only metadata interface, allowing its normal power gate to reactivate beacons. Cooling and fuel prototype fields are protected by the data-stage comparison.
- `-Transition` uses an unlisted local headless server on port 34197 to save an overloaded factory, disable overload with Strict, reload it, and enable overload again. It checks actual startup-setting changes. Benchmark mode is used for other runs; benchmark calls to `server_save` do not persist saves.
- `-Geometry` replays the existing checked-in overload lifecycle fixture independently after the profile matrix. It covers 20 scenarios and 26 checkpoints, including destruction, cloning, teleport, disabled lifecycle, and legacy rebuilds.

`*-create.txt` contains `BEACON_PROFILE_QC_DATA` and isolation assertions. `*.json` contains receiver effects and lifecycle snapshots. Transition saves and original engine logs remain in the ignored run directory.

## Native behavior

The production pass uses [Factorio 2.0.77 BeaconPrototype.profile](https://lua-api.factorio.com/2.0.77/prototypes/BeaconPrototype.html#profile) and `beacon_counter = "total"`. Iron's overload weight does not change the native profile index. The engine counts all covering beacon types; weaker additions may dilute stronger tiers.

The Vanilla option uses the mathematical square-root curve rather than vanilla's rounded 100-entry array. Every preset contains 4096 full-precision samples. Beyond that, the native engine repeats sample 4096; Severe and Saturating therefore do not impose an absolute bound at arbitrary beacon counts.

These checks are headless functional acceptance, not a graphical settings review, multiplayer certification, or a UPS benchmark.

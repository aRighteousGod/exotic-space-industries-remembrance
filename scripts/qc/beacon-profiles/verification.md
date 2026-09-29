# Beacon profile verification — 2026-09-28

Validated ESIR 1.3.40 with the installed Factorio **2.0.77** engine. Artifacts are retained locally in the ignored directory `.factorio-qc/bp/0928-205139`.

## Results

| Coverage | Result |
| --- | --- |
| Overload disabled: Gentle, Vanilla, Strict, Harsh, Severe, Saturating | All six passed |
| Overload enabled: Gentle and Saturating selected | Both passed; dropdown selection did not change overload behavior |
| Saved overloaded layout: disable with Strict, save/reload, enable again | All three phases passed; receiver unit numbers survived each transition |
| Native receiver effects | 275 checkpoints across 11 phases, 25 layouts per phase, all five effect channels |
| Existing overload lifecycle fixture | 20 scenarios, 26 checkpoints, zero failures |

Fresh final `data.raw` assertions verified visible settings, enabled/Strict defaults, the six dropdown values and adjacent ordering, and profiles containing 4,096 positive, decreasing samples. The first sample is exactly 1. Independent calculations verified the samples at 4, 8, and 16 covering beacons. Only the four ESIR beacon profiles and counters change when overload is disabled; their counters use `total`. A complete before/after comparison across seven beacon prototypes protected all other fields and foreign profiles, including vanilla and a fixture third-party beacon.

Receiver layouts covered each of Copper, Iron, Alien, and Warp at 1, 2, 4, 8, and 16 beacons; legendary Iron; mixed ESIR tiers; Warp plus Copper; and Copper with vanilla or third-party coverage. Comparisons allowed Factorio's native effect quantization. The saved-setting transitions verified actual startup-setting change events, release of overloaded machines, removal of overload icons and topology links/registrations, persistence of Strict across save/reload, and restoration of overload behavior on re-enabling. Existing inactive tracked-machine cache entries are allowed after disabling.

Nonstandard Beacons 1.4.2 was active. The fixture supplied the actual hidden power sources after that dependency discovered the isolated beacons during configuration changes. Production cooling, fuel, energy, quality, range, and module-slot fields were protected by the prototype comparison. No production runtime counting, polling, schema, or migration was added.

## Static and locale checks

Repo preflight completed with all syntax, require, encoding, locale, asset-reference, and pack-version checks passing. It reported only existing module-header warnings in `auric-inoculation-vat.lua` and `emerald-apocalypse-hover-tank.lua`. A short `PYTHONPYCACHEPREFIX` under the temporary directory avoided the Windows path-length failure encountered by the initial Python compile check.

All seven new locale sidecars have the same 12 keys and matching placeholders. UTF-8, BOM/replacement-character, and whitespace checks passed. Japanese changes retain the accepted native beacon names and make narrow mechanical clarifications. Final Informatron label wrapping and Lua annotations received syntax checks after the engine snapshot; no gameplay behavior changed in those final edits.

## Reproduction and limits

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-beacon-profile-qc.ps1 -Transition -Geometry
python -X utf8 -B scripts\qc\beacon-profiles\check-results.py .factorio-qc\bp\<timestamp> --transitions
```

The report checker returned `PASS: 11 engine phases, 275 receiver checkpoints; transitions=True`. The existing lifecycle fixture emitted `all_pass: true`, `failure_count: 0`, `scenario_count: 20`, and `checkpoint_count: 26`.

The normal `qc-fast` wrapper could not finish copying graphics into its cache because of insufficient disk space. The focused runner instead froze gameplay source and used graphics junctions, completing the engine checks above. Concurrent unrelated sweeping-radar and other work was preserved; these results describe the frozen beacon implementation, not an exact-tree certification of later unrelated changes.

Validation was headless. It does not include a graphical settings/Informatron review, native-speaker review of translations, multiplayer certification, or a UPS benchmark. The 4,096-entry boundary is documented in all player-facing preset explanations: the engine repeats the final multiplier beyond that count, so Severe and Saturating are not absolute caps at arbitrary counts.

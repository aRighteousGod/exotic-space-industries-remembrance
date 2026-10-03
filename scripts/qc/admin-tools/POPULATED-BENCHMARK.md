# Populated whole-engine comparison

The controlled comparison did **not demonstrate a consistent whole-factory UPS improvement**. Median update time was 15.602265 ms for the baseline and 15.615204 ms for the candidate: the candidate median was **0.083% higher** (about 0.01294 ms). This is much smaller than the observed run variation; the paired comparisons changed direction.

| Measured pair | Order | Baseline ms/tick | Candidate ms/tick | Candidate change |
| --- | --- | ---: | ---: | ---: |
| 1 | Candidate, baseline | 16.002573 | 15.615204 | −2.42% |
| 2 | Baseline, candidate | 16.081808 | 15.148687 | −5.80% |
| 3 | Candidate, baseline | 14.612416 | 15.279842 | +4.57% |
| 4 | Baseline, candidate | 15.602265 | 16.045933 | +2.84% |
| 5 | Candidate, baseline | 14.780285 | 15.864098 | +7.33% |

Negative change means less update time. Baseline samples ranged 14.612416–16.081808 ms/tick (sample standard deviation 0.684095 ms); candidate samples ranged 15.148687–16.045933 ms/tick (sample standard deviation 0.379009 ms). The ranges overlap. Two pairs favored the candidate and three favored the baseline. These five pairs do not support a general performance claim or establish active-menu performance.

## Method and exact scope

- Installed Factorio 2.0.77, ESIR 1.3.40, twelve separate uninstrumented engine processes in one exclusive engine window. Every process performed 3600 updates from the same original populated save. Pair 0 was discarded as warm-up; pairs 1–5 alternated order. No helper mod, bridge or profiler was present in these timed sources.
- Warm-up baseline 14.856458 ms/tick and candidate 15.950390 ms/tick were excluded from all figures above.
- All six baseline checksums were `3238346446`; all six candidate checksums were `470203686`. Repeatability within each source passed. Different cross-source checksums are recorded, not treated as behavioral equivalence; the separate functional fixtures validate intended lifecycle behavior.
- Fixture: current `_autosave9.zip`, 97,525,176 bytes, SHA256 `02A517D4FAD391352FEA946D320C2F96B2C276F0B20C93C44A2D0B2D3186AC9F`. The archived 269-setting populated profile was applied identically to both sources. Its original preparation save has a different historical hash; this report does not claim that profile was reconstructed from the current fixture.
- Both staged mod lists had 42 enabled entries. Exact initial mod-list SHA256 `4D8A13A660E83C9C7740DCBD8338C12B55341EA7629339C411AAC50D0A34B364`; exact initial mod-settings SHA256 `3AB13D4E2C5BEAD43ACB41E9726A3E83906AB005D5583B9DBF1A4EF56AA523A0`. Native 2.0.77 had normalized the initial compatibility-load files; the baseline's earlier manifest was preserved before its metadata was updated, and the final candidate was seeded from those exact normalized bytes.
- The optional external `AspctTrainPatch` mod was disabled in both isolated staged lists. Both original comparison profiles failed its `legacy-train-model-recipes_0.2.0.lua` migration because `legacy-locomotive` was absent. Shipping mod lists and the original dependency seed were not edited. The failed compatibility logs remain beside the baseline and earlier candidate profiles.
- Baseline 740 source files and frozen candidate 763 source files were checked byte-for-byte against their source manifests before timing. Baseline is the pre-change snapshot under `output/admin-implementation/baseline/exotic-space-industries-remembrance`; candidate is the coordinated 2026-09-29 source freeze, including the enemy_mix confirmation-copy correction.
- The frozen candidate precedes the final jail HUD/damage-ownership, camera validation/click, admin job/callback/planet-menu and neutron multi-viewer snapshot follow-ups. Those later source changes are not included in the exact benchmark snapshot. The scope observations below show that their feature paths were inactive in this workload; that is an applicability observation, not a measurement of those newer source bytes.

## Native scope observation

A separate 120-update observational replay used the frozen candidate, the same save and effective settings, and the same benchmark connection behavior. It is excluded from timing analysis. At both the first and 120th updates:

- `ei-admin-tools-enabled` was **false**.
- No admin storage root existed. Admin GUI sessions, jail records and shared camera windows were all zero.
- Neutron collector `open_by_player` was empty.
- There were two saved native players: player 1 connected (controller 7), player 2 disconnected (controller 1). Both had `opened=nil`; neither had ESIR screen, relative or center panel roots. Only persistent mod-gui wrapper flows/frames were present under left/top.

This represents a populated factory with the admin toolkit disabled and no open ESIR entity/admin panels. It does not measure active admin jobs, restriction census, jails, cameras, multiple GUI viewers or interactive rendering. Closed-panel native counter assertions and the 19-owner source audit are reported separately in `GUI-VERIFICATION.md`.

## Evidence and replay

- Baseline profile/logs: `.factorio-qc/cu/g/admin-pop-b/`.
- Frozen candidate profile/logs: `.factorio-qc/cu/g/admin-pop-final-c/`.
- Scope replay: `.factorio-qc/cu/g/admin-pop-scope/`, with `script-output/admin-benchmark-scope.json` and `scope-stdout.txt`.
- Durable compact data: `populated-benchmark-results.json` and `populated-benchmark-scope.json`.
- Separate scope bridge: `benchmark-scope.lua`. Append only to a fresh staged copy; never append it to a timed profile.

Commands used:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-control-populated-benchmark.ps1 `
  -BaselineRun .factorio-qc/cu/g/admin-pop-b `
  -CandidateRun .factorio-qc/cu/g/admin-pop-final-c -Ticks 3600 -MeasuredPairs 5
python -B scripts/qc/control-ups/analyze.py `
  --alternating .factorio-qc/cu/g/admin-pop-b .factorio-qc/cu/g/admin-pop-final-c
```

Use fresh profile names when replaying so previous evidence is preserved. The existing script defaults to 3600 ticks and five measured pairs. Keep other Factorio processes closed for the timing lane; functional/scope replays may run separately and their setup-heavy timings must not be substituted for these measurements.

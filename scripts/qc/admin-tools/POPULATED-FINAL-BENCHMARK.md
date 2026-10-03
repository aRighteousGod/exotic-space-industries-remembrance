# Final administration timing snapshot: populated whole-engine comparison

The final timing-snapshot comparison **does not demonstrate a consistent whole-factory
UPS improvement**. Candidate median update time was **14.465136 ms**, versus
**14.665449 ms** for the baseline, a **1.366% lower** median. However, two of
three paired comparisons favored the baseline, the paired direction reversed,
and the observed sample ranges overlap. These three pairs support reporting the
measured times; they do not establish a general performance gain or a GUI cause.

| Measured pair | Order | Baseline ms/tick | Candidate ms/tick | Candidate change |
| --- | --- | ---: | ---: | ---: |
| 1 | Candidate, baseline | 14.684363 | 15.090583 | +2.77% |
| 2 | Baseline, candidate | 14.665449 | 14.465136 | -1.37% |
| 3 | Candidate, baseline | 14.196520 | 14.462792 | +1.88% |

Negative change means less update time. Baseline samples ranged
14.196520–14.684363 ms/tick, with sample standard deviation 0.276358 ms.
Candidate samples ranged 14.462792–15.090583 ms/tick, with sample standard
deviation 0.361781 ms. The previous five-pair snapshot comparison remains in
[POPULATED-BENCHMARK.md](POPULATED-BENCHMARK.md); it measured older source bytes
and is retained as historical evidence.

## Method and exact source

- Factorio **2.0.77 build 84539**, ESIR **1.3.40**, 2026-10-02. Eight separate,
  uninstrumented engine processes ran in a coordinated exclusive Factorio
  window. Each performed **3,600 updates** from the same original populated
  save. Pair 0 was discarded as warm-up; measured pairs 1–3 alternated order.
  No helper, bridge, profiler, GUI fixture or scope code was present in timed
  profiles.
- Excluded warm-ups: baseline **14.928925 ms/tick**, candidate
  **15.032261 ms/tick**. All four baseline runs shared checksum `3238346446`;
  all four candidate runs shared checksum `2771648898`. Different cross-source
  checksums are recorded and do not prove behavioral equivalence. Independent
  native fixtures supply preservation and lifecycle coverage.
- Original save `_autosave9.zip`: **97,525,176 bytes**, SHA-256
  `02A517D4FAD391352FEA946D320C2F96B2C276F0B20C93C44A2D0B2D3186AC9F`.
  The same retained populated settings profile and 42-enabled-entry mod list
  were staged for both sources. Initial mod-list SHA-256:
  `4D8A13A660E83C9C7740DCBD8338C12B55341EA7629339C411AAC50D0A34B364`.
  Initial mod-settings SHA-256:
  `3AB13D4E2C5BEAD43ACB41E9726A3E83906AB005D5583B9DBF1A4EF56AA523A0`.
- Native settings normalization left the baseline settings hash unchanged;
  candidate post-load settings SHA-256 is
  `7EC675C26F04B365B3176E240A4063162B0043907F36E695EBD6C104E147E042`.
  The separate native scope replay verifies that the new toolkit remains Off.
- The same optional `AspctTrainPatch` exclusion from the earlier comparison
  remains in both isolated staged lists. Both original profiles had failed its
  `legacy-train-model-recipes_0.2.0.lua` migration against missing
  `legacy-locomotive`. Installed mod lists were preserved.
- Baseline is the retained pre-administration snapshot with **740 files**;
  candidate is the coordinated administration timing snapshot with **763 files**.
  All main-pack file hashes and **32 dependency archive hashes** were verified
  before and after timing. Shared graphics/soundtrack junction targets match;
  their directory contents were shared between profiles rather than copied into
  the main-pack file manifest. Full manifests remain beside the native logs.
- The candidate includes the final window-position, explicit mode-label,
  optional auto-refresh, stale-authorization/timer, jail, camera, creation-job,
  neutron shared-snapshot and neutron/matter closed-window changes. No source
  edits were made to the frozen timed profiles.

The shipping GUI received one further correction after timing: when an existing
saved preview frame lacks the new automatic-refresh controls, explicit console
opening rebuilds that obsolete layout once while preserving position and drafts.
That structural-upgrade guard is **not included in these measured GUI bytes**.
It runs only when opening a console. The frozen scope below had the toolkit Off,
no administration root and no panels, so the measured workload does not enter
this path. Separate current-source native fixtures cover the upgrade. This is
an applicability observation, not a timing measurement of the newer GUI source.
An all-file comparison verified that `scripts/control/admin/gui.lua` is the
**only** shipping-file delta from the 763-file timing snapshot: measured GUI
SHA-256 `73647E1DDAC1F1EA9D0985D5CD6625AA159349CBD81169429099C5AE8E6CD151`
became `AE1D695B478CB0444A22E9056C6B0F1A30C366DF49DBCC005FDC1BDDC6136283`.

| Frozen source | Source-tree SHA-256 | Profile manifest SHA-256 |
| --- | --- | --- |
| Baseline | `EFE66CE74E08BE2109CC05EDAFE8B378F43C624FE17E37237B0388FD72530D46` | `A629342C14BBEA1FFF6C6ECB1066F628241E42D6CC110CF64EF1109BD695BF4E` |
| Candidate | `55837AC1B8E118DF01E3BD36225CD64AE07C7055551366B5E46F9BE69BE38F6E` | `12D029EFA6566BB031CD1ADC61A26D246AE8850CF844E073188E88A937853B39` |

The source-tree digest hashes sorted `path:SHA256` records with slash-normalized
relative paths and newline separators. Key candidate fingerprints are stored in
[populated-benchmark-final-results.json](populated-benchmark-final-results.json),
including GUI `73647E1D…CD151`, neutron `AAC36AC0…E11D1D`, and matter
`32CBF40C…E47614`.

## Separate native scope observation

After timing, a fresh copy of the frozen candidate ran **120 updates** with only
the explicit observational bridge appended to `control.lua`. This lane is
excluded from timing analysis. At the first and 120th updates:

- `ei-admin-tools-enabled` was **false** and no administration storage root
  existed. Admin GUI sessions, jails and shared camera windows were zero.
- Neutron collector GUI sessions were empty.
- Two native players were saved: one connected (controller 7), one disconnected
  (controller 1). Both had `opened=nil` and no screen, relative or center GUI
  roots. Left/top contained only persistent mod-gui wrapper flows/frames.

A second fresh 120-update observational replay, `ap4u`, copied only the current
GUI file into the otherwise frozen candidate before appending the same bridge.
It confirmed the same inactive state at both sample ticks. Its source-delta
metadata and observation are retained separately in
[populated-benchmark-final-current-scope.json](populated-benchmark-final-current-scope.json).
The current GUI also passed the final **65/65** native responsive checks and
the full **365/365** integrated administration lane. These checks substantiate
the inactive-path statement; no timing result is assigned to the newer GUI file.

This is a populated factory with the admin system disabled and no open ESIR
panels. It measures neither active administration jobs, restriction census,
jails, cameras, optional automatic refresh, multiple viewers nor client
rendering. Closed-menu display counters and the complete owner audit remain
separate evidence in [GUI-VERIFICATION.md](GUI-VERIFICATION.md). The final native
viewport/control review is documented in the responsive verification report.

## Evidence and replay

- Baseline profiles/logs: `.factorio-qc/cu/g/ap4b/`.
- Frozen candidate profiles/logs: `.factorio-qc/cu/g/ap4c/`.
- Separate scope: `.factorio-qc/cu/g/ap4s/`, with completion log and
  `script-output/admin-benchmark-scope.json`.
- Post-timing current-GUI scope: `.factorio-qc/cu/g/ap4u/`, with source-delta
  manifest, completion log and the same native report filename.
- Compact durable data:
  [populated-benchmark-final-results.json](populated-benchmark-final-results.json)
  and [populated-benchmark-final-scope.json](populated-benchmark-final-scope.json).
- Additional current-source scope data:
  [populated-benchmark-final-current-scope.json](populated-benchmark-final-current-scope.json).
- The observational bridge is [benchmark-scope.lua](benchmark-scope.lua).
  Append it only to a fresh observational copy, never to timed profiles.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-control-populated-benchmark.ps1 `
  -BaselineRun .factorio-qc/cu/g/ap4b `
  -CandidateRun .factorio-qc/cu/g/ap4c -Ticks 3600 -MeasuredPairs 3
```

Use fresh profiles for replay; the driver preserves existing timing evidence.
The native stdout records all eight results, while `alternating-results.json`
records pair order and warm-up flags. The earlier `control-ups/analyze.py`
alternating entry point expects five measured pairs; this final three-pair
analysis was computed directly from the individual native stdout totals and
verified source manifests. All timing/scope engines exited after completion.

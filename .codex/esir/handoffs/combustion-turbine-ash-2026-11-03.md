# Industrial combustion turbine expansion — 2026-11-03

## Delivered behavior

- Solid fuel supports ash-free or ash-generating operation, with either atmospheric
  oxygen or supplied oxygen. Ash mode uses native burnt results and three residue
  slots; fuels without a burnt result remain residue-free.
- Ash mode reduces normal-quality maximum output from 12 to 10.8 MW, solid-fuel
  efficiency from 300% to 270%, and base pollution from 120 to 108/min. Supplied
  oxygen and CO2 rates are 18/s instead of 20/s at full output. Atmospheric quality
  scaling is retained; oxygen-fed generator companions remain normal quality.
- Nonempty residue slots block changes to ash-free or fluid operation, including
  settings paste. Failed requests retain preferences and contents.
- Enabled is independent of external script disabling and pressure-safety holds.
  Both native producers stop while their contents remain in custody.
- Oxygen-fed panels show electrical output/capacity/utilization, native fuel,
  oxygen/CO2 buffers, residue occupancy and operating status. Periodic snapshots
  are read once per viewed turbine every 60 ticks and are not collected with all
  panels closed. Fuel, oxygen, ash and enable choices survive native lifecycle
  paths and blueprint tags.
- Generator replacement preserves its working fluid, electrical charge, and CO2
  segment contents. The one-way exhaust and downstream pipe are distinct native
  segments; the fixture measures both when checking total exhaust conservation.
- Entity, item, technology and option descriptions cover all eight supported
  locales. Existing art, sounds and death effects are reused for operational
  variants. No main-mod version change or deployment was performed.

## Verification

Exact engine: **Factorio 2.1.24**, using the development profile and managed staging.

- User reviewed the graphical scene and reported that it all looked good. The
  interactive fixture recorded four real changes (ash on, Enabled off, Enabled on,
  ash off) and completed a native checkpoint save. Evidence run:
  `34bcb6abaa59456e902d0f61fa3b5cf4`, `checkpoint.log`, stages 1–4.
  Its aggregate runner verdict is not a clean acceptance: concurrent harness and
  gate/locale edits invalidated input freshness after the graphical checkpoint.
  The captured 1440x900 frames crop the larger native UI and are not independent
  full-layout acceptance. The user's direct review supplies visual acceptance.
- Final-data engine loading and data contracts passed. Dump receipt:
  `0434d9495c154bccb60d2408d0804508/final-data-receipt.json`; valid JSON, 2,076,105,837
  bytes, SHA-256 `9da718dd0088bde30f87c2921cf54db0bdc41e6746c7c0bb007bbe78a7935832`.
  Managed storage release failed, and the enclosing targeted run also detected
  concurrent source changes. Do not label that aggregate run passed.
- Turbine locale sidecars: 30 keys per locale, eight locales, matching substitution
  tokens. Focused live module-header audit: no findings.
- Conceptual blueprint audit initially passed. Later broad preflight found only
  ownership-link errors for the concurrently edited `beacon-profiles.lua` in its
  conceptual-blueprint check; those changes are outside this turbine patch.
- Automated fixture coverage includes native ash power/fuel/oxygen/exhaust and
  pollution ratios, full residue backpressure, alternative/no-result fuels,
  connected exhaust custody, loaded atmospheric and oxygen ash switches,
  on/off holds, blueprint tags, rejected settings paste, GUI option events,
  one snapshot for two viewer-map entries, and no reads after closing panels.
  The viewer-map check uses an explicit QC-only alias to a real player; it does
  **not** establish two-client multiplayer acceptance.
- Native combustion proof: **73 assertions passed with Quality enabled**, run
  `1659f1eaad4b4e8e9d1098d2a4f4cf8f`, and **73 passed with Quality disabled**, run
  `abbc3701e3c341d980d1285e1ae99fd9`. The enabled row's housekeeping completion
  could not acquire the shared registry lock; its engine phase passed, but its
  aggregate row is failed. The disabled row has an `ok` aggregate result.
- The first direct matrix could not stage build-dispatch or either integrated
  turbine profile because another operation held the shared storage/registry
  lock. No engine assertions ran for those three attempts.
- Integrated Quality-enabled retry, run `37eba397fb134266902090f3ecb3a32c`:
  **319 candidate assertions and 159 reload assertions passed**, with a successful
  graphical checkpoint between them. Its aggregate closeout failed because a
  dependency ZIP was still locked by another engine process (`protected-error`).
- Integrated Quality-disabled retry, run `f46de338ea3e4378b93c97951545e5eb`:
  **317 candidate assertions and 159 reload assertions passed**, with a successful
  graphical checkpoint between them and an `ok` aggregate row. The combined
  integrated invocation reported no source-fingerprint changes; its overall
  failure is the enabled row's storage closeout, not a failed engine assertion.
- Build-dispatch retry, run `33bcc8d60a7f48389cca7f6f3709e167`: **930 candidate
  assertions and 56 reload assertions passed**, with an `ok` aggregate result
  and no source-fingerprint changes.

## Reproduction

```powershell
powershell -File scripts/invoke-esir-dev.ps1 -Task qc-quick -Suite combustion-turbine -PlanOnly
powershell -File scripts/invoke-esir-dev.ps1 -Task qc-targeted -Suite combustion-turbine,combustion-turbine-native-proof,build-dispatch
# Run native cases independently if an unrelated broad/storage gate prevents them:
powershell -File scripts/invoke-esir-dev.ps1 -Task qc-test -Suite combustion-turbine,combustion-turbine-native-proof,build-dispatch
# Optional operator-driven real-input check; use ash on, Enabled off/on, ash off:
python scripts/qc/combustion-turbine/manual.py
```

Managed evidence paths above are relative to `.factorio-qc/managed/`. Successful
or failed runs may be compacted into `evidence.zip`; consult `evidence-index.json`
instead of assuming historical scratch paths still exist. Other concurrent work
and its runs were not edited or retired.

Task closeout was requested for the completed enabled-profile and final-data runs;
their protected cleanup errors were retained. The interrupted manual run remains
protected: the registry declined ordinary closeout and requires explicit release
after investigation. No forced cleanup was performed.

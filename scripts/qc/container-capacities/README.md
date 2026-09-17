# Container capacity acceptance checks

Run from the repository root with Factorio 2.0.77 installed:

```powershell
python scripts/sync-container-capacity-locales.py
powershell -ExecutionPolicy Bypass -File scripts/invoke-esir-dev.ps1 -Task qc-fast
powershell -ExecutionPolicy Bypass -File scripts/invoke-container-capacity-qc.ps1
powershell -ExecutionPolicy Bypass -File scripts/invoke-container-capacity-qc.ps1 -WithK2SO -SkipRuntime
```

The first QC command seeds dependency archives. The container runner creates a
new directory under `.factorio-qc`, with its own mod list, startup settings,
configuration, saves, and reports. It does not deploy to installed mods or load
live saves. Source packs are read through workspace junctions; dependency
archives in the workspace are hard-linked. K2SO dependencies are copied from
installed archives, choosing the newest installed Factorio 2.0 versions.

The data fixture checks all six capacity columns, all ESIR variants, steam
logistics, ordinary and linked modded storage, footprint boundaries, explicit
dimensions, and hidden, zero-slot, weighted, custom-stack, and functional
inventory exclusions. K2SO adds checks for its actual container prototypes.

The runtime fixture checks filled filtered containers at normal and legendary
quality, shared linked inventories, and startup changes in both directions.
The JSON reports expose remaining item counts and spilled items; `all_pass`
does **not** mean that shrinking an inventory preserves overflow.

## Verified results, 2026-09-16

- All eight profiles passed with the non-K2SO test stack: 50 data assertions per profile.
- All eight passed with K2SO 1.6.16: 64 data assertions per profile.
- All eight non-K2SO runtime checks passed, plus Restrained-to-Extreme and Extreme-to-Restrained save loads.
- Restrained warehouse capacity was 64 at normal quality and 160 at legendary; Extreme was 1,024 and 2,560.
- Increasing capacity preserved the fixture's item counts and filters.
- Decreasing capacity removed the items in truncated slots, including linked storage. A separate shrink probe found zero spilled items. Empty slots that will be removed before reducing the setting; there is no custom overflow migration.
- Generated option descriptions matched the shared profile table in all seven locales. Manual tooltip inspection was omitted at the user's request.

Evidence directories:

- `.factorio-qc/container-capacity-20260915-232154`: eight profiles, runtime reports, both transitions, and `shrink-overflow.json`.
- `.factorio-qc/container-capacity-20260915-232349`: eight K2SO profiles.
- `.factorio-qc/container-preflight-final.txt`: final preflight; only existing module-header warnings in the auric vat and emerald hover tank modules.

## Tooltip maintenance

The main startup tooltip is assembled directly from the Lua profile table and
localized row parameters. Factorio's dropdown-option descriptions are static
locale entries. After changing profile numbers or a locale's `option-template`,
run `python scripts/sync-container-capacity-locales.py --write`, then run it
without `--write` to check all generated descriptions. This keeps the profile
table as the only manually maintained source of capacity numbers.

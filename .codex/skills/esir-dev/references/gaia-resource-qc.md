# Gaia Resource QC

Use the repo-local `qc-gaia-resources` task for deterministic Gaia resource
regressions. It runs native map previews against the resolved mod stack and
reports every Gaia resource, including relic debris.

The default policy lives in `assets/gaia-resource-qc.json`: eight seeds, a
4096-by-4096 preview, all six Gaia resources, and a minimum of one entity of
each resource per seed. Raw previews and Factorio output stay under the ignored
`.factorio-qc` artifact root.

After the seed matrix, six isolated control probes disable one resource at a
time on seed 1000. The selected resource must disappear while the other five
remain present; this catches per-entity settings that pin an individual slider.

The gate measures total presence, not radial bands. When investigating a
"center only" report, inspect the generated previews or add a runtime band
probe before treating this total-count gate as distribution proof.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-esir-dev.ps1 `
  -Task qc-gaia-resources -AsJson
```

Override the matrix for a focused check without changing the checked-in policy:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-esir-dev.ps1 `
  -Task qc-gaia-resources -Seeds 1000,2330146955 -PreviewSize 2048 -AsJson
```

This is a fresh-map test. For upgrades, separately verify that migration
`1.3.39.lua` preserves customized controls and nonmatching compatibility
overrides, replaces only the exact legacy relic default, and clears ESIR's six
legacy per-entity resource overrides. Map-generation changes apply to future
chunks; the migration intentionally does not regenerate existing chunks.

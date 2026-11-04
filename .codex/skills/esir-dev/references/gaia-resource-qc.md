# Gaia Resource QC

The [2026-11-03 acceptance record](../../../esir/handoffs/factorio-final-qc-gap-repairs-acceptance-2026-11-03.md#gaia-acceptance-and-the-observed-window)
links the corrected native case, fixed preview, extended matrix and controlled
defects. It also explains the separate graphical checkpoint worlds seen during
core execution. New changes still require fresh matching acceptance receipts.

## Required focused acceptance

Bare `qc-preview`, `qc-targeted -Suite gaia-resources` and `qc-full` require a seed-1000, 4096-square preview and
`test-suite: gaia-resources`, `test-case: gaia-resources/candidate`, profile
`default`. The native fixture calls the production runtime settings factory,
generates bounded chunk batches and requires all six resources. Its terminal
receipt includes effective settings, bounds and resource counts. The shared
runner owns private staging, report identity, input validation and finite limits.

Fresh runtime coverage calls `get_map_gen_settings()` with no preserved-save
argument and then sets the selected test seed. Supplying a seed-only preserved
table selects the historical generation branch. Required assertions verify the
native 2.1 generation revision, Gaia terrain expressions, actual Gaia tiles and
the fixture surface name.

The runtime fixture uses a separate surface named `esir-qc-gaia-runtime`.
Graphical windows during the full core run belong to declared player-dependent
checkpoint producers, including alert preferences and induction circuits. Their
starting worlds are recorded separately from Gaia map-preview/resource evidence.

```powershell
powershell -File scripts/invoke-esir-dev.ps1 -Task qc-test -Suite gaia-resources -Case candidate -TestProfile default -AsJson
powershell -File scripts/invoke-esir-dev.ps1 -Task qc-preview -Strict -AsJson
```

Explicit preview seed/planet requests default to `-PreviewScope requested` and
produce only that requested preview, with no Gaia native child. Select
`-PreviewScope gaia-acceptance` to retain the fixed row and native acceptance beside
the request. Full QC always includes the fixed gate. `qc-quick -Suite gaia-resources`
runs the native candidate alone and lists the remaining preview requirement.
Required missing reports or incomplete assertions fail the wrapper.
Current acceptance requires fresh passing receipts. Native counts establish resource
presence within the measured bounds. Geographic distribution, rendered inspection,
historical migration and reforge safety use their dedicated evidence.

## Extended preview matrix

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

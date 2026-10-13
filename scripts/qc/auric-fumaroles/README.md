# Auric fumarole rebuild lifecycle QC

Run `powershell -ExecutionPolicy Bypass -File scripts/invoke-auric-fumarole-qc.ps1`.
The runner requires installed Factorio 2.0.77 and the existing dependency seed.
It delegates isolated full-pack staging to `invoke-control-ups-qc.ps1`, registers
three managed runs, and never changes live mods or player saves. Run engines
sequentially. The private exports and command capture exist only in staged copies.
Use `-SeedModDirectory` to select another dependency seed, or `-SaveInput` to
reuse an existing tick-zero fixture instead of creating one. The default seed
falls back from `.factorio-qc/fmqc/mods-live` to `output/tesla-run-mods`.
Use `-SourceRoot` to validate an exported candidate main pack.

The first run checks module-version invalidation, same-version configuration
no-ops, missing active-count roots, stale band names, tracked and untracked
depletion, expiry, repeated adoption, absent/returning Vulcanus, console rescan,
and explicit admin repair. Private counters observe actual recount and chunk
admission calls. Terrain-generation callbacks settle before the fixture replaces
module state. A hidden local server saves real LuaEntity references with a
partially consumed backfill queue. When the separate rebuild-monitor API is
available, the fixture also checks its generation and progress; the report records
whether those integration checks ran.

Two engine benchmarks reload that same save: once normally, and once after only
the staged lifecycle helper version changes. They compare state before the first
production tick, then require production processing to finish the original
backfill without recounting or re-enumerating terrain. The test duration is
derived from the actual pending queue and the four-chunks-per-30-ticks budget.
Reports are written as
`script-output/auric-rebuild-qc.json` inside the returned managed run directories.

The fixture checks deterministic work admission and state preservation, not a
whole-save UPS speedup or long-run resource balance. Use the existing control UPS
cadence probes and rebuild-monitor owner fixture as complementary checks.

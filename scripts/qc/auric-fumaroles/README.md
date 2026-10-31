# Auric fumarole rebuild lifecycle QC

This is a historical standalone runner. Before new use, adapt dependency staging and
junction teardown to the [managed storage contract](../../../.codex/skills/esir-dev/references/housekeeping.md).
Preserve the historical receipts below; do not reinterpret them as compact managed runs.

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

## Native map controls

The setup lane also checks the resource control prototype and Vulcanus surface
defaults; absent old-save values; frequency/size/richness at disabled, minimum,
50%, 100%, 200% and maximum settings; initial-roll baseline parity; fractional
recovery budgets; actual recovery and keepalive call counts; ordinary dormant
rolls; zero in any dimension; and real finite-resource reserve assignment.
Synthetic recovery candidates instrument only staged placement calls, then
restore production functions before lifecycle and save/reload checks.

The saved pending-backfill fixture uses 50% frequency, 200% size and 200% richness.
Both reload lanes verify those selected values survive alongside the existing
4,321-unit tapped deposit and the original backfill queue.

Headless checks establish native control data and persistence, not menu layout.
In the updated build's new-game Resources tab, manually check the Vulcanus
association, enable checkbox, all three sliders at 100%, the explanatory hover
text, retained edits after switching tabs, and disabling/re-enabling the row.
Scripted vents intentionally remain absent from the map preview.

### Map-control verification, 2026-10-14

Factorio 2.0.77 run `af-map-controls-01` passed 780 setup checks, 789 ordinary
reload checks and 793 configuration-reload checks. Each reload resumed the saved
1,221-chunk queue without recounting, new admissions or terrain enumeration.
These totals include setup assertions inherited in the saved fixture; they are
not disjoint test counts. Runtime source changed only in annotations afterward.

Isolated run `af-map-menu-01` loaded and dumped current final data successfully.
`resolved-auric-controls.json` verifies the resource-category control, checkbox,
richness, Vulcanus defaults, 40,000/80,000 resource values, absent autoplace,
unchanged extraction, and retained visual/ambience fields. The production cadence
gate body also matched HEAD byte-for-byte. Native menu interaction was handed to
the user and is not claimed as verified.

The data-dump run's housekeeping receipt failed because its temporary pack
junctions were still present at completion. Only the verified staging junctions
were subsequently removed; the closed evidence remains protected. This is an
artifact-finalization failure, separate from the successful engine/data checks.

Repo preflight initially hit an unrelated long path in minigun scratch output.
A session-only file enumerator using `rg` allowed the same checks to finish:
Lua/PowerShell syntax, requires, locale coverage/duplicates, asset references and
pack versions passed. Remaining findings are unrelated minigun blueprint markers,
an asset-generator Python cache path, encoding in Singularity Lance/Anisetron
artifacts, and existing Auric Vat/Emerald module-header warnings.

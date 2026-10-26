# Unified alert verification

Run the contract audit and actual-owner Lua fixtures from the repository root:

```powershell
python -B scripts/qc/alerts/audit.py
.tools/lua-5.4.8/lua54.exe scripts/qc/alerts/runtime.lua
.tools/lua-5.4.8/lua54.exe scripts/qc/alerts/icon-sets.lua
.tools/lua-5.4.8/lua54.exe scripts/qc/alerts/icon-presentation.lua
.tools/lua-5.4.8/lua54.exe scripts/qc/terrain-evolution/v2-alerts.lua
```

The audit is also a required preflight check. These Lua tests mock native API
boundaries; they do not establish engine serialization, UI or multiplayer behavior.
`icon-sets.lua` executes the public settings/data manifest API and personal-choice
normalization. `icon-presentation.lua` executes the actual generic handler with
mocked native state. Check partial providers, future alert fallback, duplicates,
locale keys, startup/sentinel and future map defaults, player isolation, recorded
signal/message cleanup, provider removal, dismissed once-only incidents, unchanged
receipt ownership/deadlines, and ordinary-delivery priority within existing budgets.

The isolated connected native fixture uses current main-mod sources and the established
ecology dependency seed. Close other Factorio processes before running:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-terrain-evolution-qc.ps1 -HelperRoot scripts/qc/alerts/native -SeedMods .factorio-qc/egi1/mods -SaveInput .factorio-qc/egi1/fixture.zip -PrepareOnly -OutputRoot .factorio-qc/ua1
powershell -ExecutionPolicy Bypass -File scripts/qc/terrain-evolution/run-admin.ps1 -OutputRoot .factorio-qc/ua1 -TimeoutSeconds 900
```

Register a fresh short output root through housekeeping before staging; long absolute
paths can exceed Factorio's sprite-loader path limit even when the files exist.
This runner stages companion packs as junctions. Housekeeping may reject a completion
snapshot containing those reparse points; report that limitation and preserve the
evidence rather than following or deleting source-pack targets.
It drives real player settings, native alert calls, the actual gate checkbox handler,
power threshold and registry rebuild, captured destroyed-source incidents, and all
17 ecology receipt categories. GUI calls are programmatic; they do not prove mouse
interaction or multiplayer. The temporary fixture remote interface is appended only
to the staged mod and is never part of shipping code. Inspect generated screenshots
and reports separately. Save/reload fixtures must additionally check serialization
and migration rather than treating a Lua module reload as engine persistence.

After the main connected run, preserve its report and stage again with
`-SaveInput .factorio-qc/ua1/saves/_autosave-unified-alerts-migration.zip`.
Running the same connected driver verifies native serialization, adopted legacy
anchors, pending/delivered/expiring records, saved Off preferences and exact release.
The migration fixture reconstructs the old delivery root only in the isolated save.

Use `-HelperRoot scripts/qc/alerts/native-extra` with the original seed save for
native circuit transitions, programmatically opened gate consoles, clone
defaults, force-access rejection, ecology setting synchronization and layout migration.
If the save already contains another player, the fixture opens its console too;
otherwise it reports that simultaneous viewers remain unverified. This is not
a second connected client or multiplayer acceptance.

For final-data profile assertions, use the main native helper with `-DumpOnly`,
once with `-Disabled` and once without. The fixture hides and forces only the ecology
startup switch so stale staging settings cannot silently select the wrong profile.
All 27 personal alert toggles remain visible. The final-data log must contain
`ESIR_ALERT_CATALOG_FINAL_DATA_PASS 27 ecology=false` or `ecology=true`, respectively.

## Icon sets and native presentation

The shipping family has 108 PNGs and signals: 27 each for Original, SVG, Rendered
and Vanilla. Original retains root paths and old signal names; other sets occupy
`svg/`, `rendered/` and `vanilla/`. The static audit executes the actual stage-safe icon-set module and
checks both selectors, all signals/assets, real SVG/raster sources, provenance
hashes and byte-preserved Original files. It does not establish native rendering.

The `icon-sets-native` helper is the native selection/presentation fixture;
`icon-sets-provider` is its companion provider for registration and save-removal
scenarios. Both are test-only mods. Run clean isolated profiles with the provider
enabled and absent, preserve a save between removal/re-addition runs, and compare
surviving receipt/recipient/marker state. Include the startup default and first
personal normalization, two different personal selections where native players
are available, GUI/settings synchronization, actual delivered signals/messages,
dismissed once-only alerts, and preservation of unrelated native alerts.

Use `-HelperRoot scripts/qc/alerts/icon-sets-native` with the established isolated
runner/seed pattern above. Stage the provider fixture as a separate enabled mod
for provider-present runs; removing it is a save-configuration transition, not a
runtime deletion of signal prototypes. Keep generated logs and saves for each
phase. A programmatically controlled second player is not a second connected
client and does not establish multiplayer acceptance.

For the provider save/removal sequence, register a fresh short output root (the
example uses `.factorio-qc/is1`), then run from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-terrain-evolution-qc.ps1 `
  -HelperRoot scripts/qc/alerts/icon-sets-native -SeedMods .factorio-qc/egi1/mods `
  -SaveInput .factorio-qc/egi1/fixture.zip -PrepareOnly -OutputRoot .factorio-qc/is1/on
Copy-Item -LiteralPath scripts/qc/alerts/icon-sets-provider `
  -Destination .factorio-qc/is1/on/mods/esir-icon-sets-provider-qc -Recurse
$iconListPath='.factorio-qc/is1/on/mods/mod-list.json'
$iconList=Get-Content -LiteralPath $iconListPath -Raw -Encoding UTF8 | ConvertFrom-Json
$iconList.mods+=@{name='esir-icon-sets-provider-qc';enabled=$true}
$iconList | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $iconListPath -Encoding UTF8
Add-Content .factorio-qc/is1/on/config.ini -Encoding UTF8 -Value `
  @('[interface]','ui-scale-mode=manual-pixels','custom-ui-scale=1','[graphics]','full-screen=false')
powershell -ExecutionPolicy Bypass -File scripts/qc/alerts/run-icon-sets.ps1 `
  -OutputRoot .factorio-qc/is1/on -Checkpoint

powershell -ExecutionPolicy Bypass -File scripts/invoke-terrain-evolution-qc.ps1 `
  -HelperRoot scripts/qc/alerts/icon-sets-native -SeedMods .factorio-qc/egi1/mods `
  -SaveInput .factorio-qc/is1/on/saves/_autosave-style-provider.zip `
  -PrepareOnly -OutputRoot .factorio-qc/is1/off
Add-Content .factorio-qc/is1/off/config.ini -Encoding UTF8 -Value `
  @('[interface]','ui-scale-mode=manual-pixels','custom-ui-scale=1','[graphics]','full-screen=false')
powershell -ExecutionPolicy Bypass -File scripts/qc/alerts/run-icon-sets.ps1 `
  -OutputRoot .factorio-qc/is1/off
```

The provider-present fixture deliberately selects the provider startup default;
production still defaults to Rendered. `-Checkpoint` waits for a fresh ready
report, a stable readable save archive, and Factorio's save-finished log before
stopping its owned process. A ready report alone does not prove the save completed.
The second profile omits the provider and verifies the engine's real configuration
transition. It records whether the native once-only alert survived prototype
removal; either a surviving replacement or continued absence is valid, with no
new logical delivery. Use fresh seed-save profiles without the provider for
Rendered-default and 1.5 UI-scale checks, and add `-Disabled` during preparation
for ecology-off signal/operational coverage. Screenshot sequences separately show
the selector, lower categories and unobscured native toolbar.

The separate `icon-visual` helper exercises the 27 catalogue signals, all ten
operational deliveries and all seventeen ecology deliveries through the production
handler. Ecology admission waits for delivery and bounded cleanup between batches
so its four-alert budget is respected. It captures native alert blink phases and
the Ecology checkbox panel. It does not change gameplay behavior or prove mouse
interaction, multiplayer, or individual toolbar readability for every icon: Factorio
groups custom alerts into a representative button.

The older `icon-visual` helper remains a 27-identity baseline presentation fixture.
Prepare it with the same seed/save options above. For all four shipping styles,
prefer setting `ei-alert-icon-set` through the production path; never overwrite
Original with a candidate set. Unpromoted art needs a separate isolated profile:
resolve its `graphics` junction before writing and copy only into an explicitly
named style directory after verifying it lies inside that profile. Copying through
a source-pack junction would overwrite shipping art. Compare all 27 candidate
hashes with the reviewed source before launching Factorio.

Use the profile's `config.ini` `[interface]` settings `ui-scale-mode=manual-pixels`
and `custom-ui-scale=1` or `1.5`. Run a fresh fixture save for each scale and an
ecology-disabled profile, preserving each report, client log and fresh screenshots
before reusing the profile. The data-stage assertion logs
`ESIR_ICON_FINAL_DATA_PASS 27 ecology=true` or `ecology=false`; both profiles keep
every signal in the main-mod asset namespace. The disabled profile presents a
fixture catalogue because the production Ecology window is intentionally absent.

The [generator guide](../../../.codex/esir/asset-generators/alert-icons/README.md)
documents named staging, deterministic SVG/raster exports, explicit promotion and
the four-way comparison gallery. Register fresh ignored output first, then run:

```powershell
python -B .codex/esir/asset-generators/alert-icons/generate.py --set svg `
  --staging-dir output/alert-icons/svg --svg-dir .codex/esir/asset-generators/alert-icons/sources/svg
python -B .codex/esir/asset-generators/alert-icons/generate.py --set rendered `
  --staging-dir output/alert-icons/rendered --raster-dir .codex/esir/asset-generators/alert-icons/sources/rendered
python -B .codex/esir/asset-generators/alert-icons/generate.py --set vanilla `
  --staging-dir output/alert-icons/vanilla --svg-dir .codex/esir/asset-generators/alert-icons/sources/vanilla
python -B scripts/qc/alerts/icon-assets.py --stage output/alert-icons/svg `
  --rendered-stage output/alert-icons/rendered --vanilla-stage output/alert-icons/vanilla `
  --work-dir output/alert-icons/export-checks
```

The export fixture checks source reproduction, all four sets' preservation and
rejection of missing/wrong-set, Original-target, partial, stale and tampered
promotions. Preview generation and rejected promotions leave shipping and durable
sources unchanged. Imagegen physical-appearance originals/prompts are preserved;
there are no invented SVG masters or claims of Blender-render provenance.

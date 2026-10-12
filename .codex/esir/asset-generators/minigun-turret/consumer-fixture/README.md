# Isolated final minigun consumer checks

Installed entrypoint: `.codex/esir/asset-generators/minigun-turret/consumer-fixture/invoke-consumer-fixture.ps1`.
Read `output/minigun-implementation/STATUS.md` first when resuming. Native execution
is pending; use the canonical commands below after the required evidence exists.

Installed tooling for isolated Factorio **2.0.77** checks; final native acceptance
is pending. The root agent owns installation, all engine runs, image review and
promotion. These scripts never alter a shipping mod, approve an image, or change
the frozen SD/HD atlas bytes.

## Inputs and order

Use the exact **full256 draft artifact map** and its unchanged candidate-assets
manifest already bound to final native firing evidence. Pilot metadata is
rejected. The six-field lineage matches `finalize_graphics_data.py`: model,
compiled metadata, original candidate Lua, mechanics, anchors and canonical PNG
inventory hashes. Every staged PNG is a same-volume hardlink to its verified
frozen source. Each isolated G6/HD pack is a real directory, never a writable
junction into a source pack.

There are two deliberate phases, resolving the visual-review/finalization
dependency:

1. Before finalization, the private helper applies exact full256 shipping-path
   metadata through `factory.create(..., {fixture=true, direction_count=256})`.
   No calibration flag or eligibility field is fabricated. Actual main gameplay
   prototypes, item/recipe/technology and the selected pack are used. The native
   visual evidence is an input to finalization.
2. After finalization, pass `-Finalized` with the finalizer output directory.
   The builder verifies its receipt, complete output hashes, six-field lineage,
   unchanged profile/map and measured native launch contract. The main helper
   calls the factory without fixture privileges and **does not apply it to any
   live prototype**. It reads the actual shipping consumer untouched, compares
   state/base graphics and timing to an unregistered comparison copy, and checks
   exact final launch fields and icon paths/sizes. Run SD and HD integrated loads
   against the reviewed main integration source at this point. A fresh Stage
   binds that source; old payloads must not be reused after source changes.

Both phases retain the actual recipe icon fields. The recipe must inherit its
selected item icon through `main_product`; the helper never installs an explicit
recipe icon. Only the draft phase applies entity/item/technology artwork and the
previously measured shell-particle fields. Finalized consumers are observed as
loaded after all main passes, including their unchanged shell-particle behavior.

The original draft `-ArtifactMap` remains required even in phase 2 because the
native atlas manifest pins its original candidate Lua. `-Finalized` supplies the
new approved metadata separately. Do not pass the finalizer's replacement map
as the draft input.

## Main native matrix

Stage and run each combination serially:

| Scenario | Actual HD presence | Selected profile | Expected native result |
|---|---|---|---|
| `absent` | No folder, archive or mod-list entry | SD/G6 | Create + graphics succeed |
| `disabled` | Real HD folder, mod-list disabled | SD/G6 | Create + graphics succeed |
| `enabled` | Real HD folder, enabled | HD | Create + graphics succeed |
| `incompatible` | Isolated copy changes HD version to `2.0.0` | Rejected | Exact major-version guard; graphics never starts |

Run all four with `-Mode off` and `-Mode on` (8 runs). The only unsupported-major
mutation is to isolated metadata; no source `info.json` is changed. Existing
dependency ZIPs are hardlinked, source main/dependency folders are read-only-use
junctions, and G6/HD are private copies of the base-only asset scaffolds plus
hardlinked frozen PNGs. Old HD seed entries are removed.

```powershell
$fixture = '.codex/esir/asset-generators/minigun-turret/consumer-fixture/invoke-consumer-fixture.ps1'
$inputs = @{
    ArtifactMap = '<full draft emission>/artifact-map.json'
    MechanicalData = '<native frozen input>/candidate-mechanical-data.lua'
    Anchors = '<native frozen input>/muzzle-anchors.json'
    AssetsManifest = '<native frozen input>/candidate-assets-manifest.json'
}
& $fixture -Task Stage -Scenario enabled -Mode on @inputs
# Only the root operator starts the explicitly printed managed RunPath:
& $fixture -Task Run -RunPath '<printed managed payload>'
```

Run refuses concurrent Factorio or background Blender, stale source/helper/pack
hashes, a reused payload, or the wrong engine version. Processes are hidden and
exit codes are captured only after process completion. Results are retained
under `output/minigun-implementation/consumer-results`. PNGs and asset evidence
are retained as verified hardlinks, so retaining raw and review paths does not
duplicate their contents. No raw captures are deleted. On completion the managed
run closes and only verified source junctions are unlinked; asset directories and
evidence remain. `Analyze` accepts a fresh `-AnalysisOutput` for reanalysis without
rewriting historical reports.

Each successful graphics run is 660 ticks and produces **270 1280×960 PNGs**:
eight-heading parked/running/shadow views, 62 preparation and 202 folding frames,
plus actual inventory/crafting, entity and technology windows. Native audit
records every state/base sprite filename, icon provenance, selected mods,
unchanged attack/energy/inventory/collision mechanics, launch fields,
orientation observations and UI open-state readbacks. Targets and supplied power
are an observation rig; lifecycle shortage/disable/save tests belong to the
separate lifecycle fixture. Connector placement remains user-owned.

The scheduled clips are evidence to inspect, not an automatic assertion that a
particular rotor phase appeared at every scheduled tick. Visible state timing,
shadows and UI readability still require review. No screenshot-size compression
estimate is treated as a measured final evidence volume. Pack/retained hardlinks
add paths rather than new PNG allocations; the actual screenshot bytes are the
new storage cost. Measure the first retained run before scheduling all eight.

## Native visual review handoff

After all eight main runs pass automated checks:

```powershell
python -B .codex/esir/asset-generators/minigun-turret/consumer-fixture/analyze_fixture.py `
    --aggregate '<absent-off>' '<absent-on>' '<disabled-off>' '<disabled-on>' `
                '<enabled-off>' '<enabled-on>' '<incompatible-off>' '<incompatible-on>' `
    --output output/minigun-implementation/consumer-results/review-full256
```

Arguments are retained result directories. The aggregator requires the exact
eight configurations, identical lineage, unchanged source reports/PNGs/assets
and all 13 finalizer visual cases. It emits `raw-visual-observations.json` and
`visual-review-template.json`; **every approval starts false**. Review the native
captures, write specific notes and supply a reviewer in a separately retained
completed acceptance file. The template schema is
`esir.minigun.visual-acceptance.v1`, compatible with the finalizer's 13-case
contract. Exit 3 means automated checks passed but visual review is pending;
exit 2 means failure; exit 0 is reserved for the expected incompatible-major
rejection. None grants production approval.

The approved `mechanics/unchanged` case must reference this complete main
aggregate. All six successful native reports (absent/disabled/enabled, each
doctrine off/on) bind unchanged before/after combat snapshots to the review.
Mechanics must agree across the three HD scenarios within each doctrine; the
two doctrines remain separate. The finalizer retains both snapshots, their
canonical hashes and exact review/aggregate/native-report references as
`consumer_combat_baselines`. Finalized Stage rehashes those sources, and the
native observer compares untouched shipping combat fields to the matching
approved doctrine baseline. Equality between two newly observed snapshots alone
cannot excuse a pre-existing cooldown, range or energy regression. Graphics,
launch fields, shell presentation and state timing have separate checks;
`circuit_connector` is excluded because connector placement is user-owned.

## Independent base + HD example checks

These are additional integration receipts, not substitutes for the main 13-case
review. Both use `-Mode off` and enable exactly `base`, the HD pack and the private
observer helper. No ESIR main, G6 or optional doctrine/dependency graph is staged.

* `standalone-unloaded`: checks that loading the asset pack itself creates no
  `example-minigun-turret`. The observer displays a vanilla gun turret as a control.
* `standalone-example -Finalized <directory>`: the private helper explicitly
  requires the actual copied `__e-s-i-r-minigun-turret-graphics-hd__.examples.data`.
  That file uses the actual `examples/graphics.lua`, approved launch contract and
  generated final metadata. It must create the sample entity/item/recipe. The
  helper adds a private technology for its native technology icon view and checks
  `include_shadows=false` leaves zero native shadow layers.

The standalone observer leaves the actual example entity/item/recipe untouched
and builds only an unregistered comparison through the final factory. It checks
actual HD state/base sprite paths, full state timing, the exact creation map,
present-or-absent launch fields and entity/item/technology icons. The unloaded
example's explicit recipe icon is also checked; the main recipe continues to
inherit its item icon through `main_product`.

The builder rejects any root `data*`, `control.lua` or `settings*` loader in either
asset pack and verifies base-only dependencies. The standalone example cannot be
run from uncalibrated draft metadata. The actual example code is copied from the
current scaffold and individually hash-bound in the plan and native receipt.

## Actual shipping files and final ZIPs

Private fixture packs link the verified artifact sources. Passing them does not
prove those files exist at the real shipping destinations. After atomic main,
metadata and asset integration, run the installed read-only auditor:

```powershell
python -B .codex/esir/asset-generators/minigun-turret/audit_shipping.py `
    --repo . --finalized output/minigun-implementation/finalized-minigun
```

After finalized main and standalone native checks, use `measure_packages.py`
with the **finalizer's** artifact map and a fresh output directory, then repeat
the auditor with `--archives <that directory>`. This checks the complete actual
G6/HD ZIP inventories against installed PNGs and all support files, including
license, README and the unloaded example. Both final archives must be strictly
below 256,000,000 bytes. The [finalization boundary](../FINALIZATION.md) gives the
full commands and order; pre-native budget archives cannot satisfy this gate.

## Offline checks completed

`python -B .../test_fixture.py` covers stale PNGs, switched profiles, real absence,
old-pack routing, path traversal, duplicate artifacts, missing doctrines, changed
capture bytes and summary/native scenario swaps. The successful aggregate test
verifies it still produces only a pending review. Synthetic test objects are
temporary and labelled unit-only; they are never retained as native evidence.
Additional finalized-consumer tests reject helper rewrites, actual state-graphics
drift, added launch fields that must be absent, wrong icon sizes and loss of
recipe inheritance.

Python AST, Lua 5.4 syntax and PowerShell parser checks are appropriate offline
checks. Lua 5.4 parse success is not a Factorio 5.2/native compatibility verdict.
The engine/API authority inspected is the installed `2.0.77` runtime JSON under
`C:/Program Files (x86)/Steam/steamapps/common/Factorio/doc-html`.

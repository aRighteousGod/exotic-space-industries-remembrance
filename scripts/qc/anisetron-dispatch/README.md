# ANISETRON and Lance dispatch regression

Factorio 2.0.77 fixture for the guarded mandatory `updater(event)` contract.
The bridge is appended only to a staged mod. Shipping code exposes no new remote.
Fresh results and limits are recorded in [verification.md](verification.md).

The first 64 ticks instrument the actual central dispatcher with no-op weapon
receivers, always-eligible work and an exhausted railgun lane. Assertions cover
all sixteen phases, real `goto skip`, exactly one call per weapon per tick and
ANISETRON immediately after the final mandatory predecessor. Then the original
receivers are restored for native paid combat against shared targets. The first
target dies; compare exact source/tick/damage order and subsequent paid state,
ammo, target locks and endpoints against a freshly frozen source tree.

Candidate-only probes swap minimal scheduler state for repeated read-only work
checks. They cover no storage, empty owners needing cleanup, future/due parked
checks, tick zero, permanent memories, Wound marks, committed packets without
sources, attached strands, transient cleanup, visual revision repair and due
sampling. Each probe compares serialized state before and after eight calls.
Baseline controllers without the new predicate skip those probes.

After the native trace, synchronous production Lance admissions test the legacy
QC adapter with limits 0, 1 and 100000. Each must resolve all three contacts at
+8 ticks and all three collapses at +38, return three for each due batch, return
zero before or after it, and deliver exactly 4500 damage. This isolated adapter
probe simulates the paid notification; native energy payment is covered by the
ordinary Lance mechanics suite and the preceding shared-target trace.

An empty current-revision save separately checks ordinary reload without a
configuration rebuild. The first pure predicate remains eligible over repeated
calls while the local preset is cold; normal service initializes it once and
the empty controller becomes idle immediately. Replay at the same fidelity:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 -FixtureSource scripts/qc/anisetron-dispatch -RunName dispatch-cold-save -Save
$run=(Resolve-Path .factorio-qc/anisetron/dispatch-cold-save).Path
& 'C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe' --benchmark "$run/saves/anisetron-transition.zip" --benchmark-ticks 5 --benchmark-runs 1 --config "$run/config.ini" --mod-directory "$run/mods" --disable-audio
```

Keep the staged source and `test-config.lua` unchanged for that reload. The
wrapper's ordinary `-Resume` rewrites fixture configuration and triggers a
configuration rebuild, which initializes the preset before the tick predicate.

```powershell
$runner='scripts/invoke-anisetron-qc.ps1'
powershell -ExecutionPolicy Bypass -File $runner -RunName dispatch-order-before -SourceRoot .factorio-qc/anisetron/dispatch-work/baseline -FixtureSource scripts/qc/anisetron-dispatch -RuntimeTicks 502
powershell -ExecutionPolicy Bypass -File $runner -RunName dispatch-order-after -FixtureSource scripts/qc/anisetron-dispatch -RuntimeTicks 502
python -B scripts/qc/anisetron-dispatch/compare.py .factorio-qc/anisetron/dispatch-order-before/script-output/anisetron-qc.json .factorio-qc/anisetron/dispatch-order-after/script-output/anisetron-qc.json --output .factorio-qc/anisetron/dispatch-work/order-parity.json
```

Complement with the ordinary ANISETRON six-fidelity, mobility, tracking,
inheritance and historical-save fixtures, plus current-source Lance mechanics
and schema-13/schema-14 transition replays. The fleet profiler supports both
entry-point names and divides inclusive time by fixed simulation windows;
skipped idle invocations are expected, not a gameplay mismatch.

Lance's internal `update-total` profiler label remains stable across the public
rename. For matched `-Mode benchmark -Scene normal-power -Profile -Ticks 600
-Runs 1 -CurrentSource` runs, use `-BaselineSource` only for the frozen side.
`compare_lance_profile.py <before-run> <after-run> --output <report>` checks
accounting and divides nested phase attribution by the fixed [120,600) window,
including ticks with no invocation. Only shot plus update-total form the inclusive
Lance total; these are module measurements, not whole-factory UPS or GPU costs.

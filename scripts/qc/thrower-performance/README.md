# Flame and acid turret performance QC

Target: Factorio 2.0.77, ESIR 1.3.40. All runs use an isolated gameplay copy,
private mod list and settings, and `.factorio-qc/thrower-performance/<timestamp>`.
Dependency archives are hard-linked and graphics packs are read through junctions.
No live saves or installed mods are changed.
Fixture mod lists disable the gameplay pack's declared incompatible mods,
even when an older QC seed still enables them; `info.json` is authoritative.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-esir-dev.ps1 -Task qc-fast
powershell -ExecutionPolicy Bypass -File scripts/invoke-thrower-performance-qc.ps1
powershell -ExecutionPolicy Bypass -File scripts/invoke-thrower-performance-qc.ps1 -Disabled
powershell -ExecutionPolicy Bypass -File scripts/invoke-thrower-performance-qc.ps1 -Behavior
powershell -ExecutionPolicy Bypass -File scripts/invoke-thrower-performance-qc.ps1 -Transition
powershell -ExecutionPolicy Bypass -File scripts/invoke-thrower-performance-qc.ps1 -Transition -Disabled
powershell -ExecutionPolicy Bypass -File scripts/invoke-thrower-performance-qc.ps1 -Performance
powershell -ExecutionPolicy Bypass -File scripts/invoke-thrower-performance-qc.ps1 -Performance -Diagnostic -ReuseRun <timing-run-folder>
powershell -ExecutionPolicy Bypass -File scripts/invoke-thrower-performance-qc.ps1 -Visual
python scripts/qc/thrower-performance/check-results.py
python scripts/qc/thrower-performance/check-results.py <original-combat.json> <2x-combat.json> <4x-combat.json> <8x-combat.json> <16x-combat.json>
python scripts/qc/thrower-performance/check-performance.py <timing-run-folder>
```

From a PowerShell session, use `-Profiles @('original','16x')` for a subset.
When launching with `powershell -File`, pass a single profile or omit `-Profiles`;
PowerShell does not expand a comma-separated native argument into an array.
`-DataOnly` skips runtime simulation but still creates the map and runs final
prototype assertions. The ordinary create/load path validates the same engine
prototype stage as `qc-fast` without writing a multi-gigabyte data dump per case.
Use `-FrozenPack <timing-run-folder>/mods/exotic-space-industries-remembrance`
for subsequent combat/behavior/transition/visual runs to keep the gameplay code
identical while other work in the checkout continues. QC helper files are taken
from `scripts/qc/thrower-performance`; graphics packs remain read-only links.

## Contracts

- A snapshot is injected immediately before the new data-final pass in the
  disposable copy, with ownership assertions immediately after this pass and
  balance/reference checks on finalized prototypes. This separates later
  compatibility edits, such as overlap-cleanup notifications, from this feature.
  Original must leave every pre-existing fluid turret, stream,
  fire, sticker, gun, and ammo prototype unchanged. Other profiles must preserve
  every excluded prototype and ground-fire balance field.
- The combat matrix has 208 cases per profile: ten flame fuels and four acid
  fluids, normal/legendary quality, no research/research, and native direct,
  sticker, ground-fire, and combined damage. Acid has no ground-fire component.
  Native test streams isolate components; no scripted damage is used.
- Warm up for 3,600 ticks, then measure 7,200 ticks. Direct/sticker DPS and fluid
  consumption must remain within 1%; ground/combined DPS within 5%. Resistances
  are removed only from these parity targets. Reports also include event counts.
  Per-second warm-up damage records initial fire buildup separately from the
  sustained measurement window.
- Behavior runs keep the real turret identities and cover bursts, retargeting,
  moving crowds, overlapping turrets, mixed fuels, both range edges, flat plus
  percentage resistance, and starvation/recovery. Differences are measured,
  not asserted to have identical combat outcomes.
- Transition runs start a private local server on port 34198, save populated
  worlds, and stop only that fixture's process. Original -> 16x -> 2x -> Original
  checks turret identity, unit number, quality, health and active-effect survival.
  Reports expose concurrent stickers when switching shared/private effects.
  A final replay stops the populated saved turrets, waits 130 seconds, and checks
  that every fire/sticker expires naturally and damage ceases.
- Performance runs cover 100/500/1,000 actively firing turrets, each flame-only,
  acid-only and mixed. Each phase has 600 warm-up ticks and 1,800 measured ticks;
  phase setup/teardown ticks are excluded. Three sequential replays emit native
  `wholeUpdate` timings. Diagnostic replays install a damage listener separately;
  never use diagnostic timings as native performance evidence. `-ReuseRun`
  replays the exact frozen timing fixture and writes separate `-diagnostic`
  reports, so concurrent edits cannot change the measured mod stack.
  Timing targets use one million health so small acid hits remain visible in
  native health differences; the DPS matrix uses damage events instead.
- Visual runs request paired day/night screenshots at ticks 600 and 1,200 from
  a fixed camera, then stop firing and capture tails at 1,230/1,300/1,380.
  They require a working graphical client and all pack assets. A private short
  mod-directory junction in the temporary folder avoids Windows sprite-path
  length limits; its path is printed alongside the artifact directory. For a
  frozen gameplay source, missing graphics files are supplied from the working
  tree and counted in the log; existing images and all frozen Lua stay intact.

Run timing benchmarks without other fixtures running. Whole-update timings
include the rest of the loaded mod stack and machine contention; they are not a
hardware-independent UPS guarantee. Keep raw reports in ignored staging and
record measured results and coverage limits in `verification.md`.

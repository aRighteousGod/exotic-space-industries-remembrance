# Prototype 2 minigun execution report

**Historical16-phase experiment.** Its failure and measurements remain unchanged.
For the current28-pose implementation and reusable completed work, use
[the current progress record](PROGRESS-2026-10-11.md) and
[separated contract](HANDOFF-SEPARATED.md). The held status below is historical.

Executed for the selected exposed-cradle design on 2026-10-09, using Blender
5.1.1 and Factorio 2.0.77. Source, rig and review outputs remain in
`output/meshy/minigun-prototypes/prototype-2/handoff-256/`.

**Status:** rig and render pilot complete; the native spin/firing parity gate
failed. Full 256x16 production sheets, final Lua export, native muzzle calibration
and shipping promotion are held. The implementation has not changed production
Lua or graphics. The prepared Blender rotor is independently animated, but that
does not establish an independent Factorio animation clock.

## Retained results

| Result | Evidence |
| --- | --- |
| Source-preserving three-part rig | `prepared/minigun-prototype-2.blend`, `prepared/mechanical-split.json` |
| All 4096 poses fit color and hard-shadow camera bounds | `pilot/preflight.json`, `pilot/all-pose-bounds.npz` |
| 23 color and 29 shadow pilot frames | `pilot/index.html`, `pilot/frames.jsonl` |
| Native timing and phase captures | `timing-probe/timing-summary.json`, per-scenario native/decoded reports and phase contact sheets |
| Four color + one shadow frames at final settings | `benchmark/configuration.json`, `benchmark/frames.jsonl` |
| 256 geometry-derived visual muzzle anchors | `muzzle-anchors.json` |
| Explicit successful/held/skipped checks | `qa-summary.json` |

Source SHA256 is
`453a8f5b75fd16630803d698293222cf9e07a3e1cecb1f7c3b40434d75008f59`.
The original paid GLB remains unchanged.

The original 1,575,210 faces belong exactly once to base (239,525), upper
(1,167,981), or rotor (167,704). Corner UVs match exactly; maximum copied-normal
error is 0.05234 degrees. The internal bearing liner and rotor root hub hide the
two mechanical cuts without closing the front bores. The yaw driver rotates the
upper and rotor around the bearing, while a quaternion driver turns the rotor
around the measured root-to-muzzle axis. The base stays at its fitted world pose.

The analytical all-pose bounds were independently checked against full vertex
projection at six representative poses; the largest difference was
0.00002206 pixels. Fixed-base matrix error was zero. The 540x540 camera retains
at least 19.37 pixels of hard-shadow/color clearance. Rendered pilot alpha bounds
also passed the eight-pixel master-margin assertion.

## Native timing finding

The fixture clones the current final turret and preserves its combat parameters,
with cooldown 0.25 and attack-state speed 20. A single source-only diagnostic
action counts launches, independently reconciled against ammunition consumption.
The fixture does not count every ammo delivery: current final ammunition also
contains ESIR spider bookkeeping actions. Targets are healed each tick, and the
test exercises initial acquisition, heading changes, short interrupted bursts,
folding and automatic reacquisition at two initial headings.

Both Ballistic Divergence settings gave identical conclusions:

| Attack-state speed | Shots in the common 660-tick steady window | Ordered 16-phase motion |
| --- | ---: | --- |
| Legacy 20 | 660 | Original one-frame art |
| Diagnostic 20 | 660 | No |
| 1/16 | 42 | Yes |
| 1/32 | 21 | Yes |
| 1/8 | 83 | Skips phases |

The advanced probe retained the original idle and transition definitions to
isolate the attack animation. Speeds of 20 with leaf animation speeds 1, 1/16,
and 0.001, start-frame override, or random offset preserved the entire legacy
shot curve, first shot and ammunition consumption, but showed no ordered spin.
The slower start-frame variant produced ordered motion and reduced firing.
Replacing all transitions with 256-direction diagnostic art also changed some
interrupted/reacquisition timing; do not assume that a new all-state definition
is harmless merely because its speed fields are unchanged.

The energy-glow probe tested a separate normal-blend 16-frame layer at leaf speeds
1 and 1/8, zero flicker strength and zero extra glow-light intensity. It preserved
firing, but the first probe showed no decodable overlay. A further probe makes
the original state art transparent while preserving its state/frame/direction
counts, to rule out body occlusion. The transparent-body probe also preserved
firing and showed no decodable glow overlay. Its retained `on-glow-hidden`
report distinguishes that result from the earlier covered-body probe. Neither
provides a usable independent rotor clock.

These measurements agree with the [Factorio developer's explanation of turret
state progress and firing](https://forums.factorio.com/viewtopic.php?t=76805):
the attack state supplies both animation progress and the firing transition.
The live 2.0.77 measurements are the version-specific evidence here.

## Pilot and export measurements

The pilot contains d=32 phases 0..15, plus phase-zero views at d=0,64,96,128,
160,192,224. Its shadows include the full diagonal loop and additional p=4,8,12
at d=64/192. Visual inspection of the contact sheet and phase strip shows a
stable foundation/drum with the forward barrel/collar group rotating. All
adjacent phase pairs, including 15->0, differ by at least 5582 RGBA pixels.
Phase-zero shadow approximation differs by at most 1.564% of total shadow alpha
in the tested views. That supports the planned approximation for this pilot;
native shadow presentation remains an integration check.

| Density | Color cell | Shadow cell | Estimated complete texture RGBA |
| --- | --- | --- | ---: |
| 32 px/tile, scale 1 | 168x143 | 185x122 | 420.877 MiB |
| 64 px/tile, scale 0.5 | 336x286 | 370x244 | 1683.508 MiB |

These are calculated texture byte counts, **not measured VRAM**. The common
ground-anchor shifts are approximately color `{0,-1.234375}` and shadow
`{1.171875,0}`. The measured master crops are color `[102,48,438,334]` and shadow
`[160,148,530,392]`. Both densities' phase-strip cells were checked byte-for-byte
against the original color crop or the explicitly declared half-scale resize.

The 256-sample benchmark used the GTX 1070 through OptiX. Median warm color-frame
time was 1.960 seconds, shadow-frame time 3.401 seconds. A 4096-color/256-shadow
batch extrapolates to about 2.47 hours; the full batch has not run, so this is not
an observed completion time. Source textures, geometry, camera and fixed Cycles
seed are recorded in each configuration hash.

The muzzle proposal projects the measured central bore exit with the actual
camera at all 256 yaws. It retains the existing empirically calibrated native
heading-index remap, while storing visual offsets and the candidate one-tile
effect-height compensation separately. Compensation and actual projectile/flash
alignment remain unverified. The old 64-direction sprite's coordinates, scale
and shifts are not copied into the new geometry.

## Reproduction

Run from the repo root. These commands stage outputs; they do not promote assets.

```powershell
powershell -ExecutionPolicy Bypass -File .codex/esir/asset-generators/minigun-turret/invoke-prototype2.ps1 -Phase prepare
powershell -ExecutionPolicy Bypass -File .codex/esir/asset-generators/minigun-turret/invoke-prototype2.ps1 -Phase preflight
powershell -ExecutionPolicy Bypass -File .codex/esir/asset-generators/minigun-turret/invoke-timing.ps1 -Mode on
powershell -ExecutionPolicy Bypass -File .codex/esir/asset-generators/minigun-turret/invoke-timing.ps1 -Mode off
powershell -ExecutionPolicy Bypass -File .codex/esir/asset-generators/minigun-turret/invoke-timing.ps1 -Mode on -Advanced
powershell -ExecutionPolicy Bypass -File .codex/esir/asset-generators/minigun-turret/invoke-timing.ps1 -Mode on -Glow
powershell -ExecutionPolicy Bypass -File .codex/esir/asset-generators/minigun-turret/invoke-prototype2.ps1 -Phase pilot
powershell -ExecutionPolicy Bypass -File .codex/esir/asset-generators/minigun-turret/invoke-prototype2.ps1 -Phase benchmark
python .codex/esir/asset-generators/minigun-turret/build_pilot.py
```

The timing wrapper decodes and closes each new managed run automatically.
To compare several retained runs together, use
`analyze_timing.py --runs <managed-run-paths>`; returned metadata identifies those
paths. The fixture uses an isolated mod
directory and settings, not the user's live mod-list or mod-settings. Background
Blender uses factory startup and leaves the user's open scene alone. Keep heavy
Factorio/Blender graphics work serial on this workstation.

The production wrapper refuses to start when `qa-summary.json` lacks a passed
production gate. Its renderer uses global frame indices, per-frame file/config
hashes, fixed random seed, explicit Object/Shadow layer context and crash-safe
terminal journal recovery. A partial final JSONL record is discarded; earlier
journal corruption raises an error. Blender 5.1 still renders are explicitly
named per global frame to avoid repeatedly overwriting `Untitled.png`.

## Required route decision

The user was asked whether to use a native static/motion-blurred barrel or a
separate visual controller for visible spin. The first route preserves native
combat and the no-runtime-controller scope, but changes the 16-phase in-game
presentation target. The second can preserve combat with a separately driven
visual, but adds a runtime ownership/lifecycle/performance task that this staging
plan explicitly excludes. Do not silently reduce firing rate to satisfy the
animation target, or relabel the blocked full sheet as completed.

After the route is selected: reconcile the render/state contract, pass its native
parity/visual test in both doctrine modes, then render/export the applicable full
set. Calibrate muzzle/projectile height against actual shots, stage the Lua draft
and run focused asset/graphics checks. Production integration remains a separate
explicit task under the original handoff.

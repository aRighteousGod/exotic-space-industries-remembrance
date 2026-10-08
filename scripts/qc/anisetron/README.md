# ANISETRON 17 focused QC

The fixture validates the shipping Processional Cathedral on Factorio 2.0.77.
Current repair results are recorded in [tracking-verification.md](tracking-verification.md),
with the preceding integration snapshot in [verification.md](verification.md).
Runtime ownership is documented in [anisetron.md](../../../.codex/esir/blueprints/anisetron.md),
with art replay in the [reference17 dossier](../../../.codex/esir/asset-generators/anisetron/reference17/README.md).

## Ownership and isolation

`scripts/invoke-anisetron-qc.ps1` copies the actual ESIR pack into ignored staging,
appends `bridge.lua` only to that copy, and adds this helper mod. The public mod
does not expose the fixture's remote interface. Ordinary native runs copy the
existing `explode.zip` player seed; server-save profiles create a separate
playerless persistence fixture. Initial seed loading and transition-save replay
use distinct configuration flags and clocks.

The combat force has no damage bonuses, targets have no resistances, and visual
captures use a separate surface. Real native manual input, autopilot, logistic
and construction robots are exercised. The fixture never assigns Spidertron
speed, creates an unsupported player, or inserts unpaid bursts. Legacy conversion
removes v2 fields only from genuine unstarted, native-paid FIFO entries.

## Mechanical contract

| Field | Expected value |
|---|---|
| Payment | One native magazine-one charge opens both channels |
| Duration/contact | 1200 ticks; contacts at 0, 12, ..., 1188 |
| Crown | 160 laser; hold an eligible target throughout 360 degrees |
| Facade | 80 laser; hold an eligible target within the current 120-degree front |
| Normal maximum | 100 contacts per channel; 24000 combined damage |
| Rare ammo | 256 crown plus 128 facade; 38400 combined damage |
| Quality | Opener ammunition quality; duration-quality hook is zero |
| Source removal/force/surface change | Cancel remaining paid ownership without refund |
| Versionless legacy work | Original 240-quality-scaled facade packets, FIFO and deadlines; no crown |
| Fidelity | Identical payment, targeting, timing and damage at all six tiers |
| Graphics | 128 headings and both core beams at every tier |

Replacement acquisition follows a retained, unwrapped angular waypoint. Contact
opportunities spent turning are skipped within the original paid duration; no
damage is banked. Adjacent v2 charges preserve target locks and ongoing turns.

The native profile observes packets and opener payments, rear-only crown fire,
facade retention/loss/reacquisition, range/arc escape, diplomacy, target removal,
exhaustion, moving fire, normal robot cold loading and rare robot replenishment.
It retains native control, fixture obstacle paths, mining/rebuilding, quality,
equipment, logistics and blueprint ghosts. `voice_qc.lua` checks audio-helper
lifetime; `coverage_qc.lua` adds fleet fairness and raised-teleport sample reset.

## Replay commands

The tracking regression uses real low-health enemies, native moving targets and
continuous per-tick observations. Its optional graphics profile captures 435
frames, with day/night requests on separate ticks and actual surface darkness.
It checks lethal-hit visibility, retained locks, smooth angular replacement and
native movement under attack. Pixel comparisons separately require visible
moving strands and their disappearance after stopping.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 -Regression -RunName tracking-native
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 -Regression -Visual -RunName tracking-art -Fidelity standard
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 -Regression -Visual -RunName tracking-off -Fidelity off
python -B scripts/qc/anisetron/measure_trail_pixels.py --enabled .factorio-qc/anisetron/tracking-art/script-output --off .factorio-qc/anisetron/tracking-off/script-output --output output/anisetron-trails.json
```

The [mobility regression](../anisetron-mobility/README.md) independently exercises
the 50% native modifier safeguard under mixed enemy slows, including genuine
manual movement, turns, original damage, saved active slows and cleanup.

Run from the repository root. Omit `-AssetRoot` to test shipping sprites and their
lookup; that option exists for separately reviewed drafts. Use fresh run names.

```powershell
$runner='scripts/invoke-anisetron-qc.ps1'
powershell -ExecutionPolicy Bypass -File $runner -DumpOnly -RunName anisetron-data
python -B scripts/qc/anisetron/inspect_data.py --dump .factorio-qc/anisetron/anisetron-data/script-output/data-raw-dump.json --output output/anisetron-final-data.json
python -B scripts/qc/anisetron/inspect_final_extras.py --dump .factorio-qc/anisetron/anisetron-data/script-output/data-raw-dump.json --output output/anisetron-art-audio-data.json

foreach($tier in 'off','lean','standard','cinematic','maximal','unbounded'){
    powershell -ExecutionPolicy Bypass -File $runner -RunName "anisetron-$tier" -Fidelity $tier
}
$reports='off','lean','standard','cinematic','maximal','unbounded' | ForEach-Object { ".factorio-qc/anisetron/anisetron-$_/script-output/anisetron-qc.json" }
python -B scripts/qc/anisetron/compare_fidelity.py @reports --output output/anisetron-fidelity.json
powershell -ExecutionPolicy Bypass -File $runner -Timing -RunName anisetron-timing

powershell -ExecutionPolicy Bypass -File $runner -Save -RunName anisetron-paid-save
powershell -ExecutionPolicy Bypass -File $runner -Resume -Fidelity off -RunName anisetron-paid-replay -SaveInput .factorio-qc/anisetron/anisetron-paid-save/saves/anisetron-transition.zip
powershell -ExecutionPolicy Bypass -File $runner -Save -Legacy -RunName anisetron-legacy-save
powershell -ExecutionPolicy Bypass -File $runner -Resume -Legacy -Fidelity off -RunName anisetron-legacy-replay -SaveInput .factorio-qc/anisetron/anisetron-legacy-save/saves/anisetron-transition.zip
powershell -ExecutionPolicy Bypass -File $runner -Resume -HistoricalLegacy -RunName anisetron-historical-replay -SaveInput .factorio-qc/anisetron/bursts1/saves/anisetron-transition.zip
```

The rare transition saves after 25 contacts per channel. Replay preserves quality,
paid snapshots and deadlines, finishes at 100 per channel, and clears decorations
when startup fidelity changes to Off. The legacy transition saves two genuine
payments, one active/expiring burst and one queued successor. Replay waits from
the loaded tick, permits the historical one-tick FIFO handoff, and requires 200
facade packets, 48000 damage, no v2 packets and complete expiry. The retained
reference16 save separately finishes its original single charge.

The Timing profile observes three native payments over 3700 ticks. It requires
300 contacts per channel, 72000 damage, shared starts exactly 1200 ticks apart,
continuous 12-tick spacing, at most one queued record, and preservation of a
nonempty paid FIFO through a derived-visual rebuild.

## Graphics and presentation

Run only one graphics engine at a time. The wrapper uses short temporary paths
to avoid Windows loader limits, then retains reports in `.factorio-qc/anisetron`.

```powershell
foreach($tier in 'lean','standard','maximal'){
    powershell -ExecutionPolicy Bypass -File $runner -Visual -Fidelity $tier -RunName "anisetron-art-$tier"
}
foreach($channel in 'crown','facade'){
    powershell -ExecutionPolicy Bypass -File $runner -Visual -FullDirections -Isolate $channel -Fidelity off -RunName "anisetron-128-$channel"
}
```

Ordinary captures include eight day/night views, ring-target firing, unmanned
moving/turning/stopping clips, and turn/wrap/frozen poses. The movement actor is
unarmed; moving fire is separately demonstrated by the native combat profile.
FullDirections captures every heading in daylight and at night. Isolation empties
only the other channel's appearance: both paid channels and actual damage remain
active. Alignment compares the thin white centerline to its original crystal,
rather than the asymmetrically colored halo centroid.

The dossier contains packing, raw-alpha clipping, anchor projection, shipping
hashes and preview assembly commands. The 64-versus-128 comparison is a labeled
sprite simulation using alternate frames from the same model, camera and materials.

## Practical limits

These fixtures establish observed obstacle routes, finite queue examples and
fleet service behavior. They do not establish unrestricted flight, multiplayer
or whole-factory UPS. Script rendering cannot read native Spidertron bob; keel
decorations use an empirical speed/lift curve, reported separately from core-beam
muzzle accuracy. Engine runs disable audio, so waveform and helper-lifecycle
checks do not replace an audible mix review. Current measurements and unrelated
repo warnings are recorded in the verification report.

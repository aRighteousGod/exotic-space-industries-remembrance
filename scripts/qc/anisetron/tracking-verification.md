# ANISETRON tracking and movement repair — October 5, 2026

Fresh Factorio **2.0.77 build 84539** evidence for the reported intermittent
beams, unstable targeting, missing movement strands and sustained-movement
stalls. The [preceding integration report](verification.md) remains historical.
No Git commit or push is part of this repair.

## Reproduced causes and resulting behavior

- Lethal damage invalidated a target before its beam was presented. A copied
  impact point now survives for a finite contact display inside the paid deadline.
  Sustained cores omit the transparent opening/ending graphics that repeated
  source-offset recreation could restart during turns.
- Crown cycling, facade endpoint resets and wrapped bearings caused abrupt
  handoffs. Both channels now retain eligible targets, as selected by the user.
  Replacement acquisition uses an unwrapped angular waypoint and smooth turning;
  the crown covers 360 degrees and the facade remains inside its current frontal
  120 degrees. Adjacent paid charges preserve locks and interpolation. Large
  same-target bearing discontinuities reacquire rather than snap.
- Acquisition consumes the existing paid time without banked damage. Stationary
  maximums remain 100 contacts per channel, 160/80 laser every 12 ticks and
  24000 combined normal damage per charge. Original versionless paid records
  keep their historical facade-only damage, payment and deadlines.
- Movement animations were occluded beneath the hull and were too thin. Their
  layer and width now preserve visible filaments. A reusable finite light makes
  them readable at night; its creation shares the existing decoration budget.
  Stopping, teleporting, removal and Off clear the movement effects.
- Mixed enemy slows multiplied until native hover legs stopped advancing.
  Actual standard/Toxic/Cold/Explosive spitter attacks reproduced 4430 consecutive
  stopped ticks while manually driving and 4737 with autopilot. The selected
  ANISETRON-only native modifier floor compensates severe positive slows to
  approximately .20–.25 while retaining original hostile stickers and damage.
  Ordinary movement tuning is unchanged; this is not a per-tick world-speed clamp.

## Fresh acceptance

Run reports are `.factorio-qc/anisetron/<run>/script-output/anisetron-qc.json`.

| Run or artifact | Result |
|---|---|
| `tracking-final-{off,lean,standard,cinematic,maximal,unbounded}` | Off **140/140**, each enabled tier **148/148**; **880/880** total. Manual/automatic fire, control, supply, lifecycle and presentation budgets pass. |
| [Fidelity comparison](../../../output/meshy/anisetron/reference17/tracking-fix/fidelity-final.json) | Exact payment, quality, reserves, target sequences and damage match across all six presets. |
| `tracking-fix-standard-art8` / `tracking-final-off-art` | **47/47** and **46/46** tracking assertions. Real moving enemies, lethal contacts, target retention, angular limits and sustained native movement are sampled each tick. |
| [Beam pixel evidence](../../../output/meshy/anisetron/reference17/tracking-fix/beam-capture-pixel-evidence.json) | **420/420** consecutive captures contain bright core pixels. **748/748** expected channel observations have core pixels in their projected corridor; **652** are independently separable, with **96** overlapping observations recorded as ambiguous. |
| [Day/night movement pixel comparison](../../../output/meshy/anisetron/reference17/tracking-fix/trail-pixel-final.json) | **10/10** matched Standard/Off views pass: four moving day/night pairs and a stopped pair. Actual night darkness is .85. Stopped views have zero extra green pixels. |
| `tracking-fix-timing` | **15/15**: three native payments, 300 contacts/channel, 72000 damage, unchanged cadence and deadlines, and preserved paid FIFO through rebuild. |
| `tracking-fix-old-v2-replay` | **8/8**: authentic pre-fix rare twin-beam save adopts new aim fields without replacing payment or deadlines; completes 38400 damage. |
| `tracking-fix-legacy-replay` | **7/7**: two historical facade-only paid records finish their original 200 packets/48000 damage without a free crown. |
| `stallfix-shipping-native-1` | **27/27**, actual shipping mobility owner with fidelity Off. Every protected case has zero stopped ticks during 6000 attack ticks, including manual driving, turns, armed travel and equipment. |
| `stallfix-shipping-save-2` / `stallfix-shipping-replay-2` | **1/1** and **27/27**. Live slows and compensation survive save/reload; damage, rebuild, removal and natural expiry remain correct. |
| [Fresh final-data inspection](../../../output/meshy/anisetron/reference17/tracking-fix/final-data.json) | Recipes, seven prerequisites, 134-node ancestry, eight stat rows, ammunition, void movement and 21 referenced PNG paths pass against `tracking-final-data2`. |
| [Final art and mobility prototype inspection](../../../output/meshy/anisetron/reference17/tracking-fix/final-art-mobility-data.json) | 128 directions, eight sheets, glow/crest routing, action-free sustained cores, native audio and 36 finite damage-free compensation stickers pass. |

Native poison delivered **59 packets/59 damage** to both compensated cathedral
and Gaian controls. All seven original hostile sticker objects and their remaining
lifetimes survived a mobility rebuild. After expiry, movement modifiers return
to one and the controller retains zero affected records/compensation handles.
The server-save fixture uses unmanned autopilot because its player is disconnected;
the ordinary benchmark separately tests actual manual walking input.

## Visual scope and previews

The [native movement board](../../../output/meshy/anisetron/reference17/tracking-fix/movement-day-night.png)
shows moving/stopped day/night detail at one captured pixel per displayed pixel.

The compact [lethal-target](../../../output/meshy/anisetron/reference17/tracking-fix/lethal-dense-viewing-2x-slow.webp),
[twin-beam](../../../output/meshy/anisetron/reference17/tracking-fix/facade-lethal-dense-viewing-2x-slow.webp),
[walking-target](../../../output/meshy/anisetron/reference17/tracking-fix/tracking-dense-viewing-2x-slow.webp)
and [night-turning](../../../output/meshy/anisetron/reference17/tracking-fix/turning-dense-viewing-2x-slow.webp)
loops retain native 768-square framing and use explicitly **2× slow motion**.
Each viewing copy is below 10 MB. Lossless masters decode exactly to the original
screenshots; viewing copies use WebP quality 82. No brightness, color, intermediate
frame or model changes are baked into the previews.

Beam captures use `tracking-fix-standard-art6`, whose beam runtime/graphics match
the repaired behavior. Later changes add only the moving light. Movement captures
use `art8`; its subsequent center-only light-position stabilisation is exercised
by all six final native runs. These pixel tests establish visible effects and
continuity, not a new all-heading muzzle-alignment measurement. Previous approved
body sheets and attachment tables are unchanged. The inherited 128-heading
alignment report remains historical evidence for those unchanged assets.

The facade is intentionally absent when no eligible frontal enemy exists.
Overlapping beam corridors do not prove separate channels from pixels alone.
Native traces, separate facade lethal fixtures and damage accounting cover that
distinction. Night tests use actual frozen surface time on separate ticks;
the original screenshot-override-only probes were insufficient.

## Repository checks and limits

The [source acceptance snapshot](../../../output/meshy/anisetron/reference17/tracking-fix/source-acceptance.json)
confirms 60 executable-source comparisons against the final six staged native
packs, all eleven approved PNG hashes and the unchanged graphics lookup. The
final dump is 2047412976 bytes with SHA256
`5dd90cb2fac56595c404bde3b4320a85be36a111090146147ffcb819004e241d`.
Forty-one baseline paths remain byte-identical; one concurrent change to the
unrelated scheduler model was observed and left untouched.

Fresh conceptual audit: **46 models, 122 owned sources, zero findings**. Focused
parsers accept **24 Lua files**, **six Python files** and the PowerShell runner.
Preflight passes Lua/Python/PowerShell syntax, conceptual links, requires, locale,
asset paths and versions. Its overall status still fails on the existing unrelated
`scripts/qc/singularity-lance/angular-results.json` encoding finding; existing
Auric/Emerald header warnings remain. No unrelated encoding rewrite was made.

The first full dump failed when concurrent graphics/dump memory pressure exhausted
drive space. It is not acceptance evidence. Redundant graphics copies from sixteen
diagnostic staging packs created during this repair were removed (1162.8 MiB),
retaining scripts, reports, saves and useful captures. The successful final dump
ran separately as `tracking-final-data2`.

These are focused single-player native fixtures, not multiplayer or whole-factory
performance certification. They do not establish unrestricted terrain traversal.
Replay commands and fixture ownership are in [README.md](README.md) and the
[mobility fixture guide](../anisetron-mobility/README.md).

# ANISETRON Lance inheritance and eight-crystal trails

Implementation evidence collected on 2026-10-06 with installed Factorio
**2.0.77, build 84539**. These are current worktree results, not a release,
commit, multiplayer test or whole-factory performance certification.

## Delivered behavior

- One Singularity Lance is required in the existing assembly recipe. Its base
  technology joins the eight retained direct prerequisites, including Laser
  weapons damage 5. Normal ESIR pricing/science propagation remains in charge.
- New paid contracts are version 3: an 85-tile, vehicle-quality-scaled crown and
  a 30-tile frontal facade, with separate eligibility checks. Base damage remains
  320/160 every 12 ticks, 100 opportunities per channel per charge.
- Only the crown inherits Axial Rupture, Wound Memory, Terminal Collapse and
  Black-Hole Testament. Additional coefficients are 0.64 of the Lance's;
  ordinary unupgraded Lance splash is excluded. Ammo quality and laser research
  apply once per applicable packet. Paid snapshots survive research changes.
- Shared internal payload/art factories retain Lance ownership of its targeting,
  payment, persistent state and cadence. ANISETRON retains its native opener,
  smooth hold targeting, current movement, beam attachments and sound.
- Wound memory and Testament phase persist per vehicle. Missed opportunities
  consume phase. Committed collapse/echo positions and deadlines survive source
  removal; unperformed contacts retain their cancellation policy.
- Eight original lower crystal vertices supply heading-dependent strands, with
  lengths of approximately 0.7-1.4 tiles. Movement motes are gone. All eight
  physical roots participate; root and extension occlusion hide strands that
  would cross the hull. No model, material, spritesheet, icon or motion tuning
  was regenerated or replaced in this pass.

## Current engine checks

Paths below are under `.factorio-qc/anisetron/`; runtime reports are normally
`<run>/script-output/anisetron-qc.json`.

| Fixture | Result | Retained run |
|---|---:|---|
| Native controls, combat, real robot supply, equipment/quality/logistics, mining/rebuilding and blueprint preservation | 151/151, repeated after final trail visibility changes | `inheritance-native-verified`, `inheritance-release-check` |
| Paid FIFO timing and nonempty-queue rebuild | 15/15 | `inheritance-timing` |
| Smooth target holds, beam continuity and moving attachments | 47/47 | `inheritance-tracking` |
| Shipping movement, attack/stacked slows and recovery | 28/28 over 12,000 ticks | `inheritance-mobility` |
| Upgrade packets and edge cases, including force merge | 84/84 | `inheritance-final-cinematic`, `inheritance-final-unbounded` |
| Active v3 save replay with fidelity changed to Off | 84/84 | `inheritance-paid-save`, `inheritance-paid-replay` |
| Genuine historical v2 paid save replay | 10/10 | `inheritance-old-v2` |
| Genuine historical versionless/v1 paid save replay | 6/6 | `inheritance-old-v1` |
| Native range matrix: 128 scenarios, three assertions each | **368/384; engine limitation below** | `inheritance-range`, `inheritance-range-probe` |

The exact 12-actor damage/payment ledger matches across **all six fidelity
settings**. Off/Lean/Standard/Maximal runs passed 80 checks; Cinematic/Unbounded
also include the four subsequently added force-merge assertions. The retained
[comparison](../../../.factorio-qc/anisetron/inheritance-work/fidelity-comparison.json)
records the matching ledgers and specific run paths. The Off save replay includes
all 84 assertions. Rendering budgets never determine damage or deadlines.

The Lance's focused mechanical fixture completed before and after extraction:
**798 logged PASS assertions, zero FAIL assertions, ALL_COMPLETE** in each run.
Logs are `.factorio-qc/cu/l/ani-lance-{before,after}/benchmark.log`. Two stale
fixture expectations were corrected against the already-shipping first-hit Wound
behavior before both runs; this was not a Lance damage change.

### Native automatic acquisition boundary

All manual cases pass, including diagonal headings, normal/rare vehicles,
normal/rare ammo and 16-tile targets. Automatic small-target cases and automatic
rare-vehicle large-target cases pass. Eight automatic normal-vehicle large-target
scenarios at diagonal box-distance boundaries never admit the paid opener,
causing 16 failed payment/damage assertions.

A follow-up probe reproduces this with identical relative geometry at `(0,0)`
and `(32,32)`, while translation to `(16,16)` acquires successfully. Cold and
warm placement agree. This is a native spatial-search boundary, preceding
ANISETRON's scripted contact logic. Native manual fire accepts the same range.
The implementation retains native acquisition and payment; it does not fabricate
an opener, widen the mechanical range or label this matrix fully passing.

## Final data and asset inspection

`inheritance-data-final` contains a **fresh focused data-final snapshot from a
successful complete engine load**, not a full `--dump-data` export. Earlier full
dump attempts hit disk exhaustion. The focused snapshot includes all valid
technologies plus the relevant vehicle, gun, ammo, recipe, beam, animation,
sticker and sound-emitter prototypes.

- `final-data-report.json`: passes all nine restored prerequisites, 144-node
  research ancestry, propagated sciences without Quantum/Exotic requirements,
  Lance ingredient, recipe restrictions, void movement power, 85-tile native
  box-distance opener, 30-tile facade readout, ten tooltip fields and matching
  Laser weapons damage 6/7 category effects.
- `final-assets-report.json`: passes all 128 directions and eight sheets,
  at least 16 transparent pixels around every nonempty frame, neutral crest-only
  tint routing, cyan glow, all **42 owned beam variants and nine upgrade cues**,
  referenced artwork, two firing voices, hover sound and 64 damage-free native
  slowdown-compensation prototypes.
- All **11 approved ANISETRON PNG hashes** still match the retained promotion
  manifest. Original crown/facade/first-three-keel projections reproduce within
  0.000001640 tiles; only attachment metadata and runtime effects changed.

## Current visual samples

`inheritance-review-{lean,standard,maximal}/script-output/inheritance-art` contains
actual engine day/night captures at zoom 1. Each tier supplies 39 fire and 39
motion frames in each lighting condition; later tiers also include explicit
rear-crown/front-facade split views. Source captures are not repainted or brightened.

The final representative review inspected 18 images: front movement, the former
wall-crossing turn, stopped vehicles, upgrade effects and split targets. Exposed
front strands remain visible, the previous wall-crossing filament is absent,
and all inspected final stop frames have zero speed and no persistent strands.
Maximal `split-night/001.png` clearly shows rear crown fire and forward facade
fire together. Large Testament artwork can temporarily cover the nearby crown.

Encoded clips, each below 10 MB, are retained in:

| Fidelity | Day trails | Night trails | Day fire | Night fire |
|---|---|---|---|---|
| Lean | [WebP](../../../output/meshy/anisetron/reference17/eight-keel/review-lean/motion-day.webp) | [WebP](../../../output/meshy/anisetron/reference17/eight-keel/review-lean/motion-night.webp) | [WebP](../../../output/meshy/anisetron/reference17/eight-keel/review-lean/fire-day.webp) | [WebP](../../../output/meshy/anisetron/reference17/eight-keel/review-lean/fire-night.webp) |
| Standard | [WebP](../../../output/meshy/anisetron/reference17/eight-keel/review-standard/motion-day.webp) | [WebP](../../../output/meshy/anisetron/reference17/eight-keel/review-standard/motion-night.webp) | [WebP](../../../output/meshy/anisetron/reference17/eight-keel/review-standard/fire-day.webp) | [WebP](../../../output/meshy/anisetron/reference17/eight-keel/review-standard/fire-night.webp) |
| Maximal | [WebP](../../../output/meshy/anisetron/reference17/eight-keel/review-maximal/motion-day.webp) | [WebP](../../../output/meshy/anisetron/reference17/eight-keel/review-maximal/motion-night.webp) | [WebP](../../../output/meshy/anisetron/reference17/eight-keel/review-maximal/fire-day.webp) | [WebP](../../../output/meshy/anisetron/reference17/eight-keel/review-maximal/fire-night.webp) |

This is representative visual review, not a new two-pixel muzzle certificate for
every heading, a continuous-frame audit or an unrestricted-flight claim.

## Repository checks and preservation

Doctor and the installed 2.0.77 API check pass. The conceptual-link audit passes
with 125 owned sources and zero findings. Preflight's Lua/PowerShell syntax,
requires, locale, asset references and pack-version checks pass.

The complete preflight is **not green**: Python bytecode cache writes hit protected
paths/Windows path-length limits; two unrelated existing encoding findings and
two unrelated module-header warnings remain. A separate in-memory compile of
all **154 current Python sources passes**, without writing bytecode. Reports are
under `inheritance-work/preflight-final.json` and `python-syntax-memory.json`.

The starting 1,472-file hash checkpoint has no missing files. Thirty-one existing
files changed, all within the reviewed implementation, fixtures and paired
documentation; the other 1,441 sampled files remain unchanged. New files and
new generated evidence are recorded separately. Git staging, commit and push
were not performed.

## Requested QC cleanup

Approximately **16.37 GiB** of old allocated storage was reclaimed:

- Four superseded single-link prototype dumps: 8,189,411,328 allocated bytes.
- 2,877 byte-identical staged PNG copies replaced atomically by hardlinks to
  the existing immutable QC cache: 9,388,011,520 allocated bytes.

Every replaced staged path remains present and matches its cache file identity.
All 15 corresponding shipping source hashes are unchanged and independent from
the cache. Retained dumps, historical saves, dependency seeds, screenshots,
reports and source art were preserved. New ANISETRON runs use the same cache to
avoid accumulating another complete artwork copy per run.

[Cleanup reconciliation](../../../.factorio-qc/anisetron/inheritance-work/cleanup-summary.json)
records 17,577,422,848 released bytes, including the recovered first-pass 31-path
batch and the 2,846-path manifest. This measures released old allocations, before
small manifest overhead and concurrent QC output growth; apparent folder size
can still count the same hardlinked bytes more than once.

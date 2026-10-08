# ANISETRON 17 initial integration verification - October 5, 2026

This is the preceding integration snapshot. The subsequent targeting, beam
visibility, movement-effects and compounded-slowing repair is documented in
[tracking-verification.md](tracking-verification.md). Its fresh results supersede
the clockwise targeting and presentation claims below. These original fixtures
did not expose the live-enemy and compounded-slowing regressions.

Current checkout, Factorio **2.0.77 build 84539**, shipping Meshy17 sprites and
twin-beam sources. Reference16 and draft results are historical only. No new
Meshy generation, Git commit or push was performed.

[Final acceptance snapshot](../../../output/meshy/anisetron/reference17/final-acceptance.json)
confirms all 60 critical source comparisons against the six staged native packs,
eleven promoted PNG hashes and 21 unrelated baseline paths unchanged.

## Current acceptance evidence

| Evidence | Result |
|---|---|
| `final17-data/script-output/data-raw-dump.json` | Fresh final data, 2,047,382,257 bytes; SHA256 `25fe567436b0b8efde171d518979bdb7d464d7d0ae316a6083190b940ab96530`. |
| [Final-data inspection](../../../output/meshy/anisetron/reference17/final-data-inspection.json) | Prototypes, recipes, unlocks, eight stat rows, seven restored prerequisites, 134-node ancestry, void movement, grid/inventories and 23 PNG references pass. Runtime hashes refreshed against final source. |
| [Art/audio final-data inspection](../../../output/meshy/anisetron/reference17/final-data-art-audio.json) | 128 directions, eight split sheets, controlled glow, neutral crest, action-free core effects, two voice helpers, differentiated hover hum and shipped audio paths pass. |
| `final17-{off,lean,standard,cinematic,maximal,unbounded}-3` | Off **137/137**; each enabled tier **145/145**. **862/862** assertions across six complete native runs. |
| [Fidelity comparison](../../../output/meshy/anisetron/reference17/fidelity-mechanics-final.json) | Exact normalized payment, quality, reserves, packet counts/damage and target sequences match across all six tiers. |
| `final17-timing` | **15/15**; three genuine payments, 300 contacts/channel, 72000 damage, continuous 12-tick cadence, 1200-tick starts and preserved nonempty paid FIFO through visual rebuild. |
| `final17-paid-save` / `final17-paid-off-replay` | **3/3** and **8/8**. Rare burst saves at 25 contacts/channel; Off replay preserves quality/deadlines and completes 100/channel, 38400 damage, one payment. |
| `final17-legacy-save` / `final17-legacy-off-replay4` | **3/3** and **7/7**. Two native-paid versionless records finish 200 original facade packets, 48000 damage, no crown/v2 packets and no remaining owner. |
| `final17-historical-replay2` | **6/6**. Actual retained reference16 save finishes 100 original packets/24000 damage; saved 25 contacts and newly observed 75-contact tail are accounted separately. |
| `final17-{lean,standard,maximal}-art2` | **12/12** each, **36/36** total; fresh shipping-art day/night, twin-fire, unmanned movement, turning and stopped views. |
| `v2-full128-facade` / `v2-full128-crown2` | **13/13** each; isolated all-heading day/night plus turn/wrap/frozen captures use the byte-identical final sheets. |
| [Core alignment](../../../output/meshy/anisetron/reference17/review-delivery/qc/full128-twin-core-alignment.json) | **624/624** within two pixels: crown maximum **1.804597 px**, facade **1.240238 px**. White-threshold and weighted white-core fits both pass. |
| [Raw render QC](../../../output/meshy/anisetron/reference17/prepared-v2/full128-qc.json) / [packing integrity](../../../output/meshy/anisetron/reference17/prepared-v2/factorio-full128/package-integrity-qc.json) | All 512 frames unclipped; body/glow/shadow margins 82/82/60 px. All 512 packed RGBA cells and 640 projected anchors match. |
| [Shipping hashes](../../../output/meshy/anisetron/reference17/shipping-hashes.json) / [review integrity](../../../output/meshy/anisetron/reference17/review-delivery/review-integrity.json) | Eleven PNGs match the reviewed package; 515 preview source hashes and 19 artifacts pass integrity checks. |

Run reports live at `.factorio-qc/anisetron/<run>/script-output/anisetron-qc.json`.
The final data path in the table has that same run-directory prefix. Art retains
the original geometry/UV/PBR network, approved 0.65 original-albedo emission,
native hover 1.8 applied once and a separately raised shadow caster. The crest is
naturally occluded in 36/128 headings.

## Playable behavior demonstrated

One native normal charge prepays both channels for 1200 ticks. The crown delivers
160 laser every 12 ticks and cycles clockwise through enemies around the craft;
the facade holds an eligible enemy in its current 120-degree frontal cone and
delivers 80. Both have 30-tile range. Maximum damage is 16000 plus 8000; unused
channel damage is not transferred. Ammo quality affects both allocations and
the adjustable duration-quality hook remains zero.

Fresh tests cover manual/automatic fire, rear-only crown acquisition, facade
lock loss/reacquisition, range/arc escape, death/removal, diplomacy, collinear
tie-breaking, moving fire, exhaustion and source force/surface removal. Real
robots cold-load normal ammo and replenish matching rare ammo; native firing
resumes. Source cancellation does not refund a charge. Visual beam crossings
deliver no packets.

Travel measures **46.8%** of the saucer without equipment and **49.9%** with one
normal exoskeleton and charged battery each. Torso turning measures 0.05 versus
0.10. Remote selection/autopilot complete the water, cliff, factory-obstacle and
elevated-rail routes. Player/robot mining and rebuilding preserve tested vehicle
and equipment quality, equipment position/charge, labels/color, requests and
blueprint equipment ghosts. Cargo/ammo accounting includes returned inventories.

Fidelity tests cover caps, three strands, finite lifetimes, Off cleanup, finite
unique Unbounded visits, FIFO service beyond Lean's fleet cap, unmanned motion,
stopped/torso-only suppression, rebuild and raised-teleport sample reset without
paid changes. Native voices survive heading-based beam replacement, return after
rebuild and clean up at target loss, expiry, deletion and force/surface changes.
The engine refuses native helper cloning; the fixture verifies no surviving
copy. Build/clone cleanup remains defensive.

Recipes and progression are retained. Both recipes unlock from `ei-anisetron`.
Seven sciences include advanced-computer and space science; ESIR pricing is count
10, time 30. No Quantum, Exotic or Lance gate appears in the 134-node ancestry.
Assembly consumes an empty saucer and creates a fresh cathedral at gravity 15.5;
the recipe does not transfer a configured vehicle.

## Presentation, limits and repository checks

The review bundle contains six 24-frame day/night firing/movement GIFs, matched
Lean/Standard/Maximal boards, native detail crops and a labeled 64-versus-128
sprite simulation. The movement actor is unarmed; moving fire has separate
native combat proof. Dark architecture is subdued at night while crystals and
chromatic cores remain readable.

Core measurements concern perpendicular white-centerline displacement. Texture
taper/occlusion limit longitudinal endpoint inference. Native beams inherit bob;
script rendering cannot read it. Keel decoration uses an empirical speed/lift
curve, with **3.160 px inferred maximum** error in the current Standard motion
capture. Five stopped samples have zero strands. This approximation is separate
from the two-pixel core result.

The 3.2-second Lance-derived Ogg loop passes offline waveform continuity and
clipping checks; native helper lifecycle is tested. Fixtures disable audio, so
audible engine mix review remains an artist listening task. Focused routes/fleet
examples do not establish unrestricted flight, multiplayer or whole-factory UPS.

Repository doctor and installed-doc checks passed. Preflight passes conceptual
links, Lua/Python/PowerShell syntax, requires, locale, asset references and version
consistency. Conceptual audit covers 46 models and 120 owned sources with zero
findings. Generic asset validation is **ok**, with zero errors/warnings/findings.
Wrapper-wide status still fails only on pre-existing mojibake in
`scripts/qc/singularity-lance/angular-results.json`; unrelated Auric/Emerald
header warnings remain. Sandbox cache issues were resolved with normal authorized
validation permissions.

The corrected legacy fixture uses a distinct loaded clock and permits the
legitimate expiring-active/queued transition. Failed initial probes remain
diagnostics; the final pass is `final17-legacy-off-replay4`. Historical per-channel
observations are not fabricated. These fixture fixes required no gameplay change.

Use [README.md](README.md) for exact replay commands and the
[reference17 dossier](../../../.codex/esir/asset-generators/anisetron/reference17/README.md)
for source hashes, transforms and art/audio generators. Scenes, raw frames,
reports and engine captures remain in ignored staging.

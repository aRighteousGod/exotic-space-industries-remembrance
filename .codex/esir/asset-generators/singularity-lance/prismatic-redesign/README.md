# Singularity Lance: Prismatic Liturgy

Production integration: 2026-09-28, following approval of the staged direction.
The original native prismatic base shot is restored. Axial and Testament use
new segmented native beams; Wound uses target-followed animation; Collapse and
Testament have timed warning/impact sheets. Technology emblems retain the original
rendered mineral and etched jade base with separate phenomenon overlays.

## Production replay

From the repository root, with NumPy and Pillow:

```powershell
python -B .codex/esir/asset-generators/singularity-lance/prismatic-redesign/production.py
python -B .codex/esir/asset-generators/singularity-lance/prismatic-redesign/validate_production.py
```

The generator imports the approved study generator beside it and writes only to
`output/meshy/lance-prismatic-liturgy/production/`. Its `factorio-export/` contains
36 shipping PNGs: 28 animation layers and eight mineral/phenomenon icon layers.
Promotion copies those files to the main pack's
`graphics/singularity-lance-upgrades/prismatic-liturgy/`. No companion graphics
pack was changed, so no companion version/dependency change is needed.

After promotion, `validate_production.py --shipping` compares every shipped PNG
byte-for-byte with the staged export. Source and output are deliberately separate.
`production-board.png` includes actual tiled bodies and icons at 256/64/32 pixels;
`production-motion.webp` shows actual production frames; `manifest.json` records
dimensions, frame counts, layer hashes and the raw atlas budget.

| Family | Frame contract | Playback |
| --- | --- | --- |
| Axial/Testament body | 256 x 96, 16 frames, 4 columns | Native segments; 0.55 frames/tick |
| Axial/Testament head/tail | 192 x 160, 16 frames, 4 columns | Finite caps; same phase/speed |
| Wound bands | 192 x 192, 24 frames, 6 columns | 0.4 frames/tick; two-tile canvas |
| Optional Wound crown | 192 x 192, 12 frames, 6 columns | Twelve ticks at band transitions |
| Warning | 256 x 256, 30 frames, 6 columns | Exactly thirty ticks |
| Impact | 256 x 256, 12 frames, 6 columns | Contact on first frame, twelve ticks |

The warning's first circumference is at 0.775 of the half-frame radius: 99.2 pixels.
The prototype scale is `3 * 32 / 99.2`; runtime multiplies by `packet.radius / 3`.
Thus the first ring marks the actual radius; decorative tails may extend beyond it.
The visual contract is recorded in `lib/singularity-lance-config.lua`.

There are 264 animation frames. All animated layers together occupy 86.625 MiB
as unpacked RGBA, or 43.3125 MiB for semantic layers alone; the eight icon layers
add 2 MiB. These are source-atlas totals, not measured GPU allocations. Engine
padding/mips may add overhead. Lean omits glow references while retaining animation,
color flow, fracture bands, warnings and opaque void silhouettes.

Body alpha intentionally reaches the horizontal frame edges. Validation checks
matching first/last columns and wrapped glow instead of treating those edges as
clipping. Caps and other finite cues are checked on all four edges. Periodic motion
is tested at phases zero and two pi. Source notes from the initial study follow.

## Runtime integration and migration

Runtime schema stays at 11; independent presentation revision 2 destroys saved
Sprite beam/mark handles and restores valid wounds with only their remaining TTL.
Counters, wound timestamps, paid collapse buckets and due ticks are preserved.
The warning animation names/frame counts/speed stay compatible, so saved warnings
retain their phase. Legacy Sprite prototypes are retained for saved handles only;
new shots exclusively use the replacement artwork.

Native beams are cosmetic (`action=nil`) and use fixed computed shot endpoints.
Identical live beams are reused on firing events; expired or changed geometry is
replaced. Native beam TTL cannot be refreshed. Testament holds its silhouette for
up to twelve ticks when following ordinary shots share the geometry; retargeting
interrupts that hold. Damage and paid-shot counting do not follow the visual hold.
No tracking loop, particle entity stream or new scheduler was added.

Wound crowns are optional bounded decoration and are profiled separately from core
cues. The existing post-damage entity/diplomacy guard remains at Wound presentation.
See `scripts/qc/singularity-lance/prismatic-liturgy-verification.md` for current
engine checks and benchmark evidence. Gameplay appearance remains a manual review.

## Initial study archive

Staged art-direction pass, 2026-09-27. This is a response to the upgrade set losing
the original lance's saturated prismatic patterning, animation and tails. It does
not replace shipping graphics, prototypes, runtime state or research.

## Replay

From the repository root, with NumPy and Pillow:

```powershell
python .codex/esir/asset-generators/singularity-lance/prismatic-redesign/generate.py
python -B .codex/esir/asset-generators/singularity-lance/prismatic-redesign/validate.py
```

Output: `output/meshy/lance-prismatic-liturgy/`.

- `index.html`: local animated gallery, speed/scrub controls, three ground colors,
  and a glow toggle. Open locally in a browser; no server or network is needed.
- `direction-board.png`: selected actual frames and four emblem compositions.
- `motion-study.webp`: animated overview slowed for art review, not gameplay timing.
- `timing-strip.png`: sampled warning/impact frames, including the contact flash.
- `factorio-export/`: draft transparent semantic/glow sheets and separate mineral/
  phenomenon icon layers. These are not production prototype contracts.
- `manifest.json`: exact draft dimensions, frame counts and layer roles.
- `qa.json`: per-frame edge, alpha, animation diversity and loop checks.

## Reference family

The palette is the existing `spectral_color()` family from:

- `../prismatic-beam/generate_prismatic_beam.py`
- `../chromatic-afterburn/generate_chromatic_afterburn.py`
- `../crystal-link/generate_crystal_link.py`

Cool ribbon: cyan `#00E1FF` to cobalt `#584DFF`. Opposing ribbon: magenta `#FF1CC0`
to violet `#A03FFF`. Hot seam: orange `#FF7014`, gold `#FFE83A`, warm white `#FFFFF6`.
White is a small, concentrated highlight. Most of the visible material is colored.

Icon studies reuse the original rendered blue crystal and emerald-etched jade body
from `exotic-space-industries-remembrance-graphics-4/graphics/techs/singularity-lance.png`.
This extends the editable procedural/icon family; no AI-generated raster source,
Meshy credits, or Blender machine rerender is involved in this study.

## Recommended visual direction

**Prismatic Liturgy** treats the spectrum as one luminous material undergoing four
successive acts: cut, remember, gather, consume. Saturated color flows through the
surface; warm highlights travel with it, and fine tails retain its direction.

| Upgrade | Primary reading | Motion and material |
| --- | --- | --- |
| Axial Rupture | Precise hot axis and two cyan incision banks | The original opposing ribbons are drawn taut. Traveling caustics and gold knots run along the ray; thin chromatic streamers taper behind them. The endpoint pinches to a needle. |
| Wound Memory | Split, branching tear, broken halo | Color circulates along a stable readable fracture. The first band has two lips; the second grows side branches; the fifth stack adds an interrupted spectral halo. A brief crown pulse marks stronger bands. |
| Terminal Collapse | Contracting circumference at the original aim point | A few long comet tails spiral inward. At the end of the 30-tick warning they become a gold-white knot, followed by a short prismatic petal flash on contact. |
| Black-Hole Testament | Dark beam channel, dark disk, bright annulus, terminal cross | Broad cyan/magenta banks flow around negative space. Accretion tails appear to fall behind the void. The white-gold cross peaks briefly, then leaves colored tails. |

Wound animation should be calmer than the beam. Collapse accelerates inward instead
of merely shrinking at uniform speed. Testament should gain breadth and contrast,
with a distinct opaque aperture, rather than becoming a washed-out white blast.

The staged studies establish palette, motion and silhouette. Final polish should
add uneven filament breakup, a small number of coherent baked motes, a more natural
branch endpoint taper, and refined icon mineral silhouettes. Icon effects remain
separate from their rendered mineral underlays.

## Alternative directions

**Cathedral of Refraction:** stronger faceting and etched architecture. Axial slices
moving crystal planes; Wound breaks into facets; Collapse folds prisms inward;
Testament becomes a shattered rose window around a void. Excellent icon continuity
and strong silhouettes, but less fluid than the original beam. Borrow its material
detail for the recommended direction rather than replacing the flowing plasma.

**Accretion Calligraphy:** broad spectral strokes, hooked comet tails and tightening
loops. Wound is a living signature; Collapse coils into a knot; Testament becomes
a dark seal with luminous orbital script. The most fluid and uncanny alternative,
but large strokes need restraint in dense combat. Borrow its tails for Collapse
and Testament while keeping the incision and wound silhouettes explicit.

## Production integration plan

1. Restore the original base shot's animated prismatic identity. Extend its native
   segmented cosmetic beam helper with Axial and Testament body/head/tail sheets.
   Native segmentation keeps the pattern density and tail size consistent over
   long shots; stretching one short image over the full range does not.
2. Keep all cosmetic beams damage-free and use the already-computed shot positions.
   Coalesce identical shape/geometry on firing events so animation is not repeatedly
   reset to frame zero. Replace on geometry changes or expiry. Keep one per lance.
3. Use target-attached native rendering animations for Wound. Keep one mark per
   lance and the existing positive-hit TTL/reset semantics and validity guard.
4. Preserve 30-tick warnings and the authoritative contact tick. Core silhouette
   and saturated material belong in Lean too. Extra glow and baked detail are
   optional; no particles or Lua tracking loop are needed for the tails.
5. Evaluate a brief same-geometry visual hold for Testament under rapid firing.
   Otherwise the next ordinary shot can replace its beam after only one tick.
   Paid-shot counting and damage must remain untouched.
6. Migrate presentation in place. Do not naively increment the current runtime
   version: its generic legacy path would discard upgrade meters and paid collapse
   buckets. Destroy/replace old Sprite handles, retain mechanical state, and restore
   active marks with their remaining lifetime. Preserve counter-seven reload and
   paid source-removed collapses.
7. Update the artwork legend and any changed visual wording, preserving native JA
   terminology. Run asset checks and relevant mechanical/migration regression tests.
   Gameplay visual acceptance remains manual, as the user requested earlier.

The earlier dense UPS objective was not met. This visual revision must not hide that
fact or add per-tick Lua work. Baked animation exchanges atlas/GPU resources for
motion; final sheet sizes and fidelity layers require an explicit memory budget.

## Acceptance still required

Review native scale, day/night and Lean/Standard; long diagonal beams and quality
range; moving targets/worms/spawners; all three Wound bands; collapse timing; eighth
shots during rapid fire; the dense 96-lance scene; and emblems at 64/32 pixels.
The browser gallery is a design aid, not a captured Factorio acceptance fixture.

## Checks completed for this study

All nine sequences have the expected dimensions and 244 distinct animation frames
in total. Semantic and glow sheets have no visible-alpha clipping at frame edges.
The five looping beam/wound sequences meet at their endpoints within one 8-bit
channel value. The 64-frame animated overview decodes correctly. The gallery's
JavaScript passes a V8 syntax check. The direction board and timing strips were
visually inspected, including the revised mineral emblem compositions.

No browser was available in the review environment, so gallery controls and browser
appearance have not been interactively verified. No shipping files changed and no
Factorio run or UPS measurement was performed for these staged studies.

# Prismatic Liturgy integration — 2026-09-28

The approved art direction is now wired into the Factorio 2.0.77 main pack.
This is a presentation revision of the existing four-upgrade lance implementation;
damage, research progression, native targeting, power payment and protection rules
remain unchanged. No extinguisher implementation files were edited.

## Delivered presentation

- Restored the original segmented, animated prismatic base beam.
- New Axial and Testament native body/head/tail sheets, with spatially periodic
  bodies and cap direction inherited from the original generator.
- Three animated Wound bands, engine-followed targets and positive-hit TTL renewal;
  optional bounded crown pulses are counted/profiled as decoration.
- Thirty-frame inward warning animations and twelve-frame contact animations;
  Testament retains an opaque dark aperture and terminal cross.
- Four layered crystal/jade technology emblems, used directly by Informatron.
- Visual legend and fidelity wording synchronized across en/fr/ja/pl/ru/zh-CN/zh-TW.
  Mechanical tooltip parameters continue to come from the shared lance config.

The main pack contains 36 new PNGs (13,973,999 compressed bytes). The 264 animation
frames occupy 86.625 MiB as uncompressed RGBA; icon layers add 2 MiB. Lean references
semantic layers without optional glow (43.3125 MiB animation + 2 MiB icons). Engine
atlas padding and mipmaps are outside these source-pixel totals.

Source/replay dossier:
[Prismatic Liturgy generators](../../../.codex/esir/asset-generators/singularity-lance/prismatic-redesign/README.md).
Generated review artifacts live in ignored
`output/meshy/lance-prismatic-liturgy/production/`:
`production-board.png`, `production-motion.webp`, `manifest.json`, and `qa.json`.

## Save and runtime behavior

Mechanical schema remains 11. Independent presentation revision 2 replaces old
Sprite handles and restores unexpired Wound marks with only their remaining TTL.
Counters, stacks, wound timestamps, paid collapse buckets and due ticks survive.
Existing warning Animation objects retain their phase through the compatible
name/frame-count/speed contract. No companion pack/dependency version changes are
needed: all new assets ship in the main pack.

Each lance holds one native core beam and one core Wound animation. Identical live
beam geometry is reused on shot events; changed or expired beams are replaced.
Native beams cannot refresh TTL, so a late same-geometry shot may share only the
remaining life of an existing cue. Testament retains a brief same-geometry hold;
retargeting replaces it immediately. This hold never changes mechanical damage.
The post-damage LuaEntity validity guard remains in place. No tracking or idle loop
was added. Old Sprite prototypes remain solely to load/migrate saved handles.

## Validation

| Check | Result |
| --- | --- |
| Final preflight | Passed with existing unrelated runtime-header warnings |
| `qc-fast` / final data dump | Engine success, zero errors; 69 existing dependency/settings/data warnings |
| `qc-assets` | Clean success |
| Lean mechanics | 146 assertions passed |
| Standard mechanics | 146 assertions passed |
| Cinematic / Maximal / Unbounded mechanics | 144 assertions each passed |
| Save made with old artwork, reloaded into new code | 6 assertions passed |
| Production raster validation | All 264 frames, body seams, finite edges, periodic loops, native cap direction and layered icons passed |
| Shipping comparison | All 36 PNGs match staged output byte-for-byte |
| Seven-language locale check | Owned keys, duplicates, UTF-8 and localized parameters passed |
| Final `data.raw` checks | Cosmetic beam actions absent; animation contracts and layered icons correct |

Runtime coverage includes unchanged damage/friendliness fixtures, source/target
destruction during synchronous damage callbacks, positive/zero-damage Wound rules,
all three animated bands, entity-followed marks, native beam reuse/replacement,
Testament hold with ordinary damage, geometry/range/quality boundaries, and delayed
packet lifecycle. The dedicated presentation migration test preserves counter seven,
full Wound stacks and seven paid collapses, then resolves the eighth separately.
Actual old-save reload confirms configuration migration, animated mark replacement,
seven outstanding packets, and the eighth shot's 1,500 damage.

The broad harness initially encountered protected Python bytecode-cache writes and
an obsolete standalone extinguisher in its implicit cache selection. Final runs
used a writable extended-path Python cache and an explicit QC-only mod list matching
the tested dependency profile. Those fixes affect ignored test caches, not installed
mods or extinguisher source. No product failure was suppressed.

Final data was read from
`.factorio-qc/fmqc/fast-run-data-20260928-060858/script-output/data-raw-dump.json`.
The focused extraction is under `output/lance-prismatic-redesign/final-prototypes.json`.

## Matched performance measurements

Both sides contain the same four-upgrade mechanics. The baseline is this checkout
immediately before the artwork/runtime-presentation edits, using stretched Sprite
beams; the result uses native segmented beams and animated Wounds. Each row has one
discarded full warmup run and five measured runs. Direct uses 900 ticks/run; the
96-lance scenes use 600 ticks/run. Detailed counters are disabled for these runs.
These are whole-game update means from headless Factorio; they do not measure GPU
cost. Background development/QC activity was not controlled.

| Scene | Before median (min–max), ms | After median (min–max), ms | Median change |
| --- | --- | --- | --- |
| One lance, direct-only artificial firing | 0.435 (0.431–0.448) | 0.430 (0.424–0.437) | −1.1% |
| 96 lances, native normal power | 2.007 (1.977–2.384) | 2.153 (2.127–2.233) | +7.3% |
| 96 lances, artificial dense firing | 55.704 (49.708–59.867) | 52.017 (50.885–54.314) | −6.6% |

Direct-only is within the 5% investigation threshold. All paired run ranges overlap.
The normal-power median rose; this evidence does not establish a universal speedup
or rule out a smaller regression. Dense results remain dominated by the unchanged
independent paid damage packets and synchronous engine/mod work they invoke.

Separate opt-in profiling discarded ticks 0–119 and measured 120–599. Profiler
overhead is included. Shot-core is contained within shot; impact-core and most
decoration are contained within delayed update. Do not add these nested rows.

| Phase | Normal power mean / p95, ms | Dense mean / p95, ms |
| --- | --- | --- |
| Whole shot callback | 0.876 / 1.913 | 23.484 / 39.512 |
| Shot core cues | 0.082 / 0.201 | 1.859 / 2.734 |
| Delayed mechanics | 0.674 / 1.550 | 24.138 / 37.314 |
| Impact core cues | 0.011 / 0.033 | 0.395 / 0.777 |
| Decoration, including crowns | 0.007 / 0.017 | 0.171 / 0.364 |
| Whole delayed update | 0.699 / 1.643 | 24.994 / 39.153 |
| All lance script work | 1.575 / 17.777 | 48.477 / 71.295 |

**The pre-existing 1 ms p95 dense objective remains unmet.** No paid packet was
merged or dropped for this art revision. Normal-power fire is bursty; its mean is
not a substitute for p95. The figures above do not establish graphical acceptance.

## Reproduction and evidence

Use `scripts/invoke-singularity-lance-qc.ps1 -CurrentSource` with a fresh `-RunName`.
This ensures new main-pack graphics are included; the older frozen-overlay path
can point at pre-art graphics. The current evidence folders under `.factorio-qc/cu/l/`
are `liturgy-final-<fidelity>`, `liturgy-old-save`, `liturgy-reload-verified`,
`liturgy-before-direct`, `liturgy-before2-<normal-power|dense>`,
`liturgy-after-<scene>` and `liturgy-profile-<normal-power|dense>`.
The cleaned pre-art source snapshot is `.factorio-qc/liturgy/baseline-source`.

`analyze-prismatic.py` collects run samples, tested source hashes, runtime assertions,
locale validation and optional final-data checks. Curated results are retained in
[prismatic-liturgy-results.json](prismatic-liturgy-results.json); raw logs remain in
ignored QC folders. The existing original upgrade verification report is unchanged.

## Manual graphical acceptance

No isolated graphical fixture was run, as requested. Confirm in actual gameplay:

- Normal zoom, day/night and Lean/Standard: saturated motion and core silhouettes
  remain clear; Lean still has incision, Wound bands, contraction and dark apertures.
- Short/long and diagonal shots, including quality range: natural beam cap joins,
  correct endpoint, consistent pattern density, no clipping or obvious tile seams.
- Moving units, worms and spawners: stable attached Wound animation; distinct split,
  branch and broken-halo bands; correct retarget/expiry behavior.
- Collapse: fixed aim point, inward contraction over half a second, contact flash
  on impact; the initial circumference matches the intended area.
- Eighth shots during rapid firing: dark seam, broad colored banks, opaque disk,
  bright annulus and cross remain recognizable.
- Dense 96-lance combat: acceptable visual/GPU load, controlled bloom and tails.
- Technology/Factoriopedia/Informatron: readable emblems at 64/32px, correct visual
  legend, no missing sprites or locale placeholders.

## Follow-up: crystal muzzle, impact bloom and terrain lighting

The visual source again uses the original crystal-eye offset `{0, -3.35}`;
mechanical range, penetration geometry and beam endpoints are unchanged. Base,
Axial and Testament beams retain the original 24-frame prismatic impact bloom.
The unsupported beam `light` field is replaced by native `draw_as_light` ground
masks, with strength and size derived from the existing fidelity profile. This
adds no runtime light objects or polling and reuses existing shipped artwork.

Factorio 2.0.77 passed 242 runtime assertions each in Lean and Standard, including
96 new engine endpoint checks covering all three beam variants in eight directions
at a translated, grid-snapped turret position. Final-data assertions verify the
impact animation and all three terrain-light masks on four beam prototypes.
`qc-assets` passed cleanly. Evidence is in `.factorio-qc/cu/l/lance-cues-<fidelity>`
and `.factorio-qc/lance-cues-assets.log`. The benchmarks above predate this follow-up;
night-time light spill, endpoint bloom strength and GPU cost remain manual checks.

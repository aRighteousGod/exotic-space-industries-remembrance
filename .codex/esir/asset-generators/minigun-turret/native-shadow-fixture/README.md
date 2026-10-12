# Native minigun shadow-union fixture

This separate Factorio 2.0.77 fixture compares real decomposed shadow masks
with an independently packed all-caster Shadow reference. It does not change
the ordinary color fixture, shipping sprites, or production turret prototypes.
Stage and engine Run are separate operations; the main task owns both.

<a id="contract"></a>
## Inputs and ownership

`-ShadowCandidatesPath` identifies `esir.minigun.shadow-candidates.v1`
metadata. Each `profiles.sd/hd` contains `leaves.{base,upper,shadow}` and
corresponding `families` crop/packing records. Here `shadow` means the dynamic
rotor residual, containing 28 physical frames per direction. Base and upper
have one physical frame. All leaves must have `draw_as_shadow=true`.

`-ReferencePath` identifies the ordinary compiled pilot metadata. Its
`profiles.sd/hd.leaves.shadow` and `families.shadow` are the complete combined
all-caster references. Candidate/reference render-configuration hashes must
match, and both must contain the exact eight pilot directions. All copied
files retain their original bytes and hashes. No image resampling or new
residual solving occurs inside this fixture.

The builder independently extracts the packed cells and reconstructs alpha
over at both equal densities. The maximum source-alpha allowance is **one
8-bit code value** across all 224 direction/pose cells per density. It refuses
to stage mismatching source arrays. This mathematical precheck does not
replace the native filtering gate.

The candidate's fixed base shadow lives in `graphics_set.base_visualisation`;
upper and rotor shadows are separate native state-animation leaves. The
reference has one complete shadow state-animation leaf and no fixed-base
shadow. No color layers are drawn. Frozen, inactive turrets have no ammo and
cannot introduce flash, casing or projectile effects. The helper's sole
dispatcher captures each pair sequentially at the identical position, camera,
orientation, lighting and opaque neutral background.

## Family tiers

The first mandatory baseline is `all_hd`: HD base, upper and rotor against
the HD union. `sd_baseline` compares all SD components against the SD union.
The following optional HD-reference tiers preserve complete families:

- `base_upper`: HD base/upper, SD rotor.
- `base_only`: HD base, SD upper/rotor.
- `all_sd`: SD base/upper/rotor against the HD reference.
- Remaining whole-family combinations have explicit names such as
  `hd-b32-u64-r64`.

Naively mixing separately solved SD/HD residuals is **not presumed valid**.
Failed optional tiers are ineligible and appear in `optional_tiers_rejected`.
They do not turn a passing mandatory baseline into a failure of that baseline.
A selected single-tier run must itself pass. A new mixed-density residual
solution requires a new candidate metadata hash and fresh native evidence;
no old result can be applied to changed masks.

## Native sampling and tolerances

Smoke uses directions 0/32/96/128, physical poses 0/1/7/20, offsets 0/0.5,
and zoom 1/1.5: **64 pairs per tier**, or **576** for all nine tiers.
Full uses eight directions, all 28 poses, offsets 0/0.25/0.5/0.75, and zoom
0.75/1/1.5/2: **3,584 pairs for one selected tier**. Full runs one tier at a
time and requires that tier's passed smoke result for the same input hashes
and compression mode. Each matrix adds three duplicate control pairs.

Offsets are fractions of an engine-native pixel (32 pixels per tile) in both
X and Y; they test diagonal subpixel phases rather than all X/Y combinations.
The camera displacement is `fraction / 32` tiles for both densities. HD source
offset is twice the native offset; SD source offset is equal. Screen offset is
native offset times zoom. Every capture records and checks all three units.
Neither input images nor native screenshots are fitted, aligned or resampled.
The camera moves relative to the actual entity position, because native turret
creation snaps requested positions to the placement grid. Both positions and
the resulting offset are checked. Each fractional group must produce distinct
decoded reference screenshots. The `entity-relative-camera-v3` contract requires
v3 smoke evidence before a full run. Historical v2 used source-pixel fractions,
covering HD native fractions only half as large; that remains limited evidence.
Earlier snapped-position runs provide no fractional evidence. Framing includes an
unclipped uniform border, and calibration uses a strictly uniform 16x16 interior
ROI centered on the control rather than a median across an unknown edge.

The strict native visual allowance is **2 RGB code values maximum** and
**0.25 RGB RMS per case**. Identical controls and the registration border
must match exactly. Native alpha 0/128/255 controls calibrate the shadow
darkening transfer; the midpoint must be linear within two RGB code values.
The analyzer reports **equivalent alpha units**, not framebuffer alpha, with
a maximum allowance of **6 alpha code values**. At a background near 180 and
the measured 50% full-shadow darkening, one native RGB code corresponds to
roughly 2.8 alpha codes. This quantization allowance does not permit large
overlap shadows, missing coverage, halos, or misregistered family edges.

Use `-TextureCompression none` for mathematical eligibility. Stage a separate
`high-quality` run to inspect the normal GPU compression path. No production
or fixture sprite gains a `not-compressed` flag. The observed engine DXT mode
must match the requested mode. Native source alpha, filtered RGB errors and
compression effects remain separate evidence.

Reports use schema `esir.minigun.native-shadow-evidence.v1`, with exact
`candidate_metadata_sha256`, `reference_metadata_sha256`, `matrix`, and
`texture_compression_observed`. `tiers.<name>.native_eligible` can be true only
after a complete passing **full** uncompressed matrix, valid calibration,
passing source-alpha checks, and no required failures. It includes the exact
`families={base,upper,rotor}` and `reference_profile` mapping. Smoke never
grants eligibility. `production_approved` always remains false.

## Commands

```powershell
powershell -File .codex/esir/asset-generators/minigun-turret/invoke-shadow-fixture.ps1 -Task Stage -ShadowCandidatesPath "<shadow-candidates>" -ReferencePath "<compiled all-caster pilot>" -Matrix smoke -Tier all -TextureCompression none
```

The wrapper delegates to the existing managed native runner and its engine,
version, concurrent-process and junction-cleanup guards. Only the main task
may run the newly staged payload:

```powershell
powershell -File .codex/esir/asset-generators/minigun-turret/invoke-shadow-fixture.ps1 -Task Run -RunPath "<printed managed payload>"
```

Full Stage additionally takes `-Matrix full -Tier <passing tier> -SmokeSummary
"<passed smoke summary.json>"`. Native screenshots, signed error heatmaps and
all input/evidence hashes are retained. Red error pixels mean extra darkening;
blue means missing darkening. A source-array proof alone never approves a tier.
# Final256 combined-shadow extension

The builder also accepts the complete `0..255` compiled family. Final256 runs use only `combined_sd` or `combined_hd`; residual and mixed-density tiers remain pilot-only. The original pilot full-reference layout, case set, alpha controls and tolerances are preserved.

`--render-references` identifies the retained renderer directory containing `render-configuration.json`, `render-records.jsonl` and `references/full/Shadow/`. Combined staging now reads every real source frame, checks its byte size and SHA256 against both compiled source manifests and the render journal, verifies every atlas file against compiler metadata, and compares the reconstructed full alpha canvas exactly. This checks **7,168 cells per density** for final256, even in a one-profile native run. The SD target uses the compiler's explicit premultiplied Pillow LANCZOS path before comparison. No matching-metadata shortcut remains. The retained source ledger includes all actual cell addresses, decoded RGBA hashes, alpha hashes and source digests.

`--reference-selection auto|full|cells` defaults to `full` for pilot8 and `cells` for final256. The candidate retains its complete actual packing and every direction. References select original PNG rectangles with `filename/x/y`, one physical frame and one direction, preserving their crop, scale and shift. No reference PNG is repacked or resampled. Native data-stage audit and screenshot prototype names verify those selectors.

Final full canaries are `0,7,8,15,16,32,64,96,127,128,160,192,224,255`. Each serial profile tests 14 headings × 28 physical poses × four camera fractions × four zooms: **6,272 comparisons plus three alpha calibration controls**. The strict aggregate has **12,544 comparisons plus six controls = 12,550 pairs**. Its source components must share exact metadata, source proof, analyzer, compression and texture policy; each component keeps its independent alpha calibration.

The error contract remains max RGB **2**, per-case RGB RMS **0.25**, calibrated equivalent alpha max **6**, source alpha allowance **1**. Combined source alpha additionally must match exactly (0); there is no lossy source exception. Identity controls and registration borders remain exact zero. Existing `native_eligible` remains full and global `none` only. A separate `final_policy_qualified` verdict requires final256, a complete full matrix, observed global `high-quality`, complete source proof, and native leaves preserving default shadow flags with an observed `[shadow,linear-magnification,alpha-mask]` atlas. No `not-compressed` or sampling flag is added to shadows.

Both verdicts require actual source, profile, case and geometry evidence. Reanalysis of historical pilot evidence does not acquire a final source proof or final256 qualification. Production combined emission requires the exact retained serial HQ aggregate. An aggregate always remains `production_approved=false`; it is one release gate, not promotion authorization.

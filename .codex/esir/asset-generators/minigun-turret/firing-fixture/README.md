<a id="contract"></a>
# Native minigun firing alignment fixture

Status: native pilots captured; full matrix and image-backed acceptance pending.
Resume from [the operational status](../../../../../output/minigun-implementation/STATUS.md)
and [live render snapshot](../../../../../output/minigun-implementation/render-status.json)
before starting engines. Compact controls and strict retention are installed and
checked offline; their native smoke is still pending. The accepted eight-view
SD/BD-on piercing pilot remains valid within its recorded historical scope.
This isolated helper never alters shipping prototypes. Its four ammunition
variants clone the final native ammo/effect graph after ESIR's doctrine pass:
native visuals, flash-only, projectile-only, and both visual families blank.
Only private clones receive source/creation observers and contrast overrides.
The native-visual variant preserves authored flashes, projectile animation,
height, payload, delivery multiplicity, scatter and physics.

The main graphics factory builds the candidate from a supplied helper-local
`candidate-graphics-data.lua`. Pilot uses the compiler's actual eight-direction
atlas, in order `0,32,64,96,128,160,192,224`; full uses 256. A marker layer follows
the color layers' exact direction count/projection/convention, encoding the global
rendered index in complementary pixel bits. A mathematical inverse-projection
hypothesis becomes verified only after the actual native marker agrees. Every
comparison is keyed by the observed rendered direction, not the requested angle.
The central `muzzle-anchors.json` is an uncalibrated geometry proposal, including
its candidate one-tile effect height, until native evidence establishes otherwise.

## Staging inputs and matrix

Use the sibling `invoke-firing-fixture.ps1`. Stage is its default and never starts
an engine. Run starts only the pinned installed Factorio 2.0.77, using the same
dependency seed/configuration and managed-payload convention as the native timing
fixture. It rejects concurrent Factorio or background Blender work. Root owns
serial Run execution. The HD mod is explicitly disabled for SD and enabled for
HD; merely omitting a newly discovered graphics pack from mod-list is insufficient.

Required Stage inputs are `-CandidateData <Lua file>` and the geometry proposal
`-Anchors <JSON>` (defaults to the prototype-2 handoff path). `-CandidateAssets`
copies a candidate export directory beneath the helper's `candidate/` directory.
Every supplied PNG path must reference
`__zzz-esir-minigun-firing__/candidate/<sd|hd>/graphics/<relative image path>`.
Current strict staging rejects external installed-pack PNG references, traversal
and reparse points. `candidate-assets-manifest.json` binds the complete referenced
SD/HD union, including icons, by path, PNG dimensions, byte count and SHA256;
every atlas must remain within 4096 pixels. Analysis and matrix aggregation
reopen those retained PNGs instead of trusting a summary or the Lua hash alone. Profiles
must expose the production factory's complete schema, icon fields and full
256-tuple launch map even when the pilot atlas has eight rendered views.

Connector placement is `deferred_by_user`; ordinary staging preserves the existing
connector. `-IncludeWiredPreview` opts into eight red/green wire captures for the
user's reference, and never adds a pass requirement. `mechanical-proposal.lua`
retains the unvalidated variation-28 offsets `(30,14)` and `(35,19)` as an optional
reference only. It is not loaded unless explicitly supplied through
`-MechanicalData`. Original connector and shell values remain in the audit. Shell
ejection is an optional visual audit, not an added acceptance gate.
The same optional mechanical table may explicitly set `projectile_center` and
`apply_projection_to_projectile_creation_position` for native calibration. The
new candidate's creation parameters are always assigned explicitly; the graphics
factory's visual `apply()` alone does not replace the legacy launch map.

```powershell
# Compact-control smoke: only eight piercing headings, no moving or wires.
python -B .codex/esir/asset-generators/minigun-turret/emit_graphics_data.py --compiled <compiled-pilot-root> --anchors output/meshy/minigun-prototypes/prototype-2/handoff-256/muzzle-anchors.json --color-evidence <passed-exact-input-color-evidence.json> --output <emitted-fixture-root> --mode fixture
powershell -File .codex/esir/asset-generators/minigun-turret/invoke-firing-fixture.ps1 -Task Stage -Profile sd -Mode on -Coverage pilot -CalibrationOnly -CompactHeadingTemplates -CandidateData <emitted-fixture-root>/candidate-graphics-data.lua -CandidateAssets <emitted-fixture-root>/candidate-assets
powershell -File .codex/esir/asset-generators/minigun-turret/invoke-firing-fixture.ps1 -Task Run -RunPath <managed-payload-returned-by-Stage>

# Repeat Stage for sd/on, sd/off, hd/on, hd/off; run each returned payload serially.
powershell -File .codex/esir/asset-generators/minigun-turret/invoke-firing-fixture.ps1 -Task Stage -Profile sd -Mode on -Coverage pilot -CompactHeadingTemplates -CandidateData <candidate.lua> -CandidateAssets <export-directory>
powershell -File .codex/esir/asset-generators/minigun-turret/invoke-firing-fixture.ps1 -Task Run -RunPath <managed-payload>

# Full coverage additionally requires a native pilot projection result.
powershell -File .codex/esir/asset-generators/minigun-turret/invoke-firing-fixture.ps1 -Task Stage -Profile hd -Mode off -Coverage full -CompactHeadingTemplates -CandidateData <candidate.lua> -CandidateAssets <export-directory> -Calibration <projection-calibration.json>
```

`-CalibrationOnly` cannot satisfy all-ammo or full acceptance, even after every
image in that subset is reviewed. It is exactly eight static cases;
`-CalibrationOnly -IncludeMoving` is rejected by both wrapper and builder.
Ordinary acceptance always includes moving shots; wired previews are always
optional. Counts include 14 native template atlases per distinct ammunition:

| Scope | Cases | Benchmark ticks | Maximum planned screenshots without heading controls | With compact heading controls |
| --- | ---: | ---: | ---: | ---: |
| Calibration only | 8 | 1,850 | 718 | 766 |
| All-ammo pilot acceptance | 89 | 19,870 | 9,030 | 9,558 |
| Full acceptance | 337 | 74,430 | 30,854 | 32,870 |

Wired previews add eight screenshots. Each SD/HD by doctrine configuration is a
separate run; the small calibration is deliberately not the complete matrix.
Counts use the current one-frame-per-variant/native-tick moving policy, with at
most 1,044 moving screenshot paths. All source-observed shots remain in the report.
The generated `fixture-plan.json` records the exact planned component counts.

`-CompactHeadingTemplates` and `-HeadingTemplates` are mutually exclusive.
Compact mode uses the actual observed animation variation separately for the
native and flash-only first shot. For each of three native ray hypotheses it
renders two zero-height controls over different fixed opaque backgrounds and a
third, held-out control at the source's native height. The nine 256-pixel cells
form a 2304x256 atlas at zoom 2, captured before the shot and at offsets 0/1.
This adds six images per static case. It preserves the full firing/decay captures;
only diagnostic control atlases are smaller.

`fit_compact_flash.py` recovers foreground/opacity from the paired backgrounds,
then independently searches the third cell to test height registration. That
cell is excluded from recovery. Actual-shot fitting searches the full muzzle
capture; the expected muzzle is compared only afterward. The report binds all
15 source images per static case and retains all ray alternatives. It requires
every case, variant, frame and held-out ray control; it never creates an approved
visual review. A failed native compact smoke blocks using those controls for the
full matrix without changing historical pilot verdicts.

```powershell
python -B .codex/esir/asset-generators/minigun-turret/firing-fixture/fit_compact_flash.py --evidence <retained-compact-evidence> --output <new-diagnostic-directory>
```

The retained diagnostic `-HeadingTemplates` route adds five forced native animation variations for each actual
native and flash-only first flash in every static case. It adds224 screenshots
to calibration-only, for942 total with the same1,850 ticks. Source rotation and
correct-rotation behavior remain intact. Constructor target rays initialize
rotation; the engine returns orientation0 for these effects even when their
pixels rotate, so no orientation setter/readback can establish the rendered angle.
Controls cover the observed center ray, center ray projected once/twice, and
source/visual rays projected twice. The five variations for each ray appear at
height0 and source-native height, in50-cell12800x256 atlases. All coordinates,
ray multipliers and resulting positions are recorded. Target entities use
`snap_to_grid=false`; otherwise diagonal target quantization can skip directions
and produce about2 pixels of apparent error. Each atlas has a pre-shot baseline
and frames0..12. Original animation shifts and effect fields remain in the audit.
The source effect and template snapshots do not establish a rendered attachment
point by themselves. Template pivot, animation frame and shape still require
image calibration before translation fitting can support a native overlay.
Compare paired cells by actual animation/frame appearance, including adjacent
capture ticks if needed; an equal tick offset is not proof of equal native frame.
The expected height scale is 32 normal-native pixels per tile (64 at capture zoom
2), and the paired pixel translation must establish it rather than assuming it.
These opt-in captures never replace actual firing screenshots or approve a gate.

`fit_heading_flash.py` compares actual native pixels without CPU angle rotation
or a muzzle-coordinate search prior. Background-dependent alpha composition can
weaken raw difference correlations, so low confidence remains explicit even when
successive-frame locations agree. `fit_projectile_cap.py` independently fits the
audited piercing bullet's leading cap, constraining only its angle to the observed
projectile heading plus/minus2 degrees. It retains all angular alternatives,
source/capture hashes and pre-shot/native/projectile-only panels. Its first-frame
location is an attachment measurement; the next frame is a moving glyph center,
not a substitute muzzle position. Neither tool writes an approved review.

For both compact and diagnostic heading-template routes, the review's
`heading_template_calibration.measurement_report` identifies the independent
measurement JSON. Analysis retains it as `heading-measurements.json` and binds
its SHA alongside the native report, candidate and source captures. The matrix
repeats its control and coverage checks from those retained bytes. A missing or
changed retained measurement fails; a historical report lacking this retention
needs a fresh analysis output, not an overwritten summary. Compact controls also
require their complete image inventory and held-out checks described above.

`fit_composited_flash.py` is a companion diagnostic for the background-dependent
flash residual. It recovers opacity and premultiplied foreground from paired
native controls over different floor pixels, then searches every valid image
translation using the absolute compositing residual. The independently measured
height translation and capture hashes must agree before recovery. The proposed
muzzle point is compared only after fitting; it never constrains the search.
Different cardinal control cells validate recovery against backgrounds that were
not used to recover the foreground. This does not change the original raw-score
thresholds or approve alignment. Nearby native ray alternatives are retained.

```powershell
python -B .codex/esir/asset-generators/minigun-turret/firing-fixture/fit_composited_flash.py --evidence <retained-evidence> --raw-measurements <heading-flash-measurements.json> --output <new-analysis-directory>
```

The unsnapped SD/doctrine-on calibration pilot produced 32 visible-flash
measurements and 16 passing held-out controls. The fitted attachments differ
from the proposed anchor by at most 0.707 normal native pixels, with physical
barrel attachment, decay, moving fire and the complete four-configuration matrix
still required. These results remain explicitly unapproved.

There are 88 static pilot cases: eight views for basic, piercing, uranium and
eight exotic families (compound, corrosive, cryo, oxyfluoride, morphium,
hexafluoride, arc, neutron). Full coverage expands piercing to 256 views, yielding
336 static cases. Both add one moving-aim piercing burst with 1,024 rounds available, starting
from the first native shot and turning its target through a full revolution over
240 ticks, then removing unspent ammunition after 20 settling ticks. This budget
allows the native 0.25 cooldown to fire several times per update without exhausting
the magazine before the sweep. Actual shot counts must equal consumed ammunition;
the recorded unspent amount reconciles the deliberately stopped burst. This records
first-after-preparation separately from sustained shots.
It must actually fire through all eight cardinal/diagonal sectors; static cases
cannot pass that gate. Expected native timing is not faked by directly spawning
flashes or projectiles.

## Native observations and visual evidence

Each static control fires one round and records actual ammo consumption, a single
source-only shot observer, native flash/projectile creation effects and the
effective attack map. Full-frame direction captures occur before ammunition and
at the actual shot. Muzzle clips are 320x320 at zoom 2, centered on the proposed
visual anchor, at the shot tick, ticks 1..12 and 16/24/32/48/64/96 afterward, plus
a pre-shot baseline. `force_render=true` binds screenshots to the requested
update. Basic native instant delivery in BD-off legitimately has no projectile;
that branch is recorded as not applicable, never synthesized for the test.
`evidence_contract.projectile_requirements()` resolves the observed private-ammo
branch against the audited effective source `ammo_type` for every contrast row.
It checks declared branch/projectile delivery counts, source identity and actual
projectile birth on each required shot tick. A declared projectile route with no
observer fails; only an audited instant route can omit projectile-origin review.
Repeated source deliveries do not establish an exact visible projectile count.
Script-trigger positional fields can be absent; source/target entity snapshots
are recorded separately. A turret-center snapshot is never labeled as an effect
spawn point. Older captures lacking those snapshots cannot prove creation
coordinates from their observer identifiers alone.

The moving burst captures one actual native full frame per variant and tick,
including the direction marker. Multiple shots on that tick reference the same
frame; each retains its own shot, source, effect and projectile observations.
Analysis decodes actual native direction markers, requires sustained fire through
all eight sectors, and selects the first-after-preparation shot plus the median
sustained shot in each sector for origin review. Every required flash/projectile
annotation binds exact capture bytes and the two-normal-native-pixel maximum.
The matrix recomputes this moving evidence through the same analyzer and compares
the saved result. All captures and source observations
remain available, including overlapping effects in the sustained burst.

The wrapper defaults to `-CaptureStorage hardlink`: retained captures and
candidate PNGs share immutable same-volume files with the managed payload.
Every evidence pathname and original byte sequence remains available, and
`capture-manifest.json` binds every unique recorded screenshot path, hash and
byte count. `copy` remains explicit for another volume. Neither mode removes
raw files or overwrites different evidence. Reanalysis and the four-run matrix
rehash the retained images and manifests; hardlinks are storage reuse, not fewer
acceptance cases or a substitute for actual native frames.

For the first case of each ammunition, the same native shot callback also creates
an isolated template atlas containing each authored flash animation variation.
The templates retain animation frames, timing, tint, glow and scale, but fix
rotation and height to zero and remove secondary emissions. Creation explicitly
disables grid snapping and records the returned entity positions. The initial
native run exposed an offset consistent with grid snapping in older captures: actual attachment points
were 32 pixels below/right of the assumed cell centers. Never reuse those assumed
centers. The source-frame pixel calibration below locates each template's actual
attachment point from its image and authored sprite geometry. A pre-shot atlas
and updates 0..12 are captured. These are calibration templates, never substitutes
for actual turret-fired effects. Installed 2.0.77's `gunshot()` has five variations,
34x38 pixels, two or three frames each (13 horizontal cells total), shift zero and
speed 1.5; exotic source flashes can override timing and tint. The audit retains
the actual effective animations rather than assuming these vanilla defaults.

The analyzer subtracts each variant's static baseline before comparing contrast
controls, reducing different floor pixels and static body differences. It reports
first contrasted pixels, bounds, energy and late decay; it creates annotated
contact sheets. These masks are diagnostic, not semantic proof: native random
flash rotation, projectile scatter, casing particles and lighting can contaminate
the difference. Neither flash centroid nor script-effect coordinates are a
measured visual muzzle origin. The actual native image must support the origin.

Optional pixel-fit diagnostics can reduce manual point-finding work:

```powershell
python -B .codex/esir/asset-generators/minigun-turret/firing-fixture/calibrate_flash_templates.py --evidence <retained-evidence> --output <template-origin-calibration.json>
python -B .codex/esir/asset-generators/minigun-turret/firing-fixture/fit_flash_origin.py --evidence <retained-evidence> --output <diagnostic-output> --template-calibration <template-origin-calibration.json> --case d000-piercing-rounds-magazine
```

Omitting `--case` fits every static case and can be expensive. The tool compares
the actual native shot image with the isolated native templates, searching
translation and rotation without receiving an expected muzzle point. It reports
the translated template attachment point, score, competing-origin spread,
translation-peak margin and magnified native overlays. It never measures a
centroid or uses source coordinates as an origin. Scores are provisional; CPU
rotation interpolation can differ from the engine, and random smoke/projectiles
can make a match ambiguous. No fit auto-populates an approved review. Template
creation/update ordering and known-origin placement still require native visual
inspection. Missing first-shot evidence remains a failure or pending review.

## Review and pass criteria

`analyze_fixture.py` exits 2 for failed automated evidence, 3 for pending visual
review, and 0 only when that individual configuration's alignment gate passes.
The launcher retains completed native captures with a warning when review is
pending. All four SD/HD by doctrine combinations require acceptance. Pilot
acceptance is not full-256 acceptance; `production_approved` remains false here.

Pass `-Review <JSON>` to Analyze, or run the Python analyzer directly against a
retained evidence directory. The review must bind to the model hash, candidate
metadata hash, profile and doctrine setting. Every static flash and applicable
first-projectile origin needs a measured point on the exact native capture bytes,
plus identity confirmation. Flash first-appearance/decay review is required.
The current hard maximum is two pixels at normal 32-pixel-per-tile native scale
for both SD and HD (four HD source pixels); the attachment goal is one pixel.
Analyze accepts a stricter tolerance but rejects a value above two. Older retained
reports keep their original recorded thresholds and are not retroactively passed.
If a projectile has moved before its first screenshot, do not claim its visible
tail equals the launch origin; record that measurement limit and keep the gate
pending until native image evidence can locate the origin. Coordinates cannot
substitute for a missing or ambiguous first visual.

Review structure (replace example values with measurements; never auto-approve):

```json
{
  "source_sha256": "<model hash>",
  "native_report_sha256": "<exact native report hash>",
  "candidate_data_sha256": "<staged metadata hash>",
  "mechanical_data_sha256": "<staged optional mechanical metadata hash>",
  "profile": "sd",
  "ballistic": true,
  "height_compensation_verified": true,
  "cases": {
    "d000-piercing-rounds-magazine": {
      "flash": {
        "capture": "minigun-firing/d000-piercing-rounds-magazine/native/0.png",
        "sha256": "<image hash>",
        "origin_pixels": [160, 160],
        "native_visibility_confirmed": true,
        "first_appearance_and_decay_reviewed": true
      },
      "projectile": {"capture": "<first native image>", "sha256": "<hash>",
        "origin_pixels": [160, 160], "native_visibility_confirmed": true}
    }
  },
  "moving": {"1": {"flash": {"capture": "<native burst image>", "sha256": "<hash>",
    "origin_pixels": [256, 129], "native_visibility_confirmed": true}}}
}
```

The example is deliberately incomplete. Supply every required view/visual,
including all selected sustained shots and applicable projectiles. Retained
reports list pending entries. A matching source coordinate with no image-backed
review cannot produce a pass.

After all four full configurations pass individually, pin the exact reviewed
frozen run inputs explicitly. These are the original candidate Lua, mechanical
table, anchors and loaded-PNG manifest used by all four runs, not the later
finalizer output or whichever files happen to be newest. Rehash the frozen
bytes; every retained configuration must match all four expected hashes.

```powershell
$frozen = '<exact reviewed frozen run input directory>'
$candidate = (Get-FileHash -Algorithm SHA256 -LiteralPath "$frozen/candidate-graphics-data.lua").Hash.ToLowerInvariant()
$mechanical = (Get-FileHash -Algorithm SHA256 -LiteralPath "$frozen/candidate-mechanical-data.lua").Hash.ToLowerInvariant()
$anchors = (Get-FileHash -Algorithm SHA256 -LiteralPath "$frozen/muzzle-anchors.json").Hash.ToLowerInvariant()
$assets = (Get-FileHash -Algorithm SHA256 -LiteralPath "$frozen/candidate-assets-manifest.json").Hash.ToLowerInvariant()
python -B .codex/esir/asset-generators/minigun-turret/firing-fixture/summarize_matrix.py `
  '<sd-off>' '<sd-on>' '<hd-off>' '<hd-on>' `
  --expected-candidate-sha256 $candidate --expected-mechanical-sha256 $mechanical `
  --expected-anchors-sha256 $anchors --expected-assets-manifest-sha256 $assets `
  --output '<new-matrix.json>'
```

It also requires equal SD/HD effective native attack definitions and collision/selection boxes, plus
source observations within each doctrine mode. The doctrine itself deliberately
changes projectile delivery, so on/off payloads are not asserted identical.
The strict schema-2 matrix reopens all four reports, exact static/moving case
inventories, reviews, candidate PNG manifests and capture manifests. A passing
summary with missing or changed underlying evidence cannot satisfy finalization.
Projectile-route, moving-review and retained heading-measurement checks are
repeated rather than inherited from that summary. The [finalizer](../FINALIZATION.md)
also binds the matrix, evidence-contract, image-review and compact-control source
hashes in its receipt. These analyzers use the installed NumPy/Pillow environment;
running them does not start an engine.

## Offline verification and boundaries

Run `python -B test_fixture.py` in this directory for deterministic barcode,
inverse-hypothesis, contrast-baseline and image-review binding checks. Those tests
do not execute Factorio or validate the API against a running engine. The code
was written against the installed 2.0.77 prototype/runtime docs. Existing native
pilot loading and the separate eight-view SD/BD-on piercing review keep their
recorded scope. Native compact-control smoke, final256 first-frame/appearance
review, turning bursts and all four full configurations remain pending until
their actual artifacts are analyzed. Offline checks do not acquire those verdicts.

Sub-tick projectile positions cannot be reconstructed from one frame per tick.
Windows analysis uses absolute extended-length paths for retained copies and
image I/O. Capture paths stored in evidence remain portable relative paths.
An eight-view pilot cannot establish all fine-angle behavior. Direction markers
prove the fixture color-layer convention; final production artwork and atlas
metadata must still be the same accepted inputs. No publishing or deployment is
performed by these tools.

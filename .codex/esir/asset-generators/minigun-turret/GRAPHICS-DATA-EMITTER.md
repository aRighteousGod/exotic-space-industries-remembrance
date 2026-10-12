# Staged graphics metadata and exact package map

`emit_graphics_data.py` converts `compile_separated.py` output to the metadata
accepted by the main mod's `gatling-turret/graphics.lua` factory. It flattens
`profiles.sd/hd.leaves`, retains physical atlas strides, and supplies the complete
256-entry muzzle proposal even when the real image family has only eight views.
It writes only below repository `output/`; it never promotes shipping assets.

```powershell
python -B .codex/esir/asset-generators/minigun-turret/emit_graphics_data.py `
  --compiled output/meshy/minigun-prototypes/prototype-2/handoff-256/separated-v2-pilot/compiled `
  --anchors output/meshy/minigun-prototypes/prototype-2/handoff-256/muzzle-anchors.json `
  --output output/meshy/minigun-prototypes/prototype-2/handoff-256/emitted-pilot `
  --mode fixture
```

The fixture result is `candidate-graphics-data.lua` and a curated
`candidate-assets/` directory. Pass those to firing-fixture `-CandidateData` and
`-CandidateAssets`. Paths point to
`__zzz-esir-minigun-firing__/candidate/sd/graphics/...` and its HD equivalent.
`--fixture-mod` changes only the disposable helper identifier. The factory call
must use `{fixture=true,direction_count=8}` for a pilot; no repeated or invented
views fill the other 248 directions. A full result uses `direction_count=256`.

`--mode production` requires all 256 real directions and writes staged
`graphics-data.lua` with these shipping roots:

- Complete SD: `ei_graphics_6_path`, followed by the pack-relative asset path.
- HD: `__minigun-turret-HD__/`.
- Entity sheets: `graphics/entities/gatling-turret/`.
- Item and technology icons: `graphics/items/gatling-turret.png` and
  `graphics/techs/gatling-turret.png`.

All SD base, upper, rotor, icons and shadows stay in Graphics 6. File capacity
comes from actual atlas metadata; there is no direction128 package boundary.
Each direction retains all 28 physical poses in its original file. Pilot files retain their genuine eight-view contents
and helper-local paths; their package totals are not a full-family budget.

The main production Lua uses `ei_graphics_6_path` for every Graphics 6 asset;
its JSON and artifact map retain the fully resolved strings. Fixture paths and
the self-contained HD library keep their independent owner roots. The map records
`graphics_data_path_binding` so finalization can reproduce either historical
literal Lua or newly emitted constant-based Lua without rewriting old evidence.

The production-shaped result remains an unaccepted proposal. It records source,
render-configuration, compiler, emitter, input-manifest and anchor hashes.
`graphics-data.json` exposes the emitted table without Lua parsing.
`emitter-report.json` records resolved inputs and payload bytes. All candidate
images are verified against encoded hashes, dimensions, exact-decoding
declarations and raw `sRGB/gAMA/cHRM` chunks before copying. Changed inputs require
a fresh output directory; reruns with identical inputs reproduce the same files.

## Artifact map and package staging

`artifact-map.json` uses `esir.minigun.artifact-map.v1`. Each `artifacts` entry has
an absolute `source`, target `pack`, pack-relative `path`, encoded `sha256`,
`bytes`, `size`, and `decoded_rgba_sha256`. The decoded hash covers row-major
8-bit RGBA bytes, including transparent pixels. Duplicate SD fallback references
produce one artifact, never an SD shadow copy inside HD. The
`frozen_profile_contract` always uses shipping roots, even in fixture mode;
the runnable fixture Lua uses its helper roots. The map records the selected
shadow tier and complete-direction status. An archive builder can overlay this
explicit map onto existing pack content without touching shipping folders.

`support_artifacts` adds one hash-bound unloaded Lua metadata module at
HD `examples/graphics-data.lua`. It contains only the shipping HD profile and
the same firing calibration/provenance flags as the main candidate. A draft
module remains outside shipping and the example rejects it until full-direction
and calibrated-native flags are true. The standalone example itself and reuse
README live in the HD scaffold and are counted as existing archive content.

## Shadow representation and eligibility

The default is `shadow_representation="combined"` with one complete 28-pose
shadow family. `--shadow-tier all_hd` keeps each profile's own complete shadows;
`all_sd` makes HD reference the Graphics 6 shadow family.

`--shadow-candidates <directory>` instead consumes
`esir.minigun.shadow-candidates.v1`. Its base, upper and dynamic residual become
`shadows={base,upper,rotor}` with `shadow_representation="alpha_over_residual"`.
Renamed shipping files use `minigun-shadow-base-*`, `minigun-shadow-upper-*`, and
`minigun-shadow-rotor-*` to prevent collision with color sheets. Every SD profile
keeps complete SD residual families. HD tier choices are:

| Tier | Base | Upper | Rotor |
| --- | --- | --- | --- |
| `all_hd` | HD | HD | HD |
| `base_upper` | HD | HD | SD |
| `base_only` | HD | SD | SD |
| `all_sd` | SD | SD | SD |

Uniform residual tiers can be emitted as explicitly unvalidated fixture/staging
data. The factory refuses unaccepted residuals outside an explicit fixture.
Mixed tiers additionally require `--shadow-evidence` with schema
`esir.minigun.native-shadow-evidence.v1`, exact candidate/reference manifest
hashes, `matrix="full"`, observed texture compression `none`, passed automated
checks, passed source-alpha proofs, and a native-eligible tier matching the exact
family densities and reference profile. SD eligibility uses `sd_baseline`;
HD fallback uses `all_sd`. A smoke run cannot authorize a mixed tier. Native
residual acceptance does not imply muzzle, icon, animation or package acceptance.

## Preserved muzzle proposal and user-owned connector

The emitter accepts the retained `geometry_proposal_not_native_calibrated`
anchor document. It validates, then copies its 256 ordered values without
recalculation: uniform lookup orientation maps through
`atan2(sqrt(2)*sin(angle),cos(angle))/(2*pi) mod 1`, interpolates visual anchors,
and retains the proposed one-tile effect-height adjustment. That observed lookup
transform does not prove this new model's native muzzle alignment. Calibration
and height compensation remain false in emitted provenance.

Connector placement is user-owned. The emitter produces no mechanical-data
override, and the builder preserves the existing production circuit connector.
There is no connector-position acceptance gate for this implementation.

## Compression and motion review

The compiler option `--rotor-strips 4` preserves the original mechanical
decomposition and stores each logical rotor crop in four disjoint vertical
rectangles. Every child retains28physical frames, all declared directions,
its measured packing stride and its exact source-rectangle registration.
Crop boundaries are divided deterministically even when the width is not
divisible by four. The compiler records each child and its exact partition
proof, while PNG encoding verifies decodedRGBA and preserves color chunks.
Source references and B/U/R decomposition are unchanged. A new compiler source
hash requires a new output directory; prior proof folders remain intact.

The emitter accepts `rotor.layers` only as an exact four-child container and
requires `--color-evidence <summary.json>`. The evidence must bind the exact
compiled metadata hash, pass the uncompressed native comparison, include the
camera-v3 native-pixel fractional geometry and its identity control, and contain
the complete declared case matrix. Pilot smoke evidence permits only fixture
emission. Production still requires256real directions plus full native
eligibility; a pilot metadata hash never substitutes for final artifact proof.
The final native matrix is bounded to the eight representative global headings
0,32,...224 plus any declared boundary sentinels, with all28poses, four fractions
and four zooms. It loads the final256-direction leaves and binds that final
metadata hash. `source_direction_count=256` identifies that final-artifact run;
`tested_direction_indices` records its actual canaries. Separately, all7168
logical cells per density must have exact offline reconstruction records.
The factory flattens those internal storage children and applies each native
state sequence to every child without changing its physical frame count,
packing, offset or scale. Rotor strips remain one logical mechanical family.

Every SD child is owned by Graphics 6. File counts follow each child's actual
directions-per-file capacity and are not fixed at32. All SD shadows remain G6.
The compiler's older all-SD-in-G4 budget comparison is explicitly not the
selected package budget; the emitted map and measured complete archives own
that gate.

The emitter carries the tested `not-compressed` color flag from native evidence
and preserves default sampling. Lossless PNG encoding alone does not make GPU
texture compression lossless. Native color comparison and compression-policy
review remain separate gates. Ground-shadow atlases receive native shadow/alpha-mask handling; a
software bilinear reconstruction check cannot establish the engine's actual
color filtering behavior.

`build_motion_review.py --compiled <directory>` independently writes a d096
28-pose contact, lossless RGBA APNG spin-up/spin-down/cycle previews and timing
report below `compiled/motion-review/`. It does not change compiler inputs,
metadata or shipping payloads. Integer-millisecond boundary rounding retains the
complete 60 Hz transition duration; native smoothness acceptance remains pending.

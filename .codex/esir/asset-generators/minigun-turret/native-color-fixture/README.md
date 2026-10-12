# Native minigun color composition fixture

This disposable Factorio 2.0.77 helper tests how the compiled base, upper and
rotor layers compose after native sprite filtering. It compares them with the
compiler's combined Object reference atlases. Those reference sheets remain
outside both shipping graphics payloads. No engine is started by Stage.

<a id="contract"></a>
## Contract

`build_fixture.py` accepts the completed eight-direction pilot metadata. It
copies byte-identical atlas inputs and records their hashes, source paths and
crop/scale/shift metadata. `contract.lua` is generated inside the disposable
helper; `data-final-fixes.lua` consumes it to create frozen separated/reference
turret clones. Base and gun color use the same object draw order as the shipping
builder. Physical source counts and atlas packing are preserved, with one
selected physical pose in each clone's `frame_sequence`.
Fixture-only rotor candidates may supply recursive `rotor.layers` leaves.
Every child must retain 28 physical poses and eight pilot directions. The
builder copies each child atlas and includes its shift/scale in crop bounds;
the native prototype flattens selected children after the upper layer in their
declared order. This tests spatial-strip seams without changing production
graphics construction or accepting a compiler-only reconstruction proof.

`control.lua` owns this helper's only dispatcher and bounded screenshot matrix.
It creates each separated/reference pair sequentially at the **same** world
position, with exactly the same fixed camera, background, resolution, lighting
and orientation. Entities are inactive, have no ammunition, and never fire.
Autoplaced entities/decoratives are disabled and an opaque neutral ground patch
covers the crop. A duplicate empty-background control must match exactly.
No image registration fit, resampling, brightness adjustment or screenshot
alignment correction is allowed during analysis.

Turret creation snaps to its placement grid. Subpixel shifts therefore move
the camera relative to the entity's measured position by the requested fraction
of an engine-native pixel (32 pixels per tile) in both X and Y. This uses
`fraction / 32` tiles for both profiles. SD source-pixel offset equals the
native offset; HD source-pixel offset is twice it. Screen-pixel offset equals
native offset times zoom. All three offsets and both positions are recorded and
verified; every otherwise-identical fractional group must also contain distinct
decoded reference screenshots. The camera is identical within each pair.
The `entity-relative-camera-v3` contract distinguishes these units and gates
full runs on a passing v3 smoke. Historical v2 runs moved by source-pixel
fractions: SD native offset was `fraction`, HD was `fraction / 2`. They remain
evidence only for those actual offsets, not a full HD native-pixel period.
Earlier snapped-position runs provide no fractional evidence. This tests four diagonal
subpixel phases, not all 16 possible X/Y phase combinations. Pilot headings
use the same inverse Factorio projection as the verified atlas fixture.

## Matrices and gates

- `smoke` (default): directions 0/32/96/128, physical poses 0/1/7/20,
  SD and HD, offsets 0/0.5 native pixel, zoom 1/1.5: **128 comparison pairs**.
- `full`: all eight pilot directions and 28 physical poses, SD and HD,
  offsets 0/0.25/0.5/0.75 native pixel, zoom 0.75/1/1.5/2:
  **7,168 comparison pairs**.
- Each matrix adds one exact duplicate-background control pair.
- First use `-TextureCompression none` for the mathematical composition gate.
  Then stage a separate `-TextureCompression high-quality` run to inspect the
  user's normal GPU compression path. The analyzer checks the actual DXT mode
  in the engine log. `-ColorTexturePolicy not-compressed` changes only the color
  leaves' compression, retaining measured native default sampling. Explicit
  `linear-magnification` is rejected: the native pilot reached80 RGB error.
  The background is uncompressed so cross-mode comparisons cannot be confounded
  by its former blue-channel110-to108 DXT change. The fixture exports every
  actual color leaf's flags through mod-data; an unrelated atlas cannot satisfy
  the lossless-color gate. Automatic sprite cropping remains enabled.
- Maximum RGB error is one 8-bit code value, and per-case RGB RMS error may
  not exceed 0.25. This narrow allowance covers GPU blend rounding across
  extra layers; it does not excuse holes, halos or large compression errors.
  High-quality compression differences are retained for review and are not
  silently relabeled as correct color composition. Camera phase aliases require
  complete actual-position records and exact pixel translations proving nonzero
  movement; the original failed all-phases-unique summary remains historical.
- Reports include per-pair maximum/RMS error, error pixel counts, amplified
  heatmaps, native screenshot hashes and all original native captures.

The smoke gate must pass before the full matrix; Full Stage requires
`-SmokeSummary "<passed smoke summary.json>"` from the identical compiled
metadata and compression mode. A full matrix is still only
the eight-direction pilot when source metadata contains8 directions. Complete256
metadata selects14 global canaries spanning directions and file boundaries,
all28 poses, both densities, four fractions and four zooms. Its evidence is
bound to the final files/metadata; the pilot cannot approve production.
`production_approved` always remains false. This fixture compares **Object
color only**. Full-union shadows and game UI appearance need their own checks;
scalar alpha calibration does not prove geometry seams. Connector placement is
user-owned and is not an acceptance blocker for this implementation.

## Commands

```powershell
powershell -File .codex/esir/asset-generators/minigun-turret/invoke-color-fixture.ps1 -Task Stage -CompiledPath "<compiled pilot>" -Matrix smoke -TextureCompression none
```

Stage delegates to the existing native fixture runner, so engine pinning,
managed staging, source snapshots, source-junction cleanup and serial heavy-job
guards stay shared. Only an explicit Run starts Factorio:

```powershell
powershell -File .codex/esir/asset-generators/minigun-turret/invoke-color-fixture.ps1 -Task Run -RunPath "<printed managed payload>"
```

Run high-quality and full matrices in fresh payloads. Never overwrite a prior
native verdict to change its extraction or tolerance policy. The diagnostic
images can consume substantial disk space; full matrices are deferred until
the smoke comparison passes and the main task authorizes serial execution.

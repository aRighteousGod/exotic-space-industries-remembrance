# Native multicolor status lights and lens coverage

Implementation baseline: Factorio **2.0.77**, ESIR **1.3.41**, Bottleneck Lite
**1.3.4**, flib **0.16.5**, and Assembler-Reskin **1.0.3**. The main mod version
is unchanged. Evidence is in managed run `.factorio-qc/ml-ba1f9d1d`, ID
`d421658441fc432d903a62d9c72fbca5`.

This extends the earlier [plain-light replacement](VERIFICATION.md) and
[smelter extension](SMELTER-VERIFICATION.md). Their earlier red/green-only
captures and counts are historical evidence, not acceptance of this palette.

## Implemented contract

- The existing startup values remain `status` (default), `original`, and `off`.
- Twenty indicator-bearing bodies have exactly 23 paired native lens/light
  visualisations. Eight bodies without lamps receive no replacement indicator.
- Working is green; full output yellow; low power orange; other powered stops
  red. No energy makes both added lens and light transparent. Original colored
  sprite pixels remain visible when no status overlay is drawn.
- Lights retain intensity 1, minimum darkness 0.1, and no flicker. Size is 0.35
  except the refinery's 0.50. Its whole inset screen is centered at source pixel
  `(470, 555)`, offset `(-0.669375, 0.3353125)`, replacing the earlier corner-only
  placement. Other positions are unchanged.
- All 23 neutral masks ship in the main mod. The generator includes disconnected
  colored rims, antialiased fringes, and one opaque source pixel of filtering
  coverage. Red-to-green animation changes distinguish ordinary lens edges from
  unchanged bronze casing. The refinery additionally covers its cyan quadrants.
- Arc furnace, plasma heater, caster and HTR process effects remain authored
  effects. All five arc-furnace process-light presets remain independent.
- Only Status with BNL installed and enabled sets the early ignore flag on the
  20 lamp bodies. The other eight retain BNL indicators. ESIR's palette is fixed
  even when BNL's colors are customized. No shipping runtime handlers or state
  were added.

## Static and asset evidence

`lens-art/acceptance.json` verifies 23 neutral RGBA 64x64 masks, matching shipping
and manifest hashes, unclipped bounds and opaque edge coverage. All 40 original
source sprites/animations remain unchanged; source hashes are recorded per mask.
The whole refinery screen has a separate explicit coverage assertion.

All eight locale sidecars have matching eight-key sets, valid UTF-8 and no
duplicate keys. Source/blueprint ownership and dependency touchpoint checks pass.

The latest repository preflight passes Lua/PowerShell syntax, blueprint and alert
contracts, require/asset references, locale coverage, version consistency and
module headers. It is **not globally clean**: 44 unrelated Python bytecode-cache
path failures and three existing encoding findings remain. Focused Python AST
parsing passes separately. The encoding findings are
`scripts/qc/singularity-lance/angular-results.json`,
`temp/anisetron-tracking-fix/blueprint-final.json`, and
`temp/storage-audit-c/evidence-link-update.json`.

## Native and rendered evidence

The final-data/headless matrix passes:

- Bottleneck compatibility: **1,432 assertions**, 12 mode/presence/custom-color
  profiles, **9,168 native state/orientation cases** and **1,872 transitions**.
  Actual startup values, early flag scope, consumption of unrelated existing
  ignore flags, remaining BNL indicators, fixed ESIR colors, custom BNL cyan and
  complete affected prototypes are checked.
- Arc presets: **1,308 assertions**, seven profiles, **2,628 state cases** and
  **564 transitions**. Three profiles overlap the matrix above; the four extra
  arc presets add 336 cases and 96 transitions, giving **9,504 distinct native
  state cases and 1,968 transition checks** across the combined mode profiles.
- All fields outside the intentional light/lens/status-color/BNL differences
  remain equal, including authored animation/process effects, death effects,
  sounds, energy and Factoriopedia presentation.

The 112 updated Status scene captures are complete. All 16 day/night,
normal/enlarged lamp galleries were visually reviewed across requested directions
0/4/8/12; native direction normalization is recorded. No visible red rims or
fringes remain on green/yellow/orange lenses. The whole refinery screen fits its
dark bezel, and Fission's three and Castor's two small lenses remain readable.
The native pixel check covers **1,072 opaque projected lens regions** with zero
residual-red detections. Manual review additionally covers filtered borders and
the surrounding housing. At night the orange emitter deepens the orange lens
color; the detector distinguishes that from near-pure underlying red.

The Status transition-only graphical pass exits cleanly and writes a fresh
156-check receipt plus all **156 native transition images**. The full transition
gallery was visually reviewed: circuit disable/resume, energy loss/restoration,
output blockage/recovery, and electric shortage/recovery all display their
intended colors without visible disagreement at the lens edges.

The four brightness atlases retain 80 native comparison cases. Current intensity-1
bright-core means are about 236/255, versus approximately 248–255 for the reskinned
assemblers. The dark ribbed Castor pins remain dimmer than the larger lenses;
their existing shape and shading are preserved. Day/night brightness galleries
were reviewed. These methods and physical lens areas differ, so this is a
readability comparison rather than a claim of identical luminance.

The Off comparison passes across **636 lamp regions**: every powered region
contains its expected color, including the HTR and bright smelter effects. All
**92 unpowered regions are pixel-identical to Off**. The maximum measured
powered-color centroid displacement is **1.081 pixels** at native normal zoom,
within the 1.5-pixel limit. The check has no exception for process effects hiding
the added status indication.

Final rendered acceptance passes:

- Main three-mode suite: **1,137 assertions**, **328 native images** (112 Status
  scenes, 56 Original/Off comparisons, 156 transitions and four brightness atlases).
- Smelter suite: **1,464 assertions**, **75 images**, all five arc presets checked
  in final data, plus native default/arc-Off Status and production-Off comparisons.
  Twelve unpowered smelter regions match production Off exactly.
- Arc-Off adds 36 images not already counted in the main suite, for **364 unique
  accepted native images**. Its full body, lamp and transition galleries confirm
  the independent status lamp remains visible with the tagged arc process lights
  disabled. Other authored effects remain present.
- All four final graphical invocations exit cleanly and produce fresh complete
  transition receipts. Status uses the completed scene pass plus the successful
  transition-only pass; Off, Original and arc-Off have complete graphical passes.

Useful evidence under the managed run:

- `review/refinery-whole-screen-native.png`: whole-screen day/night comparison.
- `review/lamps-*-direction-*.png`: all 20 lamp bodies, both zoom levels and all
  requested directions, including their actual native orientation.
- `review/lamp-transitions.png`: all 156 Status transition images.
- `review/native-lens-edges.json` and `review/native-light-pixels.json`: color,
  edge, position and no-power comparisons with capture hashes.
- `review/mode-comparison.png`, `review/off-status-*-bodies.png` and
  `review/off-status-transitions.png`: mode and arc-preset visual comparisons.
- `script-output/machine-lights/{acceptance,bottleneck-acceptance,smelter-acceptance}.json`:
  complete suite receipts.

The fixture freezes private data entrypoints so concurrent unrelated checkout
changes cannot contaminate comparisons. It disables unrelated runtime controls,
adapts recipes only after recording complete final prototypes, and powers the
electric cases through actual isolated networks. Native furnace empty states use
furnace semantics rather than assembler semantics.

Graphical capture serializes large screenshot writes to bound memory use and
requires a fresh final transition receipt. Earlier failed atlas-cache and batched
screenshot attempts are retained as diagnostics, not acceptance evidence.
The original transition capture stopped at Freeplay's intro dialog around tick
720. The fixture now suppresses that modal and exits the initial cutscene;
increasing the graphics frame limit alone did not resolve the pause.

This is focused native lighting acceptance. It does not establish full-mod
runtime integration, multiplayer behavior, or native-speaker approval of locale
wording.

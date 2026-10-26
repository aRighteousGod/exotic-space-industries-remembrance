# Production status light verification

Historical red/green-only acceptance. See [multicolor status and complete lens
coverage](MULTICOLOR-VERIFICATION.md) for the current palette, Bottleneck
integration, guarded masks and whole refinery screen.

Factorio **2.0.77**, ESIR **1.3.41**, active local dependency profile including
Assembler-Reskin **1.0.3**. Shipping profile: radius **0.35**, intensity **1**,
minimum darkness **0.1**, no flicker. Startup default is `status`; alternatives
are `original` and `off`. Mod version was not changed.

## Prototype and state evidence

- **834 focused assertions passed** over the original baseline and three startup
  modes: 25 targets, 17 indicator-bearing bodies, exactly 20 status emitters.
- Original mode is identical to baseline. Off removes exactly the 25 standalone
  plain lights and adds none. Status adds no light to the eight indicatorless bodies.
- Complete prototype comparisons preserve every other field, including animation,
  energy, process lights, death effects, sounds and Factoriopedia presentation.
  Nine present excluded bodies and two excluded absences are also preserved.
- **680 native state/orientation cases per mode**, plus **68 circuit/energy
  transition checks per mode**. Actual directions are compared to baseline;
  Factorio normalizes some requested orientations to north.
- Native low-power cases use undersupplied electrical networks. Burner, fluid,
  and heat machines use their actual energy source and omit electrical low-power.
- **222 native images**: 100 status day/night/normal/double-zoom atlases, 50
  Original/Off comparison atlases, 68 transition images, four brightness atlases.

## Rendered review and brightness

All 25 bodies were reviewed in day/night contact sheets, with enlarged indicator
crops for all four requested directions. Lights agree with the existing indicator
artwork. Fission's three lights and Castor's two remain distinct. The eight bodies
without indicators retain their authored working effects without invented lamps.

Status-versus-Off pixel analysis covers **552 lamp regions**. All **80 no-energy
regions have exactly zero difference**, including bio-reactor `no_fuel` and HTR
`low_temperature`. Every measurable added lamp has the expected color; maximum
isolated-core centroid error is **0.554 pixels** at normal zoom. The HTR's preserved
process illumination masks the extra green halo in this working test scene; its
existing green lens remains visible. Its stopped red glow is separately visible.

Brightness was compared against fully network-powered reskinned AM1/2/3 lamps,
using five representative ESIR bodies at intensities 0.35, 0.5, 0.65, 0.8 and 1.
The **80 comparison cases** retain the reference's native additive sprites/colors.
Intensity **1** is the closest tested match in both red and green. Crusher,
advanced chemical plant and nano factory come particularly close at night; the
smaller/darker Castor artwork remains dimmer. Daytime artwork is unchanged.
The point-light method cannot reproduce additive-sprite brightness exactly.

Transition captures hold each verified state through a render boundary before
changing it. This avoids recording the prior native status beside pixels from
the next state. The corrected 68 rendered snapshots were reviewed: every body
shows red when circuit-disabled, green after resuming, dark after energy loss,
and green after restoration, with the existing artwork in agreement.

## Scope and broader checks

The fixture retains native machine IDs, speed, graphics and energy sources, but
adapts recipes after recording final prototypes and disables other copied runtime
controls. This is focused native lighting acceptance, not a full-mod runtime,
multiplayer or player-save compatibility audit. HTR production recipe tinting is
preserved by the complete prototype comparison; the fixture recipe has no tint.

Repository doctor passed. Preflight's Lua, PowerShell, blueprint, require, locale,
asset-reference, version and header checks passed. Full preflight remains blocked
by unrelated Python cache-path failures and three existing encoding findings:
`scripts/qc/singularity-lance/angular-results.json`,
`temp/anisetron-tracking-fix/blueprint-final.json`, and
`temp/storage-audit-c/evidence-link-update.json`. The new Python files also pass
direct AST parsing without writing bytecode caches.

The broad `qc-fast` staging failed on Windows path length while loading a mining
drill. The focused runner uses the same ESIR wrapper helpers and dependency staging
through a short path; all four native data/create/runtime passes and final graphical
passes succeeded. The staged assets were moved into the lighting run after removing
only its verified temporary junction, preserving their content.

## Reproduction and retained evidence

See [README](README.md) and `scripts/invoke-machine-status-light-qc.ps1`.

- Engine payload: `.factorio-qc/ml-58bb759f`
- Initial managed run: `bc697e08e9ed47d99b0962ddfe1f6ff8`
- Final rendered review: `.factorio-qc/ml-accepted`,
  run `f78082a06410401f891932d35b5ae17b`
- Native prototype/state/image evidence: `script-output/machine-lights/`
- Pixel reports, native lamp galleries and mode/brightness comparisons: `review/`
- Earlier broad QC failure: managed run `4d4db18178b7490bacb6865efbe32e20`

Generated reports and captures remain managed artifacts. Shipping sources contain
no generated sprite assets, runtime handlers, persistent state or migrations.

# Prototype 2 rotor exposure inspection

Rendered 2026-10-10 for the selected exposed-cradle minigun. This supplements the
256-direction handoff; it does not mark the previous native spin gate passed.

## Retained inspection

Open `output/meshy/minigun-prototypes/prototype-2/handoff-256/motion-blur/index.html`.
The gallery has a sharp/90-degree slider at eight compass views, four exposure
strengths at 32 and 64 pixels per tile, and a muzzle/rotor detail comparison.

| Exposure sweep | Inspection use |
| --- | --- |
| 0 degrees | Stopped rotor; individual barrels and front bores remain sharp |
| 36 degrees | Restrained blur; more barrel separation remains visible |
| 90 degrees | Preferred running candidate; visibly rotating envelope, sharp cradle |
| 180 degrees | Heavy alternative; little added readability over 90 degrees |

These are angular sweeps during the exposure, not specified gameplay RPMs.
The 90-degree variant and sharp reference each have eight views. The 36/180-degree
alternatives have the same diagonal view, d=32. Matching ground shadows were
rendered for every image. Presentation composites use 35% shadow alpha only;
the retained raw PNGs and transparent review atlases keep their original alpha.

Actual Cycles rigid motion blur is confined to `BARREL_ROTOR` and
`ROTOR_INTERNAL_ROOT_HUB`. Continuous alignment-times-local-Z quaternion drivers
replace the old modulo-phase driver. Base, aiming upper, fixed liner, camera and
lights are stationary during the centered one-frame exposure. Deformation blur
is disabled; rotor temporal sampling is increased. Original GLB, mesh partition,
UVs, material maps, camera pose and footprint fit are retained.

Blender 5.1.1 / OptiX / 256 samples / fixed seed 0 / 540x540 / 64 pixels per tile.
The saved camera's legacy RNA driver is frozen to the checked 8.4375 orthographic
scale, so reopening the preset with embedded scripts disabled is reproducible.
Both beauty and shadow view layers explicitly enable motion blur.

## Verified

- 18 beauty and 18 matching shadow PNGs; complete expected pose set and SHA256s.
- All images are 540x540 RGBA, nonblank; minimum full-frame alpha margin 19 pixels.
- Existing master crops retain at least six pixels of actual alpha clearance.
- 48 direction/exposure/layer proofs, each evaluated at nine shutter subframes.
- Stationary matrix and rotor-root errors: zero. Maximum axis error 3.23e-7;
  quaternion component error 1.20e-7. Motion changes the rendered rotor in all
  eight directions; matching shadow alpha changes are also measured.
- Both densities' eight-view atlas cells match their source crops or declared
  half-size Lanczos resize exactly. They are inspection sheets, not 256-direction
  production textures.

Visual inspection confirms that blur stays around the barrel group. The rear
drum and aiming cradle retain sharp silhouettes. The 36-degree alternative is
useful if more barrel detail is preferred; 90 degrees gives the clearer running
state. No engine asset load or transition timing was tested in this inspection.

## Activation and stand-down handoff

The user accepts a brief spin-up pause and permits **up to 0.75 seconds if needed
for smooth animation**. Start with 12 ticks / 0.20 seconds; increase only after
reviewing the actual animation. The hard preparation-segment cap is 45 ticks /
0.75 seconds. This changes the earlier exact first-shot parity requirement;
sustained firing cadence and ammo consumption must still remain unchanged.

| Native state | Rendered behavior | Initial duration |
| --- | --- | --- |
| Folded | Stopped rotor at a declared parked phase | Static |
| Preparing | Same-direction acceleration; exposure blur grows with speed | 12 ticks / 0.20 s, conditional cap 45 ticks / 0.75 s |
| Prepared | Running appearance; reuse the selected blurred body | Existing native timing |
| Attacking | Same running appearance, coherent with Prepared | Keep attack speed 20 and existing cooldown |
| Folding | Same-direction deceleration; blur fades to the parked phase | 18 ticks / 0.30 s initially |

Use `preparing_animation` and `folding_animation`. Do not install a spin delay in
`starting_attack_animation`/`ending_attack_animation`: those are part of the
repeating shot cycle. Prepared is also visited between shots, so a sharp stopped
Prepared image would cause flicker. Keep the running appearance there.

Initial prototype proposal, **not applied to shipping Lua**:

```lua
preparing_speed = 1 / 12,
preparing_speed_secondary = 1 / 12,
folding_speed = 1 / 18,
folding_speed_secondary = 1 / 18,
shoot_in_prepare_state = false,
-- Keep attacking_speed = 20 and the existing attack parameters.
```

Set both primary and secondary speeds: secondary defaults are independent of
the corresponding primary value. With a chosen spin-up length N, use 1/N for
both preparing fields; do not stretch the animation merely by adding frames.
The reciprocal speed defines the nominal state duration. Render adequate time
samples over that same duration; begin with one sample per game tick.

The current turret prepares within 35 tiles and fires within 32 tiles. Some
spin-up can therefore finish before enemies enter shooting range. This native
approach spins while alert and decelerates when standing down; it is not an
independent coast timer after every brief interruption in firing.

Author spin-down as a separate forward-playing animation. The old folding
`run_mode="backward"` must not reverse spin-up images: that would reverse the
barrels. Use a smooth nonnegative angular velocity curve, integrate it to get
phase, and preserve phase across endpoints. For normalized time u, a useful
acceleration envelope is `3*u^2 - 2*u^3`; deceleration uses its complement.
Sample the actual transform during each shutter rather than applying image blur.
Register the final stopped phase to the folded pose; test transitions both ways.
Keep the whole upper mechanically stable unless later art review requests a
separate deployment movement. Base stays fixed and yaw remains independent.

The original planned 256-direction / 16-phase continuous attacking atlas remains
held. A running blurred single-frame appearance avoids requiring that independent
attack-state rotor clock. Transition sheets need their own render/packing contract
and budget after timing selection, not automatic promotion of this eight-view set.

Before final export, check native state decoding, nominal prepare duration,
acquisition-to-first-shot delay separately from aiming time, sustained shot and
ammo counts, interrupted activation, target changes during folding, ammo/power
shortages, turn/yaw continuity and native muzzle alignment. Reacquisition should
interrupt/reverse stand-down promptly; current inspection does not prove that.
If the engine cannot meet that behavior, report the native constraint before
adding any runtime scheduler or changing combat.

Authority checked: installed Factorio 2.0.77
`doc-html/prototypes/TurretPrototype.html`, retained final-data/native timing
evidence, and the developer's
[per-shot state-cycle explanation](https://forums.factorio.com/viewtopic.php?p=461686#p461686).

## Reproduce

From the repository root, using the protected prepared scene:

```powershell
powershell -ExecutionPolicy Bypass -File .codex/esir/asset-generators/minigun-turret/invoke-motion-blur.ps1
```

`-Phase Review` rebuilds and verifies the gallery without rerendering. Generators
are durable under `.codex/esir/asset-generators/minigun-turret/`; raw frames,
configuration, measured QA, review atlases and the inspection `.blend` remain
under ignored `output`. These small intermediates are retained inspection
evidence, not disposable caches. No shipping sprites, prototypes or runtime
scripts were changed.

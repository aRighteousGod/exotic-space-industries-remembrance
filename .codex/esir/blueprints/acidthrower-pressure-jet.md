<a id="contract"></a>
# Acidthrower native pressure jet

## Implementation sources

- [acid.lua](../../../exotic-space-industries-remembrance/prototypes/steam-age/acid-turret/acid.lua)
- [pressure-jet.lua](../../../exotic-space-industries-remembrance/prototypes/steam-age/acid-turret/pressure-jet.lua)
- [graphics.lua](../../../exotic-space-industries-remembrance/prototypes/steam-age/acid-turret/graphics.lua)
- [thrower-performance.lua](../../../exotic-space-industries-remembrance/scripts/data-final-updates/thrower-performance.lua)

## Ownership and trajectory

The data-stage module owns the turret stream's liquid presentation and faster
trajectory. [acid.lua](../../../exotic-space-industries-remembrance/prototypes/steam-age/acid-turret/acid.lua)
loads it after registering the turret stream. The pressure module assigns its
complete liquid animation tables before final prototype resolution.
The native engine owns targeting, rotation, emission, flight and impact; this
feature adds no runtime handler, persistent state, migration or public setting.

All revision-03 machine sheets, liquid effects and item/research icons belong to
`exotic-space-industries-remembrance-graphics-6`. Gameplay definitions remain in
the main pack. Only shared ordnance `spark.png` remains in the old Graphics-3
acid-flame folder; active rocket and exotic-ammunition stickers consume it.
The original three machine gun sheets and their superseded animation/model
builders are retired. Construct the turret with its revision-03 graphics before
registration; no transient original sprite tables remain in `acid.lua`.

The legacy handheld/tank streams had no weapon or runtime consumer. Four acid
fires and four smokes formed a disconnected graph; the turret's create-fire
edge was commented out, and the sticker's acid-spread fields were unsupported.
Those prototypes, their helper module and four flame sheets are retired. The
administrator's generic fire catalogue consequently drops those old choices;
any manually created transient instances disappear on reload. Current turret
stream/sticker identities and performance aliases remain unchanged.

Horizontal speed and aim-leading speed are both 0.85 tile/tick. Vertical
acceleration is 0.00025, speed deviation 0.0015, target deviation zero and ribbon
width 0.1. Supported `particle_scale_per_part=1` replaces the obsolete
`particle_end_scale` assignment on the turret stream. The jet uses normal
blending, wet highlights and separate shadows without an added area light.

The existing 9–38 tile range, 96-degree aiming sector, rotation speed, machine
graphics, placement shifts, secondary draw order, sound and active-only machine
glow remain owned by the existing turret definition and graphics module.

The native muzzle now uses barrel length 0.835 and projected height
`0.87555 * sqrt(0.5)`. Independent shipping-atlas outlet measurements and native
source markers drive this small lip/height correction; model anchors alone do
not establish visible alignment. Bearing and placement shifts remain unchanged.

<a id='dispersion'></a>
## Downrange liquid breakup and wet corrosion

The original narrow connected ribbon remains intact. Native scale/playback
probes did not establish reliable travel-age widening: scale-per-part changed
the relative sizes inside an emitted burst rather than providing the desired
downrange envelope. Therefore the stream starts cosmetic trivial-smoke flecks
at projectile progress 0.35. The normal-blend animation contains separated wet
beads, not smoke artwork. The 12-tick effect has no wind, movement, vertical
velocity, light, action or damage. Its source frequency is 0.8 under Original,
divided by the existing late performance factor. No damaging emission is added.
The ordinary smoke-quality graphics opt-out remains active. Sparse segments and
visual clipping are acceptable at higher performance factors; never increase
cosmetic density or runtime work to conceal them.

`ei-acid-sticker` keeps its existing identity and payload, but uses the base-game
50-frame wet acid sticker at scale 0.5 and animation speed 0.5, with an olive-green
tint and no glow. Private performance
aliases inherit the finished source animation without changing refresh/stacking.

<a id="impact-cadence"></a>
## Impact cadence and payload

Keep spawn interval, timeout, buffer, fluid consumption per second, damage
upgrades, fluid modifiers, the radius-three area action and its corrosion sticker
unchanged. `initial_action` must remain absent: a nonempty value replaces the
first particle's ordinary impact action. Each native particle retains its area
damage and sticker refresh. A sibling direct action has a 25 percent chance of
creating a brief cosmetic liquid splash once per landing, independently of how
many victims the area action affects. The splash has no damage, light, fire or
persistent puddle. Do not add damaging particles to fill visual gaps.

<a id="late-profiles"></a>
## Late performance-profile ownership

[thrower-performance.lua](../../../exotic-space-industries-remembrance/scripts/data-final-updates/thrower-performance.lua)
remains the late owner of cadence, per-particle damage, sticker and fluid-use
scaling for Original, 2x, 4x, 8x and 16x. It clones the finished source stream into
the existing resolved/private aliases. Pressure-jet changes must precede that
pass and preserve stream names. Higher profiles retain their deliberate sparse
emission; cosmetics must not undo their density/performance tradeoff.

The same late pass owns existing native flamethrower and fuel-variant thinning:
multiply turret cooldown, per-refresh fluid and damaging-particle interval by
the selected factor, compensate per-particle damage, and cap/co-scale sticker
damage intervals. It walks only the selected turret impact graph and thins smoke
without changing ground-fire DPS or research/quality multipliers. Shared effects
receive private aliases; exclusive fuel effects can be transformed directly.
This pressure-jet revision changes only the acidthrower's refresh exception below.

At 8x/16x only, an approved compatibility correction halves attack-refresh
cooldown and fluid per refresh after the pass has computed the existing timeout.
Cooldowns are 16/32 ticks, consumption 4/8 units, particle intervals 16/32 and
timeouts 48/96. Native tests show a short-flight stream can retire before its next
sparse particle; refreshing at the intended particle cadence prevents lost
impacts without increasing the configured particle count or fluid/second.
Cosmetic fade/animation lifetime changes did not correct this engine behavior.
This also restores a pre-existing 16x minimum-range underdelivery: direct damage
there approximately doubles, while unchanged corrosion reduces the proportional
combined-DPS increase. Record that correction separately from ordinary parity.

## Verification

`scripts/invoke-acid-jet-qc.ps1` runs isolated Factorio 2.0.77 fixtures on D:.
Its helper exports a focused final-data snapshot through `mod-data`, including
source, resolved and alias streams, turret, sticker and retained poison fallback.
It asserts the absence of the ten retired legacy fire/smoke/stream prototypes. It compares old/new native flight, stationary damage and fluid use
with a 1,800-tick warm-up and 7,200-tick measurement, all four acid fluids, normal
and legendary quality, and two research modifier combinations. Direct damage,
corrosion and combined payload are measured separately.

The dispersion-02 fixture freezes the approved FINAL pressure-jet definition and
its 64-pixel ribbon in a helper-only baseline, rather than reconstructing the old
lobbed flame. Both sides include the approved 8x/16x refresh fix. Flight parity
allows one tick for the small physical muzzle correction; damage/fluid parity
has no legacy restoration exception. Small/large/moving sticker fixtures check
refresh and expiry after the final landing plus the 900-tick lifetime.

Visual fixtures cover four placement facings, nominal ranges 9/24/38, centre and
sector edges, daylight/night, moving targets, retargeting and shutdown. Tiny
inward range/angle tolerances and actual target/launch coordinates are recorded;
nominal edge labels must not conceal non-firing cases. Source script effects
mark stream creation, not every particle emission; flight uses first launch to
first landing and shutdown uses the last landing after emission stops.

`scripts/invoke-acid-art-qc.ps1` supplies the separate machine regression for
muzzle attachment, fine rotation, active glow and adjacent-pipe draw order.
The asset generator dossier records native width/bow measurements, unchanged
seven machine-image hashes, effect generation, gallery and replay commands.

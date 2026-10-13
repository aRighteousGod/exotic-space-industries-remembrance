# Minigun receiver casing ejection

Main and standalone use a short native gun-right/rear discharge and private
four-second casing particles. The graphics factory API is unchanged. No turret
render, ammunition payload, runtime controller or combat balance change is part
of this patch.

The later placement-box centering adjustment adds `6/32` screen-space tiles south
to every sprite/shadow and launch-map entry. Normal shell emission inherits that
translated launch origin, so the receiver-relative parameters below remain
unchanged. The original render-anchor measurements and casing evidence stay as
historical calibration; the centering dossier retains the native before/after.

## Geometry and native offset

Canonical coordinates are tiles from the common ground/yaw anchor, forward +Y,
right +X. The outlet `(0.43,-0.85,1.65)` sits on the lower outer right receiver
lip, behind the cradle arm and forward of the rear drum. Actual mesh intersection
at its Y/Z gives outer X `0.4277628829`; the outlet is just outside that surface.
It is a designated visual outlet, not a separately modeled opening.

Pre-fit Blender source: `(0.3375917639,0.1714817159,0.1552841770)`.
Projection relative to ground for render angle phi is:

```text
x = 0.43*cos(phi) - 0.85*sin(phi)
y = (0.43*sin(phi) + 0.85*cos(phi) - 1.65)/sqrt(2)
native heading = atan2(sqrt(2)*sin(phi), cos(phi))
```

Native normal-mode shell origin inherits the approved projectile launch
reference. Its canonical lateral/forward coefficients are `0.05811459943652153`
and `2.460180041633924`, with constant screen-height offset
`0.2478458238638983`. Move by right `0.37188540056347846`, forward
`-3.310180041633924`, and add screen height `0.918880365093905`.
The resulting native radius/orientation are below. Do not replace them with the
receiver's radius about the bearing: that would leave casings near the barrels.

| Native field | Value |
| --- | --- |
| direction | `105/360` |
| direction_deviation | `0.025` |
| speed / speed_deviation | `0.06` / `0.008` |
| center | `{0,0}` |
| creation_distance | `3.331004451991` |
| creation_distance_orientation | `0.482194244912` |
| use_source_position | `false` |
| height / vertical_speed | `0.918880365094` / `0.01` |
| starting_frame_speed / deviation | `0.2` / `0.04` |

The measured quarter-turn offset establishes orientation fractions for creation
offsets. The API does not document the shell deviation's distribution; treat its
small value as the native-tested visual spread, not an unverified degree formula.
`use_source_position=true` triggered installed 2.0.77
`ProjectileShootingLogic::tryCreatingParticle` / `Optional.hpp` in probe002.
Normal mode was verified without a runtime workaround.

## Particle ownership

`ei-gatling-shell-particle` belongs to main. The standalone
`minigun-turret-hd-shell-particle` is created only when main is absent. Both copy
the vanilla optimized particle and change only name, `life_time=240`,
`fade_away_duration=60`, and `movement_modifier_when_on_ground=0.6`. Pictures,
shadows, gravity, render layers and water behavior are preserved. Native shots
own emission; rotor states do not emit independently.

## Focused evidence and reproduction

Retained dossier: `output/minigun-implementation/casing-ejection-001/`.
`invoke-probe.ps1` establishes offset/height behavior against a frozen colored
native particle; `analyze_probe.py` measures the eight outlets. Probe004 maximum
error is `1.248876` SD pixels, including native aiming/quantization. All eight
markers were found and each turret fired one shot.

`invoke-final.ps1` exercises the actual gameplay owners, normal native casing
art, eight headings, three magazine types, first shots, a turning burst,
stand-down and disappearance. A fixture-only single-shot colored particle
provides a trajectory. `analyze_final.py` checks all 256 launch coordinates,
launch fields, unchanged combat data and the steady ammunition window. Factorio
JSON decimals differ from source floats by at most rounding; source graphics
metadata and PNGs remain unchanged.

The standalone run records eight times 54 shots per 60 ticks with full bullet
damage. Its single marker settles by roughly 30 ticks and remains stationary
through tick 35. The selected ground particle fades over its final 60 ticks.
Final main case results, images, hashes and archive sizes are retained in
`acceptance.json` and `package-report.json`; consult these before claiming a case
passed. The existing full 256-direction muzzle evidence remains authoritative;
this cosmetic patch does not repeat that production matrix.

Concurrent working-tree Lance references prevented an unrelated graphics load.
Native main test source is the committed `001559f` baseline plus the scoped
casing prototype and changelog. Graphics1–5 use complete installed archive
snapshots; Graphics6 uses the committed snapshot. `main-export.json` records this
test source choice.

Shipping ZIPs in `packages-complete/` are a frozen current-worktree snapshot:
thin main, complete current Graphics6 and HD. Install the thin main together with
this Graphics6 ZIP; the earlier minigun-only Graphics6 archive is insufficient.
Package membership, hashes and exact sizes are recorded in `package-report.json`.
The casing evidence does not establish a new whole-mod verdict for unrelated
concurrent asset relocation. Other edits remain intact. ZIPs are staged for later
installation; this patch has not been committed.

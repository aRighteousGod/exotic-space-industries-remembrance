# Native eight-direction acidthrower acceptance

This is the current Factorio **2.1.23 / ESIR 1.4.1** fixture. The older
`acid-art` and `acid-jet` calibration fixtures retain their historical contracts;
the art wrapper routes here by default and the jet wrapper requires explicit
`-LegacyReplay`. Nothing in this directory is loaded by the shipping mod.

From the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-acid-eight-way-qc.ps1 `
  -RunRoot output/acidthrower-eight-way-qc `
  -FactorioPath 'C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe' `
  -SeedMods .factorio-qc/dependency-seeds/2.1-core `
  -BaselineRoot .factorio-qc/acid8-20261028
```

The runner verifies the executable, installed base version and pinned dependency
lock. It sets the Steam application environment only for its child processes.
Generated outputs are registered with housekeeping. Use `D:/ESIR/output` only
when C: capacity requires overflow. Source packs are junctions; dependency
archives and the private helper are staged. Never run runtime-isolation tools
that rewrite controls against those source junctions.

`-Suite` selects `all`, `accept`, `visual`, `player`, `legacy`, `layouts` or
`profiles`. `all` includes the graphical suites and profile parity.
`-GraphicsQuality high` is the default; medium captures must be labelled as such.
The profile baseline is deliberately a retained **pre-change** snapshot, not a
fresh export of the implementation being tested. It contains `probe` (Original),
`baseline-2x/4x/8x/16x`, and `baseline/machine-hashes.json`.

| Suite | Native contract |
| --- | --- |
| `accept` | 32 port masks, real connected entities, supply/private-buffer mass, removal/reconnection, vanilla rotation parity, 16 fast replacements, 72 source/damage/fluid-use cases |
| `visual` | The same assertions, day/night ports and states, moving aiming, native death, authored Factoriopedia scene content, save/reload and image review |
| `player` | Eight cursor placements, 128 individually checked rotated/mirrored blueprint turret ghosts, actual robot construction, wire/settings/quality/fluid persistence on 144 bodies |
| `legacy` | A real four-way save loaded with the eight-way prototype; four original cardinal bodies, unit identities, positions, health, quality, fluid and circuit targets preserved |
| `layouts` | Ordinary pipe branches, connected-segment transfer through each turret, nearby walls, daylight/night captures |
| `profiles` | Original/2x/4x/8x/16x complete final-turret/effect parity after removing only the approved eight-way fields; original seven PNG hashes |

Target positions use off-grid stationary unit prototypes at actual radii
9.2, 24 and 37.8, at -47.9, 0 and +47.9 degrees relative to placement. A
grid-snapped building target invalidates the boundary cases. Target health is
one million, which retains small acid damage increments. Native damage events
and health loss are both recorded. `consumed` measures loss from the sum of both
fluid stores before replenishment, so internal supply-to-firing transfers cancel.
This is not a sustained fluid/second benchmark. Complete final-data equality
separately preserves the configured consumption.

Native stream creation aims from the shifted gun center to the actual target.
`LuaEntity.orientation` points from the entity origin and is not an exact source
position reference when the gun is offset. Source events mark stream creation,
not every emitted particle. The source tolerance is one native pixel (1/32 tile).
The reviewer separately matches the visible 256-frame head and measures green
liquid pixels. It retains the accepted 32px ribbon's intermittent phase gaps.

Native placed rotation follows the vanilla rectangular flamethrower: the tested
`rotate()` sequences reverse by 180 degrees. Cursor placement and blueprints
provide all eight headings; this fixture does not substitute scripted 45-degree
rotation for engine behavior.

`review.py` produces native/enlarged port contact sheets, day/night comparisons,
eight aiming animations, state animations, source/outlet marker images and
`visible-outlet.json`. The authored Factoriopedia scene capture is scene-content
validation, not full GUI automation. Sounds are compared in final data; the
graphical runner disables audio playback.

Implementation evidence is retained under
`D:/ESIR/output/acidthrower-eight-way-20261028`, with the source/baseline registry
at `.factorio-qc/acid8-20261028`. See the generator's
`EIGHT-WAY-ACCEPTANCE.md` for completed receipts and review boundaries.

# Approved sweeping radar art

Final user selection, 2026-09-28: **#1 / E1 Split-Trough Watcher** is the earlier Electricity Age `ei-sweeping-radar`; **#8 / S4 Fourfold Interrogator** is the Simulation Age `ei-phased-array-radar`. The user replaced #3 with #1 after generation had begun. #3 is retained only as a superseded source. Concept titles are development labels, not new entity names.

Both must have actual mechanical rotation. The user also requested glow on #8's red core indicator and white panel faces, and authorized maximum-detail Meshy generation. These production amendments take precedence over the original static-array S4 prompt.

## Earlier Sweeping Radar

Preserve the broad split parabolic trough, coarse copper mesh, riveted ribs, heavy central receiver spine, U-shaped cradle and exposed ring gear. Dark steel, oxidized copper, ceramic insulators and the small amber indicator retain the selected identity.

The trough, central receiver spine, cradle and upper turntable rotate as one rigid assembly about the vertical bearing. The lower plinth, feet, drive housing, transformer, insulators and external connections stay fixed. Use a shaft/slip-ring connection so repeated revolutions do not wind cables around the base. Preserve the trough's center split and broad ribs; simplify fine details only where gameplay readability requires it.

## Later Phased-Array Radar

Preserve four upright tiled antenna panels, their open cross arrangement, copper cooling edges, armored central hub and stepped foundation. The pale faces must distinguish this tier with glow off.

All four panels, radial support arms and the upper central hub rotate together. The lower foundation, visible base wires, cable runs, feet and external connections remain stationary. Put a bearing/slip-ring seam above the wired base. Rework panel-to-base braces as upper supports with clearance over the fixed base; moving panels cannot remain attached to fixed feet. Check the entire swept envelope.

Create separate red-core and white-panel emissive groups, both following the rotor. White glow should retain tile divisions; use stronger red emission at the core. Keep frames, copper fins, backing, wires and base out of glow masks. Match body, shadow and emission transforms, origin, scale and frame ordering.

## Production and runtime

- Preserve a 3x3 footprint and fixed-base wire connection points. Check both rotors through a full revolution.
- The existing overlay remains the precise completed-observation heading indicator. Actual body rotation must be implemented and tested; the current placeholder has native rotation disabled.
- Factorio 2.0.77 fixture result: writable entity orientation does not turn the disabled shell. Frozen-frame `rendering.draw_animation` does display selected headings while the shell stays disabled. Use that mechanism through the existing bounded radar service for the eventual sprite integration. Do not rotate a flat isometric sprite in screen space or re-enable native scanning/wireless coupling.
- Verify pause, fixed-bearing, reversal, power loss and save/reload. Powered #8 emission goes dark when unpowered. A preview loop verifies geometry only, not runtime synchronization.
- Use the local Factorio preset, upper-left lighting, separate lower-right shadows and unclipped alpha margins. Separate body, shadow, emission and any neutral owner trim.
- Preserve raw high-detail models, reusable scripts and requests. Check gameplay-scale readability, daylight/nighttime appearance and raw-frame versus packed-sheet color/alpha fidelity before shipping integration.

## Generation

Explicit Meshy 7.1, 4K geometry, 8K base color, PBR enabled, no remesh, GLB output. User authorization: "you are cleared to pull assets from meshy with maximum detail generation". Generation: three tasks at 40 credits each (120 total), including the superseded #3 already running when the user selected #1. Pricing checked against official documentation on 2026-09-28.

Meshy 7.1 does not produce emission maps. Build #8's requested glow in Blender. Geometry separation and mechanical clearance need local inspection even when the generated shape resembles the concept.

References are unchanged copies of the selected 1254x1254 RGB images. Preserve original prompts as historical provenance alongside the approved motion amendments above.

## Prepared models

Both selected GLBs are downloaded. Local Blender preparation separates fixed base geometry from the rotating upper assembly, preserves original triangles and UVs, and adds bearing geometry. #8 includes separate white-panel and red-core emission. Sources, inspection reports, animated `.blend` files, and eight-angle preset review renders are staged under `output/meshy/sweeping-radar/` and `output/meshy/phased-array-radar/`.

Reproducible preparation/render/check scripts and limitations are documented in `.codex/esir/asset-generators/sweeping-radar/README.md`. The review gallery is `output/meshy/radar-production/index.html`. These model artifacts are separate from final production sprites and live in-game integration; the shipping radar art is still the native placeholder.

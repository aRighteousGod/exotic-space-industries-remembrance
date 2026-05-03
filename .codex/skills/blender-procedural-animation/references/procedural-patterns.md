# Procedural Animation Patterns

## ESIR Motion Language

- **Machine**: counter-rotating rings, indexed plates, pulsing cores, restrained oscillation, slow industrial rhythm.
- **Crystal**: float, slow spin, inner light pulse, sharp silhouette, no frantic wobble.
- **Gate**: opening/closing side masses, rotating threshold rings, core flare at midpoint.
- **Orbital**: satellites, halos, arcing motes, clockwork rotation with a readable center.
- **Reactor**: core breathing, containment ring rotation, asymmetrical flicker kept subtle.
- **Drone/prop**: hover bob, slow yaw, secondary fins or emitters moving independently.

Favor a few strong motions over many tiny ones. The animation must survive being scaled down to Factorio entity size.

## Factorio Lighting And Shadows

Default Factorio-compatible render assumptions:

- Key light reads as coming from the sprite's upper-left.
- Lit surfaces should not flip direction across frames.
- Draft shadows fall lower-right from the visible object.
- Shadows should be separate sheets whenever practical, then wired with `draw_as_shadow`.
- Glow or light overlays should be separate from shadow layers; Factorio sprite definitions only allow one of `draw_as_shadow`, `draw_as_glow`, and `draw_as_light` on a layer.

For directional sheets, prefer object rotation over camera orbit when the goal is an in-game rotated entity. This keeps the screen-space light and shadow direction stable while the object turns.

The bundled renderer defaults to `--direction-mode rotate-object`, screen-space upper-left key lighting, and optional generated lower-right shadow sheets.

## Local Factorio Rendering Preset

The repo root includes `factorioRenderingPreset_v4.blend` and `Render.zip`, and the saved Notion guide is at `C:\Users\Theorun\Documents\3D model to Factorio sprites v2 _ Notion.htm`.

Use the preset for maximum-fidelity manual Blender work:

- Move the main mesh into `Object > Normal`.
- Keep the preset's `Scene` collection intact.
- Leave or scale `Ground Dirt` when it helps scattered ground contact and shadows.
- Put object light sources under `Lights on`; exclude sun lights from this collection.
- Put pipes in `Pipe` when the machine uses the preset pipe helpers.
- Change canvas size through the preset UI: Factorio sidebar > `Orthographic Scale` and tile size > `Set Resolution`. Do not hand-edit camera resolution first.
- Test export with `F12` and reduce ortho scale/canvas as much as possible without clipping shadow or glow.
- For repo-compatible compositor output, save the `.blend` under a repo `blender` folder and point output paths to `///Render/{export_type}`.

Glow and light pass notes:

- Add Point/Area/etc. lights, place them under `Lights on`, and assign their Light Group to `Lights`; otherwise they may appear in the viewport but not in the exported light/glow passes.
- Warm yellow/red glow tends to read well for Factorio machines.
- Toggle the preset's `Lighting` collection visibility to preview how the object will read at night.
- Keep glow/light sheets separate from base and shadow sheets so the exporter can emit `draw_as_glow` or `draw_as_light` layers.

Animation notes from the guide:

- Group moving objects before animating; select dependent objects first, main object last, then parent with Object (Keep Transform).
- For simple rotating parts, set frame end, keyframe the first frame, then keyframe the final frame just before the duplicated loop value. Factorio loops cleaner when the last frame is not identical to frame one.
- The guide's machine example uses `frame_count = 128`, `line_length = 8`, `animation_speed = 0.1`, base + shadow + additive glow layers.
- Factorio water reflection supports only limited frames in practice; keep water reflection static or short and do not rely on animated water reflection for machine motion.

Directional/unit animation:

- Recommended direction counts are 16 or 32 for unit-like sprites; base-game biters use 16.
- Shadows and water reflection usually do not need full animation because the motion is barely visible at scale.
- The guide's directional driver pattern is `radians(-initial_angle - ((frame - 1) // frame_count) * 360 / direction_count)`.
- Loop the object animation in Graph Editor after copying the first key to the next cycle and applying cyclic extrapolation.
- Disable unused compositor outputs before long exports.

## Object Naming Hints

The bundled renderer understands these object-name fragments:

- `core`, `glow`, `crystal`: pulse scale.
- `ring`, `halo`, `rotor`, `blade`: rotate around local Z.
- `orbiter`, `satellite`, `mote`: orbit around the scene center.
- `left`, `right`, `gate`: gate preset moves side objects outward and inward.

For imported GLBs, rename objects in Blender or through Blender MCP before rendering if you want targeted procedural motion. If no names match, presets fall back to whole-asset motion.

## Sheet Layout

Default animation layout is frame-major:

- `frames`: animation frames per direction.
- `directions`: camera directions.
- `columns`: defaults to `frames`, producing one row per direction.

For a simple Factorio working animation, use `directions = 1`, `frames = 16`, `columns = 4`, then pass `--working-frame-count 16 --working-line-length 4` to `$esir-factorio-asset-export`.

For rotated/directional drafts, use `directions = 4` or `8`, inspect the manifest, and expect hand-tuning before wiring.

## Blender MCP Tuning Loop

Use Blender MCP when the first sheet is close but needs human-looking composition:

1. Open Blender normally.
2. Connect the BlenderMCP add-on.
3. Import or create the asset.
4. Rename important parts with the naming hints above.
5. Save a `.blend` under `output/meshy/<asset>/`.
6. Run the deterministic background renderer from the saved scene or source model.

## Factorio Export Handoff

The renderer does not copy into the mod. After inspection, use `$esir-factorio-asset-export` to stage snippets and previews. Only wire into ESIR graphics/prototypes after explicit approval.

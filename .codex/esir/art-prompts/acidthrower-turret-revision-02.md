# Acidthrower revision 02 design decisions

2026-10-08. Implements the approved recessed rear tanks / pressure-jet head plan with the user's later clarifications.

- Use the refined upper-only pressure-monitor reference. A first 40-credit revision 02 generation had already started when the user requested a more considered image; the user then explicitly approved another 40 credits and selected the refined head. Preserve both sources.
- Build a new base. Retain the existing footprint: **2 across × 3 front-to-back relative to the nozzle**, appearing 3×2 for east/west placement. Do not reinterpret this as a gameplay footprint change.
- Put two identical short upright canisters, partly recessed, in the fixed rear bed. Keep their clamps and plumbing fixed with the base export.
- Make exterior pipe collars exactly symmetric in geometry, size, height, placement and outward orientation. Construct once and mirror in Blender. Align to existing west/east fluid-grid connections.
- Only the low bearing, pressure housing and nozzle rotate through the existing ±48° arc. Feed the moving housing through a central rotary union.
- Use an actual open small ceramic orifice, a tapered steel sleeve and substantial retaining coupling. Preserve the selected head's trunnion/cradle identity.
- Material palette: weathered gunmetal, olive-grey steel, dirty ivory, restrained acid green. Keep a separate neutral owner-colour region; exporting and wiring its mask is a later step.
- Stage at `D:/CodexArtifacts/esir-acidthrower-20261008/revision-02`. Preserve revision 01.
- Deliver complete/base/head GLBs, editable Blender, recorded anchors, centred four-facing gallery, native-size comparison, close-ups and a restricted forward-arc animation.
- This iteration ends at model/render review. The firing flash, old sprite alignment, deployment animation and production integration follow the model choice.

The exact two image prompts accompany this note in `acidthrower-turret-revision-02-initial.md` and `acidthrower-turret-revision-02-refined.md`. Durable replay generators and measured QA notes are in `../asset-generators/acidthrower-turret/revision-02/README.md`.

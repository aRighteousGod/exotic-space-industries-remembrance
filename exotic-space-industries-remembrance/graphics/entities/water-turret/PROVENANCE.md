# Water turret

Original ESIR asset: selected concept 9, PIPEWORK BASTION, light blue/teal palette.
Reference art was generated with built-in image generation. Meshy 7.1 generated
the textured source model with 4K geometry, 8K texture option and PBR, at a cost
of 40 credits. Task: `01a0dbbe-601e-7336-8d16-33d112e20d1a`.

Blender preparation separates the fixed lower plinth from the complete rotating
platform, head, backpack and internal pipe. A narrow machined bearing joint and
neutral owner trim were added. External pipe collars use Factorio's own runtime
fluidbox graphics; those images are referenced from `__base__`, not copied here.

Rendered through `factorioRenderingPreset_v4.blend`: 4 base directions, 64 head
directions, independent shadows and neutral force-color mask. Shared 576px
frames, 64px per tile, scale 0.5. The shipping sheets are packed from original
frames to preserve their color values. Item icon: 128/64/32 mips; research: 256px.

Replay scripts, selected reference, prompts and coordinate notes are in
`.codex/esir/asset-generators/water-turret/` and
`.codex/esir/art-prompts/water-turret/`. The original GLB and full task metadata
remain under ignored `output/meshy/water-turret/source/`.
Source GLB SHA-256: `f9b54cc4a846b840491bed74b77aff1fc8f99534685aca114c26b439e8819c7a`.

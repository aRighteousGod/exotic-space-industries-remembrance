# Seasonal Ecology launcher

Four generated transparent illustrations share the summer mechanical-tree design:
copper gears, articulated roots and trunk, enamel leaves, turquoise reactor core.
The art direction is ESIR industrial machinery with saturated ecological color.
These are GUI sprites, not entities; they have no world shadow, death effects,
sounds, item/recipe icon, or Factoriopedia presentation.

Built-in imagegen generated the summer source and edited its leaves for the other
seasons. The edits preserve the visual silhouette, not pixel-identical geometry.
Do not independently crop or auto-fit the sources. All use the original 1254 x 1254
canvas and one common Lanczos reduction to 128 x 128. No semantic postprocessing,
recoloring, palette quantization or background removal is used during export.

## Sources and reproduction

Protected source dossier: `output/meshy/ecology-season-button/sources/`, containing
`spring.png`, `summer.png`, `autumn.png`, `winter.png`. Task registry
`a09dbf7b539f45bf92487eede7a795b1` preserves that evidence. Exact source hashes:

- Spring: `d907fb44b477be0b28b2d2669aade3fb1e4010217437ac5fc6a9d95b3a04cf11`
- Summer: `77846580bf444dda94474ba93c81201bfbc447d8735b738672743600913a1bd4`
- Autumn: `c96e5795f4c04df0decff4999b18de7eee57db37183709425ac0d480a95185d6`
- Winter: `b8f05fad8a9fc671ebc62dab2deca21a1689689802e43431e55f5959c9141647`

```powershell
python .codex/esir/asset-generators/ecology-season-button/prepare.py --source output/meshy/ecology-season-button/sources --output output/meshy/ecology-season-button/factorio-export
```

The explicit `--promote exotic-space-industries-remembrance-graphics-6/graphics/gui`
option copies only the four reviewed sprites. No old shipping tree artwork is
superseded. Previews and alternate concepts remain outside mod packs. Output
manifest records source/export hashes and alpha bounds; the preview includes
32 px toolbar mockups. All four have 3-4 px solid-alpha margins at 128 px.
`prototypes/terrain-evolution.lua` owns their startup-gated sprite registrations.

## Exact seasonal edit prompts

Each built-in edit referenced the summer source, with `transparent_background=true`.
The following common prompt was followed by one seasonal paragraph:

```text
Use case: precise-object-edit.
Asset type: transparent mechanical-tree seasonal GUI launcher sprite for Factorio.
Input image 1 is the exact edit target, the existing summer tree. Produce one isolated tree, preserving the original canvas dimensions, framing and transparent alpha background.
Change ONLY the enamel color painted on the existing metal leaves. Keep the exact leaf count, shapes, positions, overlap, contours, rivets, metal edging, weathering, texture, highlights and shadows. Preserve exactly the tree geometry and silhouette, copper trunk, branches, roots, copper gears and screws, dark mechanical joints and tubing, glowing turquoise core, camera, lighting, crop and scale. This must be a recolor of the same tree, not a redesign. Do not modify or recolor any non-leaf component. No ground, backdrop, text, symbols, added objects, snow, frost or icicles.
```

Spring:

```text
Spring leaf enamel palette: bright fresh lime and chartreuse greens, with vivid yellow-green lit areas and rich green shaded areas. Make the existing leaves noticeably fresher and lighter than the summer emerald palette, while retaining all surface texture and dimensional shading.
```

Autumn:

```text
Autumn leaf enamel palette: saturated amber, orange and scarlet, with warm golden-orange lit areas and deep red shaded areas. Recolor every existing green enamel leaf into this autumn palette; retain all surface texture and dimensional shading.
```

Winter:

```text
Winter leaf enamel palette: saturated cyan, ice blue and indigo, with luminous icy-blue lit areas and rich cobalt/indigo shaded areas. Keep the leaves opaque painted metal with all original texture and dimensional shading. NO snow, frost, icicles, white coating, leaf loss or added winter scenery.
```

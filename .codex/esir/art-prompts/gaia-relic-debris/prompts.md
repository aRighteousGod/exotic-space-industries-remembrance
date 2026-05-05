# Gaia Relic Debris Art Prompts

## Recommended Workflow
- Use GPT/image generation for concept art and clean source illustration, not for a final Factorio-ready sprite sheet in one step.
- Best path: generate a strong item-icon concept and a high-resolution top-down salvage cluster, then paint over or cut down into the final `8 x 8` resource sheet manually.
- Keep the current in-repo placeholder art for now so the prototype loads and we can iterate on gameplay independently from final art.

## Visual Direction
- Theme: drowned crystalline infrastructure, not rusty industrial junk.
- Read: ancient machine remains fused with Gaia crystal growth and morphium staining.
- Palette: oxidized seafoam, pale jade, cold blue-white crystal, muted charcoal metal, small morphium-violet edge glow.
- Material mix: broken relay rings, carved circuit ribs, corroded panels, vine-like cable bundles, crystal accretions, wet mineral bloom.
- Mood: sacred ruin, shoreline wreckage, buried planetary memory.

## Item Icon Prompt
Create a clean game item icon for "Gaia relic debris", shown as a compact top-down salvage emblem made from a broken alien relay ring wrapped around a pale blue-white crystal shard, with oxidized seafoam metal, dark charcoal structure, subtle morphium-violet glow in cracks, crisp silhouette, transparent background, high contrast, readable at small size, premium strategy game icon, no text, no border, no UI frame.

## Resource Patch Prompt
Create a top-down game resource illustration for "Gaia relic debris", a salvage patch made of scattered alien machine wreckage half embedded in wet stone and crystal growth, broken relay segments, ribbed mechanical panels, cable bundles, mineral crust, seafoam and jade oxidation, pale energy crystal shards, faint violet contamination glow near edges, readable silhouettes, grounded shadows, consistent top-down lighting, suitable as source art for a Factorio-style mined resource patch, transparent background.

## Negative Guidance
- Avoid rusty orange scrapyard colors.
- Avoid human junkpile props like tires, barrels, or sheet-metal trash.
- Avoid cartoon saturation.
- Avoid side-view perspective.
- Avoid dense foliage; this is relic salvage, not a plant patch.

## Sprite Conversion Notes
- Final resource sheet target in this mod is `128` sprite size with `8` frames and `8` variations on a `1024 x 1024` sheet.
- Strongest approach is to generate 3 to 6 distinct salvage cluster concepts, then downscale, simplify, and arrange them into the sheet with hand-tuned silhouette cleanup.
- Favor large readable masses over tiny detail, because Gaia terrain already adds surrounding texture.

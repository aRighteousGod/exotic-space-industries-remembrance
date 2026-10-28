# Authored recipe economy and engine-version parity

<a id="contract"></a>
## Contract

ESIR's vanilla recipe patches retain their authored ingredients, output counts,
duration, categories and progression while adopting the 2.1 product schema.
Engine-default changes must not silently alter an ESIR batch's throughput or
quality eligibility. The explicit crystal-return correction is documented in the
upgrade synopsis and does not change unrelated random byproducts.

## Implementation sources

- [Vanilla recipe replacements and alternatives](../../../exotic-space-industries-remembrance/scripts/data-updates/vanilla-updates/recipes.lua)
- [Rigor crystal-return selection](../../../exotic-space-industries-remembrance/scripts/data-updates/rigor-crystal-returns.lua)
- [Final optional productivity routing](../../../exotic-space-industries-remembrance/scripts/data-final-updates/compatibility.lua)
- [Inherited core recipe fluid sizing](../../../exotic-space-industries-remembrance/scripts/data-final-updates/recipe-buffer-sizing.lua)

<a id="muluna-rockets"></a>
## Muluna rocket productivity

Muluna can replace the vanilla productivity technology and regenerate its effects
from all recipes producing `rocket-part`. ESIR's silo recipe only consumes an
already-manufactured ESIR part. After Muluna's generator, final compatibility moves
that recipe's productivity effect to the four ESIR part-manufacturing routes,
preserving the technology's change value and effect metadata. Existing effects on
those routes are retained without duplication. Other Muluna rocket recipes and
its progression remain unchanged. This avoids losing the four authored routes or
applying the same bonus again at the silo. No runtime state or locale key is added.

<a id="crystal-rigor"></a>
## Crystal returns and generated Rigor recipes

Rigor Module is a transitive Muluna dependency. Its native selector would choose
the rare depleted-crystal return and rescale the shared ranges, changing the
approved probabilities. Before its final generation, ESIR excludes the two
returned crystals from candidate selection and calls Rigor's own selector on the
remaining products. A suitable unrelated random product remains eligible through
`rigor_product`; a recipe with no such product uses `rigor_blacklist`. Resource
crystal drops that do not consume a high-energy crystal are untouched.
All generated return pairs must retain their source split and productivity
exclusion, including the two-input/one-return Alien science exception. This adds
no runtime work, persistent state, settings or locale keys. Rigor's generated
metadata and tooltips describe the actual selected unrelated product.

## Policy and stage ordering

The owner installs replacement ingredient tables, declares alternative recipes,
removes superseded plate recipes and applies ESIR's existing recipe mutations.
It runs after the shared routing module, allowing alternatives cloned here to
inherit the established machine eligibility. Fluid sizing follows the native
capacity contract below rather than retaining the old field value mechanically.

<a id="fluid-buffers"></a>
## Quality-aware fluid buffers

The user approved native 2.1 recipe buffers when Quality is enabled. Main ESIR
requires Quality: default input capacity therefore changes from two batches to
four (new multiplier 3 plus one batch), and the default fluid-output sizing floor changes from two batches to
three. Explicit authored input multiplier 10 remains 10, giving eleven input
batches under 2.1's `amount * (multiplier + 1)` rule. Larger native fluid volumes
still dominate. This increases buffering, not recipe costs or yields.

`ei_lib.recipe_fluidbox_multiplier(legacy_multiplier, output)` centralizes this
policy for literal records and generated recipes. With Quality it returns the
authored explicit value, or nil to inherit the engine default. Without Quality
it subtracts one from the old input multiplier and retains the old output default
2. The bounded inherited-recipe module returns immediately when Quality is
enabled. Its fallback remains available for a deliberately modified dependency
configuration; removing Quality is not a supported core ESIR configuration.
Ingredients, outputs, temperatures, probabilities, catalysts, productivity and
recipe durations remain unchanged.
The locked railgun recipe's separate 15/30 sizing declaration retains its native
30/60 helper capacities without changing runtime 10/10 shot conversion.

Literal records, shared recipe-add/output-add helpers, generated auric phases and
fumarole products, barrel capacity rewrites and compatibility generators share
this contract. Generated or imported recipes still require final-data comparison;
native dependencies' own choices are not inferred from their mod names. See the
[upgrade synopsis](../handoffs/factorio-2.1/UPGRADE_SYNOPSIS.md) for bounded evidence.

The piercing shotgun recipe retains one magazine for its unchanged ESIR inputs
and duration. Acid neutralisation retains five seconds in the Vulcanus owner
before its tier-two clone, because ESIR's fluid batches did not shrink with the
native 2.1 batch change. Recycling uses its separate generation-stage policy.

Native metallic/oxide asteroid crushing retains independent chunk returns of
20%, or 5% for advanced crushing. Native asteroid reprocessing retains independent
40% same-family and 20% for each other family, with quality still allowed. These
are independent byproducts, not consumed high-energy-crystal returns. The hidden
native uranium recipe likewise retains independent 0.7% / 99.3% isotope products;
ESIR's existing technology owner still removes its unlock and hides the recipe.
This policy preserves the 2.0 economy rather than adopting unrelated 2.1 recipe
changes during the engine port. Asteroid impact damage uses the separately
approved native 2.1 values.

## Verification

Compare native final data for all shared recipe identities, including generated
variants, rather than only source literals. Normalize renamed probability fields
and native integer product amounts; retain changes in correlations, freshness,
productivity, quality, buffers and duration as separate findings. Category membership
does not prove craftability; native recipe and progression fixtures remain required.
Source-level and engine receipts live in the upgrade synopsis and parity reports.

# Recipe routing across Factorio versions

<a id="contract"></a>
## Contract

Factorio 2.1 accepts arrays of recipe categories. ESIR preserves the established
machine and handcrafting eligibility of its existing recipes while adopting that
schema. The former electronics, pressing and union categories become 11 explicit
ESIR-owned category identities. Array membership alone does not establish whether
an entity can craft a recipe: fluid connections, input slots, surface conditions,
research and quality requirements still apply.

## Implementation sources

- [Routing declarations and machine grants](../../../exotic-space-industries-remembrance/lib/recipe-routing.lua)

## Lifecycle and boundaries

The end of ESIR `data.lua` declares these categories and grants them to the exact
former machine sets, before later generated machine copies inherit categories.
At the start of ESIR `data-updates.lua`, 58 existing native recipes and two
dependency recipes receive their established routes. This precedes the explosives
and acid recipe clones. Four Air Scrubber routes remain with its compatibility
owner. ESIR's 41 recipe constructors supply 53 authored/generated recipe routes.
Together these account for the 117 shared recipes found in the migration audit.

Native `electromagnetics`, `organic`, `cryogenics`, `crafting` and other categories
remain available for recipes that intentionally use them. Replacing every old
category with a broad native category would expose electronics to the burner
assembler/nano factory and biochemical recipes to ESIR's bio chamber/reactor.
The precise grants prevent those unintended progression changes.

The two assembler tiers, neo assembler and steam assembler share the assembling
routes. Electromagnetic plant additionally receives the electronics routes;
chemical/advanced chemical/heat chemical plants receive chemistry routes;
cryogenic plant, biochamber and foundry receive their corresponding combinations.
Character and assembler-1 membership is explicit per route. Existing native machine
categories are retained. Optional machines need an integration-specific review;
name-prefix guesses do not grant compatibility.

The recycling policy understands `ei-chemistry-or-cryogenics` as the old excluded
union, with the battery exception. Other old composite routes remain recyclable
where the historical policy permitted them.

## Verification

Compare the full set of eligible shared machines for all shared recipes against
the preserved 2.0.77 merged data, then test representative native crafts and
research reachability. Do not accept equality of category names as a substitute
for equality of machine eligibility. Generated variants must be included.
The upgrade synopsis records final-data and engine receipts separately.

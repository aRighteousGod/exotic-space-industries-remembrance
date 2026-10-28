--==============================================================================
-- ESIR FILE MAP
-- owns: inherited core recipe fluid-buffer parity when Quality is disabled
-- loaded_by: data-final-fixes.lua after ESIR recipe and compatibility generation
-- cadence: data-final-fixes only
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: data stage reload
--==============================================================================
-- blueprint: .codex/esir/blueprints/recipe-economy.md#contract
-- blueprint-ref: .codex/esir/blueprints/recipe-economy.md#fluid-buffers

-- Main ESIR requires Quality and uses native 2.1 buffer sizing. Retain this
-- bounded fallback for configurations that deliberately omit that dependency.
if mods["quality"] then return end

-- Bounded identities from the preserved 1.3.41 core comparison, plus the two
-- native ore-melting renames. Do not rewrite every optional mod's buffer policy.
local inherited_recipes = {
    "advanced-oil-processing", "advanced-thruster-fuel", "advanced-thruster-oxidizer",
    "ammonia-rocket-fuel", "ammoniacal-solution-separation", "atan-foundation-from-ash",
    "atan-nutrients-from-ash", "captive-biter-spawner", "casting-copper", "casting-copper-cable",
    "casting-iron", "casting-iron-gear-wheel", "casting-iron-stick", "casting-low-density-structure",
    "casting-pipe", "casting-pipe-to-ground", "cb-artifact-to-oil", "cb-clean-gland",
    "cb-cold-extract", "cb-coldjet-ammo", "coal-synthesis", "cold-capsule", "concrete",
    "concrete-from-molten-iron", "cryogenic-science-pack", "electrolyte", "electromagnetic-science-pack",
    "explosives", "fish-breeding", "flamethrower-ammo", "fluoroketone", "foundation", "foundry",
    "fusion-power-cell", "holmium-plate", "holmium-solution", "ice-melting", "ice-platform",
    "light-oil-cracking", "lightning-collector", "lithium", "metallurgic-science-pack",
    "molten-copper-from-lava", "molten-iron-from-lava", "overgrowth-jellynut-soil",
    "overgrowth-yumako-soil", "plastic-bar", "quantum-processor", "railgun", "railgun-turret",
    "refined-concrete", "rp-steam-soul", "solid-fuel-from-ammonia", "solid-fuel-from-heavy-oil",
    "solid-fuel-from-light-oil", "solid-fuel-from-petroleum-gas", "steam-condensation", "sulfur",
    "supercapacitor", "superconductor", "tesla-ammo", "tesla-turret", "teslagun", "thruster-fuel",
    "thruster-oxidizer", "tungsten-carbide", "tungsten-plate", "turbo-splitter", "turbo-transport-belt",
    "turbo-underground-belt", "zeus-wrath-lightning-ammo", "zeus-wrath-zeus-gun", "zeus-wrath-zeus-turret",
    "iron-ore-melting", "copper-ore-melting",
}
local legacy_input_overrides = {
    ["casting-copper"] = 10, ["casting-copper-cable"] = 5,
    ["casting-iron"] = 10, ["casting-iron-gear-wheel"] = 10,
    ["casting-iron-stick"] = 10, ["casting-pipe"] = 10,
    ["casting-pipe-to-ground"] = 10, ["holmium-plate"] = 10,
}

for _, name in ipairs(inherited_recipes) do
    local recipe = data.raw.recipe[name]
    if recipe then
        for _, ingredient in pairs(recipe.ingredients or {}) do
            if ingredient.type == "fluid" then
                if ingredient.fluidbox_multiplier == nil then
                    ingredient.fluidbox_multiplier = 1
                elseif legacy_input_overrides[name] and ingredient.fluidbox_multiplier == legacy_input_overrides[name] then
                    ingredient.fluidbox_multiplier = legacy_input_overrides[name] - 1
                end
            end
        end
        for _, product in pairs(recipe.results or {}) do
            if product.type == "fluid" and product.fluidbox_multiplier == nil then
                product.fluidbox_multiplier = 2
            end
        end
    end
end

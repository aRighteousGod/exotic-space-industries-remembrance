--==============================================================================
-- ESIR FILE MAP
-- owns: closed cryo-container registry, items, recipes and technology finalization
-- loaded_by: data.lua (declare), data-final-fixes.lua (finalize)
-- cadence: data declaration and final compatibility reconciliation
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: data stage reload
--==============================================================================
-- blueprint: .codex/esir/blueprints/cryo-containers.md#contract
-- Cryo containment is a closed data-stage registry, not a generic barreling override.
local ei_lib = require("lib/lib")
local ei_data = require("lib/data")
local model = {}

---@class CryoContainerFamily
---@field name string Technology suffix and locale suffix.
---@field prerequisite string Production milestone required alongside cryo containers.
---@field age string Initial science age; inherited packs are resolved after compatibility.
---@field science_source string|nil Technology whose final science ingredients are inherited.
---@field icon_fluid string Representative fluid for the technology icon.

---@type CryoContainerFamily[]
local families = {
    {name = "propellant", prerequisite = "space-platform-thruster", age = "computer-age", icon_fluid = "thruster-fuel"},
    {name = "electrochemical", prerequisite = "electromagnetic-plant", age = "computer-age-space", icon_fluid = "electrolyte"},
    {name = "aquilan", prerequisite = "planet-discovery-aquilo", age = "computer-age-space", science_source = "planet-discovery-aquilo", icon_fluid = "ammonia"},
    {name = "auric-vapor", prerequisite = "ei-auric-precipitation", age = "computer-age-space-vulcanus", science_source = "ei-auric-precipitation", icon_fluid = "ei-auric-vapor"},
}

---@class CryoContainerEntry
---@field fluid string Existing fluid prototype; no optional-mod discovery.
---@field suffix string Item and recipe suffix, preserving existing cryo naming.
---@field family integer Index into families.
---@field temperature number Authored exact transfer temperature; invalid compatibility ranges are reconciled at finalization.

-- blueprint-ref: .codex/esir/blueprints/cryo-containers.md#registry
---@type CryoContainerEntry[]
local entries = {
    {fluid = "thruster-fuel", suffix = "thruster-fuel", family = 1, temperature = 25},
    {fluid = "thruster-oxidizer", suffix = "thruster-oxidizer", family = 1, temperature = 25},
    {fluid = "holmium-solution", suffix = "holmium-solution", family = 2, temperature = 15},
    {fluid = "electrolyte", suffix = "electrolyte", family = 2, temperature = 15},
    {fluid = "ammoniacal-solution", suffix = "ammoniacal-solution", family = 3, temperature = -50},
    {fluid = "ammonia", suffix = "ammonia", family = 3, temperature = -35},
    {fluid = "fluorine", suffix = "fluorine", family = 3, temperature = 25},
    {fluid = "lithium-brine", suffix = "lithium-brine", family = 3, temperature = 15},
    {fluid = "ei-auric-vapor", suffix = "auric-vapor", family = 4, temperature = 500},
}

-- Preserve layered fluid symbols (notably auric vapor's gold-bearing steam).
---@param base string
---@param base_size integer
---@param fluid data.FluidPrototype
---@param shift number[]
---@param extent number Width in icon-coordinate pixels of the fluid's normal 32px canvas.
---@return data.IconData[]
local function container_icons(base, base_size, fluid, shift, extent)
    local icons = ei_lib.make_icons(base, base_size)
    local layers = fluid.icons or {{icon = fluid.icon, icon_size = fluid.icon_size}}
    for _, source in ipairs(layers) do
        local layer = table.deepcopy(source)
        local size = layer.icon_size or fluid.icon_size or 64
        local scale = extent / 32
        layer.icon_size = size
        layer.scale = (layer.scale or 32 / size) * scale
        layer.shift = {
            shift[1] + ((source.shift and source.shift[1]) or 0) * scale,
            shift[2] + ((source.shift and source.shift[2]) or 0) * scale,
        }
        icons[#icons + 1] = layer
    end
    return icons
end

function model.declare()
    for _, family in ipairs(families) do
        data:extend({{
            type = "technology",
            name = "ei-"..family.name.."-cryo-container",
            icons = container_icons(ei_graphics_tech_path.."cryo-container.png", 128, data.raw.fluid[family.icon_fluid], {9, 7}, 18),
            prerequisites = {"ei-cryo-container", family.prerequisite},
            effects = {},
            unit = {count = 100, time = 20, ingredients = table.deepcopy(ei_data.science[family.age])},
            age = family.age,
            order = "c[cryo]-"..family.name,
        }})
    end

    local capacity = ei_lib.config("barrel-capacity")
    for index, entry in ipairs(entries) do
        local fluid = data.raw.fluid[entry.fluid]
        assert(fluid, "Missing cryo fluid: "..entry.fluid)
        local fluid_name = fluid.localised_name or {"fluid-name."..entry.fluid}
        local item_name = "ei-cryo-container-"..entry.suffix
        local fill_name = "ei-fill-cryo-container-"..entry.suffix
        local empty_name = "ei-empty-cryo-container-"..entry.suffix
        local order = string.format("c-3-%02d-%02d", entry.family, index)
        data:extend({
            {
                type = "item", name = item_name,
                localised_name = {"item-name.ei-filled-cryo-container", fluid_name},
                icons = container_icons(ei_graphics_item_path.."empty-cryo-container.png", 64, fluid, {8, 7}, 19),
                subgroup = "intermediate-product", order = "d[barrel]-3-"..order,
                stack_size = 50,
            },
            {
                type = "recipe", name = fill_name,
                localised_name = {"recipe-name.ei-fill-cryo-container", fluid_name},
                icons = container_icons(ei_graphics_other_path.."fill-cryo-container-nitrogen.png", 64, fluid, {-8, -7}, 21),
                categories = {"crafting-with-fluid"}, energy_required = 1,
                ingredients = {
                    {type = "item", name = "ei-empty-cryo-container", amount = 1, ignored_by_stats = 1},
                    {type = "fluid", name = entry.fluid, amount = capacity, temperature = entry.temperature, ignored_by_stats = capacity, fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier()},
                },
                results = {{type = "item", name = item_name, amount = 1, ignored_by_stats = 1}},
                enabled = false, allow_productivity = false, allow_quality = false, auto_recycle = false,
                always_show_made_in = true, main_product = "",
                subgroup = "fill-barrel", order = order,
            },
            {
                type = "recipe", name = empty_name,
                localised_name = {"recipe-name.ei-empty-cryo-container", fluid_name},
                icons = container_icons(ei_graphics_other_path.."empty-cryo-container-nitrogen.png", 64, fluid, {8, 7}, 21),
                categories = {"crafting-with-fluid"}, energy_required = 1,
                ingredients = {{type = "item", name = item_name, amount = 1, ignored_by_stats = 1}},
                results = {
                    {type = "item", name = "ei-empty-cryo-container", amount = 1, ignored_by_stats = 1, ignored_by_productivity = 1},
                    {type = "fluid", name = entry.fluid, amount = capacity, temperature = entry.temperature, ignored_by_stats = capacity, ignored_by_productivity = capacity, fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier(nil, true)},
                },
                enabled = false, allow_productivity = false, allow_quality = false, auto_recycle = false,
                always_show_made_in = true, main_product = "",
                subgroup = "barrel", order = order,
            },
        })
        local technology = "ei-"..families[entry.family].name.."-cryo-container"
        ei_lib.add_unlock_recipe(technology, fill_name)
        ei_lib.add_unlock_recipe(technology, empty_name)
    end
end

-- blueprint-ref: .codex/esir/blueprints/cryo-containers.md#finalization
function model.finalize()
    -- Compatibility can change a fluid's minimum or replace its identity after
    -- declaration. Reconcile the actual transfer pair, preserving one exact
    -- temperature in both directions rather than allowing arbitrary heat loss.
    for _, entry in ipairs(entries) do
        local fill = data.raw.recipe["ei-fill-cryo-container-"..entry.suffix]
        local empty = data.raw.recipe["ei-empty-cryo-container-"..entry.suffix]
        if fill and empty then
            for _, product in ipairs(empty.results) do
                if product.type == "fluid" then
                    local fluid = data.raw.fluid[product.name]
                    local minimum = fluid.default_temperature
                    local maximum = fluid.max_temperature or minimum
                    local temperature = product.temperature or minimum
                    if temperature < minimum or temperature > maximum then
                        local input
                        for _, ingredient in ipairs(fill.ingredients) do
                            if ingredient.type == "fluid" and ingredient.name == product.name then input = ingredient; break end
                        end
                        assert(input, "Mismatched cryo transfer fluid: "..entry.suffix)
                        input.temperature = minimum
                        input.minimum_temperature = nil
                        input.maximum_temperature = nil
                        product.temperature = minimum
                        log("EI cryo temperature: "..entry.suffix.." ("..product.name..") "..temperature.." -> "..minimum)
                    end
                end
            end
        end
    end

    for _, family in ipairs(families) do
        local name = "ei-"..family.name.."-cryo-container"
        if family.science_source then
            ei_lib.set_science_packs(name, data.raw.technology[family.science_source].unit.ingredients)
        else
            ei_lib.set_age_packs(name, family.age)
        end
        -- Only copy ingredients: retain the base cost after ESIR's normal scaling pass.
        data.raw.technology[name].unit.time = 20
        ei_lib.set_prerequisites(name, {"ei-cryo-container", family.prerequisite})
    end
end

return model

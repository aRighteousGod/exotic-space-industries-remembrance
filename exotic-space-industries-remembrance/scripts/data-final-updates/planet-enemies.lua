--==============================================================================
-- ESIR FILE MAP
-- owns: independent planetary enemy controls and native placement overrides
-- loaded_by: data-final-fixes.lua
-- cadence: data stage only
-- dependency_sources: __Explosive_biters__/prototypes/enemy-autoplace.lua,
-- __Cold_biters__/prototypes/enemy-autoplace.lua, __Electric_flying_enemies__/prototypes/enemy-autoplace.lua,
-- __space-age__/prototypes/planet/planet-vulcanus-map-gen.lua, __base__/prototypes/entity/enemy-autoplace-utils.lua,
-- __Arachnids_enemy__/prototypes/enemy-autoplace.lua, __Toxic_biters__/prototypes/enemy-autoplace.lua, __ArmouredBiters__/armoured-autoplace.lua
-- shared_config: lib/planet-enemies-config.lua
--==============================================================================
-- blueprint: .codex/esir/blueprints/planet-enemies.md#contract
local config = require("lib/planet-enemies-config")
local electric_noise = require("scripts/data-final-updates/legacy-electric-noise")

local function control(name, family, order)
    data:extend{{type = "autoplace-control", name = name, category = "enemy", richness = false,
        can_be_disabled = true, order = order, related_to_fight_achievements = true,
        localised_name = {"planet-enemies." .. family},
        localised_description = {"planet-enemies." .. family .. "-description"}}}
end

local function expression(name, value)
    data:extend{{type = "noise-expression", name = name, expression = value}}
    return name
end

-- Nauvis families share the native noise closure. Planet-wide aliases would
-- couple them, so preserve and rebind that closure separately for each family.
local native_noise = {{"noise-expression", "enemy_base_radius"}, {"noise-expression", "enemy_base_frequency"},
    {"noise-expression", "enemy_base_probability"}, {"noise-function", "enemy_autoplace_base"}}
local function rebind(value, names, name, previous_control)
    if type(value) ~= "string" then return value end
    local pattern = (previous_control or "enemy-base"):gsub("(%W)", "%%%1")
    value = value:gsub("control:" .. pattern .. ":", function() return "control:" .. name .. ":" end)
    return (value:gsub("[%a_][%w_:]*", function(identifier) return names[identifier] or identifier end))
end
local function rebind_definition(definition, names, name, previous_control)
    definition.expression = rebind(definition.expression, names, name, previous_control)
    for key, value in pairs(definition.local_expressions or {}) do
        definition.local_expressions[key] = rebind(value, names, name, previous_control)
    end
    for _, value in pairs(definition.local_functions or {}) do rebind_definition(value, names, name, previous_control) end
end
local nauvis = data.raw.planet.nauvis
if nauvis then
    for _, family in ipairs(config.nauvis_splits) do
        local name = config.controls.nauvis[family]
        control(name, family, "z-ei-nauvis-" .. family)
        local names = {}
        for _, source in ipairs(native_noise) do names[source[2]] = "ei_nauvis_" .. family .. "_" .. source[2] end
        for _, source in ipairs(native_noise) do
            local clone = table.deepcopy(assert(data.raw[source[1]][source[2]], "Missing native enemy noise: " .. source[2]))
            clone.name = names[source[2]]
            clone.intended_property = nil
            rebind_definition(clone, names, name)
            data:extend{clone}
        end
        local controls = nauvis.map_gen_settings.autoplace_controls
        controls[name] = controls[name] or table.deepcopy(controls["enemy-base"] or {})
        for prototype_type in pairs(config.hostile_types) do
            for entity_name, prototype in pairs(data.raw[prototype_type] or {}) do
                local autoplace = prototype.autoplace
                if autoplace and autoplace.control == "enemy-base" and config.family(entity_name, prototype_type) == family then
                    autoplace = table.deepcopy(autoplace)
                    autoplace.control = name
                    rebind_definition(autoplace, names, name)
                    local enabled = "((var('control:" .. name .. ":frequency') > 0) * (var('control:" .. name .. ":size') > 0))"
                    autoplace.probability_expression = "(" .. tostring(rebind(autoplace.probability_expression, names, name))
                        .. ") * " .. enabled .. " - (1 - " .. enabled .. ")"
                    prototype.autoplace = autoplace
                end
            end
        end
        for _, presets in pairs(data.raw["map-gen-presets"] or {}) do
            for _, preset in pairs(presets) do
                local values = type(preset) == "table" and preset.basic_settings and preset.basic_settings.autoplace_controls
                if values and values["enemy-base"] and not values[name] then values[name] = table.deepcopy(values["enemy-base"]) end
            end
        end
    end

    -- blueprint-ref: .codex/esir/blueprints/planet-enemies.md#seed-compatibility
    -- Factorio 2.0.77 merges spot-noise state for equal seeds, even when density
    -- or radius differs. Keep native seeds at 1/1; adjusted families use stable,
    -- distinct seeds. Only spot centers change; blobs and terrain masks remain.
    -- New surfaces use the native 2.1 clone; old surfaces retain these identities.
    local probabilities = {
        {"ordinary", "enemy_base_probability", 2000123},
        {"explosive", "eb_enemy_base_probability", 2000124},
        {"cold", "cb_enemy_base_probability", 2000125},
        {"arachnid", "ei_nauvis_arachnid_enemy_base_probability", 2000126},
        {"toxic", "ei_nauvis_toxic_enemy_base_probability", 2000127},
        {"armoured", "ei_nauvis_armoured_enemy_base_probability", 2000128},
    }
    local properties = nauvis.map_gen_settings.property_expression_names or {}
    nauvis.map_gen_settings.property_expression_names = properties
    for _, row in ipairs(probabilities) do
        local prototype = assert(data.raw["noise-expression"][row[2]])
        if row[1] == "ordinary" or row[1] == "explosive" or row[1] == "cold" then
            prototype = table.deepcopy(prototype)
            prototype.name = "ei_nauvis_" .. row[1] .. "_enemy_base_probability"
            prototype.intended_property = nil
            data:extend{prototype}
        end
        local native = table.deepcopy(prototype)
        native.name = "ei_native21_nauvis_" .. row[1] .. "_enemy_base_probability"
        native.intended_property = nil
        data:extend{native}
        if properties[row[2]] == nil or properties[row[2]] == row[2] then properties[row[2]] = native.name end
        local name = config.controls.nauvis[row[1]]
        local frequency, size = "var('control:" .. name .. ":frequency')", "var('control:" .. name .. ":size')"
        local adjusted = "max(" .. frequency .. " < 1, " .. frequency .. " > 1, " .. size .. " < 1, " .. size .. " > 1)"
        local count
        prototype.expression, count = prototype.expression:gsub("seed1%s*=%s*(%d+)", function(seed)
            return "seed1 = (" .. seed .. " + " .. (row[3] - tonumber(seed)) .. " * " .. adjusted .. ")"
        end, 1)
        assert(count == 1, "Unsupported enemy spot-noise seed: " .. row[2])
    end
end

for _, prototype in pairs(data.raw["autoplace-control"]) do
    if prototype.category == "enemy" then prototype.can_be_disabled = true end
end
for family, name in pairs(config.controls.nauvis) do
    local prototype = data.raw["autoplace-control"][name]
    if prototype then
        prototype.localised_name = {"planet-enemies." .. family}
        prototype.localised_description = {"planet-enemies." .. family .. "-description"}
    end
end

-- blueprint-ref: .codex/esir/blueprints/planet-enemies.md#generation
-- Name resolution consults a planet's property_expression_names before global
-- expressions. Only the controls change: dependency seeds and terrain masks stay intact.
for _, binding in ipairs(config.rebindings) do
    local planet = data.raw.planet[binding.planet]
    if planet and data.raw["autoplace-control"][binding.legacy] then
        if not data.raw["autoplace-control"][binding.control] then
            control(binding.control, binding.family, "z-ei-" .. binding.planet)
        end
        local settings = planet.map_gen_settings
        settings.autoplace_controls[binding.control] = settings.autoplace_controls[binding.legacy]
            or {frequency = 1, size = binding.size}
        settings.autoplace_controls[binding.legacy] = nil
        local properties = settings.property_expression_names or {}
        settings.property_expression_names = properties
        for _, suffix in ipairs(binding.planet == "gaia" and {"radius", "frequency", "probability"} or {"radius", "frequency"}) do
            local original = binding.prefix .. "_enemy_base_" .. suffix
            local source = binding.planet == "gaia" and electric_noise[suffix] or data.raw["noise-expression"][original]
            assert(source and type(source.expression) == "string", "Unsupported planetary enemy noise: " .. original)
            local clone = table.deepcopy(source)
            clone.name = binding.control .. "-" .. suffix
            clone.intended_property = nil
            rebind_definition(clone, {}, binding.control, binding.legacy)
            data:extend{clone}
            properties[original] = clone.name
            if binding.planet == "gaia" then
                local native = table.deepcopy(clone)
                native.name = "ei-native21-gaia-electric-" .. suffix
                data:extend{native}
                properties[original] = native.name
            end
        end
        local enabled = "((var('control:" .. binding.control .. ":frequency') > 0) * (var('control:" .. binding.control .. ":size') > 0))"
        local entities = settings.autoplace_settings.entity.settings
        for prototype_type in pairs(config.hostile_types) do
            for name, prototype in pairs(data.raw[prototype_type] or {}) do
                local autoplace = prototype.autoplace
                if autoplace and autoplace.control == binding.legacy and config.family(name, prototype_type) == binding.family then
                    -- Explicit whitelist keeps the old shared control out of this
                    -- planet's menu without excluding its existing enemy prototypes.
                    entities[name] = entities[name] or {}
                    local probability = binding.planet == "gaia"
                        and assert(data.raw["noise-expression"]["ei-legacy20-electric-" .. name]).expression
                        or autoplace.probability_expression
                    local value = "(" .. probability .. ") * " .. enabled .. " - (1 - " .. enabled .. ")"
                    properties["entity:" .. name .. ":probability"] = expression(binding.control .. "-" .. name, value)
                    if binding.planet == "gaia" then
                        properties["entity:" .. name .. ":probability"] = expression("ei-native21-gaia-electric-" .. name, value)
                    end
                end
            end
        end
    end
end

expression(config.revision_property, "2")
expression(config.legacy_revision, "1")
expression(config.native_revision, "2")
for name in pairs(config.controls) do
    local planet = data.raw.planet[name]
    if planet and planet.map_gen_settings then
        local properties = planet.map_gen_settings.property_expression_names or {}
        planet.map_gen_settings.property_expression_names = properties
        properties[config.revision_property] = config.native_revision
    end
end

for _, row in ipairs({{"electric_enemies", "electric"}, {"gleba_enemy_base", "pentapod"}}) do
    local prototype = data.raw["autoplace-control"][row[1]]
    if prototype then
        prototype.can_be_disabled = true
        prototype.localised_description = {"planet-enemies." .. row[2] .. "-description"}
    end
end

local gleba = data.raw.planet.gleba
if gleba then
    local frequency, size = "control:gleba_enemy_base:frequency", "control:gleba_enemy_base:size"
    local off = "max(" .. frequency .. " <= 0, " .. size .. " <= 0)"
    local properties = gleba.map_gen_settings.property_expression_names
    for _, suffix in ipairs({"radius", "frequency"}) do
        local original = "gleba_enemy_base_" .. suffix
        local value = data.raw["noise-expression"][original].expression
        value = value:gsub(frequency, "(" .. frequency .. " * (1 - " .. off .. ") + " .. off .. ")")
        value = value:gsub(size, "(" .. size .. " * (1 - " .. off .. ") + " .. off .. ")")
        -- The native planet binds generic enemy_base_* directly to the Gleba
        -- expression. Replace that binding, not the name it already resolves to.
        properties["enemy_base_" .. suffix] = expression("ei-" .. original, value)
    end
    -- Off retains the normal egg supply. Runtime deactivates these rafts and
    -- suppresses their offspring; the native checkbox must not omit the rafts.
    for _, name in ipairs({"gleba-spawner", "gleba-spawner-small"}) do
        data.raw["unit-spawner"][name].autoplace.control = nil
        gleba.map_gen_settings.autoplace_settings.entity.settings[name] = {}
    end
end

local vulcanus = data.raw.planet.vulcanus
if vulcanus then
    control(config.demolisher_control, "demolisher", "z-ei-vulcanus-demolisher")
    local settings = vulcanus.map_gen_settings
    settings.autoplace_controls[config.demolisher_control] = {}
    local frequency = "var('control:" .. config.demolisher_control .. ":frequency')"
    local size = "var('control:" .. config.demolisher_control .. ":size')"
    local properties = settings.property_expression_names
    properties.demolisher_territory_radius = expression("ei-demolisher-territory-radius",
        "floor(clamp(384 * sqrt(max(" .. size .. ", 0.000001) / max(1, " .. frequency .. ")), 128, 65535))")
    -- Voronoi cell IDs are stable random values in [0,1]. Keep the native cell
    -- layout below 100% frequency and leave a deterministic fraction unoccupied.
    local disabled = "max(" .. frequency .. " <= 0, " .. size .. " <= 0, demolisher_territory_expression > min(1, max(0, " .. frequency .. ")))"
    properties.demolisher_variation_expression = expression("ei-demolisher-variation",
        "(" .. data.raw["noise-expression"].demolisher_variation_expression.expression .. ") - 99 * " .. disabled)
end

-- Preserve all dependency effects, and notify only actual hostile bodies.
-- Segmented units use their native whole-unit lifecycle event instead of head births.
for prototype_type in pairs(config.hostile_types) do
    for name, prototype in pairs(data.raw[prototype_type] or {}) do
        if config.family(name, prototype_type) then
            local notification = {type = "direct", action_delivery = {type = "instant",
                target_effects = {{type = "script", effect_id = config.created_effect}}}}
            local existing = prototype.created_effect
            if not existing then prototype.created_effect = notification
            elseif existing.type then prototype.created_effect = {existing, notification}
            else existing[#existing + 1] = notification end
        end
    end
end

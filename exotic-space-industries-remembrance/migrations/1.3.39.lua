-- Remove Gaia's legacy per-entity resource overrides so autoplace controls can
-- drive future chunks. Existing chunks and their resource entities are untouched.

local legacy_resource_entity_settings = {
    ["ei-morphium-patch"] = {frequency = 4.2, size = 0.72, richness = 1.2},
    ["ei-phytogas-patch"] = {frequency = 2.4, size = 1.15, richness = 0.95},
    ["ei-cryoflux-patch"] = {frequency = 2.8, size = 0.68, richness = 1.4},
    ["ei-ammonia-patch"] = {frequency = 3.4, size = 0.86, richness = 1.05},
    ["ei-coal-gas-patch"] = {frequency = 2.2, size = 1.08, richness = 1.1},
    ["ei-gaia-relic-debris"] = {frequency = 0.14, size = 0.12, richness = 0.2},
}

local surfaces = {}
local seen_surface_indexes = {}

local function add_surface(surface)
    if surface and surface.valid and not seen_surface_indexes[surface.index] then
        seen_surface_indexes[surface.index] = true
        surfaces[#surfaces + 1] = surface
    end
end

local function matches_frequency_size_richness(actual, expected)
    return type(actual) == "table"
        and actual.frequency == expected.frequency
        and actual.size == expected.size
        and actual.richness == expected.richness
end

local gaia_planet = game.planets and game.planets["gaia"]
add_surface(gaia_planet and gaia_planet.surface)
add_surface(game.surfaces and game.surfaces["gaia"])
add_surface(game.surfaces and game.surfaces["Gaia"])
add_surface(game.surfaces and game.surfaces["gaia-reforge-staging"])

for _, surface in ipairs(surfaces) do
    local map_gen_settings = surface.map_gen_settings
    if map_gen_settings then
        local changed = false
        map_gen_settings.autoplace_settings = map_gen_settings.autoplace_settings or {}
        map_gen_settings.autoplace_settings.entity = map_gen_settings.autoplace_settings.entity or {}
        local entity_settings = map_gen_settings.autoplace_settings.entity.settings or {}
        map_gen_settings.autoplace_settings.entity.settings = entity_settings

        for resource_name, legacy_settings in pairs(legacy_resource_entity_settings) do
            local current_settings = entity_settings[resource_name]
            if current_settings == nil or matches_frequency_size_richness(current_settings, legacy_settings) then
                entity_settings[resource_name] = {}
                changed = true
            end
        end

        -- Only migrate the exact legacy default. Any player-customized triplet is preserved.
        local controls = map_gen_settings.autoplace_controls
        local relic_control = controls and controls["ei-gaia-relic-debris"]
        if matches_frequency_size_richness(relic_control, legacy_resource_entity_settings["ei-gaia-relic-debris"]) then
            controls["ei-gaia-relic-debris"] = {frequency = 1, size = 0.2, richness = 0.2}
            changed = true
        end

        if changed then
            surface.map_gen_settings = map_gen_settings
        end
    end
end

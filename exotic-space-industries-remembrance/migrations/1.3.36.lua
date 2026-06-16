local function get_technology(force, name)
    if not (force and force.valid) then return nil end
    return force.technologies and force.technologies[name] or nil
end

local function get_recipe(force, name)
    if not (force and force.valid) then return nil end
    return force.recipes and force.recipes[name] or nil
end

local function research_technology(force, name)
    local tech = get_technology(force, name)
    if tech then
        tech.researched = true
    end
end

local function enable_recipe(force, name)
    local recipe = get_recipe(force, name)
    if recipe then
        recipe.enabled = true
    end
end

for _, force in pairs(game.forces) do
    local steam_power = get_technology(force, "ei-steam-power")
    local electricity_power = get_technology(force, "ei-electricity-power")
    local offshore_recipe = get_recipe(force, "offshore-pump")
    local had_offshore_recipe = offshore_recipe and offshore_recipe.enabled

    if steam_power and steam_power.researched then
        research_technology(force, "ei-burner-offshore-pump")
        research_technology(force, "ei-steam-offshore-pump")
        enable_recipe(force, "ei-stone-well-pump")
        enable_recipe(force, "ei-burner-offshore-pump")
        enable_recipe(force, "ei-steam-offshore-pump")
    end

    if had_offshore_recipe or (electricity_power and electricity_power.researched) then
        research_technology(force, "ei-electric-offshore-pump")
        enable_recipe(force, "offshore-pump")
    end
end

local STEAM_ASSEMBLER_NAME = "ei-steam-assembler"
local ROTATE_CLOCKWISE = defines.direction.east
local DIRECTION_COUNT = 16

local function rotate_steam_assembler(entity)
    if not (entity and entity.valid) then
        return
    end

    local ok, direction = pcall(function()
        return entity.direction
    end)

    if not ok or direction == nil then
        return
    end

    pcall(function()
        entity.direction = (direction + ROTATE_CLOCKWISE) % DIRECTION_COUNT
    end)
end

-- The prototype now uses AM2-style recipe ports. Rotate existing machines so
-- old world-space recipe and steam pipe hookups remain connected after load.
for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered{name = STEAM_ASSEMBLER_NAME}) do
        rotate_steam_assembler(entity)
    end

    for _, ghost in pairs(surface.find_entities_filtered{type = "entity-ghost", ghost_name = STEAM_ASSEMBLER_NAME}) do
        rotate_steam_assembler(ghost)
    end
end

--==============================================================================
-- ESIR FILE MAP
-- owns: data-final presentation registry entries for repetitive machines and logistics
-- loaded_by: data-final entity presentation orchestrator
-- cadence: data-final-fixes load
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: visible machine/logistics prototype changes
--==============================================================================

local NORTH = 0
local EAST = 4
local SOUTH = 8

local force_simulation = {factoriopedia_simulation = true}

local function companion(name, x, y, direction, opts)
    local entity = {}

    if type(opts) == "table" then
        for key, value in pairs(opts) do
            entity[key] = value
        end
    end

    entity.name = name
    entity.position = {x, y}

    if direction then
        entity.direction = direction
    end

    return entity
end

local function visible_item(name)
    return {
        name = name,
        count = 80,
    }
end

local function add_entry(entries, api, name, prototype_type, hit, sound, simulation, force)
    entries[#entries + 1] = api.entity(name, {
        type = prototype_type,
        hit = hit,
        sound = sound,
        simulation = simulation,
        force = force,
    })
end

local function ingredient_name(ingredient)
    if type(ingredient) ~= "table" then
        return nil
    end

    return ingredient.name or ingredient[1]
end

local function ingredient_amount(ingredient)
    if type(ingredient) ~= "table" then
        return 1
    end

    return tonumber(ingredient.amount or ingredient[2] or ingredient.amount_min) or 1
end

local function ingredient_type(ingredient, name)
    if type(ingredient) ~= "table" then
        return "item"
    end

    if ingredient.type then
        return ingredient.type
    end

    if data and data.raw and data.raw.fluid and data.raw.fluid[name] then
        return "fluid"
    end

    return "item"
end

local function recipe_ingredients(recipe_name)
    if not (data and data.raw and data.raw.recipe and data.raw.recipe[recipe_name]) then
        return nil
    end

    local recipe = data.raw.recipe[recipe_name]
    return recipe.ingredients or (recipe.normal and recipe.normal.ingredients)
end

local function infer_recipe_inputs(recipe_name)
    local ingredients = recipe_ingredients(recipe_name)
    local items = {}
    local fluids = {}

    if type(ingredients) ~= "table" then
        return items, fluids
    end

    local iterator = #ingredients > 0 and ipairs or pairs

    for _, ingredient in iterator(ingredients) do
        local name = ingredient_name(ingredient)
        if name then
            if ingredient_type(ingredient, name) == "fluid" then
                fluids[#fluids + 1] = {
                    name = name,
                    amount = ingredient_amount(ingredient),
                    temperature = ingredient.temperature or ingredient.minimum_temperature or ingredient.min_temperature,
                }
            else
                items[#items + 1] = {
                    name = name,
                    count = math.max(ingredient_amount(ingredient) * 5, 10),
                }
            end
        end
    end

    return items, fluids
end

local function has_named_input(inputs, input_name)
    if type(inputs) ~= "table" then
        return false
    end

    for _, input in ipairs(inputs) do
        if input == input_name or (type(input) == "table" and (input.name or input[1]) == input_name) then
            return true
        end
    end

    return false
end

local function append_missing_inputs(target, inferred)
    if type(target) ~= "table" then
        return #inferred > 0 and inferred or nil
    end

    for _, input in ipairs(inferred) do
        if input.name and not has_named_input(target, input.name) then
            target[#target + 1] = input
        end
    end

    return target
end

local function hydrate_recipe_inputs(opts)
    if type(opts.recipe) ~= "string" then
        return opts
    end

    local items, fluids = infer_recipe_inputs(opts.recipe)
    opts.items = append_missing_inputs(opts.items, items)
    opts.fluids = append_missing_inputs(opts.fluids, fluids)

    return opts
end

local function container_scene(simulation, name, opts)
    local size = opts.size or 1
    local zoom = opts.zoom or ({[1] = 1.7, [2] = 1.25, [6] = 0.62})[size] or 1.1

    return simulation.entity(name, {
        camera_position = opts.camera or {0, -0.1},
        camera_zoom = zoom,
        direction = opts.direction or SOUTH,
        tiles = opts.tiles or "refined-concrete",
        init_update_count = opts.init_update_count or 30,
    })
end

local function large_container_scene(simulation, name, opts)
    return simulation.entity(name, {
        camera_position = opts.camera or {0, -0.35},
        camera_zoom = opts.zoom or 0.82,
        direction = opts.direction or SOUTH,
        tiles = opts.tiles or "refined-concrete",
        main_first = true,
        init_update_count = opts.init_update_count or 30,
    })
end

local function gate_receiver_scene(simulation, name, opts)
    return simulation.entity(name, {
        camera_position = opts.camera or {0, -0.25},
        camera_zoom = opts.zoom or 0.82,
        direction = opts.direction or SOUTH,
        tiles = opts.tiles or "refined-concrete",
        main_first = true,
        init_update_count = opts.init_update_count or 30,
        companions = {
            companion("substation", -4, -2),
        },
    })
end

local function belt_scene(simulation, name, opts)
    local scene_opts = {
        camera_position = opts.camera or {0, 0},
        camera_zoom = opts.zoom or 1.5,
        direction = opts.direction or EAST,
        tiles = opts.tiles or "concrete",
        active = opts.active ~= false,
        init_update_count = opts.init_update_count or 90,
        companions = opts.companions or {
            companion("transport-belt", -2, 0, EAST),
            companion("transport-belt", 2, 0, EAST),
            companion("small-electric-pole", 0, -2),
        },
    }

    if opts.prototype_type == "transport-belt" then
        scene_opts.belt = name
        return simulation.belt(name, scene_opts)
    end

    return simulation.entity(name, scene_opts)
end

local function loader_scene(simulation, name, opts)
    return simulation.entity(name, {
        camera_position = opts.camera or {0, 0},
        camera_zoom = opts.zoom or 1.45,
        direction = opts.direction or EAST,
        tiles = opts.tiles or "concrete",
        active = true,
        init_update_count = opts.init_update_count or 120,
        companions = {
            companion(opts.chest or "steel-chest", -1, 0, nil, {items = {visible_item(opts.item or "iron-plate")}}),
            companion(opts.belt or "transport-belt", 1, 0, EAST),
            companion("small-electric-pole", 0, -1.5),
        },
    })
end

local function inserter_scene(simulation, name, opts)
    local reach = name:find("long", 1, true) and 2.5 or 1.5

    return simulation.entity(name, {
        camera_position = opts.camera or {0, 0},
        camera_zoom = opts.zoom or 1.65,
        direction = opts.direction or NORTH,
        tiles = opts.tiles or "concrete",
        active = true,
        init_update_count = opts.init_update_count or 120,
        companions = {
            companion(opts.input or "transport-belt", 0, reach, EAST),
            companion(opts.output or "steel-chest", 0, -reach),
            companion("small-electric-pole", 1.5, 0),
        },
    })
end

local function fluid_scene(simulation, name, opts)
    opts = hydrate_recipe_inputs(opts)

    local companions = {
        companion("pipe", -5.5, 0, EAST),
        companion("pipe", 5.5, 0, EAST),
        companion("small-electric-pole", 0, -5.5),
    }

    if opts.tank then
        companions[#companions + 1] = companion("storage-tank", 0, 6.5)
    elseif opts.pump then
        companions[#companions + 1] = companion("pump", -3.5, 3.5, EAST)
    end

    return simulation.entity(name, {
        camera_position = opts.camera or {0, 0},
        camera_zoom = opts.zoom or 1.15,
        direction = opts.direction or EAST,
        tiles = opts.tiles or "concrete",
        recipe = opts.recipe,
        items = opts.items,
        fluids = opts.fluids,
        power = opts.power == true or type(opts.recipe) == "string",
        active = true,
        init_update_count = opts.init_update_count or (type(opts.recipe) == "string" and 90 or nil),
        companions = companions,
    })
end

local function miner_scene(simulation, name, opts)
    opts = hydrate_recipe_inputs(opts)

    local companions = {
        companion(opts.belt or "transport-belt", 0, 3.2, EAST),
        companion("small-electric-pole", -3.3, -2),
    }

    if opts.fluid then
        companions[#companions + 1] = companion("pipe", 3.2, 0, NORTH)
    end

    if opts.steam then
        companions[#companions + 1] = companion("pipe", -3.2, 0, NORTH)
    end

    return simulation.entity(name, {
        camera_position = opts.camera or {0, -0.25},
        camera_zoom = opts.zoom or 1.05,
        direction = opts.direction or EAST,
        tiles = opts.tiles or "stone-path",
        init = opts.init,
        recipe = opts.recipe,
        items = opts.items,
        fluids = opts.fluids,
        power = opts.power == true or type(opts.recipe) == "string",
        active = true,
        init_update_count = opts.init_update_count or (opts.resource and 120) or (type(opts.recipe) == "string" and 90 or nil),
        companions = companions,
    })
end

local function furnace_scene(simulation, name, opts)
    opts = hydrate_recipe_inputs(opts)

    local companions = {
        companion("transport-belt", -3.8, 3.2, EAST),
        companion("inserter", -3.2, 2.5, NORTH),
        companion("small-electric-pole", 3.5, -2.6),
    }

    if opts.fluid then
        companions[#companions + 1] = companion("pipe", 3.2, 0, NORTH)
    end

    if opts.heat then
        companions[#companions + 1] = companion("heat-pipe", 0, -3.2, EAST)
    end

    return simulation.entity(name, {
        camera_position = opts.camera or {0, -0.1},
        camera_zoom = opts.zoom or 1.2,
        direction = opts.direction or SOUTH,
        tiles = opts.tiles or "stone-path",
        recipe = opts.recipe,
        items = opts.items,
        fluids = opts.fluids,
        power = opts.power == true or type(opts.recipe) == "string",
        active = true,
        init_update_count = opts.init_update_count or (type(opts.recipe) == "string" and 90 or nil),
        companions = companions,
    })
end

local function lab_scene(simulation, name, opts)
    opts = hydrate_recipe_inputs(opts)

    return simulation.entity(name, {
        camera_position = opts.camera or {0, -0.25},
        camera_zoom = opts.zoom or 1.1,
        direction = SOUTH,
        tiles = opts.tiles or "refined-concrete",
        main_first = opts.large == true,
        recipe = opts.recipe,
        items = opts.items,
        fluids = opts.fluids,
        power = opts.power == true or type(opts.recipe) == "string",
        active = true,
        init_update_count = opts.init_update_count or (type(opts.recipe) == "string" and 90 or nil),
        companions = {
            companion("small-electric-pole", opts.large and -6 or -2.5, opts.large and -3 or -1.5),
        },
    })
end

local function beacon_scene(simulation, name, opts)
    return simulation.entity(name, {
        camera_position = opts.camera or {0, -0.35},
        camera_zoom = opts.zoom or 0.95,
        direction = SOUTH,
        tiles = opts.tiles or "refined-concrete",
        items = opts.items or {
            {name = opts.module or "speed-module", count = opts.module_count or 2},
            opts.fuel and {name = opts.fuel, count = opts.fuel_count or 8} or nil,
        },
        active = true,
        init_update_count = opts.init_update_count or 90,
    })
end

local function wall_scene(simulation, name, opts)
    return simulation.entity(name, {
        camera_position = opts.camera or {0, -0.2},
        camera_zoom = opts.zoom or 1.35,
        direction = SOUTH,
        tiles = opts.tiles or "stone-path",
        init_update_count = opts.init_update_count or 30,
    })
end

local function power_scene(simulation, name, opts)
    local companions = {}

    if opts.heat then
        companions[#companions + 1] = companion("heat-pipe", 0, 5, EAST)
    end

    if opts.pipe then
        companions[#companions + 1] = companion("pipe", 5, 0, NORTH)
    end

    return simulation.entity(name, {
        camera_position = opts.camera or {0, -0.25},
        camera_zoom = opts.zoom or 1.0,
        direction = opts.direction or SOUTH,
        tiles = opts.tiles or "refined-concrete",
        main_first = true,
        energy = opts.energy,
        fluid = opts.fluid,
        fluid_amount = opts.fluid_amount,
        fluidbox_index = opts.fluidbox_index,
        fluid_temperature = opts.fluid_temperature,
        fluids = opts.fluids,
        items = opts.items,
        init_update_count = opts.init_update_count,
        active = true,
        companions = companions,
    })
end

local function charger_scene(simulation, name, opts)
    return simulation.entity(name, {
        camera_position = opts.camera or {0, -0.35},
        camera_zoom = opts.zoom or 0.78,
        direction = opts.direction or SOUTH,
        tiles = opts.tiles or "refined-concrete",
        main_first = true,
        energy = opts.energy or 1000000000,
        active = true,
        init_update_count = opts.init_update_count or 90,
        companions = {
            companion("substation", -5, -2),
            companion("accumulator", 5, -2),
        },
    })
end

local function machine_scene(simulation, name, opts)
    opts = hydrate_recipe_inputs(opts)

    local companions = {
        companion(opts.pole or "small-electric-pole", -3.3, -2.7),
    }

    if opts.pipe then
        companions[#companions + 1] = companion("pipe", 3.2, 0, NORTH)
    end

    if opts.heat then
        companions[#companions + 1] = companion("heat-pipe", 0, -3.2, EAST)
    end

    return simulation.entity(name, {
        camera_position = opts.camera or {0, -0.2},
        camera_zoom = opts.zoom or 1.05,
        direction = opts.direction or SOUTH,
        tiles = opts.tiles or "concrete",
        main_first = opts.main_first == true,
        recipe = opts.recipe,
        items = opts.items,
        fluids = opts.fluids,
        power = opts.power == true or type(opts.recipe) == "string",
        active = true,
        init_update_count = opts.init_update_count or (type(opts.recipe) == "string" and 90 or nil),
        companions = companions,
    })
end

local function large_machine_scene(simulation, name, opts)
    opts = hydrate_recipe_inputs(opts)

    local spread = opts.spread or 5.5
    local companions = {
        companion(opts.pole or "substation", -spread - 1.2, -3.5),
    }

    if opts.pipe then
        companions[#companions + 1] = companion("pipe", spread, 0, NORTH)
    end

    if opts.heat then
        companions[#companions + 1] = companion("heat-pipe", 0, -spread, EAST)
    end

    return simulation.entity(name, {
        camera_position = opts.camera or {0, -0.45},
        camera_zoom = opts.zoom or 0.78,
        direction = opts.direction or SOUTH,
        tiles = opts.tiles or "refined-concrete",
        main_first = true,
        power = opts.power ~= false,
        recipe = opts.recipe,
        items = opts.items,
        fluids = opts.fluids,
        active = true,
        init_update_count = opts.init_update_count or (type(opts.recipe) == "string" and 90 or 45),
        companions = companions,
    })
end

local function induction_scene(simulation, name, opts)
    return simulation.entity(name, {
        camera_position = opts.camera or {0, -0.25},
        camera_zoom = opts.zoom or 1.05,
        direction = opts.direction or SOUTH,
        tiles = opts.tiles or "refined-concrete",
        main_first = true,
        energy = opts.energy or 1000000000,
        active = true,
        init_update_count = opts.init_update_count or 90,
        companions = {
            companion("substation", -4.5, -3),
        },
    })
end

local function alien_ruin_scene(simulation, name, opts)
    return simulation.entity(name, {
        camera_position = opts.camera or {0, -0.35},
        camera_zoom = opts.zoom or 0.92,
        direction = opts.direction or SOUTH,
        tiles = opts.tiles or "stone-path",
        init_update_count = opts.init_update_count or 30,
    })
end

local function robot_scene(simulation, name, opts)
    return simulation.entity(name, {
        camera_position = opts.camera or {0, -0.15},
        camera_zoom = opts.zoom or (opts.prototype_type == "roboport" and 0.82 or 1.45),
        direction = opts.direction or EAST,
        tiles = opts.tiles or "refined-concrete",
        main_first = opts.prototype_type == "roboport",
        active = true,
    })
end

local function orbital_scene(simulation, name, opts)
    return simulation.entity(name, {
        camera_position = opts.camera or {0, -0.1},
        camera_zoom = opts.zoom or 1.25,
        direction = opts.direction or SOUTH,
        tiles = opts.tiles or "refined-concrete",
        main_first = true,
        power = true,
        active = true,
        init_update_count = opts.init_update_count or 90,
        companions = {
            companion("medium-electric-pole", 4, -2),
        },
    })
end

local function holo_scene(simulation, name, opts)
    return simulation.entity(name, {
        camera_position = opts.camera or {0, -0.2},
        camera_zoom = opts.zoom or 1.15,
        direction = opts.direction or SOUTH,
        tiles = opts.tiles or "refined-concrete",
        main_first = true,
        power = true,
        recipe = name .. "-running",
        active = true,
        init_update_count = opts.init_update_count or 90,
        companions = {
            companion("medium-electric-pole", 0, 3),
        },
    })
end

return function(api)
    local simulation = api.simulation
    local entries = {}

    local containers = {
        {name = "ei-1x1-container", prototype_type = "container", size = 1},
        {name = "ei-1x1-container-blue", prototype_type = "logistic-container", size = 1, logistic = true},
        {name = "ei-1x1-container-red", prototype_type = "logistic-container", size = 1, logistic = true},
        {name = "ei-1x1-container-pink", prototype_type = "logistic-container", size = 1, logistic = true},
        {name = "ei-1x1-container-yellow", prototype_type = "logistic-container", size = 1, logistic = true},
        {name = "ei-1x1-container-green", prototype_type = "logistic-container", size = 1, logistic = true},
        {name = "ei-1x1-container-filter", prototype_type = "container", size = 1, filter = true},
        {name = "ei-2x2-container", prototype_type = "container", size = 2},
        {name = "ei-2x2-container-blue", prototype_type = "logistic-container", size = 2, logistic = true},
        {name = "ei-2x2-container-red", prototype_type = "logistic-container", size = 2, logistic = true},
        {name = "ei-2x2-container-pink", prototype_type = "logistic-container", size = 2, logistic = true},
        {name = "ei-2x2-container-yellow", prototype_type = "logistic-container", size = 2, logistic = true},
        {name = "ei-2x2-container-green", prototype_type = "logistic-container", size = 2, logistic = true},
        {name = "ei-2x2-container-filter", prototype_type = "container", size = 2, filter = true},
        {name = "ei-6x6-container", prototype_type = "container", size = 6},
        {name = "ei-6x6-container-blue", prototype_type = "logistic-container", size = 6, logistic = true},
        {name = "ei-6x6-container-red", prototype_type = "logistic-container", size = 6, logistic = true},
        {name = "ei-6x6-container-pink", prototype_type = "logistic-container", size = 6, logistic = true},
        {name = "ei-6x6-container-yellow", prototype_type = "logistic-container", size = 6, logistic = true},
        {name = "ei-6x6-container-green", prototype_type = "logistic-container", size = 6, logistic = true},
        {name = "ei-6x6-container-filter", prototype_type = "container", size = 6, filter = true},
    }

    for _, entry in ipairs(containers) do
        add_entry(entries, api, entry.name, entry.prototype_type, "entity", "metallic_chest", container_scene(simulation, entry.name, entry))
    end

    local logistic_structures = {
        {name = "ei-fueler", prototype_type = "container", zoom = 1.2},
        {name = "ei-gate-container", prototype_type = "container", zoom = 0.82, force_simulation = true},
        {name = "ei-gate-receiver", prototype_type = "container", scene = "gate_receiver", force_simulation = true},
        {name = "ei-black-hole", prototype_type = "container", zoom = 0.82, force_simulation = true},
    }

    for _, entry in ipairs(logistic_structures) do
        local scene = nil
        if entry.scene == "gate_receiver" then
            scene = gate_receiver_scene(simulation, entry.name, entry)
        else
            scene = large_container_scene(simulation, entry.name, entry)
        end
        add_entry(entries, api, entry.name, entry.prototype_type, "wall", "metal_large", scene, entry.force_simulation and force_simulation or nil)
    end

    local alien_ruins = {
        {name = "ei-alien-beacon_off-1", prototype_type = "container"},
        {name = "ei-alien-beacon_off-2", prototype_type = "container"},
        {name = "ei-alien-beacon_off-3", prototype_type = "container"},
        {name = "ei-crystal-accumulator_off-1", prototype_type = "container"},
        {name = "ei-crystal-accumulator_off-2", prototype_type = "container"},
        {name = "ei-crystal-accumulator_off-3", prototype_type = "container"},
        {name = "ei-crystal-accumulator_off-4", prototype_type = "container"},
        {name = "ei-farstation_off-1", prototype_type = "container"},
        {name = "ei-farstation_off-2", prototype_type = "container"},
        {name = "ei-farstation_off-3", prototype_type = "container"},
    }

    for _, entry in ipairs(alien_ruins) do
        add_entry(entries, api, entry.name, entry.prototype_type, "wall", "metal_large", alien_ruin_scene(simulation, entry.name, entry))
    end

    local loaders = {
        {name = "ei-steam-loader", belt = "transport-belt", chest = "wooden-chest", tiles = "stone-path"},
        {name = "ei-loader", belt = "transport-belt", chest = "steel-chest"},
        {name = "ei-fast-loader", belt = "fast-transport-belt", chest = "steel-chest"},
        {name = "ei-express-loader", belt = "express-transport-belt", chest = "passive-provider-chest"},
        {name = "ei-turbo-loader", belt = "turbo-transport-belt", chest = "requester-chest"},
        {name = "ei-neo-loader", belt = "ei-neo-belt", chest = "buffer-chest"},
    }

    for _, entry in ipairs(loaders) do
        add_entry(entries, api, entry.name, "loader-1x1", "entity", "transport_belt", loader_scene(simulation, entry.name, entry))
    end

    local belts = {
        {name = "ei-neo-belt", prototype_type = "transport-belt", zoom = 1.65},
        {name = "ei-neo-underground-belt", prototype_type = "underground-belt", zoom = 1.45, companions = {
            companion("ei-neo-belt", -2, 0, EAST),
            companion("ei-neo-belt", 2, 0, EAST),
            companion("small-electric-pole", 0, -2),
        }},
        {name = "ei-neo-splitter", prototype_type = "splitter", zoom = 1.35, companions = {
            companion("ei-neo-belt", -2, -0.5, EAST),
            companion("ei-neo-belt", -2, 0.5, EAST),
            companion("ei-neo-belt", 2, -0.5, EAST),
            companion("ei-neo-belt", 2, 0.5, EAST),
        }},
    }

    for _, entry in ipairs(belts) do
        add_entry(entries, api, entry.name, entry.prototype_type, "entity", "transport_belt", belt_scene(simulation, entry.name, entry))
    end

    local inserters = {
        {name = "ei-mechanical-inserter", tiles = "stone-path", input = "transport-belt", output = "wooden-chest"},
        {name = "ei-mechanical-long-inserter", zoom = 1.45, tiles = "stone-path", input = "transport-belt", output = "wooden-chest"},
        {name = "ei-steam-inserter", tiles = "stone-path", input = "transport-belt", output = "steel-chest"},
        {name = "ei-steam-long-inserter", zoom = 1.45, tiles = "stone-path", input = "transport-belt", output = "steel-chest"},
        {name = "ei-small-inserter-normal", input = "fast-transport-belt", output = "steel-chest"},
        {name = "ei-big-inserter-normal", zoom = 1.25, input = "express-transport-belt", output = "passive-provider-chest"},
    }

    for _, entry in ipairs(inserters) do
        add_entry(entries, api, entry.name, "inserter", "entity", "inserter", inserter_scene(simulation, entry.name, entry))
    end

    local fluids = {
        {name = "ei-tank-1", prototype_type = "storage-tank", tank = true, zoom = 1.0},
        {name = "ei-tank-2", prototype_type = "storage-tank", tank = true, zoom = 0.82},
        {name = "ei-tank-3", prototype_type = "storage-tank", tank = true, zoom = 0.72},
        {name = "ei-insulated-tank", prototype_type = "storage-tank", tank = true, zoom = 0.92},
        {name = "ei-insulated-pipe", prototype_type = "pipe", zoom = 1.55},
        {name = "ei-insulated-underground-pipe", prototype_type = "pipe-to-ground", zoom = 1.4},
        {name = "ei-data-pipe", prototype_type = "pipe", zoom = 1.5, tiles = "refined-concrete"},
        {name = "ei-basic-heat-pipe", prototype_type = "heat-pipe", zoom = 1.45, tiles = "stone-path"},
        {name = "ei-burner-offshore-pump", prototype_type = "offshore-pump", pump = true, zoom = 1.15, tiles = {
            {name = "stone-path", area = {{-5, -4}, {0, 4}}},
            {name = "water", area = {{1, -4}, {5, 4}}},
        }},
        {name = "ei-steam-offshore-pump", prototype_type = "offshore-pump", pump = true, zoom = 1.15, tiles = {
            {name = "stone-path", area = {{-5, -4}, {0, 4}}},
            {name = "water", area = {{1, -4}, {5, 4}}},
        }},
        {name = "ei-stone-well-pump", prototype_type = "offshore-pump", pump = true, zoom = 1.2, tiles = {
            {name = "stone-path", area = {{-5, -4}, {0, 4}}},
            {name = "water", area = {{1, -4}, {5, 4}}},
        }},
        {name = "ei-gaia-pump", prototype_type = "offshore-pump", pump = true, zoom = 1.15, tiles = {
            {name = "stone-path", area = {{-5, -4}, {0, 4}}},
            {name = "water", area = {{1, -4}, {5, 4}}},
        }},
    }

    for _, entry in ipairs(fluids) do
        local sound = entry.prototype_type == "storage-tank" and "metal_large" or "metal_small"
        local force = entry.prototype_type == "pipe-to-ground" and {factoriopedia_simulation = true} or nil
        add_entry(entries, api, entry.name, entry.prototype_type, "entity", sound, fluid_scene(simulation, entry.name, entry), force)
    end

    local walls = {
        {name = "ei-sanguine-wall", zoom = 1.45},
        {name = "ei-hemocrystal-wall", zoom = 1.45, tiles = "refined-concrete"},
    }

    for _, entry in ipairs(walls) do
        add_entry(entries, api, entry.name, "wall", "wall", false, wall_scene(simulation, entry.name, entry))
    end

    local miners = {
        {name = "ei-burner-quarry", tiles = "stone-path", zoom = 0.92, belt = "transport-belt", resource = "iron-ore", items = {{name = "coal", count = 10}}},
        {name = "ei-electric-quarry", tiles = "stone-path", zoom = 0.92, belt = "transport-belt", resource = "iron-ore", power = true},
        {name = "ei-steam-oil-pumpjack", tiles = "stone-path", zoom = 1.0, fluid = true, steam = true, resource = "crude-oil", resource_amount = 100000, fluids = {{name = "steam", amount = 200, temperature = 165}}},
        {name = "ei-steam-miner", tiles = "stone-path", zoom = 1.15, steam = true, resource = "stone", fluids = {{name = "steam", amount = 200, temperature = 165}}},
        {name = "ei-steam-quarry", tiles = "stone-path", zoom = 0.95, steam = true, resource = "coal", fluids = {{name = "steam", amount = 200, temperature = 165}}},
        {name = "ei-deep-drill", tiles = "stone-path", zoom = 0.86, fluid = true, resource = "ei-iron-patch", fluids = {{name = "ei-drill-fluid", amount = 200}}},
        {name = "ei-advanced-electric-mining-drill", tiles = "concrete", zoom = 1.0, resource = "iron-ore", power = true},
        {name = "ei-advanced-deep-drill", tiles = "concrete", zoom = 0.82, fluid = true, resource = "ei-neodym-patch", fluids = {{name = "ei-drill-fluid", amount = 200}}},
        {name = "ei-deep-pumpjack", tiles = "concrete", zoom = 0.9, fluid = true, resource = "ei-auric-fumarole", resource_amount = 100000, fluids = {{name = "ei-drill-fluid", amount = 200}}},
        {name = "ei-superior-electric-mining-drill", tiles = "refined-concrete", zoom = 0.95, belt = "ei-neo-belt", resource = "copper-ore", power = true},
    }

    for _, entry in ipairs(miners) do
        add_entry(entries, api, entry.name, "mining-drill", "entity", "drill", miner_scene(simulation, entry.name, entry))
    end

    local furnaces = {
        {name = "ei-camp-fire", prototype_type = "furnace", tiles = "stone-path", zoom = 1.45},
        {name = "ei-coke-furnace", prototype_type = "furnace", tiles = "stone-path", zoom = 1.18},
        {name = "ei-heat-steel-furnace", prototype_type = "furnace", tiles = "stone-path", zoom = 1.15, heat = true},
        {name = "ei-arc-furnace", prototype_type = "furnace", tiles = "concrete", zoom = 1.04, recipe = "ei-molten-iron-ore", items = {{name = "ei-poor-iron-chunk", count = 30}}, init_update_count = 120},
        {name = "ei-thermal-furnace", prototype_type = "furnace", tiles = "concrete", zoom = 1.0, heat = true},
        {name = "ei-cooler", prototype_type = "furnace", tiles = "concrete", zoom = 1.08, fluid = true, recipe = "ei-liquid-nitrogen", fluids = {{name = "ei-nitrogen-gas", amount = 200}}, init_update_count = 120},
        {name = "ei-plasma-heater", prototype_type = "furnace", tiles = "refined-concrete", zoom = 1.02, fluid = true, recipe = "ei-heated-protium", fluids = {{name = "ei-protium", amount = 120}}, init_update_count = 120},
        {name = "ei-basic-heat-exchanger", prototype_type = "boiler", tiles = "stone-path", zoom = 1.12, fluid = true, heat = true},
        {name = "ei-fluid-boiler", prototype_type = "boiler", tiles = "stone-path", zoom = 1.12, fluid = true},
    }

    for _, entry in ipairs(furnaces) do
        local sound = entry.prototype_type == "boiler" and "steam" or "machine"
        add_entry(entries, api, entry.name, entry.prototype_type, "entity", sound, furnace_scene(simulation, entry.name, entry))
    end

    local power_entities = {
        {name = "ei-burner-heater", prototype_type = "reactor", sound = "reactor", tiles = "stone-path", zoom = 1.1, heat = true, items = {{name = "coal", count = 10}}, init_update_count = 120},
        {name = "ei-fluid-heater", prototype_type = "reactor", sound = "steam", tiles = "stone-path", zoom = 1.1, heat = true, pipe = true, fluid = "light-oil", fluid_amount = 200, init_update_count = 120},
        {name = "ei-combustion-turbine", prototype_type = "burner-generator", sound = "steam", zoom = 0.62, camera = {0, -0.45}, pipe = true},
        {name = "ei-big-turbine", prototype_type = "generator", sound = "steam", zoom = 0.82, pipe = true, fluid = "ei-critical-steam", fluid_amount = 200, fluid_temperature = 1500, init_update_count = 120},
        {name = "ei-solar-panel-2", prototype_type = "solar-panel", sound = "electric_network", zoom = 1.08},
        {name = "ei-solar-panel-3", prototype_type = "solar-panel", sound = "electric_network", zoom = 1.08},
        {name = "ei-crystal-accumulator", prototype_type = "electric-energy-interface", sound = "electric_network", zoom = 1.0, energy = 1000000000, force_simulation = true},
        {name = "ei-crystal-accumulator-gaia", prototype_type = "electric-energy-interface", sound = "electric_network", zoom = 1.0, energy = 1000000000, force_simulation = true},
        {name = "ei-energy-extractor-pylon", prototype_type = "electric-energy-interface", sound = "electric_large", zoom = 0.95, energy = 1000000000, init_update_count = 90},
        {name = "ei_charger", prototype_type = "electric-energy-interface", sound = "electric_large", zoom = 0.82, camera = {0, -0.15}, scene = "charger"},
        {name = "ei-farstation", prototype_type = "electric-pole", sound = "electric_network", zoom = 0.88, energy = 1000000000, force_simulation = true},
    }

    for _, entry in ipairs(power_entities) do
        local scene = nil
        if entry.scene == "charger" then
            scene = charger_scene(simulation, entry.name, entry)
        else
            scene = power_scene(simulation, entry.name, entry)
        end
        add_entry(entries, api, entry.name, entry.prototype_type, "entity", entry.sound, scene, entry.force_simulation and force_simulation or nil)
    end

    local labs = {
        {name = "ei-dark-age-lab", zoom = 1.18, tiles = "stone-path"},
        {name = "ei-big-lab", zoom = 0.72, large = true},
    }

    for _, entry in ipairs(labs) do
        add_entry(entries, api, entry.name, "lab", "entity", "lab", lab_scene(simulation, entry.name, entry))
    end

    local beacons = {
        {name = "ei-copper-beacon", zoom = 1.1, machine = "assembling-machine-2"},
        {name = "ei-iron-beacon", zoom = 1.05, machine = "assembling-machine-3"},
        {name = "ei-alien-beacon", zoom = 0.88, machine = "ei-alien-stabilizer", tiles = "stone-path", fuel = "ei-bio-matter", module = "speed-module"},
        {name = "ei-warp-beacon", zoom = 0.78, machine = "ei-rift-stabilizer", tiles = "stone-path", fuel = "ei-bio-matter", module = "speed-module-2"},
    }

    for _, entry in ipairs(beacons) do
        add_entry(entries, api, entry.name, "beacon", "entity", "beacon", beacon_scene(simulation, entry.name, entry))
    end

    local robots = {
        {name = "ei-advanced-port", prototype_type = "roboport", hit = "entity", sound = "roboport", zoom = 1.05},
        {name = "ei-advanced-logistic-bot", prototype_type = "logistic-robot", hit = "flying_robot", sound = "roboport", chest = "requester-chest"},
        {name = "ei-cargo-bot", prototype_type = "logistic-robot", hit = "flying_robot", sound = "roboport", chest = "buffer-chest"},
        {name = "ei-advanced-construction-bot", prototype_type = "construction-robot", hit = "flying_robot", sound = "roboport", chest = "storage-chest"},
        {name = "ei-construction-bot", prototype_type = "construction-robot", hit = "flying_robot", sound = "roboport", chest = "storage-chest"},
    }

    for _, entry in ipairs(robots) do
        add_entry(entries, api, entry.name, entry.prototype_type, entry.hit, entry.sound, robot_scene(simulation, entry.name, entry))
    end

    for index = 0, 16 do
        local entry = {
            name = "ei-induction-matrix-core-" .. tostring(index),
            prototype_type = "electric-energy-interface",
            partner = "ei-induction-matrix-basic-coil",
            zoom = 1.0,
        }
        add_entry(entries, api, entry.name, entry.prototype_type, "entity", "electric_large", induction_scene(simulation, entry.name, entry))
    end

    local induction_matrix = {
        {name = "ei-induction-matrix-basic-coil", prototype_type = "container", partner = "ei-induction-matrix-core-0", zoom = 1.12},
        {name = "ei-induction-matrix-advanced-coil", prototype_type = "container", partner = "ei-induction-matrix-core-0", zoom = 1.12},
        {name = "ei-induction-matrix-superior-coil", prototype_type = "container", partner = "ei-induction-matrix-core-0", zoom = 1.12},
        {name = "ei-induction-matrix-basic-solenoid", prototype_type = "container", partner = "ei-induction-matrix-core-0", zoom = 1.12},
        {name = "ei-induction-matrix-advanced-solenoid", prototype_type = "container", partner = "ei-induction-matrix-core-0", zoom = 1.12},
        {name = "ei-induction-matrix-basic-converter", prototype_type = "container", partner = "ei-induction-matrix-core-0", zoom = 1.12},
        {name = "ei-induction-matrix-advanced-converter", prototype_type = "container", partner = "ei-induction-matrix-core-0", zoom = 1.12},
        {name = "ei-induction-matrix-superior-converter", prototype_type = "container", partner = "ei-induction-matrix-core-0", zoom = 1.12},
    }

    for _, entry in ipairs(induction_matrix) do
        add_entry(entries, api, entry.name, entry.prototype_type, "entity", "electric_large", induction_scene(simulation, entry.name, entry))
    end

    local machines = {
        {name = "ei-burner-assembler", tiles = "stone-path", zoom = 1.18, inserter = "burner-inserter"},
        {name = "ei-burner-surface-harvester", tiles = "stone-path", zoom = 1.0, inserter = "burner-inserter"},
        {name = "ei-steam-assembler", tiles = "stone-path", zoom = 1.12, pipe = true, inserter = "ei-steam-inserter"},
        {name = "ei-steam-crusher", tiles = "stone-path", zoom = 1.08, pipe = true, inserter = "ei-steam-inserter"},
        {name = "ei-heat-chemical-plant", tiles = "stone-path", zoom = 1.0, pipe = true, heat = true},
        {name = "ei-destill-tower", tiles = "stone-path", zoom = 0.86, pipe = true},
        {name = "ei-steam-surface-harvester", tiles = "stone-path", zoom = 1.0, pipe = true},
        {name = "ei-crusher", tiles = "concrete", zoom = 1.08, inserter = "fast-inserter", recipe = "ei-sand", init_update_count = 90},
        {name = "ei-waver-factory", tiles = "concrete", zoom = 1.02, pipe = true, recipe = "ei-semiconductor", init_update_count = 120},
        {name = "ei-grower", tiles = "concrete", zoom = 1.02, pipe = true, recipe = "ei-energy-crystal-growing", init_update_count = 150},
        {name = "ei-purifier", tiles = "concrete", zoom = 0.96, pipe = true, recipe = "ei-gold-chunk-purifier", init_update_count = 120},
        {name = "ei-caster", tiles = "concrete", zoom = 1.02, pipe = true, recipe = "ei-cast-iron-ingot", init_update_count = 120},
        {name = "ei-fission-facility", tiles = "concrete", zoom = 0.78, pipe = true, pole = "medium-electric-pole", large = true, recipe = "ei-fission-tech", init_update_count = 120},
        {name = "ei-castor", tiles = "concrete", zoom = 1.02, pipe = true, recipe = "ei-store-nuclear-waste", init_update_count = 120},
        {name = "ei-electric-surface-harvester", tiles = "concrete", zoom = 1.0, inserter = "fast-inserter", recipe = "ei-surface-harvester-running-nauvis", init_update_count = 90},
        {name = "ei-high-temperature-reactor", tiles = "concrete", zoom = 0.78, pipe = true, heat = true, pole = "medium-electric-pole", large = true},
        {name = "ei-exchanger", tiles = "concrete", zoom = 1.02, pipe = true, recipe = "ei-coolant-exchange", init_update_count = 120},
        {name = "ei-lufter", tiles = "concrete", zoom = 1.02, pipe = true, recipe = "ei-nitrogen-gas", init_update_count = 90},
        {name = "ei-computer-core", tiles = "refined-concrete", zoom = 0.84, lab = true, pole = "medium-electric-pole", large = true, recipe = "ei-computing-power", items = {{name = "ei-electronic-parts", count = 80}}, init_update_count = 120},
        {name = "ei-small-simulator", tiles = "refined-concrete", zoom = 1.08, lab = true, recipe = "ei-simulation-data", fluids = {{name = "ei-computing-power", amount = 120}}, init_update_count = 120},
        {name = "ei-advanced-chem-plant", tiles = "refined-concrete", zoom = 0.98, pipe = true, pole = "medium-electric-pole", recipe = "ei-dirty-water-stone-water", init_update_count = 120},
        {name = "ei-advanced-refinery", tiles = "refined-concrete", zoom = 0.76, pipe = true, pole = "medium-electric-pole", large = true, recipe = "ei-coke-advanced_coal", init_update_count = 120},
        {name = "ei-advanced-destill-tower", tiles = "refined-concrete", zoom = 0.82, pipe = true, pole = "medium-electric-pole", recipe = "ei-destill-light", init_update_count = 120},
        {name = "ei-advanced-centrifuge", tiles = "refined-concrete", zoom = 1.0, pipe = true, pole = "medium-electric-pole", recipe = "ei-seperate-uranium", init_update_count = 120},
        {name = "ei-bio-chamber", tiles = "refined-concrete", zoom = 0.98, pipe = true, recipe = "ei-evolved-alien-seed", init_update_count = 120},
        {name = "ei-bio-reactor", tiles = "refined-concrete", zoom = 0.9, pipe = true, recipe = "ei-sus-plating", init_update_count = 120},
        {name = "ei-excavator", tiles = "refined-concrete", zoom = 0.72, belt = "ei-neo-belt", inserter = "bulk-inserter", large = true, spread = 6.5, recipe = "ei-excavator-running-nauvis", init_update_count = 120},
        {name = "ei-quantum-computer", tiles = "refined-concrete", zoom = 0.72, lab = true, pole = "substation", large = true, spread = 6.5, recipe = "ei-space-data", items = {
            {name = "ei-simulation-data-chemical", count = 12},
            {name = "ei-simulation-data-organic", count = 12},
            {name = "ei-simulation-data-stone", count = 12},
            {name = "ei-simulation-data-uranium", count = 12},
            {name = "ei-simulation-data-petrified", count = 12},
            {name = "ei-simulation-data-scrap", count = 12},
        }, fluids = {
            {name = "ei-liquid-oxygen", amount = 300, index = 1},
            {name = "ei-liquid-nitrogen", amount = 300, index = 2},
        }, init_update_count = 150},
        {name = "ei-neo-assembler", tiles = "refined-concrete", zoom = 1.02, belt = "ei-neo-belt", inserter = "bulk-inserter", recipe = "ei-1x1-container", init_update_count = 90},
        {name = "ei-neutron-collector", tiles = "refined-concrete", zoom = 0.92, pipe = true, recipe = "ei-charged-neutron-container-10", init_update_count = 120},
        {name = "ei-neutron-activator", tiles = "refined-concrete", zoom = 0.98, pipe = true, recipe = "ei-deuterium-activator", init_update_count = 120},
        {name = "ei-fusion-reactor", tiles = "refined-concrete", zoom = 0.7, pipe = true, heat = true, pole = "substation", large = true, spread = 6.5, recipe = "ei-fusion-F1__ei-heated-deuterium-F2__ei-heated-tritium-TM__low-FM__low", fluids = {
            {name = "ei-heated-deuterium", amount = 50, index = 1},
            {name = "ei-heated-tritium", amount = 50, index = 2},
            {name = "ei-cold-coolant", amount = 150, index = 3},
        }, init_update_count = 150},
        {name = "ei-nano-factory", tiles = "refined-concrete", zoom = 0.86, belt = "ei-neo-belt", inserter = "bulk-inserter", recipe = "ei-carbon", init_update_count = 150},
        {name = "ei-advanced-crusher", tiles = "refined-concrete", zoom = 1.0, belt = "ei-neo-belt", inserter = "bulk-inserter", recipe = "ei-sand", init_update_count = 90},
        {name = "ei-exotic-assembler", tiles = "refined-concrete", zoom = 0.92, belt = "ei-neo-belt", inserter = "bulk-inserter", recipe = "ei-induction-matrix-superior-coil", init_update_count = 150},
        {name = "ei-matter-stabilizer", tiles = "refined-concrete", zoom = 0.78, pole = "substation", large = true, recipe = "ei-matter-stabilizer-running", init_update_count = 120},
        {name = "ei-accelerator", tiles = "refined-concrete", zoom = 0.68, pipe = true, pole = "substation", large = true, spread = 6.5, recipe = "ei-exotic-matter-up-conversion", items = {
            {name = "ei-exotic-matter-down", count = 12},
            {name = "ei-charged-neutron-container", count = 12},
            {name = "ei-enriched-cryodust", count = 12},
        }, init_update_count = 150},
        {name = "ei-alien-stabilizer", tiles = "stone-path", zoom = 0.84, pole = "medium-electric-pole", recipe = "ei-alien-stabilizer-running", init_update_count = 150},
        {name = "ei-rift-stabilizer", tiles = "stone-path", zoom = 0.84, pole = "medium-electric-pole", recipe = "ei-alien-stabilizer-running", init_update_count = 150},
        {name = "ei-energy-injector-pylon", tiles = "refined-concrete", zoom = 0.84, pipe = true, pole = "substation", large = true, recipe = "ei-energy-injector-pylon-running", init_update_count = 120},
        {name = "ei-metalworks-1", tiles = "concrete", zoom = 1.12, inserter = "inserter", recipe = "ei-iron-ingot-chunk-smelting-metalworks", init_update_count = 90},
        {name = "ei-metalworks-2", tiles = "concrete", zoom = 1.08, inserter = "fast-inserter", recipe = "ei-iron-ingot-chunk-smelting-metalworks", init_update_count = 90},
        {name = "ei-metalworks-3", tiles = "refined-concrete", zoom = 1.05, inserter = "bulk-inserter", recipe = "ei-iron-ingot-chunk-smelting-metalworks", init_update_count = 90},
        {name = "ei-metalworks-4", tiles = "refined-concrete", zoom = 1.0, belt = "ei-neo-belt", inserter = "bulk-inserter", recipe = "ei-iron-ingot-chunk-smelting-metalworks", init_update_count = 90},
        {name = "ei-auric-inoculation-vat", tiles = "refined-concrete", zoom = 0.78, pipe = true, pole = "medium-electric-pole", large = true, recipe = "ei-auric-vat-bloom", init_update_count = 120},
        {name = "ei-steampunk-lamp", tiles = "stone-path", zoom = 1.35, pipe = true, pole = "small-electric-pole", recipe = "ei-steampunk-lamp-running", init_update_count = 120},
    }

    for _, entry in ipairs(machines) do
        local sound = entry.heat and "electric_large" or "machine"
        local scene = entry.large and large_machine_scene(simulation, entry.name, entry) or machine_scene(simulation, entry.name, entry)
        add_entry(entries, api, entry.name, "assembling-machine", "entity", sound, scene)
    end

    local orbital_logistics = {
        {name = "ei-orbital-combinator", zoom = 1.35},
        {name = "ei-platform-transponder", zoom = 1.45},
        {name = "ei-orbital-selector", zoom = 1.24},
        {name = "ei-orbital-coordinator", zoom = 0.84},
        {name = "ei-orbital-dispatch-uplink", zoom = 1.18},
    }

    for _, entry in ipairs(orbital_logistics) do
        add_entry(entries, api, entry.name, "constant-combinator", "entity", "combinator", orbital_scene(simulation, entry.name, entry))
    end

    local holos = {
        {name = "ei-holo-moon", zoom = 1.16},
        {name = "ei-holo-mars", zoom = 1.16},
        {name = "ei-holo-sulf", zoom = 1.16},
        {name = "ei-holo-uran", zoom = 1.16},
        {name = "ei-holo-gas-giant", zoom = 1.08},
        {name = "ei-holo-nauvis-orbit", zoom = 1.08},
        {name = "ei-holo-sun", zoom = 1.08},
        {name = "ei-holo-asteroid", zoom = 1.08},
        {name = "ei-holo-black-hole", zoom = 1.08},
        {name = "ei-holo-galaxy", zoom = 1.08},
    }

    for _, entry in ipairs(holos) do
        add_entry(entries, api, entry.name, "assembling-machine", "entity", "electric_network", holo_scene(simulation, entry.name, entry))
    end

    return entries
end

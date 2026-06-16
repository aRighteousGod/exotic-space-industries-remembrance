--==============================================================================
-- ESIR FILE MAP
-- owns: combat, rolling-stock, vehicle, and optional legacy entity presentation entries
-- loaded_by: entity presentation registry loader
-- cadence: data-final-updates load
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: data-final-updates reload, prototype cache rebuild
--==============================================================================

local function prototype_exists(prototype_type, name)
    if not data or not data.raw then
        return true
    end

    return data.raw[prototype_type] and data.raw[prototype_type][name] ~= nil
end

local function add(entries, api, name, opts)
    if not prototype_exists(opts.type, name) then
        return
    end

    if opts.simulation_factory then
        opts.simulation = opts.simulation_factory()
        opts.simulation_factory = nil
    end

    local entry = api.entity(name, opts)
    if entry then
        entries[#entries + 1] = entry
    end
end

local EAST = 4
local force_simulation = {factoriopedia_simulation = true}

local function turret_scene(opts)
    return {
        camera_zoom = opts.zoom or 1.0,
        camera_position = {opts.camera_x or 0, opts.camera_y or 0},
        direction = opts.direction or EAST,
        ammo = opts.ammo,
        fluid = opts.fluid,
        power = opts.feed == "electric",
        energy = opts.energy,
        active = true,
        init_update_count = opts.init_update_count or 30,
    }
end

local function train_scene(opts)
    return {
        camera_zoom = opts.zoom or 0.62,
        camera_position = {opts.camera_x or 0, opts.camera_y or 0},
        direction = opts.direction or 0,
        rails = {
            length = opts.rail_length or 6,
        },
        init_update_count = opts.init_update_count or 30,
    }
end

local function vehicle_scene(opts)
    return {
        camera_zoom = opts.zoom or 0.72,
        camera_position = {opts.camera_x or 0, opts.camera_y or 0},
        direction = opts.direction or EAST,
        ammo = opts.ammo,
        power = opts.feed == "electric",
        active = true,
        init_update_count = opts.init_update_count or 30,
    }
end

return function(api)
    local entries = {}

    local ammo_turrets = {
        {
            name = "ei-shotgun-turret",
            ammo = "piercing-shotgun-shell",
            zoom = 1.14,
        },
        {
            name = "ei-auto-shotgun-turret",
            ammo = "piercing-shotgun-shell",
            zoom = 1.08,
        },
        {
            name = "ei-cannon-turret-mk1",
            ammo = "cannon-shell",
            zoom = 0.76,
        },
        {
            name = "ei-cannon-turret",
            ammo = "explosive-cannon-shell",
            zoom = 0.74,
        },
        {
            name = "ei-gatling-turret",
            ammo = "piercing-rounds-magazine",
            zoom = 0.86,
        },
    }

    for _, turret in ipairs(ammo_turrets) do
        add(entries, api, turret.name, {
            type = "ammo-turret",
            hit = "entity",
            sound = "turret",
            simulation_factory = function()
                return api.simulation.entity(turret.name, turret_scene(turret))
            end,
        })
    end

    local electric_turrets = {
        {
            name = "ei-sawblade-turret",
            zoom = 1.12,
            feed = "electric",
            energy = 10000000,
        },
        {
            name = "tl-basic-tesla-coil",
            zoom = 1.08,
            feed = "electric",
            energy = 1000000000,
        },
        {
            name = "tl-advanced-tesla-coil",
            zoom = 0.88,
            feed = "electric",
            energy = 1000000000,
        },
    }

    for _, turret in ipairs(electric_turrets) do
        add(entries, api, turret.name, {
            type = "electric-turret",
            hit = "entity",
            sound = "turret",
            simulation_factory = function()
                return api.simulation.entity(turret.name, turret_scene(turret))
            end,
        })
    end

    add(entries, api, "ei-plasma-turret", {
        type = "electric-turret",
        hit = "entity",
        sound = "turret",
        force = force_simulation,
        simulation_factory = function()
            return api.simulation.entity("ei-plasma-turret", turret_scene({
                zoom = 0.78,
                feed = "electric",
                energy = 2000000000,
            }))
        end,
    })

    add(entries, api, "ei-singularity-lance", {
        type = "electric-turret",
        hit = "entity",
        sound = "turret",
        force = force_simulation,
        simulation_factory = function()
            return api.simulation.entity("ei-singularity-lance", turret_scene({
                zoom = 0.72,
                feed = "electric",
                energy = 2000000000,
            }))
        end,
    })

    add(entries, api, "ei-acidthrower-turret", {
        type = "fluid-turret",
        hit = "entity",
        sound = "turret",
        simulation_factory = function()
            return api.simulation.entity("ei-acidthrower-turret", turret_scene({
                zoom = 0.94,
                feed = "acid",
                fluid = "sulfuric-acid",
            }))
        end,
    })

    local locomotives = {
        {
            name = "ei-steam-basic-locomotive",
            consist = {"ei-steam-basic-locomotive", "ei-steam-basic-wagon"},
            zoom = 0.56,
        },
        {
            name = "ei-steam-advanced-locomotive",
            consist = {"ei-steam-advanced-locomotive", "ei-steam-advanced-wagon"},
            zoom = 0.54,
        },
        {
            name = "ei-nuclear-locomotive",
            consist = {"ei-nuclear-locomotive", "ei-advanced-cargo-wagon", "ei-advanced-fluid-wagon"},
            zoom = 0.54,
        },
        {
            name = "ei_em-locomotive",
            consist = {"ei_em-locomotive", "ei_em-cargo-wagon", "ei_em-fluid-wagon"},
            zoom = 0.50,
        },
    }

    for _, locomotive in ipairs(locomotives) do
        add(entries, api, locomotive.name, {
            type = "locomotive",
            hit = "entity",
            sound = "train_door",
            force = {factoriopedia_simulation = true},
            simulation_factory = function()
                return api.simulation.train(locomotive.name, train_scene(locomotive))
            end,
        })
    end

    add(entries, api, "ei-steam-basic-locomotive-placement-entity", {
        type = "locomotive",
        hit = "entity",
        sound = "train_door",
        force = {factoriopedia_simulation = true},
        simulation_factory = function()
            return api.simulation.train("ei-steam-basic-locomotive-placement-entity", train_scene({
                consist = {"ei-steam-basic-locomotive-placement-entity"},
                zoom = 0.58,
            }))
        end,
    })

    local cargo_wagons = {
        {
            name = "ei-steam-basic-wagon",
            consist = {"ei-steam-basic-locomotive", "ei-steam-basic-wagon"},
            zoom = 0.58,
        },
        {
            name = "ei-steam-advanced-wagon",
            consist = {"ei-steam-advanced-locomotive", "ei-steam-advanced-wagon"},
            zoom = 0.56,
        },
        {
            name = "ei-advanced-cargo-wagon",
            consist = {"ei-nuclear-locomotive", "ei-advanced-cargo-wagon"},
            zoom = 0.56,
        },
        {
            name = "ei_em-cargo-wagon",
            consist = {"ei_em-locomotive", "ei_em-cargo-wagon"},
            zoom = 0.54,
        },
    }

    for _, wagon in ipairs(cargo_wagons) do
        add(entries, api, wagon.name, {
            type = "cargo-wagon",
            hit = "entity",
            sound = "cargo_wagon",
            force = {factoriopedia_simulation = true},
            simulation_factory = function()
                return api.simulation.train(wagon.name, train_scene(wagon))
            end,
        })
    end

    local fluid_wagons = {
        {
            name = "ei-advanced-fluid-wagon",
            consist = {"ei-nuclear-locomotive", "ei-advanced-fluid-wagon"},
            sound = "cargo_wagon",
            zoom = 0.56,
        },
        {
            name = "ei-steam-advanced-fluid-wagon",
            consist = {"ei-steam-advanced-locomotive", "ei-steam-advanced-fluid-wagon"},
            sound = "cargo_wagon",
            zoom = 0.56,
        },
        {
            name = "ei_em-fluid-wagon",
            consist = {"ei_em-locomotive", "ei_em-fluid-wagon"},
            sound = "cargo_wagon",
            zoom = 0.54,
        },
    }

    for _, wagon in ipairs(fluid_wagons) do
        add(entries, api, wagon.name, {
            type = "fluid-wagon",
            hit = "entity",
            sound = wagon.sound,
            force = {factoriopedia_simulation = true},
            simulation_factory = function()
                return api.simulation.train(wagon.name, train_scene(wagon))
            end,
        })
    end

    local vehicles = {
        {
            name = "tl-tesla-tank",
            type = "car",
            ammo = "tl-tesla-coil-ammo",
            zoom = 0.78,
            feed = "electric",
        },
        {
            name = "ei-emerald-apocalypse-hover-tank",
            type = "car",
            ammo = "ei-emerald-apocalypse-charge",
            zoom = 0.72,
            force_simulation = true,
        },
        {
            name = "ei-gaian-saucer",
            type = "spider-vehicle",
            zoom = 0.95,
            force_simulation = true,
        },
    }

    for _, vehicle in ipairs(vehicles) do
        add(entries, api, vehicle.name, {
            type = vehicle.type or "car",
            hit = "entity",
            sound = "car_door",
            force = vehicle.force_simulation and force_simulation or nil,
            simulation_factory = function()
                return api.simulation.entity(vehicle.name, vehicle_scene(vehicle))
            end,
        })
    end

    return entries
end

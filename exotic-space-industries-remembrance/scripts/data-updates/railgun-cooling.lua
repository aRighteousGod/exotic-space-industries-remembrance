require("util")

local ei_lib = require("lib/lib")

local PROXY_NAME = "ei-railgun-cooling-proxy"
local DIAGONAL_PROXY_NAMES = {
    [defines.direction.northwest] = PROXY_NAME .. "-nw",
    [defines.direction.northeast] = PROXY_NAME .. "-ne",
    [defines.direction.southwest] = PROXY_NAME .. "-sw",
    [defines.direction.southeast] = PROXY_NAME .. "-se",
}
local SHOT_EFFECT_ID = "ei-railgun-cooling-shot"
local ICE_RECIPE_NAME = "ei-fluoroketone-cooling-ice"

local function append_effect(effect_container, new_effect)
    if not effect_container then
        return {new_effect}
    end

    if effect_container.type then
        return {effect_container, new_effect}
    end

    effect_container[#effect_container + 1] = new_effect
    return effect_container
end

local function make_hidden_proxy()
    if data.raw["assembling-machine"][PROXY_NAME] then
        return
    end

    local base = data.raw["assembling-machine"]["assembling-machine-3"]
    if not base then
        return
    end

    local railgun_item = data.raw.item["railgun-turret"]
    local proxy = table.deepcopy(base)
    proxy.name = PROXY_NAME
    proxy.icon = railgun_item and railgun_item.icon or proxy.icon
    proxy.icon_size = railgun_item and railgun_item.icon_size or proxy.icon_size
    proxy.minable = nil
    proxy.max_health = 1
    proxy.flags = {
        "not-on-map",
        "not-deconstructable",
        "not-blueprintable",
        "not-upgradable",
        "not-repairable",
    }
    proxy.selectable_in_game = false
    proxy.allow_copy_paste = false
    proxy.destructible = false
    proxy.collision_box = {{-1.5, -1.5}, {1.5, 1.5}}
    proxy.selection_box = {{0, 0}, {0, 0}}
    proxy.collision_mask = {layers = {}}
    proxy.hidden = true
    proxy.hidden_in_factoriopedia = true
    proxy.fast_replaceable_group = nil
    proxy.next_upgrade = nil
    proxy.show_recipe_icon = false
    proxy.energy_usage = "1W"
    proxy.energy_source = {
        type = "electric",
        usage_priority = "secondary-input",
        buffer_capacity = "1J",
        input_flow_limit = "1W",
        emissions_per_minute = {pollution = 0},
        render_no_power_icon = false,
        render_no_network_icon = false,
    }
    proxy.crafting_categories = {"crafting"}
    proxy.ingredient_count = 255
    proxy.module_slots = 0
    proxy.allowed_effects = {}
    proxy.fluid_boxes_off_when_no_fluid_recipe = false
    proxy.graphics_set = {
        animation = util.empty_sprite(),
        working_visualisations = {},
    }
    proxy.working_sound = nil
    proxy.open_sound = nil
    proxy.close_sound = nil
    proxy.circuit_connector = nil
    proxy.circuit_wire_max_distance = 0
    proxy.fluid_boxes = {
        {
            production_type = "input",
            filter = "fluoroketone-cold",
            pipe_picture = ei_pipe_big_insulated,
            pipe_covers = pipecoverspictures(),
            volume = 100,
            pipe_connections = {
                {flow_direction = "input", direction = defines.direction.south, position = {1, 1}},
            },
        },
        {
            production_type = "output",
            filter = "fluoroketone-hot",
            pipe_picture = ei_pipe_big_insulated,
            pipe_covers = pipecoverspictures(),
            volume = 100,
            pipe_connections = {
                {flow_direction = "output", direction = defines.direction.south, position = {-1, 1}},
            },
        },
    }

    local diagonal_proxies = {}
    local diagonal_inputs = {
        [defines.direction.northwest] = {flow_direction = "input", direction = defines.direction.east, position = {1, 0}},
        [defines.direction.northeast] = {flow_direction = "input", direction = defines.direction.west, position = {-1, 0}},
        [defines.direction.southwest] = {flow_direction = "input", direction = defines.direction.west, position = {-1, 0}},
        [defines.direction.southeast] = {flow_direction = "input", direction = defines.direction.east, position = {1, 0}},
    }
    local diagonal_output = {flow_direction = "output", direction = defines.direction.south, position = {0, 1}}

    for direction, proxy_name in pairs(DIAGONAL_PROXY_NAMES) do
        local diagonal_proxy = table.deepcopy(proxy)
        diagonal_proxy.name = proxy_name
        diagonal_proxy.fluid_boxes[1].pipe_connections = {table.deepcopy(diagonal_inputs[direction])}
        diagonal_proxy.fluid_boxes[2].pipe_connections = {table.deepcopy(diagonal_output)}
        diagonal_proxies[#diagonal_proxies + 1] = diagonal_proxy
    end

    local prototypes = {proxy}
    for _, diagonal_proxy in ipairs(diagonal_proxies) do
        prototypes[#prototypes + 1] = diagonal_proxy
    end

    data:extend(prototypes)
end

local function patch_railgun_ammo()
    local ammo = data.raw.ammo["railgun-ammo"]
    local delivery = ammo
        and ammo.ammo_type
        and ammo.ammo_type.action
        and ammo.ammo_type.action.action_delivery
        or nil
    if not delivery then
        return
    end

    delivery.source_effects = append_effect(delivery.source_effects, {
        type = "script",
        effect_id = SHOT_EFFECT_ID,
    })
end

local function add_ice_cooling_recipe()
    if data.raw.recipe[ICE_RECIPE_NAME] then
        return
    end

    local base_recipe = data.raw.recipe["fluoroketone-cooling"]
    if not base_recipe then
        return
    end

    local recipe = table.deepcopy(base_recipe)
    recipe.name = ICE_RECIPE_NAME
    recipe.localised_name = {"recipe-name." .. ICE_RECIPE_NAME}
    recipe.localised_description = {"recipe-description." .. ICE_RECIPE_NAME}
    recipe.order = (base_recipe.order or "z") .. "-ice"
    recipe.enabled = false
    recipe.allow_productivity = false
    recipe.auto_recycle = false
    recipe.ingredients = {
        {type = "fluid", name = "fluoroketone-hot", amount = 10, ignored_by_stats = 10},
        {type = "item", name = "ice", amount = 2},
    }
    recipe.results = {
        {type = "fluid", name = "fluoroketone-cold", amount = 10, temperature = -150, ignored_by_stats = 10},
        {type = "fluid", name = "steam", amount = 40, temperature = 500},
    }

    data:extend({recipe})
    ei_lib.add_unlock_recipe("cryogenic-plant", ICE_RECIPE_NAME)
end

make_hidden_proxy()
patch_railgun_ammo()
add_ice_cooling_recipe()

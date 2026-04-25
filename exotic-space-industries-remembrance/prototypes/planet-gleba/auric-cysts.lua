--==============================================================================
-- ESIR FILE MAP
-- owns: auric cyst node entity, item, and gleba-local washing recipe
-- loaded_by: exotic-space-industries-remembrance\prototypes\planet-gleba\gleba.lua
-- cadence: data-stage load
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: data stage reload, prototype cache rebuild
--==============================================================================
local util = require("util")

local main_graphics_path = ei_path .. "graphics/"
local cyst_icon_path = main_graphics_path .. "items/auric-cyst.png"
local cyst_node_shadow_path = main_graphics_path .. "entities/auric-cyst-node/auric-cyst-node-shadow.png"
local cyst_node_variation_paths = {
    main_graphics_path .. "entities/auric-cyst-node/auric-cyst-1.png",
    main_graphics_path .. "entities/auric-cyst-node/auric-cyst-2.png",
    main_graphics_path .. "entities/auric-cyst-node/auric-cyst-3.png",
    main_graphics_path .. "entities/auric-cyst-node/auric-cyst-4.png",
    main_graphics_path .. "entities/auric-cyst-node/auric-cyst-5.png",
    main_graphics_path .. "entities/auric-cyst-node/auric-cyst-6.png",
}

local function make_cyst_node_sprite(filename)
    local shift = util.by_pixel(0, -10)
    local scale = 0.36

    return {
        filename = filename,
        flags = {"mipmap"},
        width = 512,
        height = 512,
        frame_count = 1,
        shift = shift,
        scale = scale,
    }
end

local function make_cyst_node_variation(filename)
    local scale = 0.36
    local variation = table.deepcopy(data.raw["plant"]["jellystem"].variations[1])

    variation.trunk = make_cyst_node_sprite(filename)
    variation.leaves = util.empty_sprite()
    variation.normal = nil
    variation.shadow = {
        frame_count = 2,
        lines_per_file = 1,
        line_length = 1,
        flags = {"shadow"},
        filenames = {
            cyst_node_shadow_path,
            cyst_node_shadow_path,
        },
        width = 512,
        height = 512,
        shift = util.by_pixel(10, 20),
        scale = scale,
    }
    variation.underwater = nil
    variation.water_reflection = nil
    variation.leaves_when_damaged = 12
    variation.leaves_when_destroyed = 8
    variation.leaves_when_mined_manually = 8
    variation.leaves_when_mined_automatically = 4
    variation.branches_when_damaged = 8
    variation.branches_when_destroyed = 6
    variation.branches_when_mined_manually = 6
    variation.branches_when_mined_automatically = 2

    return variation
end

local function make_cyst_node_variations()
    local variations = {}

    for _, filename in ipairs(cyst_node_variation_paths) do
        variations[#variations + 1] = make_cyst_node_variation(filename)
    end

    return variations
end

local cyst_node = table.deepcopy(data.raw["plant"]["jellystem"])
cyst_node.name = "ei-auric-cyst-node"
cyst_node.icon = cyst_icon_path
cyst_node.icon_size = 256
cyst_node.flags = {"placeable-neutral", "placeable-off-grid", "breaths-air", "not-blueprintable"}
cyst_node.minable = {
    mining_time = 0.75,
    results = {
        {type = "item", name = "ei-auric-cyst", amount = 2},
        {type = "item", name = "spoilage", amount_min = 1, amount_max = 3, ignored_by_stats = 3},
    },
}
cyst_node.max_health = 65
cyst_node.collision_box = {{-0.7, -0.7}, {0.7, 0.7}}
cyst_node.selection_box = {{-0.9, -1.15}, {0.9, 0.8}}
cyst_node.drawing_box_vertical_extension = 0.45
cyst_node.autoplace = nil
cyst_node.subgroup = "trees"
cyst_node.order = "a[tree]-c[gleba]-d[auric-cyst-node]"
cyst_node.factoriopedia_simulation = nil
cyst_node.variations = make_cyst_node_variations()
cyst_node.colors = {
    {r = 255, g = 245, b = 235},
}
cyst_node.agricultural_tower_tint = {
    primary = {r = 0.80, g = 0.44, b = 0.30, a = 1.0},
    secondary = {r = 0.62, g = 0.69, b = 0.28, a = 1.0},
}
cyst_node.ambient_sounds = nil
cyst_node.map_color = {255, 215, 140}

local cyst_washing_recipe = {
    type = "recipe",
    name = "ei-auric-cyst-washing",
    category = "ei-purifier",
    energy_required = 4,
    ingredients = {
        {type = "item", name = "ei-auric-cyst", amount = 2},
        {type = "fluid", name = "water", amount = 20},
    },
    results = {
        {type = "item", name = "ei-gold-chunk", amount = 2},
        {type = "fluid", name = "ei-dirty-water", amount = 20, ignored_by_stats = 20},
    },
    always_show_made_in = true,
    allow_productivity = false,
    auto_recycle = false,
    enabled = false,
    main_product = "ei-gold-chunk",
    icons = {
        {
            icon = cyst_icon_path,
            icon_size = 256,
        },
        {
            icon = "__base__/graphics/icons/fluid/water.png",
            icon_size = 64,
            scale = 0.32,
            shift = {8, 8},
        },
    },
    subgroup = "ei-refining-extraction",
    order = "z[auric-cyst-washing]",
    surface_conditions = {
        {property = "pressure", min = 2000, max = 2000},
    },
}

data:extend({
    {
        type = "item",
        name = "ei-auric-cyst",
        icon = cyst_icon_path,
        icon_size = 256,
        subgroup = "intermediate-product",
        order = "z[auric-cyst]",
        stack_size = 50,
        auto_recycle = false,
    },
    cyst_node,
    cyst_washing_recipe,
})

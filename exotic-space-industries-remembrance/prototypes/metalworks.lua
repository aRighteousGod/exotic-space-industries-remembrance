--====================================================================================================
-- METALWORKS PROTOTYPES
--====================================================================================================

--ITEMS AND TECHS
------------------------------------------------------------------------------------------------------

data:extend({
    -- metalworks 1,2,3,4
    {
        name = "ei-metalworks-1",
        type = "item",
        icon = ei_graphics_item_path.."metalworks_1.png",
        icon_size = 64,
        subgroup = "production-machine",
        order = "a[assembling-machine-1]-a",
        place_result = "ei-metalworks-1",
        stack_size = 50
    },
    {
        name = "ei-metalworks-1",
        type = "recipe",
        category = "crafting",
        energy_required = 0.5,
        ingredients =
        {
            {type="item", name="assembling-machine-1", amount=1},
            {type="item", name="electric-engine-unit", amount=4},
            {type="item", name="ei-iron-mechanical-parts", amount=2},
        },
        results = {{type="item", name="ei-metalworks-1", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-metalworks-1",
    },
    {
        name = "ei-metalworks-2",
        type = "item",
        icon = ei_graphics_item_path.."metalworks_2.png",
        icon_size = 64,
        subgroup = "production-machine",
        order = "b[assembling-machine-2]-a",
        place_result = "ei-metalworks-2",
        stack_size = 50
    },
    {
        name = "ei-metalworks-2",
        type = "recipe",
        category = "crafting",
        energy_required = 0.5,
        ingredients =
        {
            {type="item", name="assembling-machine-2", amount=1},
            {type="item", name="electric-engine-unit", amount=4},
            {type="item", name="ei-iron-mechanical-parts", amount=2},
        },
        results = {{type="item", name="ei-metalworks-2", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-metalworks-2",
    },
    {
        name = "ei-metalworks-3",
        type = "item",
        icon = ei_graphics_item_path.."metalworks_3.png",
        icon_size = 64,
        subgroup = "production-machine",
        order = "c[assembling-machine-3]-a",
        place_result = "ei-metalworks-3",
        stack_size = 50
    },
    {
        name = "ei-metalworks-3",
        type = "recipe",
        category = "crafting",
        energy_required = 0.5,
        ingredients =
        {
            {type="item", name="assembling-machine-3", amount=1},
            {type="item", name="ei-advanced-motor", amount=4},
            {type="item", name="ei-steel-mechanical-parts", amount=2},
        },
        results = {{type="item", name="ei-metalworks-3", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-metalworks-3",
    },
    {
        name = "ei-metalworks-4",
        type = "item",
        icon = ei_graphics_item_path.."metalworks_4.png",
        icon_size = 64,
        subgroup = "production-machine",
        order = "c[assembling-machine-3]-c",
        place_result = "ei-metalworks-4",
        stack_size = 50
    },
    {
        name = "ei-metalworks-4",
        type = "recipe",
        category = "crafting",
        energy_required = 0.5,
        ingredients =
        {
            {type="item", name="ei-neo-assembler", amount=1},
            {type="item", name="ei-advanced-motor", amount=4},
            {type="item", name="ei-steel-mechanical-parts", amount=2},
        },
        results = {{type="item", name="ei-metalworks-4", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-metalworks-4",
    },
    {
        name = "ei-metalworks",
        type = "recipe-category",
    }
})

--ENTITIES
------------------------------------------------------------------------------------------------------

local entity_base = {
    name = "ei-metalworks-1",
    type = "assembling-machine",
    icon = ei_graphics_item_path.."metalworks_1.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {
        mining_time = 0.5,
        result = "ei-metalworks-1"
    },
    max_health = 300,
    corpse = "big-remnants",
    dying_explosion = "medium-explosion",
    collision_box = {{-0.9, -0.9}, {0.9, 0.9}},
    selection_box = {{-1.0, -1.0}, {1.0, 1.0}},
    map_color = ei_data.colors.assembler,
    crafting_categories = {"ei-metalworks"},
    crafting_speed = 1,
    energy_source = {
        type = 'electric',
        usage_priority = 'secondary-input',
    },
    energy_usage = "150kW",
    graphics_set = {
        animation = {
            layers = {
                {
                    filename = "__base__/graphics/entity/assembling-machine-1/assembling-machine-1.png",
                    priority = "high",
                    width = 214,
                    height = 226,
                    frame_count = 32,
                    line_length = 8,
                    shift = util.by_pixel(0, 2 * 2 / 3),
                    scale = 1/3,
                },
                {
                    filename = "__base__/graphics/entity/assembling-machine-1/assembling-machine-1-shadow.png",
                    priority = "high",
                    width = 190,
                    height = 165,
                    frame_count = 1,
                    line_length = 1,
                    repeat_count = 32,
                    draw_as_shadow = true,
                    shift = util.by_pixel(8.5 * 2 / 3, 5 * 2 / 3),
                    scale = 1/3
                }
            }
        },
    },
    fast_replaceable_group = "ei-metalworks",
    next_upgrade = "ei-metalworks-2",
    working_sound =
    {
        sound = {filename = "__base__/sound/electric-mining-drill.ogg", volume = 0.8},
        apparent_volume = 0.3,
    },
}

local function make_metalworks(base, foo, level, max_level, animation, result)

    local entity = util.table.deepcopy(base)
    entity.name = "ei-metalworks-"..level
    entity.icon = ei_graphics_item_path.."metalworks_"..level..".png"
    if result then
        entity.minable.result = result
    else
        entity.minable.result = "ei-metalworks-"..level
    end
    entity.crafting_speed = 0.75 + (level-1)*0.5
    entity.energy_usage = tostring(150*level).."kW"
    if animation then
        entity.graphics_set = { animation = animation }
    else
        entity.graphics_set.animation.layers[1].filename = "__base__/graphics/entity/assembling-machine-"..level.."/assembling-machine-"..level..".png"
        entity.graphics_set.animation.layers[1].width = foo[1].width
        entity.graphics_set.animation.layers[1].height = foo[1].height
        entity.graphics_set.animation.layers[1].shift = foo[1].shift

        entity.graphics_set.animation.layers[2].filename = "__base__/graphics/entity/assembling-machine-"..level.."/assembling-machine-"..level.."-shadow.png"
        entity.graphics_set.animation.layers[2].width = foo[2].width
        entity.graphics_set.animation.layers[2].height = foo[2].height
        entity.graphics_set.animation.layers[2].shift = foo[2].shift
    end

    if level < max_level then
        entity.next_upgrade = "ei-metalworks-"..(level+1)
    else
        entity.next_upgrade = nil
    end

    data:extend({entity})
end

local metalworks_4_animation = util.table.deepcopy(data.raw["assembling-machine"]["ei-neo-assembler"])
-- has 4 entries in layer, and also hr versions, mutiply their scale with 2/3 and 1/3 respectively
for _, layer in ipairs(metalworks_4_animation.graphics_set.animation.layers) do
    if not layer.scale then
        layer.scale = 1
    end
    layer.scale = layer.scale * 2/3
end

local foo_1 = {
    {
        width = 214,
        height = 226,
        shift = util.by_pixel(0, 2 * 2 / 3),
    },
    {
        width = 190,
        height = 165,
        shift = util.by_pixel(8.5 * 2 / 3, 5 * 2 / 3),
    }
}
local foo_2 = {
    {
        width = 214,
        height = 218,
        shift = util.by_pixel(0, 4 * 2 / 3),
    },
    {
        width = 196,
        height = 163,
        shift = util.by_pixel(12 * 2 / 3, 4.75 * 2 / 3),
    }
}
local foo_3 = {
    {
        width = 214,
        height = 237,
        shift = util.by_pixel(0 * 2 / 3, -0.75 * 2 / 3),
    },
    {
        width = 260,
        height = 162,
        shift = util.by_pixel(28 * 2 / 3, 4 * 2 / 3),
    }
}

make_metalworks(entity_base, foo_1, 1, 4)
make_metalworks(entity_base, foo_2, 2, 4)
make_metalworks(entity_base, foo_3, 3, 4)
make_metalworks(entity_base, foo_1, 4, 4, metalworks_4_animation.graphics_set.animation, "ei-metalworks-4")

-- add the metalworks to their respective techs
table.insert(
    data.raw["technology"]["automation"].effects,
    {type = "unlock-recipe", recipe = "ei-metalworks-1"}
)
table.insert(
    data.raw["technology"]["automation-2"].effects,
    {type = "unlock-recipe", recipe = "ei-metalworks-2"}
)
table.insert(
    data.raw["technology"]["automation-3"].effects,
    {type = "unlock-recipe", recipe = "ei-metalworks-3"}
)
table.insert(
    data.raw["technology"]["ei-neo-assembler"].effects,
    {type = "unlock-recipe", recipe = "ei-metalworks-4"}
)

-- add the new recipe category to
local recipes_to_add = {
    ["iron-plate"] = "none",
    ["iron-gear-wheel"] = "none",
    ["iron-stick"] = "none",
    ["barrel"] = "none",
    ["copper-plate"] = "none",
    ["ei-gold-ingot"] = "ei-deep-mining",
    ["ei-lead-ingot"] = "ei-deep-mining",
    ["ei-neodym-ingot"] = "ei-neodym-refining",
    ["ei-iron-mechanical-parts"] = "none",
    ["ei-copper-mechanical-parts"] = "none",
    ["ei-steel-mechanical-parts"] = "steel-processing",
    ["copper-cable"] = "electronics",
}

for recipe_name, tech in pairs(recipes_to_add) do
  local recipe = data.raw["recipe"][recipe_name]
  if recipe then 
    -- make a copy of the recipe and change the category
    local new_recipe = util.table.deepcopy(recipe)

    if tech ~= "none" then
      ei_lib.add_unlock_recipe(tech,recipe_name)
    end

    new_recipe.name = new_recipe.name.."-metalworks"
    new_recipe.category = "ei-metalworks"
    new_recipe.hide_from_player_crafting = true

    if tech ~= "none" then
      -- add the new recipe to the tech
      table.insert(
        data.raw["technology"][tech].effects,
        {type = "unlock-recipe", recipe = new_recipe.name}
      )
    end

    if tech == "none" then new_recipe.enabled = true end

    -- add the new recipe to the data
    data:extend({new_recipe})
  end
end

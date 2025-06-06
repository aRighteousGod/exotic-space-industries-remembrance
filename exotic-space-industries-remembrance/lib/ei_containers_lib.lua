local ei_containers_lib = {}

--====================================================================================================
--BASE PROTOTYPES
--====================================================================================================

local mod_entity_base = {
    name = "ei-1x1-container",
    type = "container",
    flags = {"placeable-neutral", "player-creation"},
    icon = ei_containers_item_path.."1x1-container.png",
    icon_size = 64,
    selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
    collision_box = {{-0.35, -0.35}, {0.35, 0.35}},
    picture = {
        layers = {
            {
                filename = ei_containers_entity_path.."1x1-container.png",
                priority = "extra-high",
                width = 256*2,
                height = 256*2,
                scale = 0.13,
            },
            {
                filename = ei_containers_entity_path.."1x1-container_shadow.png",
                priority = "extra-high",
                width = 256*2,
                height = 256*2,
                scale = 0.13,
                draw_as_shadow = true,
            }
        }
    },
    minable = {
        mining_time = 1,
        result = "ei-1x1-container"
    },
    inventory_size = 48,
    circuit_connector_sprites = data.raw["container"]["steel-chest"].circuit_connector_sprites,
    circuit_wire_connection_point = data.raw["container"]["steel-chest"].circuit_wire_connection_point,
    circuit_wire_max_distance = data.raw["container"]["steel-chest"].circuit_wire_max_distance,
    -- inventory_type = "with_filters_and_bar",
    scale_info_icons = true,
    fast_replaceable_group = "container",
    max_health = 350,
}

local entity_base = table.deepcopy(data.raw["logistic-container"]["buffer-chest"])
entity_base['picture'] = mod_entity_base['picture']
entity_base['animation'] = mod_entity_base['picture']
entity_base['name'] = mod_entity_base['name']
entity_base['minable'] = mod_entity_base['minable']
entity_base['inventory_size'] = mod_entity_base['inventory_size']

local item_base = {
    name = "ei-1x1-container",
    type = "item",
    icon = ei_containers_item_path.."1x1-container.png",
    icon_size = 64,
    subgroup = "energy",
    order = "f[nuclear-energy]-b[basic-heat-pipe]",
    place_result = "ei-1x1-container",
    stack_size = 50
}

local recipe_base = {
    name = "ei-1x1-container",
    type = "recipe",
    category = "crafting",
    energy_required = 1,
    ingredients =
    {
      {type="item", name="steel-plate", amount=1},
    },
    results = {{type="item", name="ei-1x1-container", amount=1}},
    enabled = false,
    always_show_made_in = true,
    main_product = "ei-1x1-container",
}

local order_dict = {
    ["none"] = "a",
    ["filter"] = "b",
    ["blue"] = "e",
    ["red"] = "c",
    ["yellow"] = "d",
    ["green"] = "f",
    ["pink"] = "g",
}


--====================================================================================================
--UTIL FUNCTIONS
--====================================================================================================

function ei_containers_lib.switch_recipe(old_recipe, new_recipes)
    -- loop over all techs and look into their effects
    -- if the effect is a recipe unlock, check if it is the old recipe
    -- if it is, replace it with the new recipe

    for _, tech in pairs(data.raw.technology) do
        if tech.effects then
            for _, effect in pairs(tech.effects) do
                if effect.type == "unlock-recipe" and effect.recipe == old_recipe then
                    effect.recipe = new_recipes
                end
            end
        end
    end
end


function ei_containers_lib.swap_item_in_recipe(item, new_item)
    -- loop over all recipes and look into their ingredients
    -- if the ingredient is the item, replace it with the new item

    for _, recipe in pairs(data.raw.recipe) do
        -- account normal and expensive mode aswell
        for _, difficulty in pairs({recipe.expensive or nil, recipe.normal or nil, recipe}) do
            if difficulty.ingredients then
                for _, ingredient in pairs(difficulty.ingredients) do
                    if ingredient[1] == item then
                        ingredient[1] = new_item
                    end
                end
            end
        end
    end

end


function ei_containers_lib.add_bigger_containers()
    -- loop over all techs and look into their effects
    -- if the effect is a recipe unlock, check if it unlocks a 1x1_container
    -- if so also add unlock for the 2x2 and 6x6 container

    local done = {}

    for i, tech in pairs(data.raw.technology) do
        if tech.effects then
            for j, effect in pairs(tech.effects) do
                if effect.type == "unlock-recipe" then
                    -- log
                    -- log("effect: "..effect.recipe)

                    start, stop = string.find(effect.recipe, "ei-1x1-")

                    if start and stop then
                        -- log 
                        log("Adding bigger container to tech: "..tech.name)

                        -- swap ei_1x1- with ei_2x2-
                        local new_recipe_2x2 =  "ei-2x2"..string.sub(effect.recipe, 7)
                        local new_recipe_6x6 =  "ei-6x6"..string.sub(effect.recipe, 7)

                        -- dont do stuff multiple times
                        if not done[new_recipe_2x2] then
                            table.insert(data.raw.technology[i].effects, {type = "unlock-recipe", recipe = new_recipe_2x2})
                            table.insert(data.raw.technology[i].effects, {type = "unlock-recipe", recipe = new_recipe_6x6})

                            done[new_recipe_2x2] = true
                        end
                    end
                end
            end
        end
    end

end


function ei_containers_lib.make_all(size, typus, slots, time, animation, ingredients)
    -- build item, recipe, entity
    ei_containers_lib.make_recipe(size, typus, ingredients, time)
    ei_containers_lib.make_item(size, typus)
    ei_containers_lib.make_container(size, slots, typus, animation)
end

function ei_containers_lib.make_recipe(size, typus, ingredients, time)
    local recipe = table.deepcopy(recipe_base)

    if typus then
        typename = "-"..typus
    else
        typename = ""
    end

    name = size.."x"..size.."-container"
    fullname = "ei-"..name..typename

    recipe.name = fullname

    recipe.ingredients = ingredients
    recipe.energy_required = time

    recipe.results = {{type="item", name=fullname, amount=1}}
    recipe.main_product = fullname
    
    data:extend({recipe})
end


function ei_containers_lib.make_item(size, typus)
    local item = table.deepcopy(item_base)

    if typus then
        typename = "-"..typus
    else
        typename = ""
    end

    name = size.."x"..size.."-container"
    fullname = "ei-"..name..typename

    item.name = fullname
    item.place_result = fullname

    item.icon = ei_containers_item_path..name..typename..".png"

    item.subgroup = "ei-containers-"..size.."x"..size
    
    if not typus then
        typus = "none"
    end
    item.order = order_dict[typus]

    data:extend({item})
end


function ei_containers_lib.make_container(size, slots, typus, animation)
    -- size can be 1 for 1x1, 2 for 2x2, 3 for 3x3, etc.
    -- type can be blue, red, pink, filter, green, yellow

    local container = table.deepcopy(entity_base)

    if typus then
        typename = "-"..typus
    else
        typename = ""
    end
    
    -- naming
    name = size.."x"..size.."-container"
    fullname = "ei-"..name..typename

    container.name = fullname
    container.icon = ei_containers_item_path..name..typename..".png"

    image_size = 512
    adjust = 1

    if size > 2 then
        image_size = 1024
        adjust = 0.5
    end

    -- size
    container.selection_box = {{-size/2, -size/2}, {size/2, size/2}}
    container.collision_box = {{-size/2+0.15, -size/2+0.15}, {size/2-0.15, size/2-0.15}}

    -- picture
    container.picture.layers[1].filename = ei_containers_entity_path..name..typename..".png"
    container.picture.layers[1].width = image_size
    container.picture.layers[1].height = image_size

    container.picture.layers[2].filename = ei_containers_entity_path..name.."_shadow.png"
    container.picture.layers[2].width = image_size
    container.picture.layers[2].height = image_size

    container.picture.layers[1].scale = 0.13*size*adjust
    container.picture.layers[2].scale = 0.13*size*adjust

    -- inventory
    container.minable.result = fullname
    container.inventory_size = slots
    -- next_upgrade
    container.next_upgrade = nil 
    -- animation
    if animation then
        container.animation = {
            layers = {
                {
                    filename = ei_containers_entity_path..name..typename..".png",
                    priority = "extra-high",
                    width = image_size,
                    height = image_size,
                    scale = 0.13*size*adjust,
                    frame_count = 1,
                    line_length = 1,
                    animation_speed = 1,
                    repeat_count = 5,
                },
                {
                    filename = ei_containers_entity_path..name.."_beam.png",
                    priority = "extra-high",
                    width = image_size,
                    height = image_size,
                    scale = 0.13*size*adjust,
                    frame_count = 5,
                    line_length = 5,
                    animation_speed = 1,
                    run_mode = "backward",
                },
                {
                    filename = ei_containers_entity_path..name.."_shadow.png",
                    priority = "extra-high",
                    width = image_size,
                    height = image_size,
                    scale = 0.13*size*adjust,
                    draw_as_shadow = true,
                    frame_count = 1,
                    line_length = 1,
                    animation_speed = 1,
                    repeat_count = 5,
                }
            }
        }
    end

    -- for different types of containers
    if typus then
        if typus == "filter" then
            container.inventory_type = "with_filters_and_bar"
            -- also only 18 slots
            -- container.inventory_size = 18
        end
        -- TODO add animations

        -- different logistic versions
        if typus == "blue" then
            container.type = "logistic-container"
            container.logistic_mode = "requester"
            container.max_logistic_slots = 1000
        end

        if typus == "yellow" then
            container.type = "logistic-container"
            container.logistic_mode = "storage"
            container.max_logistic_slots = 1
        end

        if typus == "red" then
            container.type = "logistic-container"
            container.logistic_mode = "passive-provider"
            container.max_logistic_slots = 0
        end

        if typus == "green" then
            container.type = "logistic-container"
            container.logistic_mode = "buffer"
            container.max_logistic_slots = 1000
        end

        if typus == "pink" then
            container.type = "logistic-container"
            container.logistic_mode = "active-provider"
            container.max_logistic_slots = 0
        end
    end

    data:extend({container})
end



return ei_containers_lib



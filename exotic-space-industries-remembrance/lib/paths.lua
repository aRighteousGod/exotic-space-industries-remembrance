local ei_lib = require("lib/lib")

-- stores commonly used paths esp. for graphics

--====================================================================================================
--PATHS
--====================================================================================================

-- modprefix = "esi-"
modprefix = "ei-"
ei_graphics_base_path = "__base__/graphics/icons/"

ei_path = "__exotic-space-industries-remembrance__/"
ei_soundtrack_path_1 = "__exotic-space-industries-remembrance-soundtrack-1__/sounds/ambient/"
ei_soundtrack_path_2 = "__exotic-space-industries-remembrance-soundtrack-2__/sounds/ambient/"
ei_graphics_path = "__exotic-space-industries-remembrance-graphics-1__/"
ei_graphics_2_path = "__exotic-space-industries-remembrance-graphics-2__/"
ei_graphics_3_path = "__exotic-space-industries-remembrance-graphics-3__/"

ei_graphics_entity_path = ei_graphics_path.."graphics/entities/"
ei_graphics_item_path = ei_graphics_path.."graphics/items/"
ei_graphics_icon_path = ei_graphics_path.."graphics/icons/"
ei_graphics_tech_path = ei_graphics_path.."graphics/techs/"
ei_graphics_fluid_path = ei_graphics_path.."graphics/fluids/"
ei_graphics_resources_path = ei_graphics_path.."graphics/resources/"
ei_graphics_other_path = ei_graphics_path.."graphics/other/"
ei_graphics_kirazy_path = ei_graphics_other_path.."kirazy-mining-drill/"
ei_graphics_semi_kirazy_path = ei_graphics_other_path.."kirazy-semi-classic-mining-drill/"
ei_graphics_V453000_path = ei_graphics_other_path.."V453000-entities/"
ei_graphics_pipe_path = ei_graphics_path.."graphics/pipe-covers/"
ei_graphics_insulated_path = ei_graphics_path.."graphics/insulated-pipes/"
ei_graphics_data_pipe_path = ei_graphics_path.."graphics/data-pipes/"
ei_graphics_train_path = ei_graphics_path.."graphics/yuoki-trains/"
ei_graphics_heat_path = ei_graphics_path.."graphics/heat-pipes/"
ei_graphics_inserter_path = ei_graphics_path.."graphics/inserters/"
ei_graphics_belt_path = ei_graphics_path.."graphics/belts/"
ei_graphics_destination_path = ei_graphics_path.."graphics/destinations/"

ei_graphics_terrain_path = ei_graphics_2_path.."graphics/terrain/"
ei_graphics_tree_path = ei_graphics_2_path.."graphics/trees/"
ei_graphics_entity_2_path = ei_graphics_2_path.."graphics/entities/"
ei_graphics_item_2_path = ei_graphics_2_path.."graphics/items/"
ei_graphics_icon_2_path = ei_graphics_2_path.."graphics/icons/"
ei_graphics_tech_2_path = ei_graphics_2_path.."graphics/techs/"

ei_graphics_glow_path = ei_path.."graphics/glow/"

ei_loaders_item_path = ei_graphics_item_2_path
ei_loaders_entity_path = ei_graphics_entity_2_path

ei_containers_item_path = ei_graphics_item_2_path
ei_containers_entity_path = ei_graphics_entity_2_path

ei_tanks_entity_path = ei_graphics_entity_2_path
ei_tanks_item_path = ei_graphics_item_2_path
ei_tanks_pipe_path = ei_graphics_2_path.."graphics/pipe-covers/"
ei_tanks_tech_path = ei_graphics_tech_2_path

ei_robots_item_path = ei_graphics_item_2_path
ei_robots_tech_path = ei_graphics_tech_2_path
ei_robots_entity_path = ei_graphics_entity_2_path

ei_fueler_graphics_path = ei_graphics_2_path.."graphics/fueler/"

ei_trains_path = ei_graphics_2_path
ei_trains_sounds_path = ei_trains_path.."sounds/em_trains/"
ei_trains_entity_path = ei_trains_path.."graphics/entities/"
ei_trains_item_path = ei_trains_path.."graphics/items/"
ei_trains_tech_path = ei_trains_path.."graphics/techs/"
--[[
if ei_lib.config("slag") then
    ei_slag_path = ei_path.."graphics/slag/"
end

if ei_lib.config("ash") then
    ei_ash_path = ei_path.."graphics/ash/"
end
]]
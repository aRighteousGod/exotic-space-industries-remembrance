--====================================================================================================
--CHECK FOR MOD
--====================================================================================================

if not mods["Assembler-Reskin"] then
    return
end

--[[
ei_lib.add_item_level("assembling-machine-1", 1)
ei_lib.add_item_level("assembling-machine-2", 2)
ei_lib.add_item_level("assembling-machine-3", 3)
]]
--item graphics?
--assembler_reskin
--3 has the fanciest top animation

local neo_tint_base = {r = 0.6, g = 0.3, b = 1, a = 1.0} --machinery/top/edges
local neo_tint = {r = 1.0, g = 0.05, b = 0.85, a = 1.0} --sides
local exotic_tint_base = {r = 0.4, g = 0.4, b = 0.8, a = 1.0}
local exotic_tint = {r = 0.1, g = 0.2, b = 1.0, a = 1.0}

local a_r = ei_lib.raw["assembling-machine"]["assembling-machine-3"] 
local a_r_corpse = ei_lib.raw.corpse["sa-assembler-3-remnants"]
if a_r_corpse then
    --neo assembler corpse
    local n_corpse = table.deepcopy(a_r_corpse)
    n_corpse.name = "ei-neo-assembler-corpse"
    --tint for base
    n_corpse.animation[1].layers[1].tint = neo_tint_base
    --tint for mask
    n_corpse.animation[1].layers[2].tint = neo_tint
    --exotic assembler corpse
    local e_corpse = table.deepcopy(a_r_corpse)
    e_corpse.name = "ei-exotic-assembler-corpse"
    --tint for base
    e_corpse.animation[1].layers[1].tint = exotic_tint_base
    --tint for mask
    e_corpse.animation[1].layers[2].tint = exotic_tint
    data:extend({
        n_corpse,
        e_corpse
    })
end

--neo assembler
local n_a = ei_lib.raw["assembling-machine"]["ei-neo-assembler"]
if n_a and a_r then

    n_a.icon = nil
    n_a.icons = table.deepcopy(a_r.icons)
    n_a.icon_size = table.deepcopy(a_r.icon_size)
    n_a.fluid_boxes = table.deepcopy(a_r.fluid_boxes)
    n_a.graphics_set = table.deepcopy(a_r.graphics_set)
    n_a.graphics_set.animation.layers[1].tint = neo_tint_base
    n_a.graphics_set.animation.layers[2].tint = neo_tint
    n_a.graphics_set.animation.layers[2].draw_as_glow = true
    n_a.fluid_boxes[1].pipe_picture.north.layers[2].tint = neo_tint
    n_a.fluid_boxes[1].pipe_picture.east.layers[2].tint = neo_tint
    n_a.fluid_boxes[1].pipe_picture.south.layers[3].tint = neo_tint
    n_a.fluid_boxes[1].pipe_picture.west.layers[2].tint = neo_tint
    n_a.fluid_boxes[2].pipe_picture.north.layers[2].tint = neo_tint
    n_a.fluid_boxes[2].pipe_picture.east.layers[2].tint = neo_tint
    n_a.fluid_boxes[2].pipe_picture.south.layers[3].tint = neo_tint
    n_a.fluid_boxes[2].pipe_picture.west.layers[2].tint = neo_tint
    n_a.corpse = "ei-neo-assembler-corpse"
    n_a.circuit_connector = table.deepcopy(a_r.circuit_connector)
    n_a.bottleneck_ignore = true
end
local n_a_item = ei_lib.raw.item["ei-neo-assembler"]
--ei_lib.add_item_level("ei-neo-assembler", 4)
local n_a_tech = ei_lib.raw.technology["ei-neo-assembler"]

--exotic assembler
local e_a = ei_lib.raw["assembling-machine"]["ei-exotic-assembler"]
if e_a and a_r then
    e_a.icon = nil
    e_a.icons = table.deepcopy(a_r.icons)
    e_a.icon_size = table.deepcopy(a_r.icon_size)
    e_a.fluid_boxes = table.deepcopy(a_r.fluid_boxes)
    e_a.graphics_set = table.deepcopy(a_r.graphics_set)
    e_a.graphics_set.animation.layers[1].tint = exotic_tint_base
    e_a.graphics_set.animation.layers[2].tint = exotic_tint
    e_a.graphics_set.animation.layers[2].draw_as_glow = true
    e_a.fluid_boxes[1].pipe_picture.north.layers[2].tint = exotic_tint
    e_a.fluid_boxes[1].pipe_picture.east.layers[2].tint = exotic_tint
    e_a.fluid_boxes[1].pipe_picture.south.layers[3].tint = exotic_tint
    e_a.fluid_boxes[1].pipe_picture.west.layers[2].tint = exotic_tint
    e_a.fluid_boxes[2].pipe_picture.north.layers[2].tint = exotic_tint
    e_a.fluid_boxes[2].pipe_picture.east.layers[2].tint = exotic_tint
    e_a.fluid_boxes[2].pipe_picture.south.layers[3].tint = exotic_tint
    e_a.fluid_boxes[2].pipe_picture.west.layers[2].tint = exotic_tint
    e_a.corpse = "ei-exotic-assembler-corpse"
    e_a.circuit_connector = table.deepcopy(a_r.circuit_connector)
    e_a.bottleneck_ignore = true
end
local e_a_item = ei_lib.raw.item["ei-exotic-assembler"]
local e_a_tech = ei_lib.raw.technology["ei-exotic-assembler"]
local ei_lib = require("lib/lib")

ei_lib.raw.technology["space-science-pack"] = {
    localised_name = {"technology-name.ei-space-science-pack"},
    localised_description = {"technology-description.ei-space-science-pack"},
    icon = ei_graphics_3_path.."graphics/items/cosmic-criticality-pack.png",
    icon_size = 512,
    icon_mipmaps = 5,
}

--Increase space science pack difficulty, make alt recipes with different fuels
ei_lib.raw.tool["space-science-pack"] = {
    icon = ei_graphics_3_path.."graphics/items/cosmic-criticality-pack.png",
    icon_size = 512,
    icon_mipmaps = 5,
    localised_name = {"item-name.ei-space-science-pack"},
    localised_description = {"item-description.ei-space-science-pack"}
}
ei_lib.raw.recipe["space-science-pack"] = {
    category = "centrifuging",
    icon = ei_graphics_3_path.."graphics/items/cosmic-criticality-pack.png",
    icon_size = 512,
    icon_mipmaps = 5,
}
ei_lib.recipe_swap("space-science-pack","iron-plate","ei-steel-beam")
ei_lib.recipe_add("space-science-pack","ei-liquid-nitrogen",50,true)
ei_lib.recipe_add("space-science-pack","ei-liquid-oxygen",50,true)
local ssp = table.deepcopy(ei_lib.raw.recipe["space-science-pack"])

local two_three_nine = table.deepcopy(ssp)
--239
table.insert(two_three_nine.ingredients,{type="item",name="ei-plutonium-239-fuel",amount=1})
two_three_nine.name = "ei-space-science-pack-239"

--original science pack is 235
ei_lib.recipe_add("space-science-pack","ei-uranium-235-fuel",2)
ei_lib.raw.recipe["space-science-pack"].localised_name = {"recipe-name.ei-space-science-pack-235"}

--233
local two_three_three = table.deepcopy(ssp)
two_three_three.name = "ei-space-science-pack-233"
table.insert(two_three_three.ingredients,{type="item",name="ei-uranium-233-fuel",amount=3})

--232
local two_three_two = table.deepcopy(ssp)
two_three_two.name = "ei-space-science-pack-232"
table.insert(two_three_two.ingredients,{type="item",name="ei-thorium-232-fuel",amount=4})
--test fuel
local test_fuel = table.deepcopy(ssp)
test_fuel.name = "ei-space-science-pack-testfuel"
test_fuel.results[1].amount = 1
table.insert(test_fuel.ingredients,{type="item",name="ei-uranium-test-fuel",amount=16})

data:extend({
    two_three_nine,
    two_three_three,
    two_three_two,
    test_fuel
})
ei_lib.add_unlock_recipe("space-science-pack","ei-space-science-pack-239")
ei_lib.add_unlock_recipe("space-science-pack","ei-space-science-pack-233")
ei_lib.add_unlock_recipe("space-science-pack","ei-space-science-pack-232")
ei_lib.add_unlock_recipe("space-science-pack","ei-space-science-pack-testfuel")

--double centrifuge fluidboxes
local cent = ei_lib.raw["assembling-machine"].centrifuge
if cent then
    local i2 = table.deepcopy(cent.fluid_boxes[1])
    local o2 = table.deepcopy(cent.fluid_boxes[2])
    if i2 then
        i2.pipe_connections = {{ flow_direction="input", direction = defines.direction.north, position = {0, -1} }}
        table.insert(cent.fluid_boxes,i2)
    end
    if o2 then
        o2.pipe_connections = {{ flow_direction="output", direction = defines.direction.south, position = {0, 1} }}
        table.insert(cent.fluid_boxes,o2)
    end
end

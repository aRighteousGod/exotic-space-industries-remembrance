-- Private verification of the shared policy in Factorio's data-stage Lua.
assert(mods.quality,"Core acceptance requires Quality")
assert(ei_lib.recipe_fluidbox_multiplier()==nil)
assert(ei_lib.recipe_fluidbox_multiplier(nil,true)==nil)
assert(ei_lib.recipe_fluidbox_multiplier(10)==10)
local quality=mods.quality
mods.quality=nil
local legacy_input=ei_lib.recipe_fluidbox_multiplier()
local legacy_output=ei_lib.recipe_fluidbox_multiplier(nil,true)
local legacy_explicit=ei_lib.recipe_fluidbox_multiplier(10)
mods.quality=quality
assert(legacy_input==1 and legacy_output==2 and legacy_explicit==9)
data:extend{{type="recipe-category",name="qc-native-buffer"}}
for _,volume in ipairs{1,100} do
    for index,spec in ipairs{
        {name="native-default",input=ei_lib.recipe_fluidbox_multiplier(),output=ei_lib.recipe_fluidbox_multiplier(nil,true)},
        {name="legacy-default",input=legacy_input,output=legacy_output},
        {name="native-explicit",input=ei_lib.recipe_fluidbox_multiplier(10),output=ei_lib.recipe_fluidbox_multiplier(nil,true)},
        {name="legacy-explicit",input=legacy_explicit,output=legacy_output},
    } do
        local name="qc-buffer-"..spec.name.."-"..volume
        local recipe={type="recipe",name=name,enabled=false,hidden=true,categories={"qc-native-buffer"},
            ingredients={{type="item",name="iron-plate",amount=1},
                {type="fluid",name="water",amount=60,fluidbox_multiplier=spec.input}},
            results={{type="fluid",name="water",amount=60,fluidbox_multiplier=spec.output}}}
        local machine=table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
        machine.name=name;machine.fixed_recipe=name;machine.crafting_categories={"qc-native-buffer"}
        machine.fluid_boxes={
            {production_type="input",volume=volume,filter="water",pipe_connections={{flow_direction="input",direction=defines.direction.north,position={0,-1}}}},
            {production_type="output",volume=volume,filter="water",pipe_connections={{flow_direction="output",direction=defines.direction.south,position={0,1}}}},
        }
        data:extend{recipe,machine}
    end
end

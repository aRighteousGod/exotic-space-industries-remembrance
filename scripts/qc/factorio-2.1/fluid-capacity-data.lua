-- Private paired-engine probes. No recipe can run without its unfed iron item.
local modern = mods.base:match("^2%.1%.") ~= nil
data:extend{{type="recipe-category",name="qc-fluid-capacity"}}
local index = 0
for _, volume in ipairs{1,30,100} do
    for _, amount in ipairs{1,15,30,100} do
        for multiplier=1,3 do
            index=index+1
            local name="qc-fluid-capacity-"..index
            local recipe={type="recipe",name=name,enabled=false,hidden=true,energy_required=1,
                ingredients={{type="fluid",name="water",amount=amount,fluidbox_multiplier=multiplier},
                    {type="item",name="iron-plate",amount=1}},
                results={{type="fluid",name="water",amount=amount,fluidbox_multiplier=2}}}
            if modern then recipe.categories={"qc-fluid-capacity"} else recipe.category="qc-fluid-capacity" end
            local machine=table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
            machine.name=name
            machine.fixed_recipe=name
            machine.crafting_categories={"qc-fluid-capacity"}
            machine.fluid_boxes={
                {production_type="input",volume=volume,filter="water",
                    pipe_connections={{flow_direction="input",direction=defines.direction.north,position={0,-1}}}},
                {production_type="output",volume=volume,filter="water",
                    pipe_connections={{flow_direction="output",direction=defines.direction.south,position={0,1}}}},
            }
            data:extend{recipe,machine}
        end
    end
end

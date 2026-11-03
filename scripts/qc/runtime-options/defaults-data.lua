-- Private native scanner fixture; no production prototypes are added.
local crafter=table.deepcopy(data.raw["assembling-machine"]["chemical-plant"])
crafter.name="esir-options-qc-crafter"
crafter.fluid_boxes_off_when_no_fluid_recipe=true
data:extend{crafter,{type="recipe",name="esir-options-qc-water",categories={"chemistry"},enabled=true,
    ingredients={{type="fluid",name="water",amount=1}},results={{type="item",name="stone",amount=1}},energy_required=10}}

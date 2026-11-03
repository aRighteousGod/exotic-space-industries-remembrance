if not mods["exotic-space-industries-remembrance"] then require("prototypes/factory-passage") end
if mods["squeak-through-2"] then return end
-- Different connection categories provide genuinely separate parallel pipe runs.
for _,suffix in ipairs{"a","b"} do
    local pipe=table.deepcopy(data.raw.pipe.pipe)
    pipe.name="ei-passage-qc-pipe-"..suffix
    pipe.minable={mining_time=0.1,result="pipe"}
    for _,port in pairs(pipe.fluid_box.pipe_connections) do port.connection_category="ei-passage-qc-"..suffix end
    data:extend{pipe}
end
local masks=require("__core__/lualib/collision-mask-util")
local heat=table.deepcopy(data.raw["heat-pipe"]["heat-pipe"])
heat.name="ei-passage-qc-heat"
heat.collision_mask=table.deepcopy(masks.get_mask(data.raw.pipe.pipe))
heat.collision_box={{-0.4,-0.4},{0.4,0.4}}
data:extend{heat}
local opt=table.deepcopy(data.raw.pipe.pipe)
opt.name="ei-passage-qc-opt-out";opt.squeak_behaviour=false
data:extend{opt}
local off=table.deepcopy(data.raw.pipe.pipe)
off.name="ei-passage-qc-off-grid"
off.flags=off.flags or {};off.flags[#off.flags+1]="placeable-off-grid"
data:extend{off}
local unsupported=table.deepcopy(data.raw.pipe.pipe)
unsupported.name="ei-passage-qc-unsupported"
unsupported.fluid_box.pipe_connections[1].position={3,0}
unsupported.collision_box={{-3.4,-0.4},{3.4,0.4}};unsupported.tile_width=1
for _,port in pairs(unsupported.fluid_box.pipe_connections) do port.connection_category="qc-unsupported" end
data:extend{unsupported}
local boundary=table.deepcopy(data.raw.container["steel-chest"])
boundary.name="ei-passage-qc-grid-boundary";boundary.collision_box={{-1.0001,-0.4},{1.0001,0.4}}
data:extend{boundary}
local eight=table.deepcopy(data.raw["ammo-turret"]["gun-turret"])
eight.name="ei-passage-qc-eight-way";eight.flags=eight.flags or {}
eight.flags[#eight.flags+1]="building-direction-8-way"
eight.collision_box={{-0.95,-0.95},{0.95,0.95}};eight.next_upgrade=nil
if eight.circuit_connector then
    local connector=table.deepcopy(eight.circuit_connector[1]);eight.circuit_connector={}
    for index=1,8 do eight.circuit_connector[index]=table.deepcopy(connector) end
end
data:extend{eight}
if data.raw.thruster and data.raw.thruster.thruster then
    local walkable=table.deepcopy(data.raw.thruster.thruster)
    walkable.name="ei-passage-qc-walkable-receiver";walkable.collision_mask={layers={}}
    data:extend{walkable}
end
local hidden=table.deepcopy(data.raw["assembling-machine"]["assembling-machine-2"])
hidden.name="ei-passage-qc-hidden-operating-body";hidden.hidden=true
hidden.next_upgrade=nil
hidden.collision_box={{-1.4,-1.4},{1.4,1.4}}
data:extend{hidden}
local upgrade=table.deepcopy(hidden)
upgrade.name="ei-passage-qc-upgrade";upgrade.next_upgrade="ei-passage-qc-upgrade-opt-out"
local upgrade_opt=table.deepcopy(hidden)
upgrade_opt.name="ei-passage-qc-upgrade-opt-out";upgrade_opt.squeak_behaviour=false
upgrade_opt.placeable_by={item="assembling-machine-2",count=1}
data:extend{upgrade,upgrade_opt}
local crafter=table.deepcopy(data.raw["assembling-machine"]["chemical-plant"])
crafter.name="ei-passage-qc-crafter";crafter.fluid_boxes_off_when_no_fluid_recipe=true
crafter.localised_name={"","Passage test assembler"}
data:extend{crafter}
data:extend{{type="recipe",name="ei-passage-qc-fluid-crafting",categories={"crafting-with-fluid"},enabled=true,
    ingredients={{type="fluid",name="water",amount=1}},results={{type="item",name="stone",amount=1}},energy_required=10}}
data:extend{{type="recipe",name="ei-passage-qc-fluid-recipe",localised_name={"","Passage fluid test"},categories={"chemistry"},enabled=true,
    ingredients={{type="fluid",name="water",amount=1}},results={{type="item",name="stone",amount=1}},energy_required=10}}

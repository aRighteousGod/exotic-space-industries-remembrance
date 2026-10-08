local target = table.deepcopy(data.raw.unit["behemoth-biter"])
target.name = "anisetron-qc-target"
target.max_health = 1000000
target.resistances = {}
target.healing_per_tick = 0
target.movement_speed = 0
target.vision_distance = 0
target.attack_parameters.range = 0
target.collision_box = {{-0.2,-0.2},{0.2,0.2}}
target.dying_explosion = nil
target.corpse = nil
local source = table.deepcopy(data.raw["electric-energy-interface"]["electric-energy-interface"])
source.name = "anisetron-qc-source"
source.energy_production = "1GW"
source.energy_usage = "0W"
source.energy_source = {type="electric",usage_priority="primary-output",buffer_capacity="1GJ",output_flow_limit="1GW"}
data:extend{target, source}
-- Active native walker, deliberately durable so holding/arrival can be observed.
local walker=table.deepcopy(data.raw.unit["behemoth-biter"])
walker.name="anisetron-qc-tracking-target"
walker.max_health=1000000;walker.resistances={};walker.healing_per_tick=0
walker.movement_speed=.06
data:extend{walker}
-- Fixture-only speed candidates; no production prototype uses these IDs.
for index,speed in ipairs{.02,.04,.06,.1,.5} do
    local leg=table.deepcopy(data.raw["spider-leg"]["ei-anisetron-leg"])
    leg.name="anisetron-qc-speed-leg-"..index
    leg.initial_movement_speed=speed;leg.movement_acceleration=speed
    local vehicle=table.deepcopy(data.raw["spider-vehicle"]["ei-anisetron"])
    vehicle.name="ei-anisetron-speed-"..index
    for _,anchor in ipairs(vehicle.spider_engine.legs) do anchor.leg=leg.name end
    data:extend{leg,vehicle}
end

-- A hostile non-military bystander sits on the manual beam line. It must never
-- receive scripted packets or damage from the action-free primary beams.
local bystander=table.deepcopy(assert(data.raw["simple-entity"]["big-rock"]))
bystander.name="anisetron-qc-bystander"
bystander.max_health=1000000;bystander.resistances={};bystander.minable=nil
bystander.collision_box={{-.2,-.2},{.2,.2}}
data:extend{bystander}

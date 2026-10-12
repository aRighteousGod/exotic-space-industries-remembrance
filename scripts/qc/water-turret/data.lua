local target=table.deepcopy(data.raw.unit["behemoth-biter"])
target.name="esir-water-qc-target"
target.max_health=1000000
target.resistances={}
target.healing_per_tick=0
target.movement_speed=0
target.vision_distance=0
target.attack_parameters.range=0
target.collision_box={{-0.2,-0.2},{0.2,0.2}}
target.dying_explosion=nil
target.corpse=nil
local moving=table.deepcopy(target)
moving.name="esir-water-qc-moving"
moving.movement_speed=0.1
data:extend{target,moving}
local pole=table.deepcopy(data.raw["electric-pole"].substation)
pole.name="esir-water-qc-pole"
pole.maximum_wire_distance=64
pole.supply_area_distance=64
pole.minable=nil
local source=table.deepcopy(data.raw["electric-energy-interface"]["electric-energy-interface"])
source.name="esir-water-qc-source"
source.collision_mask={layers={}}
source.energy_production="1GW"
source.energy_usage="0W"
source.energy_source={type="electric",usage_priority="primary-output",buffer_capacity="1GJ",output_flow_limit="1GW"}
data:extend{pole,source}
-- An upstream effect must survive the production notification append.
if require("test-config").creation then
    data.raw.fire["fire-flame"].created_effect={type="direct",action_delivery={type="instant",
        target_effects={{type="script",effect_id="water-qc-prior-created"}}}}
    data:extend{{type="projectile",name="water-qc-refuel",flags={"not-on-map"},acceleration=0,
        action={type="direct",action_delivery={type="instant",target_effects={{type="create-fire",entity_name="fire-flame"}}}}}}
end

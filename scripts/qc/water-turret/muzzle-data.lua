local variants={a={0,{0,0},{0,0}},b={2,{0,0},{0,0}},c={0,{0.3,-0.7},{0,0}},d={0,{0,0},{0.25,-0.5}},e={2.5962124,{0,-1.3620957621},{0,0}}}
for key,values in pairs(variants) do for direction=0,7 do
    local id=key.."-"..direction
    local stream=table.deepcopy(data.raw.stream["ei-water-combat-stream"])
    stream.name="esir-water-qc-probe-"..id;stream.action=nil
    stream.initial_action={type="direct",action_delivery={type="instant",target_effects={{type="script",effect_id="water-muzzle-impact-"..id}}}}
    local turret=table.deepcopy(data.raw["fluid-turret"]["ei-water-turret"])
    turret.name="esir-water-qc-muzzle-"..id
    local attack=turret.attack_parameters
    attack.gun_barrel_length=values[1];attack.gun_center_shift=values[2]
    local delivery=attack.ammo_type.action.action_delivery
    delivery.stream=stream.name;delivery.source_offset=values[3]
    delivery.source_effects={{type="script",effect_id="water-muzzle-launch-"..id}}
    data:extend{stream,turret}
end end
local calibration=table.deepcopy(data.raw.stream["esir-water-qc-probe-a-0"])
calibration.name="esir-water-qc-calibration"
calibration.initial_action.action_delivery.target_effects[1].effect_id="water-muzzle-calibration"
data:extend{calibration}

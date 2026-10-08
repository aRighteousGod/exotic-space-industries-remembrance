local target=table.deepcopy(data.raw.unit["behemoth-biter"])
target.name="anisetron-hover-qc-target";target.max_health=10000000;target.resistances={}
target.healing_per_tick=0;target.movement_speed=0;target.vision_distance=0;target.attack_parameters.range=0
data:extend{target}
local lab=table.deepcopy(data.raw.lab.lab)
lab.name="anisetron-hover-qc-lab";lab.energy_source={type="void"}
data:extend{lab}
-- Deliberately recreate the old category ONLY in the staged migration seed.
if require("options").old_category then
 for _,name in ipairs{"laser-weapons-damage-6","laser-weapons-damage-7"} do
  local effects=data.raw.technology[name].effects
  for i=#effects,1,-1 do if effects[i].ammo_category=="ei-anisetron-crystal" then table.remove(effects,i) end end
 end
end

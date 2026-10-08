local target=table.deepcopy(data.raw.unit["behemoth-biter"])
target.name="anisetron-inheritance-target";target.max_health=10000000;target.resistances={}
target.healing_per_tick=0;target.movement_speed=0;target.vision_distance=0;target.attack_parameters.range=0
target.collision_box={{-.1,-.1},{.1,.1}}
data:extend{target}
local large=table.deepcopy(target);large.name="anisetron-inheritance-large-target";large.collision_box={{-8,-8},{8,8}}
data:extend{large}
local structure=table.deepcopy(data.raw["electric-turret"]["laser-turret"])
structure.name="anisetron-inheritance-large-structure";structure.max_health=10000000
structure.collision_box={{-8,-8},{8,8}};structure.resistances={}
data:extend{structure}

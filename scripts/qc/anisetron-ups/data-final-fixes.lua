local target=table.deepcopy(data.raw.unit["small-biter"])
target.name="anisetron-ups-target";target.max_health=1000000000;target.resistances={}
target.corpse=nil;target.dying_explosion=nil;target.healing_per_tick=0;target.movement_speed=0
data:extend{target}

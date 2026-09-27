local target=table.deepcopy(data.raw.unit["behemoth-biter"])
target.name="esir-flame-qc-target"
target.max_health=100000
target.resistances={}
target.healing_per_tick=0
target.movement_speed=0
target.vision_distance=0
target.attack_parameters.range=0
data:extend{target}

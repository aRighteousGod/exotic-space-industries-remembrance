local target=table.deepcopy(data.raw.unit["behemoth-biter"])
target.name="esir-spider-qc-target"
target.max_health=1000000000
target.resistances={}
target.healing_per_tick=0
data:extend({target})

local target = table.deepcopy(data.raw.unit["behemoth-biter"])
target.name = "esir-thrower-qc-target"
-- Timing runs infer activity from health loss without a damage listener. Keep
-- health low enough that small acid hits exceed native float health precision.
target.max_health = require("test-config").mode == "performance" and 1000000 or 100000000
target.resistances = {}
target.healing_per_tick = 0
target.movement_speed = 0
target.vision_distance = 0
target.attack_parameters.range = 0
target.collision_box = {{-1,-1},{1,1}}
target.dying_explosion = nil
target.corpse = nil
data:extend{target}
local moving=table.deepcopy(target)
moving.name="esir-thrower-qc-moving"
moving.movement_speed=0.04
local resistant=table.deepcopy(target)
resistant.name="esir-thrower-qc-resistant"
resistant.resistances={{type="fire",decrease=3,percent=25},{type="acid",decrease=3,percent=25}}
data:extend{moving,resistant}

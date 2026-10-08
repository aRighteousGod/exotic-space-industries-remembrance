local options=require("options")
if options.public_bob then data.raw["spider-vehicle"]["ei-anisetron"].torso_bob_speed=options.public_bob end
if options.public_overlap then data.raw["spider-vehicle"]["ei-anisetron"].spider_engine.walking_group_overlap=options.public_overlap end
if options.public_min_step then data.raw["spider-leg"]["ei-anisetron-leg"].minimal_step_size=options.public_min_step end
if options.fast_half then
 local leg=data.raw["spider-leg"]["ei-anisetron-leg"];leg.initial_movement_speed=1;leg.movement_acceleration=1
 data:extend{{type="sticker",name="anisetron-trial-pace",duration_in_ticks=100000,vehicle_speed_modifier=.5,vehicle_friction_modifier=1}}
end
local target=table.deepcopy(data.raw.unit["small-biter"])
target.name="anisetron-stability-target";target.max_health=1000000000;target.resistances={};target.corpse=nil;target.dying_explosion=nil
target.healing_per_tick=0;target.movement_speed=0
data:extend{target}
for _,p in ipairs(options.profiles or {}) do
 local body=table.deepcopy(data.raw["spider-vehicle"][p.saucer and "ei-gaian-saucer" or "ei-anisetron"])
 body.name="anisetron-stability-"..p.id;body.minable=nil;body.placeable_by=nil;body.guns={}
 local leg=table.deepcopy(data.raw["spider-leg"][p.saucer and "ei-gaian-saucer-leg" or "ei-anisetron-leg"])
 leg.name=body.name.."-leg"
 if p.response then leg.initial_movement_speed=p.response;leg.movement_acceleration=p.response end
 if p.friction then body.friction_force=p.friction end
 if p.bob then body.torso_bob_speed=p.bob end
 if p.selection then leg.base_position_selection_distance=p.selection;leg.movement_based_position_selection_distance=p.selection end
 if p.force then leg.stretch_force_scalar=p.force end
 for _,anchor in ipairs(body.spider_engine.legs) do anchor.leg=leg.name end
 data:extend{body,leg}
end

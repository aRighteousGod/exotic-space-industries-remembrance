-- Isolated instrumentation: keep the canonical turret and resolved stream names.
-- The full production prototypes are snapshotted before adding a source marker.
local turret=data.raw["fluid-turret"]["ei-acidthrower-turret"]
local delivery=turret.attack_parameters.ammo_type.action.action_delivery
local stream=data.raw.stream[delivery.stream]
data:extend{{type="mod-data",name="acid-origin-final-data",data={
    profile=settings.startup["ei-thrower-performance-profile"].value,
    turret=table.deepcopy(turret),stream=table.deepcopy(stream),
    source=table.deepcopy(data.raw.stream["ei-flamethrower-acid-stream"]),
    alias=table.deepcopy(data.raw.stream["ei-thrower-performance-ei-flamethrower-acid-stream"])}}}
assert(not delivery.source_effects,"Review existing source effects before instrumenting")
delivery.source_effects={{type="script",effect_id="acid-origin-source"}}
if require("test-config").origin_variants then
    for _,variant in ipairs(require("origin-variants")) do
        local body=table.deepcopy(turret);body.name="acid-origin-"..variant.name
        body.minable=nil;body.placeable_by=nil;body.next_upgrade=nil
        local jet=table.deepcopy(stream);jet.name=body.name.."-stream"
        body.attack_parameters.ammo_type.action.action_delivery.stream=jet.name
        local animation=jet.spine_animation
        local filename=animation.filename or animation.stripes[1].filename
        animation.filename=nil;animation.line_length=nil;animation.width=variant.width;animation.stripes={}
        for frame=0,15 do
            animation.stripes[frame+1]={filename=filename,width_in_frames=1,height_in_frames=1,
                x=(frame%4)*64+(64-variant.width)/2,y=math.floor(frame/4)*32}
        end
        animation.shift={variant.shift or 0,2.25/32}
        if variant.no_crop then animation.flags={"no-crop"} end
        if variant.launch then
            body.attack_parameters.gun_barrel_length=body.attack_parameters.gun_barrel_length+variant.launch
        end
        data:extend{body,jet}
    end
end
local target=table.deepcopy(data.raw.unit["behemoth-biter"])
target.name="acid-origin-target";target.max_health=100000000;target.resistances={};target.healing_per_tick=0
target.movement_speed=0;target.vision_distance=0;target.attack_parameters.range=0
target.collision_box={{-.03,-.03},{.03,.03}};target.dying_explosion=nil;target.corpse=nil
target.damaged_trigger_effect=nil
data:extend{target}

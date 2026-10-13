local config=require("test-config")
if config.origin_probe then require("origin-probe-data");return end
if config.dispersion_probe then require("dispersion-probe-data");return end
local baseline=config.pressure_baseline and require("baseline/contract")
local factor=config.profile=="original" and 1 or tonumber(config.profile:match("%d+"))
local original=data.raw["fluid-turret"]["ei-acidthrower-turret"]
local stream=data.raw.stream[original.attack_parameters.ammo_type.action.action_delivery.stream]
local source=data.raw.stream["ei-flamethrower-acid-stream"]
local alias=data.raw.stream["ei-thrower-performance-ei-flamethrower-acid-stream"]
assert(stream.particle_horizontal_speed==.85 and stream.particle_vertical_acceleration==.00025)
local refresh_factor=factor>=8 and .5 or 1
assert(stream.particle_spawn_interval==2*factor and original.attack_parameters.cooldown==4*factor*refresh_factor)
assert(original.attack_parameters.fluid_consumption==factor*refresh_factor and original.attack_parameters.lead_target_for_projectile_speed==.85)
assert(stream.particle_spawn_timeout==math.max(16,6*factor))
assert(stream.particle_buffer_size==120 and stream.action[1].radius==3)
assert(stream.initial_action==nil and #stream.action==2)
assert(stream.action[1].action_delivery.target_effects[2].damage.amount==3.3*factor)
assert(stream.action[2].type=="direct" and stream.action[2].action_delivery.target_effects[1].type=="create-explosion")
assert(original.attack_parameters.range==38 and original.attack_parameters.min_range==9)
assert(original.graphics_set.base_visualisation[1].render_layer=="object" and original.gun_animation_secondary_draw_order==4)
assert(source.particle_horizontal_speed==.85 and alias.particle_horizontal_speed==.85)
assert(source.progress_to_create_smoke==.12 and stream.progress_to_create_smoke==.12)
assert(source.smoke_sources[1].frequency==.59 and stream.smoke_sources[1].frequency==.59/factor)
local flecks=data.raw["trivial-smoke"]["ei-acid-pressure-flecks"]
assert(flecks.duration==12 and not flecks.affected_by_wind and flecks.movement_slow_down_factor==0)
assert(flecks.fade_in_duration==8 and flecks.spread_duration==12 and flecks.start_scale==.05 and flecks.end_scale==1)
assert(flecks.animation.blend_mode=="normal" and not flecks.animation.draw_as_glow and not flecks.animation.draw_as_light)
local retired={fire={"ei-acid-flame","ei-fire-flame-small","ei-acid-flame-small","ei-acid-flame-on-tree"},
    ["trivial-smoke"]={"ei-acid-smoke","ei-acid-smoke-without-glow","ei-soft-acid-smoke","ei-acid-smoke-on-adding-fuel"},
    stream={"ei-handheld-flamethrower-acid-stream","ei-tank-flamethrower-acid-stream"}}
for kind,names in pairs(retired) do
    for _,name in ipairs(names) do assert(not data.raw[kind][name],"Retired effect remains: "..name) end
end
assert(data.raw.sticker["ei-poison-sticker"].animation.filename:find("spark.png",1,true))
local sticker=stream.action[1].action_delivery.target_effects[1].sticker
data:extend{{type="mod-data",name="acid-jet-final-data",data={profile=config.profile,
    turret=table.deepcopy(original),source=table.deepcopy(source),resolved=table.deepcopy(stream),
    item=table.deepcopy(data.raw.item["ei-acidthrower-turret"]),
    technology=table.deepcopy(data.raw.technology["ei-acidthrower-turret"]),
    alias=table.deepcopy(alias),sticker=table.deepcopy(data.raw.sticker[sticker]),
    flecks=table.deepcopy(data.raw["trivial-smoke"]["ei-acid-pressure-flecks"]),
    retired=table.deepcopy(retired),poison=table.deepcopy(data.raw.sticker["ei-poison-sticker"])}}}

for _,variant in ipairs{"old","new"} do
    for _,component in ipairs{"direct","sticker","combined","probe"} do
        local turret=table.deepcopy(original)
        turret.name="acid-jet-"..variant.."-"..component
        turret.minable=nil;turret.placeable_by=nil;turret.next_upgrade=nil
        local jet=table.deepcopy(stream);jet.name=turret.name.."-stream"
        if variant=="new" and config.native_refresh_candidate and factor>=8 then
            turret.attack_parameters.cooldown=2*factor
            turret.attack_parameters.fluid_consumption=factor/2
        end
        if variant=="new" and config.animation_lifetime_candidate then
            jet.particle_loop_frame_count=3;jet.particle_fade_out_duration=nil
        end
        if variant=="old" then
          if baseline then
            -- Frozen approved pressure jet, including unmodified texture files.
            -- Only the source pose and presentation differ from production.
            turret.attack_parameters.gun_barrel_length=baseline.attack.gun_barrel_length
            turret.attack_parameters.gun_center_shift=table.deepcopy(baseline.attack.gun_center_shift)
            turret.attack_parameters.ammo_type.action.action_delivery.source_offset=table.deepcopy(baseline.source_offset)
            for key,value in pairs(baseline.stream) do jet[key]=table.deepcopy(value) end
            if baseline.flecks then
                local frozen_flecks=table.deepcopy(baseline.flecks)
                frozen_flecks.name=turret.name.."-flecks"
                data:extend{frozen_flecks}
                jet.smoke_sources[1].name=frozen_flecks.name
                jet.smoke_sources[1].frequency=baseline.stream.smoke_sources[1].frequency/factor
            else
                jet.smoke_sources=nil;jet.progress_to_create_smoke=nil
            end
            local coating=table.deepcopy(data.raw.sticker[jet.action[1].action_delivery.target_effects[1].sticker])
            coating.name=turret.name.."-sticker";coating.animation=table.deepcopy(baseline.sticker_animation)
            data:extend{coating}
            jet.action[1].action_delivery.target_effects[1].sticker=coating.name
          else
            turret.attack_parameters.cooldown=4*factor
            turret.attack_parameters.fluid_consumption=factor
            jet.smoke_sources=nil;jet.progress_to_create_smoke=nil
            -- Historical lobbed comparator lives only in this QC helper.
            jet.spine_animation={filename="__base__/graphics/entity/flamethrower-fire-stream/flamethrower-fire-stream-spine.png",
                blend_mode="normal",draw_as_glow=true,tint={r=.3,g=.8,b=.8,a=.7},
                line_length=6,width=54,height=26,frame_count=36,animation_speed=2,shift={0,0}}
            jet.particle={filename="__base__/graphics/entity/flamethrower-fire-stream/flamethrower-explosion.png",
                priority="extra-high",blend_mode="normal",draw_as_glow=true,tint={r=.3,g=.8,b=.8,a=.7},
                line_length=6,width=124,height=108,frame_count=36,scale=.666}
            jet.shadow={filename="__base__/graphics/entity/acid-projectile/projectile-shadow.png",
                line_length=5,width=28,height=16,frame_count=33,priority="high",shift={-.09,.395}}
            jet.particle_vertical_acceleration=.0045;jet.particle_horizontal_speed=.3375
            jet.particle_horizontal_speed_deviation=.00525;jet.particle_start_scale=.125
            jet.particle_scale_per_part=nil;jet.width=nil;jet.target_position_deviation=nil
            jet.particle_loop_frame_count=3;jet.particle_fade_out_duration=nil
            jet.particle_end_alpha=.19
            jet.action={jet.action[1]}
            turret.attack_parameters.lead_target_for_projectile_speed=.45
          end
        end
        if component=="direct" then
            jet.action[1].action_delivery.target_effects={jet.action[1].action_delivery.target_effects[2]}
        elseif component=="sticker" then
            jet.action[1].action_delivery.target_effects={jet.action[1].action_delivery.target_effects[1]}
        elseif component=="probe" then
            turret.attack_parameters.ammo_type.action.action_delivery.source_effects={{type="script",effect_id="acid-jet-source"}}
            jet.action[#jet.action+1]={type="direct",action_delivery={type="instant",target_effects={{type="script",effect_id="acid-jet-land"}}}}
        end
        turret.attack_parameters.ammo_type.action.action_delivery.stream=jet.name
        data:extend{turret,jet}
    end
end
local snapshot=data.raw["mod-data"]["acid-jet-final-data"].data
snapshot.test_config=table.deepcopy(config)
snapshot.baseline=baseline and table.deepcopy(baseline) or nil
snapshot.helper_attack={}
for _,variant in ipairs{"old","new"} do
    local attack=data.raw["fluid-turret"]["acid-jet-"..variant.."-probe"].attack_parameters
    snapshot.helper_attack[variant]={cooldown=attack.cooldown,fluid_consumption=attack.fluid_consumption}
end
local target=table.deepcopy(data.raw.unit["behemoth-biter"])
target.name="acid-jet-target";target.max_health=100000000;target.resistances={};target.healing_per_tick=0
target.movement_speed=0;target.vision_distance=0;target.attack_parameters.range=0
target.collision_box={{-.03,-.03},{.03,.03}};target.dying_explosion=nil;target.corpse=nil
target.damaged_trigger_effect=nil -- Suppress fixture blood so the coating is visible.
data:extend{target}
local moving=table.deepcopy(target);moving.name="acid-jet-moving";moving.movement_speed=.04
data:extend{moving}
local small=table.deepcopy(target);small.name="acid-jet-target-small"
small.run_animation=table.deepcopy(data.raw.unit["small-biter"].run_animation)
small.attack_parameters.animation=table.deepcopy(data.raw.unit["small-biter"].attack_parameters.animation)
data:extend{small}
log("ACID_JET_DATA pass=true profile="..config.profile)

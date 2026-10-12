-- Isolated native playback experiment; never loaded by production.
local original=data.raw["fluid-turret"]["ei-acidthrower-turret"]
local stream=data.raw.stream[original.attack_parameters.ammo_type.action.action_delivery.stream]
data:extend{{type="trivial-smoke",name="acid-jet-diagnostic-flecks",flags={"not-on-map"},
    duration=12,fade_in_duration=0,fade_away_duration=4,spread_duration=0,
    affected_by_wind=false,movement_slow_down_factor=0,start_scale=.3,end_scale=1,
    animation={filename="__zzz-esir-acid-jet-qc__/baseline/diagnostic.png",width=64,height=64,
        frame_count=16,line_length=4,animation_speed=1,scale=.5,blend_mode="normal"}}}
for _,kind in ipairs{"fixed","scale","playback","flecks"} do
    local turret=table.deepcopy(original)
    turret.name="acid-dispersion-"..kind;turret.minable=nil;turret.placeable_by=nil;turret.next_upgrade=nil
    turret.attack_parameters.cooldown=240
    turret.attack_parameters.ammo_type.action.action_delivery.source_effects={{type="script",effect_id="acid-dispersion-source"}}
    local jet=table.deepcopy(stream);jet.name=turret.name.."-stream"
    jet.smoke_sources=nil;jet.progress_to_create_smoke=nil
    jet.particle_spawn_interval=2;jet.particle_spawn_timeout=16
    jet.action={{type="direct",action_delivery={type="instant",target_effects={{type="script",effect_id="acid-dispersion-land"}}}}}
    jet.particle={filename="__zzz-esir-acid-jet-qc__/baseline/diagnostic.png",width=64,height=64,
        frame_count=16,line_length=4,animation_speed=.5,scale=.5,blend_mode="normal"}
    jet.shadow=nil
    if kind=="scale" then jet.particle_scale_per_part=1.12 end
    if kind=="playback" then jet.particle_loop_frame_count=1;jet.particle_loop_exit_threshold=.35 end
    if kind=="flecks" then
        jet.particle=table.deepcopy(stream.particle)
        jet.progress_to_create_smoke=.35
        jet.smoke_sources={{name="acid-jet-diagnostic-flecks",frequency=1,position={0,0},
            starting_vertical_speed=0,starting_vertical_speed_deviation=0,height_deviation=0}}
    end
    turret.attack_parameters.ammo_type.action.action_delivery.stream=jet.name
    data:extend{turret,jet}
end
local target=table.deepcopy(data.raw.unit["behemoth-biter"])
target.name="acid-dispersion-target";target.max_health=100000000;target.resistances={};target.healing_per_tick=0
target.movement_speed=0;target.vision_distance=0;target.attack_parameters.range=0
target.collision_box={{-.03,-.03},{.03,.03}};target.dying_explosion=nil;target.corpse=nil
data:extend{target}

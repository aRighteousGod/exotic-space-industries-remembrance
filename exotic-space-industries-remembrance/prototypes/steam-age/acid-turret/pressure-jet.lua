--==============================================================================
-- ESIR FILE MAP
-- owns: acidthrower pressure trajectory and isolated liquid effect artwork
-- loaded_by: prototypes/steam-age/acid-turret/acid.lua, after stream registration
-- cadence: data stage; native streams own emission, flight and impact
--==============================================================================
-- blueprint: .codex/esir/blueprints/acidthrower-pressure-jet.md#contract
local art = "__exotic-space-industries-remembrance-graphics-6__/graphics/entities/acidthrower-turret/pressure-jet/"
local stream = data.raw.stream["ei-flamethrower-acid-stream"]
local turret = data.raw["fluid-turret"]["ei-acidthrower-turret"]

-- Assign the complete liquid presentation before native prototype resolution.
-- The late performance pass clones this finished stream and its effect graph.
stream.spine_animation = {filename=art.."acid-pressure-spine.png",width=64,height=32,
    frame_count=16,line_length=4,animation_speed=0.5,scale=0.5,blend_mode="normal"}
stream.particle = {filename=art.."acid-pressure-droplet.png",width=32,height=32,
    frame_count=16,line_length=4,animation_speed=0.5,scale=0.5,blend_mode="normal"}
stream.shadow = {filename=art.."acid-pressure-droplet-shadow.png",width=32,height=32,
    frame_count=16,line_length=4,animation_speed=0.5,scale=0.5,draw_as_shadow=true}
stream.particle_horizontal_speed = 0.85
stream.particle_vertical_acceleration = 0.00025
stream.particle_horizontal_speed_deviation = 0.0015
stream.target_position_deviation = 0
stream.width = 0.1
stream.particle_start_scale = 1
stream.particle_scale_per_part = 1
stream.particle_end_scale = nil -- Not a Factorio 2.0 stream property.
stream.particle_loop_frame_count = 16
stream.particle_fade_out_duration = 8
stream.particle_end_alpha = 0
stream.stream_light = nil
stream.ground_light = nil
turret.attack_parameters.lead_target_for_projectile_speed = 0.85

-- blueprint-ref: .codex/esir/blueprints/acidthrower-pressure-jet.md#dispersion
-- Leave the connected core alone. Short-lived cosmetic beads begin only after
-- the first third of flight; the late pass thins their source with its profile.
data:extend{{type="trivial-smoke",name="ei-acid-pressure-flecks",flags={"not-on-map"},
    duration=12,fade_in_duration=0,fade_away_duration=4,spread_duration=0,
    affected_by_wind=false,movement_slow_down_factor=0,start_scale=0.15,end_scale=1.25,
    -- Keep the native attenuation and smoke-quality opt-out: performance wins
    -- over preserving cosmetic density on sparse profiles or reduced graphics.
    color={r=0.375,g=0.375,b=0.375,a=0.375},show_when_smoke_off=false,
    render_layer="projectile",
    animation={filename=art.."acid-pressure-flecks.png",width=96,height=96,
        frame_count=16,line_length=4,animation_speed=1,scale=0.5,blend_mode="normal"}}}
stream.progress_to_create_smoke = 0.35
stream.smoke_sources = {{name="ei-acid-pressure-flecks",frequency=0.8,position={0,0},
    starting_vertical_speed=0,starting_vertical_speed_deviation=0,height_deviation=0}}

data:extend{{type="explosion",name="ei-acid-pressure-splash",flags={"not-on-map"},hidden=true,
    height=0,rotate=false,render_layer="explosion",
    animations={{layers={
        {filename=art.."acid-pressure-splash.png",width=512,height=512,frame_count=24,line_length=4,
            animation_speed=1.5,scale=0.5,blend_mode="normal"},
        {filename=art.."acid-pressure-splash-shadow.png",width=512,height=512,frame_count=24,line_length=4,
            animation_speed=1.5,scale=0.5,draw_as_shadow=true},
    }}}}}

-- blueprint-ref: .codex/esir/blueprints/acidthrower-pressure-jet.md#impact-cadence
-- One cosmetic landing chance per particle, not per victim in the area action.
-- Keep initial_action empty: it would replace the first particle's damage.
stream.action[#stream.action+1] = {type="direct",action_delivery={type="instant",
    target_effects={{type="create-explosion",entity_name="ei-acid-pressure-splash",probability=0.25}}}}

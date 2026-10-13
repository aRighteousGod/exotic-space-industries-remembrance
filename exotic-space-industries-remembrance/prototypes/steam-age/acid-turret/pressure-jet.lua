--==============================================================================
-- ESIR FILE MAP
-- owns: acidthrower pressure trajectory and isolated liquid effect artwork
-- loaded_by: prototypes/steam-age/acid-turret/acid.lua, after stream registration
-- cadence: data stage; native streams own emission, flight and impact
--==============================================================================
-- blueprint: .codex/esir/blueprints/acidthrower-pressure-jet.md#contract
local art = ei_graphics_6_path.."graphics/entities/acidthrower-turret/pressure-jet/"
local stream = data.raw.stream["ei-flamethrower-acid-stream"]
local turret = data.raw["fluid-turret"]["ei-acidthrower-turret"]

-- Assign the complete liquid presentation before native prototype resolution.
-- The late performance pass clones this finished stream and its effect graph.
-- The Blender FX have projected height baked into their frame. Register their
-- visible cores on the native source ray; the spine shift rotates with the jet.
-- Do not move the machine's grey nozzle anchor to compensate for texture bias.
stream.spine_animation = {width=32,height=32,
    frame_count=16,animation_speed=0.5,scale=0.5,blend_mode="normal",shift={0,2.25/32},stripes={}}
-- Sample the centre of each original cell without changing its transverse
-- liquid profile. The full 64-pixel cell overdraws the native segment endpoint.
-- User-approved 32-pixel crop: preserve sparse phase gaps rather than adding
-- particles or extending the physical launch beyond the grey nozzle opening.
for frame=0,15 do
    stream.spine_animation.stripes[frame+1] = {
        filename=art.."acid-pressure-spine.png",width_in_frames=1,height_in_frames=1,
        x=(frame%4)*64+16,y=math.floor(frame/4)*32,
    }
end
stream.particle = {filename=art.."acid-pressure-droplet.png",width=32,height=32,
    frame_count=16,line_length=4,animation_speed=0.5,scale=0.5,blend_mode="normal",shift={0,1.35/32}}
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
-- Flecks start small and fade in earlier along the flight. Lower source frequency
-- offsets the longer emitting path; the late pass still thins it by profile.
-- Grow over the whole lifetime, with no opaque plateau: mature stationary
-- clusters otherwise recreate a hard edge even when individual births fade in.
data:extend{{type="trivial-smoke",name="ei-acid-pressure-flecks",flags={"not-on-map"},
    duration=12,fade_in_duration=8,fade_away_duration=4,spread_duration=12,
    affected_by_wind=false,movement_slow_down_factor=0,start_scale=0.05,end_scale=1,
    -- Keep the native attenuation and smoke-quality opt-out: performance wins
    -- over preserving cosmetic density on sparse profiles or reduced graphics.
    color={r=0.375,g=0.375,b=0.375,a=0.375},show_when_smoke_off=false,
    render_layer="projectile",
    animation={filename=art.."acid-pressure-flecks.png",width=96,height=96,
        frame_count=16,line_length=4,animation_speed=1,scale=0.5,blend_mode="normal"}}}
stream.progress_to_create_smoke = 0.12
stream.smoke_sources = {{name="ei-acid-pressure-flecks",frequency=0.59,position={0,0},
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

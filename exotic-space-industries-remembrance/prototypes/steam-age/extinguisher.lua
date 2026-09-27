--==============================================================================
-- ESIR FILE MAP
-- owns: integrated handheld extinguisher, canister, research and spray effects
-- loaded_by: data.lua
-- cadence: data stage only; impact handling lives in control/firefighting
-- provenance: Devilwarriors, extinguisher 2.0.0, portal-declared Unlicense
--==============================================================================
local config = require("lib/firefighting-config")
local path = "__exotic-space-industries-remembrance__/graphics/"

data:extend({
    {type="ammo-category", name=config.gun},
    {
        type="gun", name=config.gun,
        icon=path.."items/extinguisher.png", icon_size=32,
        subgroup="gun", order="e[extinguisher]", stack_size=5,
        attack_parameters={
            type="stream", ammo_category=config.gun, cooldown=1,
            movement_slow_down_factor=0.6, projectile_creation_distance=0.6,
            gun_barrel_length=0.8, gun_center_shift={0,-1}, range=15, min_range=1,
            cyclic_sound=table.deepcopy(data.raw.gun.flamethrower.attack_parameters.cyclic_sound),
        },
    },
    {
        type="ammo", name=config.ammo,
        icon=path.."items/extinguisher-ammo.png", icon_size=32,
        ammo_category=config.gun, magazine_size=100, subgroup="ammo",
        order="e[extinguisher]", stack_size=100,
        ammo_type={target_type="position", clamp_position=true,
            action={type="direct", action_delivery={type="stream",
                stream="ei-handheld-extinguisher-stream", max_length=15, duration=160}}},
    },
    {
        type="recipe", name=config.gun, enabled=false, energy_required=10,
        ingredients={{type="item",name="steel-plate",amount=5},
            {type="item",name="ei-iron-mechanical-parts",amount=10}},
        results={{type="item",name=config.gun,amount=1}},
    },
    {
        type="recipe", name=config.ammo, category="chemistry", enabled=false, energy_required=3,
        ingredients={{type="item",name="iron-plate",amount=5},
            {type="item",name="copper-plate",amount=1}, {type="item",name="stone",amount=5},
            {type="fluid",name="sulfuric-acid",amount=1}, {type="fluid",name="water",amount=5}},
        results={{type="item",name=config.ammo,amount=1}},
    },
    {
        type="technology", name=config.gun,
        icon=path.."technology/extinguisher.png", icon_size=128,
        prerequisites={"sulfur-processing"},
        unit={count=20, ingredients=ei_data.science["steam-age"], time=15},
        effects={{type="unlock-recipe",recipe=config.gun},{type="unlock-recipe",recipe=config.ammo}},
        age="steam-age", order="e-c-b",
    },
    {
        type="trivial-smoke", name="ei-extinguisher-smoke", flags={"not-on-map"},
        duration=300, fade_in_duration=0, fade_away_duration=60,
        spread_duration=600, spread_delay=120, start_scale=1, end_scale=2,
        color={0.1,0.1,0.1,0.1}, cyclic=true, affected_by_wind=true,
        animation={filename=path.."entities/extinguisher/smoke.png", width=152,height=120,
            line_length=5,frame_count=60,axially_symmetrical=false,direction_count=1,
            shift={-0.53125,-0.4375},priority="high",flags={"smoke"},animation_speed=0.25},
    },
    {
        -- Old in-flight effects and saved markers retain a harmless compatibility entity.
        type="corpse", name="extinguisher-remnants", flags={"not-on-map"},
        hidden_in_factoriopedia=true, selectable_in_game=false,
        selection_box={{-0.5,-0.5},{0.5,0.5}}, tile_width=1,tile_height=1,
        time_before_removed=60*60*5,
    },
    {
        type="stream", name="ei-handheld-extinguisher-stream", flags={"not-on-map"},
        smoke_sources={{name="ei-extinguisher-smoke",frequency=0.10,position={0,0},starting_frame_deviation=60}},
        particle_buffer_size=65, particle_spawn_interval=1, particle_spawn_timeout=1,
        particle_vertical_acceleration=0.003, particle_horizontal_speed=0.25,
        particle_horizontal_speed_deviation=0.0035, particle_start_alpha=1, particle_end_alpha=0.8,
        particle_start_scale=0.1, particle_loop_frame_count=3, particle_fade_out_threshold=0.9,
        particle_loop_exit_threshold=0.25,
        action={type="direct",action_delivery={type="instant",
            target_effects={{type="script",effect_id=config.handheld_effect}}}},
        spine_animation={filename=path.."entities/extinguisher/stream-spine.png",blend_mode="additive-soft",
            line_length=4,width=32,height=18,frame_count=32,axially_symmetrical=false,
            direction_count=1,animation_speed=1,scale=0.60,shift={0,0}},
        particle={filename=path.."entities/extinguisher/fumes.png",priority="extra-high",
            width=64,height=64,frame_count=32,line_length=8,scale=1.5},
    },
})

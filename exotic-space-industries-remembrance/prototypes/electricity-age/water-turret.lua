--==============================================================================
-- ESIR FILE MAP
-- owns: water-only support turret, slowing stream and private suppression streams
-- loaded_by: data.lua
-- cadence: data stage; control/water-turret owns power and firefighting
--==============================================================================
local config = require("lib/firefighting-config")
local icon = "__exotic-space-industries-remembrance__/graphics/items/water-turret.png"
local art = "__exotic-space-industries-remembrance__/graphics/entities/water-turret/"

-- The native combat payload has no damage, fire or global targeting changes.
local stream = table.deepcopy(data.raw.stream["ei-handheld-extinguisher-stream"])
stream.name = "ei-water-combat-stream"
stream.smoke_sources = nil
stream.particle_buffer_size = 128
stream.particle_spawn_interval = 2
stream.particle_spawn_timeout = 16
stream.particle_horizontal_speed = 0.4
stream.particle.tint = {0.5, 0.8, 1, 0.65}
stream.spine_animation.tint = {0.5, 0.8, 1, 0.65}
stream.spine_animation.blend_mode = "normal"
stream.action = {type="area", radius=config.radius, force="enemy",
    action_delivery={type="instant", target_effects={
        {type="create-sticker", sticker="ei-water-slow", show_in_tooltip=true},
    }}}

---@type data.FluidTurretPrototype
local turret = table.deepcopy(data.raw["fluid-turret"]["flamethrower-turret"])
turret.name = config.turret
turret.icon = icon
turret.icon_size = 128
turret.icon_mipmaps = 3
turret.icons = nil
turret.minable = {mining_time=0.5, result=config.turret}
turret.max_health = 800
turret.resistances = {{type="fire",percent=75}}
turret.tile_width = 3
turret.tile_height = 3
turret.collision_box = {{-1.2,-1.2},{1.2,1.2}}
turret.selection_box = {{-1.5,-1.5},{1.5,1.5}}
turret.fast_replaceable_group = nil
turret.next_upgrade = nil
turret.factoriopedia_simulation = nil
turret.turret_base_has_direction = true
turret.rotation_speed = 0.02
turret.preparing_speed = 1
turret.folding_speed = 1
turret.prepare_range = config.range
turret.rotation_slowdown = 1
-- Engine-positioned collars stay aligned with ordinary pipes while the complete
-- platform, head, backpack and internal supply pipe rotate independently.
turret.fluid_box = {volume=100, filter="water", production_type="none",
    pipe_picture=assembler2pipepictures(), pipe_covers=pipecoverspictures(),
    render_layer="lower-object", secondary_draw_order=0, pipe_connections={
    {direction=defines.direction.west, position={-1,0}},
    {direction=defines.direction.east, position={1,0}},
}}
turret.fluid_buffer_size = 100
turret.fluid_buffer_input_flow = 1
turret.activation_buffer_ratio = 0.25
-- Both roles retain the same ground origin, 576px canvas and half scale.
-- Upper platform, backpack and pipe are one 64-direction rotating assembly.
turret.base_picture = nil
turret.graphics_set = {base_visualisation={render_layer="object",secondary_draw_order=0,
    animation=ei_lib.make_4way_animation_from_spritesheet({layers={
        {filename=art.."water-turret-base.png",width=576,height=576,frame_count=1,scale=0.5,shift={0,0}},
        {filename=art.."water-turret-base_shadow.png",width=576,height=576,frame_count=1,scale=0.5,shift={0,0},draw_as_shadow=true},
    }})}}
local head = {layers={
    {filename=art.."water-turret-head.png",width=576,height=576,line_length=8,frame_count=1,
        direction_count=64,scale=0.5,shift={0,0},apply_projection=true,counterclockwise=false},
    {filename=art.."water-turret-head_mask.png",width=576,height=576,line_length=8,frame_count=1,
        direction_count=64,scale=0.5,shift={0,0},apply_projection=true,counterclockwise=false,
        flags={"mask"},apply_runtime_tint=true},
    {filename=art.."water-turret-head_shadow.png",width=576,height=576,line_length=8,frame_count=1,
        direction_count=64,scale=0.5,shift={0,0},apply_projection=true,counterclockwise=false,draw_as_shadow=true},
}}
for _,key in ipairs{"folded_animation","preparing_animation","prepared_animation",
    "attacking_animation","ending_attack_animation","folding_animation"} do
    turret[key] = table.deepcopy(head)
end
turret.muzzle_animation = nil
turret.muzzle_light = nil
for _,key in ipairs{"folded","preparing","prepared","attacking","ending_attack","folding"} do
    turret[key.."_muzzle_animation_shift"] = nil
end
turret.preparing_muzzle_animation = nil
turret.prepared_muzzle_animation = nil
turret.folded_muzzle_animation = nil
turret.attacking_muzzle_animation = nil
turret.ending_attack_muzzle_animation = nil
turret.folding_muzzle_animation = nil
turret.attack_parameters = {
    type="stream", ammo_category="ei-water", cooldown=4,
    fluid_consumption=2, fluids={{type="water"}},
    range=config.range, min_range=0, turn_range=1, fire_penalty=0,
    gun_barrel_length=config.muzzle_length, gun_center_shift={0,-config.muzzle_height},
    ammo_type={category="ei-water", target_type="position", clamp_position=true,
        action={type="direct", action_delivery={type="stream", stream=stream.name,
            source_offset={0,0}}}},
}

data:extend({
    {type="ammo-category",name="ei-water"},
    {type="sticker",name="ei-water-slow",flags={"not-on-map"},
        duration_in_ticks=120,target_movement_modifier=0.75,
        animation={filename=ei_lib.empty_sprite(),width=64,height=64}},
    stream, turret,
    {type="item", name=config.turret, icon=icon, icon_size=128, icon_mipmaps=3,
        subgroup="defensive-structure",order="b[turret]-b[water]",stack_size=50,place_result=config.turret},
    {type="recipe",name=config.turret,enabled=false,energy_required=8,
        ingredients={{type="item",name=config.gun,amount=1},
            {type="item",name="pump",amount=1},
            {type="item",name="ei-steel-mechanical-parts",amount=12},
            {type="item",name="electronic-circuit",amount=10},
            {type="item",name="pipe",amount=10},{type="item",name="steel-plate",amount=10}},
        results={{type="item",name=config.turret,amount=1}}},
    {type="technology",name=config.turret,
        icon="__exotic-space-industries-remembrance__/graphics/technology/water-turret.png",icon_size=256,
        prerequisites={config.gun,"fluid-handling","ei-electricity-power","gun-turret"},
        unit={count=100,time=20,ingredients=ei_data.science["electricity-age"]},
        effects={{type="unlock-recipe",recipe=config.turret}},age="electricity-age",order="e-c-c"},
    {type="electric-energy-interface",name=config.power,
        flags={"not-on-map","placeable-off-grid","not-blueprintable","not-deconstructable","not-flammable"},
        hidden=true,hidden_in_factoriopedia=true,selectable_in_game=false,
        collision_mask={layers={}},collision_box={{-1.2,-1.2},{1.2,1.2}},
        energy_source={type="electric",usage_priority="secondary-input",buffer_capacity="50kJ",
            input_flow_limit="200kW",output_flow_limit="0W",render_no_power_icon=false,
            render_no_network_icon=false},
        energy_usage="100kW",energy_production="0W",picture={filename=ei_lib.empty_sprite(),width=64,height=64},
        gui_mode="none",allow_copy_paste=false},
})

for _,effect in ipairs{config.protect_effect,config.all_effect} do
    local pulse = table.deepcopy(stream)
    pulse.name = effect.."-stream"
    pulse.action = nil
    -- initial_action lands once; remaining particles are purely cosmetic.
    pulse.initial_action = {type="direct",action_delivery={type="instant",
        target_effects={{type="script",effect_id=effect}}}}
    data:extend({pulse})
end

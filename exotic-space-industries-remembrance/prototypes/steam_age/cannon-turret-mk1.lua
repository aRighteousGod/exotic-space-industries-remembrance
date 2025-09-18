function cannon_turret_sheet(inputs)
    return {
        layers = {{
            filename = ei_graphics_3_path.."graphics/entity/cannon-turret-mk1/cannon-turret-sheet.png",
            priority = "medium",
            scale = 0.75,
            width = 128,
            height = 128,
            direction_count = inputs.direction_count and inputs.direction_count or 64,
            frame_count = 1,
            line_length = inputs.line_length and inputs.line_length or 8,
            axially_symmetrical = false,
            run_mode = inputs.run_mode and inputs.run_mode or "forward",
            shift = {0.35, -0.5}
        }}
    }
end

local sounds = require("__base__/prototypes/entity/sounds")

-- Make subgroup follow whatever subgroup the base gun turret uses (some mods move turrets out of
-- "defensive-structure"). This keeps our item/recipe grouped alongside the other turrets.
local gun_turret_item = data.raw["item"] and data.raw["item"]["gun-turret"]
local gun_turret_recipe = data.raw["recipe"] and data.raw["recipe"]["gun-turret"]
local turret_item_subgroup = (gun_turret_item and gun_turret_item.subgroup) or "defensive-structure"
local turret_recipe_subgroup = (gun_turret_recipe and gun_turret_recipe.subgroup) or "defensive-structure"

--====================================================================================================
-- CANNON TURRET MK1
--====================================================================================================

data:extend({
    {
    type = "item",
    name = "ei-cannon-turret-mk1",
    icon = ei_graphics_3_path.."graphics/item/cannon-turret-mk1.png",
    icon_size = 64,
    subgroup = "defensive-structure",
    order = "c-ab",
    place_result = "ei-cannon-turret-mk1",
    stack_size = 50
},
{
    type = "technology",
    name = "ei-cannon-turret-mk1",
    icon_size = 128,
    icon_mipmaps = 4,
    icon = ei_graphics_3_path.."graphics/tech/cannon-turret-mk1.png",
    effects = {{
        type = "unlock-recipe",
        recipe = "ei-cannon-turret-mk1"
    }},
    prerequisites = {"explosives","engine","electronics"},
        unit = {
            count = 100,
            ingredients = ei_data.science["steam-age"],
            time = 20
        },
        age = "steam-age",
    },
    {
    type = "recipe",
    name = "ei-cannon-turret-mk1",
    icon = ei_graphics_3_path.."graphics/item/cannon-turret-mk1.png",
    icon_size = 64,
    icon_mipmaps = 4,
    subgroup = turret_recipe_subgroup,
    order = "b[turret]-a2[laser-turret]",
    energy_required = 4,
    ingredients = {
    {type="item", name="gun-turret", amount=1},
    {type="item", name="ei-iron-mechanical-parts", amount=35},
    {type="item", name="engine-unit", amount=10},
    {type="item", name="steel-plate", amount=20},
    {type="item", name="electronic-circuit", amount=4},
    },
    results = {
        {type = "item",name = "ei-cannon-turret-mk1",amount = 1}
    },
    enabled = false,
    always_show_made_in = true,
},
{
    type = "ammo-turret",
    name = "ei-cannon-turret-mk1",
    icon = ei_graphics_3_path.."graphics/item/cannon-turret-mk1.png",
    icon_size = 64,
    icon_mipmaps = 4,
    flags = {"placeable-player", "player-creation", "building-direction-8-way"},
    minable = {
        mining_time = 0.5,
        result = "ei-cannon-turret-mk1"
    },
    max_health = 750,
    resistances = {
        {type = "physical", percent = 25},
        {type = "fire", percent = 30},
        {type = "impact", percent = 30},
    },
    corpse = "medium-remnants",
    collision_box = {{-0.7, -0.7}, {0.7, 0.7}},
    selection_box = {{-1, -1}, {1, 1}},
    rotation_speed = 0.00185,
    preparing_speed = 0.1,
    folding_speed = 0.1,
    dying_explosion = "medium-explosion",
    inventory_size = 1,
    heating_energy = "50kW",
    attacking_speed = 0.24,
    automated_ammo_count = 5,

    preparing_sound = sounds.gun_turret_activate,
    folding_sound = sounds.gun_turret_deactivate,
    alert_when_attacking = true,
    open_sound = sounds.machine_open,
    close_sound = sounds.machine_close,
    turret_base_has_direction = true,
    graphics_set = {},
    folded_animation = cannon_turret_sheet {
        direction_count = 8,
        line_length = 1
    },
    preparing_animation = cannon_turret_sheet {
        direction_count = 8,
        line_length = 1
    },
    prepared_animation = cannon_turret_sheet {},
    attacking_animation = cannon_turret_sheet {},
    folding_animation = cannon_turret_sheet {
        direction_count = 8,
        line_length = 1,
        run_mode = "backward"
    },

    vehicle_impact_sound = sounds.generic_impact,

    attack_parameters = {
        type = "projectile",
        ammo_category = "cannon-shell",
        cooldown = 300,
        prepare_range = 29,
        rotate_penalty = 20,
        health_penalty = -10,
		projectile_creation_distance = 1.39375,
		projectile_center = {0.1, -0.0875},
        damage_modifier = 1,
        shell_particle = {
            name = "shell-particle",
            direction_deviation = 0.33,
            speed = 0.1,
            speed_deviation = 0.09,
            center = {0.1, -0.0875},
            creation_distance = 1.39375,
            starting_frame_speed = 0.18,
            starting_frame_speed_deviation = 0.1
        },
        range = 25,
        turn_range = 0.3333333334,
        min_range = 8,
        sound = sounds.tank_gunshot
    },
    call_for_help_radius = 40,
    circuit_connector =  circuit_connector_definitions.create_vector(
        universal_connector_template,
        {
            {variation = 14, main_offset = util.by_pixel( 3.875,  10.25), shadow_offset = util.by_pixel( 3.875,  10.25), show_shadow = true },
            {variation = 14, main_offset = util.by_pixel( 3.875,  10.25), shadow_offset = util.by_pixel( 3.875,  10.25), show_shadow = true },
            {variation = 14, main_offset = util.by_pixel( 3.875,  10.25), shadow_offset = util.by_pixel( 3.875,  10.25), show_shadow = true },
            {variation = 14, main_offset = util.by_pixel( 3.875,  10.25), shadow_offset = util.by_pixel( 3.875,  10.25), show_shadow = true },
            {variation = 14, main_offset = util.by_pixel( 3.875,  10.25), shadow_offset = util.by_pixel( 3.875,  10.25), show_shadow = true },
            {variation = 14, main_offset = util.by_pixel( 3.875,  10.25), shadow_offset = util.by_pixel( 3.875,  10.25), show_shadow = true },
            {variation = 14, main_offset = util.by_pixel( 3.875,  10.25), shadow_offset = util.by_pixel( 3.875,  10.25), show_shadow = true },
            {variation = 14, main_offset = util.by_pixel( 3.875,  10.25), shadow_offset = util.by_pixel( 3.875,  10.25), show_shadow = true },
        }),
    circuit_wire_max_distance = default_circuit_wire_max_distance,
},
}
)

-- blueprint: .codex/esir/blueprints/minigun-turret-graphics.md#contract

-- blueprint-ref: .codex/esir/blueprints/minigun-turret-graphics.md#profile-selection
-- One enabled texture profile owns entity/item icons, research art and native
-- state layers. The recipe inherits its main product's selected item icon.
local graphics = require("prototypes/electricity-age/gatling-turret/graphics").create()
local icons = graphics.icons()

-- blueprint-ref: .codex/esir/blueprints/minigun-turret-graphics.md#casing-ejection
-- This particle belongs to the turret; other weapons retain vanilla casing life.
---@type data.ParticlePrototype
local shell_particle = table.deepcopy(data.raw["optimized-particle"]["shell-particle"])
shell_particle.name = "ei-gatling-shell-particle"
shell_particle.life_time = 240
shell_particle.fade_away_duration = 60
shell_particle.movement_modifier_when_on_ground = 0.6
data:extend({shell_particle})

data:extend({
	{
		name = "ei-gatling-turret",
		type = "item",
		icon = icons.item.icon,
		icon_size = icons.item.icon_size,
		subgroup = "defensive-structure",
		order = "c-ab",
		place_result = "ei-gatling-turret",
		stack_size = 10,
	},
	{
		type = "ammo-turret",
		name = "ei-gatling-turret",
		icon = icons.item.icon,
		icon_size = icons.item.icon_size,
		flags = { "placeable-player", "player-creation" },
		minable = { mining_time = 0.75, result = "ei-gatling-turret" },
		max_health = 1500,
		heating_energy = "100kW",
		hide_resistances = false,
        circuit_connector =  circuit_connector_definitions.create_vector(
        universal_connector_template,
        {
            { variation = 28, main_offset = util.by_pixel( 47.5,  32.25), shadow_offset = util.by_pixel( 47.5,  32.25), show_shadow = true },
        }
        ),
        circuit_wire_max_distance = default_circuit_wire_max_distance,
		energy_source = {
			type = "electric",
			buffer_capacity = "666kJ",
			--input_flow_limit = "500kW",
			drain = "15kW",
			usage_priority = "primary-input",
		},
		energy_per_shot = "1kJ",
		resistances = {
			{ type = "physical", percent = 50 },
			{ type = "fire", percent = 75 },
			{ type = "impact", percent = 75 },
		},
		corpse = "big-remnants",
		damaged_trigger_effect = hit_effects.entity(),
		collision_box = { { -1.4, -1.4 }, { 1.4, 1.4 } },
		selection_box = { { -1.5, -1.5 }, { 1.5, 1.5 } },
		--collision_box = { { -0.7, -0.7 }, { 0.7, 0.7 } },
		--selection_box = { { -1, -1 }, { 1, 1 } },
		rotation_speed = 0.01,
		shoot_in_prepare_state = false,
		dying_explosion = "big-explosion",
		inventory_size = 1,
		prepare_range = 35,
		automated_ammo_count = 10,
		can_retarget_while_starting_attack = true,
		attacking_speed = 20,
        preparing_sound = {
            variations = {
				{
                    filename = ei_sounds_path .. "gatling-turret-preparing.ogg",
					volume = 0.6,
				},
			},
            audible_distance_modifier = 0.66,
            aggregation = {max_count = 2, remove = true, count_already_playing = true},
        },
        folding_sound = {
            variations = {
				{
                    filename = ei_sounds_path .. "gatling-turret-folding.ogg",
					volume = 0.6,
				},
			},
            audible_distance_modifier = 0.66,
            aggregation = {max_count = 2, remove = true, count_already_playing = true},
        },
        alert_when_attacking = true,
        open_sound = sounds.machine_open,
        close_sound = sounds.machine_close,
		vehicle_impact_sound = { variations = sound_variations("__base__/sound/car-metal-impact", 5, 0.8) },

		attack_parameters = {
			type = "projectile",
			ammo_categories = { "bullet" },
			cooldown = 0.25,
			rotate_penalty = 14.0,
			shell_particle = {
				name = "ei-gatling-shell-particle",
				-- Native offsets start at the calibrated launch point. Move back to
				-- the gun-right receiver lip, then apply its separate particle height.
				direction = 105 / 360,
				direction_deviation = 0.025,
				speed = 0.06,
				speed_deviation = 0.008,
				center = { 0, 0 },
				creation_distance = 3.331004451991,
				creation_distance_orientation = 0.482194244912,
				use_source_position = false,
				height = 0.918880365094,
				vertical_speed = 0.01,
				starting_frame_speed = 0.2,
				starting_frame_speed_deviation = 0.04,
			},
			range = 32,
			min_range = 4,
			sound = {
				category = "weapon",
				variations = {
					{
                        filename = ei_sounds_path .. "gatling-turret-firing.ogg",
						volume = 0.7,
					},
				},
				audible_distance_modifier = 0.66,
				aggregation = {max_count = 8, remove = true, count_already_playing = true, priority = "newest"},
			},
		},

		call_for_help_radius = 35,
	},

	{
		name = "ei-gatling-turret",
		type = "recipe",
		category = "crafting",
		energy_required = 8,
		ingredients = {
			{ type = "item", name = "gun-turret", amount = 1 },
			{ type = "item", name = "ei-minigun", amount = 1 },
			{ type = "item", name = "ei-steel-mechanical-parts", amount = 30 },
			{ type = "item", name = "electric-engine-unit", amount = 8 },
			{ type = "item", name = "advanced-circuit", amount = 15 },
		},
		results = { { type = "item", name = "ei-gatling-turret", amount = 1 } },
		enabled = false,
		always_show_made_in = true,
		main_product = "ei-gatling-turret",
	},
	{
		name = "ei-gatling-turret",
		type = "technology",
		icon = icons.technology.icon,
		icon_size = icons.technology.icon_size,
		prerequisites = {
			"gun-turret",
			"ei-electricity-power",
			"ei-minigun",
			"advanced-circuit",
			"electric-engine",
		},
		effects = {
			{
				type = "unlock-recipe",
				recipe = "ei-gatling-turret",
			},
		},
		unit = {
			count = 100,
			ingredients = ei_data.science["electricity-age"],
			time = 20,
		},
		age = "electricity-age",
	},
})

-- blueprint-ref: .codex/esir/blueprints/minigun-turret-graphics.md#muzzle-alignment
-- Apply the finalizer's exact native-tested launch fields with the new art;
-- attack cadence, ammunition, connector and shell-particle behavior stay here.
graphics.apply(data.raw["ammo-turret"]["ei-gatling-turret"])

table.insert(
	data.raw.technology["physical-projectile-damage-1"].effects,
	{ type = "turret-attack", turret_id = "ei-gatling-turret", modifier = 0.1 }
)
table.insert(
	data.raw.technology["physical-projectile-damage-2"].effects,
	{ type = "turret-attack", turret_id = "ei-gatling-turret", modifier = 0.1 }
)
table.insert(
	data.raw.technology["physical-projectile-damage-3"].effects,
	{ type = "turret-attack", turret_id = "ei-gatling-turret", modifier = 0.2 }
)
table.insert(
	data.raw.technology["physical-projectile-damage-4"].effects,
	{ type = "turret-attack", turret_id = "ei-gatling-turret", modifier = 0.2 }
)
table.insert(
	data.raw.technology["physical-projectile-damage-5"].effects,
	{ type = "turret-attack", turret_id = "ei-gatling-turret", modifier = 0.2 }
)
table.insert(
	data.raw.technology["physical-projectile-damage-6"].effects,
	{ type = "turret-attack", turret_id = "ei-gatling-turret", modifier = 0.2 }
)
table.insert(
	data.raw.technology["physical-projectile-damage-7"].effects,
	{ type = "turret-attack", turret_id = "ei-gatling-turret", modifier = 0.2 }
)

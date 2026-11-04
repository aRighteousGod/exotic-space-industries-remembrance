-- blueprint: .codex/esir/blueprints/combustion-turbine.md#contract
-- Native combustion and generation; runtime only owns topology and settings.
local config = require("lib/combustion-turbine-config")
local solid = data.raw["burner-generator"][config.solid]
local fluid = data.raw.generator[config.fluid]
solid.localised_description = {"entity-description.ei-combustion-turbine", tostring(config.atmospheric_oxygen_min_pressure)}
fluid.localised_description = table.deepcopy(solid.localised_description)
data.raw.item[config.solid].localised_description = table.deepcopy(solid.localised_description)
data.raw.technology[config.solid].localised_description = table.deepcopy(solid.localised_description)
local names = {config.solid, config.fluid, config.oxygen_solid, config.oxygen_fluid,
    config.ash_solid, config.oxygen_ash_solid,
    "ei-combustion-turbine-fluid-open-proxy"}
solid.additional_pastable_entities = table.deepcopy(names)
fluid.additional_pastable_entities = table.deepcopy(names)
data.raw["constant-combinator"]["ei-combustion-turbine-fluid-open-proxy"].additional_pastable_entities = table.deepcopy(names)
data.raw["constant-combinator"]["ei-combustion-turbine-fluid-open-proxy"].localised_description = table.deepcopy(solid.localised_description)

data:extend({
    {type="fluid", name=config.working_fluid, icon=solid.icon, icon_size=64,
        localised_name={"fluid-name.ei-combustion-turbine-working-fluid"},
        default_temperature=15, max_temperature=615, heat_capacity="1kJ",
        base_color={0.65,0.35,0.15}, flow_color={0.9,0.6,0.3},
        hidden=true, hidden_in_factoriopedia=true, auto_barrel=false},
    {type="recipe-category", name=config.recipe},
    {type="recipe", name=config.recipe, categories={config.recipe},
        icon=solid.icon, icon_size=64, localised_name={"recipe-name.ei-combustion-turbine-oxygen-combustion"},
        hidden=true, hidden_in_factoriopedia=true, enabled=true,
        energy_required=0.05, allow_productivity=false, maximum_productivity=0, allow_quality=false,
        auto_recycle=false,
        -- Deliberately fixed private buffers on the exact 2.1 engine, with or
        -- without Quality: 200 input units and three working-fluid output units.
        ingredients={{type="fluid",name="ei-oxygen-gas",amount=1,fluidbox_multiplier=199}},
        results={{type="fluid",name=config.working_fluid,amount=1,temperature=615,fluidbox_multiplier=3}}},
})

local quality_speed = {}
for name in pairs(data.raw.quality or {}) do quality_speed[name] = 1 end
for _, mode in ipairs({"solid", "fluid"}) do
    local machine = {
        type="assembling-machine", name=mode=="solid" and config.oxygen_solid or config.oxygen_fluid,
        icon=solid.icon, icon_size=solid.icon_size,
        localised_name={"entity-name.ei-combustion-turbine"},
        localised_description=table.deepcopy(solid.localised_description),
        flags=table.deepcopy(solid.flags), hidden=true, hidden_in_factoriopedia=true,
        placeable_by={item=config.solid,count=1}, minable=table.deepcopy(solid.minable),
        fast_replaceable_group=solid.fast_replaceable_group,
        max_health=solid.max_health, corpse=solid.corpse, dying_explosion=solid.dying_explosion,
        collision_box=table.deepcopy(solid.collision_box), selection_box=table.deepcopy(solid.selection_box),
        map_color=table.deepcopy(solid.map_color), heating_energy="0kW",
        additional_pastable_entities=table.deepcopy(names),
        crafting_categories={config.recipe}, fixed_recipe=config.recipe, crafting_speed=1,
        crafting_speed_quality_multiplier=quality_speed, quality_affects_energy_usage=false,
        quality_affects_module_slots=false, module_slots=0, allowed_effects={},
        effect_receiver={uses_module_effects=false,uses_beacon_effects=false,uses_surface_effects=false},
        energy_usage="12MW", fluid_boxes_off_when_no_fluid_recipe=false,
        energy_source=table.deepcopy(solid.burner),
        graphics_set={animation=table.deepcopy(solid.animation)},
        working_sound=table.deepcopy(solid.working_sound),
        fluid_boxes={
            {volume=200,production_type="input",pipe_covers=pipecoverspictures(),pipe_picture=ei_pipe_big,
                pipe_connections={{direction=defines.direction.north,position={0,-4},flow_direction="input"}}},
            {volume=3,production_type="output",pipe_connections={
                {connection_type="linked",linked_connection_id=1,flow_direction="output",hide_connection_info=true}}},
        },
    }
    machine.energy_source.burnt_inventory_size = 0
    if mode=="fluid" then
        machine.graphics_set.animation.filename=ei_graphics_entity_4_path.."combustion-turbine-fluid_animation.png"
        machine.energy_source={type="fluid",burns_fluid=true,scale_fluid_usage=true,
            effectivity=fluid.effectivity,fluid_usage_per_tick=fluid.fluid_usage_per_tick,
            maximum_temperature=fluid.maximum_temperature,
            emissions_per_minute=table.deepcopy(fluid.energy_source.emissions_per_minute),
            fluid_box=table.deepcopy(fluid.fluid_box)}
    end
    data:extend{machine}
end

local generator = table.deepcopy(fluid)
generator.name = config.generator
generator.localised_name = {"entity-name.ei-combustion-turbine"}
generator.localised_description = table.deepcopy(solid.localised_description)
generator.flags={"not-on-map","not-blueprintable","not-deconstructable","not-flammable","not-repairable","not-upgradable","hide-alt-info"}
generator.minable=nil
generator.placeable_by=nil
generator.fast_replaceable_group=nil
generator.additional_pastable_entities=nil
-- Pipe mouths must lie inside the native bounding box, even on a helper
-- whose empty collision mask permits overlap with its owner.
generator.collision_box=table.deepcopy(solid.collision_box)
generator.collision_mask={layers={}}
generator.selection_box={{0,0},{0,0}}
generator.selectable_in_game=false
generator.two_direction_only=false
generator.corpse=nil
generator.dying_explosion=nil
generator.dying_trigger_effect=nil
generator.working_sound=nil
generator.smoke=nil
generator.effectivity=1
generator.burns_fluid=false
generator.scale_fluid_usage=true
generator.maximum_temperature=615
generator.minimum_input_temperature=615
generator.fluid_usage_per_tick=1/3
generator.max_power_output="12MW"
generator.energy_source.emissions_per_minute=nil
generator.fluid_box={volume=3,filter=config.working_fluid,production_type="input",
    pipe_connections={{connection_type="linked",linked_connection_id=1,flow_direction="input",hide_connection_info=true}}}
generator.output_fluid_box={volume=200,filter="ei-carbon-dioxide",production_type="output",
    pipe_covers=pipecoverspictures(),pipe_picture=ei_pipe_big,
    pipe_connections={{direction=defines.direction.south,position={0,4},flow_direction="output"}}}
generator.spent_fluid={name="ei-carbon-dioxide",amount=1,temperature=15}
generator.pictures={north={animation=util.empty_sprite()},east={animation=util.empty_sprite()},
    south={animation=util.empty_sprite()},west={animation=util.empty_sprite()}}
data:extend{generator}

-- Same recipe and gas energy density: lower throughput and burner efficiency
-- retain the full-load chemical-fuel rate without scripted production.
local ash = table.deepcopy(solid)
ash.name = config.ash_solid
ash.localised_name = {"entity-name.ei-combustion-turbine"}
ash.localised_description = table.deepcopy(solid.localised_description)
ash.hidden = true
ash.hidden_in_factoriopedia = true
ash.max_power_output = "10.8MW"
ash.burner.effectivity = solid.burner.effectivity * config.ash_factor
ash.burner.emissions_per_minute.pollution = 108
ash.burner.burnt_inventory_size = config.ash_slots
local oxygen_ash = table.deepcopy(data.raw["assembling-machine"][config.oxygen_solid])
oxygen_ash.name = config.oxygen_ash_solid
oxygen_ash.energy_usage = "10.8MW"
oxygen_ash.crafting_speed = config.ash_factor
oxygen_ash.energy_source.effectivity = ash.burner.effectivity
oxygen_ash.energy_source.emissions_per_minute.pollution = 108
oxygen_ash.energy_source.burnt_inventory_size = config.ash_slots
local ash_generator = table.deepcopy(generator)
ash_generator.name = config.ash_generator
ash_generator.max_power_output = "10.8MW"
ash_generator.fluid_usage_per_tick = generator.fluid_usage_per_tick * config.ash_factor
data:extend{ash, oxygen_ash, ash_generator}

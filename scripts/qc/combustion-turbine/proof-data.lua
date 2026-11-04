-- Private native fuel + oxygen -> working fluid -> electricity + CO2 proof.
local p = "esir-turbine-proof-"
for _, name in ipairs({"oxygen", "co2", "working", "diesel"}) do
    data:extend{{type="fluid",name=p..name,default_temperature=15,max_temperature=615,
        icon="__base__/graphics/icons/fluid/steam.png",icon_size=64,
        heat_capacity="1kJ",fuel_value=name=="diesel" and "200kJ" or nil,
        base_color={0.4,0.6,0.8},flow_color={0.4,0.6,0.8},auto_barrel=false,hidden=true}}
end
data:extend{{type="recipe-category",name=p.."combustion"},
    {type="recipe",name=p.."combustion",categories={p.."combustion"},hidden=true,
        enabled=true,energy_required=0.05,allow_productivity=false,allow_quality=false,
        ingredients={{type="fluid",name=p.."oxygen",amount=1,fluidbox_multiplier=199}},
        results={{type="fluid",name=p.."working",amount=1,temperature=615,fluidbox_multiplier=3}}}}
local quality_speed = {}
for name in pairs(data.raw.quality or {}) do quality_speed[name] = 1 end
for _, mode in ipairs({"solid", "fluid"}) do
    local m = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-2"])
    m.name = p..mode
    m.minable = nil
    m.next_upgrade = nil
    m.fast_replaceable_group = nil
    m.crafting_categories = {p.."combustion"}
    m.fixed_recipe = p.."combustion"
    m.crafting_speed = 1
    m.crafting_speed_quality_multiplier = quality_speed
    m.quality_affects_energy_usage = false
    m.quality_affects_module_slots = false
    m.module_slots = 0
    m.allowed_effects = {}
    m.effect_receiver = {uses_module_effects=false,uses_beacon_effects=false,uses_surface_effects=false,uses_local_effects=false}
    m.energy_usage = "12MW"
    m.energy_source = mode=="solid" and {type="burner",fuel_categories={"chemical"},effectivity=3,
        fuel_inventory_size=3,burnt_inventory_size=0}
        or {type="fluid",burns_fluid=true,scale_fluid_usage=true,effectivity=2.25,fluid_usage_per_tick=1,
            fluid_box={volume=400,production_type="input-output",pipe_connections={
                {direction=defines.direction.east,position={1,0},flow_direction="input-output"}}}}
    m.fluid_boxes = {
        {volume=200,production_type="input",pipe_connections={{direction=defines.direction.north,position={0,-1},flow_direction="input"}}},
        {volume=3,production_type="output",pipe_connections={{connection_type="linked",linked_connection_id=1,flow_direction="output"}}},
    }
    data:extend{m}
end
local g = table.deepcopy(data.raw.generator["steam-engine"])
g.name = p.."generator"
g.minable = nil
g.next_upgrade = nil
g.fast_replaceable_group = nil
g.effectivity = 1
g.burns_fluid = false
g.scale_fluid_usage = true
g.maximum_temperature = 615
g.minimum_input_temperature = 615
g.fluid_usage_per_tick = 1/3
g.max_power_output = "12MW"
g.fluid_box = {volume=3,filter=p.."working",production_type="input",
    pipe_connections={{connection_type="linked",linked_connection_id=1,flow_direction="input"}}}
g.output_fluid_box = {volume=200,filter=p.."co2",production_type="output",
    pipe_connections={{direction=defines.direction.south,position={0,2},flow_direction="output"}}}
g.spent_fluid = {name=p.."co2",amount=1,temperature=15}
data:extend{g}
local load = table.deepcopy(data.raw["electric-energy-interface"]["electric-energy-interface"])
load.name = p.."load"
load.energy_source = {type="electric",buffer_capacity="1MJ",usage_priority="primary-input",input_flow_limit="12MW",output_flow_limit="0W"}
load.energy_production = "0W"
load.energy_usage = "12MW"
data:extend{load}

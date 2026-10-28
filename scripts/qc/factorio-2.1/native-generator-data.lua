-- Minimal engine reproduction: no ESIR control, compatibility owners or assets.
local generator=table.deepcopy(data.raw.generator["steam-engine"])
generator.name="qc-native-generator"
generator.minable=nil
generator.burns_fluid=true
generator.scale_fluid_usage=true
generator.fluid_usage_per_tick=1
generator.effectivity=2.25
generator.max_power_output="12MW"
generator.maximum_temperature=1000
generator.fluid_box={volume=400,production_type="input-output",pipe_connections={
    {flow_direction="input-output",direction=defines.direction.east,position={1,0}},
    {flow_direction="input-output",direction=defines.direction.west,position={-1,0}},
}}
local pipe=table.deepcopy(data.raw.pipe.pipe)
pipe.name="qc-native-pipe"
pipe.minable=nil
pipe.fluid_box.volume=100
data:extend{generator,pipe,{type="fluid",name="qc-native-fuel",default_temperature=25,
    icon="__base__/graphics/icons/fluid/water.png",icon_size=64,auto_barrel=false,
    max_temperature=100,heat_capacity="1kJ",fuel_value="1MJ",base_color={1,0,0},flow_color={1,0,0}}}

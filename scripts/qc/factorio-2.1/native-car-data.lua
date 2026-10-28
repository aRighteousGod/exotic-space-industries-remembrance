-- Minimal Base-only physics probe: identical car values, no ESIR controller.
local car=data.raw.car.car
car.weight=60000
car.consumption="3.6MW"
car.effectivity=0.85
car.terrain_friction_modifier=0
car.air_resistance=0.002
for name,values in pairs({coal={1,1},["rocket-fuel"]={1.8,1.15},["nuclear-fuel"]={2.5,1.25}}) do
    data.raw.item[name].fuel_acceleration_multiplier=values[1]
    data.raw.item[name].fuel_top_speed_multiplier=values[2]
end
if mods.base=="2.0.77" then
    car.braking_power="2500kW"
    car.friction=0.0008
else
    assert(mods.base=="2.1.23")
    car.braking_force=2500000/60
    car.friction_force=0.0008
end

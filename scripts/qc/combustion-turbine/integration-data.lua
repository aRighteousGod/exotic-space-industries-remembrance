local config=require("__exotic-space-industries-remembrance__/lib/combustion-turbine-config")
local canonical=data.raw["burner-generator"][config.solid]
local recipe=data.raw.recipe[config.recipe]
assert(recipe.energy_required==0.05 and recipe.ingredients[1].amount==1 and recipe.results[1].amount==1)
assert(recipe.ingredients[1].fluidbox_multiplier==199 and recipe.results[1].fluidbox_multiplier==3)
assert(recipe.results[1].temperature==615 and recipe.allow_productivity==false and recipe.allow_quality==false)
assert(recipe.maximum_productivity==0,"Research must not amplify the private energy carrier")
local extraction=data.raw.recipe["ei-oxygen-gas"]
local aligned=false
for _,condition in pairs(extraction.surface_conditions) do
    if condition.property=="pressure" then aligned=condition.min==config.atmospheric_oxygen_min_pressure end
end
assert(aligned,"Oxygen extraction and turbine atmospheric threshold must stay aligned")
for _,name in ipairs({config.oxygen_solid,config.oxygen_fluid}) do
    local machine=data.raw["assembling-machine"][name]
    assert(machine.energy_usage=="12MW" and machine.crafting_speed==1 and machine.module_slots==0)
    assert(machine.fixed_recipe==config.recipe and machine.effect_receiver.uses_surface_effects==false)
    assert(machine.effect_receiver.uses_beacon_effects==false and machine.effect_receiver.uses_module_effects==false)
    assert(machine.quality_affects_energy_usage==false)
    assert(machine.minable.result==config.solid and machine.hidden_in_factoriopedia)
    assert(machine.dying_explosion==canonical.dying_explosion,"Operational variant must inherit combustion death")
    assert(machine.damaged_trigger_effect and machine.open_sound and machine.close_sound,"Operational presentation")
end
assert(data.raw["assembling-machine"][config.oxygen_solid].energy_source.burnt_inventory_size==0)
assert(data.raw["assembling-machine"][config.oxygen_solid].energy_source.fuel_inventory_size==3)
assert(data.raw["assembling-machine"][config.oxygen_solid].energy_source.effectivity==3)
assert(data.raw["assembling-machine"][config.oxygen_fluid].energy_source.effectivity==2.25)
assert(data.raw["assembling-machine"][config.oxygen_fluid].energy_source.fluid_usage_per_tick==1)
local generator=data.raw.generator[config.generator]
assert(generator.dying_explosion==nil and generator.dying_trigger_effect==nil,"Helper is excluded from death effects")
assert(generator.selectable_in_game==false and generator.output_fluid_box.volume==200)
assert(generator.max_power_output=="12MW" and generator.spent_fluid.name=="ei-carbon-dioxide")
for _,entry in ipairs({{"burner-generator",config.ash_solid},{"assembling-machine",config.oxygen_ash_solid}}) do
    local body=data.raw[entry[1]][entry[2]]
    local burner=body.burner or body.energy_source
    assert(burner.burnt_inventory_size==3 and math.abs(burner.effectivity-2.7)<0.0001)
    assert(burner.emissions_per_minute.pollution==108)
    assert(body.dying_explosion==canonical.dying_explosion)
    assert(body.damaged_trigger_effect and body.open_sound and body.close_sound)
    assert(body.hidden_in_factoriopedia and body.minable.result==config.solid)
end
assert(data.raw["assembling-machine"][config.oxygen_ash_solid].crafting_speed==0.9)
assert(data.raw.generator[config.ash_generator].max_power_output=="10.8MW")
assert(data.raw.generator[config.ash_generator].dying_explosion==nil)
data:extend{{
    type="electric-energy-interface", name="esir-turbine-integration-load",
    flags={"placeable-off-grid"}, collision_mask={layers={}},
    collision_box={{-0.4,-0.4},{0.4,0.4}}, selection_box={{-0.4,-0.4},{0.4,0.4}},
    energy_source={type="electric",buffer_capacity="2MJ",usage_priority="primary-input"},
    energy_usage="12MW",energy_production="0W",
    picture={filename="__core__/graphics/empty.png",width=1,height=1},
}}
for _,entry in ipairs({{"esir-turbine-qc-residue-fuel","stone"},{"esir-turbine-qc-clean-fuel"}}) do
    local fuel=table.deepcopy(data.raw.item.coal)
    fuel.name=entry[1]
    fuel.fuel_value="100kJ"
    fuel.burnt_result=entry[2]
    data:extend{fuel}
end

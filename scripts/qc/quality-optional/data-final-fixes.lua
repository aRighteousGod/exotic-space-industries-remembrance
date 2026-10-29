local case = require("case")
local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, "QUALITY OPTIONAL DATA: " .. message)
end
local function contains(values, target)
    for _, value in pairs(values or {}) do if value == target then return true end end
    return false
end
local function permitted(selection, family) return selection == "both" or selection == family end
check((mods.quality ~= nil) == case.quality, "Quality selection")
check(mods["space-age"] and mods.recycler, "Space Age and Recycler retained")
for name, value in pairs({["ei-beacon-quality-modules"]=case.quality_permission,
    ["ei-beacon-productivity-modules"]=case.productivity_permission,["ei-quality-module-effects"]=case.effects}) do
    check(settings.startup[name].value == value, name)
end
local specs = {
    {"ei-copper-beacon", "nitrogen", 4, 6, 0.5, 0.25, "60W", "ei-iron-beacon"},
    {"ei-iron-beacon", "nitrogen", 6, 6, 0.75, 0.5, "120W"},
    {"ei-alien-beacon", "alien", 8, 20, 1, 0.25, "30MW", "ei-warp-beacon"},
    {"ei-warp-beacon", "alien", 10, 64, 2, 0.25, "60MW"},
}
for _, spec in ipairs(specs) do
    local name, family = spec[1], spec[2]
    local beacon = assert(data.raw.beacon[name])
    for _, effect in ipairs({"speed", "consumption", "pollution"}) do
        check(contains(beacon.allowed_effects, effect), name .. "/" .. effect)
    end
    check(contains(beacon.allowed_effects, "quality") == permitted(case.quality_permission, family), name .. "/quality")
    check(contains(beacon.allowed_effects, "productivity") == permitted(case.productivity_permission, family), name .. "/productivity")
    check(beacon.module_slots == spec[3] and beacon.supply_area_distance == spec[4], name .. "/slots-range")
    check(beacon.distribution_effectivity == spec[5] and beacon.distribution_effectivity_bonus_per_quality_level == spec[6], name .. "/effectivity")
    check(beacon.energy_usage == spec[7] and beacon.next_upgrade == spec[8], name .. "/energy-upgrade")
    check(beacon.energy_source.type == "void", name .. "/NSBC-body")
    local deaths = {"ei-death-explosion-signal-medium","ei-death-explosion-quantum-medium",
        "ei-death-explosion-alien-large","ei-death-explosion-alien-large"}
    check(beacon.dying_explosion == deaths[_] and data.raw.explosion[beacon.dying_explosion]
        and beacon.damaged_trigger_effect and beacon.open_sound and beacon.close_sound
        and beacon.factoriopedia_simulation, name .. "/presentation")
    check(beacon.localised_description ~= nil and data.raw.item[name].localised_description ~= nil, name .. "/descriptions")
    local source = assert(data.raw["assembling-machine"][name .. "-source"])
    check(source.module_slots == 0 and source.hidden and source.hidden_in_factoriopedia, name .. "/helper-ownership")
    check(source.quality_affects_energy_usage == true and source.fixed_recipe == "nsb-filler-recipe", name .. "/helper-native-quality")
    for _, flag in ipairs({"uses_beacon_effects", "uses_module_effects", "uses_surface_effects"}) do
        check(source.effect_receiver[flag] == false, name .. "/helper-" .. flag)
    end
    if family == "nitrogen" then
        local energy = source.energy_source
        check(energy.type == "fluid" and energy.fluid_box.volume == 100 and energy.fluid_box.filter == "ei-liquid-nitrogen", name .. "/nitrogen")
        check(energy.burns_fluid and energy.scale_fluid_usage and energy.effectivity == 1, name .. "/nitrogen-consumption")
    else
        check(source.energy_source.type == "burner" and source.energy_source.fuel_inventory_size == 1
            and contains(source.energy_source.fuel_categories, "ei-bio-matter"), name .. "/bio-matter")
    end
end
for tier = 1, 3 do
    local name = "quality-module" .. (tier == 1 and "" or "-" .. tier)
    local module = data.raw.module[name]
    check((module ~= nil) == case.quality, name .. "/availability")
    if module then
        local effect = module.effect
        local expected = case.effects == "esir"
            and {quality=({0.03,0.045,0.06})[tier],speed=-0.3*tier,consumption=tier,productivity=-0.25*tier}
            or {quality=({0.01,0.02,0.025})[tier],speed=-0.05}
        if case.upstream_sentinel and case.effects=="vanilla" and tier==1 then
            expected.quality=0.01234;expected.pollution=0.123
        end
        for key, amount in pairs(expected) do check(math.abs((effect[key] or 0)-amount)<1e-9, name .. "/" .. key) end
        for key in pairs(effect) do check(expected[key] ~= nil, name .. "/unexpected-effect-" .. key) end
        check(data.raw.recipe[name] and data.raw.technology[name], name .. "/recipe-technology")
        check(module.category == "quality" and module.tier == tier and module.stack_size == 50, name .. "/module-identity")
        log("QUALITY_OPTIONAL_PROGRESSION " .. name .. " " .. serpent.line({
            recipe=data.raw.recipe[name],technology=data.raw.technology[name]}, {comment=false,sortkeys=true}))
    end
end
-- Private runtime actors are added after all production compatibility passes.
local receiver = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
receiver.name = "esir-qc-quality-receiver"
receiver.minable = nil
receiver.next_upgrade = nil
receiver.energy_source = {type="void"}
receiver.effect_receiver = {base_effect={quality=0.1,productivity=1},uses_beacon_effects=true,uses_module_effects=true}
receiver.allowed_effects = {"quality","productivity","speed","consumption","pollution"}
receiver.crafting_categories = {"esir-qc-quality-crafting"}
receiver.fixed_recipe = "esir-qc-quality-craft"
data:extend({receiver,{type="recipe-category",name="esir-qc-quality-crafting"},
    {type="recipe",name="esir-qc-quality-craft",categories={"esir-qc-quality-crafting"},enabled=true,
        ingredients={},results={{type="item",name="iron-plate",amount=1}},energy_required=10,
        allow_quality=true,allow_productivity=true},
    {type="module",name="esir-qc-mixed-module",icon="__base__/graphics/icons/productivity-module.png",
        icon_size=64,subgroup="module",category="productivity",tier=1,stack_size=50,
        effect={quality=0.02,productivity=0.02}},
})
log("QUALITY_OPTIONAL_DATA_PASSED " .. checks)
local target=table.deepcopy(data.raw.unit["behemoth-biter"])
target.name="esir-qc-quality-target"
target.max_health=1000000;target.resistances={};target.healing_per_tick=0
target.movement_speed=0;target.vision_distance=0;target.attack_parameters.range=0
target.collision_box={{-0.2,-0.2},{0.2,0.2}}
data:extend({target})

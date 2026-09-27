local config = require("test-config")
if not config.baseline then
    local fire=data.raw.fire["ei-singularity-lance-hit-fire"]
    local sticker=data.raw.sticker["ei-singularity-lance-fire-sticker"]
    assert(fire.damage_per_tick.amount==0 and not fire.on_damage_tick_effect,"lance fire is not cosmetic")
    assert(sticker.damage_per_tick.amount==0 and sticker.target_movement_modifier==1
        and sticker.vehicle_speed_modifier==1 and sticker.vehicle_friction_modifier==1,"lance sticker is not cosmetic")
    local keys={"axial-rupture","wound-memory","terminal-collapse","black-hole-testament"}
    local counts={7,8,9,10}
    for i,key in ipairs(keys) do
        local name="ei-singularity-lance-"..key
        local tech=data.raw.technology[name]
        local packs={}
        for _,p in ipairs(tech.unit.ingredients) do packs[#packs+1]=p.name or p[1] end
        table.sort(packs)
        assert(#packs==counts[i],name.." wrong pack count")
        if i>=3 then for _,p in ipairs(packs) do assert(p~="space-science-pack",name.." incorrectly inherits Space") end end
        if config.no_scaling then assert(tech.unit.count==100*counts[i],name.." bypassed existing no-scaling normalization") end
        log("LANCE_TECH name="..name.." count="..tostring(tech.unit.count).." time="..tech.unit.time
            .." packs="..table.concat(packs,",").." prerequisites="..table.concat(tech.prerequisites,","))
    end
end
local target = table.deepcopy(data.raw["ammo-turret"]["gun-turret"])
target.name, target.max_health, target.healing_per_tick = "lance-qc-target", 10000000, 0
target.collision_box = {{-0.25,-0.25},{0.25,0.25}}
target.selection_box = target.collision_box
target.collision_mask = {layers = {}}
target.resistances = {}
target.minable = nil
target.attack_parameters.range = 1
data:extend({target})
local resistant = table.deepcopy(target)
resistant.name, resistant.resistances = "lance-qc-resistant", {{type="laser",decrease=100,percent=0}}
local immune = table.deepcopy(target)
immune.name, immune.resistances = "lance-qc-immune", {{type="laser",percent=100}}
local large = table.deepcopy(data.raw.car.car)
large.name, large.max_health, large.resistances = "lance-qc-large", 10000000, {}
large.collision_box, large.collision_mask = {{-0.5,-4},{0.5,4}}, {layers={}}
large.selection_box = table.deepcopy(large.collision_box)
large.is_military_target = true
data:extend({resistant,immune,large})
local power = table.deepcopy(data.raw["electric-energy-interface"]["electric-energy-interface"])
power.name, power.energy_production, power.energy_usage = "lance-qc-power", "100GW", "0W"
power.energy_source.buffer_capacity, power.energy_source.output_flow_limit = "100GJ", "100GW"
local pole = table.deepcopy(data.raw["electric-pole"].substation)
pole.name, pole.supply_area_distance = "lance-qc-pole", 64
data:extend({power,pole})
for _, pair in ipairs({{"unit","behemoth-biter"},{"turret","behemoth-worm-turret"},{"unit-spawner","biter-spawner"}}) do
    local visual = table.deepcopy(data.raw[pair[1]][pair[2]])
    visual.name, visual.max_health = "lance-qc-"..pair[2], 10000000
    visual.resistances = {}
    data:extend({visual})
end
if config.mode == "benchmark" and config.scene ~= "normal-power" then
    -- Explicit artificial firing stress, separate from shipped-power results.
    local turret = data.raw["electric-turret"]["ei-singularity-lance"]
    turret.attack_parameters.ammo_type.energy_consumption = "1J"
    turret.energy_source.buffer_capacity, turret.energy_source.input_flow_limit = "1GJ", "1GW"
    turret.energy_source.drain = "0W"
end

local config = require("test-config")
local catalog = require("__exotic-space-industries-remembrance__/lib/flamethrower-fuels")
local factor = config.profile == "original" and 1 or tonumber(config.profile:match("%d+"))
local before = assert(esir_thrower_qc_before, "Missing pre-pass snapshot")
local checks = assert(esir_thrower_qc_isolation_checks, "Missing immediate isolation assertions")
local function equal(a,b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local function check(value, label)
    checks = checks + 1
    assert(value, "THROWER_QC_DATA " .. label)
end
local allowed = {[catalog.base_turret]=true, ["ei-acidthrower-turret"]=true}
for _,fuel in ipairs(catalog.fuels) do
    allowed[fuel.turret] = true
end
local seen = {}
local function effects(old,new)
    for key,value in pairs(old) do
        if type(value) == "table" then effects(value,new[key]) end
    end
    if old.type == "damage" then check(math.abs(new.damage.amount-old.damage.amount*factor)<1e-8,"impact") end
    if old.type == "create-sticker" then
        local a,b = before.sticker[old.sticker],data.raw.sticker[new.sticker]
        local interval = factor == 1 and (a.damage_interval or 1) or math.min((a.damage_interval or 1)*factor,30)
        check((b.damage_interval or 1)==interval,"sticker cadence")
        check(math.abs(b.damage_per_tick.amount/interval-a.damage_per_tick.amount/(a.damage_interval or 1))<1e-8,"sticker dps")
        check(b.duration_in_ticks==a.duration_in_ticks and b.target_movement_modifier==a.target_movement_modifier,"sticker duration/slow")
    elseif old.type == "create-fire" then
        local a,b = before.fire[old.entity_name],data.raw.fire[new.entity_name]
        for _,field in ipairs{"damage_per_tick","initial_lifetime","maximum_lifetime","lifetime_increase_by","lifetime_increase_cooldown","add_fuel_cooldown","damage_multiplier_increase_per_added_fuel","damage_multiplier_decrease_per_tick","maximum_damage_multiplier","spawn_entity"} do
            check(equal(a[field],b[field]),"ground fire "..field)
        end
    end
end
for name in pairs(allowed) do
    local a,b = before["fluid-turret"][name].attack_parameters,data.raw["fluid-turret"][name].attack_parameters
    check(b.cooldown==a.cooldown*factor,"cooldown "..name)
    check(b.fluid_consumption==a.fluid_consumption*factor,"consumption "..name)
    for _,field in ipairs{"damage_modifier","range","min_range","fluids","lead_target_for_projectile_speed"} do check(equal(a[field],b[field]),"attack "..field) end
    local old_name,new_name = a.ammo_type.action.action_delivery.stream,b.ammo_type.action.action_delivery.stream
    local old,new = before.stream[old_name],data.raw.stream[new_name]
    check(new.particle_spawn_interval==old.particle_spawn_interval*factor,"stream cadence")
    check(new.particle_buffer_size==old.particle_buffer_size,"buffer")
    check(new.particle_horizontal_speed==old.particle_horizontal_speed,"flight")
    local original_timeout=old.particle_spawn_timeout or 4*old.particle_spawn_interval
    local expected_timeout=factor==1 and original_timeout or math.max(original_timeout,b.cooldown+new.particle_spawn_interval)
    check((new.particle_spawn_timeout or 4*new.particle_spawn_interval)==expected_timeout,"stream timeout")
    if not seen[new_name] then effects(old.action,new.action);seen[new_name]=true end
end
log("THROWER_QC_DATA all_pass=true checks="..checks.." profile="..config.profile)

-- Isolate direct, sticker, and ground damage using native copies of the actual
-- final turret/stream graph. Combined tests use the unmodified final graph.
local function filter(node, component)
    if node.type=="damage" and component~="direct"
        or node.type=="create-sticker" and component~="sticker"
        or node.type=="create-fire" and component~="ground" then return nil end
    local result = {}
    for key,value in pairs(node) do
        if type(value)=="table" then
            local child=filter(value,component)
            if not child and (key=="target_effects" or key=="action_delivery") then return nil end
            if type(key)=="number" then
                if child then result[#result+1]=child end
            else result[key]=child end
        else result[key]=value end
    end
    return next(result) and result or nil
end
for name in pairs(allowed) do
    for _,component in ipairs{"direct","sticker","ground","combined"} do
        local turret = table.deepcopy(data.raw["fluid-turret"][name])
        turret.name = "esir-thrower-qc-"..component.."-"..name
        turret.minable = nil
        turret.placeable_by = nil
        local stream = table.deepcopy(data.raw.stream[turret.attack_parameters.ammo_type.action.action_delivery.stream])
        stream.name = turret.name.."-stream"
        if component~="combined" then stream.action=filter(stream.action,component) end
        turret.attack_parameters.ammo_type.action.action_delivery.stream=stream.name
        data:extend{turret,stream}
    end
end
esir_thrower_qc_before = nil

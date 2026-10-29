-- Runs the real raised-build dispatcher and actual NSBC admission/transmission.
local case = require("case")
local model = {}
local function check(value, message)
    storage.checks = (storage.checks or 0) + 1
    assert(value, "QUALITY OPTIONAL NATIVE: " .. message)
end
local function permits(selection, family) return selection == "both" or selection == family end
local function source(entity)
    local record = remote.call("nonstandard-beacons", "get-beacon-data", entity.unit_number)
    check(record and record.source.valid and record.manager.valid, "NSBC custody " .. entity.name)
    return record.source
end
local function fill(entity)
    local power = source(entity)
    if power.burner then power.get_fuel_inventory().insert{name="ei-bio-matter",count=50}
    else power.set_fluid(1,{name="ei-liquid-nitrogen",amount=100,temperature=25}) end
end
local function amount(effects, key)
    local value = effects[key]
    return type(value) == "table" and value.bonus or value or 0
end
local function same(actual, expected, label, tolerance)
    check(math.abs(actual-expected)<(tolerance or 0.000001), label .. ": " .. actual .. " expected " .. expected)
end
local function upgrade(row, name)
    local body=row.beacon
    body.get_module_inventory().clear()
    body.get_module_inventory().insert{name="speed-module",count=1}
    local old=remote.call("nonstandard-beacons","get-beacon-data",body.unit_number)
    local energy=old.source.energy+(old.energy_reserve or 0)
    local buffer=game.create_inventory(4)
    check(body.order_upgrade{target={name=name,quality="normal"},force=body.force},"native upgrade order")
    local successor=body.apply_upgrade(nil,buffer)
    check(successor and successor.valid and not body.valid,"native replacement "..name)
    local current=remote.call("nonstandard-beacons","get-beacon-data",successor.unit_number)
    check(current and current.source.valid and current.manager.valid,"replacement helper custody")
    same(current.source.energy+(current.energy_reserve or 0),energy,"replacement stored energy")
    check(successor.get_module_inventory().get_item_count("speed-module")+buffer.get_item_count("speed-module")==1,
        "replacement module conservation")
    row.beacon=successor
    buffer.destroy()
end
local function start_round(index)
    storage.round = index
    local name = storage.modules[index]
    if not name then return false end
    local effect = prototypes.item[name].module_effects
    for _, row in ipairs(storage.beacons) do
        local inventory = row.beacon.get_module_inventory()
        inventory.clear()
        local allowed = (permits(case.quality_permission,row.family) or (effect.quality or 0)<=0)
            and (permits(case.productivity_permission,row.family) or (effect.productivity or 0)<=0)
        local stack = {name=name,count=1}
        check(inventory.can_insert(stack)==allowed, row.beacon.name .. "/" .. name .. "/can-insert")
        check(inventory.insert(stack)==(allowed and 1 or 0), row.beacon.name .. "/" .. name .. "/insert")
        row.accepted = allowed
        fill(row.beacon)
    end
    return true
end
local function finish_round()
    local name = storage.modules[storage.round]
    for _, row in ipairs(storage.beacons) do
        local beacon, receiver = row.beacon, row.receiver
        local power=source(beacon)
        check(not beacon.disabled_by_script, beacon.name .. "/powered: "..serpent.line{
            status=power.status,energy=power.energy,fuel=power.burner and power.get_fuel_inventory().get_contents(),
            remainder=power.burner and power.burner.remaining_burning_fuel})
        -- Compare native body emission to receiver effects, preserving penalties.
        for _, key in ipairs({"quality","productivity","speed","consumption","pollution"}) do
            local base = key=="quality" and 0.1 or key=="productivity" and 1 or 0
            local emitted = amount(beacon.effects,key)*beacon.prototype.distribution_effectivity
            local transmitted = amount(receiver.effects,key)-base
            local limits=receiver.prototype.effect_receiver[key.."_limits"]
            emitted=math.max(limits.low,math.min(limits.high,base+emitted))-base
            -- Native effect transmission quantizes the bonus to 1/10000.
            same(transmitted,emitted,beacon.name .. "/" .. name .. "/" .. key,0.00010001)
        end
        storage.results[#storage.results+1]={beacon=beacon.name,module=name,accepted=row.accepted,
            emitted=beacon.effects,received=receiver.effects}
    end
end
local function setup()
    storage.checks=0;storage.results={};storage.beacons={}
    local surface=game.create_surface("quality-policy-native",{width=1024,height=128})
    for i=1,4 do surface.request_to_generate_chunks({(i-2.5)*200,0},1) end
    surface.force_generate_chunk_requests()
    for _,entity in pairs(surface.find_entities()) do entity.destroy() end
    storage.surface=surface
    for index,name in ipairs({"ei-copper-beacon","ei-iron-beacon","ei-alien-beacon","ei-warp-beacon"}) do
        local x=(index-2.5)*200
        local beacon=assert(surface.create_entity{name=name,position={x,0},force="player",raise_built=true})
        local receiver=assert(surface.create_entity{name="esir-qc-quality-receiver",position={x+6,0},force="player",raise_built=true})
        storage.beacons[index]={beacon=beacon,receiver=receiver,family=index<=2 and "nitrogen" or "alien"}
        fill(beacon)
    end
    local pump=assert(surface.create_entity{name="rp-steam-pump",position={0,30},force="player",raise_built=true})
    storage.pump=pump
    local fluid=pump.get_fluid(2)
    check(pump.quality.name=="normal" and pump.quality.level==0,"native normal entity")
    check(fluid and fluid.name=="steam" and fluid.amount==3 and fluid.temperature==165,"production pump priming storage 2")
    storage.pump_initial=fluid
    local player=game.get_player(1)
    storage.identifier_shapes={}
    if player then
        local picker=player.gui.screen.add{type="choose-elem-button",elem_type="item-with-quality",
            ["item-with-quality"]={name="iron-plate",quality="normal"}}
        local value=picker.elem_value
        storage.identifier_shapes.picker_name=type(value.name)
        storage.identifier_shapes.picker_quality=type(value.quality)
        picker.destroy()
    else storage.identifier_shapes.picker="requires native client; covered by transition suite" end
    for y=-18,-2,2 do surface.create_entity{name="straight-rail",position={0,y},force="player",direction=defines.direction.north} end
    local wagon=assert(surface.create_entity{name="cargo-wagon",position={0,-10},force="player",raise_built=true})
    local inventory=wagon.get_inventory(defines.inventory.cargo_wagon)
    inventory.set_filter(1,{name="iron-plate",quality="normal"})
    local filter=inventory.get_filter(1)
    storage.identifier_shapes.filter_name=type(filter.name)
    storage.identifier_shapes.filter_quality=type(filter.quality)
    check(inventory.insert{name="iron-plate",count=1,quality="normal"}==1,"native normal item")
    check(inventory[1].quality.level==0,"native normal stack level")
    wagon.destroy{raise_destroy=true}
    storage.modules={"speed-module","efficiency-module","productivity-module","esir-qc-mixed-module"}
    if case.quality then
        for _,name in ipairs({"quality-module","quality-module-2","quality-module-3"}) do
            storage.modules[#storage.modules+1]=name
        end
    end
    start_round(1)
end
function model.tick(event)
    local age=event.tick-storage.started
    if age==1 then setup() end
    if storage.beacons and not storage.done then
        for _,row in ipairs(storage.beacons) do fill(row.beacon) end
    end
    if age>1 and age%30==0 and not storage.done then
        finish_round()
        if not start_round(storage.round+1) then
            local fluid=storage.pump.get_fluid(2)
            check(storage.pump.energy>0 and fluid and fluid.amount<3,"primed pump consumes steam")
            upgrade(storage.beacons[1],"ei-iron-beacon")
            upgrade(storage.beacons[3],"ei-warp-beacon")
            local report={passed=true,case=case,checks=storage.checks,rows=storage.results,
                identifier_shapes=storage.identifier_shapes,pump_initial=storage.pump_initial,
                pump_after=fluid,pump_energy=storage.pump.energy,
                skipped=case.quality and {} or {"Quality module tiers absent; explicitly skipped"}}
            helpers.write_file("quality-optional-native.json",helpers.table_to_json(report),false)
            storage.done=true
        end
    end
end
return model

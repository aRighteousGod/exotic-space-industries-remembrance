-- Deterministic persistent fixture state: client joining/rejoining must not take
-- a different simulation path because an unsaved local flag was initialized.
local function check(value,label)
    assert(value,"ESIR MULTIPLAYER QC: "..label)
    storage.checks[#storage.checks+1]=label
end
local function beacon(entity)
    return remote.call("nonstandard-beacons","get-beacon-data",entity.unit_number)
end
local function snapshot()
    local result={beacons={},fusion=remote.call("esir-fusion-qc","record",storage.reactor),
        chest=storage.chest.get_inventory(defines.inventory.chest).get_contents()}
    local fusion=result.fusion
    fusion.wire_proxy={unit=fusion.wire_proxy.unit_number,name=fusion.wire_proxy.name}
    for _,entity in ipairs(storage.beacons) do
        local entry=beacon(entity)
        check(entry and entry.source.valid and entry.manager.valid,"beacon helpers valid")
        result.beacons[#result.beacons+1]={unit=entity.unit_number,name=entity.name,quality=entity.quality.name,
            modules=entity.get_module_inventory().get_contents(),source=entry.source.unit_number,
            manager=entry.manager.unit_number,direction=entry.source.direction,mirroring=entry.source.mirroring}
    end
    return result
end
local function write(name,report)
    local text=helpers.table_to_json(report)
    helpers.write_file(name,text,false)
    helpers.write_file(name,text,false,storage.player)
end
script.on_init(function()
    if remote.interfaces.freeplay then remote.call("freeplay","set_skip_intro",true) end
    storage.checks={};storage.joins=0;storage.leaves=0
    local surface=game.create_surface("multiplayer-upgrade-qc",{width=128,height=128,
        autoplace_settings={entity={treat_missing_as_default=false,settings={}}}})
    surface.request_to_generate_chunks({0,0},3);surface.force_generate_chunk_requests()
    for _,entity in pairs(surface.find_entities()) do entity.destroy() end
    surface.always_day=true;storage.surface=surface
    storage.reactor=surface.create_entity{name="ei-fusion-reactor",position={0,0},force="player",quality="rare",raise_built=true}
    storage.reactor.disabled_by_script=true
    remote.call("esir-fusion-qc","select",storage.reactor,
        {fuel_1="ei-heated-deuterium",fuel_2="ei-heated-tritium",temperature="low",injection_rate="high"},"circuit",game.tick)
    storage.chest=surface.create_entity{name="steel-chest",position={0,10},force="player",quality="rare",raise_built=true}
    storage.chest.get_inventory(defines.inventory.chest).insert{name="iron-plate",count=137,quality="rare"}
    storage.beacons={}
    for index,name in ipairs{"ei-copper-beacon","ei-alien-beacon"} do
        local entity=surface.create_entity{name=name,position={index*12,0},force="player",quality="rare",raise_built=true}
        entity.get_module_inventory().insert{name="speed-module",count=2,quality="rare"}
        storage.beacons[index]=entity
    end
end)
script.on_event(defines.events.on_player_joined_game,function(event)
    local player=game.get_player(event.player_index)
    check(game.is_multiplayer(),"real multiplayer session")
    storage.joins=storage.joins+1
    if storage.joins==1 then
        storage.player=player.index
        player.teleport({0,8},storage.surface)
        remote.call("esir-fusion-qc","preference",player.index,"ei-ecology-alert-restoration",false)
    else
        check(player.index==storage.player,"rejoin retains player identity")
        check(storage.leaves>=1,"server observed disconnect")
        check(player.mod_settings["ei-ecology-alert-restoration"].value==false,"personal Off survives rejoin")
    end
    remote.call("esir-fusion-qc","gui",player.index,"open",storage.reactor,event.tick)
    storage.deadline=event.tick+600
end)
script.on_event(defines.events.on_player_left_game,function(event)
    if event.player_index==storage.player then
        storage.leaves=storage.leaves+1
        write("multiplayer-left.json",{passed=true,joins=storage.joins,leaves=storage.leaves,tick=event.tick})
    end
end)
script.on_event(defines.events.on_tick,function(event)
    if not storage.deadline or event.tick<storage.deadline then return end
    storage.deadline=nil
    local player=game.get_player(storage.player)
    check(player.connected and #game.connected_players==1,"one actual connected peer")
    check(remote.call("esir-fusion-qc","gui",storage.player,"inspect",nil,event.tick).valid,"fusion console owned after join")
    local value=snapshot()
    if storage.joins==1 then storage.baseline=value
    else check(serpent.line(value,{sortkeys=true,comment=false})==serpent.line(storage.baseline,{sortkeys=true,comment=false}),
        "beacon helpers modules orientation fusion controls and inventory survive rejoin") end
    local owned,names={},{}
    for _,entity in ipairs(storage.beacons) do
        local record=beacon(entity)
        for _,helper in ipairs{record.source,record.manager} do owned[helper.unit_number]=true;names[helper.name]=true end
    end
    for name in pairs(names) do
        for _,helper in pairs(storage.surface.find_entities_filtered{name=name}) do
            check(owned[helper.unit_number],"no unowned beacon helper")
        end
    end
    write("multiplayer-phase-"..storage.joins..".json",{passed=true,engine=script.active_mods.base,
        joins=storage.joins,leaves=storage.leaves,tick=event.tick,checks=storage.checks,state=value,
        connected_ticks=600,player=storage.player,controller=player.controller_type})
    if storage.joins==2 then game.auto_save("multiplayer-accepted") end
end)

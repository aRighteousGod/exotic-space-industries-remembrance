local mod = "even-pickier-dollies"
local neighborhoods=require("neighborhoods")
script.on_init(function()
    if remote.interfaces.freeplay then remote.call("freeplay", "set_skip_intro", true) end
end)
script.on_configuration_changed(function(e)
    local change = e.mod_changes[mod]
    if change and not change.old_version then storage.installed = true end
end)
local function verify(player)
    assert(storage.installed and script.active_mods[mod] == "3.2.0")
    assert(settings.startup["dolly-transporter-mode"].value)
    local s = player.surface
    local function make(name, x, y, ghost, direction)
        return assert(s.create_entity{name=ghost and "entity-ghost" or name, inner_name=ghost and name or nil,
            position={x,y}, direction=direction, force=player.force, raise_built=true}, name)
    end
    local function press(entity, key)
        player.clear_cursor()
        player.selected = entity
        assert(player.selected == entity, "selection: "..entity.name)
        remote.call("esir-dollies-input","press","dolly-move-"..key,player.index)
    end
    local function step(entity, key, delta)
        local x = entity.position.x
        local name = entity.name
        press(entity,key)
        assert(entity.valid and entity.position.x == x+delta, name.." move "..key.." expected "..(x+delta))
    end
    local tiles={}
    for x=-48,64 do for y=-20,32 do tiles[#tiles+1]={position={x,y},name="landfill"} end end
    s.set_tiles(tiles)
    for _,e in pairs(s.find_entities_filtered{area={{-48,-20},{64,32}},type={"tree","simple-entity","cliff","resource"}}) do e.destroy() end
    local function approach(x,y) assert(player.teleport({x,y},s)) end
    approach(31,5)
    local receiver = make("ei-gate-receiver",31.5,0.5)
    local sender = make("ei-gate-container",12.5,0.5)
    remote.call("esir-dollies-state","bind",sender,receiver)
    receiver.insert{name="iron-plate",count=7}
    step(receiver,"east",1); step(receiver,"west",-1); step(receiver,"east",1)
    assert(receiver.get_item_count("iron-plate")==7)
    assert(remote.call("esir-dollies-state","destination",sender).x==receiver.position.x)
    storage.receiver=receiver
    storage.sender=sender
    approach(-8,5)
    local ghost=make("ei-sweeping-radar",-8.5,0.5,true)
    local art=assert(s.find_entity("ei-sweeping-radar-visual-ghost",ghost.position))
    step(ghost,"east",1)
    assert(art.valid and art.position.x==ghost.position.x)
    local _,radar=ghost.revive{raise_revive=true}
    assert(radar and radar.valid)
    approach(2,19)
    local railgun=make("railgun-turret",2,14)
    local coolant=assert(s.find_entities_filtered{name="ei-railgun-cooling-proxy",position=railgun.position,radius=3}[1])
    coolant.set_fluid(1,{name="fluoroketone-cold",amount=7,temperature=-150})
    coolant.set_fluid(2,{name="fluoroketone-hot",amount=6,temperature=180})
    remote.call("esir-dollies-state","heat",railgun,12)
    local x=coolant.position.x
    step(railgun,"east",1)
    assert(coolant.valid and coolant.position.x==x+1)
    assert(math.abs(coolant.get_fluid(1).amount-7)<0.001 and math.abs(coolant.get_fluid(2).amount-6)<0.001)
    assert(coolant.get_fluid(1).temperature==-150 and coolant.get_fluid(2).temperature==180)
    assert(remote.call("esir-dollies-state","heat",railgun)==12)
    local protected=prototypes.mod_data[mod].data.blacklist_names
    local names={"ei-gate-container","ei-gate","ei-auric-inoculation-vat","ei-induction-matrix-core-circuit-interface",
        "ei-induction-matrix-basic-coil","ei-induction-matrix-basic-solenoid","ei-induction-matrix-basic-converter",
        "ei-steam-loader","ei-loader","ei-fast-loader","ei-express-loader","ei-turbo-loader","ei-neo-loader"}
    for i=0,16 do names[#names+1]="ei-induction-matrix-core-"..i end
    if prototypes.entity["ei-military-loader"] then names[#names+1]="ei-military-loader" end
    for _,name in ipairs(names) do assert(protected[name],name) end
    approach(20,20)
    player.cheat_mode=true
    step(sender,"east",0)
    for _,name in ipairs(names) do
        local ok,g=pcall(make,name,40,22,true)
        if ok then
            player.selected=g
            if player.selected==g then step(g,"east",0) end
            g.destroy()
        else
            assert(tostring(g):find("can not be part a entity ghost",1,true),g)
        end
    end
    local loader=make("ei-steam-loader",21.5,14.5)
    loader.set_fluid(1,{name="steam",amount=31,temperature=165})
    step(loader,"east",0)
    assert(loader.get_fluid(1).amount==31)
    player.cheat_mode=false
    local belt=make("transport-belt",21.5,16.5,false,defines.direction.north)
    local at=belt.position
    press(belt,"north")
    assert(not belt.valid and s.find_entity("transport-belt",{at.x,at.y-1}),"transporter replacement")
    local chest=make("steel-chest",19.5,20.5)
    make("steel-chest",20.5,20.5)
    step(chest,"east",0)
    neighborhoods(player,s,make,step,approach)
end
script.on_event(defines.events.on_tick,function(e)
    local player=game.get_player(1)
    if not player then return end
    local phase=script.test_arg or (script.active_mods[mod] and "installed" or "absent")
    if storage.phase==phase then return end
    if phase=="installed" then verify(player)
    elseif phase=="reload" then
        assert(storage.phase=="installed" and storage.receiver.valid and storage.receiver.get_item_count("iron-plate")==7)
        assert(remote.call("esir-dollies-state","destination",storage.sender).x==storage.receiver.position.x)
    else assert(phase=="absent" and not script.active_mods[mod]) end
    storage.phase=phase
    helpers.write_file("dollies-"..phase..".json",helpers.table_to_json({passed=true,phase=phase,tick=e.tick}),false)
    if script.test_arg then script.finish_test(true) else game.auto_save("dollies-"..phase) end
end)

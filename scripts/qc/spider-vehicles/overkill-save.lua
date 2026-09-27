-- Save a live automatic hold with a lost projectile, then reload its original
-- expiry bucket. This deliberately keeps the same startup settings/mod set.
local catalog=require("__exotic-space-industries-remembrance__/lib/spider-vehicles")
local api="exotic-industries-spider-vehicles"
local qc="esir-spider-qc-controls"
local loaded,finished=false,false
local function check(name,value)
    storage.checks[#storage.checks+1]={name=name,pass=value==true}
end
local function controls() return remote.call(api,"get_weapon_controls",storage.vehicle) end
local function report(phase)
    local all=true
    for _,entry in ipairs(storage.checks) do all=all and entry.pass end
    helpers.write_file("spider-vehicles-qc.json",helpers.table_to_json({all_pass=all,checks=storage.checks,
        status=remote.call(api,"get_status"),phase=phase}),false)
    finished=true
    game.server_save("spider-overkill-smart")
end
script.on_load(function() loaded=true end)
script.on_init(function()
    storage.checks={};storage.shots=0
    local force=game.create_force("esir-overkill-save")
    local surface=game.create_surface("esir-overkill-save",{width=128,height=128,autoplace_controls={},
        autoplace_settings={entity={treat_missing_as_default=false,settings={}}}})
    surface.request_to_generate_chunks({0,0},2);surface.force_generate_chunk_requests()
    local tiles={}
    for x=-5,60 do for y=-5,5 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
    surface.set_tiles(tiles)
    storage.vehicle=surface.create_entity{name=catalog.configured_name("rocket",catalog.researched_state(force),{cycling=true,special=true},true),position={0,0},force=force}
    storage.vehicle.get_inventory(defines.inventory.spider_ammo)[1].set_stack{name="rocket",count=100}
    storage.vehicle.vehicle_automatic_targeting_parameters={auto_target_with_gunner=false,auto_target_without_gunner=true}
    remote.call(api,"set_weapon_controls",storage.vehicle,{overkill=true})
    storage.id=controls().vehicle_id
    storage.target=surface.create_entity{name="esir-spider-qc-target",position={30,0},force="enemy"}
    storage.target.active=false;storage.target.health=500
end)
script.on_event(defines.events.on_script_trigger_effect,function(event)
    if event.effect_id~=catalog.overkill.launch.."rocket" or event.source_entity~=storage.vehicle then return end
    storage.shots=storage.shots+1;storage.first_shot=storage.first_shot or event.tick
    storage.last_shot=event.tick
    for _,entity in ipairs(storage.vehicle.surface.find_entities_filtered{type="projectile",position=storage.vehicle.position,radius=8}) do entity.destroy() end
end)
script.on_event(defines.events.on_tick,function(event)
    if finished or not storage.first_shot then return end
    if loaded and not storage.checked_reload then
        storage.checked_reload=true
        local current=controls()
        local snapshot=remote.call(qc,"snapshot",storage.vehicle)
        check("live-save-identity-preference",current.vehicle_id==storage.id and current.overkill and current.effective_overkill)
        check("live-save-hold-and-reservation",current.holding_fire and snapshot.overkill and #snapshot.overkill.shots==1)
        check("live-save-native-suppression",not storage.vehicle.vehicle_automatic_targeting_parameters.auto_target_without_gunner)
    end
    local age=event.tick-storage.first_shot
    if not loaded and age==70 then
        check("live-save-initial-hold",controls().holding_fire and storage.shots==1)
        report("overkill-save-initial")
    elseif loaded and age==290 then
        check("live-save-no-early-expiry",storage.shots==1 and controls().holding_fire)
    elseif loaded and age>=330 then
        check("live-save-original-expiry-resumes",storage.shots==2 and storage.last_shot-storage.first_shot>=300 and storage.last_shot-storage.first_shot<=320)
        remote.call(api,"set_weapon_controls",storage.vehicle,{overkill=false})
        local targeting=storage.vehicle.vehicle_automatic_targeting_parameters
        check("live-save-restores-requested-targeting",not controls().holding_fire and not targeting.auto_target_with_gunner and targeting.auto_target_without_gunner)
        report("overkill-save-reloaded")
    end
end)

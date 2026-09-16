-- Focused engine fixture; stage only in an isolated QC mod directory.
local config=require("test-config")
if (config.performance or 0)>0 then require("performance");return end
if config.save_fixture then require("save-controls");return end
local catalog=require("__exotic-space-industries-remembrance__/lib/spider-vehicles")
local interface="exotic-industries-spider-vehicles"
local combat=require("combat")
local weapon_controls=require("weapon-controls")
local robot_controls=require("robot-controls")
local function expected(family,force)
    return catalog.configured_name(family,catalog.researched_state(force),{cycling=true,special=true},settings.startup["ei-spider-range-aware-cycling"].value)
end
local function check(name,condition,detail)
    storage.checks=storage.checks or {}
    storage.checks[#storage.checks+1]={name=name,pass=condition==true,detail=detail}
    log("SPIDER_QC "..name.."="..tostring(condition).." "..tostring(detail or ""))
end
local function inventory_state(inv)
    if not inv then return {} end
    local result={}
    if inv.supports_bar() and inv.get_bar()<=#inv then result.bar=inv.get_bar() end
    for index=1,#inv do
        local stack=inv[index]
        if stack.valid_for_read then
            result[index]={name=stack.name,count=stack.count,quality=stack.quality.name}
            if stack.type=="ammo" then result[index].ammo=stack.ammo end
        end
        if inv.supports_filters() and inv.get_filter(index) then result["filter"..index]=inv.get_filter(index) end
    end
    return result
end
local function fingerprint(entity)
    local result={inventories={},equipment={},sections={},burner={}}
    for _,id in ipairs({defines.inventory.spider_trunk,defines.inventory.spider_trash,defines.inventory.spider_ammo,defines.inventory.fuel,defines.inventory.burnt_result}) do result.inventories[id]=inventory_state(entity.get_inventory(id)) end
    for _,eq in ipairs(entity.grid.equipment) do
        result.equipment[#result.equipment+1]={name=eq.name,position=eq.position,quality=eq.quality.name,ghost=eq.type=="equipment-ghost" and eq.ghost_name or nil,energy=eq.energy,shield=eq.shield}
    end
    for _,section in pairs(entity.get_logistic_sections().sections) do
        result.sections[#result.sections+1]={group=section.group,active=section.active,multiplier=section.multiplier,filters=section.filters}
    end
    if entity.burner then result.burner={burning=entity.burner.currently_burning,remaining=entity.burner.remaining_burning_fuel,heat=entity.burner.heat} end
    result.label=entity.entity_label
    result.color=entity.color
    result.grid_inhibit=entity.grid.inhibit_movement_bonus
    result.health_fraction=entity.health/entity.max_health
    return result
end
local function same(a,b) return serpent.line(a,{sortkeys=true,comment=false})==serpent.line(b,{sortkeys=true,comment=false}) end
script.on_event(defines.events.script_raised_destroy,function(event)
    local entity=event.entity
    if storage.units and storage.units[entity.unit_number] then
        storage.before[entity.unit_number]=fingerprint(entity)
    end
end)
local function on_replacement(event)
    weapon_controls.replaced(event)
    robot_controls.replaced(event)
    if event.vehicle_id==storage.legacy_id then storage.legacy=event.entity end
    if event.vehicle_id==storage.transfer_id then storage.transfer=event.entity end
    if event.vehicle_id==storage.merge_id then storage.merge=event.entity end
    if event.vehicle_id==storage.proxy_id then storage.proxy_return=event.entity end
    local index=storage.units[event.old_unit_number]
    if not index then return end
    local before=storage.before[event.old_unit_number]
    local after=fingerprint(event.entity)
    local health=before.health_fraction
    before.health_fraction=nil;after.health_fraction=nil
    check("transfer-"..event.old_unit_number,same(before,after),same(before,after) and event.entity.name or serpent.line({before=before,after=after}))
    check("health-"..event.old_unit_number,math.abs(event.entity.health/event.entity.max_health-health)<0.000001)
    check("identity-"..event.old_unit_number,event.vehicle_id==storage.identities[index])
    storage.units[event.old_unit_number]=nil
    storage.units[event.entity.unit_number]=index
    storage.vehicles[index]=event.entity
end
script.on_load(function() script.on_event(remote.call(interface,"get_replacement_event"),on_replacement) end)
script.on_configuration_changed(function()
    for index,entity in ipairs(storage.vehicles) do storage.identities[index]=remote.call(interface,"get_vehicle_id",entity) end
    storage.legacy_id=remote.call(interface,"get_vehicle_id",storage.legacy)
end)
script.on_init(function()
    storage.start_tick=game.tick
    game.create_force("esir-spider-qc")
    storage.replacement_event=remote.call(interface,"get_replacement_event")
    script.on_event(storage.replacement_event,on_replacement)
    storage.units={};storage.before={};storage.vehicles={};storage.identities={};storage.checks={}
    local surface=game.create_surface("esir-spider-qc",{width=128,height=128,autoplace_controls={}})
    surface.request_to_generate_chunks({0,0},2);surface.force_generate_chunk_requests()
    local tiles={}
    for x=-32,32 do for y=-32,32 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
    surface.set_tiles(tiles)
    for index,family in ipairs(catalog.families) do
        local entity=surface.create_entity{name=catalog.variant_name(family,{}),position={(index-1)*10,0},force="esir-spider-qc",quality=index==2 and "rare" or "normal",raise_built=true}
        storage.vehicles[index]=entity
        entity.vehicle_automatic_targeting_parameters={auto_target_without_gunner=false,auto_target_with_gunner=false}
        storage.units[entity.unit_number]=index
        storage.identities[index]=remote.call(interface,"get_vehicle_id",entity)
        entity.health=entity.max_health*0.61
        entity.entity_label="QC "..family
        entity.color={r=0.21,g=0.34,b=0.55,a=0.9}
        entity.burner.inventory[1].set_stack{name="coal",count=19}
        entity.burner.burnt_result_inventory[1].set_stack{name="depleted-uranium-fuel-cell",count=3}
        entity.burner.currently_burning={name="coal",quality="normal"}
        entity.burner.remaining_burning_fuel=1234567
        local trunk=entity.get_inventory(defines.inventory.spider_trunk)
        trunk[1].set_stack{name="iron-plate",count=43,quality="rare"}
        trunk.set_filter(1,{name="iron-plate",quality="rare",comparator="="})
        if index==2 and trunk.supports_bar() then trunk.set_bar(20) end
        entity.get_inventory(defines.inventory.spider_trash)[1].set_stack{name="copper-plate",count=7}
        local equipment=entity.grid.put{name="battery-equipment",position={0,0},quality="rare"}
        equipment.energy=345678
        entity.grid.put{name="night-vision-equipment",position={2,0},ghost=true,quality="rare"}
        entity.grid.inhibit_movement_bonus=true
        local section=entity.get_logistic_sections().add_section("spider-qc-shared")
        section.set_slot(1,{value={name="iron-plate",quality="normal",comparator="="},min=73,max=90})
        section.multiplier=2
        section.active=false
        for _,point in pairs(entity.get_logistic_point()) do point.enabled=false end
        if family=="assault" then
            local ammo=entity.get_inventory(defines.inventory.spider_ammo)
            ammo[1].set_stack{name="cannon-shell",count=3}
            ammo[2].set_stack{name="piercing-rounds-magazine",count=7};ammo[2].ammo=3
            ammo[3].set_stack{name="flamethrower-ammo",count=2};ammo[3].ammo=17
        elseif family=="rocket" then entity.get_inventory(defines.inventory.spider_ammo)[1].set_stack{name="rocket",count=5} end
    end
    local player=game.get_player(1)
    if player then
        player.force=game.forces["esir-spider-qc"]
        if not player.character then
            player.set_controller{type=defines.controllers.god}
            player.create_character()
        end
        player.teleport({0,0},surface)
        storage.player=player.index
        storage.vehicles[1].set_driver(player)
        player.cursor_stack.set_stack{name="spidertron-remote"}
        player.spidertron_remote_selection={storage.vehicles[1],storage.vehicles[2]}
        player.opened=storage.vehicles[1]
    else
        storage.driver=surface.create_entity{name="character",position={0,0},force="esir-spider-qc"}
        storage.vehicles[1].set_driver(storage.driver)
    end
    storage.follower=surface.create_entity{name="ei-gaian-saucer",position={-10,0},force="esir-spider-qc"}
    storage.follower.follow_target=storage.vehicles[1]
    storage.follower.follow_offset={x=-10,y=0}
    storage.legacy=surface.create_entity{name="assault_spidertron",position={0,20},force="esir-spider-qc",raise_built=true}
    storage.legacy_id=remote.call(interface,"get_vehicle_id",storage.legacy)
    storage.legacy.vehicle_automatic_targeting_parameters={auto_target_without_gunner=false,auto_target_with_gunner=false}
    local ammo=storage.legacy.get_inventory(defines.inventory.spider_ammo)
    for index,name in ipairs({"artillery-shell","rocket","cannon-shell","piercing-rounds-magazine","flamethrower-ammo"}) do ammo[index].set_stack{name=name,count=2} end
    ammo[4].ammo=3;ammo[5].ammo=17
    storage.legacy_artillery=ammo[1].count
end)
local function step(event)
    local tick=event.tick-storage.start_tick
    local force=game.forces["esir-spider-qc"]
    if tick==2 and remote.interfaces.SpidertronPatrols then
        remote.call("SpidertronPatrols","add_waypoints",storage.vehicles[1],{{position={x=12,y=12}},{position={x=0,y=0}}})
        remote.call("SpidertronPatrols","set_on_patrol",storage.vehicles[1],false)
    elseif tick==5 then
        force.technologies["ei-spider-vehicles"].researched=true
        check("normal-research-start",force.add_research("ei-spider-chassis-1"))
        force.research_progress=1
    elseif tick==15 then
        check("single-research-hull",storage.vehicles[1].prototype.name:match("h1$")~=nil)
        check("normal-research-event",storage.normal_research==true)
        local legacy_ammo=storage.legacy.get_inventory(defines.inventory.spider_ammo)
        check("legacy-assault-converted",storage.legacy.name:find("ei-spider-assault-",1,true)==1)
        check("legacy-ammo-remapped",legacy_ammo[1].name=="cannon-shell" and legacy_ammo[2].ammo==3 and legacy_ammo[3].ammo==17)
        check("legacy-extra-ammo-stored",storage.legacy.get_inventory(defines.inventory.spider_trunk).get_item_count("rocket")==2 and storage.legacy.get_inventory(defines.inventory.spider_trunk).get_item_count("artillery-shell")==storage.legacy_artillery,serpent.line(storage.legacy.get_inventory(defines.inventory.spider_trunk).get_contents()))
        check("driver",storage.vehicles[1].get_driver()==(storage.player and game.get_player(storage.player).character or storage.driver))
        check("follower",storage.follower.follow_target==storage.vehicles[1])
        if remote.interfaces.SpidertronPatrols then
            remote.call("SpidertronPatrols","set_on_patrol",storage.vehicles[1],true)
            check("patrol-after-upgrade",storage.vehicles[1].autopilot_destination~=nil)
            remote.call("SpidertronPatrols","set_on_patrol",storage.vehicles[1],false)
        end
        if storage.player then
            check("remote",game.get_player(storage.player).spidertron_remote_selection[1]==storage.vehicles[1])
            check("opened",game.get_player(storage.player).opened==storage.vehicles[1])
        end
        force.research_all_technologies()
    elseif tick==50 then
        if remote.interfaces.SpidertronPatrols then
            remote.call("SpidertronPatrols","set_on_patrol",storage.vehicles[1],true)
            check("patrol-after-burst",storage.vehicles[1].autopilot_destination~=nil)
            remote.call("SpidertronPatrols","set_on_patrol",storage.vehicles[1],false)
        end
        for index,family in ipairs(catalog.families) do
            check("burst-final-"..family,storage.vehicles[index].name==expected(family,force))
        end
        local scout=storage.vehicles[1]
        local laser=scout.grid.put{name="personal-laser-defense-equipment",position={2,2}}
        check("scout-lasers",laser~=nil)
        local rocket=storage.vehicles[3]
        local battery=rocket.grid.put{name="battery-equipment",position={11,6}}
        check("expanded-grid-placement",battery~=nil)
        battery.energy=98765
        local inventory=game.create_inventory(200)
        storage.mined_inventory=inventory
        storage.units[rocket.unit_number]=nil
        check("mine-expanded",rocket.mine{inventory=inventory})
        local item
        for index=1,#inventory do
            if inventory[index].valid_for_read and inventory[index].name==catalog.stored_item("rocket",3) then item=inventory[index];break end
        end
        check("stored-item",item~=nil)
        check("stored-energy",item.grid.get({11,6}).energy==98765)
        local rebuilt=game.surfaces["esir-spider-qc"].create_entity{name=item.prototype.place_result.name,position={20,0},force=force,item=item,raise_built=true}
        item.clear()
        storage.vehicles[3]=rebuilt
        storage.units[rebuilt.unit_number]=3
        storage.identities[3]=remote.call(interface,"get_vehicle_id",rebuilt)
        check("rebuild-energy",rebuilt.grid.get({11,6}).energy==98765)
    elseif tick==70 then
        local rocket=storage.vehicles[3]
        check("rebuilt-final-variant",rocket.name==expected("rocket",force))
        force.technologies["ei-spider-chassis-12"].researched=false
    elseif tick==85 then
        check("unsafe-grid-downgrade-retained",storage.vehicles[3].grid.height==8 and storage.vehicles[3].grid.get({11,6})~=nil)
        force.technologies["ei-spider-chassis-12"].researched=true
        remote.call(interface,"refresh_force",force)
        local assault=storage.vehicles[2]
        local surface=assault.surface
        storage.smoke_enemy=surface.create_entity{name="esir-spider-qc-target",position={assault.position.x+4,assault.position.y},force="enemy"}
        storage.smoke_enemy.active=false
        storage.smoke_friend=surface.create_entity{name="esir-spider-qc-target",position={assault.position.x-4,assault.position.y},force=force}
        storage.smoke_friend.active=false
        assault.get_inventory(defines.inventory.spider_trunk).insert{name=catalog.smoke.charge,count=2}
        assault.damage(assault.max_health,game.forces.enemy,"electric")
    elseif tick==100 then
        local status=remote.call(interface,"get_status")
        check("runtime-errors",status.failures==0,serpent.line(status))
        check("smoke-consumed",storage.vehicles[2].get_inventory(defines.inventory.spider_trunk).get_item_count(catalog.smoke.charge)==1)
        check("smoke-slows-enemy",#(storage.smoke_enemy.stickers or {})>0)
        check("prominent-smoke-bank",storage.smoke_enemy.surface.count_entities_filtered{name="ei-assault-smoke-bank"}==6)
        check("smoke-spares-friendly",#(storage.smoke_friend.stickers or {})==0)
        storage.vehicles[2].damage(10,game.forces.enemy,"electric")
        check("smoke-cooldown-after-upgrade",storage.vehicles[2].get_inventory(defines.inventory.spider_trunk).get_item_count(catalog.smoke.charge)==1)
    elseif tick==110 then
        combat.setup()
        weapon_controls.setup()
        robot_controls.setup()
    elseif tick==120 then
        local secondary=game.create_force("esir-spider-secondary")
        local surface=game.create_surface("esir-spider-transfer",{width=64,height=64,autoplace_controls={}})
        surface.request_to_generate_chunks({0,0},1);surface.force_generate_chunk_requests()
        local tiles={}
        for x=-20,20 do for y=-20,20 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
        surface.set_tiles(tiles)
        storage.transfer=surface.create_entity{name=catalog.variant_name("scout",{chassis=12}),position={0,0},force=secondary,raise_built=true}
        storage.transfer_id=remote.call(interface,"get_vehicle_id",storage.transfer)
        storage.transfer.get_inventory(defines.inventory.fuel).insert{name="coal",count=10}
        local shield=storage.transfer.grid.put{name="energy-shield-equipment",position={0,0}}
        shield.shield=17
    elseif tick==140 then
        check("separate-force-base",storage.transfer.name==catalog.variant_name("scout",{}))
        check("shield-preserved",storage.transfer.grid.get({0,0}).shield==17)
        storage.transfer.force=force
        remote.call(interface,"refresh_vehicle",storage.transfer)
        storage.merge=storage.transfer.surface.create_entity{name=catalog.variant_name("scout",{}),position={0,10},force="esir-spider-secondary",raise_built=true}
        storage.merge_id=remote.call(interface,"get_vehicle_id",storage.merge)
    elseif tick==170 then
        check("direct-force-transfer",storage.transfer.name==catalog.variant_name("scout",catalog.researched_state(force)))
        game.merge_forces("esir-spider-secondary",force)
    elseif tick==190 then
        check("force-merge",storage.merge.name==catalog.variant_name("scout",catalog.researched_state(force)))
        storage.transfer.autopilot_destination={15,0}
    elseif tick==200 and prototypes.custom_event["on_spidertron_replaced"] then
        local clone=storage.vehicles[2].clone{position={5,20},surface=storage.vehicles[2].surface}
        storage.proxy_id=remote.call(interface,"get_vehicle_id",clone)
        check("clone-new-identity",storage.proxy_id~=storage.identities[2])
        storage.proxy=clone.surface.create_entity{name=catalog.proxy_prefix..clone.name,position=clone.position,force=force,raise_built=true}
        script.raise_event("on_spidertron_replaced",{old_spidertron=clone,new_spidertron=storage.proxy})
        clone.destroy{raise_destroy=true}
        force.technologies[catalog.weapon_technology("mg",4)].researched=false
    elseif tick==230 and storage.proxy then
        check("boarding-proxy-suspended",storage.proxy.valid and catalog.is_proxy(storage.proxy.name) and remote.call(interface,"get_vehicle_id",storage.proxy)==storage.proxy_id)
        storage.proxy_return=storage.proxy.surface.create_entity{name=storage.proxy.name:sub(#catalog.proxy_prefix+1),position=storage.proxy.position,force=force,raise_built=true}
        script.raise_event("on_spidertron_replaced",{old_spidertron=storage.proxy,new_spidertron=storage.proxy_return})
        storage.proxy.destroy{raise_destroy=true}
    elseif tick==250 and storage.proxy_return then
        check("disembark-latest-research",storage.proxy_return.name==expected("assault",force))
        check("disembark-identity",remote.call(interface,"get_vehicle_id",storage.proxy_return)==storage.proxy_id)
        storage.proxy_return.get_inventory(defines.inventory.spider_trunk).insert{name=catalog.smoke.charge,count=1}
        storage.proxy_return.health=storage.proxy_return.max_health*0.4
        storage.proxy_return.damage(10,game.forces.enemy,"electric")
        check("clone-boarding-smoke-cooldown",storage.proxy_return.get_inventory(defines.inventory.spider_trunk).get_item_count(catalog.smoke.charge)==1)
        force.technologies[catalog.weapon_technology("mg",4)].researched=true
    elseif tick==500 then
        check("smoke-expires",#(storage.smoke_enemy.stickers or {})==0)
        check("visual-smoke-expires",storage.smoke_enemy.surface.count_entities_filtered{name={"ei-assault-smoke-cloud","ei-assault-smoke-bank"}}==0)
        check("three-legged-scout-moves",storage.transfer.position.x>5,storage.transfer.position.x)
    elseif tick==620 then
        storage.combat_results=combat.verify(check)
        storage.weapon_results=weapon_controls.verify(check)
        local status=remote.call(interface,"get_status")
        check("final-runtime-errors",status.failures==0,serpent.line(status))
        local all=true
        for _,result in ipairs(storage.checks) do if not result.pass then all=false end end
        helpers.write_file("spider-vehicles-qc.json",helpers.table_to_json({all_pass=all,checks=storage.checks,status=status,combat=storage.combat_results,weapon_controls=storage.weapon_results,player=storage.player}),false)
        log("SPIDER_QC ALL_PASS="..tostring(all))
    end
    if tick>110 and tick<620 then combat.sample(tick);weapon_controls.step(tick,check);robot_controls.step(tick,check) end
end
script.on_event(defines.events.on_robot_mined_entity,robot_controls.mined)
script.on_event(defines.events.on_robot_built_entity,robot_controls.built)
script.on_event(defines.events.on_research_finished,function(event)
    if event.research.name=="ei-spider-chassis-1" and not event.by_script then storage.normal_research=true end
end)
script.on_event(defines.events.on_tick,function(event)
    local ok,err=pcall(step,event)
    if not ok then check("fixture-error-"..event.tick,false,tostring(err)) end
end)

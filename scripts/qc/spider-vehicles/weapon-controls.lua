-- Mixed-range combat and per-vehicle control acceptance, isolated from native probes.
local catalog=require("__exotic-space-industries-remembrance__/lib/spider-vehicles")
local api="exotic-industries-spider-vehicles"
local model={}
local SMART=settings.startup["ei-spider-range-aware-cycling"].value
local function ammo(stack)
    if not stack.valid_for_read then return 0 end
    return (stack.count-1)*stack.prototype.magazine_size+stack.ammo
end
local function controls(entity,changes) return remote.call(api,"set_weapon_controls",entity,changes) end
local function status(entity) return remote.call(api,"get_weapon_controls",entity) end
function model.replaced(event)
    for _,case in ipairs(storage.weapon_cases or {}) do if case.id==event.vehicle_id then case.entity=event.entity end end
    if storage.control_clone_id==event.vehicle_id then storage.control_clone=event.entity end
    if storage.control_rebuilt_id==event.vehicle_id then storage.control_rebuilt=event.entity end
end
function model.setup()
    local base=game.create_force("esir-control-base")
    local advanced=game.create_force("esir-control-advanced")
    for _,force in ipairs({base,advanced}) do
        for _,branch in ipairs(catalog.branch_order) do
            local levels=force==advanced and #catalog.upgrade_names[branch] or ((branch=="artillery" or branch=="doeworks") and 1 or 0)
            for level=1,levels do force.technologies[catalog.weapon_technology(branch,level)].researched=true end
        end
        remote.call(api,"refresh_force",force)
    end
    local cases={
        {name="artillery-far",family="assault",range=60,selected=1},
        {name="artillery-close",family="assault",range=10,selected=4},
        {name="doeworks-far",family="rocket",range=105,selected=1},
        {name="doeworks-close",family="rocket",range=25,selected=5},
        {name="assault-overlap",family="assault",range=10,advanced=true},
        {name="rocket-overlap",family="rocket",range=40,advanced=true},
        {name="assault-controls",family="assault",parked=true},
        {name="rocket-controls",family="rocket",parked=true},
        {name="manual-controls",family="assault",parked=true},
        {name="artillery-near-and-far",family="assault",range=10,selected=4,second_range=60},
        {name="doeworks-near-and-far",family="rocket",range=25,selected=5,second_range=105},
        {name="artillery-boundary",family="assault",range=60,selected=1,dynamic=true},
        {name="doeworks-boundary",family="rocket",range=105,selected=1,dynamic=true},
        {name="partial-ammo-controls",family="assault",parked=true,partial=true},
        {name="empty-ammunition",family="rocket",range=40,advanced=true,empty=true},
        {name="ammunition-range-modifier",family="assault",range=30,selected=2,modifier=true},
    }
    storage.weapon_cases=cases
    local surface=game.create_surface("esir-weapon-controls",{autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false,settings={}}}})
    for index,case in ipairs(cases) do
        local position={x=0,y=index*300}
        surface.request_to_generate_chunks(position,2);surface.force_generate_chunk_requests()
        local tiles={}
        for x=-8,125 do for y=-6,6 do tiles[#tiles+1]={name="grass-1",position={x,position.y+y}} end end
        surface.set_tiles(tiles)
        local force=case.advanced and advanced or base
        local name=catalog.configured_name(case.family,catalog.researched_state(force),{cycling=true,special=true},SMART)
        local entity=surface.create_entity{name=name,position=position,force=force,raise_built=true}
        entity.vehicle_automatic_targeting_parameters={auto_target_with_gunner=not case.parked,auto_target_without_gunner=not case.parked}
        entity.selected_gun_index=case.selected or 1
        case.entity=entity;case.id=remote.call(api,"get_vehicle_id",entity)
        case.ammo_names=case.family=="assault" and {"cannon-shell","firearm-magazine","flamethrower-ammo","artillery-shell"} or {"rocket","rocket","rocket","rocket","dw-deer-ammo-basic"}
        if case.partial then case.ammo_names[4]="esir-spider-qc-partial-artillery" end
        if case.modifier then case.ammo_names[4]=nil end
        case.previous={};case.fired={}
        for slot,name in ipairs(case.ammo_names) do
            local stack=entity.get_inventory(defines.inventory.spider_ammo)[slot]
            stack.set_stack{name=name,count=100,quality=case.parked and "rare" or "normal"}
            case.previous[slot]=ammo(stack)
        end
        if not case.parked then
            case.target=surface.create_entity{name="esir-spider-qc-target",position={position.x+case.range,position.y},force="enemy"}
            case.target.active=false
            if case.second_range then
                local target=surface.create_entity{name="esir-spider-qc-target",position={position.x+case.second_range,position.y},force="enemy"}
                target.active=false
            end
        else
            entity.grid.put{name="battery-equipment",position={0,0},quality="rare"}.energy=9876
        end
        controls(entity,{cycling=true})
        if case.partial then
            local ammo=entity.get_inventory(defines.inventory.spider_ammo)[4]
            ammo.count=2;ammo.ammo=7
            local cargo=entity.get_inventory(defines.inventory.spider_trunk)
            for slot=1,#cargo-1 do cargo[slot].set_stack{name="iron-plate",count=prototypes.item["iron-plate"].stack_size} end
            cargo[#cargo].set_stack{name=case.ammo_names[4],count=2,quality="rare"}
        end
    end
    local trunk=cases[7].entity.get_inventory(defines.inventory.spider_trunk)
    for slot=1,#trunk do trunk[slot].set_stack{name="iron-plate",count=prototypes.item["iron-plate"].stack_size} end
end
function model.step(tick,check)
    local cases=storage.weapon_cases
    if not cases then return end
    local assault,rocket=cases[7],cases[8]
    if tick==120 then
        controls(assault.entity,{special=false})
        controls(rocket.entity,{cycling=false})
    elseif tick==130 then
        local value=status(assault.entity)
        check("controls-full-cargo-pending",value.pending and value.effective_special and not value.special and value.pending_reason=="mount-ammo-space",serpent.line(remote.call("esir-spider-qc-controls","snapshot",assault.entity)))
        assault.entity.get_inventory(defines.inventory.spider_trunk)[80].clear()
        check("controls-hold-rocket",status(rocket.entity).effective_mode=="hold" and catalog.mode(rocket.entity.name)=="hold")
        controls(rocket.entity,{selected_slot=5,special=false})
    elseif tick==145 then
        for _,case in ipairs(cases) do
            if case.empty then for slot=1,4 do case.entity.get_inventory(defines.inventory.spider_ammo)[slot].clear();case.previous[slot]=0 end end
        end
        check("controls-rocket-mount-off",#rocket.entity.get_inventory(defines.inventory.spider_ammo)==4 and not status(rocket.entity).effective_special)
        check("controls-rocket-ammo-stowed",rocket.entity.get_inventory(defines.inventory.spider_trunk).get_item_count{name="dw-deer-ammo-basic",quality="rare"}>0)
        controls(rocket.entity,{special=true})
    elseif tick==160 then
        check("controls-rocket-ammo-restored",rocket.entity.get_inventory(defines.inventory.spider_ammo)[5].valid_for_read and rocket.entity.get_inventory(defines.inventory.spider_ammo)[5].quality.name=="rare")
        controls(rocket.entity,{cycling=true})
    elseif tick==180 then
        for _,case in ipairs(cases) do
            if case.dynamic then case.target.teleport({case.family=="assault" and 10 or 25,case.entity.position.y}) end
        end
        check("controls-cycle-on-mode",status(rocket.entity).effective_mode==(SMART and "smart" or "native"))
        controls(rocket.entity,{cycling=false,selected_slot=2})
        local clone=rocket.entity.clone{position={10,rocket.entity.position.y},surface=rocket.entity.surface}
        storage.control_clone=clone
        storage.control_clone_id=remote.call(api,"get_vehicle_id",clone)
    elseif tick==200 then
        local clone=storage.control_clone
        check("controls-clone-preferences",status(clone).cycling==false and status(clone).selected_slot==2)
        check("controls-clone-distinct-id",status(clone).vehicle_id~=rocket.id)
    elseif tick==250 then
        check("controls-assault-off",#assault.entity.get_inventory(defines.inventory.spider_ammo)==3 and not status(assault.entity).pending)
        check("controls-assault-ammo-stowed",assault.entity.get_inventory(defines.inventory.spider_trunk).get_item_count{name="artillery-shell",quality="rare"}==1)
        controls(assault.entity,{special=true,cycling=false,selected_slot=2})
    elseif tick==270 then
        local stack=assault.entity.get_inventory(defines.inventory.spider_ammo)[4]
        check("controls-assault-restored",stack.valid_for_read and stack.name=="artillery-shell" and stack.quality.name=="rare")
        check("controls-assault-hold",status(assault.entity).effective_mode=="hold" and assault.entity.selected_gun_index==2)
        check("controls-equipment-retained",assault.entity.grid.get({0,0}).energy==9876)
        local before=status(assault.entity)
        local invalid,err=controls(assault.entity,{selected_slot=99})
        check("controls-invalid-slot",invalid==nil and err=="invalid-slot" and status(assault.entity).selected_slot==before.selected_slot)
        controls(storage.control_clone,{special=false})
    elseif tick==300 and game.get_player(1) then
        local player=game.get_player(1)
        storage.control_player_force=player.force
        player.driving=false;player.force=storage.control_clone.force
        player.teleport({12,rocket.entity.position.y},rocket.entity.surface)
        player.clear_cursor()
        player.get_main_inventory().clear()
        check("controls-native-player-mine",player.mine_entity(storage.control_clone,true))
        local inventory=player.get_main_inventory()
        local item
        for index=1,#inventory do
            local stack=inventory[index]
            if stack.valid_for_read and stack.type=="item-with-entity-data" and stack.prototype.place_result and catalog.family(stack.prototype.place_result.name)=="rocket" then item=stack;break end
        end
        storage.control_mined_number=item and item.item_number
        check("controls-mined-preferences",item and remote.call("esir-spider-qc-controls","has_item_preference",item.item_number))
        if item then
            player.cursor_stack.transfer_stack(item)
            player.build_from_cursor{position={20,rocket.entity.position.y}}
            storage.control_rebuilt=rocket.entity.surface.find_entities_filtered{position={20,rocket.entity.position.y},type="spider-vehicle"}[1]
            storage.control_rebuilt_id=storage.control_rebuilt and remote.call(api,"get_vehicle_id",storage.control_rebuilt)
        end
    elseif tick==310 and storage.control_rebuilt then
        local entity=storage.control_rebuilt
        local result=status(entity)
        check("controls-native-player-rebuild",result and not result.cycling and not result.special and result.selected_slot==2 and not result.pending)
        check("controls-consumed-item-cleanup",not remote.call("esir-spider-qc-controls","has_item_preference",storage.control_mined_number))
    elseif tick==320 and storage.control_rebuilt then
        local player=game.get_player(1)
        player.opened=nil
        if player.controller_type==defines.controllers.remote then player.exit_remote_view() end
        player.teleport({19,rocket.entity.position.y},rocket.entity.surface)
        check("controls-remine",player.mine_entity(storage.control_rebuilt,true))
        -- Enhancements may enter remote view when a distant native window closes.
        -- The mined item remains in the physical character inventory.
        local inventory=player.character.get_main_inventory()
        for index=1,#inventory do
            local stack=inventory[index]
            if stack.valid_for_read and stack.type=="item-with-entity-data" and stack.prototype.place_result and catalog.family(stack.prototype.place_result.name)=="rocket" then storage.control_discarded_number=stack.item_number;stack.clear();break end
        end
    elseif tick==330 and game.get_player(1) then
        check("controls-discarded-item-cleanup",storage.control_discarded_number and not remote.call("esir-spider-qc-controls","has_item_preference",storage.control_discarded_number))
    elseif tick==340 and game.get_player(1) then
        local player=game.get_player(1)
        player.teleport({3,assault.entity.position.y},assault.entity.surface)
        player.force=assault.entity.force;assault.entity.set_driver(player);player.opened=assault.entity
        remote.call("esir-spider-qc-controls","open",{player_index=player.index,entity=assault.entity})
        local root=player.gui.relative["ei-spider-weapon-console"]
        check("controls-relative-gui",root~=nil and root.valid)
        local content=root.children[2].content
        content.weapon.selected_index=3
        local changed=remote.call("esir-spider-qc-controls","change",{player_index=player.index,element=content.weapon})
        check("controls-gui-selected-slot",assault.entity.selected_gun_index==3,serpent.line(changed))
        content=player.gui.relative["ei-spider-weapon-console"].children[2].content
        content.special.state=false
        remote.call("esir-spider-qc-controls","change",{player_index=player.index,element=content.special})
    elseif tick==350 and game.get_player(1) then
        local player=game.get_player(1)
        check("controls-gui-mount-off",not status(assault.entity).effective_special)
        check("controls-occupied-artillery-gui",player.vehicle==assault.entity and player.opened==assault.entity and player.gui.relative["ei-spider-weapon-console"]~=nil)
        local content=player.gui.relative["ei-spider-weapon-console"].children[2].content
        content.cycling.state=true
        remote.call("esir-spider-qc-controls","change",{player_index=player.index,element=content.cycling})
    elseif tick==360 and game.get_player(1) then
        local player=game.get_player(1)
        check("controls-gui-cycling",status(assault.entity).cycling)
        remote.call("esir-spider-qc-controls","close",{player_index=player.index})
        check("controls-gui-close",player.gui.relative["ei-spider-weapon-console"]==nil)
        player.opened=nil
        local case=cases[9]
        player.teleport({2,case.entity.position.y},case.entity.surface)
        case.entity.set_driver(player);case.entity.driver_is_gunner=true
        case.entity.vehicle_automatic_targeting_parameters={auto_target_with_gunner=true,auto_target_without_gunner=true}
        case.entity.selected_gun_index=2
        case.target=case.entity.surface.create_entity{name="esir-spider-qc-target",position={10,case.entity.position.y},force="enemy"}
        case.target.active=false
        player.shooting_state={state=defines.shooting.shooting_enemies,position=case.target.position}
        controls(case.entity,{cycling=true})
    elseif tick==390 and game.get_player(1) then
        if SMART then check("controls-manual-gunner",cases[9].entity.selected_gun_index==2) end
        game.get_player(1).shooting_state={state=defines.shooting.not_shooting,position=cases[9].target.position}
    elseif tick==400 then
        for _,case in ipairs(cases) do
            if case.dynamic then
                case.target.destroy()
                case.target=case.entity.surface.create_entity{name="esir-spider-qc-target",position={case.range,case.entity.position.y},force="enemy"}
                case.target.active=false
            elseif case.second_range then
                -- Remove the close target which the engine was prioritising;
                -- the already cached far target must then receive long-range fire.
                case.target.destroy()
            end
        end
    elseif tick==410 then
        rocket.entity.get_inventory(defines.inventory.fuel).insert{name="coal",count=20}
        rocket.entity.autopilot_destination={100,rocket.entity.position.y}
    elseif tick==420 then
        controls(rocket.entity,{special=false})
    elseif tick==430 then
        local value=status(rocket.entity)
        check("controls-moving-pending",value.pending and value.effective_special and value.pending_reason=="moving",serpent.line(value))
        rocket.entity.autopilot_destination=nil
        controls(rocket.entity,{special=true})
    elseif tick==450 then
        controls(cases[14].entity,{special=false})
    elseif tick==470 then
        local case=cases[14]
        local inventory=case.entity.get_inventory(defines.inventory.spider_trunk)
        local total=0
        for index=1,#inventory do if inventory[index].valid_for_read and inventory[index].name==case.ammo_names[4] then total=total+ammo(inventory[index]) end end
        check("controls-partial-cargo-merge",not status(case.entity).pending and not status(case.entity).effective_special and total==37,total)
        controls(case.entity,{special=true})
    elseif tick==490 then
        local stack=cases[14].entity.get_inventory(defines.inventory.spider_ammo)[4]
        check("controls-partial-ammo-restored",stack.valid_for_read and stack.quality.name=="rare" and ammo(stack)==37,stack.valid_for_read and ammo(stack))
    elseif tick==510 then
        local case=cases[14]
        controls(case.entity,{cycling=false,special=false,selected_slot=2})
        local force=game.create_force("esir-control-transfer")
        case.entity.force=force
        remote.call(api,"refresh_vehicle",case.entity)
        for _,branch in ipairs(catalog.branch_order) do
            for level=1,#catalog.upgrade_names[branch] do force.technologies[catalog.weapon_technology(branch,level)].researched=true end
        end
        force.technologies["ei-spider-chassis-1"].researched=true
        remote.call(api,"refresh_force",force)
    elseif tick==540 then
        local case=cases[14]
        local value=status(case.entity)
        check("controls-force-and-burst-preferences",value.vehicle_id==case.id and not value.pending and not value.cycling and not value.special and value.selected_slot==2 and value.effective_mode=="hold" and not value.effective_special)
    elseif tick==550 and game.get_player(1) then
        if SMART then check("controls-resume-after-manual",cases[9].entity.selected_gun_index~=2) end
        local player=game.get_player(1)
        player.driving=false;player.force=rocket.entity.force
        player.teleport({2,rocket.entity.position.y},rocket.entity.surface)
        rocket.entity.set_driver(player);player.opened=rocket.entity
        remote.call("esir-spider-qc-controls","open",{player_index=player.index,entity=rocket.entity})
        local content=player.gui.relative["ei-spider-weapon-console"].children[2].content
        content.special.state=false
        remote.call("esir-spider-qc-controls","change",{player_index=player.index,element=content.special})
    elseif tick==565 and game.get_player(1) then
        local player=game.get_player(1)
        check("controls-occupied-doeworks-gui",player.vehicle==rocket.entity and player.opened==rocket.entity and player.gui.relative["ei-spider-weapon-console"]~=nil and not status(rocket.entity).effective_special)
        local content=player.gui.relative["ei-spider-weapon-console"].children[2].content
        content.special.state=true
        remote.call("esir-spider-qc-controls","change",{player_index=player.index,element=content.special})
    elseif tick==580 and game.get_player(1) then
        local player=game.get_player(1)
        check("controls-occupied-doeworks-restored-gui",player.vehicle==rocket.entity and player.opened==rocket.entity and player.gui.relative["ei-spider-weapon-console"]~=nil and status(rocket.entity).effective_special)
        player.opened=nil;player.driving=false
        player.teleport({2,assault.entity.position.y},assault.entity.surface)
        assault.entity.set_passenger(player);player.opened=assault.entity
        remote.call("esir-spider-qc-controls","open",{player_index=player.index,entity=assault.entity})
        local content=player.gui.relative["ei-spider-weapon-console"].children[2].content
        content.special.state=true
        remote.call("esir-spider-qc-controls","change",{player_index=player.index,element=content.special})
    elseif tick==600 and game.get_player(1) then
        local player=game.get_player(1)
        check("controls-passenger-artillery-gui",assault.entity.get_passenger()==player.character and player.opened==assault.entity and player.gui.relative["ei-spider-weapon-console"]~=nil and status(assault.entity).effective_special)
        player.opened=nil;player.driving=false;player.force=storage.control_player_force
    end
    for _,case in ipairs(cases) do
        if not case.parked then
            for slot,name in ipairs(case.ammo_names) do
                local stack=case.entity.get_inventory(defines.inventory.spider_ammo)[slot]
                local remaining=ammo(stack)
                if remaining<case.previous[slot] then case.fired[#case.fired+1]={tick=tick,slot=slot,used=case.previous[slot]-remaining} end
                if remaining<10 and not (case.empty and slot<=4 and tick>=145) then stack.set_stack{name=name,count=100};remaining=ammo(stack) end
                case.previous[slot]=remaining
            end
        end
    end
end
function model.verify(check)
    local results={}
    for _,case in ipairs(storage.weapon_cases) do
        if not case.parked then
            results[#results+1]={name=case.name,shots=case.fired,snapshot=remote.call("esir-spider-qc-controls","snapshot",case.entity),target=case.target.valid and case.target.position}
            if case.modifier then
                if SMART then check("selector-ammunition-range-modifier",#case.fired>0 and case.fired[1].slot==1) end
            elseif case.empty then
                if SMART then
                    local used=false
                    for _,shot in ipairs(case.fired) do used=used or (shot.slot==5 and shot.tick>=145 and shot.tick<=170) end
                    check("selector-empty-battery-yields",used)
                end
            elseif case.dynamic then
                if SMART then
                    local short,long=false,false
                    for _,shot in ipairs(case.fired) do
                        local special=shot.slot==(case.family=="assault" and 4 or 5)
                        short=short or (not special and shot.tick>180 and shot.tick<400)
                        long=long or (special and shot.tick>400)
                    end
                    check("selector-boundaries-and-destruction-"..case.family,short and long)
                end
            elseif case.name:find("far") or case.name:find("close") then
                if case.second_range then
                    if SMART then
                        local long=false
                        for _,shot in ipairs(case.fired) do long=long or (shot.slot==(case.family=="assault" and 4 or 5) and shot.tick>400) end
                        check("selector-"..case.name,#case.fired>0 and long,#case.fired)
                    end
                else check("selector-"..case.name,SMART and #case.fired>0 or not SMART and #case.fired==0,#case.fired) end
            elseif SMART then
                local first={}
                for _,shot in ipairs(case.fired) do
                    local group=catalog.slot_group(case.family,shot.slot)
                    if not first[group] then first[group]={start=shot.tick,finish=shot.tick,count=1}
                    elseif not first[group].ended then first[group].finish=shot.tick;first[group].count=first[group].count+1 end
                    for other,turn in pairs(first) do if other~=group then turn.ended=true end end
                end
                if case.family=="assault" then
                    check("selector-cannon-two-shot-turn",first.cannon and first.cannon.count==2)
                    check("selector-mg-sustained",first.mg and first.mg.finish-first.mg.start>=118,serpent.line(first.mg))
                    check("selector-flame-sustained",first.flamer and first.flamer.finish-first.flamer.start>=178,serpent.line(first.flamer))
                else
                    check("selector-four-rocket-battery",first.rocket and first.rocket.count==4)
                    local ordered=true
                    for slot=1,4 do ordered=ordered and case.fired[slot] and case.fired[slot].slot==slot end
                    check("selector-battery-slot-order",ordered)
                    check("selector-doeworks-sustained",first.doeworks and first.doeworks.finish-first.doeworks.start>=88,serpent.line(first.doeworks))
                end
            end
        end
    end
    local status=remote.call(api,"get_status")
    check("selector-search-budget",status.selector_max_searches_per_tick<=8,status.selector_max_searches_per_tick)
    check("selector-startup-policy",SMART and status.selector_searches>0 and status.selector_samples>0 or not SMART and status.selector_searches==0 and status.selector_samples==0)
    return results
end
return model

local config=require("test-config")
local INTERFACE="anisetron-mobility-qc"
local SLOWS={"acid-sticker-small","acid-sticker-medium","acid-sticker-big","acid-sticker-behemoth","tb-fire-sticker","cb-cold-sticker","eb-fire-sticker"}
local function check(name,pass,detail) storage.results[name]={pass=pass==true,detail=detail} end
script.on_configuration_changed(function(event)
    storage.native_configuration_receipt={tick=game.tick,mods=event.mod_changes,settings=event.mod_startup_settings_changed}
end)
local function setup(tick)
    storage.start_tick,storage.results,storage.records,storage.by_unit=tick,{},{},{}
    local surface=game.create_surface("anisetron-stallfix-combat",{width=10000,height=2048,water=0,
        autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
    for x=0,4000,500 do surface.request_to_generate_chunks({x,0},12) end
    surface.force_generate_chunk_requests()
    for _,entity in pairs(surface.find_entities_filtered{type={"unit","unit-spawner","turret","tree"}}) do entity.destroy() end
    storage.surface=surface
    local force=game.create_force("anisetron-stallfix-combat")
    storage.force=force
    local function add(key,name,attack,manual,turns,armed,equipped,mixed)
        local index=#storage.records+1
        local entity=surface.create_entity{name=name,position={0,-480+index*110},force=force,raise_built=true}
        entity.orientation=.25;entity.torso_orientation=.25
        entity.vehicle_automatic_targeting_parameters={auto_target_without_gunner=armed==true,auto_target_with_gunner=armed==true}
        if not manual then entity.autopilot_destination={4500,entity.position.y} end
        local record={key=key,entity=entity,attack=attack,manual=manual,turns=turns,mixed=mixed,
            samples={},phases={},damage_count=0,damage_total=0,enemies={},last=entity.position,stopped_runs={},stop_run=0}
        if armed then entity.get_inventory(defines.inventory.spider_ammo)[1].set_stack{name="ei-anisetron-crystal-charge",count=10,ammo=1} end
        if equipped then
            for _,pos in ipairs{{0,0},{4,0}} do local eq=entity.grid.put{name="fusion-reactor-equipment",position=pos};eq.energy=100000000 end
            for _,pos in ipairs{{8,0},{10,0},{0,4},{2,4},{4,4},{6,4},{8,4},{10,4}} do local eq=entity.grid.put{name="exoskeleton-equipment",position=pos};eq.energy=100000000 end
        end
        storage.records[index]=record;storage.by_unit[entity.unit_number]=record
        if manual then
            local player=assert(game.get_player(1),"Copied seed player required")
            if player.controller_type==defines.controllers.remote then player.exit_remote_view() end
            player.driving=false;player.force=force;player.teleport(entity.position,surface)
            if not(player.character and player.character.valid) then player.set_controller{type=defines.controllers.character,character=surface.create_entity{name="character",position=entity.position,force=force}} end
            storage.player=player.index
            if config.save then
                -- Disconnected server players do not execute manual input.
                -- Native autopilot still proves saved movement/cohort state.
                entity.set_driver(nil)
                record.manual=false;entity.autopilot_destination={4500,entity.position.y}
                record.persistence_control="native-autopilot"
                check("persistence-native-autopilot",entity.autopilot_destination~=nil)
            else
                entity.set_driver(player)
                check("manual-driver-seated",player.vehicle==entity)
            end
        end
    end
    add("remote-baseline","ei-anisetron",false)
    add("remote-real-attack","ei-anisetron",true)
    add("remote-mixed-slow","ei-anisetron",false,false,false,false,false,true)
    add("remote-turning","ei-anisetron",true,false,true)
    add("saucer-real-attack","ei-gaian-saucer",true)
    add("manual-real-attack","ei-anisetron",true,true)
    add("remote-armed-attack","ei-anisetron",true,false,false,true)
    add("remote-equipped-attack","ei-anisetron",true,false,false,false,true)
end
script.on_event(defines.events.on_entity_damaged,function(event)
    local dot=storage.dot_records and storage.dot_records[event.entity.unit_number]
    if dot and event.damage_type.name=="poison" then
        dot.damage=dot.damage+event.final_damage_amount;dot.hits=dot.hits+1
    end
    local record=storage.by_unit and storage.by_unit[event.entity.unit_number]
    if record then
        record.damage_count=record.damage_count+1;record.damage_total=record.damage_total+event.final_damage_amount
        event.entity.health=event.entity.max_health
    end
end)
local function wave(record)
    local source=record.entity
    for i=1,24 do
        local angle=i*math.pi/12
        local position={source.position.x+math.cos(angle)*12,source.position.y+math.sin(angle)*12}
        local types={"small-spitter","medium-spitter","big-spitter","behemoth-spitter","big-toxic-spitter","big-cold-spitter","big-explosive-spitter"}
        local name=i<=3 and "behemoth-biter" or types[(i-4)%#types+1]
        local enemy=storage.surface.create_entity{name=name,position=position,force="enemy"}
        enemy.commandable.set_command{type=defines.command.attack,target=source,distraction=defines.distraction.none}
        record.enemies[#record.enemies+1]=enemy
    end
end
script.on_event(defines.events.on_tick,function(event)
    if config.save and storage.saved then return end
    if storage.complete then return end
    if not storage.start_tick then setup(event.tick) end
    local t=event.tick-storage.start_tick
    if not storage.native_topology_checked then
        storage.native_topology_checked=true
        local all=true
        for id,record in pairs(storage.by_unit) do
            local source=record.entity
            all=all and source.valid and source.unit_number==id
            if source.name=="ei-anisetron" then all=all and #source.get_spider_legs()==(config.ten_leg_trial and 10 or 4) end
        end
        check("native-leg-count-and-body-identities",all)
        if config.loaded then check("configuration-transition-observed",storage.native_configuration_receipt~=nil,storage.native_configuration_receipt) end
    end
    if config.save then game.speed=20 end
    local phase=t<1500 and "baseline" or t<7500 and "attack" or "recovery"
    for _,record in ipairs(storage.records) do
        local source=record.entity
        if record.manual then game.get_player(storage.player).walking_state={walking=true,direction=defines.direction.east} end
        if record.turns and t%240==0 then
            local sign=t%480==0 and 1 or -1
            source.autopilot_destination={source.position.x+200,source.position.y+100*sign}
        end
        if record.attack and t>=1500 and t<7500 and t%300==0 then wave(record) end
        if record.mixed and t>=1500 and t<7500 and t%30==0 then
            for _,name in ipairs(SLOWS) do
                storage.surface.create_entity{name=name,position=source.position,target=source,force="enemy"}
            end
            -- Native damage admission for the scripted seven-sticker control.
            source.damage(1,"enemy","physical")
        end
        if t==7500 then for _,enemy in ipairs(record.enemies) do if enemy.valid then enemy.destroy() end end end
        local dx,dy=source.position.x-record.last.x,source.position.y-record.last.y
        local displacement=math.sqrt(dx*dx+dy*dy)
        record.last={x=source.position.x,y=source.position.y}
        if t>300 then
            local stats=record.phases[phase] or {sum=0,min=math.huge,max=0,count=0,zero_ticks=0,distance=0,max_zero_run=0}
            stats.sum=stats.sum+source.speed;stats.min=math.min(stats.min,source.speed);stats.max=math.max(stats.max,source.speed);stats.count=stats.count+1
            stats.distance=stats.distance+displacement
            if displacement<.00001 then stats.zero_ticks=stats.zero_ticks+1;record.stop_run=record.stop_run+1
            else record.stop_run=0 end
            stats.max_zero_run=math.max(stats.max_zero_run,record.stop_run)
            record.phases[phase]=stats
        end
        if t%30==0 then
            local legs={}
            for _,leg in ipairs(source.get_spider_legs()) do legs[#legs+1]={x=leg.position.x-source.position.x,y=leg.position.y-source.position.y,active=leg.active} end
            local stickers={};for _,sticker in pairs(source.stickers or {}) do stickers[#stickers+1]=sticker.name end
            record.samples[#record.samples+1]={tick=t,speed=source.speed,displacement=displacement,x=source.position.x,y=source.position.y,
                active=source.active,modifier=source.sticker_vehicle_modifiers,stickers=stickers,legs=legs,
                walking=record.manual and game.get_player(storage.player).walking_state or nil,
                autopilot=not record.manual and source.autopilot_destination or nil}
        end
    end
    if t==2100 then
        local snapshot=remote.call(INTERFACE,"snapshot")
        -- Faster protected craft can outrun an individual slow before this
        -- sample. The direct seven-sticker case guarantees compensation;
        -- requiring five simultaneous helpers confused exposure with coverage.
        local floor_valid=true
        for _,record in pairs(snapshot.per_vehicle) do
            if record.raw_modifier and record.raw_modifier>0 and record.raw_modifier<snapshot.minimum_modifier then
                local effective=record.raw_modifier*record.factor
                floor_valid=floor_valid and record.factor>1 and effective>=snapshot.minimum_modifier-.000001
                    and effective<snapshot.minimum_modifier*1.25+.000001
            end
        end
        check("shipping-floor-active-with-visuals-off",settings.startup["ei-anisetron-visual-fidelity"].value=="off"
            and snapshot.affected>=5 and snapshot.compensated>=1 and floor_valid,snapshot)
    end
    if t==6000 then
        local source=storage.records[3].entity
        local originals={}
        for _,sticker in ipairs(source.stickers or {}) do
            if not sticker.name:find("ei%-anisetron%-hover%-compensation") then originals[#originals+1]={entity=sticker,name=sticker.name,ttl=sticker.time_to_live} end
        end
        remote.call(INTERFACE,"rebuild",event.tick)
        local retained=#originals==7
        for _,original in ipairs(originals) do retained=retained and original.entity.valid and original.entity.name==original.name and original.entity.time_to_live==original.ttl end
        check("rebuild-preserves-all-original-sticker-handles-and-ttl",retained,#originals)
    end
    if t==6100 then
        storage.dot_records={}
        for i,name in ipairs{"ei-anisetron","ei-gaian-saucer"} do
            local source=storage.surface.create_entity{name=name,position={-40+i*20,-320},force=storage.force,raise_built=true}
            local record={entity=source,name=name,damage=0,hits=0}
            storage.dot_records[source.unit_number]=record
            for _,slow in ipairs(SLOWS) do storage.surface.create_entity{name=slow,position=source.position,target=source,force="enemy"} end
            storage.surface.create_entity{name="anisetron-stallfix-dot",position=source.position,target=source,force="enemy"}
        end
    end
    if t==6162 then
        local records={};for _,record in pairs(storage.dot_records) do records[#records+1]=record end
        check("native-dot-damage-identical-with-and-without-compensation",#records==2 and records[1].hits>0
            and records[1].hits==records[2].hits and math.abs(records[1].damage-records[2].damage)<.000001,
            {{name=records[1].name,hits=records[1].hits,damage=records[1].damage},{name=records[2].name,hits=records[2].hits,damage=records[2].damage}})
        for _,record in ipairs(records) do record.entity.destroy{raise_destroy=true};record.entity=nil end
    end
    if t==6500 then
        local source=storage.surface.create_entity{name="ei-anisetron",position={-20,-310},force=storage.force,raise_built=true}
        storage.removal_source,storage.removal_id=source,source.unit_number
        for _,name in ipairs(SLOWS) do storage.surface.create_entity{name=name,position=source.position,target=source,force="enemy"} end
        source.damage(1,"enemy","physical")
    end
    if t==6508 then
        local snapshot=remote.call(INTERFACE,"snapshot")
        local record=snapshot.per_vehicle[storage.removal_id]
        check("removal-source-was-compensated",record and record.factor>1,record)
        local handles={}
        for _,sticker in ipairs(storage.removal_source.stickers or {}) do
            if sticker.name:find("ei%-anisetron%-hover%-compensation") then handles[#handles+1]=sticker end
        end
        storage.removal_handles=handles;storage.removal_source.destroy{raise_destroy=true}
    end
    if t==6525 then
        local snapshot=remote.call(INTERFACE,"snapshot")
        local clean=not snapshot.per_vehicle[storage.removal_id]
        for _,handle in ipairs(storage.removal_handles or {}) do clean=clean and not handle.valid end
        check("source-removal-cleans-owned-sticker-and-cohort",clean)
        storage.removal_handles,storage.removal_source=nil,nil
    end
    if config.save and t==3500 then
        local snapshot=remote.call(INTERFACE,"snapshot")
        storage.saved=true
        helpers.write_file("anisetron-qc.json",helpers.table_to_json{all_pass=snapshot.compensated>=5,count=1,complete=true,
            profile="shipping-movement-floor-save",fixture_version=6,cases={saved_native_compensation={pass=snapshot.compensated>=1,detail=snapshot}},saved_tick=event.tick},false)
        game.server_save("anisetron-transition")
    elseif t==11900 then
        local all,count=true,0
        for _,record in ipairs(storage.records) do
            for _,stats in pairs(record.phases) do stats.mean=stats.sum/stats.count end
            if record.attack then check("real-enemy-hits-"..record.key,record.damage_count>0,{count=record.damage_count,damage=record.damage_total}) end
            if record.entity.name=="ei-anisetron" then
                check("no-sustained-stall-"..record.key,record.phases.attack.max_zero_run==0,record.phases.attack)
                local clean=true
                for _,sample in ipairs(record.samples) do
                    if sample.tick>8100 then
                        clean=clean and sample.modifier.speed_modifier<=1.000001
                        for _,name in ipairs(sample.stickers) do clean=clean and not name:find("ei%-anisetron%-hover%-compensation") end
                    end
                end
                check("no-unwanted-speed-boost-after-expiry-"..record.key,clean)
            end
            record.entity=nil;record.last=nil;record.enemies=nil
        end
        local snapshot=remote.call(INTERFACE,"snapshot")
        check("affected-cohorts-return-to-idle",snapshot.affected==0 and snapshot.compensated==0,snapshot)
        for _,result in pairs(storage.results) do count=count+1;all=all and result.pass end
        storage.complete=true
        helpers.write_file("anisetron-qc.json",helpers.table_to_json{all_pass=all,count=count,complete=true,profile="shipping-native-mobility",fixture_version=6,cases=storage.results,records=storage.records},false)
    end
end)

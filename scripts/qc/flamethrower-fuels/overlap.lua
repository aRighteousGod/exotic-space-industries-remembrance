local catalog=require("__exotic-space-industries-remembrance__/lib/flamethrower-fuels")
local module={}
local function check(name,value)
    storage.report.checks[name]=value==true
    if not value then
        helpers.write_file("flamethrower-qc.json",helpers.table_to_json(storage.report),false)
        error("Fire overlap QC: "..name)
    end
end
local function shot(name,target,position)
    storage.surface.create_entity{name="overlap-qc-"..name,position=position or target.position or target,
        target=target,speed=1,force="player"}
end
local function supported_stickers(target)
    local count=0
    for _,sticker in pairs(target.stickers or {}) do
        if catalog.fire_stickers[sticker.name] then count=count+1 end
    end
    return count
end
function module.install(config)
    script.on_init(function()
        storage.start=game.tick
        storage.report={checks={},profile=config.profile,enabled=config.enabled,seen={},sticker_damage=0,
            rapid_sticker_damage=0,settled_sticker_hits={},ground_early=0,ground_late=0}
        storage.surface=game.create_surface("flame-overlap",{width=512,height=512,autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
        local surface=storage.surface
        surface.request_to_generate_chunks({0,0},9);surface.force_generate_chunk_requests()
        local tiles={}
        for x=-230,230 do for y=-100,100 do tiles[#tiles+1]={name="refined-concrete",position={x,y}} end end
        surface.set_tiles(tiles)
        local function target(position)
            local entity=surface.create_entity{name="esir-flame-qc-target",position=position,force="enemy"}
            entity.active=false
            return entity
        end
        storage.target=target({0,0})
        -- A fresh target guarantees a creation event for every forced sticker
        -- identity, even when disabled cleanup leaves saved stickers alive.
        storage.hook_target=target({0,-40})
        storage.sticker_names={}
        for name in pairs(catalog.fire_stickers) do storage.sticker_names[#storage.sticker_names+1]=name end
        table.sort(storage.sticker_names)
        -- These overlapping effects are written into the fixture save, then
        -- recovered on load before testing cleanup or disabled coexistence.
        for _,name in ipairs{"ei-flame-diesel-ammo-sticker","ei-flame-petroleum-gas-ammo-sticker"} do
            surface.create_entity{name=name,position={0,0},target=storage.target,force="player"}
        end
        storage.unrelated=surface.create_entity{name="overlap-qc-unrelated-sticker",position={0,0},target=storage.target,force="player"}
        storage.boundaries={}
        for index,distance in ipairs{0,0.5,1,1.015625} do
            local center={x=-180+index*15,y=0}
            local old=surface.create_entity{name="ei-flame-diesel-ammo-fire",position={center.x+distance,0},force="enemy"}
            storage.boundaries[index]={old=old,center=center,distance=distance}
        end
        storage.tree=surface.create_entity{name="fire-flame-on-tree",position={-165,0},force="player"}
        storage.same_type={}
        for index,distance in ipairs{0.5,1} do
            local center={x=150+index*15,y=0}
            local old=surface.create_entity{name="fire-flame",position={center.x+distance,0},force="player"}
            storage.same_type[index]={old=old,center=center}
        end
        storage.foreign_fire=surface.create_entity{name="overlap-qc-unrelated-fire",position={-165,0},force="player"}
        storage.extinguished=surface.create_entity{name="fire-flame",position={-80,0},force="player"}
        storage.fed_target=target({60,0})
        storage.fed=surface.create_entity{name="fire-flame",position={60,0},force="player"}
        storage.unfed=surface.create_entity{name="fire-flame",position={70,0},force="player"}
        storage.unfed_target=target({70,0})
        storage.stream_targets={}
        for index,mode in ipairs{"handheld","tank"} do
            storage.stream_targets[index]={target=target({90+index*15,0}),mode=mode}
        end
        storage.turrets={}
        local names={catalog.base_turret}
        for _,fuel in ipairs(catalog.fuels) do names[#names+1]=fuel.turret end
        for index,name in ipairs(names) do
            local position={x=-180+index*30,y=60}
            local victim=target({position.x,position.y-20})
            local entity=surface.create_entity{name=name,position=position,force="player"}
            entity.set_fluid(1,{name="ei-diesel",amount=100});entity.set_fluid(2,{name="ei-diesel",amount=100})
            entity.shooting_target=victim
            storage.turrets[index]={entity=entity,target=victim}
        end
    end)
    script.on_event(defines.events.on_trigger_created_entity,function(event)
        local incoming=event.entity
        if not incoming.valid then return end
        local name=incoming.name
        if catalog.fire_stickers[name] then
            if config.enabled then check("one-sticker-after-each-event",supported_stickers(incoming.sticked_to)==1) end
            check("newest-sticker-survives",incoming.valid)
            storage.report.seen[name]=true
        elseif catalog.ground_fires[name] then
            if config.enabled then
                for _,other in pairs(incoming.surface.find_entities_filtered{position=incoming.position,radius=1,name=catalog.ground_fire_names}) do
                    local a,b=incoming.position,other.position
                    check("one-ground-type-after-each-event",other.name==incoming.name or (a.x-b.x)^2+(a.y-b.y)^2>1)
                end
            end
            storage.report.seen[name]=true
        end
    end)
    script.on_event(defines.events.on_entity_damaged,function(event)
        local source=event.source
        if source and source.valid and source.type=="sticker" and event.entity==storage.target then
            storage.report.sticker_damage=storage.report.sticker_damage+event.final_damage_amount
            local elapsed=event.tick-storage.start
            if elapsed>=60 and elapsed<=180 then
                storage.report.rapid_sticker_damage=storage.report.rapid_sticker_damage+event.final_damage_amount
            elseif elapsed>210 and elapsed<400 then
                storage.report.settled_sticker_hits[#storage.report.settled_sticker_hits+1]=elapsed
            end
        end
        if source and source.valid and source==storage.fed then
            local elapsed=event.tick-storage.start
            if elapsed<20 then storage.report.ground_early=math.max(storage.report.ground_early,event.final_damage_amount) end
            if elapsed>300 then storage.report.ground_late=math.max(storage.report.ground_late,event.final_damage_amount) end
        end
        if event.entity==storage.unfed_target and event.tick-storage.start>300 then
            storage.report.unfed_late=(storage.report.unfed_late or 0)+event.final_damage_amount
        end
    end)
    script.on_event(defines.events.on_tick,function(event)
        local elapsed=event.tick-storage.start
        if elapsed==1 then
            check("preexisting-stickers-survived-save-load",supported_stickers(storage.target)>1)
            shot("fire-sticker",storage.target)
            for _,case in ipairs(storage.boundaries) do shot("fire-flame",case.center) end
            for _,case in ipairs(storage.same_type) do shot("fire-flame",case.center) end
        elseif elapsed==3 then
            if config.enabled then check("saved-stickers-cleaned",supported_stickers(storage.target)==1)
            else check("disabled-saved-stickers-retained",supported_stickers(storage.target)>1) end
            for index,case in ipairs(storage.boundaries) do check("distance-"..index,case.old.valid==(not config.enabled or case.distance>1)) end
            for index,case in ipairs(storage.same_type) do check("same-type-retained-"..index,case.old.valid) end
            check("unrelated-sticker-retained",storage.unrelated.valid)
            check("tree-fire-retained",storage.tree.valid)
            check("unrelated-fire-retained",storage.foreign_fire.valid)
            -- Multiple creation events within one tick; enabled cleanup leaves
            -- only the newest effect, while disabled effects can coexist.
            for index=1,4 do
                shot(storage.sticker_names[index],storage.target)
                shot(catalog.ground_fire_names[index],{20,0})
            end
            shot("legacy-extinguisher",{-80,0})
        elseif elapsed==5 then
            check("legacy-firefighting-still-dispatched",not storage.extinguished.valid)
        end
        if elapsed>=10 and elapsed<10+#storage.sticker_names then
            shot(storage.sticker_names[elapsed-9],storage.hook_target)
            shot(catalog.ground_fire_names[elapsed-9],{20,0})
        end
        if elapsed>=40 and elapsed<=400 then
            -- Alternate profile-batched and ammo stickers faster than either
            -- damage interval, then allow the final sticker to burn normally.
            if elapsed<=180 then
                shot(elapsed%2==0 and "ei-flame-diesel-turret-sticker" or "ei-flame-petroleum-gas-ammo-sticker",storage.target)
            end
            if elapsed%5==0 then shot("fire-flame",{60,0}) end
            if elapsed%30==0 then
                for _,case in ipairs(storage.stream_targets) do
                    local fuel=catalog.fuels[(elapsed/30)%10+1]
                    local position=case.target.position
                    storage.surface.create_entity{name="ei-flame-"..fuel.id.."-"..case.mode.."-flamethrower-fire-stream",
                        position={position.x,position.y-5},source_position={position.x,position.y-5},target=case.target,force="player"}
                end
            end
        end
        if elapsed==500 then
            check("refueling-keeps-original-entity",storage.fed.valid)
            check("refueling-increases-heat",storage.report.ground_late>storage.report.ground_early and storage.report.ground_early>0)
            check("refueling-extends-burning",storage.report.ground_late>0 and (storage.report.unfed_late or 0)==0)
            local hits=storage.report.settled_sticker_hits
            check("sticker-damage-resumes",#hits>1 and storage.report.sticker_damage>0)
            local expected=math.min(10*(tonumber(config.profile:match("%d+")) or 1),30)
            if config.enabled then
                for index=2,#hits do check("native-profile-sticker-interval",hits[index]-hits[index-1]==expected) end
            end
            for name in pairs(catalog.fire_stickers) do check("sticker-hook-"..name,storage.report.seen[name]) end
            for name in pairs(catalog.ground_fires) do check("fire-hook-"..name,storage.report.seen[name]) end
            for index,case in ipairs(storage.turrets) do check("native-turret-fired-"..index,case.target.health<case.target.max_health) end
            for _,case in ipairs(storage.stream_targets) do
                check(case.mode.."-stream-fired",case.target.health<case.target.max_health)
                if case.mode=="tank" then
                    check("tank-no-ground-fire",storage.surface.count_entities_filtered{position=case.target.position,radius=3,type="fire"}==0)
                end
            end
            for _,case in ipairs(storage.turrets) do case.entity.destroy() end
        elseif elapsed==610 then
            check("no-periodic-adaptation-work",not remote.call("esir-flame-qc","has_tick_work"))
            storage.report.overlap_calls=remote.call("esir-flame-qc","overlap_calls")
            check("overlap-dispatch-gated",(storage.report.overlap_calls>0)==config.enabled)
            storage.report.all_pass=true
            helpers.write_file("flamethrower-qc.json",helpers.table_to_json(storage.report),false)
        end
    end)
end
return module

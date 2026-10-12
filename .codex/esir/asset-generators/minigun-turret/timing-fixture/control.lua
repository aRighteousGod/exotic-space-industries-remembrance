local variants=require("test-config").glow and {"legacy","glow1","glow8"} or require("test-config").advanced and {"legacy","native16","leaf16","leaf001","start16","start20","random20"}
    or {"legacy","speed20","speed16","speed32","speed8"}
local function target(row, heading)
    local angle=heading*2*math.pi
    row.target=row.surface.create_entity{name="mg-timing-target",position={row.entity.position.x+math.sin(angle)*16,row.entity.position.y-math.cos(angle)*16},force="enemy"}
    row.target.health=1000000000
    row.entity.shooting_target=row.target
end
local function remaining(row)
    local stack=row.entity.get_inventory(defines.inventory.turret_ammo)[1]
    if not stack.valid_for_read then return 0 end
    return (stack.count-1)*row.magazine_size+stack.ammo
end
local function capture(row,tick,elapsed)
    if row.variant=="legacy" then return end
    local path="minigun-timing/"..row.id.."/"..elapsed..".png"
    game.take_screenshot{surface=row.surface,position=row.entity.position,resolution={160,128},zoom=2,daytime=0,
        anti_alias=false,show_gui=false,show_entity_info=false,hide_clouds=true,hide_fog=true,force_render=true,path=path}
    row.captures[#row.captures+1]={tick=tick,elapsed=elapsed,path=path,orientation=row.entity.orientation,remaining=remaining(row)}
end
script.on_init(function()
    if remote.interfaces.freeplay then remote.call("freeplay","set_skip_intro",true);remote.call("freeplay","set_disable_crashsite",true) end
    storage.started=game.tick;storage.rows={};storage.by_unit={};storage.errors={}
    for _,variant in ipairs(variants) do for heading=0,1 do
        local id=variant.."-"..heading
        local surface=game.create_surface("mg-"..id,{autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
        surface.request_to_generate_chunks({0,0},2);surface.force_generate_chunk_requests()
        surface.freeze_daytime=true;surface.daytime=0
        game.forces.player.chart(surface,{{-64,-64},{64,64}})
        local entity=surface.create_entity{name="mg-timing-"..variant,position={0.5,0.5},force="player"}
        entity.orientation=heading/8
        local row={id=id,variant=variant,heading=heading/8,entity=entity,surface=surface,
            magazine_size=prototypes.item["piercing-rounds-magazine"].magazine_size,
            inserted=0,shots=0,curve={},captures={},ammo_samples={},orientations={}}
        row.inserted=entity.get_inventory(defines.inventory.turret_ammo).insert{name="piercing-rounds-magazine",count=100}*row.magazine_size
        storage.rows[#storage.rows+1]=row;storage.by_unit[entity.unit_number]=row
    end end
end)
script.on_event(defines.events.on_script_trigger_effect,function(event)
    if event.effect_id~="mg-timing-launch" then return end
    local entity=event.source_entity
    local row=entity and entity.valid and storage.by_unit[entity.unit_number]
    if not row then storage.errors[#storage.errors+1]={tick=event.tick,message="unattributed launch"};return end
    row.shots=row.shots+1;row.first_shot=row.first_shot or event.tick
    local elapsed=event.tick-storage.started
    local key=tostring(elapsed)
    row.curve[key]=(row.curve[key] or 0)+1
end)
script.on_event(defines.events.on_tick,function(event)
    if storage.done then return end
    local elapsed=event.tick-storage.started
    local player=game.get_player(1)
    if player and not storage.viewer then player.set_controller{type=defines.controllers.spectator};player.teleport({0,0},storage.rows[1].surface);storage.viewer=true end
    for _,row in ipairs(storage.rows) do
        row.entity.energy=1000000
        local inventory=row.entity.get_inventory(defines.inventory.turret_ammo)
        if inventory.get_item_count("piercing-rounds-magazine")<30 then
            row.inserted=row.inserted+inventory.insert{name="piercing-rounds-magazine",count=70}*row.magazine_size
        end
        if row.target and row.target.valid then row.target.health=1000000000 end
        if elapsed==60 then target(row,row.heading) end
        if elapsed==760 then
            row.target.destroy();target(row,(row.heading+0.25)%1)
        end
        if elapsed==860 or elapsed==1097 or elapsed==1143 or elapsed==1191 then
            if row.target and row.target.valid then row.target.destroy() end
        end
        if elapsed==1080 or elapsed==1120 or elapsed==1160 then target(row,row.heading) end
        if elapsed==1240 then
            -- Automatic reacquisition: create without assigning shooting_target.
            local angle=row.heading*2*math.pi
            row.target=row.surface.create_entity{name="mg-timing-target",position={row.entity.position.x+math.sin(angle)*16,row.entity.position.y-math.cos(angle)*16},force="enemy"}
        end
        if (elapsed>=55 and elapsed<=160) or (elapsed>=750 and elapsed<=800) or
           (elapsed>=850 and elapsed<=920) or (elapsed>=1075 and elapsed<=1200) or (elapsed>=1235 and elapsed<=1300) then capture(row,event.tick,elapsed) end
        if elapsed%10==0 then
            row.ammo_samples[#row.ammo_samples+1]={elapsed=elapsed,shots=row.shots,consumed=row.inserted-remaining(row),energy=row.entity.energy}
            row.orientations[#row.orientations+1]={elapsed=elapsed,orientation=row.entity.orientation}
        end
    end
    if elapsed==1500 then
        storage.done=true
        local report={ballistic=settings.startup["ei-ballistic-divergence"].value,started=storage.started,elapsed=elapsed,errors=storage.errors,cases={}}
        for _,row in ipairs(storage.rows) do
            report.cases[#report.cases+1]={id=row.id,variant=row.variant,heading=row.heading,first_shot=row.first_shot,
                shots=row.shots,consumed=row.inserted-remaining(row),curve=row.curve,captures=row.captures,
                ammo_samples=row.ammo_samples,orientations=row.orientations}
        end
        helpers.write_file("minigun-timing-report.json",helpers.table_to_json(report),false)
        game.set_wait_for_screenshots_to_finish()
    end
end)

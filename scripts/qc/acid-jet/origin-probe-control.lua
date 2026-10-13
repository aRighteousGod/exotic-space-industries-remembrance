-- QC-only canonical turret motion and same-tick source/capture evidence.
local config=require("test-config")
local variants=require("origin-variants")
local directions={defines.direction.north,defines.direction.east,defines.direction.south,defines.direction.west}

---@param case table Canonical turret, target, placement and capture history.
---@param tick integer Fixture-relative tick.
---@param from_source boolean True when captured inside native delivery callback.
local function capture(case,tick,from_source)
    if not config.visual then return end
    local key=case.key.."-"..tick..(from_source and "-launch" or "")
    local p=case.turret.position
    game.take_screenshot{surface=case.turret.surface,position={p.x,p.y-.3},resolution={512,512},zoom=4,
        path="origin/"..key..".png",show_gui=false,show_entity_info=false,anti_alias=false,force_render=true,daytime=0}
    storage.origin.captures[#storage.origin.captures+1]={key=key,tick=tick,case=case.key,
        orientation=case.turret.orientation,target=case.target.valid and case.target.position or nil,
        source=case.last_source,source_callback=from_source,position=p,zoom=4,resolution={512,512},camera={p.x,p.y-.3}}
end

---@param tick integer Setup event tick, never read during module loading.
local function setup(tick)
    local root={start=tick,cases={},by_entity={},sources={},captures={},ticks={}}
    storage.origin=root
    helpers.write_file("origin-final-data.json",helpers.table_to_json(prototypes.mod_data["acid-origin-final-data"].data),false)
    helpers.write_file("origin-mods.json",helpers.table_to_json(script.active_mods),false)
    local s=game.create_surface("acid-canonical-origin",{width=16384,height=1024,autoplace_controls={},
        autoplace_settings={entity={treat_missing_as_default=false},decorative={treat_missing_as_default=false}}})
    s.freeze_daytime=true;s.daytime=0
    for i=1,(config.origin_variants and (6+#variants*5) or 6) do
        local pose=i>6 and ((i-7)%5+1) or i
        local variant=i>6 and variants[math.floor((i-7)/5)+1].name or nil
        local facing=pose<=4 and pose or 2
        local p={x=(i-1)*120-300,y=0}
        s.request_to_generate_chunks(p,2);s.force_generate_chunk_requests()
        for _,e in pairs(s.find_entities_filtered{area={{p.x-55,-55},{p.x+55,55}},type={"unit","unit-spawner","tree"}}) do e.destroy() end
        local tiles={}
        for x=p.x-50,p.x+50 do for y=-50,50 do tiles[#tiles+1]={name="lab-dark-1",position={x,y}} end end
        s.set_tiles(tiles)
        local turret=s.create_entity{name=variant and ("acid-origin-"..variant) or "ei-acidthrower-turret",position=p,force="player",direction=directions[facing]}
        p=turret.position
        local angle=math.rad((facing-1)*90+(pose==5 and 23 or -47.9))
        local target=s.create_entity{name="acid-origin-target",position={p.x+24*math.sin(angle),p.y-24*math.cos(angle)},force="enemy"}
        target.active=false
        turret.set_fluid(1,{name="sulfuric-acid",amount=100});turret.set_fluid(2,{name="sulfuric-acid",amount=100})
        turret.shooting_target=target
        local pose_key=pose<=4 and ("sweep-"..facing) or (pose==5 and "static-ESE" or "retarget-E")
        local case={key=variant and (variant.."-"..pose_key) or pose_key,
            turret=turret,target=target,facing=facing,index=i,pose=pose,position=p}
        root.cases[#root.cases+1]=case;root.by_entity[turret.unit_number]=case
    end
end

script.on_init(function()
    if remote.interfaces.freeplay then
        remote.call("freeplay","set_skip_intro",true);remote.call("freeplay","set_disable_crashsite",true)
    end
end)
script.on_event(defines.events.on_script_trigger_effect,function(event)
    if event.effect_id~="acid-origin-source" then return end
    local root=storage.origin
    local case=root and event.source_entity and root.by_entity[event.source_entity.unit_number]
    if not case then return end
    local tick=event.tick-root.start
    local row={tick=tick,case=case.key,position=event.source_position,orientation=case.turret.orientation,
        target=case.target.valid and case.target.position or nil}
    root.sources[#root.sources+1]=row;case.last_source=row
    case.first_source=case.first_source or tick
    capture(case,tick,true)
end)
script.on_event(defines.events.on_tick,function(event)
    if not storage.origin then setup(event.tick) end
    local root=storage.origin;local tick=event.tick-root.start
    for _,case in ipairs(root.cases) do
        if tick%30==0 then
            case.turret.set_fluid(1,{name="sulfuric-acid",amount=100});case.turret.set_fluid(2,{name="sulfuric-acid",amount=100})
        end
        if case.pose<=4 and tick>=200 and tick<=600 then
            local angle=math.rad((case.facing-1)*90-47.9+95.8*(tick-200)/400)
            case.target.teleport({case.position.x+24*math.sin(angle),case.position.y-24*math.cos(angle)})
        end
        if case.index==6 and tick==300 then
            case.target.destroy()
            local angle=math.rad(137.9)
            case.target=case.turret.surface.create_entity{name="acid-origin-target",position={case.position.x+24*math.sin(angle),case.position.y-24*math.cos(angle)},force="enemy"}
            case.target.active=false;case.turret.shooting_target=case.target
        end
        if tick>=180 and tick<=680 then
            root.ticks[#root.ticks+1]={tick=tick,case=case.key,orientation=case.turret.orientation,
                source_tick=case.last_source and case.last_source.tick,target=case.target.valid and case.target.position or nil}
            if tick%8==0 or (case.index==6 and tick>=298 and tick<=370 and tick%2==0) or (tick>=220 and tick<=235) then capture(case,tick,false) end
        end
        if case.first_source and tick>case.first_source and tick<=case.first_source+9 then capture(case,tick,false) end
        if tick==650 then case.turret.active=false end
    end
    if tick==800 then
        local cases={}
        for _,case in ipairs(root.cases) do cases[#cases+1]={key=case.key,prototype=case.turret.name,position=case.position,facing=case.facing} end
        helpers.write_file("origin-probe.json",helpers.table_to_json{profile=settings.startup["ei-thrower-performance-profile"].value,
            cases=cases,sources=root.sources,captures=root.captures,ticks=root.ticks},false)
    end
end)

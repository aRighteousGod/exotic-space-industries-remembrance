-- Isolated engine receipts; all state and scheduling belong to this QC helper.
local config = require("test-config")
if config.phase=="legacy-seed" or config.phase=="legacy-load" then require("upgrade");return end
if config.phase=="player" then require("player");return end
if config.phase=="accept" or config.phase=="visual" then
    require("acceptance")
    return
end
local facings={"north","northeast","east","southeast","south","southwest","west","northwest"}

local function setup(tick)
    helpers.write_file("final-data.json",helpers.table_to_json(prototypes.mod_data["acid-eight-final"].data),false)
    if config.phase=="baseline" then storage.acid_eight={start=tick,entities={},records={}}; return end
    local s=game.create_surface("acid-eight-layout",{width=256,height=256,autoplace_settings={
        entity={treat_missing_as_default=false},decorative={treat_missing_as_default=false}}})
    s.request_to_generate_chunks({0,0},4);s.force_generate_chunk_requests()
    for _,e in pairs(s.find_entities()) do e.destroy() end
    local tiles={}
    for x=-100,100 do for y=-100,100 do tiles[#tiles+1]={name="lab-dark-1",position={x,y}} end end
    s.set_tiles(tiles);s.freeze_daytime=true;s.daytime=0
    local root={start=tick,entities={},records={}}
    storage.acid_eight=root
    local name=config.phase=="probe" and "acid-eight-probe" or "ei-acidthrower-turret"
    for i,facing in ipairs(facings) do
        local e=assert(s.create_entity{name=name,position={(i-4.5)*12,0},direction=defines.direction[facing],force="player"})
        local row={facing=facing,direction=e.direction,position=e.position,bounds=e.bounding_box,fluids_count=e.fluids_count,ports={}}
        for index,port in ipairs(e.get_fluid_box_pipe_connections(1)) do
            local p=assert(s.create_entity{name="pipe",position=port.target_position,force="player"})
            p.insert_fluid{name="sulfuric-acid",amount=100}
            row.ports[index]={position=port.position,target_position=port.target_position,pipe=p.position}
        end
        root.entities[#root.entities+1]=e;root.records[#root.records+1]=row
    end
end

script.on_init(function()
    if remote.interfaces.freeplay then
        remote.call("freeplay","set_skip_intro",true)
        remote.call("freeplay","set_disable_crashsite",true)
    end
end)
script.on_event(defines.events.on_tick,function(event)
    if not storage.acid_eight then setup(event.tick) end
    local root=storage.acid_eight
    if event.tick-root.start==120 then
        for i,e in ipairs(root.entities) do
            local row=root.records[i]
            row.fluid=e.get_fluid(1)
            assert(row.fluid and row.fluid.name=="sulfuric-acid" and row.fluid.amount>0,"Fluid must enter turret")
            for j,port in ipairs(e.get_fluid_box_pipe_connections(1)) do
                assert(port.target and port.target.valid,"Every native port must join its adjacent pipe")
                row.ports[j].connected=port.target.name
            end
            if config.phase=="layouts" then
                row.neighbours={pipes={},walls={}}
                for _,port in ipairs(e.get_fluid_box_pipe_connections(1)) do
                    local dx,dy=port.target_position.x-port.position.x,port.target_position.y-port.position.y
                    local x,y=port.target_position.x+dx,port.target_position.y+dy
                    for _,p in ipairs{{x,y},{x-dy,y+dx},{x+dy,y-dx}} do
                        assert(e.surface.can_place_entity{name="pipe",position=p,force="player"})
                        local pipe=assert(e.surface.create_entity{name="pipe",position=p,force="player"})
                        row.neighbours.pipes[#row.neighbours.pipes+1]=pipe.position
                    end
                end
                for _,dx in ipairs{-2,2} do for _,dy in ipairs{-2,2} do
                    local p={e.position.x+dx,e.position.y+dy}
                    if e.surface.can_place_entity{name="stone-wall",position=p,force="player"} then
                        local wall=assert(e.surface.create_entity{name="stone-wall",position=p,force="player"})
                        row.neighbours.walls[#row.neighbours.walls+1]=wall.position
                    end
                end end
                local p=e.get_fluid_box_pipe_connections(1)
                assert(p[1].target.insert_fluid{name="sulfuric-acid",amount=10}==10)
                local removed=p[2].target.remove_fluid_segment_fluid(1,10)
                assert(removed and removed.name=="sulfuric-acid" and removed.amount==10,"Through-manifold fluid transfer")
            end
        end
        if config.phase=="ports" then
            for i,e in ipairs(root.entities) do
                game.take_screenshot{surface=e.surface,position={e.position.x,e.position.y-.3},resolution={512,512},zoom=4,
                    path="ports/connected-"..i..".png",daytime=0,show_gui=false,anti_alias=false,force_render=true}
            end
        elseif config.phase~="layouts" then helpers.write_file("ports.json",helpers.table_to_json{passed=true,engine=script.active_mods.base,records=root.records},false) end
    end
    if config.phase=="ports" and event.tick-root.start==140 then
        for _,e in ipairs(root.entities) do for _,port in ipairs(e.get_fluid_box_pipe_connections(1)) do port.target.destroy() end end
    end
    if config.phase=="ports" and event.tick-root.start==150 then
        for i,e in ipairs(root.entities) do
            game.take_screenshot{surface=e.surface,position={e.position.x,e.position.y-.3},resolution={512,512},zoom=4,
                path="ports/capped-"..i..".png",daytime=0,show_gui=false,anti_alias=false,force_render=true}
        end
        game.set_wait_for_screenshots_to_finish()
        helpers.write_file("ports.json",helpers.table_to_json{passed=true,engine=script.active_mods.base,records=root.records},false)
    end
    if config.phase=="layouts" and event.tick-root.start==150 then
        for i,e in ipairs(root.entities) do for _,day in ipairs{0,.5} do
            game.take_screenshot{surface=e.surface,position=e.position,resolution={640,640},zoom=2,
                path="layouts/"..i.."-"..day..".png",daytime=day,show_gui=false,show_entity_info=false,force_render=true}
        end end
        game.set_wait_for_screenshots_to_finish()
        helpers.write_file("ports.json",helpers.table_to_json{passed=true,engine=script.active_mods.base,records=root.records},false)
    end
end)

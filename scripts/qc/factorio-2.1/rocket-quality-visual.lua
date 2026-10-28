-- Native graphical observer; the lifecycle suite remains the acceptance owner.
do
    local previous=script.get_event_handler(defines.events.on_tick)
    local frames={}
    local viewer
    script.on_event(defines.events.on_tick,function(event)
        previous(event)
        local player=game.get_player(1)
        if not (player and player.connected and storage.cases) then return end
        game.speed=8
        if not viewer then
            player.set_controller{type=defines.controllers.spectator}
            player.teleport({0,0},storage.cases[1].surface)
            viewer=true
        end
        for _,row in ipairs(storage.cases) do
            if row.style=="hybrid" and (row.name=="hybrid" or row.quality) or row.name=="cinematic" then
                local frame
                if event.tick==row.ignition_tick then frame="ignition" end
                if row.ascent_tick then
                    local age=event.tick-row.ascent_tick-239
                    if age==0 or age==150 or age==300 then frame="plume-"..age end
                end
                if frame then
                    local position=row.rocket and row.rocket.valid and row.rocket.position or row.silo.position
                    local path="rocket-quality/"..row.name.."-"..frame..".png"
                    game.take_screenshot{player=player,surface=row.surface,position={0,position.y-6},
                        resolution={960,800},zoom=.85,show_gui=false,hide_clouds=true,hide_fog=true,
                        force_render=true,path=path}
                    frames[#frames+1]={path=path,case=row.name,phase=frame,tick=event.tick,
                        ignition=row.ignition_tick,clamp_release=row.ascent_tick,native_position=position}
                end
            end
        end
        if storage.done then
            assert(#frames==24,"Missing native quality render frames: "..#frames)
            helpers.write_file("rocket-quality-rendered.json",helpers.table_to_json{passed=true,frames=frames,
                checks=storage.checks,native_input=false,audio=false},false)
            script.on_event(defines.events.on_tick,previous)
        end
    end)
end

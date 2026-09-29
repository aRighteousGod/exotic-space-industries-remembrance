-- Disposable QC only; tests orientation while native scanning stays inhibited.
script.on_init(function() storage.pending=true end)
---@param event EventData.on_tick
script.on_event(defines.events.on_tick,function(event)
    if storage.pending then
        storage.pending=nil
        storage.started=event.tick
        local surface=game.surfaces[1]
        surface.request_to_generate_chunks({0,0},1)
        surface.force_generate_chunk_requests()
        surface.daytime=0
        surface.freeze_daytime=true
        storage.radar=assert(surface.create_entity{name="radar-art-qc",position={0,0},force="player"})
        storage.radar.disabled_by_script=true
        storage.head=rendering.draw_animation{animation="radar-art-head",surface=surface,target=storage.radar,
            animation_speed=0,animation_offset=0,render_layer="object"}
        storage.results={}
        return
    end
    local elapsed=event.tick-storage.started
    local radar=storage.radar
    if not (radar and radar.valid) then error("Fixture radar invalid") end
    if elapsed>=10 and elapsed<=70 and (elapsed-10)%20==0 then
        local orientation=math.floor((elapsed-10)/20)/4
        local ok,err=pcall(function() storage.head.animation_offset=orientation*64 end)
        storage.results[#storage.results+1]={requested=orientation,ok=ok,error=not ok and tostring(err) or nil,
            actual=storage.head.animation_offset,disabled=radar.disabled_by_script}
    elseif elapsed>=15 and elapsed<=75 and (elapsed-15)%20==0 then
        local index=math.floor((elapsed-15)/20)
        storage.results[#storage.results].after_five_ticks=storage.head.animation_offset
        game.take_screenshot{surface=radar.surface,position={0,-0.5},resolution={512,512},zoom=3,
            path="orientation/heading-"..index..".png",show_gui=false,show_entity_info=false}
    elseif elapsed==90 then
        helpers.write_file("orientation/result.json",helpers.table_to_json({results=storage.results,version=script.active_mods.base}),false)
    end
end)

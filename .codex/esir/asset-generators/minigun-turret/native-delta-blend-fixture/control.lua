-- Isolated bounded screenshot probe; no production runtime changes.
-- Contract and lifecycle: README.md#contract.
local contract=require("contract")
script.on_init(function()
    if remote.interfaces.freeplay then
        remote.call("freeplay","set_skip_intro",true)
        remote.call("freeplay","set_disable_crashsite",true)
    end
    storage.started=game.tick -- on_init boundary has no event tick.
    storage.surface=game.create_surface("mg-native-delta",{autoplace_controls={},
        autoplace_settings={entity={treat_missing_as_default=false},decorative={treat_missing_as_default=false}}})
    storage.surface.request_to_generate_chunks({0,0},2);storage.surface.force_generate_chunk_requests()
    storage.surface.freeze_daytime=true;storage.surface.daytime=0
    storage.surface.create_entity{name="mg-delta-background",position={0,0}}
    storage.foreground=storage.surface.create_entity{name="mg-delta-foreground",position={0,0}}
    storage.fx=storage.surface.create_entity{name="mg-delta-fx",position={0,0}}
    storage.captures={}
end)
script.on_event(defines.events.on_tick,function(event)
    if storage.done then return end
    local player=game.get_player(1)
    if player and not storage.viewer then
        player.set_controller{type=defines.controllers.spectator};player.teleport({0,0},storage.surface);storage.viewer=true
    end
    local elapsed=event.tick-storage.started
    local step=elapsed-contract.first_tick
    if step>=0 and step<#contract.cases*8 then
        local case=contract.cases[math.floor(step/8)+1]
        local phase=step%8
        local variant=phase<4 and "candidate" or "reference"
        if phase==0 or phase==4 then
            if storage.entity and storage.entity.valid then storage.entity.destroy() end
            storage.surface.daytime=case.daytime
            local kind=(variant=="reference" or case.control) and "reference" or case.variant
            if case.identity then kind="identity-"..kind end
            local position={case.offset/32,case.offset/32}
            storage.entity=assert(storage.surface.create_entity{name="mg-delta-"..case.surface.."-"..kind,
                position=position,force="player"})
            storage.entity.active=false
            storage.foreground.teleport(position);storage.fx.teleport(position)
        elseif phase==3 or phase==7 then
            local path="minigun-native-delta/"..case.id.."/"..variant..".png"
            game.take_screenshot{surface=storage.surface,position={0,0},resolution=case.resolution,zoom=case.zoom,
                daytime=case.daytime,anti_alias=false,show_gui=false,show_entity_info=false,hide_clouds=true,
                hide_fog=true,force_render=true,path=path}
            storage.captures[#storage.captures+1]={case_id=case.id,variant=variant,path=path,
                elapsed=elapsed,surface_darkness=storage.surface.darkness,surface_daytime=storage.surface.daytime,
                prototype_name=storage.entity.name,position=storage.entity.position}
        end
    end
    if elapsed==contract.finish_tick then
        helpers.write_file("minigun-native-color-report.json",helpers.table_to_json({schema=contract.schema,
            cases=contract.cases,captures=storage.captures,production_approved=false}),false)
        game.set_wait_for_screenshots_to_finish();storage.done=true
    end
end)

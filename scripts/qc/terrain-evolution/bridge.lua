-- Isolated fixture only: appended to the staged ESIR control script.
local tq=require("scripts/control/terrain-evolution")
local tq_config=require("lib/terrain-evolution-config")
local tq_policy=require("lib/terrain-policy")
local tq_calendar=require("scripts/control/terrain-calendar")
local tq_stress=require("__zzz-esir-terrain-qc__.stress")
tq_stress.configure(tq)
remote.add_interface("ei-terrain-stress-qc",{
    prepare=tq_stress.prepare,chunks=tq_stress.chunks,fill_active=tq_stress.fill_active,burst=tq_stress.burst,start=tq_stress.start,stop=tq_stress.stop,
})
remote.add_interface("ei-terrain-qc",{
    defaults=function() return tq_config.resolve({}, {["ei-terrain-evolution-enabled"]={value=true}}) end,
    resolve=function(values) return tq_config.resolve(values,{["ei-terrain-evolution-enabled"]={value=true}}) end,
    compile=function() return tq_policy.compile(prototypes.tile) end,
    calculate=tq_calendar.calculate_parameters,
    snapshot=function(index) return tq.snapshot(game.get_surface(index),game.tick) end,
    override=function(index,name,value) return tq.set_override(game.get_surface(index),name,value,game.tick) end,
    phase=function(index,phase) return tq.set_season_phase(game.get_surface(index),phase,game.tick) end,
    reset=function(index) return tq.reset_overrides(game.get_surface(index),game.tick) end,
    enqueue=function(index,p,cause,extra) return tq.enqueue_scar(game.get_surface(index),p,cause,game.tick,extra) end,
    depleted=function(entity) tq.on_resource_depleted{entity=entity,tick=game.tick} end,
    gaia_positive_point=function(index)
        local surface=game.get_surface(index);local root=storage.ei.terrain_evolution
        local entry=root.surfaces[index];local radius=root.anchor_extent+32
        for attempt=0,31 do
            local p={x=10000+attempt*256,y=10000}
            surface.request_to_generate_chunks(p,1);surface.force_generate_chunk_requests()
            local cell=math.floor(p.x/32)..":"..math.floor(p.y/32)
            if not entry.protection_saturated and not entry.protected[cell]
                and #surface.find_entities_filtered{name="ei-artifact-flag",area={{p.x-radius,p.y-radius},{p.x+radius,p.y+radius}},limit=1}==0 then return p end
        end
        error("No unprotected positive Gaia fixture location; retain authored protection")
    end,
    history=function(index,x,y)
        local root=storage.ei.terrain_evolution;local i=root.history.index[index..":"..x..":"..y]
        if not i then return nil end
        local r=root.history.items[i];return {origin=r.origin,expected=r.expected,depth=#r.path,cause=r.cause}
    end,
    release=function() tq_calendar.release(storage.ei.terrain_evolution) end,
    pending=function() return #storage.ei.terrain_evolution.pending.items end,
    enablement=function() return tq.has_tick_work(game.tick+100000) end,
    calendar=function(index) return tq_calendar.snapshot(storage.ei.terrain_evolution,game.get_surface(index),game.tick) end,
    gui=function(index)
        ei_admin_tools.on_configuration_changed(game.tick)
        local player=game.get_player(index)
        if not player then return false end
        local handler=commands.commands["ei-admin"]
        return handler~=nil
    end,
})

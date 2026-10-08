-- Appended only to the private staged ESIR control script.
local persistence_terrain=require("scripts/control/terrain-evolution")
local persistence_calendar=require("scripts/control/terrain-calendar")
local function persistence_same(a,b)
    if not a or not b then return false end
    for _,k in ipairs({"dusk","evening","morning","dawn"}) do if math.abs(a[k]-b[k])>1e-8 then return false end end
    return true
end
local function persistence_record(root,surface,tick)
    return persistence_calendar.snapshot(root,surface,tick)
end
remote.add_interface("ei-terrain-persistence-qc",{
    prepare=function(tick)
        local s=game.surfaces.nauvis
        local g=game.planets.gleba.create_surface()
        local v=game.planets.vulcanus.create_surface()
        local f=game.planets.fulgora.create_surface()
        persistence_terrain.initialize(tick)
        local root=storage.ei.terrain_evolution
        persistence_calendar.release(root)
        root.config.cold_chunks=0
        local baseline={dusk=.25,evening=.45,morning=.55,dawn=.75}
        for _,surface in ipairs({s,g,v,f}) do
            surface.daytime_parameters=baseline
            surface.freeze_daytime=false;surface.always_day=false
            for _,pair in ipairs({{"degradation",false},{"tree_stress",false},{"tree_regrowth",false},{"recovery",false},{"seasonal_daylight",true},{"hazard_radius",1},{"protection_buffer",0}}) do
                assert(persistence_terrain.set_override(surface,pair[1],pair[2],tick))
            end
        end
        local function own(surface)
            persistence_calendar.set_phase(root,surface,.25,tick)
            root.calendar.order={surface.index};root.calendar.cursor=1
            root.calendar.records[surface.index].next_tick=0
            persistence_calendar.service(root,tick,persistence_terrain.resolve_config)
        end
        own(s);own(g);own(v)
        g.freeze_daytime=true
        local external=v.daytime_parameters;external.evening=external.evening+.001
        v.daytime_parameters=external
        root.calendar.records[v.index].next_tick=0
        persistence_calendar.service(root,tick,persistence_terrain.resolve_config)
        f.daytime_parameters={dusk=.2,evening=.4,morning=.6,dawn=.8}
        persistence_calendar.initialize(root,tick)
        storage.__terrain_persistence={baseline=baseline,surfaces={s=s,g=g,v=v,f=f},external=external,
            fulgora=f.daytime_parameters,rotation=s.ticks_per_day,solar=s.solar_power_multiplier}
        s.request_to_generate_chunks({768,768},1);s.force_generate_chunk_requests()
        for _,e in pairs(s.find_entities_filtered{area={{760,760},{778,778}}}) do if e.valid and e.type~="character" then e.destroy() end end
        local tiles={}
        for x=764,772 do for y=764,772 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
        s.set_tiles(tiles,false,false,false,true)
    end,
    scar=function(tick)
        local p=storage.__terrain_persistence
        p.admitted=persistence_terrain.enqueue_scar(p.surfaces.s,{x=768,y=768},"thermal",tick)
    end,
    capture=function(tick)
        local root=storage.ei.terrain_evolution
        local p=storage.__terrain_persistence
        p.tick=tick;p.phase=persistence_record(root,p.surfaces.s,tick).phase
        p.period=persistence_record(root,p.surfaces.s,tick).period_ticks
        p.history_count=#root.history.items
        p.history={}
        for _,h in ipairs(root.history.items) do p.history[#p.history+1]={id=h.id,origin=h.origin,expected=h.expected,depth=#h.path} end
        p.owned=p.surfaces.s.daytime_parameters;p.frozen=p.surfaces.g.daytime_parameters
        return {all_pass=p.admitted and p.history_count>0 and persistence_record(root,p.surfaces.s,tick).owns_daylight
            and persistence_record(root,p.surfaces.g,tick).owns_daylight
            and persistence_record(root,p.surfaces.v,tick).status=="external-control",history=p.history_count,tick=tick}
    end,
    verify=function(tick)
        local root=storage.ei.terrain_evolution
        local p=storage.__terrain_persistence
        local disabled=not settings.startup["ei-terrain-evolution-enabled"].value
        local cases={}
        local function check(name,pass,detail) cases[name]={pass=pass==true,detail=detail} end
        check("saved-history-present",p.history_count>0 and #root.history.items==p.history_count)
        for _,h in ipairs(p.history) do
            local index=root.history.index[h.id];local current=index and root.history.items[index]
            check("history-path-"..h.id,current and current.origin==h.origin and current.expected==h.expected and #current.path==h.depth)
        end
        local now=persistence_record(root,p.surfaces.s,tick)
        local expected=(p.phase+(tick-p.tick)/p.period)%1
        check("analytic-phase-survives-save",math.abs(now.phase-expected)<1e-10,{actual=now.phase,expected=expected})
        check("frozen-flag-preserved",p.surfaces.g.freeze_daytime)
        check("external-tuple-preserved",persistence_same(p.surfaces.v.daytime_parameters,p.external))
        check("fulgora-tuple-preserved",persistence_same(p.surfaces.f.daytime_parameters,p.fulgora))
        check("rotation-solar-preserved",p.surfaces.s.ticks_per_day==p.rotation and p.surfaces.s.solar_power_multiplier==p.solar)
        if disabled then
            check("owned-restored-on-startup-disable",persistence_same(p.surfaces.s.daytime_parameters,p.baseline))
            check("frozen-owned-restored-on-startup-disable",persistence_same(p.surfaces.g.daytime_parameters,p.baseline))
            check("disabled-idle",not persistence_terrain.has_tick_work(tick+100000))
            check("disabled-detaches-active",#root.active.items==0 and #root.pending.items==0)
            check("disabled-rejects-admission",not persistence_terrain.enqueue_scar(p.surfaces.s,{x=0,y=0},"thermal",tick))
        else
            check("owned-tuple-survives-save",persistence_same(p.surfaces.s.daytime_parameters,p.owned) and now.owns_daylight)
            check("frozen-owned-tuple-survives-save",persistence_same(p.surfaces.g.daytime_parameters,p.frozen))
            check("external-suspension-survives-save",persistence_record(root,p.surfaces.v,tick).status=="external-control")
        end
        local all,count=true,0
        for _,result in pairs(cases) do count=count+1;all=all and result.pass end
        return {all_pass=all,count=count,cases=cases,startup_disabled=disabled,checkpoint_tick=p.tick,verify_tick=tick}
    end,
})

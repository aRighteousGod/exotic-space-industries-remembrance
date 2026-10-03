-- Native lifecycle cases run after repair fixtures, in the disposable save only.
local model={}
local placement=require("placement")
local callbacks=require("world-callbacks")
local function call(name,...) return remote.call("esir-admin-qc",name,...) end
local function action(player,name,args,tick) return call("execute",player.index,name,args,tick) end

function model.start(player,tick,check)
    local ok,message=action(player,"ban",{player_name=string.upper(player.name)},tick)
    check("case-variant self ban is rejected",not ok and message=="Self-moderation is not available.",message)
    local force=game.create_force("ei-admin-research-qc")
    force.research_all_technologies(false)
    local infinite
    for _,tech in pairs(force.technologies) do
        if tech.prototype.max_level==4294967295 and tech.prototype.enabled then infinite=tech;break end
    end
    assert(infinite,"No native infinite technology found")
    infinite.researched=false;infinite.enabled=true
    force.research_queue={infinite,infinite,infinite}
    check("native infinite queued",force.current_research==infinite,infinite.name)
    storage.admin_feature_qc={start=tick,player=player.index,force=force.name,technology=infinite.name,level=infinite.level}
    action(player,"instant_research",{force_index=force.index,enabled=true},tick)
end

function model.tick(tick,check)
    local state=storage.admin_feature_qc;if not state or state.done then return false end
    local elapsed=tick-state.start
    local player=game.get_player(state.player);local force=game.forces[state.force]
    if state.callbacks then
        if callbacks.tick(tick,check) then state.done=true;return true end
        return false
    end
    if state.world_gui then
        local done,entries=call("world_gui_finish",player.index,tick)
        for _,entry in ipairs(entries) do check(entry.name,entry.ok,entry.detail) end
        if done then callbacks.start(player,state.placement.surface,tick,check);state.callbacks=true end
        return false
    end
    if state.placement then
        if placement.finish(state.placement,tick,check) then
            for _,entry in ipairs(call("world_gui_start",player.index,state.placement.surface.index,tick)) do check(entry.name,entry.ok,entry.detail) end
            state.world_gui=true
        end
        return false
    end
    local tech=force.technologies[state.technology]
    if elapsed==8 then
        check("infinite automation completes one level",tech.level==state.level+1,tech.level)
        action(player,"finish_research",{force_index=force.index},tick)
    elseif elapsed==14 then
        check("explicit finish completes one more infinite level",tech.level==state.level+2,tech.level)
        force.research_queue={}
        force.research_queue={tech}
    elseif elapsed==20 then
        check("explicit infinite reselection rearms one level",tech.level==state.level+3,tech.level)
        action(player,"instant_research",{force_index=force.index,enabled=false},tick)
        force.research_queue={}
        local finite
        for _,candidate in pairs(force.technologies) do
            if candidate.prototype.max_level==1 and candidate.prototype.enabled then finite=candidate;break end
        end
        assert(finite,"No finite technology found")
        finite.researched=false;finite.enabled=true;state.finite=finite.name
        force.research_queue={finite}
        action(player,"instant_research",{force_index=force.index,enabled=true},tick)
        player.admin=false
    elseif elapsed==25 then
        local finite=force.technologies[state.finite]
        check("queued research rejects demoted actor",not finite.researched)
        player.admin=true
        action(player,"instant_research",{force_index=force.index,enabled=true},tick)
    elseif elapsed==30 then
        local finite=force.technologies[state.finite]
        check("finite instant research completes",finite.researched)
        action(player,"instant_research",{force_index=force.index,enabled=false},tick)
        local disabled
        for _,candidate in pairs(force.technologies) do
            if not candidate.prototype.enabled then disabled=candidate;break end
        end
        assert(disabled,"No prototype-disabled technology found")
        disabled.researched=false
        action(player,"research_all",{force_index=force.index},tick)
        check("research all preserves prototype-disabled technology",not disabled.researched,disabled.name)
        state.existing=game.surfaces.nauvis
        state.existing.peaceful_mode=false
        call("peaceful_default",true)
        local name
        for candidate,planet in pairs(game.planets) do
            if candidate~="gaia" and not candidate:find("^ei%-admin%-") and not planet.surface then name=candidate;break end
        end
        assert(name,"No uncreated optional/native planet remains for fixture")
        state.new_planet=name
        game.planets[name].create_surface()
        state.helper=game.create_surface("ei-admin-qc-nonplanet",{width=64,height=64})
    elseif elapsed==34 then
        check("peaceful default leaves existing surface",not state.existing.peaceful_mode)
        check("new planetary surface inherits peaceful default",game.planets[state.new_planet].surface.peaceful_mode)
        check("nonplanet helper ignores peaceful default",not state.helper.peaceful_mode)
        local gaia=game.planets.gaia.surface
        assert(gaia,"Missing Gaia fixture surface")
        action(player,"planet_peaceful",{planet="gaia",enabled=false},tick)
        action(player,"planet_spawning",{planet="gaia",enabled=false},tick)
        state.gaia_index=gaia.index
        call("reforge",tick)
    elseif elapsed>=35 then
        if state.effects then
            local effects=state.effects
            if call("rupture_pending") then
                assert(tick-effects.submitted<240,"Environmental rupture did not drain within 240 ticks")
                return false
            end
            if effects.victim then
                check("native damaging rupture "..effects.label,not effects.victim.valid or effects.victim.health<effects.health)
                if effects.victim.valid then effects.victim.destroy() end
                effects.victim=nil
            end
            local families={"oil","gas","exotic","thermal","lava","chemical","cryo","data"}
            local energies={20,100,500}
            local index=effects.index
            if index>24 then
                local gleba=game.planets.gleba.surface or game.planets.gleba.create_surface()
                gleba.request_to_generate_chunks({0,0},0);gleba.force_generate_chunk_requests()
                for _,surface in ipairs({game.surfaces.nauvis,gleba}) do
                    local before=surface.get_pollution({0,0})
                    local ok=action(player,"add_pollution",{surface_index=surface.index,position={0,0},amount=10000},tick)
                    check("native pollutant creation "..surface.pollutant_type.name,ok and surface.get_pollution({0,0})>=before+9999)
                end
                state.placement=placement.start(player,force,tick,check)
                return false
            end
            local family=families[math.floor((index-1)/3)+1];local energy=energies[(index-1)%3+1]
            local origin={x=((index-1)%6)*32-80,y=math.floor((index-1)/6)*32-48}
            local victim=effects.surface.create_entity{name="iron-chest",position={origin.x+1,origin.y},force=player.force}
            assert(victim,"Rupture fixture victim creation failed")
            effects.victim=victim;effects.health=victim.health;effects.label=family.." "..energy.."MJ"
            local ok,message=action(player,"rupture",{surface_index=effects.surface.index,position=origin,rupture_family=family,energy=energy},tick)
            check("native rupture admission "..effects.label,ok,message)
            effects.index=index+1;effects.submitted=tick
            return false
        end
        local gaia=game.planets.gaia.surface
        if gaia and gaia.index~=state.gaia_index and not call("reforge_pending") then
            check("Gaia reforge replaces planetary surface",true,gaia.index)
            check("Gaia explicit peaceful override survives reforge",not gaia.peaceful_mode)
            check("Gaia explicit spawning override survives reforge",gaia.no_enemies_mode)
            for _,entry in ipairs(call("targeting",player.index,tick)) do check(entry.name,entry.ok,entry.detail) end
            local surface=game.create_surface("ei-admin-qc-effects",{width=256,height=256,
                autoplace_settings={entity={treat_missing_as_default=false},decorative={treat_missing_as_default=false}}})
            surface.request_to_generate_chunks({0,0},4);surface.force_generate_chunk_requests()
            local tiles={};for x=-100,100 do for y=-70,70 do tiles[#tiles+1]={name="refined-concrete",position={x,y}} end end
            surface.set_tiles(tiles,true)
            state.effects={surface=surface,index=1}
        elseif elapsed>=650 then
            check("Gaia reforge replaces planetary surface",false,"Timed out or intact-surface fast path")
            state.done=true
            return true
        end
    end
    return false
end
return model

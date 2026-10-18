-- Executes inside the staged main-mod sandbox, alongside the actual GUI owner.
-- Fixture setup explicitly creates worlds; report opening is then required never
-- to create one. All mutations below are confined to the copied fixture save.
local options=require("__zzz-esir-field-report-qc__/config")
local model={}
local names={"nauvis","gaia","vulcanus","gleba","fulgora","aquilo"}
local function state()
    storage.ei=storage.ei or {}
    storage.ei.field_report_qc=storage.ei.field_report_qc or {checks={},stats={calls=0,writes=0,max_writes=0,max_inspections=0,
        snapshots=0,compositions=0,fulgora_observations=0,instrumented_services=0,profiled_services=0},case_index=0,captures={}}
    return storage.ei.field_report_qc
end
local function check(name,ok,detail)
    local s=state();s.checks[#s.checks+1]={name=name,ok=not not ok,detail=detail}
    assert(ok,name..(detail and ": "..tostring(detail) or ""))
end
local function count_surfaces()
    local count=0;for _ in pairs(game.surfaces) do count=count+1 end;return count
end
local function session(player)
    local root=storage.ei.ecology_gui;return root and root.players[player.index]
end
local function dispatch(name,player,element,tick)
    local receiver=assert(script.get_event_handler(defines.events[name]),name.." receiver missing")
    return receiver{name=defines.events[name],player_index=player.index,element=element,tick=tick,
        button=defines.mouse_button_type.left,alt=false,control=false,shift=false}
end
local function find_action(root,wanted)
    if root.tags.action==wanted then return root end
    for _,child in pairs(root.children or {}) do local found=find_action(child,wanted);if found then return found end end
end
local function row_by_key(p,key)
    for _,row in ipairs(p.rows[1]) do if row.key==key then return row end end
end
local function cycle_rendered(p,last)
    if row_by_key(p,"day").signature~=helpers.table_to_json(last.values.day) then return false end
    for i=1,4 do
        for _,prefix in ipairs{"day_width_","day_visible_"} do
            if row_by_key(p,prefix..i).signature~=tostring(last.values[prefix..i]) then return false end
        end
    end
    return true
end
local function close_monitor(player,tick)
    local root=storage.ei.rebuild_monitor;local p=root and root.players[player.index]
    if p and p.root and p.root.valid then
        local button=find_action(p.root,"close");if button then dispatch("on_gui_click",player,button,tick) end
    end
end
local function saved_light(surface)
    return {period=surface.ticks_per_day,tuple=helpers.table_to_json(surface.daytime_parameters),
        daytime=surface.daytime,held=surface.freeze_daytime,permanent=surface.always_day}
end
local function same_light(surface,before)
    return surface.ticks_per_day==before.period and helpers.table_to_json(surface.daytime_parameters)==before.tuple
        and surface.daytime==before.daytime and surface.freeze_daytime==before.held and surface.always_day==before.permanent
end
local function fulgora_state()
    return helpers.table_to_json(storage.ei.fulgora_day_length_variation or {})
end

function model.instrument(ctx)
    local original_snapshot=ctx.terrain.public_snapshot
    local observed_snapshot=function(...)
        state().stats.snapshots=state().stats.snapshots+1;return original_snapshot(...)
    end
    ctx.terrain.public_snapshot=observed_snapshot
    local original_compose=ctx.field.compose
    local observed_compose=function(report,surface,tick,...)
        local s=state();s.stats.compositions=s.stats.compositions+1
        local before=saved_light(surface);local population=count_surfaces()
        local variation=surface.planet and surface.planet.name=="fulgora" and fulgora_state() or nil
        local result=original_compose(report,surface,tick,...)
        assert(same_light(surface,before),"Presentation changed native light state")
        assert(count_surfaces()==population,"Presentation created a surface")
        if variation then
            assert(fulgora_state()==variation,"Presentation changed independent Fulgora controller state")
            s.stats.fulgora_observations=s.stats.fulgora_observations+1
            assert(result.cycle.period==surface.ticks_per_day,"Fulgora observer did not use current native period")
        end
        s.last_composition={surface=surface.index,planet=result.planet,cycle=result.cycle,values=result.values,tick=tick}
        return result
    end
    ctx.field.compose=observed_compose
    local original_update=ctx.gui.updater
    ctx.gui.updater=function(event)
        local s=state();s.stats.calls=s.stats.calls+1
        local root=storage.ei.ecology_gui
        local player=root and #root.viewers>0 and game.get_player(root.viewers[root.cursor%#root.viewers+1])
        local p=player and root.players[player.index]
        if not p or not p.frame or not p.frame.valid or p.tab==3 or p.layout_version~=2 then return original_update(event) end
        local admitted=event.tick>=(p.next_tick or 0)
        if not admitted then return original_update(event) end
        if s.stats.last_admission then assert(event.tick-s.stats.last_admission>=16,"Viewer admissions exceeded the global 16-tick cadence") end
        s.stats.last_admission=event.tick
        if s.profiling then
            -- A separate naturally admitted tail measures the real owner without
            -- property proxies, read-only assertions, or snapshot counters.
            ctx.terrain.public_snapshot=original_snapshot;ctx.field.compose=original_compose
            local profiler=helpers.create_profiler()
            local ok,err=pcall(original_update,event)
            profiler.stop()
            ctx.terrain.public_snapshot=observed_snapshot;ctx.field.compose=observed_compose
            if not ok then error(err) end
            s.stats.profiled_services=s.stats.profiled_services+1
            log({"","ECOLOGY_FIELD_PROFILE locale="..options.locale.." tick="..event.tick.." elapsed=",profiler})
            return
        end
        local target=options.instrumented_services or (options.locale=="en" and 50 or 8)
        if s.stats.instrumented_services>=target then return original_update(event) end
        local writes,inspections=0,0;local native_rows=p.rows[p.tab or 1]
        local replaced={};local cache={}
        local function proxy(native,is_style)
            if cache[native] then return cache[native] end
            local object=setmetatable({}, {
                __index=function(_,key)
                    if not is_style and key=="style" then return proxy(native.style,true) end
                    return native[key]
                end,
                __newindex=function(_,key,value) writes=writes+1;native[key]=value end,
            })
            cache[native]=object;return object
        end
        for _,row in ipairs(native_rows) do
            replaced[#replaced+1]={row=row,native=row.element};row.element=proxy(row.element)
        end
        local bodies={p.bodies[1],p.bodies[2]};local loading=p.loading
        p.bodies[1]=proxy(bodies[1]);p.bodies[2]=proxy(bodies[2]);p.loading=proxy(loading)
        p.rows[p.tab or 1]=setmetatable({}, {
            __len=function()return #native_rows end,
            __index=function(_,key) if type(key)=="number" then inspections=inspections+1 end;return native_rows[key] end,
        })
        local ok,err=pcall(original_update,event)
        p.rows[p.tab or 1]=native_rows;p.bodies[1]=bodies[1];p.bodies[2]=bodies[2];p.loading=loading
        for _,row in ipairs(replaced) do row.row.element=row.native end
        if not ok then error(err) end
        assert(writes<=8,"Native presentation property-write allowance exceeded: "..writes)
        assert(inspections<=32,"Native presentation binding-inspection allowance exceeded: "..inspections)
        s.stats.writes=s.stats.writes+writes;s.stats.max_writes=math.max(s.stats.max_writes,writes)
        s.stats.max_inspections=math.max(s.stats.max_inspections,inspections)
        s.stats.instrumented_services=s.stats.instrumented_services+1
        if writes>0 then assert(p.last_update_writes==writes,"Reported write counter disagrees with native setters") end
    end
end

local function setup(ctx,player,tick)
    local s=state();s.started=tick;s.surfaces={};s.original_flags={};s.cases={}
    player.set_controller{type=defines.controllers.god};close_monitor(player,tick)
    for _,name in ipairs(names) do
        local planet=assert(game.planets[name],"Loaded planet missing: "..name)
        -- Explicit fixture setup; native LuaPlanet creates and associates it.
        local surface=planet.surface or planet.create_surface()
        check("fixture surface associated with "..name,surface.planet and surface.planet.name==name)
        s.surfaces[name]=surface
        s.original_flags[surface.index]={held=surface.freeze_daytime,permanent=surface.always_day}
    end
    s.utility=game.surfaces["ecology-field-report-utility"] or game.create_surface("ecology-field-report-utility")
    check("utility fixture is not a planet",not s.utility.planet and not s.utility.platform)
    for _,name in ipairs(names) do
        if options.all_planets or name=="nauvis" or name=="fulgora" then
            s.cases[#s.cases+1]={name=name,surface=s.surfaces[name],kind="normal"}
        end
    end
    s.cases[#s.cases+1]={name="nauvis-held",surface=s.surfaces.nauvis,kind="held"}
    s.cases[#s.cases+1]={name="nauvis-permanent",surface=s.surfaces.nauvis,kind="permanent"}
    s.cases[#s.cases+1]={name="nauvis-permanent-held",surface=s.surfaces.nauvis,kind="both"}
    s.cases[#s.cases+1]={name="nauvis-rapid-return",surface=s.surfaces.nauvis,kind="rapid"}
    s.cases[#s.cases+1]={name="nauvis-legacy-layout",surface=s.surfaces.nauvis,kind="legacy"}
    s.cases[#s.cases+1]={name="remote-utility",surface=s.utility,kind="utility"}
    s.surface_count=count_surfaces();s.ready_tick=tick+160
    local entry=storage.ei.terrain_evolution.surfaces[s.surfaces.nauvis.index]
    local old_capability,old_sample=entry.pollution_supported,entry.last_sample_tick
    entry.pollution_supported=nil
    check("legacy unsampled capability remains read-only",ctx.terrain.public_snapshot(s.surfaces.nauvis,tick).pollution_supported
        and entry.pollution_supported==nil and entry.last_sample_tick==old_sample)
    entry.pollution_supported=old_capability
    check("startup integration is enabled",settings.startup["ei-terrain-evolution-enabled"].value)
end
local function begin_case(ctx,player,case,tick)
    local s=state();s.case_tick=tick;s.captured=0;s.translated=false;s.ready=nil
    local old=s.active_case
    if old then
        local flags=s.original_flags[old.surface.index]
        if flags then old.surface.always_day=flags.permanent;old.surface.freeze_daytime=flags.held end
    end
    s.active_case=case
    if case.kind~="utility" then
        local permanent=case.kind=="permanent" or case.kind=="both"
        case.surface.always_day=permanent
        -- Native always_day sets a held daylight state; unfreezing it clears
        -- that state. Test the resulting native flags, not independent booleans.
        if not permanent then
            if case.kind=="held" then case.surface.daytime=0.5 end
            case.surface.freeze_daytime=case.kind=="held"
        end
        check(case.name.." native flags match fixture setup",case.surface.always_day==permanent
            and (permanent or case.surface.freeze_daytime==(case.kind=="held")))
        local phase=(s.case_index%4)/4+0.125
        check(case.name.." calendar phase control",ctx.terrain.set_season_phase(case.surface,phase,tick))
    end
    player.set_controller{type=defines.controllers.remote,surface=case.surface,position={0,0}}
    ctx.gui.on_player_event{player_index=player.index,tick=tick}
    local p=session(player)
    if not p or not p.frame or not p.frame.valid then
        local root=assert(storage.ei.ecology_gui.players[player.index]);dispatch("on_gui_click",player,root.button,tick);p=session(player)
    end
    if p.tab~=1 then p.pane.selected_tab_index=1;dispatch("on_gui_selected_tab_changed",player,p.pane,tick) end
    if case.kind=="rapid" then
        player.set_controller{type=defines.controllers.remote,surface=s.utility,position={0,0}}
        ctx.gui.on_player_event{player_index=player.index,tick=tick}
        player.set_controller{type=defines.controllers.remote,surface=case.surface,position={0,0}}
        ctx.gui.on_player_event{player_index=player.index,tick=tick}
        check("rapid return keeps stale body hidden",not p.bodies[1].visible and p.invalidated)
    end
    if case.kind=="legacy" then p.layout_version=nil;p.tab_generations=nil;p.strip_width=nil end
    p.bodies[1].scroll_to_top()
end
local function collect_captions(player,case)
    local p=session(player);local captions={};local serial=0
    local function add(value,kind)
        if type(value)=="table" and value[1]~=nil then
            serial=serial+1;captions[#captions+1]={tag=case.name.."/"..kind.."/"..serial,caption=value}
        end
    end
    local function walk(element)
        if not element.visible then return end
        if element.type=="label" or element.type=="button" or element.type=="tab" then add(element.caption,"caption") end
        add(element.tooltip,"tooltip")
        for _,child in pairs(element.children or {}) do walk(child) end
    end
    walk(p.bodies[1]);add({"ei-ecology.title"},"title")
    for _,key in ipairs{"simple","advanced","alerts"} do add({"ei-ecology.tab-"..key},"tab") end
    return captions
end
local function verify_ready(ctx,player,case,tick)
    local p=session(player);local s=state();local last=s.last_composition
    check(case.name.." remote view selects actual surface",player.surface==case.surface and p.surface==case.surface)
    check(case.name.." Simple atomically reveals current surface",p.tab==1 and p.bodies[1].visible and not p.loading.visible
        and p.tab_generations[1]==p.view_generation)
    check(case.name.." uses native artwork",row_by_key(p,"banner").element.sprite=="ei-ecology-banner-"..(case.kind=="utility" and "neutral" or case.surface.planet.name))
    check(case.name.." icon is valid",helpers.is_valid_sprite_path(row_by_key(p,"icon").element.sprite))
    check(case.name.." body fits horizontal viewport",p.frame.location.x>=0 and p.frame.location.x+p.frame.style.minimal_width*player.display_scale<=player.display_resolution.width+2)
    check(case.name.." body is constrained to vertical viewport",p.frame.location.y>=0
        and p.frame.location.y+p.frame.style.maximal_height*player.display_scale<=player.display_resolution.height+2)
    check(case.name.." opening did not create surfaces",count_surfaces()==s.surface_count)
    check(case.name.." fresh composition matches surface",last and last.surface==case.surface.index and last.tick>s.case_tick)
    if case.kind=="legacy" then check("old saved layout is retired on first use",p.layout_version==2 and p.strip_width>0) end
    if case.kind=="utility" then
        check(case.name.." native cycle is unavailable",not last.cycle.available and last.values.day[1]=="ei-ecology-field.no-cycle")
        check(case.name.." unsupported report remains honest",last.values.status[1]=="ei-ecology-field.status-unsupported")
        check(case.name.." unavailable strips are hidden",not row_by_key(p,"day_available").element.visible
            and not row_by_key(p,"season_available").element.visible)
    else
        check(case.name.." reads actual native period",last.cycle.available and last.cycle.period==case.surface.ticks_per_day)
        local widths=0
        for i=1,4 do widths=widths+last.values["day_width_"..i] end
        check(case.name.." phase strip has exact bounded width",widths==p.strip_width and last.values.day_marker>=0 and last.values.day_marker<=p.strip_width-20)
        if case.kind=="held" or case.kind=="both" then check(case.name.." held cycle omits forecast",last.cycle.frozen and last.cycle.remaining==nil) end
        if case.kind=="permanent" or case.kind=="both" then check(case.name.." permanent day omits forecast",last.cycle.permanent and last.cycle.remaining==nil) end
        if case.kind=="permanent" or case.kind=="both" then
            check(case.name.." permanent day occupies full strip",last.values.day_width_1==p.strip_width
                and last.values.day_width_2==0 and last.values.day_width_3==0 and last.values.day_width_4==0)
            for i=2,4 do check(case.name.." zero phase "..i.." is hidden",not row_by_key(p,"day_visible_"..i).element.visible) end
        end
        if case.surface.planet.name=="fulgora" then
            check(case.name.." independent controller is described",last.values.daylight[1]=="ei-ecology-field.daylight-independent")
            check(case.name.." seasonal daylight never owns Fulgora",not ctx.terrain.public_snapshot(case.surface,tick).calendar.owns_daylight)
            check(case.name.." actual Fulgora observations were read-only",s.stats.fulgora_observations>0)
        end
    end
end
local function capture(player,case,suffix,tick)
    local s=state();local p=session(player);close_monitor(player,tick);p.frame.bring_to_front()
    local path=(options.capture_prefix or "ecology-field").."/"..options.locale.."/"..case.name.."-"..suffix..".png"
    game.take_screenshot{player=player,path=path,show_gui=true,show_entity_info=false,force_render=true,resolution=player.display_resolution}
    s.captures[#s.captures+1]=path
end
local function lifecycle_step(ctx,player,tick)
    local s=state();if s.lifecycle_done then return true end
    local p=session(player);local l=s.lifecycle
    if not l then
        local utility=assert(s.utility,"Existing fixture utility required")
        check("lifecycle starts on the explicitly created utility",utility.valid and not utility.planet
            and player.surface==utility and p.surface==utility and p.tab==1 and p.bodies[1].visible)
        local new_name="ecology-field-report-renamed"
        check("lifecycle rename target is unused",not game.surfaces[new_name])
        l={phase="renamed",started=tick,rename_tick=tick,index=utility.index,
            old_name=utility.name,new_name=new_name,before_count=count_surfaces()}
        s.lifecycle=l
        -- LuaSurface.name raises the real on_surface_renamed event immediately.
        utility.name=new_name
        local catalog=storage.ei.ecology_gui
        check("native rename forwarding refreshes surface catalog",catalog.surface_known[new_name]
            and not catalog.surface_known[l.old_name])
        check("native rename preserves surface identity and membership",game.surfaces[new_name]==utility
            and count_surfaces()==l.before_count)
        return false
    end
    assert(tick-l.started<1200,"Report lifecycle phase timed out: "..l.phase)
    if l.phase=="renamed" then
        local last=s.last_composition;local identity=row_by_key(p,"identity")
        if not (last and last.tick>l.rename_tick and last.surface==l.index and p.tab==1
            and identity.element.caption[3]==l.new_name
            and identity.signature==helpers.table_to_json(last.values.identity)) then return false end
        check("viewed rename refreshes rendered identity without a new surface",p.surface==s.utility
            and player.surface==s.utility and p.bodies[1].visible and count_surfaces()==l.before_count)
        p.pane.selected_tab_index=2;dispatch("on_gui_selected_tab_changed",player,p.pane,tick)
        l.phase="advanced-partial"
        return false
    end
    if l.phase=="advanced-partial" then
        if not (p.tab==2 and p.row_cursor>0 and p.row_cursor<#p.rows[2]
            and p.tab_generations[2]~=p.view_generation) then return false end
        check("Advanced has real partial native population",p.rows[2][1].generation==p.view_generation
            and p.rows[2][#p.rows[2]].generation~=p.view_generation and not p.bodies[2].visible)
        l.partial_generation=p.view_generation;l.partial_cursor=p.row_cursor;l.move_tick=tick
        player.set_controller{type=defines.controllers.remote,surface=s.surfaces.nauvis,position={0,0}}
        check("native remote controller leaves utility before deletion",player.surface==s.surfaces.nauvis)
        p.pane.selected_tab_index=1;dispatch("on_gui_selected_tab_changed",player,p.pane,tick)
        -- Deliberately queue removal before the next report refresh. The session
        -- may still hold the old LuaSurface; the real deletion events must retire
        -- it safely. Never delete the primary surface or a gameplay-owned world.
        check("fixture deletes only its unassociated utility",s.utility.valid and not s.utility.planet
            and s.utility.index==l.index and l.index~=s.surfaces.nauvis.index)
        check("native utility deletion is queued",game.delete_surface(l.index))
        l.phase="deleted"
        return false
    end
    if l.phase=="deleted" then
        -- LuaGameScript.delete_surface queues both deletion events for a future
        -- tick. Do not infer completion from its boolean return or touch an
        -- invalid LuaSurface after it retires.
        if game.surfaces[l.index] or storage.ei.ecology_gui.surface_known[l.new_name] then return false end
        if not l.count_adjusted then
            check("native deletion removes exactly the fixture surface",count_surfaces()==l.before_count-1)
            check("native deletion forwarding retires catalog entry",not storage.ei.ecology_gui.surface_known[l.new_name])
            s.surface_count=l.before_count-1;l.count_adjusted=true
        end
        local last=s.last_composition
        if not (p.surface==s.surfaces.nauvis and p.tab==1 and p.bodies[1].visible and not p.loading.visible
            and p.tab_generations[1]==p.view_generation and last and last.tick>l.move_tick
            and last.surface==s.surfaces.nauvis.index and cycle_rendered(p,last)) then return false end
        check("Simple recovers current native generation after viewed-surface deletion",p.surface.valid
            and p.view_generation>l.partial_generation)
        check("Simple never waits for unfinished Advanced population",p.tab_generations[2]~=p.view_generation
            and p.rows[2][#p.rows[2]].generation~=p.view_generation)
        check("lifecycle report actions preserve adjusted membership",count_surfaces()==s.surface_count)
        s.lifecycle_evidence={renamed_index=l.index,renamed_from=l.old_name,renamed_to=l.new_name,
            partial_advanced_cursor=l.partial_cursor,old_generation=l.partial_generation,new_generation=p.view_generation,
            deletion_and_simple_ready_ticks=tick-l.move_tick,surface_count_after=s.surface_count}
        s.utility=nil;s.lifecycle=nil;s.lifecycle_done=true
        return true
    end
    error("Unknown report lifecycle phase: "..tostring(l.phase))
end
function model.step(ctx,player,tick)
    local s=state();if s.complete then return model.result() end
    if not s.started then setup(ctx,player,tick) end
    if tick<s.ready_tick then return {} end
    if s.idle_tick then
        if tick-s.idle_tick<180 then return {} end
        check("closed report does not compose",s.stats.compositions==s.idle_compositions)
        check("closed report does not request snapshots",s.stats.snapshots==s.idle_snapshots)
        check("closed viewer is not scheduled",not ctx.gui.has_tick_work(tick))
        check("instrumentation observed native writes",s.stats.writes>0 and s.stats.max_writes<=8)
        check("instrumentation verified binding inspection bound",s.stats.max_inspections>0 and s.stats.max_inspections<=32)
        check("requested independent native instrumentation completed",s.stats.instrumented_services>=(options.instrumented_services or (options.locale=="en" and 50 or 8)))
        check("requested natural unwrapped profiling completed",s.stats.profiled_services>=(options.profiled_services or (options.locale=="en" and 100 or 0)))
        check("all requested three-part captures submitted",#s.captures==#s.cases*3)
        check("report interactions never created a surface",count_surfaces()==s.surface_count)
        s.complete=true;return model.result()
    end
    if s.tail_tick then
        local p=session(player)
        if p and p.surface==s.surfaces.nauvis and p.tab_generations[1]==p.view_generation and p.bodies[1].visible then
            local instrumented=options.instrumented_services or (options.locale=="en" and 50 or 8)
            local profiled=options.profiled_services or (options.locale=="en" and 100 or 0)
            if s.stats.instrumented_services>=instrumented then
                if s.stats.profiled_services<profiled then s.profiling=true
                else
                    s.profiling=nil
                    if options.locale~="en" then
                        local guide=assert(find_action(p.bodies[1],"guide"),"Field-guide button missing")
                        dispatch("on_gui_click",player,guide,tick)
                        check("field-guide button opens native Informatron",player.gui.screen.informatron and player.gui.screen.informatron.valid)
                        check("field-guide handoff closes Ecology",not p.frame)
                    else dispatch("on_gui_closed",player,p.frame,tick) end
                    s.idle_tick=tick;s.idle_compositions=s.stats.compositions;s.idle_snapshots=s.stats.snapshots
                end
            end
        end
        return {}
    end
    if not s.active_case then
        if s.case_index>=#s.cases and not lifecycle_step(ctx,player,tick) then return {} end
        s.case_index=s.case_index+1
        if s.case_index>#s.cases then
            for index,flags in pairs(s.original_flags) do local surface=game.surfaces[index];surface.always_day=flags.permanent;surface.freeze_daytime=flags.held end
            player.set_controller{type=defines.controllers.remote,surface=s.surfaces.nauvis,position={0,0}}
            ctx.gui.on_player_event{player_index=player.index,tick=tick}
            s.tail_tick=tick
            return {}
        end
        begin_case(ctx,player,s.cases[s.case_index],tick)
        return {}
    end
    local case=s.active_case;local p=session(player)
    if not s.ready then
        local last=s.last_composition
        if p and p.frame and p.frame.valid and p.surface==case.surface and p.bodies[1].visible
            and p.tab_generations and p.tab_generations[1]==p.view_generation and last and last.tick>s.case_tick and last.surface==case.surface.index
            and cycle_rendered(p,last) then
            verify_ready(ctx,player,case,tick);s.ready=tick;p.bodies[1].scroll_to_top()
            return {captions=collect_captions(player,case)}
        end
        assert(tick-s.case_tick<600,"Simple never became ready: "..case.name)
        return {}
    end
    local elapsed=tick-s.ready
    if elapsed>=10 and s.captured==0 then capture(player,case,"top",tick);s.captured=1 end
    if elapsed>=20 and s.captured==1 then p.bodies[1].scroll_to_element(row_by_key(p,"season").element,"top-third");s.captured=2 end
    if elapsed>=30 and s.captured==2 then capture(player,case,"mid",tick);s.captured=3 end
    if elapsed>=40 and s.captured==3 then p.bodies[1].scroll_to_bottom();s.captured=4 end
    if elapsed>=50 and s.captured==4 then capture(player,case,"bottom",tick);s.captured=5 end
    if elapsed>=60 and s.captured==5 then
        check(case.name.." captures preserve surface membership",count_surfaces()==s.surface_count)
        local flags=s.original_flags[case.surface.index]
        if flags then case.surface.always_day=flags.permanent;case.surface.freeze_daytime=flags.held end
        s.active_case=nil
    end
    return {}
end
function model.result()
    local s=state();local pass=s.complete==true
    for _,r in ipairs(s.checks) do if not r.ok then pass=false end end
    return {complete=s.complete or false,all_pass=pass,checks=s.checks,stats=s.stats,captures=s.captures,
        cases=s.cases and #s.cases or 0,started=s.started,finished=s.complete and game.tick or nil,lifecycle=s.lifecycle_evidence,
        scope="Explicit fixture-world setup; real remote views and native GUI. Setter instrumentation and unwrapped profiling are separate phases; timings are in ECOLOGY_FIELD_PROFILE log records."}
end
return model

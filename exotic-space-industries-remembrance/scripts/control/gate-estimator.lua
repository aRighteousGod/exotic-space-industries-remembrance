-- blueprint: .codex/esir/blueprints/gate.md#contract
-- Detached what-if UI. Snapshots are read-only; only explicit Run admits queued work.
-- Persistent owner: storage.ei_gate_estimator. All events come from control.lua.
local lib=require("lib/lib")
local gate_model=require("scripts/control/gate")
local calc=require("lib/gate-calculations")
local projection=require("lib/gate-projection")
local chart=require("lib/gate-estimator-chart")
local anchors=require("lib/surface-anchor")
local scheduler=require("lib/runtime-scheduler")
local options=require("lib/runtime-options-config")
---@class GateEstimator
local model={}
---@alias GateEstimatorGuiEvent EventData.on_gui_click|EventData.on_gui_value_changed|EventData.on_gui_text_changed|EventData.on_gui_elem_changed|EventData.on_gui_selection_state_changed|EventData.on_gui_selected_tab_changed|EventData.on_gui_confirmed
---@class GateEstimatorTags
---@field parent_gui string
---@field action string
---@field key string|integer|nil
---@field gate_unit uint|nil
---@class GateEstimatorViewer
---@field source uint Gate unit used only for explicit snapshot reads.
---@field draft table Editable plain inputs, independent of real gate state.
---@field baseline GateEstimateScenario|nil
---@field results table[]|nil Completed bounded traces.
---@field metrics integer[] Two selected chart metrics.
---@field renders LuaRenderObject[]|nil Viewer-restricted objects.
---@field gui table|nil Revalidated native elements.
---@field open boolean|nil
---@field stale boolean
---@field location GuiLocation|nil
local GUI="ei-gate-estimator"
local repair_pending=false
local route_names={"local","orbital","distance","unknown","snapshot"}
local click_actions={close=true,run=true,advanced=true,pin=true,["clear-baseline"]=true,snapshot=true,reset=true,["gate-estimator"]=true}
local horizons={60,300,900,3600}
local function text(key,...) return {"gate-estimator."..key,...} end
local function tags(action,key) return {parent_gui=GUI,action=action,key=key} end
local function number(value) return string.format("%.6g",value or 0) end
local function copy(value) return table.deepcopy(value) end
local function state()
    storage.ei_gate_estimator=storage.ei_gate_estimator or {players={},jobs={},queue=scheduler.ensure_queue()}
    return storage.ei_gate_estimator
end
local function valid_source(player,viewer)
    local entry=storage.ei and storage.ei.gate and storage.ei.gate.gate[viewer.source]
    return entry and lib.entity_check(entry.gate) and lib.entity_check(entry.container)
        and entry.container.force==player.force and entry or nil
end
local function distance_cache()
    return storage.ei and storage.ei.gate and storage.ei.gate.distance_cache
        or anchors.build_distance_cache(prototypes.space_location)
end
local function available_quality(name)
    local quality=name and prototypes.quality[name]
    -- Base hides Normal when Quality is disabled; it remains the valid sender tier.
    if quality and (name=="normal" or not quality.hidden) then return quality end
end

---@param player LuaPlayer
---@param viewer GateEstimatorViewer Per-player draft; never owns a gameplay entity.
---@param tick MapTick
function model.snapshot(player,viewer,tick)
    local entry=valid_source(player,viewer)
    if not entry then return false end
    local d=viewer.draft
    local gate=entry.gate
    d.quality=entry.container.quality.name;d.energy=gate.energy/1e9
    d.capacity=gate.electric_buffer_size;d.input_limit=gate.input_flow_limit
    d.slots=#entry.container.get_inventory(defines.inventory.chest)
    d.stress=entry.stress or 0;d.cooldown=math.max(0,(entry.cooldown_until_tick or 0)-tick)/60
    local receiver=entry.effective_target_entity
    if not lib.entity_check(receiver) then receiver=nil end
    local receiver_entry=receiver and storage.ei.gate.receiver[receiver.unit_number]
    d.saturation=receiver_entry and receiver_entry.saturation or 0
    local quote=gate_model.resolve_distance_quote(gate.surface,receiver and receiver.surface)
    d.distance=quote.raw_distance;d.snapshot_multiplier=quote.distance_multiplier;d.snapshot_span=quote.span_ratio
    d.route="snapshot";d.from=nil;d.to=nil
    if receiver and gate.surface.planet and receiver.surface.planet then
        d.from=gate.surface.planet.name;d.to=receiver.surface.planet.name
    end
    local count=math.max(1,gate_model.get_pending_work_count())
    local divisor=options.get("ei-ticks_per_full_update",60)/16
    local budget=math.max(1,math.min(math.ceil(count/divisor),options.get("ei-max_updates_per_tick",10)))
    d.service=16*math.ceil(count/budget)
    viewer.snapshot_tick=tick
    return true
end

---@param viewer GateEstimatorViewer
---@return GateEstimateScenario|nil,string|nil
function model.scenario(viewer)
    local d=viewer.draft
    local item=d.item and prototypes.item[d.item]
    local quality=available_quality(d.quality)
    if not item or not quality then return nil,"missing-prototype" end
    local cache=distance_cache()
    local distance=d.distance
    local kind=d.route
    if d.from and d.to then
        local pair=cache.pair_distance[d.from]
        if not pair or pair[d.to]==nil then return nil,"missing-prototype" end
        distance=pair[d.to];kind=d.from==d.to and "local" or "distance"
    end
    local multiplier=kind=="snapshot" and d.snapshot_multiplier
        or calc.distance_multiplier(kind,distance,cache.max_pair_distance)
    return {item=d.item,quality=d.quality,from=d.from,to=d.to,
        weight=gate_model.mass_weights[d.item] or 1,stack_size=item.stack_size,
        batch=math.min(item.stack_size,math.max(1,math.floor(d.batch))),slots=d.slots,
        multiplier=multiplier,span_ratio=kind=="snapshot" and d.snapshot_span or calc.span_ratio(multiplier),
        quality_multiplier=calc.quality_multiplier(quality.level),quality_level=quality.level,
        distance=distance,maximum_distance=cache.max_pair_distance,route=kind,
        capacity=d.capacity,input_limit=d.input_limit,energy=math.min(d.capacity,d.energy*1e9),
        stress=d.stress,saturation=d.saturation,cooldown=math.ceil(d.cooldown*60),
        rate=d.rate,power=d.power*1e6,service=d.service,horizon=d.horizon}
end

-- Pinned inputs survive configuration changes; removed prototypes cannot run silently.
local function baseline_scenario(viewer,horizon)
    if not viewer.baseline then return nil end
    local s=copy(viewer.baseline)
    local item=prototypes.item[s.item]
    local quality=available_quality(s.quality)
    if not item or not quality then return nil,"missing-prototype" end
    local cache=distance_cache()
    if s.from and s.to then
        local pair=cache.pair_distance[s.from]
        if not pair or pair[s.to]==nil then return nil,"missing-prototype" end
        s.distance=pair[s.to];s.route=s.from==s.to and "local" or "distance"
    end
    s.maximum_distance=cache.max_pair_distance
    if s.route~="snapshot" then
        s.multiplier=calc.distance_multiplier(s.route,s.distance,s.maximum_distance)
        s.span_ratio=calc.span_ratio(s.multiplier)
    end
    s.weight=gate_model.mass_weights[s.item] or 1;s.stack_size=item.stack_size
    s.batch=math.min(s.batch,item.stack_size)
    s.quality_level=quality.level;s.quality_multiplier=calc.quality_multiplier(quality.level)
    s.horizon=horizon
    return s
end

local function label(parent,caption,tooltip,width)
    local element=parent.add{type="label",caption=caption,tooltip=tooltip}
    element.style.single_line=false;element.style.maximal_width=width or 540
    return element
end
local function caption_list(keys)
    local result={};for _,key in ipairs(keys) do result[#result+1]=text(key=="snapshot" and "route-snapshot" or key=="power" and "power-draw" or key) end;return result
end
local function cancel(viewer,index)
    state().jobs[index]=nil
    viewer.stale=true
end

local function summary(job)
    return text("summary",number(job.delivered),number(job.delivered/job.scenario.horizon),number(job.upstream),
        number(job.cargo),number(job.transfer_j/1e9),number(job.upkeep_j/1e9),
        number((job.transfer_j+job.upkeep_j)/job.scenario.horizon/1e6),number(job.minimum_energy/1e9),
        number(job.maximum_stress),number(job.waits.cooldown/60),number(job.waits.power/60),
        number(job.waits.receiver/60),number(job.residue))
end

---@param player LuaPlayer
---@param viewer GateEstimatorViewer
function model.refresh(player,viewer)
    local gui=viewer.gui
    if not gui or not gui.root.valid then return end
    local s,reason=model.scenario(viewer)
    local _,baseline_reason=baseline_scenario(viewer,viewer.draft.horizon)
    gui.snapshot.enabled=valid_source(player,viewer)~=nil
    gui.pin.enabled=s~=nil and not viewer.invalid
    gui.run.enabled=gui.pin.enabled and not baseline_reason
    if not s or viewer.invalid then gui.status.caption=text(reason or "invalid");return end
    local locked=viewer.draft.from~=nil and viewer.draft.to~=nil
    gui.fields.distance.slider.enabled=not locked and viewer.draft.route=="distance"
    gui.fields.distance.value.enabled=gui.fields.distance.slider.enabled
    gui.route.enabled=not locked
    if locked then
        gui.fields.distance.value.text=number(s.distance)
        gui.fields.distance.slider.slider_value=math.min(s.maximum_distance,s.distance)
    end
    local q=calc.quote(s.weight*s.batch,s.batch,s.multiplier,s.quality_multiplier,s.span_ratio)
    local stress,cooldown=calc.after_transfer(s.stress,q)
    local expressions={
        {"burden",number(s.weight).." × "..s.batch.." = "..number(q.burden)},
        {"distance-factor",s.route=="distance" and "2.5 + 5.5 × ("..number(s.distance).." / "..number(s.maximum_distance)..")^0.6 = "..number(s.multiplier) or "×"..number(s.multiplier)},
        {"quality-factor","1 / (1 + 0.2 × "..number(s.quality_level)..") = "..number(s.quality_multiplier)},
        {"toll","floor("..number(q.burden).."^1.2 × 100 MJ × "..number(s.multiplier).." × "..number(s.quality_multiplier)..") = "..number(q.energy_j/1e9).." GJ"},
        {"per-item",number(q.energy_j/1e6).." MJ / "..s.batch.." = "..number(q.energy_j/s.batch/1e6).." MJ"},
        {"stress-result","min(35, √"..number(q.burden).." × (1 + 0.75 × "..number(q.span_ratio)..")) = +"..number(q.stress_delta).."; min(100, "..number(s.stress).." + "..number(q.stress_delta)..") = "..number(stress)},
        {"cooldown-result","(30 + floor(15 × √"..number(q.burden)..") + floor(2 × "..number(stress)..")) / 60 = "..number(cooldown/60).." s"},
        {"saturation-result","min(20, 0.8 × √"..number(q.burden)..") = +"..number(q.saturation_delta).."; "..number(math.min(100,s.saturation+q.saturation_delta))},
        {"upkeep-result","(30 + 1.5 × "..number(stress).." + 30) × "..number(s.quality_multiplier).." = "..number(calc.upkeep(stress,true,s.quality_multiplier)/1e6).." MW / "..number(calc.upkeep(s.stress,s.cooldown>0,s.quality_multiplier)/1e6).." MW"},
    }
    for i,row in ipairs(expressions) do gui.calculations[i].caption={"",text(row[1]),": ",row[2]} end
    gui.hardware.caption=text("hardware",number(s.capacity/1e9),number(s.input_limit*60/1e6),number(s.service/60))
    gui.fallback.caption=gate_model.mass_weights[s.item] and "" or text("fallback")
    local running=state().jobs[player.index]
    gui.status.caption=running and text("running") or viewer.stale and text("stale") or text("ready")
    if q.energy_j>s.capacity then gui.status.caption=text("too-expensive") end
    if viewer.results then
        gui.summary.caption=summary(viewer.results[1])
        if viewer.results[2] then
            local a,b=viewer.results[1],viewer.results[2]
            gui.baseline_summary.caption={"",text("baseline"),"\n",summary(b),"\n",
                text("difference",number(a.delivered-b.delivered),number((a.transfer_j+a.upkeep_j-b.transfer_j-b.upkeep_j)/1e9))}
        else gui.baseline_summary.caption="" end
    end
    gui.baseline.caption=viewer.baseline and text("pinned") or text("no-baseline")
    if baseline_reason then gui.status.caption={"",text("baseline"),": ",text(baseline_reason)} end
end

local function field(parent,viewer,key,min,max,step,slider)
    local d=viewer.draft
    local row=parent.add{type="flow",direction="vertical"}
    local heading=label(row,key=="power" and {"",text(key),viewer.power_gw and " (GW)" or " (MW)"} or text(key),text("help-"..key),280)
    local controls=row.add{type="flow",direction="horizontal"}
    local value=controls.add{type="textfield",text=number(d[key]),numeric=true,allow_decimal=step<1,
        allow_negative=false,tags=tags("value",key),tooltip=text("help-"..key)}
    value.style.width=95
    local element
    if slider and max>min then
        element=controls.add{type="slider",minimum_value=min,maximum_value=max,value=d[key],value_step=step,
            tags=tags("slider",key),tooltip=text("help-"..key)}
        element.style.width=160
    end
    viewer.gui.fields[key]={value=value,slider=element,min=min,max=max,step=step,heading=heading}
end

---@param player LuaPlayer
---@param viewer GateEstimatorViewer
function model.build(player,viewer)
    -- Removed prototypes are shown as invalid drafts rather than passed to native selectors.
    local d=viewer.draft
    viewer.invalid=false;viewer.invalid_fields={}
    if d.item and not prototypes.item[d.item] then d.item=nil
    elseif d.item then d.batch=math.min(prototypes.item[d.item].stack_size,math.max(1,math.floor(d.batch))) end
    for _,key in ipairs{"from","to"} do
        if d[key] and not prototypes.space_location[d[key]] then d[key]=nil;viewer.invalid=true end
    end
    local location=viewer.location
    if viewer.gui and viewer.gui.root.valid then location=viewer.gui.root.location;viewer.gui.root.destroy() end
    chart.clear(viewer)
    local old=player.gui.screen[GUI];if old then old.destroy() end
    local width=math.max(320,math.min(1000,player.display_resolution.width/player.display_scale-32))
    local height=math.max(240,math.min(760,player.display_resolution.height/player.display_scale-48))
    local root=player.gui.screen.add{type="frame",name=GUI,direction="vertical"}
    root.style.width=width;root.style.maximal_height=height
    local title=root.add{type="flow",direction="horizontal"}
    title.add{type="label",caption=text("title"),style="frame_title"}
    local spacer=title.add{type="empty-widget",style="ei_titlebar_draggable_spacer"};spacer.drag_target=root
    title.add{type="sprite-button",sprite="utility/close",style="frame_action_button",tags=tags("close"),tooltip=text("close")}
    if location then root.location={x=math.max(0,math.min(location.x,player.display_resolution.width-width*player.display_scale)),
        y=math.max(0,math.min(location.y,player.display_resolution.height-height*player.display_scale))} else root.auto_center=true end
    local body=root.add{type="scroll-pane",horizontal_scroll_policy="never"}
    body.style.maximal_height=height-60
    local columns=body.add{type="flow",direction=width>=740 and "horizontal" or "vertical"}
    local controls=columns.add{type="scroll-pane",horizontal_scroll_policy="never"}
    controls.style.width=300;controls.style.maximal_height=height-90
    viewer.gui={root=root,fields={},calculations={},axes={},samples={},cameras={}}
    local gui=viewer.gui
    gui.snapshot=controls.add{type="button",caption=text("snapshot"),tags=tags("snapshot"),tooltip=text("help-snapshot")}
    controls.add{type="button",caption=text("reset"),tags=tags("reset"),tooltip=text("help-reset")}
    label(controls,text("item"),text("help-item"),280)
    gui.item=controls.add{type="choose-elem-button",elem_type="item",item=viewer.draft.item,tags=tags("item"),tooltip=text("help-item")}
    local item=viewer.draft.item and prototypes.item[viewer.draft.item]
    field(controls,viewer,"batch",1,item and item.stack_size or 1,1,true)
    field(controls,viewer,"stress",0,100,0.1,true)
    label(controls,text("quality"),text("help-quality"),280)
    local names={};viewer.qualities={}
    for name,quality in pairs(prototypes.quality) do
        if name=="normal" or not quality.hidden then viewer.qualities[#viewer.qualities+1]=name end
    end
    table.sort(viewer.qualities,function(a,b) local x,y=prototypes.quality[a],prototypes.quality[b];return x.level==y.level and a<b or x.level<y.level end)
    local selected=0
    for i,name in ipairs(viewer.qualities) do names[i]=prototypes.quality[name].localised_name;if name==viewer.draft.quality then selected=i end end
    controls.add{type="drop-down",items=names,selected_index=selected,tags=tags("quality"),tooltip=text("help-quality")}
    for _,key in ipairs{"from","to"} do
        label(controls,text(key),text("help-route"),280)
        local button=controls.add{type="choose-elem-button",elem_type="space-location",
            elem_filters={{filter="type",type="planet"}},tags=tags("planet",key),tooltip=text("help-route")}
        if viewer.draft[key] then button.elem_value=viewer.draft[key] end
    end
    selected=3;for i,name in ipairs(route_names) do if name==viewer.draft.route then selected=i end end
    gui.route=controls.add{type="drop-down",items=caption_list(route_names),selected_index=selected,tags=tags("route"),tooltip=text("help-route")}
    field(controls,viewer,"distance",0,distance_cache().max_pair_distance,0.01,true)
    field(controls,viewer,"rate",0,1e6,0.01,false)
    controls.add{type="drop-down",items=caption_list{"per-second","per-minute"},selected_index=viewer.per_minute and 2 or 1,tags=tags("rate-unit"),tooltip=text("help-rate")}
    if viewer.per_minute then gui.fields.rate.value.text=number(viewer.draft.rate*60) end
    field(controls,viewer,"power",0,viewer.draft.input_limit*60/1e6*10,0.01,false)
    controls.add{type="drop-down",items={"MW","GW"},selected_index=viewer.power_gw and 2 or 1,tags=tags("power-unit"),tooltip=text("help-power")}
    if viewer.power_gw then gui.fields.power.value.text=number(viewer.draft.power/1000) end
    controls.add{type="button",caption=text("initial-state"),tags=tags("advanced"),tooltip=text("help-initial-state")}
    gui.advanced=controls.add{type="flow",direction="vertical",visible=viewer.advanced==true}
    field(gui.advanced,viewer,"energy",0,viewer.draft.capacity/1e9,0.01,true)
    field(gui.advanced,viewer,"cooldown",0,3600,0.1,false)
    field(gui.advanced,viewer,"saturation",0,100,0.1,true)
    local right=columns.add{type="flow",direction="vertical"}
    local rw=width>=740 and width-350 or width-55
    right.style.width=rw
    gui.status=label(right,"",text("help-status"),rw)
    gui.hardware=label(right,"",text("help-hardware"),rw)
    local tabs=right.add{type="tabbed-pane"}
    gui.tabs=tabs
    for index,key in ipairs{"calculation","projections"} do
        local tab=tabs.add{type="tab",caption=text(key)}
        local content=tabs.add{type="scroll-pane",horizontal_scroll_policy="never"}
        content.style.width=rw-10;content.style.maximal_height=height-190
        tabs.add_tab(tab,content)
        if index==1 then
            for _,name in ipairs{"burden","distance-factor","quality-factor","toll","per-item","stress-result","cooldown-result","saturation-result","upkeep-result"} do
                gui.calculations[#gui.calculations+1]=label(content,"",text("help-"..name),rw-35)
                content.add{type="line"}
            end
            gui.fallback=label(content,"",text("help-burden"),rw-35)
            label(content,text("assumptions"),text("help-assumptions"),rw-35)
        else
            local bar=content.add{type="flow",direction="horizontal"}
            gui.run=bar.add{type="button",caption=text("run"),tags=tags("run"),tooltip=text("help-run")}
            local horizon_items={};selected=2
            for i,seconds in ipairs(horizons) do horizon_items[i]=text("minutes",seconds/60);if seconds==viewer.draft.horizon then selected=i end end
            bar.add{type="drop-down",items=horizon_items,selected_index=selected,tags=tags("horizon"),tooltip=text("help-horizon")}
            local baseline_bar=content.add{type="flow",direction="horizontal"}
            gui.pin=baseline_bar.add{type="button",caption=text("pin"),tags=tags("pin"),tooltip=text("help-pin")}
            baseline_bar.add{type="button",caption=text("clear-baseline"),tags=tags("clear-baseline"),tooltip=text("help-pin")}
            gui.baseline=label(content,"",text("help-pin"),rw-35)
            label(content,text("legend"),text("help-chart"),rw-35)
            local surface=chart.surface()
            for panel=1,2 do
                content.add{type="drop-down",items=caption_list(chart.metrics),selected_index=viewer.metrics[panel],tags=tags("metric",panel),tooltip=text("help-chart")}
                gui.axes[panel]=label(content,"",text("help-chart"),rw-35)
                -- Camera content does not follow interface scaling. Fit the 24-tile
                -- canvas to the widget's physical width (48 pixels/tile at zoom 1
                -- in the native camera), including after a display-scale rebuild.
                local camera=content.add{type="camera",surface_index=surface.index,position={0,(panel-1)*20},
                    zoom=(rw-35)*player.display_scale/(24*48)}
                camera.style.width=rw-35;camera.style.height=math.floor((rw-35)*0.3)
                gui.cameras[panel]=camera
                gui.samples[panel]=label(content,"",text("help-sample"),rw-35)
            end
            content.add{type="slider",minimum_value=1,maximum_value=240,value=viewer.sample or 1,value_step=1,tags=tags("sample"),tooltip=text("help-sample")}
            gui.summary=label(content,"",text("help-summary"),rw-35)
            gui.baseline_summary=label(content,"",text("help-summary"),rw-35)
        end
    end
    tabs.selected_tab_index=viewer.tab or 1
    tabs.tags=tags("tab")
    model.refresh(player,viewer)
    chart.draw(player,viewer)
end

---@param player LuaPlayer
---@param unit uint
---@param tick MapTick
function model.open(player,unit,tick)
    local root=state()
    local viewer=root.players[player.index]
    if viewer and viewer.gui and viewer.gui.root.valid then
        viewer.source=unit;model.refresh(player,viewer);viewer.gui.root.bring_to_front();return
    end
    if not viewer then
        viewer={source=unit,metrics={1,2},sample=1,stale=true,
            draft={item="iron-plate",batch=1,rate=1,power=1000,horizon=300}}
        root.players[player.index]=viewer
        if not model.snapshot(player,viewer,tick) then root.players[player.index]=nil;return end
    end
    viewer.source=unit;viewer.open=true
    model.build(player,viewer)
end

---@param index uint
---@param remove boolean|nil Also discard this player's retained draft.
function model.close(index,remove)
    local root=storage.ei_gate_estimator;if not root then return end
    local viewer=root.players[index]
    if viewer then
        if viewer.gui and viewer.gui.root.valid then viewer.location=viewer.gui.root.location;viewer.gui.root.destroy() end
        chart.clear(viewer);viewer.gui=nil;viewer.results=nil;viewer.open=false;viewer.stale=true
    end
    root.jobs[index]=nil
    if remove then root.players[index]=nil end
end

---@param player LuaPlayer
---@param viewer GateEstimatorViewer
function model.run(player,viewer)
    local scenario=model.scenario(viewer)
    if not scenario or viewer.invalid then return end
    local baseline,reason=baseline_scenario(viewer,scenario.horizon)
    if reason then model.refresh(player,viewer);return end
    local jobs={projection.new(scenario)}
    if baseline then jobs[2]=projection.new(baseline) end
    state().jobs[player.index]={runs=jobs,current=1}
    scheduler.queue_push_unique(state().queue,player.index,player.index)
    viewer.stale=true;model.refresh(player,viewer)
end

---@param event GateEstimatorGuiEvent
---@return boolean handled
function model.on_event(event)
    local element=event.element
    if not (element and element.valid) then return false end
    ---@type GateEstimatorTags
    local t=element.tags or {}
    if event.name==defines.events.on_gui_click and not click_actions[t.action] then return t.parent_gui==GUI end
    if t.action=="gate-estimator" and t.parent_gui=="ei-gate-console" then
        model.open(game.get_player(event.player_index),t.gate_unit,event.tick);return true
    end
    if t.parent_gui~=GUI then return false end
    local player=game.get_player(event.player_index)
    local viewer=state().players[event.player_index]
    if not viewer then return true end
    local d=viewer.draft
    local rebuild=false
    if t.action=="close" then model.close(player.index);return true
    elseif t.action=="run" then model.run(player,viewer);return true
    elseif t.action=="sample" then viewer.sample=element.slider_value;chart.draw(player,viewer);return true
    elseif t.action=="metric" then viewer.metrics[t.key]=element.selected_index;chart.draw(player,viewer);return true
    elseif t.action=="tab" then viewer.tab=element.selected_tab_index;return true
    elseif t.action=="advanced" then viewer.advanced=not viewer.advanced;viewer.gui.advanced.visible=viewer.advanced;return true
    elseif t.action=="rate-unit" then
        viewer.per_minute=element.selected_index==2;viewer.gui.fields.rate.value.text=number(d.rate*(viewer.per_minute and 60 or 1))
        viewer.invalid_fields.rate=nil;viewer.invalid=next(viewer.invalid_fields)~=nil
        model.refresh(player,viewer);return true
    elseif t.action=="power-unit" then
        viewer.power_gw=element.selected_index==2
        viewer.gui.fields.power.value.text=number(d.power/(viewer.power_gw and 1000 or 1))
        viewer.gui.fields.power.heading.caption={"",text("power"),viewer.power_gw and " (GW)" or " (MW)"}
        viewer.invalid_fields.power=nil;viewer.invalid=next(viewer.invalid_fields)~=nil
        model.refresh(player,viewer);return true
    elseif t.action=="pin" then viewer.baseline=copy(model.scenario(viewer))
    elseif t.action=="clear-baseline" then viewer.baseline=nil
    elseif t.action=="snapshot" then model.snapshot(player,viewer,event.tick);rebuild=true
    elseif t.action=="reset" then
        d.rate=1;d.power=1000;d.stress=0;d.saturation=0;d.cooldown=0;d.energy=d.capacity/1e9;d.batch=1;d.horizon=300;rebuild=true
    elseif t.action=="item" then
        d.item=element.elem_value
        if d.item then d.batch=math.min(d.batch,prototypes.item[d.item].stack_size);rebuild=true end
    elseif t.action=="quality" then d.quality=viewer.qualities[element.selected_index]
    elseif t.action=="planet" then d[t.key]=element.elem_value
        if not (d.from and d.to) then d.route="distance" end
        viewer.invalid=next(viewer.invalid_fields or {})~=nil
    elseif t.action=="route" then d.route=route_names[element.selected_index]
    elseif t.action=="horizon" then d.horizon=horizons[element.selected_index]
    elseif t.action=="value" or t.action=="slider" then
        local row=viewer.gui.fields[t.key]
        local value=t.action=="slider" and element.slider_value or tonumber(element.text)
        if value and t.key=="rate" and viewer.per_minute then value=value/60 end
        if value and t.key=="power" and viewer.power_gw then value=value*1000 end
        viewer.invalid_fields=viewer.invalid_fields or {}
        if not value or value~=value or value<row.min or value>row.max then
            viewer.invalid_fields[t.key]=true;viewer.invalid=true;cancel(viewer,player.index);model.refresh(player,viewer);return true
        end
        if row.step>=1 then value=math.floor(value) end
        d[t.key]=value
        if row.slider then row.slider.slider_value=value end
        if t.action=="slider" then row.value.text=number(value) end
        viewer.invalid_fields[t.key]=nil;viewer.invalid=next(viewer.invalid_fields)~=nil
    end
    cancel(viewer,player.index)
    if rebuild then model.build(player,viewer) else model.refresh(player,viewer) end
    return true
end

function model.on_load() repair_pending=true end
function model.on_configuration_changed() repair_pending=true end
---@return boolean
function model.has_tick_work()
    local root=storage.ei_gate_estimator
    return repair_pending or root and next(root.jobs)~=nil or false
end
---@param event EventData.on_tick
function model.updater(event)
    local root=storage.ei_gate_estimator
    if repair_pending then
        repair_pending=false
        if root then
            root.jobs={};root.queue=scheduler.ensure_queue()
            for index,viewer in pairs(root.players) do
                local player=game.get_player(index)
                viewer.results=nil;viewer.stale=true
                if viewer.open and player and player.connected then model.build(player,viewer) else model.close(index) end
            end
        end
    end
    if not root then return end
    local budget=1000
    -- Ten admissions bound stale queue draining as well as simulation work.
    for _=1,10 do
        if budget<=0 then break end
        local index=scheduler.queue_pop_queued(root.queue)
        if not index then break end
        local job=root.jobs[index]
        local viewer=root.players[index];local player=game.get_player(index)
        if job and viewer and viewer.gui and viewer.gui.root.valid and player and player.connected then
            local run=job.runs[job.current]
            local amount=math.min(100,budget);budget=budget-amount
            if projection.advance(run,amount) then job.current=job.current+1 end
            if job.current>#job.runs then
                viewer.results=job.runs;viewer.stale=false;root.jobs[index]=nil
                model.refresh(player,viewer);chart.draw(player,viewer)
            else scheduler.queue_push_unique(root.queue,index,index) end
        else root.jobs[index]=nil end
    end
end

---@param event EventData.on_player_display_resolution_changed|EventData.on_player_display_scale_changed
function model.on_display_changed(event)
    local root=storage.ei_gate_estimator
    local viewer=root and root.players[event.player_index]
    if viewer and viewer.open then model.build(game.get_player(event.player_index),viewer) end
end
function model.on_force_created() chart.hide_surface() end
return model

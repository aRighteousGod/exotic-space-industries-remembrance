--==============================================================================
-- ESIR FILE MAP
-- owns: player radar screens, manual settings, private coverage/beam overlays
-- loaded_by: control.lua; no independent event registrations
-- cadence: one viewer per tick, 15-tick minimum refresh; delayed open one tick
-- rebuild_on: GUI open; close on invalid entity, ownership/surface or opened change
--==============================================================================
-- blueprint: .codex/esir/blueprints/sweeping-radar.md#contract
local gui={}
local config=require("lib/sweeping-radar-config")
local model=require("scripts/control/sweeping-radar")
local scheduler=require("lib/runtime-scheduler")
local GUI=config.gui
local choice_keys={mode={"full","sector","perimeter","pulse","fixed"},
    policy={"watch","survey"},contacts={"recent","pass","beam"},direction={"counterclockwise","oscillating","clockwise"},run={"off","on"}}

local function state()
    local root=model.get_state()
    root.gui=root.gui or {viewers={},order={},indices={},cursor=0,pending={},pending_queue=scheduler.ensure_queue()}
    return root.gui
end

local function tag(action,field)
    return {parent_gui=GUI,action=action,field=field}
end

local function destroy_overlays(viewer)
    for _,object in ipairs(viewer.renders or {}) do if object.valid then object.destroy() end end
    for _,object in ipairs(viewer.beam_renders or {}) do if object.valid then object.destroy() end end
    viewer.renders={};viewer.beam_renders={}
    viewer.coverage_signature=nil;viewer.beam_signature=nil
end

function gui.close(player_index)
    local root=state()
    root.pending[player_index]=nil
    local player=game.get_player(player_index)
    local viewer=root.viewers[player_index]
    if viewer then
        destroy_overlays(viewer)
        local index=root.indices[player_index]
        local last=root.order[#root.order]
        root.order[index]=last;root.indices[last]=index;root.order[#root.order]=nil
        root.indices[player_index]=nil;root.viewers[player_index]=nil
    end
    if player and player.gui.screen[GUI] then player.gui.screen[GUI].destroy() end
end

local function choices(key)
    local result={}
    for _,name in ipairs(choice_keys[key]) do result[#result+1]={"sweeping-radar."..name} end
    return result
end

local function refresh_overlay(player,viewer,record)
    local g=record.geometry
    if not g then destroy_overlays(viewer);return end
    local entity=record.entity
    local function line(list,a,b,color,render_mode)
        list[#list+1]=rendering.draw_line{color=color,width=2,
            from=a,to=b,surface=entity.surface,players={player.index},render_mode=render_mode}
    end
    local function point(angle,distance,side)
        local a=angle*math.pi/180
        return {x=entity.position.x+math.sin(a)*distance+math.cos(a)*(side or 0),
            y=entity.position.y-math.cos(a)*distance+math.sin(a)*(side or 0)}
    end
    -- blueprint-ref: .codex/esir/blueprints/sweeping-radar.md#gui-refresh-cost
    -- Static coverage survives beam movement. Existing save viewers lazily migrate here.
    local signature=table.concat({entity.surface.index,entity.position.x,entity.position.y,
        g.mode,g.near,g.far,g.start,g.width,g.bearing},":")
    local coverage_valid=viewer.coverage_signature==signature
    if coverage_valid then
        for _,object in ipairs(viewer.renders or {}) do if not object.valid then coverage_valid=false;break end end
    end
    if not coverage_valid then
        for _,object in ipairs(viewer.renders or {}) do if object.valid then object.destroy() end end
        viewer.renders={};viewer.coverage_signature=signature
        for _,render_mode in ipairs{"game","chart"} do
        if g.mode==5 then
            for _,side in ipairs{-16,16} do line(viewer.renders,point(g.bearing,g.near,side),point(g.bearing,g.far,side),{0.3,0.8,1,0.7},render_mode) end
        else
            for _,radius in ipairs{g.far,g.near} do
                if radius>0 then
                    viewer.renders[#viewer.renders+1]=rendering.draw_arc{color={0.3,0.8,1,0.65},
                        min_radius=math.max(0,radius-0.5),max_radius=radius+0.5,
                        start_angle=(g.start-90)*math.pi/180,angle=g.width*math.pi/180,
                        target=entity.position,surface=entity.surface,players={player.index},render_mode=render_mode}
                end
            end
            if g.width<360 then
                for _,angle in ipairs{g.start,g.start+g.width} do line(viewer.renders,point(angle,g.near),point(angle,g.far),{0.3,0.8,1,0.7},render_mode) end
            end
        end
        end
    end
    -- Only the two beam lines change when a completed observation moves the beam.
    local show=(record.pass_observations or 0)>0 or record.report.valid
    local beam_signature=signature..":"..tostring(show)..":"..tostring(record.heading)
    local beam_valid=viewer.beam_signature==beam_signature
    if beam_valid then
        for _,object in ipairs(viewer.beam_renders or {}) do if not object.valid then beam_valid=false;break end end
    end
    if beam_valid then return end
    for _,object in ipairs(viewer.beam_renders or {}) do if object.valid then object.destroy() end end
    viewer.beam_renders={};viewer.beam_signature=beam_signature
    if show then
        for _,render_mode in ipairs{"game","chart"} do
            line(viewer.beam_renders,point(record.heading,g.near),point(record.heading,g.far),{0.6,1,0.3,0.9},render_mode)
        end
    end
end

local function refresh(player,viewer,record,tick)
    local frame=player.gui.screen[GUI]
    if not frame then return end
    -- Saved open screens can predate this capability readout. Add it without
    -- rebuilding the controls or losing unapplied manual edits.
    local capabilities=frame.body.capabilities
    if not capabilities then
        capabilities=frame.body.add{type="label",name="capabilities",caption=""}
        viewer.capability_signature=nil
        capabilities.style.single_line=false;capabilities.style.maximal_width=860
    end
    local hardware=config.hardware[record.entity.name]
    local effective=record.effective
    local report=model.report_snapshot(record,tick)
    local elapsed=math.max(1,(tick-record.created_tick)/60)
    local rate=record.observations/elapsed
    local count=record.geometry and record.geometry.count or 0
    local estimate=effective and count/math.max(0.001,record.rate*effective.speed/100) or 0
    local requested=(record.rate or hardware.rate)*(effective and effective.speed or record.settings.speed)/100
    local capability_caption={"sweeping-radar.capabilities",record.entity.quality.localised_name,
        tostring(record.quality_range or 0),string.format("%.0f",((record.quality_rate or 1)-1)*100),
        string.format("%.0f",(1-(record.quality_energy or 1))*100),
        string.format("%.2f",(record.cost or hardware.joules)/1000000),string.format("%.2f",requested),
        string.format("%.2f",hardware.idle/1000000),string.format("%.2f",hardware.input/1000000),
        string.format("%.2f",(hardware.idle+(record.cost or hardware.joules)*requested)/1000000),
        string.format("%.2f",record.rate or hardware.rate)}
    local capability_signature=record.entity.quality.name..":"..table.concat(capability_caption,":",3)
    if viewer.capability_signature~=capability_signature then
        capabilities.caption=capability_caption;viewer.capability_signature=capability_signature
    end
    local metric_caption={"sweeping-radar.metrics",
        {"sweeping-radar.status-"..record.status},tostring(record.maximum or hardware.range),
        string.format("%.2f",rate),tostring(count),string.format("%.1f",estimate),
        record.pass_ticks and string.format("%.1f",record.pass_ticks/60) or "—",
        string.format("%.2f",(ei_lib.entity_check(record.power) and record.power.energy or 0)/1000000),
        string.format("%.2f",hardware.buffer/1000000),
        string.format("%.2f",(hardware.idle+(record.cost or hardware.joules)*rate)/1000000),
        report.valid and tostring(report.count) or "—",tostring(report.age),tostring(report.contact_age),
        not report.valid and {"sweeping-radar.unavailable"} or report.incomplete and {"sweeping-radar.incomplete"} or {"sweeping-radar.complete"},
        tostring(report.sample_age)}
    local metric_signature=record.status..":"..table.concat(metric_caption,":",3,13)..":"
        ..tostring(report.valid)..":"..tostring(report.incomplete)..":"..tostring(report.sample_age)
    if viewer.metric_signature~=metric_signature then
        frame.body.metrics.caption=metric_caption;viewer.metric_signature=metric_signature
    end
    refresh_overlay(player,viewer,record)
end

function gui.open(player_index,entity,tick)
    local player=game.get_player(player_index)
    local record=model.get_record(entity)
    if not(player and record and player.force==entity.force and player.surface==entity.surface) then return end
    gui.close(player_index)
    local root=state()
    local viewer={entity=entity,fields={},renders={},next_tick=tick}
    root.viewers[player_index]=viewer
    root.order[#root.order+1]=player_index;root.indices[player_index]=#root.order
    local frame=player.gui.screen.add{type="frame",name=GUI,direction="vertical"}
    frame.auto_center=true
    local title=frame.add{type="flow",direction="horizontal"}
    title.add{type="label",caption={"entity-name."..entity.name},style="frame_title"}
    local spacer=title.add{type="empty-widget",style="ei_titlebar_draggable_spacer"}
    spacer.drag_target=frame
    title.add{type="sprite-button",sprite="utility/close",style="frame_action_button",tags=tag("close")}
    local body=frame.add{type="flow",name="body",direction="vertical"}
    body.style.maximal_width=900
    local help=body.add{type="label",caption={"sweeping-radar.controls-help"}}
    help.style.single_line=false;help.style.maximal_width=860
    local scroll=body.add{type="scroll-pane",vertical_scroll_policy="auto",horizontal_scroll_policy="never"}
    scroll.style.maximal_height=math.max(150,math.min(450,player.display_resolution.height/player.display_scale-400))
    local table_gui=scroll.add{type="table",column_count=4}
    for _,key in ipairs{"control","manual","override","signal"} do table_gui.add{type="label",caption={"sweeping-radar."..key},style="bold_label"} end
    local settings=record.settings
    local mode=settings.modes[settings.mode]
    for _,field in ipairs(config.fields) do
        table_gui.add{type="label",caption={"sweeping-radar.field-"..field.key},tooltip={"sweeping-radar.tip-"..field.key}}
        local value=mode[field.key] or settings[field.key] or 0
        local widget
        if choice_keys[field.key] then
            local offset=field.key=="direction" and 2 or (field.key=="policy" or field.key=="run") and 1 or 0
            widget=table_gui.add{type="drop-down",items=choices(field.key),selected_index=math.max(1,math.min(#choice_keys[field.key],value+offset)),tags=tag("value",field.key)}
        else
            widget=table_gui.add{type="textfield",text=tostring(value),numeric=true,allow_negative=true,allow_decimal=false,tags=tag("value",field.key)}
            widget.style.width=130
        end
        local override=settings.overrides[field.key] or {}
        local checkbox=table_gui.add{type="checkbox",state=override.enabled==true,tags=tag("override",field.key)}
        local chosen=override.signal or {type="virtual",name="signal-"..field.signal}
        local signal=table_gui.add{type="choose-elem-button",elem_type="signal",signal=model.valid_signal(chosen) and chosen or nil,tags=tag("signal",field.key)}
        viewer.fields[field.key]={value=widget,override=checkbox,signal=signal}
    end
    local angles=body.add{type="flow",direction="horizontal"}
    angles.add{type="label",caption={"sweeping-radar.center-width"}}
    local width=(mode.stop-mode.start)%360;if width==0 then width=360 end
    viewer.center=angles.add{type="textfield",text=tostring((mode.start+width/2)%360),numeric=true,allow_negative=true}
    viewer.center.style.width=100
    viewer.width=angles.add{type="textfield",text=tostring(width),numeric=true,allow_negative=false}
    viewer.width.style.width=100
    angles.add{type="button",caption={"sweeping-radar.set-arc"},tags=tag("arc")}
    local buttons=body.add{type="flow",direction="horizontal"}
    buttons.add{type="button",caption={"sweeping-radar.apply"},tags=tag("apply")}
    buttons.add{type="button",caption={"sweeping-radar.trigger"},tags=tag("trigger")}
    buttons.add{type="button",caption={"sweeping-radar.help"},tags=tag("help")}
    local metrics=body.add{type="label",name="metrics",caption=""}
    metrics.style.single_line=false;metrics.style.maximal_width=860
    player.opened=frame
    refresh(player,viewer,record,tick)
end

local function apply(player,viewer,record,tick)
    local settings=config.copy_settings(record.settings)
    local mode=settings.modes[settings.mode]
    for _,field in ipairs(config.fields) do
        local entry=viewer.fields[field.key]
        local value
        if choice_keys[field.key] then
            local offset=field.key=="direction" and 2 or (field.key=="policy" or field.key=="run") and 1 or 0
            value=entry.value.selected_index-offset
        else value=tonumber(entry.value.text) or 0 end
        if mode[field.key]~=nil then mode[field.key]=value else settings[field.key]=value end
        settings.overrides[field.key]={enabled=entry.override.state,signal=entry.signal.elem_value}
    end
    model.set_settings(record,settings,tick)
    gui.open(player.index,record.entity,tick)
end

function gui.on_event(event)
    local element=event.element
    if not(element and element.valid and element.tags.parent_gui==GUI) then return end
    local player=game.get_player(event.player_index)
    local viewer=state().viewers[event.player_index]
    local record=viewer and model.get_record(viewer.entity)
    if not(player and viewer and record and player.force==record.entity.force and player.surface==record.entity.surface
        and player.opened==player.gui.screen[GUI]) then gui.close(event.player_index);return end
    local action=element.tags.action
    if action=="close" then gui.close(player.index)
    elseif action=="apply" then apply(player,viewer,record,event.tick)
    elseif action=="trigger" then model.trigger(record,event.tick)
    elseif action=="arc" then
        local center=(tonumber(viewer.center.text) or 0)%360
        local width=math.max(1,math.min(360,tonumber(viewer.width.text) or 360))
        viewer.fields.start.value.text=tostring((center-width/2)%360)
        viewer.fields.stop.value.text=tostring((center+width/2)%360)
    elseif action=="value" and element.tags.field=="mode" and event.name==defines.events.on_gui_selection_state_changed then
        apply(player,viewer,record,event.tick)
    elseif action=="help" then
        player.print({"sweeping-radar.informatron-body"})
    end
end

function gui.on_open_input(event)
    local player=game.get_player(event.player_index)
    local entity=player and player.selected
    if not model.get_record(entity) then return end
    local root=state()
    root.pending[event.player_index]={entity=entity,tick=event.tick+1}
    scheduler.queue_push_unique(root.pending_queue,event.player_index,event.player_index)
end

---@param player_index integer
---@return boolean
function gui.has_open_gui_session(player_index)
    local root=storage.ei and storage.ei.sweeping_radar
    local ui=root and root.gui
    return ui~=nil and (ui.pending[player_index]~=nil or ui.viewers[player_index]~=nil)
end

---@param event EventData.on_gui_opened
function gui.on_gui_opened(event)
    local root=state()
    if not model.get_record(event.entity) then root.pending[event.player_index]=nil;return end
    root.pending[event.player_index]={entity=event.entity,tick=event.tick+1}
    scheduler.queue_push_unique(root.pending_queue,event.player_index,event.player_index)
end

function gui.on_gui_closed(event)
    local player=game.get_player(event.player_index)
    local frame=player and player.gui.screen[GUI]
    if frame and event.element==frame then
        local root=state()
        local pending=root.pending[event.player_index]
        local viewer=root.viewers[event.player_index]
        -- Opening another radar can close the old screen in the same tick.
        local another=pending and viewer and pending.entity~=viewer.entity and pending
        gui.close(event.player_index)
        if another then root.pending[event.player_index]=another end
    end
end

function gui.has_tick_work()
    local root=storage.ei and storage.ei.sweeping_radar
    local ui=root and root.gui
    return ui and (#ui.order>0 or scheduler.queue_length(ui.pending_queue)>0) or false
end

function gui.updater(event)
    local root=state()
    local index=scheduler.queue_peek(root.pending_queue)
    if index then
        local request=root.pending[index]
        if not request or event.tick>=request.tick then
            scheduler.queue_pop(root.pending_queue,index);root.pending[index]=nil
            if request then gui.open(index,request.entity,event.tick) end
            return
        end
    end
    if #root.order==0 then return end
    root.cursor=(root.cursor%#root.order)+1
    index=root.order[root.cursor]
    local player=game.get_player(index)
    local viewer=root.viewers[index]
    local record=viewer and model.get_record(viewer.entity)
    if not(player and record and player.connected and player.force==record.entity.force
        and player.surface==record.entity.surface and player.opened==player.gui.screen[GUI]) then gui.close(index);return end
    if event.tick<viewer.next_tick then return end
    viewer.next_tick=event.tick+config.ui_ticks
    refresh(player,viewer,record,event.tick)
end
return gui

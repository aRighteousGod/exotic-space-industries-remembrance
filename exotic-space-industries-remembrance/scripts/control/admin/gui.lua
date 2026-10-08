-- blueprint: .codex/esir/blueprints/admin-tools.md#contract
-- Persistent page trees preserve drafts, focused controls and scroll positions.
-- Refresh is explicit/invalidation-driven, with optional visible-only timed refresh.
local config=require("lib/admin-tools-config")
local common=require("scripts/control/admin/common")
local mod_gui=require("__core__/lualib/mod-gui")
local lib=require("lib/lib")
local scheduler=require("lib/runtime-scheduler")
local model={}
local context
local GUI=config.gui
local function label(id) return {"ei-admin."..id} end
local function tags(action,extra)
    local result={parent_gui=GUI,action=action}
    for k,v in pairs(extra or {}) do result[k]=v end
    return result
end
local function caption(parent,id,style)
    return parent.add{type="label",caption=label(id),style=style or "ei_admin_caption"}
end
local function button(parent,id,action,extra,danger)
    return parent.add{type="button",caption=label(id),tooltip=label(id),style=danger and "red_button" or "button",tags=tags(action,extra)}
end
local function row(parent,layout) return parent.add{type="flow",direction="horizontal",tags={admin_layout=layout}} end
local function heading(parent,id) caption(parent,id,"ei_admin_heading") end
local function field(parent,session,id,default)
    local r=row(parent,"field");caption(r,id)
    if session.drafts[id]==nil then session.drafts[id]=tostring(default or "") end
    local element=r.add{type="textfield",text=tostring(session.drafts[id] or default or ""),style="ei_admin_field",tags=tags("draft",{field=id})}
    session.fields[id]=element
    return element
end
local function selector(parent,session,id,kind,default)
    local r=row(parent,"selector");caption(r,id)
    if session.drafts[id]==nil then session.drafts[id]=default end
    local spec={type="choose-elem-button",elem_type=kind,tags=tags("draft",{field=id})}
    spec[kind]=session.drafts[id]
    local element=r.add(spec)
    session.fields[id]=element
    return element
end
local function choice(parent,session,id,values,default)
    local r=row(parent,"choice");caption(r,id)
    local items={};local selected=1
    for i,value in ipairs(values) do items[i]=label(id.."-"..tostring(value));if tostring(session.drafts[id] or default)==tostring(value) then selected=i end end
    local element=r.add{type="drop-down",items=items,selected_index=selected,tags=tags("draft",{field=id})}
    session.fields[id]=element;session.choices[id]=values;session.drafts[id]=values[selected]
    return element
end
local function action(parent,id,args,danger)
    return button(parent,id,"execute",{operation=id,args=args or {},confirm=danger or false},danger)
end
local function actions(parent,list)
    local i=1
    while i<=#list do
        local spec=list[i];local following=list[i+1]
        local operation=spec[2] and spec[2].operation or spec[1]
        local paired=following and spec[2] and spec[2].enabled==true and following[2]
            and following[2].enabled==false and (following[2].operation or following[1])==operation
        local r=row(parent,paired and "buttons" or nil)
        action(r,spec[1],spec[2],spec[3])
        if paired then action(r,following[1],following[2],following[3]);i=i+1 end
        i=i+1
    end
end
local function session_for(index)
    local root=common.peek();return root and root.sessions[index]
end
function model.configure(ctx) context=ctx end

-- One cancellable delayed entry per visible viewer; no session scan on idle ticks.
local function cancel_auto_refresh(index,session)
    local root=common.peek();local due=session.auto_due_tick
    if root and due and root.auto_refresh_buckets then
        local bucket=root.auto_refresh_buckets[due]
        if bucket then
            for i=#bucket,1,-1 do if bucket[i]==index then table.remove(bucket,i) end end
            if not next(bucket) then root.auto_refresh_buckets[due]=nil end
        end
        root.auto_refresh_due_tick=scheduler.delayed_next_due_tick(root.auto_refresh_buckets) or nil
    end
    session.auto_due_tick=nil
end

local function schedule_auto_refresh(index,session,tick)
    cancel_auto_refresh(index,session)
    if not (session.auto_refresh and session.root and session.root.valid and session.root.visible) then return end
    local root=common.peek();if not root then return end
    local seconds=tonumber(session.drafts.auto_refresh_interval) or 5
    session.auto_due_tick=tick+seconds*60
    root.auto_refresh_buckets=scheduler.delayed_schedule(root.auto_refresh_buckets,session.auto_due_tick,index)
    root.auto_refresh_due_tick=math.min(root.auto_refresh_due_tick or session.auto_due_tick,session.auto_due_tick)
end

local function sync_auto_refresh_button(session)
    local element=session.auto_refresh_button
    if element and element.valid then
        local enabled=session.auto_refresh==true
        if session.auto_refresh_display~=enabled then
            element.caption=label(enabled and "auto-refresh-on" or "auto-refresh-off")
            element.toggled=enabled;session.auto_refresh_display=enabled
        end
    end
end

---@param tick MapTick
function model.refresh_automatically(tick)
    local root=common.peek()
    if not (root and root.auto_refresh_due_tick and tick>=root.auto_refresh_due_tick) then return end
    local visits=0;local snapshot
    for _,index in ipairs(scheduler.delayed_take_due_through(root.auto_refresh_buckets,tick)) do
        local session=root.sessions[index]
        if session and session.auto_due_tick and session.auto_due_tick<=tick then
            session.auto_due_tick=nil
            local player=game.get_player(index)
            if not common.authorize(player) then model.close(index,true)
            elseif not player.connected then model.close(index)
            elseif session.auto_refresh and session.root and session.root.valid and session.root.visible then
                if visits<8 then
                    if ({chunks=true,creation=true,fluids=true,enemies=true,effects=true,planets=true})[session.page] then
                        snapshot=snapshot or context.world.peek_summary()
                    end
                    model.refresh(index,tick,snapshot);if root.dirty then root.dirty[index]=nil end;visits=visits+1
                    schedule_auto_refresh(index,session,tick)
                else
                    session.auto_due_tick=tick+1
                    root.auto_refresh_buckets=scheduler.delayed_schedule(root.auto_refresh_buckets,tick+1,index)
                end
            end
        end
    end
    root.auto_refresh_due_tick=scheduler.delayed_next_due_tick(root.auto_refresh_buckets) or nil
end

local function summary(session,player,args,operation)
    args=args or {}
    if operation=="repair" then return {"ei-admin.diag-repair-target",args.module_id or "?"} end
    if operation=="gaia-reforge" then return {"ei-admin.confirm-gaia-target",player.name} end
    local target=game.get_player(tonumber(args.player_index or session.drafts.player_index) or player.index)
    local force=game.forces[tonumber(args.force_index or session.drafts.force_index) or player.force.index]
    local entity=lib.get_valid_entity(args.entity or session.entity)
    local planet=args.planet or session.drafts.planet or player.physical_surface.name
    local position=args.position or session.position or player.physical_position
    local player_name=(operation=="ban" or operation=="unban") and args.player_name and args.player_name~="" and args.player_name or (target and target.name or "?")
    return {"ei-admin.target-summary",player_name,force and force.name or "?",planet,
        operation=="travel" and not args.manual and "spawn" or string.format("%.1f, %.1f",position.x,position.y),entity and entity.localised_name or label("none")}
end

local function targets(parent,session,player)
    local pane=parent.add{type="scroll-pane",direction="vertical"};session.target_pane=pane
    pane.horizontal_scroll_policy="never";pane.vertical_scroll_policy="auto-and-reserve-space"
    local f=pane.add{type="frame",direction="vertical",style="inside_shallow_frame"};session.target_frame=f
    f.style.padding=6
    session.summary=caption(f,"none")
    session.readout=caption(f,"none","ei_admin_muted")
    local selectors=f.add{type="table",column_count=3};selectors.style.horizontal_spacing=6;session.target_selectors=selectors
    local players,player_ids={},{}
    for _,target in pairs(game.players) do players[#players+1]=target.name..(target.connected and "" or " (offline)");player_ids[#player_ids+1]=target.index end
    local forces,force_ids={},{}
    for _,force in pairs(game.forces) do forces[#forces+1]=force.name;force_ids[#force_ids+1]=force.index end
    local planets,planet_ids={},{}
    for _,planet in pairs(context.planets()) do planets[#planets+1]=planet.localised_name or planet.name;planet_ids[#planet_ids+1]=planet.name end
    local function target_dropdown(id,items,ids,default)
        local r=selectors.add{type="flow",direction="vertical"}
        caption(r,id);local selected=1
        for i,value in ipairs(ids) do if tostring(value)==tostring(session.drafts[id] or default) then selected=i end end
        session.drafts[id]=ids[selected];session.choices[id]=ids
        local element=r.add{type="drop-down",items=items,selected_index=selected,tags=tags("target",{field=id})}
        session.fields[id]=element
    end
    target_dropdown("player_index",players,player_ids,player.index)
    target_dropdown("force_index",forces,force_ids,player.force.index)
    target_dropdown("planet",planets,planet_ids,player.physical_surface.planet and player.physical_surface.planet.name or "nauvis")
    local r=row(f,"buttons");button(r,"pick-location","pick",{kind="location"});button(r,"pick-area","pick",{kind="area"});button(r,"pick-entity","pick",{kind="entity"})
    r=row(f,"coordinates")
    field(r,session,"x",0);field(r,session,"y",0);button(r,"use-coordinates","coordinates")
end

-- Reconcile catalogs only on explicit/dirty refresh. Existing controls retain focus and layout.
local function sync_targets(session,player)
    local catalogs={player_index={},force_index={},planet={}}
    for _,target in pairs(game.players) do catalogs.player_index[#catalogs.player_index+1]={target.index,target.name..(target.connected and "" or " (offline)")} end
    for _,force in pairs(game.forces) do catalogs.force_index[#catalogs.force_index+1]={force.index,force.name} end
    for _,planet in pairs(context.planets()) do catalogs.planet[#catalogs.planet+1]={planet.name,planet.localised_name or planet.name} end
    session.target_signatures=session.target_signatures or {}
    for id,entries in pairs(catalogs) do
        local element=session.fields[id]
        if element and element.valid then
            table.sort(entries,function(a,b)return a[1]<b[1] end)
            local ids,items,selected={},{},nil
            for i,entry in ipairs(entries) do
                ids[i]=entry[1];items[i]=entry[2]
                if entry[1]==session.drafts[id] then selected=i end
            end
            if not selected and session.drafts[id]~=nil then
                selected=#ids+1;ids[selected]=session.drafts[id];items[selected]="Unavailable ("..tostring(ids[selected])..")"
            end
            local signature=serpent.line({ids,items})
            if session.target_signatures[id]~=signature then
                element.items=items;session.choices[id]=ids;session.target_signatures[id]=signature
            end
            if element.selected_index~=(selected or 0) then element.selected_index=selected or 0 end
        end
    end
end

-- A display event adjusts existing nodes only: editing focus and native scroll state
-- stay owned by the same LuaGuiElements. No resize polling or page rebuild is needed.
local function fit_content(parent,width)
    width=math.max(1,math.floor(width))
    local children=parent.children
    local horizontal=parent.type=="flow" and parent.direction=="horizontal"
    local layout=parent.tags.admin_layout
    local columns=parent.type=="table" and parent.column_count or (horizontal and #children or 1)
    local share=math.max(1,math.floor((width-math.max(0,columns-1)*6)/math.max(1,columns)))
    for i,element in ipairs(children) do
        local available=share
        if horizontal and (layout=="field" or layout=="selector" or layout=="choice") then
            local control=layout=="selector" and 40 or math.min(layout=="field" and 160 or 240,math.floor(width*0.60))
            available=i==1 and math.max(1,width-control-6) or control
        elseif horizontal and layout=="diagnostic-owner" then
            available=i==1 and math.max(1,width-136) or math.min(130,width)
        end
        local style=element.style
        style.minimal_width=0;style.maximal_width=available
        if element.type=="label" then
            style.single_line=false
        elseif element.type=="textfield" or element.type=="drop-down" or element.type=="text-box" then
            style.width=available
        elseif element.type=="flow" or element.type=="frame" or element.type=="table" then
            fit_content(element,available)
        end
    end
end

local function resize_window(player,session,force)
    if not (session.root and session.root.valid and session.navigation and session.navigation.valid) then return end
    local scale=player.display_scale;local resolution=player.display_resolution
    local width=math.max(1,math.floor(math.min(1060,resolution.width/scale-24)))
    local height=math.max(1,math.floor(math.min(820,resolution.height/scale-24)))
    local status=session.status.caption~=""
    local confirm=session.confirm_frame.visible
    local show_targets=session.page~="diagnostics"
    local signature=width..":"..height..":"..tostring(status)..":"..tostring(confirm)..":"..tostring(show_targets)
    if not force and session.layout_signature==signature then return end
    session.layout_signature=signature
    local root=session.root
    -- Capture the dragged location before changing dimensions. Native auto-center
    -- otherwise recenters on layout/feedback changes after the initial opening.
    local position=session.center_pending and {x=(resolution.width-width*scale)/2,y=(resolution.height-height*scale)/2}
        or root.location or session.location or {x=0,y=0}
    if root.auto_center then root.auto_center=false end
    session.center_pending=nil
    local body_height=math.max(1,height-112)
    local nav_width=math.min(width<900 and 168 or 202,math.floor(width*0.28))
    local right_width=math.max(1,width-24-nav_width)
    local feedback_height=(status or confirm) and math.min(math.floor(body_height*0.40),(status and 44 or 0)+(confirm and 112 or 0)) or 0
    local available=math.max(1,body_height-feedback_height-(feedback_height>0 and 4 or 0))
    local target_height=show_targets and math.min(224,math.floor((available-4)*0.44)) or 0
    local page_height=math.max(1,available-target_height-(show_targets and 4 or 0))
    root.style.width=width;root.style.height=height
    session.body.style.height=body_height
    session.navigation.style.width=nav_width;session.navigation.style.height=body_height
    for _,element in ipairs(session.navigation.children) do
        element.style.minimal_width=0;element.style.maximal_width=math.max(1,nav_width-18)
        if element.type=="button" then element.style.width=math.max(1,nav_width-18)
        elseif element.type=="label" then element.style.single_line=false end
    end
    session.right.style.width=right_width;session.right.style.height=body_height
    session.target_pane.visible=show_targets
    session.target_pane.style.width=right_width;session.target_pane.style.height=math.max(1,target_height)
    session.target_frame.style.width=math.max(1,right_width-18)
    fit_content(session.target_frame,right_width-30)
    session.content.style.width=right_width;session.content.style.height=page_height
    for _,pane in pairs(session.pages) do
        pane.style.width=right_width;pane.style.height=page_height
        fit_content(pane,right_width-18)
    end
    local diagnostic=session.diagnostics
    if diagnostic then
        for _,pane in ipairs({diagnostic.overview,diagnostic.detail}) do
            pane.style.width=math.max(1,right_width-18);pane.style.height=math.max(1,page_height-30)
            fit_content(pane,right_width-36)
        end
    end
    session.feedback.visible=status or confirm
    session.feedback.style.width=right_width;session.feedback.style.height=math.max(1,feedback_height)
    session.status.visible=status
    session.status.style.maximal_width=math.max(1,right_width-18)
    session.confirm_frame.style.width=math.max(1,right_width-18)
    fit_content(session.confirm_frame,right_width-30)
    fit_content(session.toolbar,width-16)
    session.title.style.maximal_width=width-16
    session.title_caption.style.minimal_width=0;session.title_caption.style.maximal_width=math.max(1,width-132)
    local margin=math.floor(8*scale)
    local x_max=math.max(0,math.floor(resolution.width-width*scale-margin))
    local y_max=math.max(0,math.floor(resolution.height-height*scale-margin))
    local location={x=math.floor(math.max(0,math.min(x_max,math.max(margin,position.x)))),
        y=math.floor(math.max(0,math.min(y_max,math.max(margin,position.y))))}
    local current=root.location
    if not current or current.x~=location.x or current.y~=location.y then root.location=location end
    session.location=location
end

function model.on_display_changed(event)
    local player=game.get_player(event.player_index);local session=session_for(event.player_index)
    if player and player.valid and session then resize_window(player,session,true) end
end

local function catalog_choice(parent,session,id)
    local r=row(parent,"choice");caption(r,id)
    local element=r.add{type="drop-down",items={},tags=tags("draft",{field=id})}
    session.fields[id]=element
    return element
end

local function sync_catalog(session,id,kind,search,optional)
    local element=session.fields[id];if not (element and element.valid) then return end
    local ids,items={},{}
    if optional then ids[1]="";items[1]=label("none") end
    local selected=optional and 1 or 0;local draft=session.drafts[id]
    search=string.lower(search or "")
    for _,entry in ipairs(context.world.get_catalog(kind)) do
        if search=="" or string.find(string.lower(entry.name),search,1,true) or entry.name==draft then
            ids[#ids+1]=entry.name;items[#items+1]={"",entry.caption or entry.name," [",entry.name,"]"}
            if entry.name==draft then selected=#ids end
        end
    end
    if selected==0 and #ids>0 then selected=1 end
    local signature=serpent.line({ids,items})
    session.catalog_signatures=session.catalog_signatures or {}
    if session.catalog_signatures[id]~=signature then element.items=items;session.catalog_signatures[id]=signature end
    session.choices[id]=ids;session.drafts[id]=ids[selected]
    if element.selected_index~=selected then element.selected_index=selected end
end

local function index_availability(session,parent)
    session.availability=session.availability or {}
    for _,element in ipairs(parent.children) do
        local t=element.tags
        local operation=t.args and t.args.operation or t.operation
        if t.action=="execute" and ({kick=true,ban=true,add_pollution=true,clear_pollution=true})[operation] then
            session.availability[#session.availability+1]={element=element,operation=operation}
        end
        if #element.children>0 then index_availability(session,element) end
    end
end

local function refresh_availability(session,player)
    local surface=session.surface_index and game.get_surface(session.surface_index)
        or (game.planets[session.drafts.planet or ""] and game.planets[session.drafts.planet].surface)
    for _,entry in ipairs(session.availability or {}) do
        if entry.element.valid then
            local moderation=entry.operation=="kick" or entry.operation=="ban"
            local available=moderation and game.is_multiplayer() or (not moderation and surface and surface.pollutant_type~=nil) or false
            entry.element.enabled=available
            entry.element.tooltip=available and label(entry.operation) or label(moderation and "multiplayer-only" or "pollution-unavailable")
        end
    end
end

local function diagnostic_value(value)
    if value==nil or value=="Not sampled" then return label("diag-not-sampled") end
    if type(value)=="boolean" then return label(value and "diag-yes" or "diag-no") end
    return tostring(value)
end

local function diagnostic_name(name)
    local words=tostring(name):gsub("([a-z])([A-Z])","%1 %2"):gsub("[_.]"," ")
    return words:sub(1,1):upper()..words:sub(2)
end

local function diagnostic_state(value)
    local known={initialized=true,["not-initialized"]=true,stateless=true,helper=true,infrastructure=true,stateful=true}
    return known[value] and label("diag-state-"..value) or diagnostic_value(value)
end

local function diagnostic_caption(diagnostic,key,element,value)
    local signature=serpent.line(value)
    if diagnostic.signatures[key]~=signature then element.caption=value;diagnostic.signatures[key]=signature end
end

-- Factorio permits 20 parameters per LocalisedString. Keep long metric/inspection
-- lists as shallow concatenation groups instead of crossing that native limit.
local function diagnostic_join(parts)
    while #parts>21 do
        local grouped={""}
        for first=2,#parts,20 do
            local group={""}
            for i=first,math.min(first+19,#parts) do group[#group+1]=parts[i] end
            grouped[#grouped+1]=group
        end
        parts=grouped
    end
    return parts
end

local function diagnostic_metrics(values)
    local keys={}
    for key,value in pairs(values or {}) do
        if type(value)=="string" or type(value)=="number" or type(value)=="boolean" then keys[#keys+1]=key end
    end
    table.sort(keys)
    if #keys==0 then return label("diag-not-sampled") end
    local lines={""}
    for _,key in ipairs(keys) do
        if #lines>1 then lines[#lines+1]="\n" end
        lines[#lines+1]={"ei-admin.diag-metric",diagnostic_name(key),diagnostic_value(values[key])}
    end
    return diagnostic_join(lines)
end

local function overview_metrics(snapshot)
    local values={}
    for key,value in pairs(snapshot.cached or {}) do if type(value)=="number" then values[key]=value end end
    for key,value in pairs(snapshot.fields or {}) do if type(value)=="number" then values[key]=value end end
    local keys={};for key in pairs(values) do keys[#keys+1]=key end;table.sort(keys)
    local counts,queue={""},{""}
    local count_added,queue_added=0,0
    for _,key in ipairs(keys) do
        local lower=key:lower()
        local queued=lower:find("pending",1,true) or lower:find("ready",1,true) or lower:find("dirty",1,true)
            or lower:find("queue",1,true) or lower:find("active_job",1,true)
        local counted=lower:find("count",1,true) or lower:find("tracked",1,true) or lower:find("registered",1,true)
        if queued and not lower:find("tick",1,true) and queue_added<1 then
            queue[#queue+1]={"ei-admin.diag-metric",diagnostic_name(key),values[key]};queue_added=queue_added+1
        elseif counted and count_added<2 then
            if count_added>0 then counts[#counts+1]="; " end
            counts[#counts+1]={"ei-admin.diag-metric",diagnostic_name(key),values[key]};count_added=count_added+1
        end
    end
    return count_added>0 and counts or label("diag-counts-unsampled"),queue_added>0 and queue or label("diag-queue-unsampled")
end

local function diagnostic_inspection(snapshot)
    local inspection=snapshot.inspection
    if not inspection then return label("diag-no-inspection") end
    local lines={"",{"ei-admin.diag-inspection-snapshot",diagnostic_value(inspection.started_tick),
        diagnostic_value(inspection.completed_tick),diagnostic_value(inspection.examined)}}
    if inspection.world_may_have_changed then lines[#lines+1]="\n";lines[#lines+1]=label("diag-inspection-nonatomic") end
    if inspection.truncated then lines[#lines+1]="\n";lines[#lines+1]=label("diag-inspection-truncated") end
    for _,collection in ipairs(inspection.collections or {}) do
        lines[#lines+1]="\n"
        lines[#lines+1]={"ei-admin.diag-collection",diagnostic_name(collection.path),collection.entries or 0,
            collection.valid_entities or 0,collection.invalid_entities or 0,collection.scalar_values or 0}
        if collection.missing then lines[#lines+1]=" ";lines[#lines+1]=label("diag-collection-missing") end
        if collection.changed_during_inspection or collection.unsupported_key then
            lines[#lines+1]=" ";lines[#lines+1]=label("diag-collection-incomplete")
        end
    end
    return diagnostic_join(lines)
end

local function build_diagnostics(parent,session)
    local diagnostic={rows={},values={},signatures={}};session.diagnostics=diagnostic
    parent.vertical_scroll_policy="never"
    diagnostic.overview=parent.add{type="scroll-pane",direction="vertical"}
    diagnostic.detail=parent.add{type="scroll-pane",direction="vertical"}
    for _,pane in ipairs({diagnostic.overview,diagnostic.detail}) do
        pane.horizontal_scroll_policy="never";pane.vertical_scroll_policy="auto-and-reserve-space"
    end
    local toolbar=row(diagnostic.overview,"buttons")
    button(toolbar,"refresh","refresh");button(toolbar,"export","export")
    diagnostic.overview_cancel=button(toolbar,"cancel-inspection","cancel-inspection")
    caption(diagnostic.overview,"diag-overview-note","ei_admin_muted")
    diagnostic.overview_activity=caption(diagnostic.overview,"diag-inspection-idle","ei_admin_muted")
    for _,owner in ipairs(context.registry.list()) do
        local r=row(diagnostic.overview,"diagnostic-owner")
        local body=r.add{type="flow",direction="vertical"}
        local name=body.add{type="label",caption=owner.label or owner.id,tooltip=owner.id,style="ei_admin_heading"}
        local status=body.add{type="label",caption="",style="ei_admin_caption"}
        diagnostic.rows[owner.id]={name=name,status=status}
        button(r,"inspect","inspect",{module_id=owner.id})
    end
    toolbar=row(diagnostic.detail,"buttons")
    button(toolbar,"diag-back","diagnostic-overview");button(toolbar,"refresh","refresh");button(toolbar,"export","export")
    diagnostic.name=caption(diagnostic.detail,"none","ei_admin_heading")
    for _,key in ipairs({"role","state","enabled","schema","sample","cache","repair"}) do
        diagnostic.values[key]=caption(diagnostic.detail,"none")
    end
    toolbar=row(diagnostic.detail,"buttons")
    diagnostic.inspect=button(toolbar,"deep-inspect","deep-inspect")
    diagnostic.cancel=button(toolbar,"cancel-inspection","cancel-inspection")
    diagnostic.activity=caption(diagnostic.detail,"diag-inspection-idle","ei_admin_muted")
    for _,key in ipairs({"fields","cached","counters","inspection"}) do
        heading(diagnostic.detail,"diag-"..key)
        diagnostic.values[key]=caption(diagnostic.detail,"diag-not-sampled")
    end
    caption(diagnostic.detail,"diag-detail-note","ei_admin_muted")
end

local function refresh_diagnostics(session,player,tick)
    local diagnostic=session.diagnostics;if not diagnostic then return end
    local selected=session.module_id~=nil
    diagnostic.overview.visible=not selected;diagnostic.detail.visible=selected
    local snapshot=context.diagnostics(session.module_id,tick,player.index)
    if not selected then
        for _,owner in ipairs(snapshot.owners or {}) do
            local target=diagnostic.rows[owner.id]
            if target then
                local counts,queue=overview_metrics(owner)
                diagnostic_caption(diagnostic,"owner-"..owner.id,target.status,{"ei-admin.diag-overview-row",
                    diagnostic_state(owner.state),diagnostic_value(owner.schema),counts,queue})
            end
        end
    else
        diagnostic_caption(diagnostic,"name",diagnostic.name,{"",snapshot.label or session.module_id," (",session.module_id,")"})
        local values={
            role={"ei-admin.diag-role",diagnostic_state(snapshot.classification)},
            state={"ei-admin.diag-state",diagnostic_state(snapshot.state)},
            enabled={"ei-admin.diag-enabled",type(snapshot.enabled)=="boolean" and label(snapshot.enabled and "on" or "off") or diagnostic_value(snapshot.enabled)},
            schema={"ei-admin.diag-schema",diagnostic_value(snapshot.schema)},
            sample={"ei-admin.diag-sample",diagnostic_value(snapshot.sample_tick)},
            cache={"ei-admin.diag-cache",diagnostic_value(snapshot.cache_updated_tick)},
            repair=snapshot.last_repair_tick and {"ei-admin.diag-last-repair",snapshot.last_repair_tick,
                label(snapshot.last_repair_ok and "diag-repair-ok" or "diag-repair-failed"),snapshot.last_repair_message or ""} or label("diag-no-repair"),
            fields=diagnostic_metrics(snapshot.fields),cached=diagnostic_metrics(snapshot.cached),counters=diagnostic_metrics(snapshot.counters),
            inspection=diagnostic_inspection(snapshot),
        }
        for key,value in pairs(values) do diagnostic_caption(diagnostic,key,diagnostic.values[key],value) end
    end
    local state=common.peek();local active=state and state.inspection
    local activity=active and {"ei-admin.diag-inspection-running",active.id,active.examined or 0} or label("diag-inspection-idle")
    diagnostic_caption(diagnostic,"activity",diagnostic.activity,activity)
    diagnostic_caption(diagnostic,"overview-activity",diagnostic.overview_activity,activity)
    diagnostic.inspect.enabled=selected and not active
    diagnostic.cancel.enabled=active~=nil;diagnostic.overview_cancel.enabled=active~=nil
end

local function sync_travel_destinations(session)
    local destinations=session.travel_destinations
    if not (destinations and destinations.valid) then return end
    local planets=context.planets();local ids={}
    for _,planet in ipairs(planets) do ids[#ids+1]=planet.name end
    local signature=serpent.line(ids)
    if session.travel_signature==signature then return end
    destinations.clear()
    for _,planet in ipairs(planets) do
        local r=row(destinations)
        r.add{type="label",caption=planet.localised_name or planet.name,style="ei_admin_caption"}
        action(r,"go-planet",{operation="travel",self=true,planet=planet.name})
        action(r,"send-planet",{operation="travel",planet=planet.name},true)
    end
    session.travel_signature=signature
end

local function build_page(parent,id,session,player,tick)
    heading(parent,"page-"..id)
    if id=="ecology" then
        context.ecology.build(parent,session,player,tick)
    elseif id=="planets" then
        caption(parent,"planet-policy-note","ei_admin_muted")
        actions(parent,{{"planet_peaceful",{enabled=true}},{"planet_peaceful_off",{operation="planet_peaceful",enabled=false}},
            {"planet_spawning",{enabled=true}},{"planet_spawning_off",{operation="planet_spawning",enabled=false}},
            {"planet_expansion",{enabled=true}},{"planet_expansion_off",{operation="planet_expansion",enabled=false}},
            {"global_expansion",{enabled=true}},{"global_expansion_off",{operation="global_expansion",enabled=false}}})
        field(parent,session,"evolution",0);action(parent,"planet_evolution")
        field(parent,session,"daytime",0.5);action(parent,"planet_daytime")
        actions(parent,{{"planet_freeze",{enabled=true}},{"planet_freeze_off",{operation="planet_freeze",enabled=false}},
            {"clear_enemies",{},true},{"clear-hostile-force",{operation="clear_enemies",explicit_hostile_force=true},true},{"clear_pollution",{},true}})
        caption(parent,"hostile-force-note","ei_admin_muted")
    elseif id=="chunks" then
        caption(parent,"chunks-note","ei_admin_muted");field(parent,session,"chunk_radius",0)
        choice(parent,session,"chunk_mode",{"reveal","generate","both","all_generated"},"reveal")
        action(parent,"chunks",{},true)
        catalog_choice(parent,session,"active_job")
        session.cancel_job_button=action(parent,"cancel_job")
    elseif id=="players" then
        heading(parent,"destinations")
        session.travel_destinations=parent.add{type="flow",direction="vertical"}
        session.travel_signature=nil
        sync_travel_destinations(session)
        actions(parent,{{"teleport-location",{operation="travel",manual=true},true},{"set_spawn",{},true},
            {"cheat",{enabled=true}},{"cheat_off",{operation="cheat",enabled=false}},
            {"invulnerable",{enabled=true}},{"invulnerable_off",{operation="invulnerable",enabled=false}},
            {"god",{enabled=true}},{"god_off",{operation="god",enabled=false}},
            {"restrict",{enabled=true}},{"restrict_off",{operation="restrict",enabled=false}},
            {"restrict-new",{operation="restrict_new",enabled=true}},{"restrict-new-off",{operation="restrict_new",enabled=false}}})
        caption(parent,"restriction-note","ei_admin_muted")
    elseif id=="moderation" then
        field(parent,session,"player_name","");field(parent,session,"reason","")
        choice(parent,session,"minutes",{1,5,15,30,60},5);field(parent,session,"custom_minutes","")
        choice(parent,session,"timer_mode",{"online","elapsed"},"online")
        actions(parent,{{"kick",{},true},{"ban",{},true},{"unban",{},true},{"promote",{},true},{"demote",{},true},{"jail",{},true},{"release",{},true}})
        caption(parent,"jail-note","ei_admin_muted")
    elseif id=="creation" then
        heading(parent,"item-grants");selector(parent,session,"item","item-with-quality",{name="iron-plate",quality="normal"})
        field(parent,session,"item_quantity",1);action(parent,"give_items")
        heading(parent,"entity-placement");selector(parent,session,"place_item","item-with-quality")
        field(parent,session,"entity_quantity",1);choice(parent,session,"direction",{0,2,4,6,8,10,12,14},0)
        action(parent,"place_entities");caption(parent,"placement-note","ei_admin_muted")
    elseif id=="fluids" then
        heading(parent,"fluid-storage");selector(parent,session,"fluid","fluid");field(parent,session,"fluid_amount",1000)
        field(parent,session,"fluidbox_index",0);action(parent,"fill_fluid");caption(parent,"fluid-note","ei_admin_muted")
        heading(parent,"resource-patches");selector(parent,session,"resource","entity").elem_filters={{filter="type",type="resource"}}
        field(parent,session,"resource_amount",1000);choice(parent,session,"resource_radius",{0,2,5,10},0)
        action(parent,"place_resources");caption(parent,"resource-note","ei_admin_muted")
    elseif id=="enemies" then
        choice(parent,session,"enemy_catalog",{"standard","advanced"},"standard")
        field(parent,session,"enemy_search","")
        session.drafts.enemy=session.drafts.enemy or "small-biter"
        catalog_choice(parent,session,"enemy");field(parent,session,"enemy_count",1)
        button(parent,"add-mixture","mixture");button(parent,"clear-mixture","clear-mixture")
        session.mixture_label=caption(parent,"empty-mixture")
        button(parent,"pick-attack","pick",{kind="attack"});button(parent,"clear-attack","clear-attack")
        action(parent,"spawn_enemies",{},true);caption(parent,"enemy-note","ei_admin_muted")
    elseif id=="effects" then
        heading(parent,"fires");choice(parent,session,"fire_family",{"oil","gas","exotic","lava"},"oil")
        choice(parent,session,"pattern",{1,3,5},1);catalog_choice(parent,session,"advanced_fire");action(parent,"start_fire",{},true)
        heading(parent,"ruptures");choice(parent,session,"rupture_family",{"oil","gas","exotic","thermal","lava","chemical","cryo","data"},"oil")
        choice(parent,session,"energy",{20,100,500},100);action(parent,"rupture",{},true)
        caption(parent,"rupture-note","ei_admin_muted")
        heading(parent,"pollution");field(parent,session,"pollution_amount",1000);action(parent,"add_pollution",{},true)
        local presets=row(parent,"buttons")
        for _,amount in ipairs({100,1000,10000}) do action(presets,"pollution-"..amount,{operation="add_pollution",amount=amount},true) end
        caption(parent,"pollution-note","ei_admin_muted")
    elseif id=="research" then
        actions(parent,{{"instant_research",{enabled=true}},{"instant_research_off",{operation="instant_research",enabled=false}},
            {"finish_research"},{"research_all",{},true}})
        caption(parent,"research-note","ei_admin_muted")
        local r
        for i,speed in ipairs({0.1,0.25,0.5,1,2,4,8,10}) do
            if (i-1)%4==0 then r=row(parent,"buttons") end
            r.add{type="button",caption=tostring(speed).."x",tags=tags("execute",{operation="speed",args={speed=speed}})}
        end
        field(parent,session,"speed",1);action(parent,"speed");action(parent,"normal_speed",{operation="speed",speed=1})
    elseif id=="diagnostics" then
        build_diagnostics(parent,session)
    elseif id=="repairs" then
        caption(parent,"repair-note","ei_admin_muted")
        for _,owner in ipairs(context.registry.list()) do
            if owner.repair then
                local r=row(parent);r.add{type="label",caption=owner.id,style="ei_admin_caption"}
                button(r,"repair","execute",{operation="repair",args={module_id=owner.id},confirm=true},true)
            end
        end
        heading(parent,"advanced");action(parent,"gaia-reforge",{},true);action(parent,"victory-reset",{},true)
    elseif id=="cameras" then
        caption(parent,"camera-note","ei_admin_muted")
        choice(parent,session,"camera_mode",{"physical","view"},"physical")
        field(parent,session,"camera_zoom",0.5)
        action(parent,"camera-player");action(parent,"camera-entity");action(parent,"camera-close")
    end
end

function model.refresh(index,tick,snapshot)
    local session=session_for(index);local player=game.get_player(index)
    if not (session and session.root and session.root.valid and session.root.visible and player and player.valid) then return end
    if not common.authorize(player) then model.close(index,true);return end
    sync_targets(session,player)
    local target_summary=summary(session,player)
    local signature=serpent.line(target_summary)
    if session.summary_signature~=signature then session.summary.caption=target_summary;session.summary_signature=signature end
    if session.page=="diagnostics" then refresh_diagnostics(session,player,tick) end
    if session.page=="ecology" then context.ecology.refresh(session,player,tick) end
    if session.page=="players" then sync_travel_destinations(session) end
    if session.page=="enemies" and session.mixture_label and session.mixture_label.valid then
        sync_catalog(session,"enemy",session.drafts.enemy_catalog=="advanced" and "advanced_enemies" or "enemies",session.drafts.enemy_search)
        local parts={};for _,entry in ipairs(session.enemy_mix or {}) do parts[#parts+1]=entry.name.." x "..entry.count end
        local mixture=#parts>0 and table.concat(parts,", ") or label("empty-mixture")
        local mixture_signature=serpent.line(mixture)
        if session.mixture_signature~=mixture_signature then
            session.mixture_label.caption=mixture;session.mixture_signature=mixture_signature
        end
    elseif session.page=="effects" then
        sync_catalog(session,"advanced_fire","fires",nil,true)
    end
    refresh_availability(session,player)
    model.refresh_live(index,tick,snapshot)
    resize_window(player,session)
end

function model.refresh_live(index,tick,snapshot)
    local root=common.peek();local session=root and root.sessions[index]
    if not (session and session.root and session.root.valid and session.root.visible and session.readout and session.readout.valid) then
        if root and root.ui_watch then root.ui_watch[index]=nil end
        return
    end
    local actor=game.get_player(index)
    if not common.authorize(actor) then model.close(index,true);return end
    local surface=session.surface_index and game.get_surface(session.surface_index)
        or (game.planets[session.drafts.planet or ""] and game.planets[session.drafts.planet].surface)
    local text="";local watch=false
    if session.page=="planets" and surface then
        local p=context.world.get_policy(surface)
        text={"ei-admin.planet-readout",surface.peaceful_mode and "On" or "Off",surface.no_enemies_mode and "Off" or "On",
            p.expansion==false and "Off" or "On",game.map_settings.enemy_expansion.enabled and "On" or "Off",
            string.format("%.1f",game.forces.enemy.get_evolution_factor(surface)*100),surface.pollutant_type and surface.pollutant_type.name or "None"}
    elseif session.page=="players" or session.page=="moderation" then
        local target=game.get_player(tonumber(session.drafts.player_index) or index)
        local jail=target and root.jails[target.index]
        local seconds=0
        if jail then
            local remaining=jail.deadline and jail.deadline-tick or jail.remaining_ticks-(jail.online_since and tick-jail.online_since or 0)
            seconds=math.max(0,math.ceil(remaining/60));watch=true
        end
        text={"ei-admin.player-readout",target and target.cheat_mode and "On" or "Off",
            target and target.character and target.character.valid and not target.character.destructible and "On" or "Off",
            target and target.controller_type==defines.controllers.god and "On" or "Off",
            target and root.restrictions[target.index] and "On" or "Off",jail and tostring(seconds).." s ("..jail.timer_mode..")" or "Off"}
    elseif session.page=="chunks" then
        local pos=session.position or actor.physical_position
        local radius=math.floor(tonumber(session.drafts.chunk_radius) or 0)
        local area=session.area
        local x1=area and math.floor(area.left_top.x/32) or math.floor(pos.x/32)-radius
        local y1=area and math.floor(area.left_top.y/32) or math.floor(pos.y/32)-radius
        local x2=area and math.ceil(area.right_bottom.x/32)-1 or math.floor(pos.x/32)+radius
        local y2=area and math.ceil(area.right_bottom.y/32)-1 or math.floor(pos.y/32)+radius
        text={"ei-admin.chunk-readout",x1,y1,x2,y2,math.max(0,x2-x1+1)*math.max(0,y2-y1+1)}
        if session.drafts.chunk_mode=="all_generated" then text={"ei-admin.chunk-all-readout"} end
    elseif session.page=="effects" then
        local radius=context.world.peek_rupture_radius(tonumber(session.drafts.energy) or 100)
        text={"",{"ei-admin.pollutant-readout",surface and surface.pollutant_type and surface.pollutant_type.name or "None"},"\n",
            {"ei-admin.rupture-radius",radius and string.format("%.1f",radius) or "?"}}
    elseif session.page=="fluids" then
        local prototype=prototypes.entity[session.drafts.resource or ""]
        local amount=common.number(session.drafts.resource_amount,1,1000000000)
        if not prototype or prototype.type~="resource" then text=label("resource-select-readout")
        elseif not amount or amount~=math.floor(amount) then text=label("resource-invalid-readout")
        elseif prototype.infinite_resource then
            local normal=prototype.normal_resource_amount or 0
            text={"ei-admin.resource-infinite-readout",prototype.localised_name,amount,normal,
                normal>0 and string.format("%.4g",100*amount/normal) or "?",prototype.minimum_resource_amount or 0}
        else text={"ei-admin.resource-finite-readout",prototype.localised_name,amount} end
    end
    local job
    if ({chunks=true,creation=true,fluids=true,enemies=true,effects=true,planets=true})[session.page] then
        snapshot=snapshot or context.world.peek_summary()
        local own,ids,items,selected={},{},{},nil
        for _,candidate in ipairs(snapshot.jobs) do
            if candidate.actor_index==index then
                own[#own+1]=candidate;ids[#ids+1]=candidate.id
                local target=candidate.surface_index and game.get_surface(candidate.surface_index)
                items[#items+1]={"ei-admin.active-job-entry",candidate.id,candidate.kind,target and target.name or "?",actor.name}
                if candidate.id==session.drafts.active_job then selected=#ids end
                if candidate.id==session.last_job then job=candidate end
            end
        end
        watch=watch or #own>0
        if session.page=="chunks" then
            local element=session.fields.active_job
            selected=selected or (#ids>0 and 1 or 0)
            if element and element.valid then
                local signature=serpent.line({ids,items})
                if session.active_jobs_signature~=signature then element.items=items;session.active_jobs_signature=signature end
                session.choices.active_job=ids;session.drafts.active_job=ids[selected]
                if element.selected_index~=selected then element.selected_index=selected end
            end
            if session.cancel_job_button and session.cancel_job_button.valid and session.cancel_job_button.enabled~=(#own>0) then
                session.cancel_job_button.enabled=#own>0
            end
            job=own[selected]
        end
        if #own>0 then text={"",text,"\n",{"ei-admin.active-job-count",#own}} end
        if job then text={"",text,"\n",{"ei-admin.job-readout",job.id,job.kind,job.completed,job.failed,job.waiting or "Working"}} end
    end
    local signature=serpent.line(text)
    if session.readout_signature~=signature then session.readout.caption=text;session.readout_signature=signature end
    root.ui_watch=root.ui_watch or {};root.ui_watch[index]=watch and true or nil
    if watch then root.ui_due_tick=math.min(root.ui_due_tick or tick+30,tick+30) end
end

function model.refresh_visible(tick)
    local root=common.peek();if not root then return end
    local snapshot=context.world.peek_summary()
    root.ui_due_tick=nil
    for index in pairs(root.ui_watch or {}) do model.refresh_live(index,tick,snapshot) end
end

function model.open(player,page,tick)
    if not common.authorize(player) then return end
    local state=common.state();local session=state.sessions[player.index]
    if not session then session={drafts={},fields={},choices={},pages={},enemy_mix={}};state.sessions[player.index]=session end
    local valid_page=false
    for _,entry in ipairs(config.pages) do if entry.id==page then valid_page=true end end
    if not valid_page then page=session.page or "planets" end
    -- An older saved console lacks the optional timer controls. This is a real
    -- structural change; close preserves its location/drafts before rebuilding.
    if session.root and session.root.valid and not (session.auto_refresh_button and session.auto_refresh_button.valid and session.nav and session.nav.ecology and session.nav.ecology.valid) then
        model.close(player.index,true)
    end
    if not (session.root and session.root.valid) then
        session.fields={};session.choices={};session.pages={};session.nav={};session.diagnostics=nil;session.ecology=nil
        session.target_signatures={};session.summary_signature=nil;session.readout_signature=nil
        session.catalog_signatures={};session.availability={};session.layout_signature=nil
        session.active_jobs_signature=nil
        session.mixture_signature=nil;session.auto_refresh_display=nil
        local old=player.gui.screen[GUI];if old then old.destroy() end
        local root=player.gui.screen.add{type="frame",name=GUI,direction="vertical",tags=tags("root")};session.root=root
        root.style.padding=8
        local title=row(root);session.title=title;session.title_caption=title.add{type="label",caption=label("title"),style="frame_title"}
        local spacer=title.add{type="empty-widget",style="ei_titlebar_draggable_spacer"};spacer.drag_target=root
        button(title,"close","close")
        local toolbar=root.add{type="flow",direction="vertical"};session.toolbar=toolbar
        local tools=row(toolbar,"buttons");button(tools,"show-launcher","launcher");button(tools,"refresh","refresh");button(tools,"cancel-target","cancel-target")
        local automatic=row(toolbar,"buttons")
        session.auto_refresh_button=button(automatic,"auto-refresh-off","auto-refresh")
        choice(automatic,session,"auto_refresh_interval",{1,2,5,10,30,60},5)
        sync_auto_refresh_button(session)
        local body=row(root);session.body=body;body.style.horizontal_spacing=8
        local nav=body.add{type="scroll-pane",direction="vertical"};session.navigation=nav
        nav.horizontal_scroll_policy="never";nav.vertical_scroll_policy="auto-and-reserve-space"
        local last
        for _,entry in ipairs(config.pages) do
            if last~=entry.group then heading(nav,"group-"..entry.group);last=entry.group end
            local b=nav.add{type="button",caption=label("page-"..entry.id),tooltip=label("page-"..entry.id),style="ei_admin_nav",tags=tags("page",{page=entry.id})};session.nav[entry.id]=b
        end
        local right=body.add{type="flow",direction="vertical"};session.right=right;right.style.vertical_spacing=4;targets(right,session,player)
        session.content=right.add{type="flow",direction="vertical"}
        session.feedback=right.add{type="scroll-pane",direction="vertical"};session.feedback.visible=false
        session.feedback.horizontal_scroll_policy="never";session.feedback.vertical_scroll_policy="auto-and-reserve-space"
        session.status=session.feedback.add{type="label",caption="",style="ei_admin_caption"}
        local confirm=session.feedback.add{type="frame",direction="vertical",style="inside_shallow_frame"};confirm.style.padding=6;confirm.visible=false;session.confirm_frame=confirm
        session.confirm_caption=confirm.add{type="label",caption="",style="ei_admin_caption"}
        local buttons=row(confirm);button(buttons,"confirm","confirm",nil,true);button(buttons,"cancel","cancel-confirm")
        if session.location then root.location=session.location else session.center_pending=true end
    end
    session.root.visible=true;session.page=page
    if not session.pages[page] then
        local pane=session.content.add{type="scroll-pane",direction="vertical"}
        pane.horizontal_scroll_policy="never";pane.vertical_scroll_policy="auto-and-reserve-space"
        session.pages[page]=pane;build_page(pane,page,session,player,tick)
        index_availability(session,pane)
    end
    for id,pane in pairs(session.pages) do pane.visible=id==page end
    for id,b in pairs(session.nav) do b.toggled=id==page end
    resize_window(player,session,true)
    player.opened=session.root
    model.refresh(player.index,tick)
    if not session.auto_due_tick then schedule_auto_refresh(player.index,session,tick) end
end

function model.close(index,destroy)
    local session=session_for(index);if not session then return end
    cancel_auto_refresh(index,session)
    if destroy then session.auto_refresh=false end
    if session.root and session.root.valid then
        session.location=session.root.location
        if destroy then session.root.destroy();session.root=nil;session.pages={} else session.root.visible=false end
    end
    session.confirm=nil
    local root=common.peek();if root and root.ui_watch then root.ui_watch[index]=nil;if not next(root.ui_watch) then root.ui_due_tick=nil end end
    if session.confirm_frame and session.confirm_frame.valid then session.confirm_frame.visible=false end
    local player=game.get_player(index)
    if player and player.opened==session.root then player.opened=nil end
end

function model.launcher(player)
    local session=session_for(player.index)
    local existing=session and session.launcher_element
    if existing and not existing.valid then existing=nil;session.launcher_element=nil end
    local enabled=common.authorize(player) and session and session.launcher
    if not enabled then
        if not existing and session and session.launcher then
            -- Read an existing native flow for defensive cleanup; the getter creates
            -- containers and must never run while the launcher/toolkit is disabled.
            local top=player.gui.top;local frame=top.mod_gui_top_frame
            local flow=top.mod_gui_button_flow or (frame and frame.mod_gui_inner_frame)
            existing=flow and flow[config.launcher]
        end
        if existing and existing.valid then existing.destroy() end
        if session then session.launcher_element=nil end
        return
    end
    if not existing then
        local flow=mod_gui.get_button_flow(player)
        session.launcher_element=flow[config.launcher] or flow.add{type="sprite-button",name=config.launcher,
            sprite="utility/brush_circle_shape",tooltip=label("title"),style=mod_gui.button_style,tags=tags("open")}
    end
end

local function arguments(session,player,extra)
    local d=session.drafts
    local args={player_index=tonumber(d.player_index),force_index=tonumber(d.force_index),planet=d.planet,
        position=session.position,area=session.area,entity=session.entity,attack_position=session.attack_position,
        item=d.item,place_item=d.place_item,direction=tonumber(d.direction),fluid=d.fluid,
        fluidbox_index=tonumber(d.fluidbox_index)~=0 and tonumber(d.fluidbox_index) or nil,resource=d.resource,enemy_mix=table.deepcopy(session.enemy_mix),
        advanced=d.enemy_catalog=="advanced",
        fire_family=d.fire_family,pattern=tonumber(d.pattern),advanced_fire=d.advanced_fire~="" and d.advanced_fire or nil,
        rupture_family=d.rupture_family,energy=tonumber(d.energy),mode=d.chunk_mode,
        reason=d.reason,player_name=d.player_name,minutes=tonumber(d.custom_minutes) or tonumber(d.minutes),timer_mode=d.timer_mode,
        speed=tonumber(d.speed),evolution=tonumber(d.evolution),daytime=tonumber(d.daytime)}
    for k,v in pairs(extra or {}) do args[k]=v end
    if session.surface_index and not (extra and extra.planet) then args.surface_index=session.surface_index end
    if args.self then args.player_index=player.index end
    return args
end

function model.on_gui_change(event)
    local element=event.element
    if not (element and element.valid and element.tags.parent_gui==GUI) then return false end
    local player=game.get_player(event.player_index);if not common.authorize(player) then return true end
    local session=session_for(player.index);if not session then return true end
    if context.ecology.on_gui_change(event,session) then model.refresh(player.index,event.tick);return true end
    local id=element.tags.field;if not id then return true end
    if element.type=="textfield" then session.drafts[id]=element.text
    elseif element.type=="choose-elem-button" then session.drafts[id]=element.elem_value
    elseif element.type=="drop-down" then session.drafts[id]=session.choices[id][element.selected_index] end
    if id=="auto_refresh_interval" then schedule_auto_refresh(player.index,session,event.tick)
    elseif element.tags.action=="target" then
        if id=="planet" then session.surface_index=nil;session.position=nil;session.area=nil;session.entity=nil;session.attack_position=nil end
        model.refresh(player.index,event.tick)
    elseif id=="chunk_radius" or id=="chunk_mode" or id=="energy" or id=="active_job"
        or id=="resource" or id=="resource_amount" then model.refresh_live(player.index,event.tick)
    elseif id=="enemy_catalog" or id=="enemy_search" then
        sync_catalog(session,"enemy",session.drafts.enemy_catalog=="advanced" and "advanced_enemies" or "enemies",session.drafts.enemy_search)
    end
    resize_window(player,session)
    return true
end

function model.on_gui_click(event)
    local element=event.element
    if not (element and element.valid and element.tags.parent_gui==GUI) then return false end
    local player=game.get_player(event.player_index)
    if not common.authorize(player) then model.close(event.player_index,true);return true end
    local t=element.tags;local session=session_for(player.index)
    if t.action=="open" then model.open(player,nil,event.tick);return true end
    if not session then return true end
    if context.ecology.on_gui_click(event,session) then model.refresh(player.index,event.tick);return true end
    if t.action=="close" then model.close(player.index)
    elseif t.action=="page" then model.open(player,t.page,event.tick)
    elseif t.action=="refresh" then model.refresh(player.index,event.tick)
    elseif t.action=="auto-refresh" then
        session.auto_refresh=not session.auto_refresh;sync_auto_refresh_button(session)
        schedule_auto_refresh(player.index,session,event.tick)
    elseif t.action=="launcher" then session.launcher=not session.launcher;model.launcher(player)
    elseif t.action=="cancel-target" then context.cancel_target(player,event.tick)
    elseif t.action=="pick" then context.begin_target(player,t.kind,session,event.tick)
    elseif t.action=="coordinates" then
        local x,y=common.number(session.drafts.x,-999999,999999),common.number(session.drafts.y,-999999,999999)
        if x and y then session.position={x=x,y=y};session.area=nil;session.entity=nil;session.surface_index=nil;model.refresh(player.index,event.tick) end
    elseif t.action=="mixture" then
        local count=common.number(session.drafts.enemy_count,1,1000)
        if count and count==math.floor(count) and session.drafts.enemy and #session.enemy_mix<32 then
            session.enemy_mix[#session.enemy_mix+1]={name=session.drafts.enemy,count=count}
        else model.result(player.index,label("invalid-mixture"),event.tick) end
        model.refresh(player.index,event.tick)
    elseif t.action=="clear-mixture" then session.enemy_mix={};model.refresh(player.index,event.tick)
    elseif t.action=="clear-attack" then session.attack_position=nil
    elseif t.action=="inspect" then session.module_id=t.module_id;model.refresh(player.index,event.tick)
    elseif t.action=="diagnostic-overview" then session.module_id=nil;model.refresh(player.index,event.tick)
    elseif t.action=="deep-inspect" then context.inspect(player,session.module_id,event.tick);model.refresh(player.index,event.tick)
    elseif t.action=="cancel-inspection" then context.cancel_inspection(player,event.tick);model.refresh(player.index,event.tick)
    elseif t.action=="export" then context.export(player,session.module_id,event.tick)
    elseif t.action=="cancel-confirm" then session.confirm=nil;session.confirm_frame.visible=false
    elseif t.action=="confirm" then
        local pending=session.confirm;session.confirm=nil;session.confirm_frame.visible=false
        if pending then context.execute(player,pending.action,pending.args,event.tick) end
    elseif t.action=="execute" then
        local args=arguments(session,player,t.args);local operation=args.operation or t.operation;args.operation=nil
        local d=session.drafts
        if operation=="give_items" then args.quantity=tonumber(d.item_quantity)
        elseif operation=="place_entities" then args.quantity=tonumber(d.entity_quantity)
        elseif operation=="fill_fluid" then args.amount=tonumber(d.fluid_amount)
        elseif operation=="place_resources" then args.amount=tonumber(d.resource_amount);args.radius=tonumber(d.resource_radius)
        elseif operation=="add_pollution" then args.amount=args.amount or tonumber(d.pollution_amount)
        elseif operation=="cancel_job" then
            args.job_id=tonumber(d.active_job)
            if not args.job_id then model.result(player.index,label("no-active-jobs"),event.tick);return true end
        elseif operation=="chunks" then args.radius=tonumber(d.chunk_radius)
        elseif operation=="camera-player" or operation=="camera-entity" then args.zoom=tonumber(d.camera_zoom);args.follow_view=d.camera_mode=="view" end
        if operation=="travel" and not args.manual then args.position=nil;args.surface_index=nil end
        if operation=="spawn_enemies" and #args.enemy_mix==0 then args.enemy_mix={{name=d.enemy,count=tonumber(d.enemy_count)}} end
        if operation=="spawn_enemies" or (operation=="clear_enemies" and not args.explicit_hostile_force) then args.force_index=game.forces.enemy.index end
        if t.confirm then
            session.confirm={action=operation,args=args}
            session.confirm_caption.caption={"ei-admin.confirm-target",label(t.operation),summary(session,player,args,operation)}
            session.confirm_frame.visible=true
        else context.execute(player,operation,args,event.tick) end
    end
    resize_window(player,session)
    return true
end

function model.result(index,message,tick)
    local session=session_for(index)
    if session and session.status and session.status.valid then session.status.caption=message end
    model.refresh(index,tick)
end

function model.on_gui_closed(event)
    if event.element and event.element.valid and event.element.name==GUI then model.close(event.player_index) end
end

function model.progress(index,message)
    local session=session_for(index)
    if session and session.root and session.root.valid and session.root.visible and session.status and session.status.valid then
        local signature=serpent.line(message)
        if session.progress_signature~=signature then
            session.status.caption=message;session.progress_signature=signature
            local player=game.get_player(index);if player then resize_window(player,session) end
        end
    end
end
return model

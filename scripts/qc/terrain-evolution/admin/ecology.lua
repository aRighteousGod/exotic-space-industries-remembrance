-- Real GUI objects, shipping control handlers, actual owner validation and state.
-- The isolated map may be changed; no fixtures or monkey patches are shipped.
local model={}
local saved,observed
local function recorder()
    local checks={}
    return checks,function(name,ok,detail)
        checks[#checks+1]={name=name,ok=not not ok,detail=detail}
    end
end
local function session(ctx,player) return ctx.common.peek().sessions[player.index] end
local function dispatch(name,player,element,tick)
    local handler=assert(script.get_event_handler(defines.events[name]),"Shipping GUI handler is missing")
    return handler{name=defines.events[name],player_index=player.index,element=element,tick=tick,
        button=defines.mouse_button_type.left}
end
local function select(ctx,player,key,tick)
    local current=session(ctx,player);local position=0
    for _,field in ipairs(ctx.config.schema) do
        if field.surface then
            position=position+1
            if field.key==key then
                current.ecology.setting.selected_index=position
                dispatch("on_gui_selection_state_changed",player,current.ecology.setting,tick)
                assert(current.drafts.ecology_key==key)
                return current.ecology.value
            end
        end
    end
    error("Missing ecology field: "..key)
end
local function set_value(ctx,player,key,value,tick)
    local element=select(ctx,player,key,tick)
    if element.type=="drop-down" then
        local values=session(ctx,player).ecology.values
        for i,v in ipairs(values) do if v==value then element.selected_index=i end end
        dispatch("on_gui_selection_state_changed",player,element,tick)
    else
        element.text=tostring(value);dispatch("on_gui_text_changed",player,element,tick)
    end
end
local function click(ctx,player,key,tick)
    dispatch("on_gui_click",player,session(ctx,player).ecology[key],tick)
end
local function target(ctx,player,surface,tick)
    session(ctx,player).surface_index=surface.index
    ctx.gui.refresh(player.index,tick)
end
local function global_setting(ctx,key,value,tick)
    local name=ctx.config.by_key[key].setting_name
    settings.global[name]={value=value}
    -- Dispatch explicitly so this check does not assume when Factorio delivers a
    -- script-written setting event. The shipping handler is idempotent.
    script.get_event_handler(defines.events.on_runtime_mod_setting_changed){
        name=defines.events.on_runtime_mod_setting_changed,setting=name,setting_type="runtime-global",tick=tick}
end
local function same(a,b) return serpent.line(a)==serpent.line(b) end
local function restore_overrides(ctx,surface,values,tick)
    ctx.terrain.reset_overrides(surface,tick)
    -- Apply together when retaining a non-default pollution threshold pair.
    local low=values.pollution_low;local high=values.pollution_high
    if high~=nil then ctx.terrain.set_override(surface,"pollution_low",0,tick);ctx.terrain.set_override(surface,"pollution_high",high,tick) end
    for key,value in pairs(values) do if key~="pollution_high" and key~="pollution_low" then ctx.terrain.set_override(surface,key,value,tick) end end
    ctx.terrain.set_override(surface,"pollution_low",low,tick)
end
function model.start(ctx,player,tick)
    local checks,check=recorder()
    check("real player is connected",player and player.valid and player.connected)
    check("administrator toolkit is enabled",ctx.common.enabled())
    local nauvis=assert(game.surfaces.nauvis)
    local vulcanus=game.planets.vulcanus.surface or game.planets.vulcanus.create_surface()
    local fulgora=game.planets.fulgora.surface or game.planets.fulgora.create_surface()
    local unsupported=game.get_surface("ei-terrain-admin-qc-unsupported") or game.create_surface("ei-terrain-admin-qc-unsupported")
    ctx.terrain.initialize(tick)
    saved={admin=player.admin,soil=settings.global[ctx.config.by_key.soil_seconds.setting_name].value,
        nauvis=nauvis,other=vulcanus,overrides=ctx.terrain.get_overrides(nauvis),other_overrides=ctx.terrain.get_overrides(vulcanus)}
    ctx.terrain.reset_overrides(nauvis,tick);ctx.terrain.reset_overrides(vulcanus,tick)
    ctx.gui.close(player.index,true)
    player.admin=false
    local before=ctx.terrain.get_overrides(nauvis)
    local denied=ctx.admin.execute(player,"ecology_override",{surface_index=nauvis.index,key="degradation",value=false},tick)
    check("nonadministrator action cannot mutate ecology",not denied and same(before,ctx.terrain.get_overrides(nauvis)))
    ctx.admin.open(player,"ecology",tick)
    local existing=ctx.common.peek() and ctx.common.peek().sessions[player.index]
    check("nonadministrator cannot open ecology console",not existing or not (existing.root and existing.root.valid))
    player.admin=true;ctx.admin.open(player,"ecology",tick);target(ctx,player,nauvis,tick)
    local s=session(ctx,player);local frame=s.root
    check("real ecology page builds",frame.valid and s.page=="ecology" and s.ecology.value.valid)
    check("page defaults to no automatic refresh",not s.auto_refresh and not s.auto_due_tick)
    local character=player.character;local cheat=player.cheat_mode;local controller=player.controller_type
    set_value(ctx,player,"degradation",false,tick)
    check("native dropdown preserves false as a draft",s.ecology_drafts[nauvis.index..":degradation"]==false)
    click(ctx,player,"apply",tick)
    check("administrator applies a false surface override",ctx.terrain.get_overrides(nauvis).degradation==false
        and ctx.terrain.resolve_config(nauvis).degradation==false)
    check("surface override is isolated",ctx.terrain.get_overrides(vulcanus).degradation==nil
        and ctx.terrain.resolve_config(vulcanus).degradation==settings.global[ctx.config.by_key.degradation.setting_name].value)
    check("effective readout identifies override",s.ecology.effective.caption[3][1]=="ei-admin.ecology-overridden")
    click(ctx,player,"inherit",tick)
    check("inherit removes the override",ctx.terrain.get_overrides(nauvis).degradation==nil
        and s.ecology.effective.caption[3][1]=="ei-admin.ecology-inherited")
    global_setting(ctx,"soil_seconds",120,tick);ctx.gui.refresh(player.index,tick)
    set_value(ctx,player,"soil_seconds",150,tick);click(ctx,player,"apply",tick)
    global_setting(ctx,"soil_seconds",240,tick);ctx.gui.refresh(player.index,tick)
    check("global changes preserve explicit surface override",ctx.terrain.resolve_config(nauvis).soil_seconds==150)
    check("unmodified surface inherits changed global value",ctx.terrain.resolve_config(vulcanus).soil_seconds==240)
    click(ctx,player,"inherit",tick)
    check("inherit refreshes effective value and native editor",ctx.terrain.resolve_config(nauvis).soil_seconds==240
        and tonumber(s.ecology.value.text)==240 and tonumber(s.ecology.effective.caption[2])==240)
    set_value(ctx,player,"soil_seconds",321,tick)
    local editor=s.ecology.value
    ctx.gui.refresh(player.index,tick)
    check("ordinary refresh retains root input and unapplied draft",s.root==frame and s.ecology.value==editor
        and s.ecology.value.text=="321" and s.ecology_drafts[nauvis.index..":soil_seconds"]=="321")
    check("unapplied draft cannot change effective value",ctx.terrain.resolve_config(nauvis).soil_seconds==240)
    set_value(ctx,player,"soil_seconds","invalid",tick);click(ctx,player,"apply",tick)
    check("invalid number is rejected by actual GUI path",ctx.terrain.get_overrides(nauvis).soil_seconds==nil)
    set_value(ctx,player,"soil_seconds",0,tick);click(ctx,player,"apply",tick)
    check("out of range number is rejected by owner",ctx.terrain.get_overrides(nauvis).soil_seconds==nil)
    set_value(ctx,player,"soil_seconds",300,tick);click(ctx,player,"apply",tick)
    set_value(ctx,player,"degradation",false,tick);click(ctx,player,"apply",tick)
    click(ctx,player,"reset",tick)
    check("reset clears all surface overrides",next(ctx.terrain.get_overrides(nauvis))==nil)
    check("reset replaces stale drafts with effective default",s.ecology_drafts[nauvis.index..":degradation"]
        ==ctx.terrain.resolve_config(nauvis).degradation)
    target(ctx,player,unsupported,tick)
    check("unsupported surface disables mutation controls",not s.ecology.apply.enabled and not s.ecology.inherit.enabled
        and not s.ecology.reset.enabled and not s.ecology.set_phase.enabled)
    target(ctx,player,fulgora,tick)
    check("Fulgora phase edit is unavailable",not s.ecology.set_phase.enabled and ctx.terrain.snapshot(fulgora,tick).calendar.status=="excluded")
    local fulgora_day=fulgora.daytime_parameters
    local phase_ok=ctx.admin.execute(player,"ecology_phase",{surface_index=fulgora.index,phase=0.25},tick)
    check("Fulgora owner rejects phase mutation without changing lighting",not phase_ok and same(fulgora_day,fulgora.daytime_parameters))
    target(ctx,player,nauvis,tick)
    s.ecology.phase.text="0.25";click(ctx,player,"set_phase",tick)
    check("administrator phase edit reaches calendar owner",math.abs(ctx.terrain.snapshot(nauvis,tick).phase-0.25)<1e-9)
    check("ecology status uses translated nested status",type(s.ecology.status.caption[3])=="table")
    check("calendar status uses translated nested status",type(s.ecology.calendar.caption[2])=="table")
    set_value(ctx,player,"degradation",false,tick)
    local pending_before=ctx.terrain.get_overrides(nauvis)
    player.admin=false;click(ctx,player,"apply",tick)
    check("revoked administrator click cannot mutate owner",same(pending_before,ctx.terrain.get_overrides(nauvis)))
    check("revoked administrator click destroys console",not s.root)
    player.admin=true;ctx.admin.open(player,"ecology",tick);target(ctx,player,nauvis,tick)
    check("ecology controls preserve player modes",player.character==character and player.cheat_mode==cheat and player.controller_type==controller)
    local page=player.gui.screen.add{type="flow",direction="vertical"}
    local content_ok,content_error=pcall(remote.call,"exotic-industries-informatron","informatron_page_content",
        {page_name="terrain_evolution",player_index=player.index,element=page})
    check("connected Informatron ecology callback builds",content_ok,content_ok and nil or tostring(content_error))
    if content_ok then
        local readout=page.children[#page.children].caption
        local effective=ctx.terrain.snapshot(player.surface,tick).effective
        check("Informatron effective status and presets are localized",type(readout[2])=="table"
            and (effective and type(readout[3])=="table" and type(readout[4])=="table"
                or not effective and readout[3]=="-" and readout[4]=="-"))
    end
    page.destroy()
    return checks
end
function model.idle_begin(ctx,player,tick)
    local root=ctx.common.peek();local s=session(ctx,player)
    if root.dirty and next(root.dirty) then return false,{} end
    local checks,check=recorder()
    check("ecology display registers no periodic watch",not root.ui_watch or not root.ui_watch[player.index])
    check("ecology display has no automatic refresh deadline",not s.auto_due_tick and not s.auto_refresh)
    observed={refresh=0,snapshot=0,frame=s.root,value=s.ecology.value,tick=tick}
    observed.original_refresh=ctx.ecology.refresh;observed.original_snapshot=ctx.terrain.snapshot
    ctx.ecology.refresh=function(...)observed.refresh=observed.refresh+1;return observed.original_refresh(...)end
    ctx.terrain.snapshot=function(...)observed.snapshot=observed.snapshot+1;return observed.original_snapshot(...)end
    return true,checks
end
function model.finish(ctx,player,tick)
    local checks,check=recorder();local s=session(ctx,player)
    check("idle observation covers 180 simulation ticks",tick-observed.tick>=180,tick-observed.tick)
    check("idle ecology page performs zero refreshes",observed.refresh==0,observed.refresh)
    check("idle ecology page performs zero owner snapshots",observed.snapshot==0,observed.snapshot)
    check("idle preserves real root and editor identity",s.root==observed.frame and s.ecology.value==observed.value)
    model.cleanup(ctx,player,tick)
    return checks
end
function model.cleanup(ctx,player,tick)
    if observed then ctx.ecology.refresh=observed.original_refresh;ctx.terrain.snapshot=observed.original_snapshot;observed=nil end
    if not saved then return end
    global_setting(ctx,"soil_seconds",saved.soil,tick)
    restore_overrides(ctx,saved.nauvis,saved.overrides,tick)
    restore_overrides(ctx,saved.other,saved.other_overrides,tick)
    ctx.gui.close(player.index,true);player.admin=saved.admin;saved=nil
end
return model

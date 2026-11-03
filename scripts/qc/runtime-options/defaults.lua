-- Native default contract, actual ecology GUI and independently paced scanner.
-- Modules are supplied by ESIR so this helper never accesses another mod's storage.
local model={}
local state
local scanner="ei-factory-passage-circuit-scanner-enabled"
local function session(ctx,player) return ctx.storage.ei.admin_tools.sessions[player.index] end
local function select(ctx,player,key,tick)
    local s=session(ctx,player);local index=0
    for _,row in ipairs(ctx.config.schema) do
        if row.surface then
            index=index+1
            if row.key==key then
                s.ecology.setting.selected_index=index
                ctx.admin.on_gui_change{player_index=player.index,element=s.ecology.setting,tick=tick}
                return s.ecology.value
            end
        end
    end
    error("Missing ecology editor "..key)
end

---@param check function
---@param ctx table Actual ESIR owners, schema, native player and ESIR storage.
---@param player LuaPlayer
---@param tick MapTick
---@return boolean
function model.candidate(check,ctx,player,tick)
    if not state then
        check("ecology-startup-default-on",prototypes.mod_setting["ei-terrain-evolution-enabled"].default_value==true
            and settings.startup["ei-terrain-evolution-enabled"].value==true)
        local resolved=ctx.config.resolve()
        local fields={};for _,f in ipairs(ctx.options.snapshot().fields) do fields[f.id]=f end
        local definitions={};for _,d in ipairs(ctx.config.definitions) do definitions[d.name]=d end
        player.admin=true;ctx.admin.open(player,"options",tick)
        local s=session(ctx,player)
        for _,row in ipairs(ctx.config.schema) do
            local native=prototypes.mod_setting[row.setting_name]
            check("ecology-default-chain-"..row.key,definitions[row.setting_name].default_value==row.default
                and native.default_value==row.default and fields[row.setting_name].default==row.default
                and settings.global[row.setting_name].value==row.default and resolved[row.key]==row.default)
            if row.type=="boolean" then
                check("ecology-default-on-"..row.key,row.default==true and s.options.rows[row.setting_name].value.state==true)
            end
        end
        check("ecology-presets-contract",resolved.wildfire=="contained" and resolved.intensity=="restrained" and resolved.performance=="lean")
        check("native-scanner-default-off",prototypes.mod_setting[scanner].default_value==false
            and settings.global[scanner].value==false and not s.options.rows[scanner].value.state)
        check("passage-default-budgets",settings.global["ei-factory-passage-update-budget"].value==256
            and settings.global["ei-factory-passage-circuit-scan-budget"].value==1)
        for index in pairs(s.options.group_ids) do
            s.options.category.selected_index=index
            ctx.admin.on_gui_change{player_index=player.index,element=s.options.category,tick=tick}
        end
        check("default-options-navigation-has-no-edits",next(s.options_draft.changes)==nil)
        ctx.admin.open(player,"ecology",tick);s=session(ctx,player);s.surface_index=game.surfaces.nauvis.index
        for _,row in ipairs(ctx.config.schema) do
            if row.surface then
                local editor=select(ctx,player,row.key,tick)
                local actual
                if editor.type=="drop-down" then actual=s.ecology.values[editor.selected_index] else actual=tonumber(editor.text) end
                check("default-ecology-editor-"..row.key,actual==ctx.terrain.resolve_config(game.surfaces.nauvis)[row.key])
            end
        end
        check("default-ecology-navigation-has-no-edits",next(s.ecology_drafts)==nil)
        for _,row in ipairs(ctx.ecology_fixture.start(ctx,player,tick)) do check("ecology-admin-"..row.name,row.ok,row.detail) end
        ctx.ecology_fixture.cleanup(ctx,player,tick)
        local surface=game.create_surface("esir-defaults-scanner",{width=64,height=64,water="none",
            autoplace_settings={entity={treat_missing_as_default=false},decorative={treat_missing_as_default=false}}})
        surface.request_to_generate_chunks({0,0},1);surface.force_generate_chunk_requests()
        local tiles={};for x=-8,8 do for y=-8,8 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
        surface.set_tiles(tiles)
        local machine=assert(surface.create_entity{name="esir-options-qc-crafter",position={0.5,0.5},force=player.force,raise_built=true})
        machine.set_recipe("esir-options-qc-water")
        machine.get_or_create_control_behavior().circuit_set_recipe=true
        local pipe=assert(surface.create_entity{name="pipe",position={-0.5,-1.5},force=player.force,raise_built=true})
        ctx.passage.refresh_entity(machine,tick,true)
        state={phase="settle",tick=tick,machine=machine,pipe=pipe,surface=surface,
            player_surface=player.surface,player_position=player.position}
        return false
    end
    if state.phase=="cleanup" then return game.get_surface(state.surface_index)==nil end
    if tick-state.tick<120 then return false end
    local status=ctx.passage.status()
    local s=ctx.storage.ei.factory_passage
    if state.phase=="settle" then
        check("scanner-default-off-has-candidate",status.circuit_candidates>0 and not status.circuit_scanner_active)
        state.attempts=status.counters.circuit_attempts or 0
        state.created=status.counters.created or 0;state.heap=s.circuit_deadlines
        state.phase="parked";state.tick=tick;return false
    elseif state.phase=="parked" then
        check("scanner-default-off-no-background-attempts",(status.counters.circuit_attempts or 0)==state.attempts)
        check("scanner-default-off-retains-state",s.circuit_deadlines==state.heap and (status.counters.created or 0)==state.created)
        player.teleport({4,4},state.surface)
        player.opened=state.machine
        ctx.passage.on_gui_opened{player_index=player.index,tick=tick}
        state.phase="gui";state.tick=tick;return false
    elseif state.phase=="gui" then
        check("scanner-off-gui-observation-active",status.gui_watchers>0 or s.gui_watch_count>0)
        check("scanner-off-gui-not-background-scan",(status.counters.circuit_attempts or 0)==state.attempts)
        player.opened=nil;ctx.passage.on_gui_closed{player_index=player.index,tick=tick}
        ctx.passage.refresh_entity(state.machine,tick,true)
        state.processed=status.counters.processed or 0
        state.phase="event";state.tick=tick;return false
    elseif state.phase=="event" then
        check("scanner-off-explicit-refresh-processed",(status.counters.processed or 0)>state.processed)
        check("scanner-off-event-not-background-scan",(status.counters.circuit_attempts or 0)==state.attempts)
        state.heap=s.circuit_deadlines;state.dirty=s.dirty;state.pending=s.pending
        settings.global[scanner]={value=true}
        check("scanner-enable-preserves-queues",s.circuit_deadlines==state.heap and s.dirty==state.dirty and s.pending==state.pending)
        state.phase="enabled";state.tick=tick;return false
    end
    check("scanner-explicit-enable-scans",(status.counters.circuit_attempts or 0)>state.attempts)
    settings.global[scanner]={value=false}
    check("scanner-disable-preserves-queues",s.circuit_deadlines==state.heap and s.dirty==state.dirty and s.pending==state.pending)
    player.teleport(state.player_position,state.player_surface)
    state.machine.destroy{raise_destroy=true}
    state.pipe.destroy{raise_destroy=true}
    state.surface_index=state.surface.index
    game.delete_surface(state.surface)
    state.phase="cleanup"
    return false
end

function model.checkpoint(check,ctx,player,tick,profile)
    local surface=game.surfaces.nauvis
    settings.global["ei-terrain-degradation"]={value=false}
    settings.global[scanner]={value=profile=="default"}
    assert(ctx.terrain.set_override(surface,"recovery",false,tick))
    ctx.admin.open(player,"ecology",tick)
    local s=session(ctx,player);s.surface_index=surface.index
    select(ctx,player,"tree_regrowth",tick)
    s.ecology_drafts[surface.index..":tree_regrowth"]=false
    s.ecology.editor_key=nil;ctx.gui.refresh(player.index,tick)
    ctx.storage.esir_defaults_saved={surface=surface.index,player=player.index,scanner=settings.global[scanner].value}
    check("saved-ecology-false-draft",s.ecology.value.selected_index==1)
end

function model.reload(check,ctx,tick)
    local saved=assert(ctx.storage.esir_defaults_saved)
    local surface=game.get_surface(saved.surface)
    check("saved-scanner-choice-preserved",settings.global[scanner].value==saved.scanner)
    check("saved-ecology-global-off-preserved",settings.global["ei-terrain-degradation"].value==false
        and ctx.terrain.resolve_config(surface).degradation==false)
    check("saved-ecology-surface-off-preserved",ctx.terrain.get_overrides(surface).recovery==false
        and ctx.terrain.resolve_config(surface).recovery==false)
    local s=ctx.storage.ei.admin_tools.sessions[saved.player]
    check("saved-ecology-pending-false-preserved",s.ecology_drafts[surface.index..":tree_regrowth"]==false)
end
return model

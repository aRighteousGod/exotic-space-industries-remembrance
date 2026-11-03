-- QC-only actual-owner bridge, appended inside the private ESIR control scope.
-- Native GUI callbacks are programmatic; this is not rendered/multiplayer evidence.
local support = require("__esir-qc-native-tests__.support")
local expected_conversions = require("__esir-qc-native-tests__.options-expected")
local options = require("scripts/control/runtime-options")
local catalog = require("lib/runtime-options-config")
local admin = require("scripts/control/admin-tools")
local admin_gui = require("scripts/control/admin/gui")
local admin_common = require("scripts/control/admin/common")
local water = require("scripts/control/water-turret")
local wake = require("scripts/control/gaian-saucer-wake")
local hover = require("scripts/control/emerald-apocalypse-hover-tank")
local tesla = require("scripts/control/teslas-legacy")
local campfire = require("scripts/control/camp-fire")
local steam = require("scripts/control/steam-train")
local flame = require("scripts/control/flamethrower-fuels")
local rupture = require("scripts/control/flammable-rupture-scheduler")
local fluid_config = require("lib/fluid-safety-config")
local fluid = require("scripts/control/fluid-safety")
local fluid_fixture = require("__esir-qc-native-tests__.options-fluid")
local icon_sets = require("lib/alert-icon-sets")
local defaults_fixture=require("__esir-qc-native-tests__.options-defaults")
local defaults_context={admin=admin,gui=admin_gui,common=admin_common,options=options,
    config=require("lib/terrain-evolution-config"),terrain=require("scripts/control/terrain-evolution"),
    ecology=require("scripts/control/admin/ecology"),passage=require("scripts/control/factory-passage"),
    ecology_fixture=require("__esir-qc-native-tests__.options-ecology")}
local checks, result = {}, nil
local phase = support.phase()

---@param name string
---@param passed boolean
---@param detail any?
---@return boolean
local function check(name, passed, detail)
    checks[#checks+1] = {name=name, passed=not not passed, detail=detail and tostring(detail) or nil}
    return not not passed
end

local function count(values)
    local total=0;for _ in pairs(values) do total=total+1 end;return total
end
local function equal(left,right)
    if count(left)~=count(right) then return false end
    for id,value in pairs(left) do if right[id]~=value then return false end end
    return true
end
local function reset_probe()
    local probe=storage.esir_native_options_probe or {}
    storage.esir_native_options_probe=probe
    probe.observe=true;probe.reconciliations=0;probe.native_events=0
    probe.last_changes=nil;probe.last_values=nil;probe.last_tick=nil
    probe.fail_after_write=nil;probe.write_attempts=0
    return probe
end

-- Observe the native setter's synchronous event without synthesizing an event.
local previous_settings=assert(script.get_event_handler(defines.events.on_runtime_mod_setting_changed))
script.on_event(defines.events.on_runtime_mod_setting_changed,function(event)
    local probe=storage.esir_native_options_probe
    if probe and probe.observe and event.setting_type=="runtime-global" and catalog.by_id[event.setting] then
        probe.native_events=probe.native_events+1
    end
    return previous_settings(event)
end)

local function apply(changes,tick,label,baseline)
    local ok,message,readback=options.apply(baseline or options.snapshot().values,changes,tick)
    check(label,ok,not ok and serpent.line(message) or nil)
    if ok then
        for id,value in pairs(changes) do
            check(label.."-native-"..id,settings.global[id].value==value)
            if readback[id]~=nil then check(label.."-readback-"..id,readback[id]==settings.global[id].value) end
        end
    end
    return ok,readback
end

local function alternate(field,current)
    if field.type=="boolean" then return not current end
    if field.values and #field.values>0 then
        for _,value in ipairs(field.values) do if value~=current then return value end end
    elseif field.type=="string" then return current=="" and "pipe; esir-qc-unknown-entity" or ""
    elseif current~=field.min then return field.min
    else return field.max end
    error("No alternate value for "..field.id)
end

local function cache_check(legacy,value)
    local key=legacy:gsub("^ei%-","")
    local direct={em_train_glow="em_train_glow",em_train_glow_timetolive="em_train_glow_timeToLive",
        em_charger_glow="em_charger_glow",em_charger_glow_timetolive="em_charger_glow_timeToLive",
        em_updater_que_width="que_width",em_updater_que_timetolive="que_timetolive"}
    if direct[key] then check("actual-cache-"..legacy,storage.ei[direct[key]]==value)
    elseif key=="em_updater_que_transparency" then check("actual-cache-"..legacy,storage.ei.que_transparency==value/100)
    elseif key=="em_updater_que" then check("actual-cache-"..legacy,storage.ei.em_train_que==({Off=0,Beam=1,Ring=2})[value])
    elseif key=="admin-tools-enabled" then check("actual-cache-"..legacy,admin_common.enabled()==value)
    elseif key=="tech-scaling-curveForm" then check("actual-cache-"..legacy,storage.ei.tech_scaling.curveForm==value)
    elseif key=="rocket-launch-pollution-mode" then check("actual-cache-"..legacy,storage.ei.rocket_launch_pollution.mode==value)
    elseif key=="rocket-launch-pollution-cap" then check("actual-cache-"..legacy,storage.ei.rocket_launch_pollution.cap==value)
    elseif key=="rocket-launch-pollution-visual-style" then check("actual-cache-"..legacy,storage.ei.rocket_launch_pollution.visual_style==value)
    elseif key=="flammable-rupture-fidelity" then check("actual-cache-"..legacy,rupture.get_fidelity_profile(32).mode==value)
    elseif key=="fulgora-day-length-variation-min-multiplier" then check("actual-cache-"..legacy,storage.ei.fulgora_day_length_variation.min_multiplier==value)
    elseif key=="fulgora-day-length-variation-max-multiplier" then check("actual-cache-"..legacy,storage.ei.fulgora_day_length_variation.max_multiplier==value)
    elseif key=="max_updates_per_tick" then
        check("actual-cache-"..legacy,ei_maxEntityUpdates==value and flame.esir_native_option_cache()==value)
        check("actual-updater-rate",math.abs(ei_updater_per_entity_calls_per_second-ei_maxEntityUpdates*ei_updater_calls_per_second)<1e-9)
    elseif key=="ticks_per_full_update" then
        check("actual-cache-"..legacy,ei_ticksPerFullUpdate==value)
        check("actual-campfire-interval",campfire.esir_native_option_cache()==math.max(150,value))
        check("actual-steam-wheel-interval",steam.esir_native_option_cache()==math.floor(math.max(1,math.min(5,value/30))))
        check("actual-updater-frequency",math.abs(ei_updater_calls_per_second-60/(value/ei_update_functions_length))<1e-9)
    elseif key=="gaian-saucer-wake-visual-fidelity" then check("actual-cache-"..legacy,wake.esir_native_option_cache()==value)
    elseif key=="emerald-apocalypse-hover-tank-hover-visual-fidelity" then check("actual-cache-"..legacy,hover.esir_native_option_cache()==value)
    elseif key=="water-turret-fire-targeting" then check("actual-cache-"..legacy,water.esir_native_option_cache()==(value=="nearest"))
    elseif key=="nauvis-pressure-grace" then
        local enabled=value and settings.startup["ei-enemy-difficulty"].value~="Impossible"
        check("actual-cache-"..legacy,storage.ei.nauvis_pressure.enabled==enabled)
    elseif key=="nauvis-pressure-grace-profile" then check("actual-cache-"..legacy,storage.ei.nauvis_pressure.profile==value)
    elseif legacy:find("^tl%-flying%-text%-") then
        check("actual-cache-"..legacy,tesla.esir_native_option_cache()[legacy:gsub("^tl%-flying%-text%-","")]==value)
    elseif key=="fluid-safety-ignored-entities" then
        local ignored=fluid_config.parse_ignored_entities(value)
        check("actual-cache-"..legacy,fluid_config.is_ignored_entity("pipe")==not not ignored.pipe)
    else check("actual-runtime-reader-"..legacy,catalog.get(legacy)==value) end
end

local function catalog_checks()
    local snapshot=options.snapshot()
    check("catalog-exact-runtime-count",#snapshot.fields==113 and count(snapshot.values)==113)
    local native_count,seen,converted=0,{},0
    local kinds={["bool-setting"]="boolean",["int-setting"]="integer",["double-setting"]="number",["string-setting"]="string"}
    for name,prototype in pairs(prototypes.mod_setting) do
        if prototype.mod=="exotic-space-industries-remembrance" and prototype.setting_type=="runtime-global" then
            native_count=native_count+1;check("native-global-catalogued-"..name,catalog.by_id[name]~=nil)
        end
    end
    check("native-global-exact-count",native_count==113)
    for _,field in ipairs(snapshot.fields) do
        local prototype=prototypes.mod_setting[field.id]
        check("native-scope-"..field.id,prototype.setting_type=="runtime-global" and not seen[field.id])
        local kind=kinds[prototype.type]
        if kind=="string" and prototype.allowed_values and #prototype.allowed_values>0 then kind="enum" end
        check("native-type-"..field.id,field.type==kind)
        check("native-value-"..field.id,snapshot.values[field.id]==settings.global[field.id].value)
        check("native-metadata-"..field.id,field.default==prototype.default_value
            and field.min==prototype.minimum_value and field.max==prototype.maximum_value)
        if field.legacy then converted=converted+1 end
        seen[field.id]=true
    end
    check("catalog-exact-converted-count",converted==29 and #expected_conversions==29)
    for _,legacy in ipairs(expected_conversions) do
        local id=catalog.runtime_name(legacy)
        check("converted-identity-"..legacy,id==legacy.."-runtime" and seen[id])
        check("legacy-readable-"..legacy,settings.startup[legacy]~=nil and prototypes.mod_setting[legacy].setting_type=="startup")
    end
    check("dead-fueler-not-exposed",not seen.ei_fueler_max_updates_per_tick)
    check("mixed-lance-not-converted",not seen["ei-singularity-lance-visual-fidelity"] and not catalog.by_legacy["ei-singularity-lance-visual-fidelity"])
    return snapshot
end

local function invalid_checks(tick)
    local integer=catalog.runtime_name("ei-max_updates_per_tick")
    local number=catalog.runtime_name("ei-fulgora-day-length-variation-max-multiplier")
    local boolean=catalog.runtime_name("ei-em_train_glow")
    local enum=catalog.runtime_name("ei-water-turret-fire-targeting")
    local free=catalog.runtime_name("ei-fluid-safety-ignored-entities")
    local scenarios={
        {"boolean-string",{[boolean]="false"}}, {"integer-fraction",{[integer]=1.5}},
        {"integer-lower-bound",{[integer]=0}}, {"integer-upper-bound",{[integer]=101}},
        {"double-lower-bound",{[number]=1.49}}, {"double-upper-bound",{[number]=3.01}},
        {"double-nan",{[number]=0/0}}, {"double-infinity",{[number]=math.huge}},
        {"enum-unknown",{[enum]="not-a-target-mode"}}, {"string-wrong-type",{[free]=true}},
        {"unknown-field",{["esir-qc-unknown-option"]=true}},
        {"startup-field",{["ei-enemy-difficulty"]="Merciful"}},
        {"personal-field",{["ei-gate-notifications"]=false}},
        {"pollution-order",{["ei-terrain-pollution-low"]=100,["ei-terrain-pollution-high"]=100}},
    }
    for _,scenario in ipairs(scenarios) do
        local before=options.snapshot().values;local probe=reset_probe()
        scenario[2]["ei-admin-new-planets-peaceful"]=not before["ei-admin-new-planets-peaceful"]
        local ok=options.apply(before,scenario[2],tick)
        check("reject-"..scenario[1],not ok)
        check("reject-no-partial-write-"..scenario[1],equal(before,options.snapshot().values))
        check("reject-no-side-effect-"..scenario[1],probe.reconciliations==0 and probe.native_events==0)
    end
    local before=options.snapshot().values
    apply({[free]=""},tick,"free-string-blank")
    apply({[free]="pipe, storage-tank; esir-qc-uninstalled-name"},tick,"free-string-unknown-names-allowed")
    apply({[free]=before[free]},tick,"free-string-restore")
    apply({[boolean]=false,[number]=2.25,[integer]=7},tick,"typed-valid-values")
    check("boolean-false-survives-snapshot",options.snapshot().values[boolean]==false)
    apply({[boolean]=before[boolean],[number]=before[number],[integer]=before[integer]},tick,"typed-values-restore")
end

local function transaction_checks(tick)
    local a="ei-admin-new-planets-peaceful"
    local b="ei-admin-restrict-new-players"
    local original=options.snapshot().values
    local probe=reset_probe()
    local changes={[a]=not original[a],[b]=not original[b]}
    apply(changes,tick,"atomic-two-native-writes")
    check("native-events-synchronous",probe.native_events==2)
    check("batch-one-owner-reconciliation",probe.reconciliations==1 and probe.last_tick==tick)
    check("batch-sees-complete-values",probe.last_values[a]==changes[a] and probe.last_values[b]==changes[b])
    apply({[a]=original[a],[b]=original[b]},tick,"atomic-restore")
    probe=reset_probe();probe.fail_after_write=2
    local ok,message=options.apply(options.snapshot().values,changes,tick)
    check("injected-write-failure-rejected",not ok and message[1]=="ei-runtime-options.failed")
    check("injected-failure-after-two-real-writes",probe.write_attempts==2 and probe.fail_after_write==nil)
    check("rollback-restores-native-values",equal(original,options.snapshot().values))
    check("rollback-suppresses-owner-side-effects",probe.reconciliations==0 and probe.native_events>=4)
    probe=reset_probe()
    options.begin_batch()
    apply({[a]=changes[a]},tick,"nested-first")
    apply({[b]=changes[b]},tick,"nested-second")
    check("nested-no-early-side-effects",probe.reconciliations==0)
    options.end_batch(tick,true)
    check("nested-single-union-reconciliation",probe.reconciliations==1 and probe.last_changes[a] and probe.last_changes[b])
    apply({[a]=original[a],[b]=original[b]},tick,"nested-restore")
    probe=reset_probe()
    settings.global[a]={value=not original[a]}
    check("native-menu-event-path",probe.native_events==1 and probe.reconciliations==1)
    check("native-menu-readback",options.snapshot().values[a]==not original[a])
    apply({[a]=original[a]},tick,"native-menu-restore")
    probe=reset_probe()
    local untouched=options.snapshot().values
    options.apply(untouched,{[a]=untouched[a]},tick)
    check("no-op-avoids-native-event-and-refresh",probe.native_events==0 and probe.reconciliations==0)

    -- Two independent administrator drafts; one actual native player is tested below.
    local first,second=options.snapshot().values,options.snapshot().values
    apply({[a]=not first[a]},tick,"first-administrator-draft",first)
    local conflict=options.apply(second,{[a]=second[a]},tick)
    check("second-administrator-same-field-conflicts",not conflict and settings.global[a].value~=second[a])
    apply({[b]=not second[b]},tick,"second-administrator-unrelated-edit",second)
    apply({[a]=original[a],[b]=original[b]},tick,"draft-isolation-restore")
end

local function conversion_checks(tick)
    local fields={};for _,field in ipairs(options.snapshot().fields) do fields[field.id]=field end
    for _,legacy in ipairs(expected_conversions) do
        local id=catalog.runtime_name(legacy)
        local before=settings.global[id].value
        local value=alternate(fields[id],before)
        local probe=reset_probe()
        if apply({[id]=value},tick,"converted-live-"..legacy) then
            check("converted-native-event-"..legacy,probe.native_events==1)
            check("converted-one-refresh-"..legacy,probe.reconciliations==1)
            cache_check(legacy,value)
        end
        apply({[id]=before},tick,"converted-restore-"..legacy)
        cache_check(legacy,before)
    end
end

local function migration_checks(tick)
    local original=options.snapshot().values
    local state=storage.ei.runtime_options
    check("fresh-migration-marker",state and state.migration_version==1)
    state.migration_version=nil
    local probe=reset_probe()
    check("fresh-does-not-import",options.migrate(tick,true)==false)
    check("fresh-preserves-native-map-inputs",equal(original,options.snapshot().values) and probe.reconciliations==0)
    state.migration_version=nil
    check("controlled-legacy-marker-import",options.migrate(tick,false)==true)
    local imported=options.snapshot().values
    local distinct=0
    for _,legacy in ipairs(expected_conversions) do
        local id=catalog.runtime_name(legacy);local value=settings.startup[legacy].value
        check("controlled-legacy-value-"..legacy,imported[id]==value)
        if value~=original[id] then distinct=distinct+1 end
    end
    if support.config.profile=="legacy-values" then check("all-legacy-values-nondefault",distinct==29) end
    check("migration-defers-owner-refresh",probe.reconciliations==0)
    check("migration-preserves-unconverted-runtime",imported["ei-terrain-active"]==original["ei-terrain-active"]
        and imported["ei-factory-passage-update-budget"]==original["ei-factory-passage-update-budget"])
    apply(original,tick,"migration-test-restore")
    local enabled=catalog.runtime_name("ei-em_train_glow")
    apply({[enabled]=not settings.startup["ei-em_train_glow"].value},tick,"post-migration-explicit-edit")
    local before=options.snapshot().values
    check("migration-idempotent",options.migrate(tick,false)==false and equal(before,options.snapshot().values))
end

local function click(player,element,tick)
    admin.on_gui_click{player_index=player.index,element=element,button=defines.mouse_button_type.left,tick=tick}
end
local function edit(player,session,id,value,tick)
    local row=assert(session.options.rows[id],"Missing Options row: "..id)
    if row.field.type=="boolean" then row.value.state=value
    elseif row.field.type=="enum" then
        for index,candidate in ipairs(row.field.values) do if candidate==value then row.value.selected_index=index end end
    else row.value.text=tostring(value) end
    admin.on_gui_change{player_index=player.index,element=row.value,tick=tick}
end

local function gui_checks(player,tick)
    local enabled=catalog.runtime_name("ei-admin-tools-enabled")
    local id=catalog.runtime_name("ei-em_train_glow")
    local budget=catalog.runtime_name("ei-max_updates_per_tick")
    local initial=options.snapshot().values
    apply({[enabled]=true},tick,"gui-enable")
    player.admin=true
    admin.open(player,"options",tick)
    local session=assert(storage.ei.admin_tools.sessions[player.index])
    check("native-options-row-count",session.options and count(session.options.rows)==113)
    edit(player,session,id,false,tick);click(player,session.options.apply,tick)
    check("native-gui-false-applied",settings.global[id].value==false and session.options.rows[id].value.state==false)
    check("native-gui-readback-baseline",session.options_draft.baseline[id]==false and next(session.options_draft.changes)==nil)
    settings.global[id]={value=true};admin_gui.refresh(player.index,tick)
    check("untouched-gui-follows-native-change",session.options.rows[id].value.state==true)
    edit(player,session,budget,7,tick)
    local before_handles=session.options.rows[budget].value
    session.options.category.selected_index=2
    admin.on_gui_change{player_index=player.index,element=session.options.category,tick=tick}
    check("group-switch-preserves-draft",session.options_draft.changes[budget]==7)
    session.options.category.selected_index=1
    admin.on_gui_change{player_index=player.index,element=session.options.category,tick=tick}
    check("group-switch-retains-controls",session.options.rows[budget].value==before_handles)
    settings.global[budget]={value=8};click(player,session.options.apply,tick)
    check("gui-stale-draft-conflicts",settings.global[budget].value==8 and session.options_draft.changes[budget]==7)
    click(player,session.options.reload,tick)
    check("gui-reload-discards-conflict",session.options_draft.baseline[budget]==8 and next(session.options_draft.changes)==nil)
    edit(player,session,budget,"bad",tick);click(player,session.options.apply,tick)
    check("gui-invalid-text-no-native-write",settings.global[budget].value==8)
    click(player,session.options.discard,tick)
    check("gui-discard-restores-value",session.options.rows[budget].value.text=="8" and next(session.options_draft.changes)==nil)
    edit(player,session,budget,9,tick)
    player.admin=false
    local allowed=admin.execute(player,"options_apply",{baseline=session.options_draft.baseline,changes=session.options_draft.changes},tick)
    check("revoked-admin-cannot-apply",not allowed and settings.global[budget].value==8)
    player.admin=true
    admin.open(player,"options",tick)
    session=storage.ei.admin_tools.sessions[player.index]
    click(player,session.options.reload,tick)
    edit(player,session,enabled,false,tick);click(player,session.options.apply,tick)
    check("admin-off-native-value",settings.global[enabled].value==false and not admin_common.enabled())
    local after=storage.ei.admin_tools.sessions[player.index]
    check("admin-off-closes-native-window",not after or not after.root or not after.root.valid or not after.root.visible)
    local baseline=options.snapshot().values
    allowed=admin.execute(player,"options_apply",{baseline=baseline,changes={[id]=false}},tick)
    check("disabled-toolkit-cannot-apply",not allowed)
    settings.global[enabled]={value=true}
    check("native-setting-reenables-admin",admin_common.enabled())
    apply(initial,tick,"gui-test-restore")
    local personal=player.mod_settings[icon_sets.setting_name].value
    player.mod_settings[icon_sets.setting_name]={value="original"}
    local default_id=catalog.runtime_name("ei-alert-icon-set-default")
    local default=settings.global[default_id].value
    apply({[default_id]="svg"},tick,"default-alert-set-change")
    check("map-default-preserves-personal-selection",player.mod_settings[icon_sets.setting_name].value=="original"
        and icon_sets.player_set(player)=="original")
    apply({[default_id]=default},tick,"default-alert-set-restore")
    player.mod_settings[icon_sets.setting_name]={value=personal}
end

local candidate_started=false
local defaults_ready=false
local function run_candidate(player,tick)
    defaults_context.storage=storage
    if not defaults_ready then
        defaults_ready=defaults_fixture.candidate(check,defaults_context,player,tick)
        if not defaults_ready then return false end
    end
    if not candidate_started then
    local original=catalog_checks().values
    for _,field in ipairs(options.snapshot().fields) do
        if field.legacy then check("fresh-native-default-"..field.id,original[field.id]==field.default) end
    end
    invalid_checks(tick)
    transaction_checks(tick)
    conversion_checks(tick)
    migration_checks(tick)
    gui_checks(player,tick)
    candidate_started=true
    end
    if not fluid_fixture.candidate(check,apply,options,catalog,fluid,tick,storage) then return false end
    defaults_fixture.checkpoint(check,defaults_context,player,tick,support.config.profile)
    storage.esir_native_options_saved={marker="runtime-options-native-v1",values=options.snapshot().values,
        migration_version=storage.ei.runtime_options.migration_version,player_index=player.index}
    check("saved-acceptance-nonempty",count(storage.esir_native_options_saved.values)==113)
    return true
end

local function run_reload(tick)
    local saved=assert(storage.esir_native_options_saved,"Missing runtime-options checkpoint")
    check("persisted-acceptance-marker",saved.marker=="runtime-options-native-v1")
    check("persisted-all-native-values",equal(saved.values,options.snapshot().values))
    check("persisted-migration-version",storage.ei.runtime_options.migration_version==saved.migration_version)
    check("reload-migration-does-not-overwrite",not options.migrate(tick,false) and equal(saved.values,options.snapshot().values))
    for _,legacy in ipairs(expected_conversions) do cache_check(legacy,saved.values[catalog.runtime_name(legacy)]) end
    fluid_fixture.reload(check,fluid,tick,phase,storage)
    defaults_context.storage=storage
    defaults_fixture.reload(check,defaults_context,tick)
end

remote.add_interface("esir-native-tests",{step=function(tick)
    if result then return result end
    local player=game.connected_players[1]
    if phase=="candidate" and not player then return {complete=false} end
    local complete=true
    local ok,failure=pcall(function()
        if phase=="candidate" then complete=run_candidate(player,tick) else run_reload(tick) end
    end)
    if ok and not complete then return {complete=false} end
    if not ok then check("fixture-exception",false,failure) end
    if storage.esir_native_options_probe then storage.esir_native_options_probe.observe=false end
    result={complete=true,checks=checks}
    return result
end})

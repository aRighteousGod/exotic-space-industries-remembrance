--==============================================================================
-- ESIR FILE MAP
-- owns: explicit runtime-owner coverage, pure admin summaries and bounded inspections
-- loaded_by: scripts/control/admin-tools.lua
-- cadence: user actions; 64 inspected records per active inspection tick, no idle work
-- forwarded_events: configure, list, get, peek, inspect, start_inspection, cancel_inspection, get_inspection, has_tick_work, updater, repair, coverage
-- storage_roots: storage.ei.admin_tools.inspection, storage.ei.admin_tools.inspection_results
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: none; module owners repair their own authoritative state
--==============================================================================
-- blueprint: .codex/esir/blueprints/admin-runtime-registry.md#contract
local lib=require("lib/lib")
local model={}
local context
local INSPECTION_BUDGET=64
local MAX_INSPECTION_RECORDS=1000000
local DEFINITIONS={
    {id="auric-inoculation-vat",label="Auric inoculation vats",blueprint="auric-inoculation-vat",root="ei.auric_inoculation_vat",repair="rebuild_runtime_state",call="repair",fields={"version","next_due_tick","next_ui_due_tick","ready_queue_count"},collections={"vats_by_unit","claims_by_tile","due_tick_by_unit","open_by_player"},sources={"exotic-space-industries-remembrance/scripts/control/auric-inoculation-vat.lua"}},
    {id="beacon-overload",label="Beacon overload",blueprint="beacon-overload",root="ei.beacon_overload",repair="refresh_all_overloads",call="reason",fields={"mode","tracked_count","registered_beacon_count","registered_machine_count","relationship_count","overloaded_count"},collections={"machines","beacons"},sources={"exotic-space-industries-remembrance/scripts/control/beacon-overload.lua","exotic-space-industries-remembrance/lib/beacon-profile-config.lua"}},
    {id="black-hole",label="Black holes",blueprint="black-hole",root="ei.black_hole",repair="rebuild_runtime_state",call="repair",fields={},collections={},sources={"exotic-space-industries-remembrance/scripts/control/black-hole.lua"}},
    {id="camp-fire",label="Campfires",blueprint="camp-fire",root="ei.campfire",repair="repair_runtime_state",call="repair",fields={},collections={},sources={"exotic-space-industries-remembrance/scripts/control/camp-fire.lua"}},
    {id="combustion-turbine",label="Combustion turbines",blueprint="combustion-turbine",root="ei.combustion_turbine",repair="rebuild_runtime_state",call="repair",fields={"version"},collections={"turbines_by_unit","open_by_player"},sources={"exotic-space-industries-remembrance/scripts/control/combustion-turbine.lua"}},
    {id="crystal-accumulator",scheduler_id="crystal_accumulator",label="Crystal accumulators",blueprint="crystal-accumulator",root="ei.crystal_accumulator",repair="repair_runtime_state",call="repair",fields={"live_crystal_count","active_surface_count","next_surface_due_tick","due_surface_count"},collections={"by_unit","surface_due_tick_by_surface","units_by_surface"},sources={"exotic-space-industries-remembrance/scripts/control/crystal-accumulator.lua"}},
    {id="em-trains",label="EM trains and chargers",blueprint="em-trains",root="ei_emt",repair="repair_runtime_state",call="repair",fields={"runtime_version","needs_runtime_rebuild","charger_rail_audit_cursor"},collections={"chargers","trains","charger_surface_queues","train_surface_queues"},sources={"exotic-space-industries-remembrance/scripts/control/em-trains/charger.lua","exotic-space-industries-remembrance/scripts/control/em-trains/gui.lua","exotic-space-industries-remembrance/scripts/control/em-trains/informatron.lua"}},
    {id="emerald-apocalypse",scheduler_id="emerald-apocalypse-hover-tank",label="Emerald Apocalypse",blueprint="emerald-apocalypse",root="ei.emerald_apocalypse_hover_tank",repair="repair_runtime_state",call="repair",fields={"version","next_charge_due_tick","next_pulse_cleanup_tick"},collections={"tanks_by_unit","charge_queue.items","charge_buckets","pending_by_unit","shield_pulses","registrations","tank_settings_by_unit"},sources={"exotic-space-industries-remembrance/scripts/control/emerald-apocalypse-hover-tank.lua","exotic-space-industries-remembrance/scripts/control/emerald-apocalypse-orbital-shards.lua","exotic-space-industries-remembrance/lib/emerald-apocalypse-hover-tank-config.lua","exotic-space-industries-remembrance/lib/emerald-apocalypse-hover-tank-hover-offsets.lua"}},
    {id="flamethrower-fuels",label="Flamethrower fuels",blueprint="flamethrower-fuel-adaptation",root="ei.flamethrower_fuels",repair="repair_runtime_state",call="repair",fields={"count"},collections={"records","units","retries","registrations"},sources={"exotic-space-industries-remembrance/scripts/control/flamethrower-fuels.lua","exotic-space-industries-remembrance/lib/flamethrower-fuels.lua"}},
    {id="fluid-safety",label="Fluid safety",blueprint="fluid-safety-and-ruptures",root="ei.fluid_runtime",repair="rebuild_fluid_runtime",call="reason",fields={"tracked_count","urgent_count","dirty_count","initialized","service_mode_cursor"},collections={"entries_by_unit","segments","scan_units"},sources={"exotic-space-industries-remembrance/scripts/control/fluid-safety.lua","exotic-space-industries-remembrance/scripts/control/flammable-fluids.lua","exotic-space-industries-remembrance/lib/fluid-safety-config.lua"}},
    {id="flammable-ruptures",label="Staged fluid ruptures",blueprint="fluid-safety-and-ruptures",root="ei.flammable_ruptures",repair="repair_runtime_state",call="repair",fields={"active_job_count","pending_ring_count","scheduled_ring_count","scheduled_bucket_count","next_ring_due_tick"},collections={"jobs","ring_buckets"},sources={"exotic-space-industries-remembrance/scripts/control/flammable-rupture-scheduler.lua","exotic-space-industries-remembrance/scripts/control/fluid-rupture-effects.lua"}},
    {id="fueler",label="Fueler towers",blueprint="fueler",root="ei.fueler_rt",repair="rebuild_runtime_state",call="repair",fields={"runtime_version","target_count","ready_target_count","last_housekeeping_tick","needs_rebuild"},collections={"towers","targets","player_states"},sources={"exotic-space-industries-remembrance/scripts/control/fueler/fueler.lua","exotic-space-industries-remembrance/scripts/control/fueler/informatron.lua"}},
    {id="fulgora-day-length",label="Fulgora day length",blueprint="fulgora-day-length",root="ei.fulgora_day_length_variation",repair="repair_runtime_state",call="repair",fields={"cycle_index","last_applied_cycle","next_check_tick","pending_since_tick","min_multiplier","max_multiplier"},collections={},sources={"exotic-space-industries-remembrance/scripts/control/fulgora-day-length-variation.lua"}},
    {id="fusion-reactor",label="Fusion reactors",blueprint="fusion-reactor",root="ei.fusion_reactor",repair="repair_runtime_state",call="repair",fields={"version","update_cursor"},collections={"reactors_by_unit","open_by_player"},sources={"exotic-space-industries-remembrance/scripts/control/fusion-reactor.lua"}},
    {id="gaia",label="Gaia world runtime",blueprint="gaia-and-alien-systems",root="ei",repair="repair_runtime_state",call="repair",fields={"damage_tick_next_due_tick"},collections={"damage_tick_buckets"},sources={"exotic-space-industries-remembrance/scripts/control/gaia.lua","exotic-space-industries-remembrance/scripts/control/gaia-mapgen-data.lua","exotic-space-industries-remembrance/migrations/1.3.03.lua","exotic-space-industries-remembrance/migrations/1.3.39.lua"}},
    {id="alien-spawner",label="Gaia alien generation",blueprint="gaia-and-alien-systems",root="ei",repair="repair_runtime_state",call="repair",fields={"spawner_next_due_tick","flower_counter"},collections={"spawner_buckets","legendary_spawns"},sources={"exotic-space-industries-remembrance/scripts/control/alien-spawner.lua","exotic-space-industries-remembrance/lib/spawner-presets.lua","exotic-space-industries-remembrance/prototypes/planet-gaia/biomes.lua"}},
    {id="alien-system",label="Alien progression",blueprint="gaia-and-alien-systems",root="ei.alien",repair="repair_runtime_state",call="repair",fields={},collections={},sources={"exotic-space-industries-remembrance/scripts/control/alien-system.lua"}},
    {id="gaian-saucer-wake",label="Gaian saucer wakes",blueprint="gaian-saucer-wake",root="ei.gaian_saucer_wake",repair="rebuild_runtime_state",call="repair",fields={"tracked_count","last_fidelity","last_rebuild_tick"},collections={"tracked","active_queue.items"},sources={"exotic-space-industries-remembrance/scripts/control/gaian-saucer-wake.lua","exotic-space-industries-remembrance/lib/gaian-saucer-wake-config.lua"}},
    {id="gate",label="Gates and receivers",blueprint="gate",root="ei.gate",repair="rebuild_runtime_state",call="event",fields={"gate_count","last_housekeeping_tick","receiver_registry_dirty"},collections={"gate","receiver"},sources={"exotic-space-industries-remembrance/scripts/control/gate.lua"}},
    {id="hemocrystal-wall",label="Hemocrystal walls",blueprint="hemocrystal-wall",root="ei.hemocrystal_wall",repair="repair_runtime_state",call="repair",fields={"version","next_due_tick"},collections={"records_by_key","due_buckets"},sources={"exotic-space-industries-remembrance/scripts/control/hemocrystal-wall.lua"}},
    {id="water-turret",label="Water turrets and firefighting",blueprint="firefighting-and-water-turret",root="ei.water_turret",repair="repair_runtime_state",call="repair",fields={"count"},collections={"records","power_due","fire_due","fire_queue.items"},sources={"exotic-space-industries-remembrance/scripts/control/firefighting.lua","exotic-space-industries-remembrance/scripts/control/water-turret.lua","exotic-space-industries-remembrance/lib/firefighting-config.lua"}},
    {id="induction-matrix",label="Induction matrices",blueprint="induction-matrix",root="ei.induction_matrix",repair="rebuild_runtime_state",call="repair",fields={"wire_slots_rebuild_needed"},collections={"core","dirty_core_queue.items","render_buckets"},sources={"exotic-space-industries-remembrance/scripts/control/induction-matrix.lua"}},
    {id="matter-stabilizer",label="Matter stabilizers",blueprint="matter-stabilizer",root="ei.matter_runtime",repair="rebuild_runtime_state",call="repair",fields={"version","machine_count","stabilizer_count"},collections={"machines","stabilizers"},sources={"exotic-space-industries-remembrance/scripts/control/matter-stabilizer.lua"}},
    {id="nauvis-pressure-grace",label="Nauvis pressure grace",blueprint="nauvis-pressure-grace",root="ei.nauvis_pressure",repair="repair_runtime_state",call="repair",fields={"schema_version","enabled","phase","milestone","profile","last_run_tick","last_sync_tick","pollution_factor_base","pollution_factor_multiplier"},collections={},sources={"exotic-space-industries-remembrance/scripts/control/nauvis-pressure-grace.lua","exotic-space-industries-remembrance/lib/enemy-difficulty-config.lua"}},
    {id="neutron-collector",label="Neutron collectors",blueprint="neutron-collector",root="ei.neutron_runtime",repair="rebuild_runtime_state",call="repair",fields={"runtime_version","collector_count","dirty_collector_count","needs_rebuild"},collections={"collectors_by_unit","dirty_collector_queue.items"},sources={"exotic-space-industries-remembrance/scripts/control/neutron-collector.lua"}},
    {id="orbital-logistics",label="Orbital logistics",blueprint="orbital-logistics",root="ei.orbital_logistics",repair="request_runtime_rescan",call="repair",fields={"runtime_state_version","last_rescan_tick","pending_rescan_reason"},collections={"cohorts","transponders_by_unit","selectors_by_unit","coordinators_by_unit","uplinks_by_unit","lease_by_job_id"},sources={"exotic-space-industries-remembrance/scripts/control/orbital-logistics.lua"}},
    {id="orbital-combinator",label="Orbital scanners",blueprint="orbital-combinator",root="ei",repair="repair_runtime_state",call="repair",fields={"orbital_combinator_bank_count","orbital_combinator_runtime_state_version","orbital_combinator_generation_epoch"},collections={"orbital_combinators","orbital_combinator_banks","orbital_combinator_mode_by_unit"},sources={"exotic-space-industries-remembrance/scripts/control/orbital-combinator.lua"}},
    {id="railgun-cooling",label="Railgun cooling",blueprint="railgun-cooling",root="ei.railgun_cooling",repair="repair_runtime_state",call="repair",fields={"version","next_due_tick"},collections={"turrets_by_unit","recovery_pending_by_unit","recovery_buckets","open_by_player"},sources={"exotic-space-industries-remembrance/scripts/control/railgun-cooling.lua","exotic-space-industries-remembrance/migrations/1.3.40.lua"}},
    {id="tech-scaling",label="Research scaling",blueprint="research-and-progression",root="ei.tech_scaling",repair="init",call="none",fields={"cacheRevision","appliedMultiplier","selectedForceKey","techCount"},collections={"researchedSnapshot.ageTotals"},sources={"exotic-space-industries-remembrance/scripts/control/tech-scaling.lua","exotic-space-industries-remembrance/lib/tech-weighting.lua","exotic-space-industries-remembrance/lib/tech-scaling-common.lua","exotic-space-industries-remembrance/lib/tech-scaling-shared.lua","exotic-space-industries-remembrance/migrations/1.3.35.lua","exotic-space-industries-remembrance/migrations/1.3.36.lua"}},
    {id="victory",label="Victory progress",blueprint="research-and-progression",root="ei.stats",repair="repair_runtime_state",call="repair",fields={},collections={},sources={"exotic-space-industries-remembrance/scripts/control/victory-disabler.lua"}},
    {id="rocket-launch-pollution",label="Rocket launch consequences",blueprint="rocket-launch-pollution",root="ei.rocket_launch_pollution",repair="repair_runtime_state",call="repair",fields={"launch_smoke_count","next_launch_smoke_tick","next_pending_cleanup_tick","pending_cleanup_item_count","pending_cleanup_bucket_count"},collections={"pending_launches_by_silo","pending_launch_cleanup_buckets","launch_smoke"},sources={"exotic-space-industries-remembrance/scripts/control/rocket-launch-pollution.lua"}},
    {id="randomized-tree-growth",label="Agricultural growth jitter",blueprint="randomized-tree-growth",root="ei.randomized_tree_growth",repair="repair_runtime_state",call="repair",fields={},collections={"pending_offsets_by_tower"},sources={"exotic-space-industries-remembrance/scripts/control/randomized-tree-growth.lua"}},
    {id="sawblade-turret",label="Oathbreaker sawblade turrets",blueprint="sawblade-turret",root="ei.sawblade_turret",repair="rebuild_runtime_state",call="none",fields={"version"},collections={"entities_by_unit","render_registrations_by_unit"},sources={"exotic-space-industries-remembrance/scripts/control/sawblade-turret.lua"}},
    {id="singularity-lance",label="Singularity Lances",blueprint="singularity-lance",root="ei.singularity_lance",repair="refresh_runtime_state",call="eventonly",fields={"version","pending","next_due","pending_contacts","sweep_count","visual_next_due","presentation_revision"},collections={"lances","force_cache"},sources={"exotic-space-industries-remembrance/scripts/control/singularity-lance.lua","exotic-space-industries-remembrance/lib/singularity-lance-config.lua"}},
    {id="spider-vehicles",label="Spider vehicles and limiter",blueprint="spider-vehicles",root="ei.spider_vehicles",repair="repair_runtime_state",call="repair",fields={"next_id","replacements","failures"},collections={"vehicles","units","items","retries","pulses"},sources={"exotic-space-industries-remembrance/scripts/control/spider-vehicles.lua","exotic-space-industries-remembrance/scripts/control/spidertron-limiter.lua","exotic-space-industries-remembrance/lib/spider-vehicles.lua"}},
    {id="steam-train",label="Steam train wheel helpers",blueprint="steam-train",root="ei.locomotives",repair="rebuild_runtime_state",call="repair",fields={"audit_cursor"},collections={"locomotives_by_unit","active_units"},sources={"exotic-space-industries-remembrance/scripts/control/steam-train.lua"}},
    {id="surveyor-scope",label="Surveyor scopes",blueprint="surveyor-scope",root="ei.surveyor_scope",repair="repair_runtime_state",call="repair",fields={},collections={"players"},sources={"exotic-space-industries-remembrance/scripts/control/surveyor-scope.lua"}},
    {id="sweeping-radar",label="Sweeping radars",blueprint="sweeping-radar",root="ei.sweeping_radar",repair="repair_runtime_state",call="repair",fields={"version","jobs","force_epoch"},collections={"records","order","transfers"},sources={"exotic-space-industries-remembrance/scripts/control/sweeping-radar.lua","exotic-space-industries-remembrance/scripts/control/sweeping-radar-gui.lua","exotic-space-industries-remembrance/scripts/control/sweeping-radar-visuals.lua","exotic-space-industries-remembrance/lib/sweeping-radar-config.lua","exotic-space-industries-remembrance/lib/sweeping-radar-geometry.lua","exotic-space-industries-remembrance/lib/sweeping-radar-contacts.lua","exotic-space-industries-remembrance/lib/sweeping-radar-timers.lua"}},
    {id="teslas-legacy",label="Tesla runtime",blueprint="tesla-runtime",root="ei.tesla_legacy",repair="repair_runtime_state",call="repair",fields={"last_prune_tick"},collections={"force_cache","variant_sync_jobs","legacy_helper_expiry_buckets"},sources={"exotic-space-industries-remembrance/scripts/control/teslas-legacy.lua","exotic-space-industries-remembrance/teslas_legacy/config/settings.lua","exotic-space-industries-remembrance/teslas_legacy/config/research.lua","exotic-space-industries-remembrance/teslas_legacy/control.lua"}},
    {id="vulcanus-fumaroles",label="Vulcanus auric fumaroles",blueprint="vulcanus-fumaroles",root="ei.vulcanus_fumaroles",repair="repair_runtime_state",call="repair",fields={"runtime_version","eligibility_version","pending_eligibility_refresh","zero_active_since_tick","below_floor_since_tick"},collections={"active","dormant_chunks","processed_chunks","history_chunks"},sources={"exotic-space-industries-remembrance/scripts/control/vulcanus-fumaroles.lua"}},
    {id="arrival",label="Arrival presentation",blueprint="startup-and-integration",root="ei",repair="repair_runtime_state",call="repair",fields={"arrival_waves_next_due_tick"},collections={"arrival_waves","pending_arrivals"},sources={"exotic-space-industries-remembrance/lib/echo-codex.lua"}},
    {id="informatron-messager",label="Informatron notifications",blueprint="startup-and-integration",root="ei.informatron_messager",repair="repair_runtime_state",call="repair",fields={},collections={"notified_by_force"},sources={"exotic-space-industries-remembrance/scripts/control/informatron-messager.lua"}},
    {id="mining-scars",label="Mining scars",blueprint="mining-scars",root=nil,repair=nil,call="stateless",fields={},collections={},sources={"exotic-space-industries-remembrance/scripts/control/mining-scars.lua"}},
    {id="runtime-orchestration",label="Runtime orchestration",blueprint="runtime-orchestration",root="ei",repair=nil,call="infrastructure",fields={"scripted_research_burst.next_due_tick"},collections={"scripted_research_burst.pending_by_force"},sources={"exotic-space-industries-remembrance/control.lua","exotic-space-industries-remembrance/scripts/control/global.lua","exotic-space-industries-remembrance/scripts/control/register-util.lua"}},
    {id="runtime-scheduler",label="Runtime scheduler",blueprint="runtime-scheduler",root="ei.runtime_scheduler",repair=nil,call="infrastructure",fields={"version","telemetry.enabled","telemetry.last_snapshot_tick"},collections={"modules"},sources={"exotic-space-industries-remembrance/lib/runtime-scheduler.lua"}},
    {id="shared-runtime-helpers",label="Shared helpers",blueprint="shared-runtime-helpers",root=nil,repair=nil,call="helper",fields={},collections={},sources={"exotic-space-industries-remembrance/lib/lib.lua","exotic-space-industries-remembrance/lib/data.lua","exotic-space-industries-remembrance/lib/rng.lua","exotic-space-industries-remembrance/lib/loaders.lua","exotic-space-industries-remembrance/lib/surface-anchor.lua","exotic-space-industries-remembrance/lib/handle-wheels.lua"}},
    {id="integration",label="Compatibility and information interfaces",blueprint="startup-and-integration",root=nil,repair=nil,call="stateless",fields={},collections={},sources={"exotic-space-industries-remembrance/scripts/control/compat.lua","exotic-space-industries-remembrance/scripts/control/debug.lua","exotic-space-industries-remembrance/scripts/control/informatron.lua","exotic-space-industries-remembrance/scripts/control/milestone-preset.lua"}},
}
DEFINITIONS[#DEFINITIONS+1]={id="admin-tools",label="Administration console and jobs",blueprint="admin-tools",root="ei.admin_tools",repair="repair_runtime_state",call="repair",fields={"version","speed_before","restriction_tracking.tracked_count","restriction_tracking.census.started_tick","restriction_tracking.census.examined","restriction_tracking.census.chunks","restriction_tracking.completed_tick","restriction_tracking.examined","restriction_tracking.chunks"},collections={"sessions","world.jobs","modes","jails","restrictions","restriction_tracking.records"},sources={"exotic-space-industries-remembrance/scripts/control/admin-tools.lua","exotic-space-industries-remembrance/scripts/control/admin/common.lua","exotic-space-industries-remembrance/scripts/control/admin/gui.lua","exotic-space-industries-remembrance/scripts/control/admin/world.lua","exotic-space-industries-remembrance/scripts/control/admin/players.lua","exotic-space-industries-remembrance/scripts/control/admin/targeting.lua","exotic-space-industries-remembrance/scripts/control/admin/restrictions.lua","exotic-space-industries-remembrance/lib/admin-tools-config.lua"}}
DEFINITIONS[#DEFINITIONS+1]={id="camera-windows",label="Shared camera windows",blueprint="camera-windows",root="ei_camera_windows",call="helper",fields={"next_due"},collections={"windows","by_target"},sources={"exotic-space-industries-remembrance/lib/camera-window.lua"}}
local BY_ID={}
for _,entry in ipairs(DEFINITIONS) do BY_ID[entry.id]=entry end
local SCALAR_TYPES={string=true,number=true,boolean=true}
local ENABLED_SETTINGS={
    ["admin-tools"]="ei-admin-tools-enabled",
    ["flamethrower-fuels"]="ei-flamethrower-fuel-adaptation",
    ["beacon-overload"]="ei-beacon-overload",
}
local STATUS_FIELDS={
    "tick","version","runtime_version","tracked_count","count","pending","next_due_tick",
    "active_jobs","pending_rings","tracked_railguns","registered_lances","tracked_vat_count",
    "bank_count","cohort_count","target_count","machine_count","collector_count","rebuild_reason",
    "live_crystals","active_surfaces","queued_surfaces","due_surfaces","next_surface_due_tick","watched_players",
    "tracked_tanks","charging","cooling_down","charge_queue_items","charge_bucket_count","charge_bucket_items",
    "next_charge_due_tick","next_pulse_cleanup_tick",
}
local COUNTER_FIELDS={
    "registered","deregistered","invalid_purges","emitted","capped","jobs_started","jobs_completed",
    "rings_processed","searches","samples","pulses","power_checks","replacements","failures",
}

---@class ESIRAdminRegistryContext
---@field state fun(): table Admin-owned state, writable only during explicit actions.
---@field modules table<string, table> Top-level loaded owner modules keyed by registry ID.
---@field enabled boolean|fun(): boolean
---@field notify fun(actor: integer?, message: string)?
---@param value ESIRAdminRegistryContext
function model.configure(value) context=value end

-- Fixed paths belong to this explicit registry; traversal never initializes state.
local function read_path(root,path)
    if path==nil then return nil end
    if path=="" then return root end
    local value=root
    for key in string.gmatch(path,"[^.]+") do
        if type(value)~="table" then return nil end
        value=value[key]
    end
    return value
end

local function existing_admin_state()
    return storage and storage.ei and storage.ei.admin_tools or nil
end

local function is_enabled()
    return context and (type(context.enabled)=="function" and context.enabled() or context.enabled==true)
end

local function actor_index(actor)
    if type(actor)=="number" then return actor end
    return actor and actor.index or nil
end

local function authorized(actor)
    if not is_enabled() then return false,"Admin tools are disabled." end
    local index=actor_index(actor)
    if not index then
        if actor~=nil then return false,"Invalid administrator identity." end
        return true -- trusted server invocation; GUI always supplies a player
    end
    local player=game.get_player(index)
    if not (player and player.valid and player.admin) then return false,"Administrator access is required." end
    return true
end

local function metadata(entry)
    return {
        id=entry.id,label=entry.label,blueprint=entry.blueprint,repair=entry.repair,
        classification=entry.repair and "stateful" or entry.call,
        sources=lib.copy_array(entry.sources),command=entry.repair and ("/ei-admin-repair "..entry.id) or nil,
    }
end

function model.list()
    local result={}
    for _,entry in ipairs(DEFINITIONS) do result[#result+1]=metadata(entry) end
    return result
end

function model.get(id)
    local entry=BY_ID[id]
    return entry and metadata(entry) or nil
end

-- All active runtime sources have an explicit owner; inactive/data-only files remain explained.
function model.coverage()
    local result={}
    for _,entry in ipairs(DEFINITIONS) do
        for _,path in ipairs(entry.sources) do
            result[path]={owner=entry.id,classification=entry.repair and "stateful" or entry.call}
        end
    end
    result["exotic-space-industries-remembrance/scripts/control/event-handlers.lua"]={classification="inactive",reason="Empty unreferenced placeholder."}
    result["exotic-space-industries-remembrance/scripts/control/more-asteroids-spawners.lua"]={classification="data-only",reason="Imported only by data-stage asteroid generation."}
    result["exotic-space-industries-remembrance/scripts/control/admin/registry.lua"]={owner="admin-tools",classification="helper"}
    return result
end

---@param id string
---@param tick MapTick
---@return table?
function model.peek(id,tick)
    local entry=BY_ID[id]
    if not entry then return nil end
    local root=read_path(storage,entry.root)
    local result=metadata(entry)
    result.sample_tick=tick
    result.state=entry.root and (type(root)=="table" and "initialized" or "not-initialized") or entry.call
    result.enabled="Not sampled"
    local schema=type(root)=="table" and (root.version or root.runtime_version or root.schema_version)
    result.schema=SCALAR_TYPES[type(schema)] and schema or "Not sampled"
    result.fields={}
    for _,path in ipairs(entry.fields) do
        local value=read_path(root,path)
        if SCALAR_TYPES[type(value)] then result.fields[path]=value else result.fields[path]="Not sampled" end
    end
    local scheduler=storage and storage.ei and storage.ei.runtime_scheduler
    local cached=type(scheduler)=="table" and type(scheduler.modules)=="table" and scheduler.modules[entry.scheduler_id or id]
    if type(cached)~="table" then cached=nil end
    local enabled_setting=ENABLED_SETTINGS[id] and settings.startup[ENABLED_SETTINGS[id]]
    if enabled_setting and type(enabled_setting.value)=="boolean" then result.enabled=enabled_setting.value
    elseif type(root)=="table" and type(root.enabled)=="boolean" then result.enabled=root.enabled
    elseif cached and type(cached.status)=="table" and type(cached.status.enabled)=="boolean" then result.enabled=cached.status.enabled end
    result.cache_updated_tick=cached and type(cached.last_tick)=="number" and cached.last_tick or "Not sampled"
    result.cached={}
    result.counters={}
    for _,key in ipairs(STATUS_FIELDS) do
        local value=cached and type(cached.status)=="table" and cached.status[key]
        if SCALAR_TYPES[type(value)] then result.cached[key]=value end
    end
    for _,key in ipairs(COUNTER_FIELDS) do
        local value=(type(root)=="table" and type(root.counters)=="table" and root.counters[key])
            or (cached and type(cached.counters)=="table" and cached.counters[key])
        if type(value)=="number" then result.counters[key]=value end
    end
    local admin=existing_admin_state()
    local repairs=admin and admin.registry_repairs
    local repair=type(repairs)=="table" and repairs[id]
    if type(repair)=="table" then
        if type(repair.tick)=="number" then result.last_repair_tick=repair.tick end
        if type(repair.ok)=="boolean" then result.last_repair_ok=repair.ok end
        if type(repair.message)=="string" then result.last_repair_message=repair.message end
    end
    result.notes="Counts without a cached scalar are available through Inspect. This summary does not poll entities."
    return result
end

---@param actor integer|LuaPlayer|nil
---@param id string
---@param tick MapTick
function model.repair(actor,id,tick)
    local allowed,message=authorized(actor)
    if not allowed then return false,message end
    local entry=BY_ID[id]
    if not (entry and entry.repair) then return false,"This module has no independent persistent state to repair." end
    local owner=context.modules and context.modules[id]
    local action=owner and owner[entry.repair]
    if type(action)~="function" then return false,"Repair provider unavailable: "..id.."." end
    local reason="admin-repair"
    local ok,result,detail
    if entry.call=="none" then ok,result,detail=pcall(action)
    elseif entry.call=="reason" then ok,result,detail=pcall(action,reason)
    elseif entry.call=="event" then ok,result,detail=pcall(action,reason,{tick=tick})
    elseif entry.call=="eventonly" then ok,result,detail=pcall(action,{tick=tick})
    else ok,result,detail=pcall(action,reason,tick) end
    local success=ok and result~=false
    message=success and ("Repair requested: "..entry.label..".")
        or ("Repair failed: "..tostring(ok and detail or result)..".")
    local admin=context.state()
    admin.registry_repairs=admin.registry_repairs or {}
    admin.registry_repairs[id]={tick=tick,ok=success,message=message}
    return success,message
end

---@param actor integer|LuaPlayer|nil
---@param id string
---@param tick MapTick
function model.start_inspection(actor,id,tick)
    local allowed,message=authorized(actor)
    if not allowed then return false,message end
    local entry=BY_ID[id]
    if not entry then return false,"Unknown module." end
    local admin=context.state()
    if admin.inspection then return false,"An inspection is already running; cancel it before starting another." end
    local paths=lib.copy_array(entry.collections)
    if #paths==0 and entry.root then paths[1]="" end
    admin.inspection={
        actor_index=actor_index(actor),id=id,started_tick=tick,paths=paths,path_index=1,
        cursor=nil,examined=0,collections={},summary=model.peek(id,tick),
    }
    return true,"Inspection started: "..entry.label.."."
end

function model.inspect(id,options,tick)
    return model.start_inspection(options and options.actor_index,id,tick)
end

function model.cancel_inspection(actor)
    local allowed,message=authorized(actor)
    if not allowed then return false,message end
    local admin=context.state()
    admin.inspection=nil
    return true,"Inspection cancelled."
end

function model.get_inspection(actor)
    local admin=existing_admin_state()
    local key=actor_index(actor) or 0
    local result=admin and admin.inspection_results and admin.inspection_results[key]
    return result and table.deepcopy(result) or nil
end

function model.has_tick_work()
    local admin=existing_admin_state()
    return is_enabled() and admin and admin.inspection~=nil or false
end

local function finish_inspection(admin,job,tick)
    job.completed_tick=tick
    job.elapsed_ticks=tick-job.started_tick
    job.world_may_have_changed=job.elapsed_ticks>0
    job.cursor=nil
    admin.inspection_results=admin.inspection_results or {}
    admin.inspection_results[job.actor_index or 0]=job
    admin.inspection=nil
    if context.notify then context.notify(job.actor_index,"Inspection finished: "..job.id..".") end
    if context.changed then context.changed("diagnostics",job.id) end
end

-- Only a requested job enters this path. Never call owner getters or scan the live world.
-- Cursors are keys and explicit source paths, not aliases to gameplay tables in admin storage.
---@param event EventData.on_tick
function model.updater(event)
    local admin=existing_admin_state()
    local job=admin and admin.inspection
    if not job then return end
    if not authorized(job.actor_index) then admin.inspection=nil;return end
    local entry=BY_ID[job.id]
    if not entry then admin.inspection=nil;return end
    for _=1,INSPECTION_BUDGET do
        local path=job.paths[job.path_index]
        if not path or job.examined>=MAX_INSPECTION_RECORDS then
            job.truncated=job.examined>=MAX_INSPECTION_RECORDS
            finish_inspection(admin,job,event.tick)
            return
        end
        local collection=read_path(read_path(storage,entry.root),path)
        local report=job.collections[job.path_index]
        if not report then
            report={path=path=="" and "(owner root)" or path,entries=0,valid_entities=0,invalid_entities=0,scalar_values=0,changed_during_inspection=false}
            job.collections[job.path_index]=report
        end
        if type(collection)~="table" then
            report.missing=true
            job.path_index=job.path_index+1;job.cursor=nil
        else
            local ok,key,value=pcall(next,collection,job.cursor)
            if not ok then
                -- A removed key invalidates next(). Stop this collection, never restart a moving scan forever.
                report.changed_during_inspection=true
                job.path_index=job.path_index+1;job.cursor=nil
            elseif key==nil then
                job.path_index=job.path_index+1;job.cursor=nil
            elseif type(key)~="number" and type(key)~="string" and type(key)~="boolean" then
                report.unsupported_key=true
                job.path_index=job.path_index+1;job.cursor=nil
            else
                job.cursor=key;job.examined=job.examined+1;report.entries=report.entries+1
                if SCALAR_TYPES[type(value)] then report.scalar_values=report.scalar_values+1
                else
                    local entity
                    -- Invalid direct LuaEntity handles must count too. Checking validity
                    -- first loses them, and indexing record fields on another LuaObject errors.
                    local ok,object_name=pcall(function() return value.object_name end)
                    if ok and object_name=="LuaEntity" then entity=value
                    elseif type(value)=="table" and (not ok or object_name==nil) then entity=value.entity or value.turret or value.gate end
                    if entity~=nil then
                        if lib.entity_check(entity) then report.valid_entities=report.valid_entities+1
                        else report.invalid_entities=report.invalid_entities+1 end
                    end
                end
            end
        end
    end
end

return model

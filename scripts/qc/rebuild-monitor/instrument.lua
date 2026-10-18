
-- Appended only to the isolated full-pack QC copy.
local rebuild_qc_core=require("__zzz-esir-rebuild-qc__/core")
local rebuild_qc_checks={}
local function rebuild_qc_check(name,ok)
    rebuild_qc_checks[#rebuild_qc_checks+1]={name=name,ok=not not ok}
end
local rebuild_qc_native={ids={}}
local function rebuild_qc_record(tick,owner,id,active)
    local snapshot=ei_runtime_scheduler.peek_rebuilds(tick,owner)
    for _,record in ipairs(active and snapshot.active or snapshot.history) do
        if record.id==id then return record end
    end
end
local function rebuild_qc_capture(tick,key,owner,operation,force_index)
    local found
    for _,record in ipairs(ei_runtime_scheduler.peek_rebuilds(tick,owner).active) do
        if record.operation==operation and (not force_index or record.force_index==force_index) then found=record;break end
    end
    rebuild_qc_check(key.." native batch admitted",found~=nil)
    if found then rebuild_qc_native.ids[key]={owner=owner,id=found.id} end
    return found
end
local function rebuild_qc_native_prepare(tick)
    local fixture=rebuild_qc_native
    fixture.force=game.forces["rebuild-producer-qc"] or game.create_force("rebuild-producer-qc")
    fixture.surface=game.create_surface("rebuild-producer-qc",{width=128,height=128,
        autoplace_settings={entity={treat_missing_as_default=false},decorative={treat_missing_as_default=false}}})
    fixture.surface.request_to_generate_chunks({0,0},2);fixture.surface.force_generate_chunk_requests()
    local tiles={}
    for x=-24,24 do for y=-12,12 do tiles[#tiles+1]={name="refined-concrete",position={x,y}} end end
    fixture.surface.set_tiles(tiles,true)
    fixture.machine=assert(fixture.surface.create_entity{name="assembling-machine-2",position={-16,0},force=fixture.force,raise_built=false})
    rebuild_qc_check("beacon eligible native machine",ei_beacon_overload.counts_for_overload(fixture.machine))
    ei_beacon_overload.set_enabled_for_qc(true,tick)
    fixture.tesla_position={x=-6,y=0}
    fixture.tesla=assert(fixture.surface.create_entity{name="tl-basic-tesla-coil__exotic",position=fixture.tesla_position,force=fixture.force,raise_built=false})
    ei_teslas_legacy.on_scripted_research_burst(fixture.force,true,tick)
    fixture.flames={}
    rebuild_qc_check("flame restoration startup disabled",settings.startup["ei-flamethrower-fuel-adaptation"].value==false)
    for i=1,4 do
        local position={x=4+i*4,y=0}
        local turret=assert(fixture.surface.create_entity{name="ei-flamethrower-turret-heavy-oil",position=position,force=fixture.force,raise_built=true})
        turret.health=123;fixture.flames[#fixture.flames+1]=position
    end
    fixture.vulcanus=game.surfaces.vulcanus or assert(game.planets.vulcanus).create_surface()
    fixture.vulcanus.request_to_generate_chunks({0,0},1);fixture.vulcanus.force_generate_chunk_requests()
    ei_vulcanus_fumaroles.on_configuration_changed({mod_changes={}})
    local chunks=0;for _ in fixture.vulcanus.get_chunks() do chunks=chunks+1 end
    rebuild_qc_check("fumarole generated native chunks",chunks>0)
    local gaia=assert(ei_gaia.ensure_surface(),"Gaia surface fixture");fixture.gaia_index=gaia.index
    for _,resource in pairs(gaia.find_entities_filtered{type="resource"}) do resource.destroy() end
    ei_gaia.reforge_gaia_surface{tick=tick}
    fixture.world_chunks={}
    for _,surface in pairs(game.surfaces) do
        local chunks=0;for _ in surface.get_chunks() do chunks=chunks+1 end
        fixture.world_chunks[#fixture.world_chunks+1]={index=surface.index,name=surface.name,chunks=chunks}
    end
end
local function rebuild_qc_native_capture(tick)
    rebuild_qc_capture(tick,"beacon","beacon-overload","topology")
    rebuild_qc_capture(tick,"Tesla","teslas-legacy","variant-sync",rebuild_qc_native.force.index)
    local flame=rebuild_qc_capture(tick,"flame","flamethrower-fuels","restore-variants")
    rebuild_qc_check("flame admitted actual turret work",flame and flame.total>=4)
    local fumarole=rebuild_qc_capture(tick,"fumarole","vulcanus-fumaroles","backfill")
    rebuild_qc_check("fumarole admitted actual chunk work",fumarole and fumarole.total>0)
    rebuild_qc_capture(tick,"Gaia","gaia","reforge")
end
local function rebuild_qc_native_finish(tick)
    local fixture=rebuild_qc_native
    for key,reference in pairs(fixture.ids) do
        local active=rebuild_qc_record(tick,reference.owner,reference.id,true)
        local done=rebuild_qc_record(tick,reference.owner,reference.id,false)
        rebuild_qc_check(key.." captured generation finished",not active and done and done.outcome=="completed")
        if key~="Gaia" then rebuild_qc_check(key.." actual work recorded",done and done.completed>0) end
        if key=="flame" or key=="fumarole" then rebuild_qc_check(key.." final counters complete",done and done.completed==done.total) end
    end
    local machine=ei_beacon_overload.get_qc_snapshot(fixture.machine.unit_number).machine
    rebuild_qc_check("beacon native machine discovered and recounted",machine and machine.tracked and machine.weighted_count~=nil and not machine.queued)
    local coils=fixture.surface.find_entities_filtered{position=fixture.tesla_position,name="tl-basic-tesla-coil",force=fixture.force}
    rebuild_qc_check("Tesla native identity synchronized",not fixture.tesla.valid and #coils==1)
    local restored=0
    for _,position in ipairs(fixture.flames) do
        local turret=fixture.surface.find_entities_filtered{position=position,name="flamethrower-turret",force=fixture.force}[1]
        if turret and turret.health==123 then restored=restored+1 end
    end
    rebuild_qc_check("flame native identities and health restored",restored==#fixture.flames)
    local gaia=game.planets.gaia.surface
    rebuild_qc_check("Gaia native reforge completed",gaia and gaia.valid and gaia.index~=fixture.gaia_index and storage.ei.reforge_gaia==nil)
end
local rq_radar_config=require("lib/sweeping-radar-config")
local rq_spiders=require("lib/spider-vehicles")
local rq_restrictions=require("scripts/control/admin/restrictions")
local function rq_active(owner,operation,tick)
    for _,row in ipairs(ei_runtime_scheduler.peek_rebuilds(tick,owner).active) do if not operation or row.operation==operation then return row end end
end
local function rq_finished(owner,operation,tick)
    for _,row in ipairs(ei_runtime_scheduler.peek_rebuilds(tick,owner).history) do if row.operation==operation and row.outcome=="completed" then return row end end
end
local function populated_start(tick)
    local f={start=tick};storage.rebuild_qc_populated=f
    local surface=game.create_surface("ei-rebuild-populated-qc",{width=512,height=512,water="none",
        autoplace_settings={entity={treat_missing_as_default=false},decorative={treat_missing_as_default=false}}})
    surface.request_to_generate_chunks({0,0},4);surface.force_generate_chunk_requests();f.surface=surface
    local function create(name,x,y,force) return assert(surface.create_entity{name=name,position={x,y},force=force or "player",raise_built=true},name) end
    for y=-12,12,2 do assert(surface.create_entity{name="straight-rail",position={-80,y},direction=defines.direction.north,force="player"}) end
    local train=create("ei_em-locomotive",-80,0)
    -- Settle the owner's pre-existing first-registration invariant repair before research admission.
    em_trains.ensure_runtime_ready()
    em_trains.request_research_rollout("train",tick)
    rebuild_qc_check("EM native train admitted",rq_active("em-trains","research-train",tick)~=nil)
    train.destroy{raise_destroy=true}
    rebuild_qc_check("EM last train removal retires report",rq_active("em-trains","research-train",tick)==nil)
    f.train=create("ei_em-locomotive",-80,0);f.charger=create("ei_charger",-72,0)
    em_trains.ensure_runtime_ready()
    em_trains.request_research_rollout("train",tick);em_trains.request_research_rollout("train",tick)
    local coalesced=rq_active("em-trains","research-train",tick)
    f.em_train_report_id=coalesced and coalesced.id
    rebuild_qc_check("EM coalesced generation denominator unknown",coalesced and coalesced.phase=="research-rescan" and coalesced.total==nil)
    em_trains.request_research_rollout("charger",tick)
    local charger_job=rq_active("em-trains","research-charger",tick);f.em_charger_report_id=charger_job and charger_job.id
    rebuild_qc_check("EM native charger admitted",rq_active("em-trains","research-charger",tick)~=nil)
    local force=game.create_force("rebuild-spider-qc")
    local smart=settings.startup["ei-spider-range-aware-cycling"].value
    local name=rq_spiders.configured_name("rocket",rq_spiders.researched_state(force),{cycling=true,special=true},smart)
    local survivor=create(name,-80,70,force);local removed=create(name,-64,70,force)
    f.spider_id=ei_spider_vehicles.get_vehicle_id(survivor)
    ei_spider_vehicles.set_weapon_controls(survivor,{cycling=false},tick);ei_spider_vehicles.set_weapon_controls(removed,{cycling=false},tick)
    rebuild_qc_check("ordinary spider preference queue excluded",rq_active("spider-vehicles",nil,tick)==nil)
    f.spider_target=rq_spiders.configured_name("rocket",rq_spiders.researched_state(force),{cycling=false,special=true},smart)
    ei_spider_vehicles.repair_runtime_state("rebuild-qc",tick)
    local refit=rq_active("spider-vehicles","refit",tick)
    rebuild_qc_check("populated spider cohort admitted",refit and refit.total==2)
    removed.destroy{raise_destroy=true}
    f.water=create("ei-water-turret",24,24)
    for i=0,599 do assert(surface.create_entity{name="ei-oil-fire-flame",position={32+(i%30)*0.2,32+math.floor(i/30)*0.2},force="neutral"}) end
    ei_water_turret.repair_runtime_state("rebuild-qc",tick)
    local water=rq_active("water-turret","fire-index",tick)
    rebuild_qc_check("populated water seeding admitted",water and water.total>0)
    f.radar_powered=create("ei-sweeping-radar",40,-70);f.radar_dry=create("ei-sweeping-radar",80,-70)
    local preferences=rq_radar_config.defaults()
    for _,mode in pairs(preferences.modes) do mode.radius=16;mode.near=0 end
    ei_sweeping_radar.set_settings(assert(ei_sweeping_radar.get_record(f.radar_powered)),preferences,tick)
    ei_sweeping_radar.set_settings(assert(ei_sweeping_radar.get_record(f.radar_dry)),preferences,tick)
    ei_sweeping_radar.repair_runtime_state("rebuild-qc",tick)
    local radar=rq_active("sweeping-radar","reconstruction",tick)
    rebuild_qc_check("native radar cohort admitted",radar and radar.total==2)
    f.radar_late=create("ei-sweeping-radar",120,-70)
    rebuild_qc_check("ordinary radar build excluded from cohort",rq_active("sweeping-radar","reconstruction",tick).total==2)
    f.ready=true
end
local rq_radar_updater=ei_sweeping_radar.updater
ei_sweeping_radar.updater=function(event)
    local f=storage.rebuild_qc_populated
    if f and f.ready and f.radar_powered and f.radar_powered.valid then
        local record=ei_sweeping_radar.get_record(f.radar_powered)
        if record and record.power and record.power.valid then record.power.energy=record.power.electric_buffer_size end
    end
    rq_radar_updater(event)
    if f and f.ready then
        local row=rq_active("sweeping-radar","reconstruction",event.tick)
        if row and row.state=="running" and row.eta_blocked then f.radar_mixed_seen=true;if row.eta_ticks~=nil then f.radar_bad_eta=true end end
        if row and row.state=="waiting" and row.completed>0 then f.radar_waiting_seen=true end
    end
end
local rq_water_updater=ei_water_turret.updater
ei_water_turret.updater=function(event)
    rq_water_updater(event)
    local f=storage.rebuild_qc_populated;local root=f and f.ready and storage.ei.water_turret
    if not root then return end
    f.water_peak_count=math.max(f.water_peak_count or 0,root.index.count or 0)
    local seeds=root.index.seeds
    if (seeds.tail or 0)<(seeds.head or 1) then
        local queue=root.cold_queue
        for i=queue.head,queue.tail do
            local job=queue.items[i]
            if job and job.kind=="seed" and job.bucket.rebuild_generation and job.cursor<=#job.entities then
                f.water_ingestion_after_queries=true
                if not rq_active("water-turret","fire-index",event.tick) then f.water_lost_report=true end
            end
        end
    end
end
local function populated_finish(tick)
    local f=assert(storage.rebuild_qc_populated)
    rebuild_qc_check("EM populated rollout naturally drains",rq_active("em-trains",nil,tick)==nil)
    local train=rebuild_qc_record(tick,"em-trains",f.em_train_report_id,false)
    local charger=rebuild_qc_record(tick,"em-trains",f.em_charger_report_id,false)
    rebuild_qc_check("EM native rollout completion history",train and train.outcome=="completed" and charger and charger.outcome=="completed" and charger.completed==charger.total)
    local record=storage.ei.spider_vehicles.vehicles[f.spider_id]
    rebuild_qc_check("native spider refit actually changes variant",record and record.entity.valid and record.entity.name==f.spider_target)
    rebuild_qc_check("removed spider does not strand cohort",rq_active("spider-vehicles","refit",tick)==nil)
    local spiders=rq_finished("spider-vehicles","refit",tick)
    rebuild_qc_check("spider removal included in terminal cohort",spiders and spiders.completed==2 and spiders.total==2)
    rebuild_qc_check("water ingestion continues after final seed query",f.water_ingestion_after_queries and not f.water_lost_report)
    rebuild_qc_check("water native seed ingestion finishes",rq_active("water-turret","fire-index",tick)==nil and (f.water_peak_count or 0)>0)
    rebuild_qc_check("radar mixed active and blocked stays public without ETA",f.radar_mixed_seen and not f.radar_bad_eta)
    local radar=rq_active("sweeping-radar","reconstruction",tick)
    rebuild_qc_check("radar completed member and dormant remainder",f.radar_waiting_seen and radar and radar.state=="waiting" and radar.completed==1 and radar.total==2)
    f.radar_dry.destroy{raise_destroy=true}
    rebuild_qc_check("last blocked radar removal retires cohort",rq_active("sweeping-radar","reconstruction",tick)==nil)
    local done=rq_finished("sweeping-radar","reconstruction",tick)
    rebuild_qc_check("radar ordinary late build never extends completed cohort",done and done.total==2 and done.completed==2 and f.radar_late.valid)
end
remote.add_interface("esir-rebuild-qc",{
    start=function(tick)
        rebuild_qc_checks=rebuild_qc_core.run(ei_runtime_scheduler,tick)
        rebuild_qc_native_prepare(tick)
        ei_beacon_overload.refresh_all_overloads("rebuild-qc",tick)
        rebuild_qc_check("beacon real admission",#ei_runtime_scheduler.peek_rebuilds(tick,"beacon-overload").active>0)
        orbital_logistics.request_runtime_rescan("rebuild-qc",tick)
        rebuild_qc_check("orbital real queued admission",#ei_runtime_scheduler.peek_rebuilds(tick,"orbital-logistics").active>0)
        ei_flamethrower_fuels.repair_runtime_state("rebuild-qc",tick)
        ei_teslas_legacy.on_scripted_research_burst(game.forces.player,true,tick)
        rebuild_qc_check("Tesla real admission",#ei_runtime_scheduler.peek_rebuilds(tick,"teslas-legacy").active>0)
        ei_vulcanus_fumaroles.repair_runtime_state("rebuild-qc",tick)
        rebuild_qc_check("empty-owner repairs accepted",true)
        rebuild_qc_native_capture(tick)
        populated_start(tick)
        local player=game.connected_players[1]
        rebuild_qc_check("native restriction census admitted",rq_restrictions.set(player,true,tick))
        rebuild_qc_capture(tick,"census","admin-tools","restriction-attribution")
    end,
    finish=function(tick)
        rebuild_qc_native_finish(tick)
        populated_finish(tick)
        local player=game.connected_players[1]
        rq_restrictions.set(player,false,tick)
        rq_restrictions.set(player,true,tick)
        local cancelled=rq_active("admin-tools","restriction-attribution",tick)
        rq_restrictions.set(player,false,tick)
        local cancelled_result=cancelled and rebuild_qc_record(tick,"admin-tools",cancelled.id,false)
        rebuild_qc_check("native census cancellation retained",cancelled_result and cancelled_result.outcome=="cancelled")
        local tesla=ei_runtime_scheduler.peek_rebuilds(tick,"teslas-legacy")
        rebuild_qc_check("Tesla naturally drained",#tesla.active==0)
        local orbital=ei_runtime_scheduler.peek_rebuilds(tick,"orbital-logistics")
        rebuild_qc_check("orbital naturally drained",#orbital.active==0)
        local done=false;for _,record in ipairs(orbital.history) do if record.operation=="rescan" and record.synchronous then done=true end end
        rebuild_qc_check("orbital synchronous result retained",done)
        local ok=true;for _,entry in ipairs(rebuild_qc_checks) do if not entry.ok then ok=false end end
        helpers.write_file("rebuild-qc.json",helpers.table_to_json{all_pass=ok,checks=rebuild_qc_checks,version=script.active_mods.base,
            mode="full-pack-owner-smoke",snapshot=ei_runtime_scheduler.peek_rebuilds(tick),world_chunks=rebuild_qc_native.world_chunks,beacon=ei_beacon_overload.get_debug_status()},false)
    end,
})

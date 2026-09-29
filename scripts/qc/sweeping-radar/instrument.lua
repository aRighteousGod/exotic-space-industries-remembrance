-- Appended to the STAGED ESIR control.lua only, never shipped remote interfaces.
local radar_qc_geometry=require("lib/sweeping-radar-geometry")
local radar_qc_configuration=require("__zzz-esir-radar-qc__/test-config")
if radar_qc_configuration.baseline then ei_sweeping_radar.updater=function() end end
remote.add_interface("esir_radar_qc",{
    settings=function(tick,entity,settings)
        local record=assert(ei_sweeping_radar.get_record(entity),"radar registration missing")
        ei_sweeping_radar.set_settings(record,settings,tick)
    end,
    fill=function(tick,entity)
        local record=assert(ei_sweeping_radar.get_record(entity))
        record.power.energy=record.power.electric_buffer_size
    end,
    trigger=function(tick,entity) ei_sweeping_radar.trigger(assert(ei_sweeping_radar.get_record(entity)),tick) end,
    research_finished=function(tick,research) ei_sweeping_radar.on_research_finished{research=research,tick=tick,by_script=false} end,
    stale_helper_notification=function(tick,entity)
        local record=assert(ei_sweeping_radar.get_record(entity))
        local root=ei_sweeping_radar.get_state()
        local power=record.power
        -- Reproduce an old registration arriving after its replacement helper.
        root.registrations[0]={id=record.id,kind="power"}
        ei_sweeping_radar.on_object_destroyed{registration_number=0,tick=tick}
        return record.power==power and power.valid and root.registrations[0]==nil
    end,
    hold_generation=function(tick,delay) ei_sweeping_radar.get_state().generation_tick=tick+delay end,
    generation_state=function(tick)
        local root=ei_sweeping_radar.get_state()
        local lane=root.lanes.generation
        local order={};local id=lane.cursor
        for _=1,lane.count do order[#order+1]=id;id=lane.nodes[id].next end
        return {order=order,cursor=lane.cursor,deadline=root.generation_tick,jobs=root.jobs,
            paid=root.counters.paid_joules,generated=root.counters.generated}
    end,
    short_pulse_probe=function(tick,entity)
        local record=assert(ei_sweeping_radar.get_record(entity))
        -- Fixture-only cursor placement defers this radar's publication without
        -- altering observations, helpers or the production publication function.
        local root=ei_sweeping_radar.get_state()
        root.cursors.publish=root.indices[record.id]
    end,
    snapshot=function(tick,entity)
        local root=ei_sweeping_radar.get_state()
        local record=entity and ei_sweeping_radar.get_record(entity)
        if not record then return {last=root.last,counters=root.counters,jobs=root.jobs,count=#root.order} end
        return {settings=record.settings,effective=record.effective,status=record.status,ready=record.ready,
            geometry=record.geometry and {phase=record.geometry.phase,count=record.geometry.count,cells=record.geometry.cells,position=record.geometry.position},
            observations=record.observations,passes=record.passes,heading=record.heading,epoch=record.epoch,
            work_count=record.work.count,report_count=record.report.count,report_valid=record.report.valid,report_incomplete=record.report.incomplete,
            report_published=record.report.published_tick,
            output=record.output_values,energy=record.power and record.power.energy,job=record.job~=nil,
            batch=record.batch~=nil,maximum=record.maximum,rate=record.rate,cost=record.cost,
            quality_range=record.quality_range,quality_rate=record.quality_rate,quality_energy=record.quality_energy,
            power=record.power,output_entity=record.output}
    end,
    open=function(tick,player,entity) ei_sweeping_radar_gui.open(player,entity,tick) end,
    close=function(tick,player) ei_sweeping_radar_gui.close(player) end,
    input=function(tick,player,entity)
        game.get_player(player).update_selected_entity(entity.position)
        ei_sweeping_radar_gui.on_open_input{player_index=player,tick=tick}
    end,
    gui_event=function(tick,event) event.tick=tick;ei_sweeping_radar_gui.on_event(event) end,
    gui_controls=function(tick,player) return ei_sweeping_radar.get_state().gui.viewers[player] end,
    paste=function(tick,source,destination) ei_sweeping_radar.on_settings_pasted{source=source,destination=destination,tick=tick} end,
    blueprint=function(tick,player,entity)
        ei_sweeping_radar.on_blueprint{player_index=player,tick=tick,stack=game.get_player(player).cursor_stack,mapping={get=function() return {[1]=entity} end}}
    end,
    robot_upgrade=function(tick,entity,name,quality)
        name=name or "ei-phased-array-radar";quality=quality or entity.quality.name
        entity.order_upgrade{force=entity.force,target={name=name,quality=quality}}
        ei_sweeping_radar.on_marked_for_upgrade{entity=entity,tick=tick}
        local args={name=name,position=entity.position,surface=entity.surface,force=entity.force,quality=quality,raise_built=true}
        ei_sweeping_radar.on_destroyed_entity{entity=entity,tick=tick,name=defines.events.on_robot_mined_entity}
        entity.destroy{raise_destroy=true}
        return args.surface.create_entity(args)
    end,
    pending=function(tick,entity)
        local r=assert(ei_sweeping_radar.get_record(entity))
        return {cursor=r.cursor,epoch=r.epoch,job=r.job,batch=r.batch,next_scan=r.next_scan,fraction=r.interval_fraction,
            observations=r.observations,settings=r.settings,energy=r.power.energy,paid=ei_sweeping_radar.get_state().counters.paid_joules}
    end,
    metrics=function(tick)
        local root=ei_sweeping_radar.get_state()
        local result={last=root.last,jobs=root.jobs,generation_waiters=root.lanes.generation.count,
            counters=root.counters,profiles={},radars={}}
        for _,id in ipairs(root.order) do
            local r=root.records[id]
            local report=ei_sweeping_radar.report_snapshot(r,tick)
            result.radars[#result.radars+1]={id=r.id,observations=r.observations,passes=r.passes,pass_ticks=r.pass_ticks or 0,
                ready_wait=r.running and r.geometry and r.geometry.phase=="ready" and tick-(r.last_observation or r.created_tick) or 0,
                wait=r.job and tick-r.wait_started or 0,age=report.age,sample_age=report.sample_age,
                report_valid=report.valid,status=r.status}
        end
        return result
    end,
    geometry=function(tick,settings,position)
        local build=radar_qc_geometry.new(settings,position)
        while build.phase~="ready" do radar_qc_geometry.step(build) end
        return build.cells
    end,
})

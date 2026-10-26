-- Appended only to an isolated staged mod. Native fluids plus stale persisted topology.
local fluid_qc_owner=require('scripts/control/fluid-safety')
local fluid_qc_alerts=require('lib/alerts')
local fluid_qc_previous=script.get_event_handler(defines.events.on_tick)
script.on_event(defines.events.on_tick,function(event)
    fluid_qc_previous(event)
    if storage.fluid_alert_qc_done then return end
    storage.fluid_alert_qc_done=true
    local checks=0
    local function check(ok,label)
        assert(ok,'FLUID_NATIVE failed: '..label)
        checks=checks+1;log('FLUID_NATIVE PASS '..label)
    end
    local surface=game.create_surface('fluid-alert-qc',{width=128,height=128})
    surface.request_to_generate_chunks({0,0},2);surface.force_generate_chunk_requests()
    local tiles={}
    for x=-48,48 do for y=-48,48 do tiles[#tiles+1]={name='refined-concrete',position={x=x,y=y}} end end
    surface.set_tiles(tiles)
    local runtime=fluid_qc_owner.ensure_fluid_runtime()
    local state=fluid_qc_alerts.channel_state('operational')
    local function reports()
        local n=0
        for _,r in pairs(state.items) do
            if r.surface_index==surface.index or (r.surface and r.surface.index==surface.index) then n=n+r.count end
        end
        return n
    end
    local function pipe(x,y,name,fluid)
        local e=assert(surface.create_entity{name=name or 'pipe',position={x=x,y=y},force='player'})
        if fluid then check(e.insert_fluid{name=fluid,amount=50}>0,'insert '..fluid) end
        fluid_qc_owner.on_fluid_entity_registered(e)
        return e
    end
    for i,name in ipairs{'empty','water','crude-oil','ei-nitrogen-gas','ei-oxygen-gas'} do
        local ordinary=pipe(-40+i*8,-20,nil,name~='empty' and name or nil)
        local detached=pipe(-40+i*8,-10,'ei-insulated-pipe','ei-liquid-nitrogen')
        local id=ordinary.fluidbox.get_fluid_segment_id(1)
        local detached_id=detached.fluidbox.get_fluid_segment_id(1)
        check(id~=detached_id,name..' native networks distinct')
        -- This is the persisted cache left when the representative changes networks
        -- before queued topology repair reaches it. Native fluid state is unmodified.
        runtime.segments[detached_id]=nil
        local entry=runtime.entries_by_unit[detached.unit_number]
        entry.last_segment_id=id
        local segment=runtime.segments[id]
        segment.members[detached.unit_number]=true;segment.member_count=segment.member_count+1
        segment.representative_unit=detached.unit_number
        local before=reports();local vents=runtime.aftermath_stats.light_vent_queued
        fluid_qc_owner.qc.audit(runtime,id,event.tick)
        check(reports()==before and runtime.aftermath_stats.light_vent_queued==vents,name..' no phantom incident or vent')
        check(ordinary.valid and (name=='empty' and ordinary.get_fluid_count()==0 or ordinary.get_fluid_contents()[name]==50),name..' ordinary contents intact')
        check(detached.get_fluid_contents()['ei-liquid-nitrogen']==50,name..' detached liquid intact')
        local context=fluid_qc_owner.qc.context(id,segment,runtime.entries_by_unit[ordinary.unit_number],
            'cryo_nitrogen','ei-liquid-nitrogen',{amount=50,breach_kind='phase-shift',drain_mode='segment',
            replacement_fluid='ei-nitrogen-gas',segment_preserve_excess=false})
        check(not fluid_qc_owner.qc.apply(runtime,id,segment,context,event.tick),name..' stale phase shift rejected')
        check(reports()==before and runtime.aftermath_stats.light_vent_queued==vents,name..' rejected context has no effects')
    end
    for i,liquid in ipairs{'ei-liquid-nitrogen','ei-liquid-oxygen'} do
        local gas=i==1 and 'ei-nitrogen-gas' or 'ei-oxygen-gas'
        local e=pipe(-30+i*25,20,nil,liquid)
        local id=e.fluidbox.get_fluid_segment_id(1);local before=reports()
        fluid_qc_owner.qc.audit(runtime,id,event.tick)
        check(e.valid and e.get_fluid_contents()[gas]==50 and not e.get_fluid_contents()[liquid],liquid..' actual conversion')
        check(reports()==before+1,liquid..' actual incident admitted')
        fluid_qc_owner.qc.audit(runtime,id,event.tick+400)
        check(reports()==before+1,liquid..' gas does not repeat')
    end
    local ordinary=pipe(20,35,nil,'ei-liquid-nitrogen')
    local data=pipe(21,35,'ei-data-pipe')
    check(ordinary.fluidbox.get_fluid_segment_id(1)==data.fluidbox.get_fluid_segment_id(1),'mixed carrier native connection')
    fluid_qc_owner.touch_entity(ordinary)
    local before=reports()
    fluid_qc_owner.qc.audit(runtime,ordinary.fluidbox.get_fluid_segment_id(1),event.tick)
    check(ordinary.valid and not data.valid,'genuine boiloff still destroys incompatible data carrier')
    check(ordinary.get_fluid_count()==0,'destructive path still drains converted gas')
    check(reports()==before+2,'real boiloff and data-carrier failure both reported')
    log('FLUID_NATIVE ALL_COMPLETE '..checks)
end)

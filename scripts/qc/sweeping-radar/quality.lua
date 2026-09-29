-- Functional matrix and power ledger fixture; no profiling or timing benchmark.
local config=require("__exotic-space-industries-remembrance__/lib/sweeping-radar-config")
local tick
local qualities={
    {"normal",0,1,1},{"uncommon",1,1.10,.95},{"rare",2,1.20,.90},
    {"epic",3,1.35,.85},{"legendary",4,1.50,.80},
    {"ei-radar-qc-level4",3,1.425,.825},{"ei-radar-qc-level9",4,1.50,.80},
}
local function call(name,...) return remote.call("esir_radar_qc",name,tick,...) end
local function near(a,b) return math.abs(a-b)<0.01 end
local function check(name,condition,detail)
    storage.tests[#storage.tests+1]={name=name,pass=condition==true,detail=detail}
    if condition~=true then log("Radar quality check failed: "..name.." "..helpers.table_to_json(detail or {})) end
end
local function settings(mode,radius,inner)
    local value=config.defaults();value.run=0;value.mode=mode or 1
    for _,g in pairs(value.modes) do g.radius=radius or 12;g.near=inner or 0 end
    return value
end
local function finish()
    local passed=true
    for _,test in ipairs(storage.tests) do passed=passed and test.pass end
    helpers.write_file("radar-qc.json",helpers.table_to_json({all_pass=passed,tests=storage.tests,
        matrix_cases=#storage.matrix,maximum=storage.maximum}),false)
end
script.on_init(function() storage.pending=true end)
---@param event EventData.on_tick
script.on_event(defines.events.on_tick,function(event)
    tick=event.tick
    if storage.pending then
        storage.pending=nil;storage.started=tick;storage.tests={};storage.matrix={};storage.maximum={}
        local surface=game.create_surface("radar-quality",{autoplace_settings={entity={treat_missing_as_default=false}}})
        surface.request_to_generate_chunks({0,0},4);surface.force_generate_chunk_requests()
        storage.surface=surface;storage.forces={}
        for profile=1,3 do
            local force=game.create_force("radar-quality-"..profile);storage.forces[profile]=force
            for _,branch in ipairs{"range","capacity","efficiency"} do
                for level=1,3 do force.technologies["ei-radar-"..branch.."-"..level].researched=profile==3 or (profile==2 and branch=="capacity") end
            end
            for tier,name in ipairs(config.names) do for _,quality in ipairs(qualities) do
                local index=#storage.matrix
                local entity=surface.create_entity{name=name,quality=quality[1],position={8*(index%8),8*math.floor(index/8)},force=force,raise_built=true}
                call("settings",entity,settings())
                storage.matrix[#storage.matrix+1]={entity=entity,profile=profile,tier=tier,quality=quality}
            end end
        end
        for _,sample in ipairs{{-10,0,1,1},{0.5,0,1.05,.975},{2.5,2,1.275,.875},{4.5,3,1.4625,.8125},{100,4,1.5,.8}} do
            local range,rate,energy=config.quality_effects(sample[1])
            check("quality-interpolation-"..sample[1],range==sample[2] and near(rate,sample[3]) and near(energy,sample[4]))
        end
        return
    end
    local t=tick-storage.started
    local fleet=call("snapshot")
    for name,limit in pairs{control=4,geometry=64,chart=2,query=2,snapshot=258,aggregate=64,maintenance=64,publish=2,generation=1} do
        local value=fleet.last[name] or 0
        storage.maximum[name]=math.max(storage.maximum[name] or 0,value)
        assert(value<=limit,"quality exceeded stage budget: "..name)
    end
    assert(fleet.jobs<=32,"quality exceeded global jobs")
    if storage.far_started and t%5==0 then call("fill",storage.wide) end
    if t==60 then
        for index,row in ipairs(storage.matrix) do
            local entity,q,profile=row.entity,row.quality,row.profile
            local value=call("snapshot",entity)
            local range=({16,24})[row.tier]+(profile==3 and 8 or 0)+q[2]
            local rate=({2,8})[row.tier]*(profile>=2 and 2 or 1)*q[3]
            local cost=({8000000,5000000})[row.tier]*(profile==3 and .7 or 1)*q[4]
            check("matrix-"..index,value.maximum==range and near(value.rate,rate) and near(value.cost,cost),
                {name=entity.name,quality=entity.quality.name,profile=profile,maximum=value.maximum,rate=value.rate,cost=value.cost})
            local hardware=config.hardware[entity.name]
            check("electrical-headroom-"..index,hardware.idle+rate*cost<hardware.input
                and value.power.electric_buffer_size==hardware.buffer and value.power.quality.name=="normal")
            check("native-health-and-empty-copy-"..index,entity.max_health==entity.prototype.get_max_health(entity.quality)
                and entity.max_health>=hardware.health and entity.disabled_by_script and value.energy==0)
            check("quality-keeps-manual-range-"..index,value.settings.modes[1].radius==12)
        end
        local force=storage.forces[3]
        storage.wide=storage.surface.create_entity{name="ei-phased-array-radar",quality="legendary",position={96,16},force=force,raise_built=true}
        call("settings",storage.wide,settings(3,36,35))
        storage.energy=storage.surface.create_entity{name="ei-sweeping-radar",position={96,48},force=storage.forces[1],raise_built=true}
        call("settings",storage.energy,settings(5,1,0))
        call("fill",storage.energy)
    elseif t==90 then
        local wide=call("snapshot",storage.wide)
        check("perimeter-above-32-valid",wide.effective and wide.effective.radius==36 and wide.effective.near==35)
        storage.idle_start=call("snapshot",storage.energy).energy
        storage.idle_paid=fleet.counters.paid_joules
    elseif t==150 then
        local value=call("snapshot",storage.energy)
        check("native-standby-once-while-paused",near(storage.idle_start-value.energy,1000000)
            and fleet.counters.paid_joules==storage.idle_paid,{before=storage.idle_start,after=value.energy})
        local manual=settings(5,36,35);call("settings",storage.wide,manual)
        -- A real isolated network has no source after this point. Its stored
        -- energy must equal native standby plus accepted observation debits.
        storage.energy_start=value.energy;storage.paid_start=fleet.counters.paid_joules
        manual=settings(5,1,0);manual.run=1;call("settings",storage.energy,manual)
    elseif t==210 then
        local wide=call("snapshot",storage.wide)
        check("fixed-above-32-valid",wide.effective and wide.effective.radius==36 and wide.effective.near==35)
        local value=call("snapshot",storage.energy)
        check("accepted-observation-paid-once",fleet.counters.paid_joules-storage.paid_start==8000000
            and near(storage.energy_start-value.energy,1000000+8000000),{energy=value.energy,paid=fleet.counters.paid_joules-storage.paid_start})
        check("starvation-suppresses-output",value.status=="power" and (not value.output or value.output[3]==0))
        local manual=settings(3,36,36);call("settings",storage.wide,manual)
        storage.before_recovery=value.observations;call("fill",storage.energy)
    elseif t==270 then
        check("invalid-inner-radius-pauses",call("snapshot",storage.wide).status=="invalid")
        local value=call("snapshot",storage.energy)
        check("recovery-without-catchup",value.observations>storage.before_recovery and value.observations<=storage.before_recovery+2)
        call("settings",storage.energy,settings(5,1,0))
        call("settings",storage.wide,settings(3,36,35));call("fill",storage.wide)
        local old=storage.wide
        storage.wide=call("robot_upgrade",old,"ei-sweeping-radar","normal")
        check("robot-quality-downgrade-transfer",storage.wide.quality.name=="normal" and call("snapshot",storage.wide).energy==10000000)
    elseif t==310 then
        local wide=call("snapshot",storage.wide)
        check("downgrade-keeps-request-and-pauses-invalid",wide.settings.modes[3].radius==36 and wide.settings.modes[3].near==35
            and wide.maximum==24 and wide.status=="invalid")
        storage.wide=call("robot_upgrade",storage.wide,"ei-phased-array-radar","legendary")
    elseif t==350 then
        local wide=call("snapshot",storage.wide)
        check("quality-upgrade-restores-valid-request",wide.maximum==36 and wide.effective and wide.effective.radius==36 and wide.effective.near==35)
        wide.power.destroy()
    elseif t==380 then
        check("repaired-buffer-empty",call("snapshot",storage.wide).energy==0)
        check("stale-helper-notification-keeps-repair",call("stale_helper_notification",storage.wide))
        -- Trigger both supported research paths independently on already-cached radars.
        local row=storage.matrix[1];storage.research_radar=row.entity
        row.entity.force.technologies["ei-radar-capacity-3"].researched=true
        call("research_finished",row.entity.force.technologies["ei-radar-capacity-3"])
    elseif t==420 then
        check("ordinary-research-refresh",call("snapshot",storage.research_radar).rate==4)
        storage.research_radar.force.technologies["ei-radar-efficiency-3"].researched=true
    elseif t==550 then
        check("scripted-research-refresh",near(call("snapshot",storage.research_radar).cost,5600000))
        local player=game.get_player(1)
        if player then
            player.force=storage.wide.force;player.teleport({96,20},storage.surface)
            player.set_controller{type=defines.controllers.god}
            player.force.unlock_quality("legendary")
            local tiles={}
            for x=109,115 do for y=13,19 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
            storage.surface.set_tiles(tiles)
            local base=storage.surface.create_entity{name="ei-sweeping-radar",position={112,16},force=player.force,raise_built=true}
            call("settings",base,settings(3,24,20))
            call("snapshot",base).power.energy=3000000
            for _,quality in ipairs{"legendary","normal"} do
                local previous_id=base.unit_number
                player.clear_cursor();player.cursor_stack.set_stack{name="ei-sweeping-radar",quality=quality,count=1}
                local can_build=player.can_build_from_cursor{position={112,16}}
                player.build_from_cursor{position={112,16}}
                local replaced=storage.surface.find_entities_filtered{name="ei-sweeping-radar",position={112,16},radius=1}[1]
                local snapshot=call("snapshot",replaced)
                check("player-quality-"..quality,can_build and replaced.unit_number~=previous_id and not base.valid
                    and replaced.quality.name==quality and snapshot.energy==3000000
                    and snapshot.settings.mode==3 and snapshot.settings.modes[3].radius==24
                    and snapshot.settings.modes[3].near==20,{can_build=can_build,quality=replaced.quality.name,
                        energy=snapshot.energy,settings=snapshot.settings})
                base=replaced
            end
            player.clear_cursor()
            call("open",player.index,storage.wide)
            local frame=player.gui.screen.ei_sweeping_radar_gui
            check("capability-readout",frame and frame.body.capabilities and frame.body.capabilities.caption[1]=="sweeping-radar.capabilities")
            local controls=call("gui_controls",player.index);controls.fields.speed.value.text="37"
            frame.body.capabilities.destroy()
            storage.gui_player=player
        end
    elseif t==590 then
        if storage.gui_player then
            local player=storage.gui_player
            check("saved-gui-gains-readout",player.gui.screen.ei_sweeping_radar_gui.body.capabilities~=nil
                and call("gui_controls",player.index).fields.speed.value.text=="37")
            call("close",player.index)
        end
        local radar=storage.wide
        local inside={x=radar.position.x,y=radar.position.y-1136}
        local outside={x=radar.position.x,y=radar.position.y-1168}
        storage.surface.request_to_generate_chunks(inside,1);storage.surface.force_generate_chunk_requests()
        radar.force.chart(storage.surface,{{inside.x-64,inside.y-64},{inside.x+64,inside.y+64}})
        for _,position in ipairs{inside,outside} do
            local target=storage.surface.create_entity{name="gun-turret",position=position,force="enemy"};target.active=false
        end
        local manual=settings(5,36,35);manual.run=1;manual.policy=0
        call("settings",radar,manual);call("fill",radar)
        storage.far_started=true;storage.generated_before=fleet.counters.generated
    elseif t==1050 then
        local wide=call("snapshot",storage.wide)
        check("fixed-detects-beyond-32-excludes-outside-36",wide.report_valid and wide.report_count==1 and wide.observations>0,
            {count=wide.report_count,observations=wide.observations,status=wide.status})
        local manual=settings(3,36,35);manual.run=1;manual.policy=0
        call("settings",storage.wide,manual)
    elseif t==1500 then
        local wide=call("snapshot",storage.wide)
        check("perimeter-detects-beyond-32-excludes-outside-36",wide.report_valid and wide.report_count==1,
            {count=wide.report_count,observations=wide.observations,status=wide.status})
        check("wide-watch-does-not-generate",fleet.counters.generated==storage.generated_before)
        finish()
    end
end)

-- Disposable helper's sole event owner. Bounded cases; no shipping runtime hook.
-- on_load changes only a local flag. Resumption writes storage on the next tick.
local config = require("test-config")
local loaded = false
local ammo_name = "mg-lifecycle-ammo"
local function valid(entity) return entity and entity.valid end

local function remaining(entity)
    local inventory = entity.get_inventory(defines.inventory.turret_ammo)
    local total = 0
    for index=1,#inventory do
        local stack = inventory[index]
        if stack.valid_for_read then total = total + (stack.count-1)*stack.prototype.magazine_size + stack.ammo end
    end
    return total
end

local function snapshot(row, tick)
    local entity = row.entity
    return {tick=tick,age=row.started and tick-row.started or -1,unit_number=entity.unit_number,
        position={entity.position.x,entity.position.y},orientation=entity.orientation,
        energy=entity.energy,ammo=remaining(entity),shots=row.shots,active=entity.active,
        disabled_by_script=entity.disabled_by_script,disabled_by_control_behavior=entity.disabled_by_control_behavior,
        is_freezable=entity.is_freezable,frozen=entity.frozen,epoch=storage.epoch}
end

local function event(row, kind, tick)
    local value = snapshot(row,tick); value.kind = kind
    row.events[#row.events+1] = value
    return value
end

local function capture(row, tick)
    local path = "minigun-lifecycle/"..storage.epoch.."/"..row.id.."/"..tick..".png"
    game.take_screenshot{surface=row.surface,position=row.entity.position,resolution={256,384},zoom=1,
        daytime=0,anti_alias=false,show_gui=false,show_entity_info=false,hide_clouds=true,hide_fog=true,
        force_render=true,path=path}
    local record = snapshot(row,tick);record.path=path;record.zoom=1
    row.captures[#row.captures+1] = record
end

local function target(row, tick)
    if valid(row.target) then row.target.destroy() end
    row.target = row.surface.create_entity{name="mg-lifecycle-target",force="enemy",snap_to_grid=false,
        position={row.entity.position.x+16,row.entity.position.y}}
    assert(row.target,"Failed to create native target")
    row.entity.shooting_target = row.target
    event(row,"acquire",tick)
end

local function lose(row,tick)
    if valid(row.target) then row.target.destroy() end
    event(row,"lose",tick)
end

local function refill(row)
    local inventory = row.entity.get_inventory(defines.inventory.turret_ammo)
    local inserted = inventory.insert{name=ammo_name,count=100}
    row.inserted = row.inserted + inserted*prototypes.item[ammo_name].magazine_size
end

local function power(row)
    row.power = row.surface.create_entity{name="mg-lifecycle-power",force="player",
        position={row.entity.position.x+3,row.entity.position.y-4}}
    assert(row.power,"Failed to restore real electrical supply")
end

local function prepare_surface(heated)
    local map
    if heated then
        local planet = assert(game.planets.aquilo,"Aquilo is required for a native freezing test")
        map = planet.surface or planet.create_surface()
    else
        map = game.surfaces["mg-lifecycle"] or game.create_surface("mg-lifecycle",{autoplace_controls={},
            autoplace_settings={entity={treat_missing_as_default=false}}})
    end
    map.request_to_generate_chunks({0,0},2);map.force_generate_chunk_requests()
    local tiles = {}
    for x=-16,128 do for y=-12,12 do tiles[#tiles+1]={name="refined-concrete",position={x,y}} end end
    map.set_tiles(tiles,true)
    map.freeze_daytime=true;map.daytime=0
    game.forces.player.chart(map,{{-32,-32},{144,32}})
    return map
end

local function spawn(spec,index,tick,variant,x)
    local map=prepare_surface(spec.kind=="freeze_thaw")
    local row={id=spec.id,kind=spec.kind,phase=spec.phase,index=index,variant=variant or "candidate",surface=map,
        spawned=tick,events={},observations={},captures={},shot_ticks={},shots=0,inserted=0,removed=0,damage=0}
    row.entity=map.create_entity{name="mg-lifecycle-"..row.variant,position={x or 0.5,0.5},
        direction=defines.direction.east,force="player"}
    assert(row.entity,"Failed to create lifecycle turret")
    row.entity.orientation=0.25
    row.pole=map.create_entity{name="medium-electric-pole",position={row.entity.position.x+3,0.5},force="player"}
    power(row);refill(row)
    if spec.kind=="freeze_thaw" then
        row.heater=map.create_entity{name="mg-lifecycle-heater",position={row.entity.position.x-4,0.5},force="player"}
        row.heater.set_heat_setting{mode="exactly",temperature=1000}
    elseif spec.kind=="circuit_disable" then
        row.signal=map.create_entity{name="constant-combinator",position={row.entity.position.x+3,3.5},force="player"}
        local behavior=row.signal.get_or_create_control_behavior()
        local section=behavior.get_section(1) or behavior.add_section()
        section.set_slot(1,{value={type="virtual",name="signal-A",quality="normal"},min=1})
        behavior.enabled=true
        local a=row.entity.get_wire_connector(defines.wire_connector_id.circuit_red,true)
        local b=row.signal.get_wire_connector(defines.wire_connector_id.circuit_red,true)
        assert(a and b and a.connect_to(b,true),"Native circuit wire connection failed")
        local control=row.entity.get_or_create_control_behavior()
        control.circuit_enable_disable=true
        control.circuit_condition={first_signal={type="virtual",name="signal-A"},comparator=">",constant=0}
    end
    storage.by_unit[row.entity.unit_number]=row
    return row
end

local function public(row)
    return {id=row.id,kind=row.kind,phase=row.phase,index=row.index,variant=row.variant,spawned=row.spawned,
        started=row.started,finished=row.finished,events=row.events,observations=row.observations,captures=row.captures,
        shots=row.shots,shot_ticks=row.shot_ticks,inserted=row.inserted,removed=row.removed,
        remaining=remaining(row.entity),damage=row.damage,checkpoint=row.checkpoint,
        failures=row.failures or {},resumed=row.resumed or false}
end

local function finish_report(tick)
    local report={schema="esir.minigun.lifecycle-native.v1",engine_version=script.active_mods.base,
        lineage=config.lineage,config=config,epoch=storage.epoch,tick=tick,cases=storage.results,
        errors=storage.errors,prototype_audit=prototypes.mod_data["mg-lifecycle-prototype-audit"].data}
    helpers.write_file("minigun-lifecycle-"..storage.epoch..".json",helpers.table_to_json(report),false)
    storage.done=true
    game.set_wait_for_screenshots_to_finish()
end

local function destroy(row)
    if valid(row.target) then row.target.destroy() end
    for _,key in ipairs({"entity","pole","power","heater","signal"}) do if valid(row[key]) then row[key].destroy() end end
end

local function intervene(row,tick)
    row.command_tick=tick
    event(row,"intervention_command",tick)
    if row.kind=="save_load" then
        local name=config.checkpoint_prefix.."-"..row.phase
        row.checkpoint={name=name,tick=tick,case_id=row.id}
        storage.checkpoint={case_index=row.index,case_id=row.id,phase=row.phase,tick=tick,name=name}
        row.effect_tick=tick
        -- auto_save has no completion callback. The wrapper must locate and
        -- hash the completed ZIP before scheduling a replay of this exact save.
        game.auto_save(name)
    elseif row.kind=="ammo_shortage" then
        row.removed=row.removed+remaining(row.entity)
        row.entity.get_inventory(defines.inventory.turret_ammo).clear()
        row.effect_tick=tick
    elseif row.kind=="energy_shortage" then
        if valid(row.power) then row.power.destroy() end
        row.entity.energy=0 -- drain the buffer once; no scripted refill loop.
        row.effect_tick=tick
    elseif row.kind=="script_disable" then
        row.entity.disabled_by_script=true;row.effect_tick=tick
    elseif row.kind=="circuit_disable" then
        row.signal.get_or_create_control_behavior().enabled=false
    elseif row.kind=="freeze_thaw" then
        row.heater.set_heat_setting{mode="exactly",temperature=0}
    end
end

local function recover(row,tick)
    event(row,"recovery_command",tick);row.recovery_tick=tick
    if row.kind=="ammo_shortage" then refill(row)
    elseif row.kind=="energy_shortage" then power(row)
    elseif row.kind=="script_disable" then row.entity.disabled_by_script=false
    elseif row.kind=="circuit_disable" then row.signal.get_or_create_control_behavior().enabled=true
    elseif row.kind=="freeze_thaw" then row.heater.set_heat_setting{mode="exactly",temperature=1000} end
    target(row,tick)
end

script.on_init(function()
    if remote.interfaces.freeplay then
        remote.call("freeplay","set_skip_intro",true);remote.call("freeplay","set_disable_crashsite",true)
    end
    storage.epoch="baseline";storage.results={};storage.errors={};storage.by_unit={};storage.case_index=0
    storage.started=game.tick -- boundary without event.tick; on_load never reads game.
end)
script.on_load(function() loaded=true end)

script.on_event(defines.events.on_script_trigger_effect,function(e)
    if e.effect_id~="mg-lifecycle-shot" then return end
    local entity=e.source_entity
    local row=valid(entity) and storage.by_unit[entity.unit_number]
    if not row then storage.errors[#storage.errors+1]={tick=e.tick,message="Unattributed native shot"};return end
    row.shots=row.shots+1;row.shot_ticks[#row.shot_ticks+1]=e.tick
end)
script.on_event(defines.events.on_entity_damaged,function(e)
    if e.entity.name~="mg-lifecycle-target" then return end
    for _,row in pairs(storage.by_unit) do
        if valid(row.target) and row.target==e.entity then row.damage=row.damage+e.final_damage_amount;break end
    end
end)

script.on_event(defines.events.on_tick,function(e)
    if storage.done then return end
    if loaded then
        loaded=false
        if storage.checkpoint then
            local checkpoint=storage.checkpoint
            storage.epoch="resume-"..checkpoint.phase
            storage.resume_only=true;storage.results={}
            local row=assert(storage.current,"Checkpoint lost its original case/entity")
            assert(row.id==checkpoint.case_id,"Checkpoint case changed")
            row.resumed=true
            event(row,"resumed_on_tick",e.tick)
            -- Old capture paths remain immutable baseline references. New
            -- images use the resume epoch and can never overwrite those files.
        end
    end
    if not storage.current then
        storage.case_index=storage.case_index+1
        local spec=config.cases[storage.case_index]
        if not spec then
            if not storage.parity then
                storage.parity={spawn({id="combat_parity/candidate",kind="parity",phase="running"},19,e.tick,"candidate",0.5),
                    spawn({id="combat_parity/legacy",kind="parity",phase="running"},20,e.tick,"legacy",96.5)}
            end
            for _,row in ipairs(storage.parity) do
                local age=e.tick-row.spawned
                if age==60 then target(row,e.tick) end
                if age==780 then lose(row,e.tick) end
                if valid(row.target) then row.target.health=1000000000 end
                if remaining(row.entity)<200 then refill(row) end
                if age==120 or age==779 or age==850 then capture(row,e.tick) end
                if age%10==0 then row.observations[#row.observations+1]=snapshot(row,e.tick) end
            end
            if e.tick-storage.parity[1].spawned>=900 then
                for _,row in ipairs(storage.parity) do row.finished=e.tick;storage.results[#storage.results+1]=public(row) end
                finish_report(e.tick)
            end
            return
        end
        storage.current=spawn(spec,storage.case_index,e.tick)
        local player=game.get_player(1)
        if player then player.set_controller{type=defines.controllers.spectator};player.teleport({0,0},storage.current.surface) end
    end
    local row=storage.current
    if not row.started then
        if not row.entity.frozen and row.entity.energy>20000 and not row.entity.disabled_by_control_behavior then
            row.started=e.tick;event(row,"ready",e.tick)
        elseif e.tick-row.spawned>300 then
            row.failures={"Native initial power/heat/circuit readiness timed out"};row.started=e.tick-2000
        else return end
    end
    local age=e.tick-row.started
    local loss=60+config.preparing_ticks+120
    local trigger=row.phase=="preparing" and 60+math.floor(config.preparing_ticks/2)
        or row.phase=="running" and 60+config.preparing_ticks+40
        or loss+config.fold_delay_ticks+math.floor(config.folding_ticks/2)
    if age==60 then target(row,e.tick) end
    if row.phase=="folding" and age==loss then lose(row,e.tick) end
    if valid(row.target) then row.target.health=1000000000 end
    local command=math.max(1,trigger-(row.kind=="freeze_thaw" and config.freeze_lead_ticks or 0))
    if not row.command_tick and age>=command then intervene(row,e.tick) end
    if row.command_tick and not row.effect_tick then
        if (row.kind=="circuit_disable" and row.entity.disabled_by_control_behavior)
            or (row.kind=="freeze_thaw" and row.entity.frozen) then row.effect_tick=e.tick end
    end
    if row.effect_tick and not row.effect_recorded then
        event(row,"effective_interruption",e.tick);row.effect_recorded=true
    end
    if row.effect_tick and not row.recovery_tick and e.tick-row.effect_tick>=90 then recover(row,e.tick) end
    if row.recovery_tick and not row.recovery_effective and not row.entity.frozen
        and not row.entity.disabled_by_control_behavior and not row.entity.disabled_by_script
        and row.entity.energy>2000 and remaining(row.entity)>0 then
        row.recovery_effective=e.tick;event(row,"effective_recovery",e.tick)
    end
    row.observations[#row.observations+1]=snapshot(row,e.tick)
    local near_command=age>=command-3 and age<=command+24
    local waiting_effect=row.command_tick and not row.effect_recorded
    local after_effect=row.effect_tick and e.tick-row.effect_tick<=24
    local near_recovery=row.recovery_tick and e.tick-row.recovery_tick<=config.preparing_ticks+24
    if near_command or waiting_effect or after_effect or near_recovery or age%30==0 then capture(row,e.tick) end
    if (row.recovery_effective and e.tick-row.recovery_effective>=90) or age>=config.maximum_case_ticks then
        if not row.recovery_effective then row.failures={"Native interruption/recovery timed out"} end
        row.finished=e.tick;storage.results[#storage.results+1]=public(row)
        if storage.resume_only then finish_report(e.tick);return end
        storage.by_unit[row.entity.unit_number]=nil;destroy(row);storage.current=nil
    end
end)

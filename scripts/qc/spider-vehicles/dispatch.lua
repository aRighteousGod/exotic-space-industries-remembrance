-- Engine-filter and dormant-work acceptance, separate from fleet combat timing.
local catalog=require("__exotic-space-industries-remembrance__/lib/spider-vehicles")
local config=require("test-config")
local api="exotic-industries-spider-vehicles"
local qc="esir-spider-qc-controls"
local function check(name,pass,detail)
    storage.checks[#storage.checks+1]={name=name,pass=pass==true,detail=detail}
end
local function counts(reset) return remote.call(qc,"dispatch_counts",reset) end
local function setup()
    storage.start=game.tick;storage.checks={}
    local surface=game.create_surface("esir-spider-dispatch",{autoplace_settings={entity={treat_missing_as_default=false,settings={}}}})
    surface.request_to_generate_chunks({0,0},2);surface.force_generate_chunk_requests()
    local tiles={}
    for x=-32,32 do for y=-32,32 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
    surface.set_tiles(tiles)
    local force=game.create_force("esir-spider-dispatch")
    force.technologies[catalog.smoke.technology].researched=true
    force.technologies[catalog.weapon_technology("artillery",1)].researched=true
    remote.call(api,"refresh_force",force)
    local name=catalog.configured_name("assault",catalog.researched_state(force),{cycling=true,special=true},config.smart)
    storage.vehicle=surface.create_entity{name=name,position={0,0},force=force,raise_built=true}
    storage.id=remote.call(api,"get_vehicle_id",storage.vehicle)
    storage.target=surface.create_entity{name="esir-spider-qc-target",position={4,0},force="enemy"}
    storage.target.active=false
    storage.wall=surface.create_entity{name="ei-hemocrystal-wall",position={20,0},force=force,raise_built=true}
    storage.tank=surface.create_entity{name="ei-emerald-apocalypse-hover-tank",position={25,0},force=force,raise_built=true}
end
script.on_event(defines.events.on_tick,function(event)
    if not storage.start then setup() end
    local tick=event.tick-storage.start
    local vehicle=remote.call(qc,"vehicle",storage.id)
    if tick==10 then
        counts(true)
        for i=1,1000 do storage.target.damage(1,vehicle.force,"physical",vehicle) end
        local physical=counts(true)
        check("unrelated-physical-never-enters-dispatch",(physical.damage_dispatch or 0)==0,physical)
        for i=1,1000 do storage.target.damage(1,vehicle.force,"electric",vehicle) end
        local electric=counts(true)
        check("electric-routes-only-to-tesla",electric.damage_dispatch==1000 and electric.tesla_damage==1000 and
            not electric.spider_damage and not electric.tank_damage and not electric.wall_damage,electric)
        storage.wall.damage(10,"enemy","physical",storage.target)
        storage.tank.damage(10,"enemy","physical",storage.target)
        local owned=counts(true)
        check("wall-and-hover-tank-routes-preserved",owned.wall_damage==1 and owned.tank_damage==1 and
            not owned.spider_damage and not owned.tesla_damage,owned)
        for i=1,1000 do vehicle.surface.create_entity{name="esir-spider-qc-dispatch",position={0,15}} end
        local effects=counts(true)
        check("unrelated-effects-skip-spider-including-prefix-collision",effects.effect_dispatch==2000 and not effects.spider_effects,effects)
        vehicle.get_inventory(defines.inventory.spider_trunk).insert{name=catalog.smoke.charge,count=2}
        vehicle.damage(vehicle.max_health*0.2,"enemy","physical",storage.target)
        check("reactive-smoke-still-consumes-charge",vehicle.get_inventory(defines.inventory.spider_trunk).get_item_count(catalog.smoke.charge)==1)
        check("reactive-smoke-still-slows-enemy",#(storage.target.stickers or {})>0)
        local smoke=counts(true)
        check("spider-damage-routes-only-to-spider",smoke.spider_damage==1 and not smoke.tesla_damage and not smoke.wall_damage and not smoke.tank_damage,smoke)
        local cargo=vehicle.get_inventory(defines.inventory.spider_trunk)
        cargo.clear()
        for i=1,#cargo do cargo[i].set_stack{name="iron-plate",count=100} end
        vehicle.get_inventory(defines.inventory.spider_ammo)[4].set_stack{name="artillery-shell",count=1}
        vehicle.vehicle_automatic_targeting_parameters={auto_target_with_gunner=false,auto_target_without_gunner=false}
        remote.call(api,"set_weapon_controls",vehicle,{special=false})
    elseif tick==15 then
        local scheduled=remote.call(qc,"scheduled_work")
        storage.retry_tick=next(scheduled.retries)
        storage.pulse_tick=next(scheduled.pulses)
        check("full-cargo-refit-defers",storage.retry_tick~=nil)
        check("smoke-next-pulse-scheduled",storage.pulse_tick==storage.start+70)
        counts(true)
    elseif tick==69 then
        local idle=counts(true)
        check("native-future-buckets-do-not-wake-updater",config.smart or not idle.updaters,idle)
    elseif tick==70 then
        local pulse=counts(true)
        check("scheduled-smoke-wakes-updater",(pulse.updaters or 0)==1,pulse)
        vehicle.get_inventory(defines.inventory.spider_trunk).clear()
    elseif storage.retry_tick and event.tick==storage.retry_tick+2 then
        local controls=remote.call(api,"get_weapon_controls",vehicle)
        check("scheduled-retry-finishes-refit",not controls.pending and #vehicle.get_inventory(defines.inventory.spider_ammo)==3,controls)
        check("removed-mount-ammunition-retained",vehicle.get_inventory(defines.inventory.spider_trunk).get_item_count("artillery-shell")==1)
    elseif tick==400 then
        check("delayed-smoke-pulses-finish",next(remote.call(qc,"scheduled_work").pulses)==nil)
        check("smoke-eventually-expires",#(storage.target.stickers or {})==0)
        counts(true)
    elseif tick==620 then
        local status=remote.call(api,"get_status")
        local dormant=counts()
        check("native-no-selector-or-prediction-work",config.smart or (status.selector_searches==0 and status.selector_samples==0 and
            status.overkill.samples==0 and not dormant.spider_effects and not dormant.updaters),dormant)
        local all=true
        for _,entry in ipairs(storage.checks) do all=all and entry.pass end
        helpers.write_file("spider-vehicles-qc.json",helpers.table_to_json({all_pass=all,checks=storage.checks,status=status}),false)
    end
end)

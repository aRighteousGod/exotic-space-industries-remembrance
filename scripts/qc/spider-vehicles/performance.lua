-- Profile only ESIR's spider module after setup/registration, separately from
-- Factorio's native combat and this helper's acquisition measurements.
local catalog=require("__exotic-space-industries-remembrance__/lib/spider-vehicles")
local config=require("test-config")
local api="exotic-industries-spider-vehicles"
local function remaining(stack)
    if not stack.valid_for_read then return 0 end
    return (stack.count-1)*stack.prototype.magazine_size+stack.ammo
end
script.on_init(function()
    local force=game.create_force("esir-spider-performance")
    for _,branch in ipairs(catalog.branch_order) do
        for level=1,#catalog.upgrade_names[branch] do force.technologies[catalog.weapon_technology(branch,level)].researched=true end
    end
    remote.call(api,"refresh_force",force)
    local surface=game.create_surface("esir-spider-performance",{autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false,settings={}}}})
    surface.request_to_generate_chunks({100,100},5);surface.force_generate_chunk_requests()
    local tiles={}
    for x=-10,220 do for y=-10,220 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
    surface.set_tiles(tiles)
    storage.perf={start=game.tick,vehicles={},first_fire={},initial={}}
    local name=catalog.configured_name("assault",catalog.researched_state(force),{cycling=true,special=true},config.smart)
    for index=1,config.performance do
        local entity=surface.create_entity{name=name,position={((index-1)%25)*8,math.floor((index-1)/25)*8},force=force,raise_built=true}
        entity.vehicle_automatic_targeting_parameters={auto_target_with_gunner=true,auto_target_without_gunner=true}
        entity.selected_gun_index=4
        local inventory=entity.get_inventory(defines.inventory.spider_ammo)
        local initial={}
        for slot,ammo in ipairs({"cannon-shell","firearm-magazine","flamethrower-ammo","artillery-shell"}) do
            inventory[slot].set_stack{name=ammo,count=100};initial[slot]=remaining(inventory[slot])
        end
        remote.call(api,"set_weapon_controls",entity,{cycling=true})
        storage.perf.vehicles[index]=entity;storage.perf.initial[index]=initial
    end
end)
script.on_event(defines.events.on_tick,function(event)
    local state=storage.perf
    local tick=event.tick-state.start
    if tick==300 and config.combat then
        for _,entity in ipairs(state.vehicles) do
            local target=entity.surface.create_entity{name="esir-spider-qc-target",position={entity.position.x+3,entity.position.y+3},force="enemy"}
            target.active=false
        end
    end
    if config.combat and tick>300 and tick<=620 then
        for index,entity in ipairs(state.vehicles) do
            if not state.first_fire[index] then
                local inventory=entity.get_inventory(defines.inventory.spider_ammo)
                for slot=1,#inventory do
                    if remaining(inventory[slot])<state.initial[index][slot] then state.first_fire[index]=tick-300;break end
                end
            end
        end
    end
    if tick==400 then
        state.before=remote.call(api,"get_status")
        remote.call("esir-spider-qc-controls","start_profile")
    elseif tick==620 then
        local status=remote.call(api,"get_status")
        local count,total,maximum=0,0,0
        for _,latency in pairs(state.first_fire) do count=count+1;total=total+latency;maximum=math.max(maximum,latency) end
        local checks={
            {name="performance-no-runtime-errors",pass=status.failures==0},
            {name="performance-search-budget",pass=status.selector_max_searches_per_tick<=8},
            {name="performance-native-no-selector",pass=config.smart or (status.selector_searches==0 and status.selector_samples==0)},
            {name="performance-acquisition",pass=not config.smart or not config.combat or count==config.performance},
        }
        local all=true
        for _,check in ipairs(checks) do all=all and check.pass end
        local report={all_pass=all,checks=checks,status=status,performance={vehicles=config.performance,combat=config.combat,smart=config.smart,
            measurement_ticks=220,profile=remote.call("esir-spider-qc-controls","profile"),searches=status.selector_searches-state.before.selector_searches,
            samples=status.selector_samples-state.before.selector_samples,acquired=count,mean_acquisition_ticks=count>0 and total/count or 0,max_acquisition_ticks=maximum}}
        helpers.write_file("spider-vehicles-qc.json",helpers.table_to_json(report),false)
        log("SPIDER_PERFORMANCE "..helpers.table_to_json(report))
    end
end)

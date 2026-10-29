local case=require("case")
local model={}
local function check(value,label)
    storage.transition_checks=(storage.transition_checks or 0)+1
    assert(value,"QUALITY POLICY TRANSITION: "..label)
end
local function allowed(selection,family)return selection=="both" or selection==family end
local function key(stack)return stack.name.."/"..stack.quality.name end
local function counts(surface,installed_only)
    local totals={}
    for _,entity in ipairs(surface.find_entities_filtered{type="beacon"}) do
        local inv=entity.get_module_inventory()
        for i=1,#inv do if inv[i].valid_for_read then local k=key(inv[i]);totals[k]=(totals[k] or 0)+inv[i].count end end
    end
    for _,entity in ipairs(installed_only and {} or surface.find_entities_filtered{type="item-entity"}) do
        local k=key(entity.stack);totals[k]=(totals[k] or 0)+entity.stack.count
    end
    return totals
end
local function serial(value)return serpent.line(value,{comment=false,sortkeys=true}) end
local function save(name,report)
    helpers.write_file(name..".json",helpers.table_to_json(report),false)
    if game.is_multiplayer() then game.server_save(name) else game.auto_save(name) end
end
local function seed_beacons()
    local surface=game.create_surface("quality-policy-donor",{width=512,height=256})
    surface.request_to_generate_chunks({0,0},5);surface.force_generate_chunk_requests()
    for _,entity in pairs(surface.find_entities()) do entity.destroy() end
    storage.policy_surface=surface;storage.policy_beacons={}
    for i,name in ipairs({"ei-copper-beacon","ei-iron-beacon","ei-alien-beacon","ei-warp-beacon"}) do
        local entity=assert(surface.create_entity{name=name,position={-80+(i-1)*50,-70},force="player",raise_built=true})
        local inv=entity.get_module_inventory()
        for _,stack in ipairs({{name="quality-module",quality="uncommon",count=1},
            {name="productivity-module",quality="normal",count=1},{name="esir-qc-mixed-module",quality="rare",count=1},
            {name="speed-module",quality="normal",count=1}}) do
            check(inv.insert(stack)==1,"donor module insertion")
        end
        local meta=assert(remote.call("nonstandard-beacons","get-beacon-data",entity.unit_number))
        local source=meta.source
        if source.burner then source.get_fuel_inventory().insert{name="ei-bio-matter",count=20}
        else source.set_fluid(1,{name="ei-liquid-nitrogen",amount=100,temperature=25}) end
        storage.policy_beacons[i]={entity=entity,source=source,manager=meta.manager,family=i<=2 and "nitrogen" or "alien"}
    end
    storage.policy_totals=counts(surface)
end
function model.configuration(event)
    if not storage.transition_seeded then return end
    storage.configuration_count=(storage.configuration_count or 0)+1
    storage.transition_complete=nil
    storage.config_seen=true
    if case.phase=="removed" then
        check(event.mod_changes.quality~=nil,"real Quality removal event")
        storage.removal_immediate=remote.call("esir-quality-removal-qc","immediate",game.tick)
        storage.normal_immediate=remote.call("esir-quality-removal-qc","normal_immediate")
        helpers.write_file("quality-removal-immediate.json",helpers.table_to_json{
            passed=true,case=case,selectors_and_caches=storage.removal_immediate,paid_work=storage.normal_immediate},false)
    elseif case.phase=="eject" then
        check(event.mod_startup_settings_changed,"real startup policy transition")
        for _,row in ipairs(storage.policy_beacons) do
            local inv=row.entity.get_module_inventory()
            for i=1,#inv do
                if inv[i].valid_for_read then
                    local effect=inv[i].prototype.module_effects
                    check(allowed(case.quality_permission,row.family) or (effect.quality or 0)<=0,"retained quality permission")
                    check(allowed(case.productivity_permission,row.family) or (effect.productivity or 0)<=0,"retained productivity permission")
                end
            end
            local expected={["quality-module"]=allowed(case.quality_permission,row.family) and 1 or 0,
                ["productivity-module"]=allowed(case.productivity_permission,row.family) and 1 or 0,
                ["esir-qc-mixed-module"]=allowed(case.quality_permission,row.family) and allowed(case.productivity_permission,row.family) and 1 or 0,
                ["speed-module"]=1}
            for name,count in pairs(expected) do
                local quality=name=="quality-module" and "uncommon" or name=="esir-qc-mixed-module" and "rare" or "normal"
                if count>0 and row.module_counts then count=row.module_counts[name] end
                check(inv.get_item_count{name=name,quality=quality}==count,row.entity.name.."/"..name)
            end
            local meta=remote.call("nonstandard-beacons","get-beacon-data",row.entity.unit_number)
            check(meta.source==row.source and meta.source.valid,"source identity preserved")
        end
        check(serial(counts(storage.policy_surface))==serial(storage.policy_totals),"exact module and quality conservation")
    elseif case.phase=="relax" then
        check(event.mod_startup_settings_changed,"real permission relaxation")
        check(serial(counts(storage.policy_surface,true))==serial(storage.policy_installed),"relaxation leaves installed modules unchanged")
    end
    storage.transition_started=game.tick
end
function model.tick(event)
    local age=event.tick-storage.started
    if case.phase=="duplicates" and not storage.duplicates_saved then
        storage.duplicates_saved=true
        local stacks={{name="quality-module",quality="uncommon",count=1},
            {name="productivity-module",quality="normal",count=1},{name="esir-qc-mixed-module",quality="rare",count=1}}
        for _,row in ipairs(storage.policy_beacons) do
            local inv=row.entity.get_module_inventory()
            for i=1,#inv do inv.insert(stacks[(i-1)%#stacks+1]) end
            check(inv.is_full(),"all beacon slots populated")
            row.module_counts={}
            for i=1,#inv do local stack=inv[i];row.module_counts[stack.name]=(row.module_counts[stack.name] or 0)+stack.count end
        end
        storage.policy_totals=counts(storage.policy_surface)
        save(case.id,{passed=true,case=case,totals=storage.policy_totals})
    elseif case.phase=="legacy" and not storage.legacy_saved then
        storage.legacy_saved=true
        remote.call("esir-quality-removal-qc","clear_beacon_policy")
        save(case.id,{passed=true,case=case})
    elseif case.phase=="normal" then
        if not storage.normal_started then
            storage.normal_started=true
            remote.call("esir-quality-removal-qc","normal_setup",event.tick)
        end
        remote.call("esir-quality-removal-qc","normal_step",event.tick)
        if age>=1550 and not storage.normal_complete then
            storage.normal_complete=true
            helpers.write_file(case.id..".json",helpers.table_to_json(remote.call("esir-quality-removal-qc","normal_finish")),false)
        end
    elseif case.phase=="player" then
        if game.get_player(1) and not storage.player_saved then
            storage.player_saved=true
            save("quality-player",{passed=true,player=1})
        end
    elseif case.phase=="donor" then
        if not storage.policy_surface then
            storage.started=event.tick-1;age=1
            seed_beacons();remote.call("esir-quality-removal-qc","normal_setup",event.tick)
            if game.get_player(1) then save("quality-donor-start",{passed=true}) end
        end
        if age>=1 then remote.call("esir-quality-removal-qc","normal_step",event.tick) end
        if not storage.transition_seeded and game.get_player(1) and age>=180 then
            storage.transition_seeded=true
            storage.removal_seed=remote.call("esir-quality-removal-qc","seed",storage.policy_surface.index,1,event.tick)
            save("quality-donor",{passed=true,checks=storage.transition_checks,seed=storage.removal_seed})
        end
    elseif storage.transition_started and event.tick>=storage.transition_started+(case.phase=="removed" and 1500 or 180) and not storage.transition_complete then
        check(storage.config_seen,"configuration callback ran")
        local report={passed=true,checks=storage.transition_checks,case=case,immediate=storage.removal_immediate}
        if case.phase=="removed" then
            report.settled=remote.call("esir-quality-removal-qc","settled")
            report.normal=remote.call("esir-quality-removal-qc","normal_finish")
            -- Removed content has native engine handling; subsequent reloads
            -- compare the surviving factory rather than resurrect removed items.
            storage.policy_totals=counts(storage.policy_surface)
        else check(serial(counts(storage.policy_surface))==serial(storage.policy_totals),"post-tick conservation") end
        storage.policy_installed=counts(storage.policy_surface,true)
        storage.saved_configuration_count=storage.configuration_count or 0
        storage.transition_complete=true
        save(case.id,report)
    elseif case.phase=="reload" and not storage.reload_reported then
        check((storage.configuration_count or 0)==(storage.saved_configuration_count or 0),"ordinary reload has no configuration callback")
        check(serial(counts(storage.policy_surface))==serial(storage.policy_totals),"unchanged reload conservation")
        storage.reload_reported=true
        save(case.id,{passed=true,checks=storage.transition_checks,case=case})
    end
    if case.phase=="removed" and storage.transition_started then remote.call("esir-quality-removal-qc","normal_step",event.tick) end
end
return model

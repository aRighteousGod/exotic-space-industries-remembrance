-- Real-engine overkill checks. Only this disposable helper registers events.
local catalog=require("__exotic-space-industries-remembrance__/lib/spider-vehicles")
local config=require("test-config")
local api="exotic-industries-spider-vehicles"
local qc="esir-spider-qc-controls"
local function check(name,pass,detail)
    storage.checks[#storage.checks+1]={name=name,pass=pass==true,detail=detail}
end
local function controls(c) return remote.call(api,"get_weapon_controls",c.entity) end
local function snapshot(c) return remote.call(qc,"snapshot",c.entity) end
local function setup()
    storage.start=game.tick;storage.checks={};storage.cases={};storage.by_unit={};storage.by_target={}
    local surface=game.create_surface("esir-overkill-qc",{autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false,settings={}}}})
    local force=game.create_force("esir-overkill-qc")
    for _,branch in ipairs({"doeworks","artillery"}) do
        for i=1,#catalog.upgrade_names[branch] do force.technologies[catalog.weapon_technology(branch,i)].researched=true end
    end
    local cases={
        {name="artillery-rocket-off",family="rocket",slot=5,ammo="dw-deer-ammo-basic",range=100,off=true},
        {name="artillery-rocket-on",family="rocket",slot=5,ammo="dw-deer-ammo-basic",range=100},
        {name="ordinary-rocket",family="rocket",slot=1,ammo="rocket",range=30},
        {name="cannon",family="assault",slot=1,ammo="cannon-shell",range=25},
        {name="artillery",family="assault",slot=4,ammo="artillery-shell",range=70},
        {name="disable-held",family="rocket",slot=5,ammo="dw-deer-ammo-basic",range=100,disable=true},
        {name="moving-held",family="rocket",slot=5,ammo="dw-deer-ammo-basic",range=100,moving=true},
        {name="moving-target",family="rocket",slot=5,ammo="dw-deer-ammo-basic",range=100,moving_target=true},
        {name="quality-bonus",family="rocket",slot=1,ammo="rocket",range=30,quality="legendary",health=100000},
        {name="resistant",family="rocket",slot=5,ammo="dw-deer-ammo-basic",range=100,target="behemoth-biter",health=2000},
        {name="overlapping-targets",family="rocket",slot=5,ammo="dw-deer-ammo-basic",range=100,second=true},
        {name="different-range",family="rocket",slot=5,ammo="dw-deer-ammo-basic",range=100,close=true},
        {name="lost-impact",family="rocket",slot=1,ammo="rocket",range=30,lost=true},
        {name="hold-mode",family="rocket",slot=5,ammo="dw-deer-ammo-basic",range=100,hold_mode=true},
        {name="manual",family="rocket",slot=5,ammo="dw-deer-ammo-basic",range=100,manual=true},
        {name="regeneration",family="rocket",slot=5,ammo="dw-deer-ammo-basic",range=100,regenerate=true},
        {name="target-destroyed",family="rocket",slot=5,ammo="dw-deer-ammo-basic",range=100,destroy_target=true},
        {name="equipment-laser",family="rocket",slot=1,ammo="rocket",range=10,laser=true,health=1000},
        {name="empty-ammunition",family="rocket",slot=5,ammo="dw-deer-ammo-basic",range=100,empty=true},
        {name="unsupported-ammunition",family="assault",slot=4,ammo="esir-spider-qc-partial-artillery",range=70,unsupported=true,health=100000},
        {name="bounded-alternative-probes",family="assault",slot=1,ammo="cannon-shell",range=10,lost=true,probes=true},
        {name="mining-held",family="rocket",slot=5,ammo="dw-deer-ammo-basic",range=100,mine=true},
        {name="cloning-held",family="rocket",slot=5,ammo="dw-deer-ammo-basic",range=100,clone=true},
        {name="threshold-covered",family="rocket",slot=1,ammo="rocket",range=30,health=1020,threshold=1},
        {name="threshold-not-covered",family="rocket",slot=1,ammo="rocket",range=30,health=1022,threshold=2},
        {name="last-round",family="rocket",slot=1,ammo="rocket",range=30,count=1},
        {name="repeated-resisted-impact",family="rocket",slot=1,ammo="esir-spider-qc-repeated-ammo",range=30,target="esir-spider-qc-resistant",health=100000,exact=true},
        {name="native-targeting-change",family="rocket",slot=5,ammo="dw-deer-ammo-basic",range=100,native_change=true},
        {name="ambiguous-mixed-impacts",family="rocket",slot=5,ammo="dw-deer-ammo-basic",range=100,health=100000,mixed=true},
    }
    for i,c in ipairs(cases) do
        local y=i*256
        surface.request_to_generate_chunks({40,y},2);surface.force_generate_chunk_requests()
        local tiles={};for x=-10,115 do for dy=-10,10 do tiles[#tiles+1]={name="grass-1",position={x,y+dy}} end end;surface.set_tiles(tiles)
        local name=catalog.configured_name(c.family,catalog.researched_state(force),{cycling=not c.hold_mode,special=true},config.smart)
        c.entity=surface.create_entity{name=name,position={0,y},force=force}
        c.entity.selected_gun_index=c.slot
        c.entity.get_inventory(defines.inventory.spider_ammo)[c.slot].set_stack{name=c.ammo,count=c.count or 100,quality=c.quality or "normal"}
        c.entity.get_inventory(defines.inventory.fuel).insert{name="coal",count=20}
        c.target=surface.create_entity{name=c.target or "esir-spider-qc-target",position={c.range,y},force="enemy"}
        c.target.active=false;c.target.health=c.health or 500
        c.initial_health=c.target.health;c.shots=0;c.holds=0;c.damage=0;c.launch_ticks={};c.held_ticks=0
        c.initial_ammo=(c.count or 100)*c.entity.get_inventory(defines.inventory.spider_ammo)[c.slot].prototype.magazine_size
        if c.empty then c.entity.get_inventory(defines.inventory.spider_ammo)[c.slot].clear();c.initial_ammo=0 end
        if c.laser then c.equipment=c.entity.grid.put{name="personal-laser-defense-equipment",position={0,0}};c.equipment.energy=1000000 end
        if c.second or c.close or c.probes then
            c.other=surface.create_entity{name="esir-spider-qc-target",position={c.close and 25 or (c.probes and 11 or c.range+8),y},force="enemy"}
            c.other.active=false;c.other.health=500
            if c.close then c.entity.get_inventory(defines.inventory.spider_ammo)[1].set_stack{name="rocket",count=100} end
            if c.probes then
                c.entity.get_inventory(defines.inventory.spider_ammo)[2].set_stack{name="firearm-magazine",count=100}
                c.entity.get_inventory(defines.inventory.spider_ammo)[3].set_stack{name="flamethrower-ammo",count=100}
                c.probe_shots={mg=0,flamer=0}
            end
        end
        local defaults=controls(c)
        check(c.name.."-default-off",defaults.overkill==false)
        remote.call(api,"set_weapon_controls",c.entity,{overkill=not c.off,cycling=not c.hold_mode})
        c.entity.vehicle_automatic_targeting_parameters={auto_target_with_gunner=not (c.mine or c.clone),auto_target_without_gunner=true}
        storage.cases[#storage.cases+1]=c;storage.by_unit[c.entity.unit_number]=c;storage.by_target[c.target.unit_number]=c
    end
    force.set_ammo_damage_modifier("rocket",0.75)
end
script.on_event(defines.events.on_script_trigger_effect,function(e)
    if e.effect_id:sub(1,#catalog.overkill.launch)~=catalog.overkill.launch then return end
    local source=e.cause_entity or e.source_entity
    local c=source and source.valid and storage.by_unit and storage.by_unit[source.unit_number]
    if not c then return end
    c.shots=c.shots+1;c.launch_ticks[#c.launch_ticks+1]=e.tick-storage.start
    if c.probes and e.tick-storage.start<290 then
        local group=catalog.slot_group(c.family,c.entity.selected_gun_index)
        if c.probe_shots[group] then c.probe_shots[group]=c.probe_shots[group]+1 end
    end
    local state=snapshot(c)
    if state.overkill and not c.first_prediction and #state.overkill.shots>0 then c.first_prediction=state.overkill.shots[#state.overkill.shots].damage end
    if c.mixed then
        local stack=c.entity.get_inventory(defines.inventory.spider_ammo)[c.slot]
        if c.shots==1 then stack.set_stack{name=c.ammo,count=100,quality="legendary"} else stack.clear() end
    end
    if c.lost then
        for _,projectile in ipairs(source.surface.find_entities_filtered{position=source.position,radius=8,type="projectile"}) do projectile.destroy() end
    end
end)
script.on_event(defines.events.on_entity_damaged,function(e)
    local c=storage.by_target and storage.by_target[e.entity.unit_number]
    if c then
        c.damage=c.damage+e.final_damage_amount
        if not c.first_impact_tick then c.before_impact_shots=c.shots end
        c.first_impact_tick=c.first_impact_tick or e.tick
        if c.first_impact_tick==e.tick then c.first_impact_damage=(c.first_impact_damage or 0)+e.final_damage_amount end
        if c.laser and e.damage_type.name=="laser" and controls(c).holding_fire then c.laser_during_hold=true end
    end
end)
script.on_event(defines.events.on_tick,function(e)
    if not storage.start then setup() end
    local tick=e.tick-storage.start
    for _,c in ipairs(storage.cases) do
        if c.entity.valid then
            if c.equipment and c.equipment.valid then c.equipment.energy=1000000 end
            if not config.smart then
                local stack=c.entity.get_inventory(defines.inventory.spider_ammo)[c.slot]
                c.shots=c.initial_ammo-(stack.valid_for_read and ((stack.count-1)*stack.prototype.magazine_size+stack.ammo) or 0)
            end
            local state=controls(c)
            if state.holding_fire then
                c.held_ticks=c.held_ticks+1
                if not c.was_held then c.holds=c.holds+1 end
                if c.disable and not c.disabled then
                    c.disabled=true;remote.call(api,"set_weapon_controls",c.entity,{overkill=false})
                    check("disable-restores-auto-targeting",not controls(c).holding_fire and c.entity.vehicle_automatic_targeting_parameters.auto_target_without_gunner)
                elseif c.moving and not c.moved then
                    c.moved=true;c.entity.autopilot_destination={x=10,y=c.entity.position.y}
                elseif c.moving_target and not c.moved then
                    c.moved=true;c.target.teleport({x=95,y=c.target.position.y+7})
                elseif c.regenerate and not c.regenerated then
                    c.regenerated=true;c.target.health=2000
                elseif c.native_change and not c.native_changed then
                    c.native_changed=tick
                    c.entity.vehicle_automatic_targeting_parameters={auto_target_with_gunner=true,auto_target_without_gunner=false}
                elseif c.destroy_target and not c.destroyed then
                    c.destroyed=tick;c.target.destroy()
                elseif c.manual and not c.manual_started and game.players[1] then
                    local player=game.players[1]
                    player.force=c.entity.force;player.teleport(c.entity.position,c.entity.surface)
                    if not player.character then player.set_controller{type=defines.controllers.god};player.create_character() end
                    c.entity.set_driver(player);c.entity.driver_is_gunner=true
                    player.shooting_state={state=defines.shooting.shooting_enemies,position=c.target.position}
                    c.manual_started=tick;c.player=player
                elseif c.clone and not c.cloned then
                    c.cloned=c.entity.clone{position={-10,c.entity.position.y},surface=c.entity.surface}
                    local targeting=c.cloned.vehicle_automatic_targeting_parameters
                    check("held-clone-restores-requested-targeting",not targeting.auto_target_with_gunner and targeting.auto_target_without_gunner)
                    check("held-clone-preference",remote.call(api,"get_weapon_controls",c.cloned).overkill)
                    c.cloned.destroy()
                elseif c.mine and not c.mined and tick>=35 and game.players[1] then
                    local player=game.players[1]
                    player.driving=false;player.force=c.entity.force
                    player.teleport(c.entity.position,c.entity.surface)
                    player.clear_cursor();player.get_main_inventory().clear()
                    c.rebuild_surface=c.entity.surface;c.rebuild_position={x=-5,y=c.entity.position.y}
                    check("held-player-mining",player.mine_entity(c.entity,true))
                    c.mined=true
                    local inventory=player.get_main_inventory()
                    for index=1,#inventory do
                        local item=inventory[index]
                        if item.valid_for_read and item.type=="item-with-entity-data" and item.prototype.place_result and catalog.family(item.prototype.place_result.name)=="rocket" then
                            player.cursor_stack.transfer_stack(item);player.build_from_cursor{position=c.rebuild_position};break
                        end
                    end
                end
            end
            c.was_held=state.holding_fire
            if c.manual_started and tick==c.manual_started+2 then check("manual-releases-hold",not controls(c).holding_fire) end
            if c.destroyed and tick==c.destroyed+2 then check("destroyed-target-releases-hold",not controls(c).holding_fire) end
            if c.native_changed and tick==c.native_changed+2 then
                local targeting=c.entity.vehicle_automatic_targeting_parameters
                check("native-targeting-change-releases-hold",not controls(c).holding_fire and targeting.auto_target_with_gunner and not targeting.auto_target_without_gunner)
            end
            if c.manual_started and tick==c.manual_started+15 then
                c.player.shooting_state={state=defines.shooting.not_shooting,position=c.entity.position}
                c.entity.set_driver(nil)
            end
            if tick==50 and c.entity.valid then c.early=snapshot(c) end
            if c.mixed and config.smart and tick==250 then
                local pending=snapshot(c).overkill
                c.ambiguous_retained=pending and #pending.shots==2
            elseif c.mixed and config.smart and tick==350 then c.ambiguous_expired=snapshot(c).overkill==nil end
        end
    end
    if tick==620 then
        local results={}
        for _,c in ipairs(storage.cases) do
            local dead=not c.target.valid
            check(c.name.."-fired",c.empty and c.shots==0 or (not c.empty and c.shots>0),c.shots)
            if config.smart and not c.off and not c.hold_mode and not c.empty and not c.unsupported then
                check(c.name.."-predicted",c.first_prediction~=nil,c.first_prediction)
                if c.health~=100000 then check(c.name.."-held",c.held_ticks>0,c.held_ticks) end
            else check(c.name.."-no-hold",c.held_ticks==0,c.held_ticks) end
            if c.moving and config.smart then check("movement-preserved",c.entity.position.x>1,c.entity.position.x) end
            if c.lost and not c.probes and config.smart then check("lost-impact-expires-and-resumes",c.shots>=2 and c.shots<=4,c.launch_ticks) end
            if c.probes and config.smart then
                for group,count in pairs(c.probe_shots) do check("bounded-"..group.."-probe",count==1,count) end
            end
            if c.mine and config.smart then
                local entity=c.rebuild_surface and c.rebuild_surface.find_entities_filtered{type="spider-vehicle",position=c.rebuild_position,radius=1}[1]
                local current=entity and remote.call(api,"get_weapon_controls",entity)
                check("held-rebuild-preference",current and current.overkill)
                -- Disable the new vehicle's overlay before inspecting its native flags.
                if entity then remote.call(api,"set_weapon_controls",entity,{overkill=false}) end
                local targeting=entity and entity.vehicle_automatic_targeting_parameters
                check("held-rebuild-restores-requested-targeting",targeting and not targeting.auto_target_with_gunner and targeting.auto_target_without_gunner)
            end
            if c.close and config.smart then check("alternate-range-target",not c.other.valid) end
            if c.regenerate and config.smart then check("regeneration-resumes-fire",c.shots>=3,c.shots) end
            if c.laser and config.smart then check("equipment-laser-during-hold",c.laser_during_hold==true) end
            if c.threshold and config.smart then check(c.name.."-120-percent",c.before_impact_shots==c.threshold,c.before_impact_shots) end
            if c.exact and config.smart then check("repeated-resistance-matches-engine",c.first_impact_damage and math.abs(c.first_prediction-c.first_impact_damage)<0.0001,{actual=c.first_impact_damage,predicted=c.first_prediction}) end
            if c.mixed and config.smart then check("ambiguous-impacts-use-safety-expiry",c.shots==2 and c.ambiguous_retained and c.ambiguous_expired) end
            if c.unsupported then check("unknown-ammunition-fails-open",not c.first_prediction and not controls(c).holding_fire) end
            if c.quality and config.smart then
                check("quality-and-force-damage",math.abs(c.first_prediction-700*prototypes.quality.legendary.default_multiplier*1.75)<0.1,c.first_prediction)
                check("quality-prediction-matches-engine",c.first_impact_damage and math.abs(c.first_impact_damage-c.first_prediction)<0.1,{actual=c.first_impact_damage,predicted=c.first_prediction})
            end
            results[#results+1]={name=c.name,shots=c.shots,holds=c.holds,held_ticks=c.held_ticks,dead=dead,predicted=c.first_prediction,damage=c.damage,early=c.early}
        end
        local off,on=storage.cases[1],storage.cases[2]
        if config.smart then check("artillery-rocket-ammunition-savings",on.shots<off.shots/3,{on=on.shots,off=off.shots}) end
        local status=remote.call(api,"get_status")
        check("bounded-searches",status.selector_max_searches_per_tick<=8)
        check("no-replacement-failures",status.failures==0)
        if not config.smart then check("native-no-selector-or-prediction",status.selector_samples==0 and status.selector_searches==0 and status.overkill.samples==0 and status.overkill.reserved==0) end
        local all=true;for _,result in ipairs(storage.checks) do all=all and result.pass end
        helpers.write_file("spider-vehicles-qc.json",helpers.table_to_json({all_pass=all,checks=storage.checks,status=status,overkill=results}),false)
        log("SPIDER_OVERKILL ALL_PASS="..tostring(all))
    end
end)

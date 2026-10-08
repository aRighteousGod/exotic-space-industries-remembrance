-- Factorio 2.0.77 fixture: native payment, twin channels and native lifecycle checks.
local config=require("test-config")
local tracking_regression=require("tracking_regression")
if config.regression then tracking_regression.register(config);return end
local v2=require("v2")
local voice_qc=require("voice_qc")
local timing_qc=require("timing_qc")
local coverage_qc=require("coverage_qc")
local VEHICLE="ei-anisetron"
local AMMO="ei-anisetron-crystal-charge"
local TARGET="anisetron-qc-target"
-- Observe the helper transition; shipping ESIR retains its own central route.
script.on_configuration_changed(function(event)
    storage.native_configuration_receipt={tick=game.tick,mods=event.mod_changes,settings=event.mod_startup_settings_changed}
end)
script.on_event(defines.events.on_entity_cloned,voice_qc.on_cloned)
script.on_event(defines.events.script_raised_teleported,coverage_qc.on_teleported)
local function health0(entity) return storage.target_health[entity.unit_number] end
local function request1(entity)
    local sections=entity.get_logistic_sections()
    for i=1,sections.sections_count do
        local slot=sections.get_section(i).get_slot(1)
        if slot.value and slot.value.name==AMMO then return slot end
    end
    return {}
end
local function check(name,pass,detail)
    storage.results[name]={pass=pass==true,detail=detail}
end
local function report()
    local all=true;local count=0
    for _,result in pairs(storage.results) do count=count+1;if not result.pass then all=false end end
    helpers.write_file("anisetron-qc.json",helpers.table_to_json{all_pass=all,count=count,complete=storage.complete==true,profile=config.timing and "timing" or config.visual and "visual" or (config.save or config.loaded) and "persistence" or "native",fixture_version=2,fidelity=settings.startup["ei-anisetron-visual-fidelity"].value,channel_view=config.isolate or "all",contract={duration_ticks=1200,contact_ticks=12,range=30,crown=320,facade=160,directions=128},mechanics=v2.mechanics_metadata(),cases=storage.results},false)
end
local function rounds(entity)
    local stack=entity.get_inventory(defines.inventory.spider_ammo)[1]
    return stack.valid_for_read and (stack.count-1)*stack.prototype.magazine_size+stack.ammo or 0
end
local function total_charges(entity)
    return rounds(entity)+entity.get_inventory(defines.inventory.spider_trunk).get_item_count(AMMO)
        +entity.get_inventory(defines.inventory.spider_trash).get_item_count(AMMO)
end
local function vehicle(surface,pos,ammo,automatic,quality)
    local entity=surface.create_entity{name=VEHICLE,position=pos,force=storage.force,quality=quality or "normal",raise_built=true}
    entity.vehicle_automatic_targeting_parameters={auto_target_with_gunner=automatic,auto_target_without_gunner=automatic}
    entity.orientation=0;entity.torso_orientation=0
    if ammo then entity.get_inventory(defines.inventory.spider_ammo)[1].set_stack{name=AMMO,count=ammo,ammo=1} end
    return entity
end
local function target(surface,pos,force)
    local entity=surface.create_entity{name=TARGET,position=pos,force=force or "enemy"}
    storage.target_health[entity.unit_number]=entity.health
    entity.active=false;return entity
end
local function power(surface,pos)
    local port=surface.create_entity{name="roboport",position=pos,force=storage.force}
    port.energy=100000000
    surface.create_entity{name="substation",position={pos[1]-5,pos[2]},force=storage.force}
    surface.create_entity{name="anisetron-qc-source",position={pos[1]-6,pos[2]-2},force=storage.force}
    return port
end
local function setup(tick)
    storage.started=tick;storage.results={};storage.target_health={};storage.damage_events={};storage.source_damage={}
    local surface=game.create_surface("anisetron-qc",{width=640,height=512,
        autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
    surface.request_to_generate_chunks({0,0},10);surface.force_generate_chunk_requests()
    for _,entity in pairs(surface.find_entities()) do entity.destroy() end
    surface.destroy_decoratives{}
    for _,entity in pairs(surface.find_entities_filtered{type={"unit","unit-spawner","turret","tree"}}) do entity.destroy() end
    local tiles={}
    for x=-220,200 do for y=-120,180 do tiles[#tiles+1]={name="lab-dark-1",position={x,y}} end end
    surface.set_tiles(tiles);surface.always_day=true;storage.surface=surface
    storage.force=game.create_force("anisetron-qc-player")
    local player=assert(game.get_player(1),"Use a copied player seed")
    if player.controller_type==defines.controllers.remote then player.exit_remote_view() end
    player.driving=false;player.force=storage.force;player.teleport({-90,0},surface)
    if not (player.character and player.character.valid) then
        local character=surface.create_entity{name="character",position={-90,0},force=storage.force}
        player.set_controller{type=defines.controllers.character,character=character}
    end
    assert(player.character and player.character.valid,"Player seed needs a physical character")
    for _,id in ipairs{defines.inventory.character_armor,defines.inventory.character_guns,defines.inventory.character_ammo} do player.get_inventory(id).clear() end
    storage.player=player.index
    local force=storage.force
    force.character_logistic_requests=true;force.vehicle_logistics=true
    for _,name in ipairs{"logistic-robotics","construction-robotics","character-logistic-requests"} do
        if force.technologies[name] then force.technologies[name].researched=true end
    end
    force.worker_robots_speed_modifier=10
    storage.auto=vehicle(surface,{-180,0},1,true)
    storage.auto_target=target(surface,{-180,-20})
    storage.manual=vehicle(surface,{-90,0},1,false)
    storage.manual_target=target(surface,{-90,-20})
    storage.neighbor=surface.create_entity{name="anisetron-qc-bystander",position={-90,-10},force="enemy"}
    storage.neighbor_health=storage.neighbor.health
    check("beam-line-bystander-is-non-military",not storage.neighbor.is_military_target)
    storage.friend=target(surface,{-89,-18},force)
    storage.manual.set_driver(player);storage.manual.driver_is_gunner=true
    storage.mobile=vehicle(surface,{-180,80},1,true)
    storage.mobile_target=target(surface,{-180,60})
    storage.mobile.autopilot_destination={-130,80}
    storage.switcher=vehicle(surface,{0,-90},1,true)
    storage.switch_target=target(surface,{0,-110})
    storage.cease_force=game.create_force("anisetron-qc-hostile")
    storage.cease=vehicle(surface,{80,-90},1,true)
    storage.cease_target=target(surface,{80,-110},storage.cease_force)
    storage.remove_source=vehicle(surface,{-90,-90},1,true)
    storage.remove_target=target(surface,{-90,-110})
    storage.speed=vehicle(surface,{-180,155},nil,false)
    storage.saucer=surface.create_entity{name="ei-gaian-saucer",position={-180,130},force=force}
    storage.speed.autopilot_destination={170,155};storage.saucer.autopilot_destination={170,130}
    storage.turn_start={storage.speed.torso_orientation,storage.saucer.torso_orientation}
    storage.speed_equipped=vehicle(surface,{-180,145},nil,false)
    storage.saucer_equipped=surface.create_entity{name="ei-gaian-saucer",position={-180,140},force=force}
    for _,e in ipairs{storage.speed_equipped,storage.saucer_equipped} do
        e.grid.put{name="battery-equipment",position={0,0}}.energy=2000000
        e.grid.put{name="exoskeleton-equipment",position={0,2}}
        e.autopilot_destination={170,e.position.y}
    end
    storage.variants={};storage.variant_start={}
    for i,speed in ipairs{.02,.04,.06,.1,.5} do
        local e=surface.create_entity{name=VEHICLE.."-speed-"..i,position={-180,95+i*6},force=force}
        e.autopilot_destination={170,95+i*6};storage.variants[i]=e
    end
    storage.travel={}
    for i,y in ipairs{-80,-40,0,40} do
        local e=vehicle(surface,{40,y},nil,false);e.autopilot_destination={100,y};storage.travel[i]=e
    end
    local water={}
    for x=62,72 do for y=-84,-76 do water[#water+1]={name="water",position={x,y}} end end
    surface.set_tiles(water)
    storage.cliff=surface.create_entity{name="cliff",position={68,-40},cliff_orientation="north-to-south"}
    for y=-4,4 do surface.create_entity{name="stone-wall",position={68,y},force=force} end
    storage.rail=surface.create_entity{name="elevated-straight-rail",position={68,40},direction=defines.direction.north,force=force}
    local port=power(surface,{150,0})
    port.get_inventory(defines.inventory.roboport_robot).insert{name="logistic-robot",count=4}
    local provider=surface.create_entity{name="passive-provider-chest",position={155,0},force=force}
    storage.provider=provider
    storage.supply=vehicle(surface,{160,0},nil,true)
    storage.supply.get_inventory(defines.inventory.spider_ammo)[1].set_stack{name=AMMO,quality="rare",count=1}
    storage.supply_target=target(surface,{160,-20})
    storage.supply_request=storage.supply.get_logistic_sections().add_section("Crystal supply")
    storage.supply_point=storage.supply.get_logistic_point(defines.logistic_member_index.spidertron_requester)
    storage.supply_point.enabled=false
    storage.cold=vehicle(surface,{173,12},nil,true)
    storage.cold_target=target(surface,{188,12})
    storage.cold.orientation=.25;storage.cold.torso_orientation=.25
    storage.cold.get_logistic_sections().add_section("Cold start").set_slot(1,
        {value={name=AMMO,quality="normal",comparator="="},min=3,max=3})
    storage.port=port
    local robot_port=power(surface,{150,80})
    robot_port.get_inventory(defines.inventory.roboport_robot).insert{name="construction-robot",count=4}
    storage.robot_chest=surface.create_entity{name="storage-chest",position={155,80},force=force}
    storage.robot_port=robot_port
    storage.arc=vehicle(surface,{-180,-90},1,true)
    storage.arc_targets={target(surface,{-195,-110}),target(surface,{-180,-110}),target(surface,{-165,-110})}
    storage.arc_behind=target(surface,{-180,-70})
    storage.arc_sequence={}
    storage.quality=vehicle(surface,{0,80},nil,true)
    storage.quality.get_inventory(defines.inventory.spider_ammo)[1].set_stack{name=AMMO,quality="rare",count=1}
    storage.quality_target=target(surface,{0,60})
    storage.retrigger=vehicle(surface,{75,125},2,true)
    storage.retrigger_target=target(surface,{75,105})
    storage.retrigger_packets=0
    storage.rear_only=vehicle(surface,{-50,125},1,true)
    storage.rear_target=target(surface,{-50,145})
    storage.reserve=vehicle(surface,{-50,0},2,true)
    storage.reserve_target=target(surface,{-50,-20})
    storage.reserve_packets=0
    storage.rare_vehicle=vehicle(surface,{-50,80},1,true,"rare")
    storage.rare_vehicle_target=target(surface,{-50,60})
    storage.rare_vehicle_packets=0;storage.rare_vehicle_exact=true
    storage.collinear=vehicle(surface,{-20,-45},1,true)
    storage.collinear_targets={target(surface,{-20,-60}),target(surface,{-20,-65}),target(surface,{-20,-70})}
    storage.collinear_sequence={}
    check("standalone-native-chassis",storage.auto.type=="spider-vehicle" and storage.auto.grid.prototype.name==VEHICLE.."-equipment-grid")
    check("native-hidden-leg-chassis",#storage.auto.get_spider_legs()==(config.ten_leg_trial and 10 or 4))
    check("remote-selection",pcall(function() player.spidertron_remote_selection={storage.auto} end)
        and player.spidertron_remote_selection[1]==storage.auto)
    check("obstacles-created",storage.cliff~=nil and storage.rail~=nil)
    storage.poses={}
    if config.visual then
        local visual=game.create_surface("anisetron-visual",{autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
        visual.request_to_generate_chunks({0,0},5);visual.force_generate_chunk_requests()
        visual.set_tiles(tiles);visual.always_day=false;visual.freeze_daytime=true
        storage.visual=visual
        for i=0,7 do
            local x,y=-180+(i%4)*100,-90+math.floor(i/4)*100
            local e=vehicle(visual,{x,y},100,true)
            local angle=i/8*math.pi*2
            target(visual,{x+math.sin(angle)*20,y-math.cos(angle)*20})
            e.color={r=i%2,g=(i+1)%2,b=.3,a=1}
            storage.poses[#storage.poses+1]=e
        end
    end
end
script.on_event(defines.events.on_entity_damaged,function(event)
    local channel=v2.observe_damage(event)
    if event.entity==storage.mobile_target and storage.mobile.speed>0 then storage.mobile_damage_moving=true end
    if event.entity==storage.auto_target or event.entity==storage.manual_target then
        local id=event.entity.unit_number
        local hits=storage.damage_events[id] or {count=0,total=0,exact=true,crown=0,facade=0}
        hits.count=hits.count+1;hits.total=hits.total+event.final_damage_amount
        hits.exact=hits.exact and (event.final_damage_amount==320 or event.final_damage_amount==160)
        if channel=="crown" then hits.crown=hits.crown+1 end
        if channel=="facade" then hits.facade=hits.facade+1 end
        storage.damage_events[id]=hits
    end
    for i,entity in ipairs(storage.arc_targets or {}) do
        if event.entity==entity and event.cause==storage.arc and channel=="crown" then
            storage.arc_sequence[#storage.arc_sequence+1]=i
        elseif event.entity==entity and event.cause==storage.arc and channel=="facade" then
            storage.arc_facade_sequence=storage.arc_facade_sequence or {}
            storage.arc_facade_sequence[#storage.arc_facade_sequence+1]=i
        end
    end
    if event.entity==storage.arc_behind and event.cause==storage.arc and channel=="crown" then
        storage.arc_sequence[#storage.arc_sequence+1]=4
    end
    for i,entity in ipairs(storage.collinear_targets or {}) do
        if event.entity==entity and event.cause==storage.collinear then
            if channel=="crown" then storage.collinear_sequence[#storage.collinear_sequence+1]=i end
            if channel=="facade" then
                storage.collinear_facade_sequence=storage.collinear_facade_sequence or {}
                storage.collinear_facade_sequence[#storage.collinear_facade_sequence+1]=i
            end
        end
    end
    if event.entity==storage.quality_target then
        storage.quality_packets=(storage.quality_packets or 0)+1
        storage.quality_exact=(storage.quality_exact~=false) and
            (math.abs(event.final_damage_amount-512)<.001 or math.abs(event.final_damage_amount-256)<.001)
    end
    if event.entity==storage.retrigger_target then storage.retrigger_packets=storage.retrigger_packets+1 end
    if event.entity==storage.reserve_target then storage.reserve_packets=storage.reserve_packets+1 end
    if event.entity==storage.rare_vehicle_target then
        storage.rare_vehicle_packets=storage.rare_vehicle_packets+1
        storage.rare_vehicle_exact=storage.rare_vehicle_exact and
            (event.final_damage_amount==320 or event.final_damage_amount==160)
    end
    if event.entity==storage.persistence_target then
        storage.persistence_packets=(storage.persistence_packets or 0)+1
    end
end)
script.on_event(defines.events.on_script_trigger_effect,function(event)
    if event.effect_id~="ei-anisetron-charge" then return end
    local source=event.source_entity
    if not(source and source.valid and source.name==VEHICLE) then source=event.cause_entity end
    if source and source.valid then
        storage.openers=storage.openers or {}
        local id=source.unit_number
        local record=storage.openers[id] or {count=0}
        record.count=record.count+1;record.first=record.first or event.tick
        record.last=event.tick;record.quality=event.quality or "normal"
        record.ticks=record.ticks or {};record.ticks[#record.ticks+1]=event.tick
        record.remaining_rounds=record.remaining_rounds or {};record.remaining_rounds[#record.remaining_rounds+1]=rounds(source)
        record.opening_target=event.target_entity and event.target_entity.valid and event.target_entity.unit_number or nil
        if config.legacy then v2.mark_paid_legacy(source) end
        storage.openers[id]=record
        if config.timing then timing_qc.after_payment(event,check) end
        if source==storage.reserve then
            source.vehicle_automatic_targeting_parameters={auto_target_with_gunner=false,auto_target_without_gunner=false}
        end
    end
end)
script.on_event(defines.events.on_robot_mined_entity,function(event)
    if event.entity==storage.robot_source then
        storage.robot_mined=true
        local item=event.buffer[1]
        check("robot-public-quality-item",item.valid_for_read and item.name==VEHICLE and item.quality.name=="rare")
        local eq=item.grid and item.grid.equipment[1]
        check("robot-mined-equipment",eq and eq.quality.name=="rare" and eq.energy==7654321 and eq.position.x==0 and eq.position.y==0)
    end
end)
script.on_event(defines.events.on_robot_built_entity,function(event)
    if event.entity.name==VEHICLE and event.entity.surface==storage.surface and math.abs(event.entity.position.x-160)<1 and math.abs(event.entity.position.y-80)<1 then storage.robot_built=event.entity end
    if event.entity.name==VEHICLE and event.entity.surface==storage.surface and math.abs(event.entity.position.x-165)<1 and math.abs(event.entity.position.y-105)<1 then storage.ghost_rebuilt=event.entity end
end)
local function mining()
    local player=game.get_player(storage.player)
    storage.manual.set_driver(nil);player.shooting_state={state=defines.shooting.not_shooting,position={0,0}}
    player.teleport({-91,50},storage.surface);player.get_main_inventory().clear();player.clear_cursor()
    local entity=vehicle(storage.surface,{-90,50},37,false,"rare")
    entity.entity_label="Procession remembers"
    entity.color={r=.2,g=.4,b=.8,a=1}
    local original_color=entity.color
    entity.get_inventory(defines.inventory.spider_trunk).insert{name="iron-plate",count=17}
    local battery=entity.grid.put{name="battery-equipment",quality="rare",position={entity.grid.width-2,entity.grid.height-2}}
    battery.energy=1234567
    entity.get_logistic_sections().add_section("Remember charges").set_slot(1,
        {value={name=AMMO,quality="normal",comparator="="},min=1,max=1})
    check("player-native-mine",player.mine_entity(entity,false))
    local item
    for i=1,#player.get_main_inventory() do local s=player.get_main_inventory()[i];if s.valid_for_read and s.name==VEHICLE then item=s end end
    check("public-item-quality-grid",item and item.quality.name=="rare" and item.grid and #item.grid.equipment==1)
    assert(item,"Native mining did not produce cathedral item")
    player.cursor_stack.transfer_stack(item);player.build_from_cursor{position={-82,50}}
    local rebuilt=storage.surface.find_entities_filtered{name=VEHICLE,position={-82,50},radius=1}[1]
    check("player-native-build",rebuilt~=nil and not player.cursor_stack.valid_for_read)
    if rebuilt then
        rebuilt.vehicle_automatic_targeting_parameters={auto_target_with_gunner=false,auto_target_without_gunner=false}
        rebuilt.active=false
        local equip=rebuilt.grid.equipment[1]
        check("equipment-quality-charge-position",equip and equip.quality.name=="rare" and equip.energy==1234567
            and equip.position.x==rebuilt.grid.width-2 and equip.position.y==rebuilt.grid.height-2)
        local recovered=0
        for i=1,#player.get_main_inventory() do local s=player.get_main_inventory()[i];if s.valid_for_read and s.name==AMMO then recovered=recovered+(s.count-1)*s.prototype.magazine_size+s.ammo end end
        check("native-cargo-ammo-no-loss",player.get_main_inventory().get_item_count("iron-plate")==17 and recovered==37,{rounds=recovered})
        check("item-label-preserved",rebuilt.entity_label=="Procession remembers")
        check("item-owner-color-preserved",math.abs(rebuilt.color.r-original_color.r)<.00001 and math.abs(rebuilt.color.g-original_color.g)<.00001 and math.abs(rebuilt.color.b-original_color.b)<.00001)
        local request=request1(rebuilt)
        check("logistic-filter-preserved",request.value and request.value.name==AMMO and request.value.quality=="normal" and request.min==1 and request.max==1,request)
        -- Explicit setup for persistence; native mining returned these to player.
        rebuilt.get_inventory(defines.inventory.spider_ammo)[1].set_stack{name=AMMO,count=37,ammo=1}
        rebuilt.get_inventory(defines.inventory.spider_trunk).insert{name="iron-plate",count=17}
        storage.rebuilt=rebuilt
    end
end

local function fingerprint(entity)
    local eq=entity.grid.equipment[1]
    local slot=request1(entity)
    local destination=entity.autopilot_destinations[1]
    return {quality=entity.quality.name,label=entity.entity_label,color=entity.color,
        rounds=total_charges(entity),cargo=entity.get_inventory(defines.inventory.spider_trunk).get_item_count("iron-plate"),
        equipment={name=eq.name,quality=eq.quality.name,energy=eq.energy,x=eq.position.x,y=eq.position.y},
        request={name=slot.value.name,quality=slot.value.quality,min=slot.min,max=slot.max},
        destination={x=destination.x,y=destination.y}}
end

local function same(left,right)
    if type(left)~=type(right) then return false end
    if type(left)~="table" then return left==right end
    for key,value in pairs(left) do if not same(value,right[key]) then return false end end
    for key in pairs(right) do if left[key]==nil then return false end end
    return true
end

local function persistence_setup(tick)
    storage.started=tick;storage.results={};storage.target_health={};storage.source_damage={}
    storage.force=game.create_force("anisetron-qc-persistence")
    storage.force.character_logistic_requests=true;storage.force.vehicle_logistics=true
    for _,name in ipairs{"logistic-robotics","construction-robotics","character-logistic-requests"} do
        if storage.force.technologies[name] then storage.force.technologies[name].researched=true end
    end
    local surface=game.create_surface("anisetron-persistence",{autoplace_controls={}})
    surface.request_to_generate_chunks({0,0},2);surface.force_generate_chunk_requests()
    local entity=vehicle(surface,{0,0},37,false,"rare")
    entity.active=false;entity.entity_label="Procession remembers"
    entity.color={r=.2,g=.4,b=.8,a=1}
    entity.get_inventory(defines.inventory.spider_trunk).insert{name="iron-plate",count=17}
    local eq=entity.grid.put{name="battery-equipment",quality="rare",position={10,6}};eq.energy=1234567
    entity.get_logistic_sections().add_section("Remember charges").set_slot(1,
        {value={name=AMMO,quality="normal",comparator="="},min=1,max=1})
    entity.autopilot_destination={30,40};storage.rebuilt=entity
    storage.snapshot=fingerprint(entity);storage.persisted=true
    storage.persistence_source=vehicle(surface,{100,0},nil,true)
    storage.persistence_source.get_inventory(defines.inventory.spider_ammo)[1].set_stack{
        name=AMMO,quality=(config.legacy or config.timing) and "normal" or "rare",
        count=config.timing and 3 or config.legacy and 2 or 1}
    storage.persistence_target=target(surface,{100,-20})
    storage.native_identity={rebuilt=entity.unit_number,paid=storage.persistence_source.unit_number,
        before_legs=#entity.get_spider_legs()}
    check("save-fingerprint-prepared",storage.snapshot.rounds==37 and storage.snapshot.cargo==17)
end

local function visual_setup(tick)
    storage.started=tick;storage.results={};storage.target_health={};storage.poses={};storage.source_damage={}
    storage.force=game.create_force("anisetron-art-qc")
    local surface=game.create_surface("anisetron-art",{autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
    surface.request_to_generate_chunks({0,0},10);surface.force_generate_chunk_requests()
    for _,entity in pairs(surface.find_entities()) do entity.destroy() end
    surface.destroy_decoratives{}
    local tiles={}
    for x=-220,200 do for y=-120,180 do tiles[#tiles+1]={name="lab-dark-1",position={x,y}} end end
    surface.set_tiles(tiles);surface.always_day=false;surface.freeze_daytime=true
    storage.visual=surface
    for i=0,7 do
        local x,y=-180+(i%4)*100,-90+math.floor(i/4)*100
        local e=vehicle(surface,{x,y},1,true)
        e.orientation=i/8;e.torso_orientation=i/8
        local angle=i/8*math.pi*2
        target(surface,{x+math.sin(angle)*20,y-math.cos(angle)*20})
        e.color={r=i%2,g=(i+1)%2,b=.3,a=1}
        storage.poses[#storage.poses+1]=e
    end
    storage.arc_art=vehicle(surface,{80,80},1,true)
    storage.arc_art.orientation=.5;storage.arc_art.torso_orientation=.5
    for _,x in ipairs{65,80,95} do target(surface,{x,100}) end
    storage.turn_art=vehicle(surface,{-180,-30},1,true)
    storage.turn_art.autopilot_destination={-130,-30}
    storage.turn_art_target=target(surface,{-160,-50})
    storage.turn_art_poses={}
    storage.extra_turns={}
    for _,pose in ipairs{{name="counterclockwise",x=-80,heading=.5,y=-10},{name="north-wrap",x=20,heading=.95,y=-50}} do
        local e=vehicle(surface,{pose.x,-30},1,true)
        e.orientation=pose.heading;e.torso_orientation=pose.heading
        e.autopilot_destination={pose.x+50,-30}
        storage.extra_turns[#storage.extra_turns+1]={entity=e,name=pose.name,
            target=target(surface,{pose.x+20,pose.y}),poses={}}
    end
end

local function visual_tick(tick)
    if not storage.started then visual_setup(tick) end
    local t=tick-storage.started
    if t==47 then
        -- Keep the naturally fractional torso: orientation setters quantize it.
        storage.turn_art.active=false
        storage.turn_art.autopilot_destination=nil
    elseif t==51 then
        local e=storage.turn_art
        game.take_screenshot{surface=storage.visual,position={e.position.x,e.position.y-5},resolution={768,768},zoom=1,
            path="anisetron-art/turn/frozen.png",show_gui=false,show_entity_info=false,
            daytime=0,anti_alias=true,force_render=true}
        local pose=v2.visual_pose_metadata(e)
        pose.target=storage.turn_art_target.position;pose.active=e.active
        helpers.write_file("anisetron-art/turn/frozen.json",helpers.table_to_json(pose),false)
    elseif t==60 or t==70 or t==80 then
        local e=storage.turn_art
        e.active=false
        e.orientation=t==60 and .195 or t==70 and .202 or .007
        e.torso_orientation=e.orientation
    elseif t==65 or t==75 or t==85 then
        local e=storage.turn_art
        game.take_screenshot{surface=storage.visual,position={e.position.x,e.position.y-5},resolution={768,768},zoom=1,
            path="anisetron-art/turn/static-"..t..".png",show_gui=false,show_entity_info=false,
            daytime=0,anti_alias=true,force_render=true}
        local pose=v2.visual_pose_metadata(e)
        pose.target=storage.turn_art_target.position;pose.active=e.active
        helpers.write_file("anisetron-art/turn/static-"..t..".json",helpers.table_to_json(pose),false)
    end
    if t>=12 and t<=45 and t%3==0 then
        local e=storage.turn_art
        local frame=(t-12)/3+1
        game.take_screenshot{surface=storage.visual,position={e.position.x,e.position.y-5},resolution={768,768},zoom=1,
            path=string.format("anisetron-art/turn/%03d.png",frame),show_gui=false,show_entity_info=false,
            daytime=0,anti_alias=true,force_render=true}
        storage.turn_art_poses[frame]=v2.visual_pose_metadata(e)
        storage.turn_art_poses[frame].target=storage.turn_art_target.position
        if frame==12 then helpers.write_file("anisetron-art/turn/poses.json",helpers.table_to_json(storage.turn_art_poses),false) end
        for _,pose in ipairs(storage.extra_turns) do
            local vehicle=pose.entity
            game.take_screenshot{surface=storage.visual,position={vehicle.position.x,vehicle.position.y-5},resolution={768,768},zoom=1,
                path=string.format("anisetron-art/%s/%03d.png",pose.name,frame),show_gui=false,show_entity_info=false,
                daytime=0,anti_alias=true,force_render=true}
            pose.poses[frame]=v2.visual_pose_metadata(vehicle)
            pose.poses[frame].target=pose.target.position
            if frame==12 then helpers.write_file("anisetron-art/"..pose.name.."/poses.json",helpers.table_to_json(pose.poses),false) end
        end
    end
    if t>=180 and t<=226 and t%2==0 then
        game.take_screenshot{surface=storage.visual,position={80,84},resolution={1024,1024},zoom=.6,
            path=string.format("anisetron-art/strafe/%03d.png",(t-180)/2+1),
            show_gui=false,show_entity_info=false,daytime=0,anti_alias=true,force_render=true}
    end
    if t==180 or t==220 then
        local poses={}
        for i,e in ipairs(storage.poses) do
            game.take_screenshot{surface=storage.visual,position={e.position.x,e.position.y-5},resolution={768,768},zoom=1,
                path="anisetron-art/pose-"..(i-1)..(t==180 and "-day.png" or "-night.png"),
                show_gui=false,show_entity_info=false,daytime=t==180 and 0 or 0.5,anti_alias=true,force_render=true}
            poses[i]=v2.visual_pose_metadata(e)
        end
        helpers.write_file("anisetron-art/poses-"..t..".json",helpers.table_to_json(poses),false)
    elseif t==240 then
        for i,e in ipairs(storage.poses) do
            check("native-heading-"..(i-1),math.abs(e.torso_orientation-(i-1)/8)<.02,{orientation=e.torso_orientation})
        end
        -- The v2 ring and move/turn/stop captures finish at 650, then report.
    end
end

script.on_event(defines.events.on_tick,function(event)
    if config.visual then visual_tick(event.tick);v2.visual_tick(event,check,report,vehicle,target);return end
    if config.timing then
        if not storage.started then persistence_setup(event.tick) end
        timing_qc.tick(event,check)
        v2.timing_tick(event,check,report,health0,rounds)
        return
    end
    if config.legacy or config.historical_legacy then
        if not storage.started then persistence_setup(event.tick) end
        v2.legacy_tick(event,check,report,health0,rounds)
        return
    end
    if config.loaded then
        assert(storage.persisted and storage.snapshot,"Resume requires the ANISETRON transition fixture")
        if not storage.reload_checked then
            local e=storage.rebuilt
            local current=e and e.valid and fingerprint(e)
            check("save-reload-native-state",current and same(current,storage.snapshot),current)
            local expected_legs=config.ten_leg_trial and 10 or 4
            check("save-reload-native-leg-count",#e.get_spider_legs()==expected_legs
                and #storage.persistence_source.get_spider_legs()==expected_legs)
            local native_legs=0
            for _,body in pairs(e.surface.find_entities_filtered{name=VEHICLE}) do native_legs=native_legs+#body.get_spider_legs() end
            check("save-reload-no-orphaned-legs",e.surface.count_entities_filtered{name=VEHICLE.."-leg"}==native_legs,native_legs)
            if storage.native_identity then
                check("save-reload-body-identity",e.unit_number==storage.native_identity.rebuilt
                    and storage.persistence_source.unit_number==storage.native_identity.paid,storage.native_identity)
                if storage.native_identity.before_legs~=expected_legs then
                    local receipt=storage.native_configuration_receipt
                    check("configuration-transition-observed",receipt and receipt.tick>=event.tick-1,receipt)
                end
            end
            storage.reload_checked=true;storage.resume_tick=event.tick
            v2.resume_started(event,check)
        end
        if event.tick-storage.resume_tick==1250 then
            local opener=storage.openers[storage.persistence_source.unit_number]
            check("active-burst-save-reload",storage.persistence_packets==200 and opener.count==1
                and v2.channels_complete(storage.persistence_source,100)
                and rounds(storage.persistence_source)==0
                and health0(storage.persistence_target)-storage.persistence_target.health==100*(storage.paid_snapshot.burst.crown_damage+storage.paid_snapshot.burst.facade_damage),
                {packets=storage.persistence_packets,openers=opener.count})
            storage.complete=true;report()
        end
        return
    end
    if config.save then
        if not storage.started then persistence_setup(event.tick) end
        if not storage.transition_saved and (storage.persistence_packets or 0)>=50 then
            storage.transition_saved=true
            check("active-burst-saved-mid-fire",storage.persistence_packets<200 and rounds(storage.persistence_source)==0,
                {packets=storage.persistence_packets})
            v2.before_save(event,check)
            storage.complete=true;report();game.server_save("anisetron-transition")
        end
        return
    end
    if not storage.started then
        setup(event.tick);v2.setup(event.tick,vehicle,target,check)
        voice_qc.setup(event.tick,vehicle,target)
        coverage_qc.setup(event.tick,vehicle,target)
    end
    local t=event.tick-storage.started
    v2.tick(event,check)
    voice_qc.tick(event,check)
    coverage_qc.tick(event,check)
    if not storage.source_removed_tick and t>10 then
        local beams=v2.beams(storage.surface,{{-130,-140},{-50,-50}})
        if #beams>=2 and storage.remove_target.health<health0(storage.remove_target) then
            storage.source_beams=beams;storage.source_removed_tick=event.tick
            storage.remove_source.destroy{raise_destroy=true};storage.source_removed_health=storage.remove_target.health
            check("active-native-beam-before-source-removal",true,{count=#beams})
        end
    elseif storage.source_removed_tick and event.tick==storage.source_removed_tick+1 then
        local gone=true;for _,beam in ipairs(storage.source_beams) do gone=gone and not beam.valid end
        check("beam-cancelled-with-source",gone and #v2.beams(storage.surface,{{-130,-140},{-50,-50}})==0)
    elseif storage.source_removed_tick and event.tick==storage.source_removed_tick+24 then
        check("source-removal-no-unpaid-tail",storage.remove_target.health==storage.source_removed_health)
    end
    if t>360 and t<1800 then
        for _,item in ipairs(storage.supply_point.targeted_items_deliver) do
            if item.name==AMMO and item.quality=="rare" and item.count>0 then storage.robot_delivery_observed={name=item.name,quality=item.quality,count=item.count} end
        end
    end
    if storage.ghost_rebuilt and storage.ghost_rebuilt.valid and not storage.equipment_ghost_observed then
        local eq=storage.ghost_rebuilt.grid.get{x=2,y=2}
        if eq and eq.type=="equipment-ghost" then
            check("native-blueprint-equipment-ghost",eq.ghost_name=="battery-equipment" and eq.quality.name=="rare" and eq.position.x==2 and eq.position.y==2)
            storage.equipment_ghost_observed=true
            storage.robot_chest.insert{name="battery-equipment",quality="rare",count=1}
        end
    end
    local player=game.get_player(storage.player)
    if t<240 then player.shooting_state={state=defines.shooting.shooting_enemies,position=storage.manual_target.position} end
    if t==60 then
        storage.speed_start={storage.speed.position.x,storage.saucer.position.x}
        storage.equipped_start={storage.speed_equipped.position.x,storage.saucer_equipped.position.x}
        for i,e in ipairs(storage.variants) do storage.variant_start[i]=e.position.x end
    end
    if t==10 then
        local cat=math.abs(storage.speed.torso_orientation-storage.turn_start[1])
        local saucer=math.abs(storage.saucer.torso_orientation-storage.turn_start[2])
        check("half-saucer-native-turning",saucer>0 and cat/saucer>=.45 and cat/saucer<=.55,{cathedral=cat,saucer=saucer})
    end
    if t==100 then
        check("switch-initial-target",storage.switch_target.health<health0(storage.switch_target))
        check("cease-initial-target",storage.cease_target.health<health0(storage.cease_target))
        storage.switch_target.force=storage.force
        storage.force.set_cease_fire(storage.cease_force,true);storage.cease_force.set_cease_fire(storage.force,true)
    elseif t==140 then
        storage.friendly_health=storage.switch_target.health;storage.friendly_rounds=rounds(storage.switcher)
        storage.cease_health=storage.cease_target.health;storage.cease_rounds=rounds(storage.cease)
    elseif t==220 then
        check("target-becomes-friendly",storage.switch_target.health==storage.friendly_health and rounds(storage.switcher)==storage.friendly_rounds)
        check("bilateral-cease-fire",storage.cease_target.health==storage.cease_health and rounds(storage.cease)==storage.cease_rounds)
        storage.switch_target.force=game.forces.enemy
        storage.force.set_cease_fire(storage.cease_force,false);storage.cease_force.set_cease_fire(storage.force,false)
    elseif t==320 then
        check("target-hostility-restored",storage.switch_target.health<storage.friendly_health)
        storage.switch_target.destroy()
        storage.cease_target.die()
    elseif t==360 then
        storage.removed_rounds=rounds(storage.switcher);storage.dead_rounds=rounds(storage.cease)
    elseif t==440 then
        check("removed-target-stops-fire",rounds(storage.switcher)==storage.removed_rounds)
        check("dead-target-stops-fire",rounds(storage.cease)==storage.dead_rounds)
        storage.switch_target=target(storage.surface,{6,-110})
        storage.cease_target=target(storage.surface,{80,-110},storage.cease_force)
    elseif t==600 then
        check("distinct-target-reacquired",storage.switch_target.health<health0(storage.switch_target) and storage.cease_target.health<health0(storage.cease_target))
        storage.force.set_friend(storage.cease_force,true);storage.cease_force.set_friend(storage.force,true)
    elseif t==640 then storage.friend_health=storage.cease_target.health;storage.friend_rounds=rounds(storage.cease)
    elseif t==740 then check("bilateral-friendship",storage.cease_target.health==storage.friend_health and rounds(storage.cease)==storage.friend_rounds) end
    if t==120 then
        check("mobile-native-fire",storage.mobile.position.x>-179 and rounds(storage.mobile)==0 and storage.mobile_target.health<health0(storage.mobile_target),
            {x=storage.mobile.position.x,rounds=rounds(storage.mobile),health=storage.mobile_target.health})
    elseif t==180 then
        local ratio=(storage.speed.position.x-storage.speed_start[1])/(storage.saucer.position.x-storage.speed_start[2])
        check("half-saucer-travel-speed",ratio>=0.45 and ratio<=0.55,{ratio=ratio})
        local variants={}
        for i,e in ipairs(storage.variants) do variants[i]={ratio=(e.position.x-storage.variant_start[i])/(storage.saucer.position.x-storage.speed_start[2]),speed=e.speed} end
        check("anchor-calibration",true,variants)
        local equipped=(storage.speed_equipped.position.x-storage.equipped_start[1])/(storage.saucer_equipped.position.x-storage.equipped_start[2])
        check("half-saucer-equipped-speed",equipped>=.45 and equipped<=.55,{ratio=equipped,equipment="one normal exoskeleton and charged battery each"})
    elseif t==240 then
        local auto_hits=storage.damage_events[storage.auto_target.unit_number]
        local manual_hits=storage.damage_events[storage.manual_target.unit_number]
        check("native-auto-upfront-payment",rounds(storage.auto)==0 and auto_hits and auto_hits.count>0)
        check("native-manual-upfront-payment",rounds(storage.manual)==0 and manual_hits and manual_hits.count>0)
        check("two-direct-channels-per-contact",auto_hits and manual_hits and auto_hits.exact and manual_hits.exact
            and auto_hits.crown==auto_hits.facade and manual_hits.crown==manual_hits.facade,{automatic=auto_hits,manual=manual_hits})
        check("damage-during-native-movement",storage.mobile_damage_moving==true)
        check("single-target-no-splash",storage.friend.health==health0(storage.friend) and storage.neighbor.health==storage.neighbor_health)
        check("ammo-exhaustion",rounds(storage.auto)==0)
        storage.prepaid_health=storage.auto_target.health
        report()
        mining()
        storage.supply_empty=storage.supply_target.health
        check("supply-upfront-exhaustion",rounds(storage.supply)==0 and health0(storage.supply_target)>storage.supply_empty)
    elseif t==360 then
        check("prepaid-burst-survives-empty-ammo",rounds(storage.auto)==0 and storage.auto_target.health<storage.prepaid_health)
        storage.robot_source=vehicle(storage.surface,{145,80},nil,false,"rare")
        storage.robot_source.grid.put{name="battery-equipment",quality="rare",position={0,0}}.energy=7654321
        storage.robot_source.order_deconstruction(storage.force)
    elseif t==900 then
        check("construction-robot-mining",storage.robot_mined==true)
        local inv=game.create_inventory(1);inv[1].set_stack{name="blueprint"}
        inv[1].set_blueprint_entities{{entity_number=1,name=VEHICLE,quality="rare",position={x=0,y=0},grid={
            {equipment={name="battery-equipment",quality="rare"},position={x=0,y=0}},
        }}}
        inv[1].build_blueprint{surface=storage.surface,force=storage.force,position={160,80},skip_fog_of_war=false};inv.destroy()
    elseif t==1300 then
        storage.supply_empty=storage.supply_target.health
        check("one-rare-charge-full-duration",health0(storage.supply_target)-storage.supply_empty==76800)
        storage.provider.insert{name=AMMO,quality="rare",count=20}
        storage.provider.insert{name=AMMO,quality="normal",count=20}
        storage.supply_request.set_slot(1,{value={name=AMMO,quality="rare",comparator="="},min=3,max=3})
        storage.supply_point.enabled=true
    elseif t==1400 then
        for _,kind in ipairs{"auto","manual"} do
            local e=storage[kind];local target=storage[kind.."_target"]
            local hits=storage.damage_events[target.unit_number]
            check(kind.."-exact-paid-burst",rounds(e)==0 and hits and hits.count==200 and hits.crown==100 and hits.facade==100 and hits.exact
                and health0(target)-target.health==48000,hits)
        end
        storage.exhausted_health=storage.auto_target.health
        check("quality-from-paid-ammo",storage.quality_packets==200 and storage.quality_exact==true
            and v2.channels_complete(storage.quality,100)
            and health0(storage.quality_target)-storage.quality_target.health==76800,{packets=storage.quality_packets})
        local sequence=storage.arc_sequence
        check("crown-360-retains-eligible-lock",v2.locked_sequence(sequence,100),
            {count=#sequence,first={sequence[1],sequence[2],sequence[3],sequence[4],sequence[5]}})
        check("facade-front-target-lock",v2.locked_sequence(storage.arc_facade_sequence,100),
            storage.arc_facade_sequence)
        -- Native opener choice may be any eligible member of this ring. A held
        -- crown spends its complete allocation on that member; the rear target
        -- no longer receives a compulsory quarter share from a cycling crown.
        local rear_expected=sequence[1]==4 and 32000 or 0
        check("rear-target-obeys-retained-crown-lock",health0(storage.arc_behind)-storage.arc_behind.health==rear_expected,
            {opening_index=sequence[1],expected_damage=rear_expected})
        check("rear-only-native-admission",health0(storage.rear_target)-storage.rear_target.health==32000
            and v2.channel_count(storage.rear_only,"crown")==100 and v2.channel_count(storage.rear_only,"facade")==0,
            {charges=rounds(storage.rear_only),health=storage.rear_target.health})
        check("prepaid-reserve-not-consumed",rounds(storage.reserve)==1 and storage.reserve_packets==200
            and storage.openers[storage.reserve.unit_number].count==1
            and v2.channels_complete(storage.reserve,100))
        check("quality-independent-of-vehicle",storage.rare_vehicle_packets==200 and storage.rare_vehicle_exact
            and storage.openers[storage.rare_vehicle.unit_number].quality=="normal"
            and v2.channels_complete(storage.rare_vehicle,100))
        check("collinear-crown-retains-opening-lock",v2.locked_sequence(storage.collinear_sequence,100),
            storage.collinear_sequence)
        check("collinear-facade-lock",v2.locked_sequence(storage.collinear_facade_sequence,100),
            storage.collinear_facade_sequence)
        v2.final_combat_checks(check)
        -- Acquisition skips paid opportunities rather than accumulating catch-
        -- up packets. These actors move or lose/reacquire eligibility; fixed
        -- stationary 100-contact/12-tick assertions above remain unchanged.
        for _,name in ipairs{"mobile","switcher","cease"} do
            local source=storage[name]
            local record=storage.source_damage[source.unit_number]
            local opener=storage.openers[source.unit_number]
            local budget=opener and opener.count*100 or 0
            local valid=record and opener and opener.count==1
            local detail={paid=opener and opener.count or 0,maximum_per_channel=budget,channels={}}
            for _,channel in ipairs{"crown","facade"} do
                local hits=record and record[channel]
                local slots=hits and hits.count>0 and hits.count<=budget
                local skipped=0
                for index=2,hits and #hits.ticks or 0 do
                    local gap=hits.ticks[index]-hits.ticks[index-1]
                    slots=slots and gap>=12 and gap%12==0
                    skipped=skipped+math.max(0,gap/12-1)
                end
                valid=valid and slots
                detail.channels[channel]={count=hits and hits.count or 0,skipped_slots=skipped}
            end
            check(name.."-acquisition-skips-without-catchup",valid==true,detail)
        end
    elseif t==1500 then
        check("expired-burst-no-unpaid-tail",storage.auto_target.health==storage.exhausted_health)
    elseif t==1800 then
        for i,e in ipairs(storage.travel) do check("native-traverse-"..({"water","cliff","factory","elevated-rail"})[i],e.position.x>90 and #e.autopilot_destinations==0 and e.speed==0,{x=e.position.x,y=e.position.y,speed=e.speed,destinations=#e.autopilot_destinations}) end
        check("robot-refill-resumes-fire",storage.supply_target.health<storage.supply_empty and rounds(storage.supply)>0,
            {rounds=rounds(storage.supply),health=storage.supply_target.health,trunk=storage.supply.get_inventory(defines.inventory.spider_trunk).get_item_count(AMMO)})
        check("native-robot-delivery-reservation",storage.robot_delivery_observed and storage.robot_delivery_observed.quality=="rare",storage.robot_delivery_observed)
        check("robot-cold-start-fire",storage.cold_target.health<health0(storage.cold_target) and rounds(storage.cold)>0)
        check("robot-blueprint-build",storage.robot_built and storage.robot_built.valid)
        local rebuilt=storage.robot_built
        check("robot-blueprint-equipment",rebuilt and #rebuilt.grid.equipment==1 and rebuilt.grid.equipment[1].name=="battery-equipment")
        local eq=rebuilt and rebuilt.grid.equipment[1]
        check("robot-blueprint-quality-charge-position",rebuilt and rebuilt.quality.name=="rare" and eq and eq.quality.name=="rare" and eq.energy==7654321 and eq.position.x==0 and eq.position.y==0)
        storage.robot_chest.insert{name=VEHICLE,quality="rare",count=1}
        local empty=storage.robot_chest.get_inventory(defines.inventory.chest).find_item_stack{name=VEHICLE,quality="rare"}
        check("blueprint-empty-chassis",empty and (not empty.grid or #empty.grid.equipment==0))
        local inv=game.create_inventory(1);inv[1].set_stack{name="blueprint"}
        inv[1].set_blueprint_entities{{entity_number=1,name=VEHICLE,quality="rare",position={x=0,y=0},grid={
            {equipment={name="battery-equipment",quality="rare"},position={x=2,y=2}},
        }}}
        inv[1].build_blueprint{surface=storage.surface,force=storage.force,position={165,105},skip_fog_of_war=false};inv.destroy()
    elseif t==2100 then
        local ghost=storage.ghost_rebuilt
        local eq=ghost and ghost.valid and ghost.grid.get{x=2,y=2}
        check("robot-delivered-blueprint-equipment",storage.equipment_ghost_observed and eq and eq.type~="equipment-ghost" and eq.name=="battery-equipment" and eq.quality.name=="rare" and #ghost.grid.equipment==1 and storage.robot_chest.get_inventory(defines.inventory.chest).get_item_count{name="battery-equipment",quality="rare"}==0)
        local e=storage.rebuilt;e.active=false;e.autopilot_destination={-70,50}
        storage.saved_energy=e.grid.equipment[1].energy;storage.persisted=true
        check("save-fingerprint-prepared",total_charges(e)==37 and #e.autopilot_destinations==1,
            {ammo=rounds(e),total=total_charges(e),trash=e.get_inventory(defines.inventory.spider_trash).get_item_count(AMMO),destinations=#e.autopilot_destinations})
        report()
        if config.save then game.server_save("anisetron-transition") end
    elseif t==2450 then
        local opener=storage.openers[storage.retrigger.unit_number]
        check("native-cooldown-two-paid-bursts",storage.retrigger_packets==400 and opener and opener.count==2
            and v2.channels_complete(storage.retrigger,200)
            and opener.last-opener.first>=1199 and rounds(storage.retrigger)==0,
            {packets=storage.retrigger_packets,openers=opener})
        storage.complete=true;report()
    end
    if config.visual and (t==180 or t==220) then
        for i,e in ipairs(storage.poses) do
            game.take_screenshot{surface=storage.visual,position={e.position.x,e.position.y-5},resolution={768,768},zoom=1,
                path="anisetron-art/pose-"..(i-1)..(t==180 and "-day.png" or "-night.png"),
                show_gui=false,show_entity_info=false,daytime=t==180 and 0 or 0.5,anti_alias=true,force_render=true}
        end
    end
end)

local config=require("test-config")
if config.origin_probe then require("origin-probe-control");return end
if config.dispersion_probe then require("dispersion-probe-control");return end
local directions={defines.direction.north,defines.direction.east,defines.direction.south,defines.direction.west}
local warmup,measured=1800,7200
local function surface(name,size)
    local s=game.create_surface(name,{width=size,height=size,autoplace_controls={},
        autoplace_settings={entity={treat_missing_as_default=false},decorative={treat_missing_as_default=false}}})
    s.freeze_daytime=true;s.daytime=0
    return s
end
local function pad(s,p,radius)
    s.request_to_generate_chunks(p,2);s.force_generate_chunk_requests()
    for _,e in pairs(s.find_entities_filtered{area={{p.x-64,p.y-64},{p.x+64,p.y+64}},type={"unit","unit-spawner","turret","tree"}}) do e.destroy() end
    local tiles={}
    for x=math.floor(p.x)-radius,math.floor(p.x)+radius do for y=math.floor(p.y)-radius,math.floor(p.y)+radius do
        tiles[#tiles+1]={name="lab-dark-1",position={x,y}}
    end end
    s.set_tiles(tiles)
end
local function fill(entity,fluid)
    entity.set_fluid(1,{name=fluid,amount=100});entity.set_fluid(2,{name=fluid,amount=100})
end
local function setup(tick)
    local root={start=tick,combat={},probes={},targets={},by_turret={},captures={}}
    storage.jet=root
    helpers.write_file("final-data.json",helpers.table_to_json(prototypes.mod_data["acid-jet-final-data"].data),false)
    local combat=surface("acid-jet-combat",4096);root.combat_surface=combat
    if not config.visual and not config.probe_only then for research=0,1 do
        local force=game.create_force("acid-jet-"..research)
        force.set_ammo_damage_modifier("flamethrower",research*.5)
        for _,variant in ipairs{"old","new"} do for _,component in ipairs{"direct","sticker","combined"} do
            force.set_turret_attack_modifier("acid-jet-"..variant.."-"..component,research*.7)
        end end
        for _,quality in ipairs{"normal","legendary"} do for _,fluid in ipairs{"ei-acidic-water","sulfuric-acid","ei-nitric-acid","ei-hydrofluoric-acid"} do
            local ranges=(config.profile=="8x" or config.profile=="16x") and {9.02,24,37.98} or {24}
            for _,distance in ipairs(ranges) do for _,component in ipairs{"direct","sticker","combined"} do for _,variant in ipairs{"old","new"} do
                local index=#root.combat;local p={x=(index%12)*112-620,y=math.floor(index/12)*112-1400}
                pad(combat,p,30)
                local turret=combat.create_entity{name="acid-jet-"..variant.."-"..component,position=p,force=force,quality=quality}
                p=turret.position
                local target=combat.create_entity{name="acid-jet-target",position={p.x,p.y-distance},force="enemy"};target.active=false
                fill(turret,fluid);turret.shooting_target=target
                local case={turret=turret,target=target,variant=variant,component=component,fluid=fluid,damage=0,fluid_used=0,
                    key=fluid.."/"..quality.."/"..research.."/"..distance.."/"..component}
                root.combat[#root.combat+1]=case;root.targets[target.unit_number]=case
            end end end
        end end
    end end
    local visual=surface("acid-jet-visual",1536);root.visual_surface=visual
    for facing=1,4 do for _,distance in ipairs{9,24,38} do for _,angle in ipairs{-48,0,48} do for _,variant in ipairs{"old","new"} do
        local index=#root.probes;local p={x=(index%8)*160-620,y=math.floor(index/8)*160-640}
        pad(visual,p,55)
        local turret=visual.create_entity{name="acid-jet-"..variant.."-probe",position=p,direction=directions[facing],force="player"}
        p=turret.position
        -- Native acquisition measures the sector from the entity centre.
        -- Tiny inward tolerances avoid fixed-point edge rejection.
        local aimed_angle=angle==0 and 0 or angle-(angle>0 and .1 or -.1)
        local radius=distance==9 and 9.02 or (distance==38 and 37.98 or distance)
        local yaw=math.rad((facing-1)*90+aimed_angle)
        local q={x=p.x+radius*math.sin(yaw),y=p.y-radius*math.cos(yaw)}
        local target=visual.create_entity{name="acid-jet-target",position=q,force="enemy"};target.active=false
        q=target.position
        fill(turret,"sulfuric-acid");turret.shooting_target=target
        local case={turret=turret,target=target,point=q,position=p,variant=variant,facing=facing,distance=distance,angle=angle,
            source_count=0,land_count=0,damage=0,requested_aim=aimed_angle,
            actual_entity_distance=math.sqrt((q.x-p.x)^2+(q.y-p.y)^2),key=facing.."/"..distance.."/"..angle.."/"..variant}
        root.probes[#root.probes+1]=case;root.by_turret[turret.unit_number]=case;root.targets[target.unit_number]=case
    end end end end
    -- Independent moving/retarget/shutdown cases keep visual matrix stationary.
    for i,kind in ipairs{"moving","retarget","shutdown","radius","sticker-small","sticker-large","sticker-moving"} do for j,variant in ipairs{"old","new"} do
        local p={x=(j-1)*160-100,y=(i-1)*160-240}
        local s=root.behavior_surface or surface("acid-jet-behavior",1024);root.behavior_surface=s
        pad(s,p,55)
        local turret=s.create_entity{name="acid-jet-"..variant.."-probe",position=p,force="player"};p=turret.position
        local moving=kind=="moving" or kind=="sticker-moving"
        local target=s.create_entity{name=kind=="sticker-small" and "acid-jet-target-small" or (moving and "acid-jet-moving" or "acid-jet-target"),position={p.x,p.y-24},force="enemy"}
        target.active=moving
        if moving then target.commandable.set_command{type=defines.command.go_to_location,destination={p.x+12,p.y-24},distraction=defines.distraction.none} end
        local case={turret=turret,target=target,point=target.position,position=p,variant=variant,kind=kind,damage=0,
            source_count=0,land_count=0,key=kind.."/"..variant}
        fill(turret,"sulfuric-acid");turret.shooting_target=target
        root.probes[#root.probes+1]=case;root.by_turret[turret.unit_number]=case;root.targets[target.unit_number]=case
        if kind=="radius" then
            case.radial={}
            for _,radius in ipairs{2.9,3.1} do
                local probe=s.create_entity{name="acid-jet-target",position={p.x+radius,p.y-24},force="enemy"};probe.active=false
                local entry={damage=0,target=probe,radius=radius}
                case.radial[#case.radial+1]=entry;root.targets[probe.unit_number]=entry
            end
        end
    end end
end
local function capture(case,name,night,zoom,close,at_target)
    if not config.visual then return end
    local p,q=case.position,case.point
    local width=math.max(640,math.ceil(math.abs(q.x-p.x)*32+450))
    local height=math.max(640,math.ceil(math.abs(q.y-p.y)*32+650))
    local position=at_target and {case.target.position.x,case.target.position.y-.4} or (close and {p.x,p.y-.3} or {(p.x+q.x)/2,(p.y+q.y)/2-1})
    game.take_screenshot{surface=case.turret.surface,position=position,
        resolution=close and {512,512} or {width,height},zoom=zoom or 1,daytime=night and .5 or 0,
        path="captures/"..name..".png",show_gui=false,show_entity_info=false,anti_alias=false,force_render=true}
    storage.jet.captures[#storage.jet.captures+1]=name
end
script.on_init(function()
    if remote.interfaces.freeplay then
        remote.call("freeplay","set_skip_intro",true);remote.call("freeplay","set_disable_crashsite",true)
    end
end)
script.on_event(defines.events.on_script_trigger_effect,function(event)
    local root=storage.jet;if not root then return end
    local case=event.source_entity and event.source_entity.valid and root.by_turret[event.source_entity.unit_number]
    if not case and event.cause_entity and event.cause_entity.valid then case=root.by_turret[event.cause_entity.unit_number] end
    if event.effect_id=="acid-jet-land" and not case then
        local point=event.target_position or event.source_position
        if point then for _,candidate in ipairs(root.probes) do
            if candidate.turret.surface.index==event.surface_index and (candidate.point.x-point.x)^2+(candidate.point.y-point.y)^2<200 then case=candidate;break end
        end end
    end
    if not case then return end
    local tick=event.tick-root.start
    if event.effect_id=="acid-jet-source" then
        case.source_count=case.source_count+1;case.first_source=case.first_source or tick;case.last_source=tick
        case.source_position=case.source_position or event.source_position
        case.launch_orientation=case.launch_orientation or case.turret.orientation
        case.last_source_position=event.source_position
        case.last_launch_orientation=case.turret.orientation
    elseif event.effect_id=="acid-jet-land" then
        case.land_count=case.land_count+1;case.first_land=case.first_land or tick;case.last_land=tick
        case.first_impact=case.first_impact or event.target_position
        case.last_impact=event.target_position
    end
end)
script.on_event(defines.events.on_entity_damaged,function(event)
    local root=storage.jet;if not root then return end
    local case=root.targets[event.entity.unit_number];if not case then return end
    local tick=event.tick-root.start
    if case.component then
        if tick>warmup and tick<=warmup+measured then case.damage=case.damage+event.final_damage_amount end
    else
        case.damage=case.damage+event.final_damage_amount;case.first_hit=case.first_hit or tick;case.last_hit=tick
        if case.kind=="retarget" and tick>500 and case.target==event.entity then case.damage_after_switch=(case.damage_after_switch or 0)+event.final_damage_amount end
        if case.kind=="moving" and tick<=250 then case.moving_damage=(case.moving_damage or 0)+event.final_damage_amount end
        if case.kind=="moving" then case.position_at_last_hit=case.target.position end
    end
end)
script.on_event(defines.events.on_tick,function(event)
    if not storage.jet then setup(event.tick) end
    local root=storage.jet;local tick=event.tick-root.start
    if tick%60==0 then
        for _,case in ipairs(root.combat) do
            local amount=0
            for i=1,2 do local fluid=case.turret.get_fluid(i);amount=amount+(fluid and fluid.amount or 0) end
            if tick>warmup and tick<=warmup+measured then case.fluid_used=case.fluid_used+200-amount end
            fill(case.turret,case.fluid)
        end
        for _,case in ipairs(root.probes) do if not case.stopped then fill(case.turret,"sulfuric-acid") end end
    end
    if tick==500 then for _,case in ipairs(root.probes) do if case.kind=="retarget" then
        case.target.teleport({case.position.x,case.position.y-80})
        local target=case.turret.surface.create_entity{name="acid-jet-target",position={case.position.x+8,case.position.y-24},force="enemy"};target.active=false
        case.target=target;case.point=target.position;root.targets[target.unit_number]=case;case.turret.shooting_target=target
    end end end
    if tick==600 then for _,case in ipairs(root.probes) do
        if case.kind=="shutdown" or (case.kind and case.kind:find("^sticker%-")) or (case.facing==2 and case.distance==24 and case.angle==0) then case.turret.active=false;case.stopped=true;case.stop_tick=tick end
    end end
    if tick==440 or tick==441 then for _,case in ipairs(root.probes) do if case.facing then
        capture(case,"matrix-"..case.key:gsub("/","-")..(tick==440 and "-day" or "-night"),tick==441)
    end end end
    if tick==445 or tick==446 then for _,case in ipairs(root.probes) do if case.facing and case.distance==24 then
        local marker
        if tick==446 and case.last_source_position then
            marker=rendering.draw_circle{surface=case.turret.surface,target=case.last_source_position,radius=.022,
                width=1,color={0,1,1},filled=true,draw_on_ground=false}
        end
        capture(case,"muzzle-"..case.facing.."-"..case.angle.."-"..case.variant..(tick==446 and "-marked" or ""),false,4,true)
        if marker then root.launch_markers=root.launch_markers or {};root.launch_markers[#root.launch_markers+1]=marker end
    end end end
    if tick==447 then for _,marker in ipairs(root.launch_markers or {}) do marker.destroy() end;root.launch_markers=nil end
    for _,case in ipairs(root.probes) do
        if case.facing==2 and case.distance==24 and case.angle==0 and case.first_source then
            local age=tick-case.first_source
            if age>=0 and age<=9 then capture(case,"startup-"..case.variant.."-"..age,false,4,true) end
        end
        if case.kind and case.kind:find("^sticker%-") then
            if tick==120 or tick==560 or tick==650 or tick==1000 or tick==1600 then
                case.sticker_samples=case.sticker_samples or {}
                case.sticker_samples[#case.sticker_samples+1]={tick=tick,count=#(case.target.stickers or {}),position=case.target.position}
                capture(case,case.kind.."-"..case.variant.."-"..tick,false,4,true,true)
            end
        end
    end
    if tick>=560 and tick<=780 and tick%4==0 then for _,case in ipairs(root.probes) do
        if case.facing==2 and case.distance==24 and case.angle==0 then capture(case,"sequence-"..case.variant.."-"..tick,false) end
    end end
    if tick==900 then for _,case in ipairs(root.probes) do
        if case.stopped then case.lands_at_900=case.land_count;case.stickers_at_900=#(case.target.stickers or {}) end
    end end
    if tick==((config.visual or config.probe_only) and 1790 or warmup+measured) then
        local report={profile=config.profile,visual=config.visual,probe_only=config.probe_only,native_refresh_candidate=config.native_refresh_candidate,
            animation_lifetime_candidate=config.animation_lifetime_candidate,pressure_baseline=config.pressure_baseline,
            fixture_version=6,combat={},probes={},captures=root.captures}
        for _,case in ipairs(root.combat) do report.combat[#report.combat+1]={key=case.key,variant=case.variant,
            damage=case.damage,fluid=case.fluid_used,dps=case.damage/(measured/60),fluid_per_second=case.fluid_used/(measured/60)} end
        for _,case in ipairs(root.probes) do
            local row={}
            for key,value in pairs(case) do if key~="turret" and key~="target" and key~="radial" then row[key]=value end end
            row.flight_ticks=case.first_land and case.first_source and case.first_land-case.first_source
            row.stickers_at_end=#(case.target.stickers or {})
            row.final_orientation=case.turret.orientation;row.status=case.turret.status
            row.final_target_position=case.target.position
            if case.radial then row.radial={};for _,probe in ipairs(case.radial) do row.radial[#row.radial+1]={radius=probe.radius,damage=probe.damage} end end
            report.probes[#report.probes+1]=row
        end
        report.ground_fires=root.visual_surface.count_entities_filtered{type="fire"}+root.behavior_surface.count_entities_filtered{type="fire"}
        helpers.write_file("jet-report.json",helpers.table_to_json(report),false)
        log("ACID_JET_RUNTIME complete profile="..config.profile)
    end
end)

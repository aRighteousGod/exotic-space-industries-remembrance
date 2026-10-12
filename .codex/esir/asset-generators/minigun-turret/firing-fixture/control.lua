-- Disposable fixture: sole dispatcher, bounded serial cases, no production
-- runtime changes. A native shot consumes one round and retains native visuals.
-- Lifecycle and evidence contract: README.md#contract in this directory.
local config = require("test-config")
local cases = require("cases")
local variants = {"native","flash","projectile","blank"}
local capture_offsets = {0,1,2,3,4,5,6,7,8,9,10,11,12,16,24,32,48,64,96}
local heading_ray_modes = {"center", "center_projected_once", "center_projected_twice",
    "source_projected_twice", "visual_projected_twice"}
local compact_ray_modes = {"center_projected_twice", "source_projected_twice", "visual_projected_twice"}

-- Compact controls use the actual shot's variation. Two zero-height cells on
-- independent backgrounds recover opacity; a third native-height cell is held
-- out to measure height and registration. No expected muzzle enters that fit.
local function compact_definitions(definition)
    local result = {}
    for _,ray_mode in ipairs(compact_ray_modes) do
        for _,role in ipairs{"recovery-a","recovery-b","held-out-height"} do
            local elevated = role == "held-out-height"
            result[#result+1] = {heading_name=elevated and definition.native_height_name or definition.heading_name,
                variation=definition.variation,height=elevated and definition.source_height or 0,
                original=definition.original,ray_mode=ray_mode,source_height=definition.source_height,role=role}
        end
    end
    return result
end

---@param entity LuaEntity|nil
---@return table|nil
local function observer_entity(entity)
    if entity and entity.valid then
        local snapshot={name=entity.name,type=entity.type,position=entity.position,property_errors={}}
        -- Some LuaEntity properties are unsupported for transient FX. Preserve
        -- that uncertainty; a turret heading is not an explosion orientation.
        for _,property in ipairs({"orientation","direction","graphics_variation"}) do
            local ok,value=pcall(function() return entity[property] end)
            if ok then snapshot[property]=value
            else snapshot.property_errors[property]=tostring(value) end
        end
        return snapshot
    end
end

local function capture_templates(group,tick,offset)
    local count=#group.definitions
    local row_y=group.row_y or -39.5
    local path="minigun-firing/templates/"..(group.path_key or group.ammo).."/"..offset..".png"
    game.take_screenshot{surface=storage.surface,position={40.5+(count-1)*2,row_y},
        resolution={count*256,256},zoom=2,daytime=0,anti_alias=false,show_gui=false,
        show_entity_info=false,hide_clouds=true,hide_fog=true,force_render=true,path=path}
    local origins={}
    for _,position in ipairs(group.spawned_positions or {}) do
        origins[#origins+1]={count*128+(position.x-(40.5+(count-1)*2))*64,
            128+(position.y-row_y)*64}
    end
    group.captures[#group.captures+1]={path=path,tick=tick,shot_offset=offset,
        cell_size=256,attachment_centers_y=128,attachment_centers_x0=128,zoom=2,
        runtime_attachment_origins=origins}
end

local function spawn_heading_templates(row,sample,tick)
    local group=row.heading_template_group
    if not group or group.first_shot then return end
    group.first_shot=tick
    group.source_effect=sample.effect_entity
    group.source_capture_variant=row.variant
    if config.compact_heading_templates then
        local variation=assert(sample.effect_entity and sample.effect_entity.graphics_variation,
            "Compact controls require observed source variation")
        local chosen
        for _,definition in ipairs(prototypes.mod_data["mg-firing-prototype-audit"].data.flash_templates[row.case.ammo]) do
            if definition.variation == variation then chosen=definition end
        end
        assert(chosen,"Actual source variation has no authored native template")
        group.definitions=compact_definitions(chosen)
    end
    group.spawned_positions,group.spawned_entities={},{}
    local source_position=assert(sample.effect_entity and sample.effect_entity.position)
    local target_position=row.target.position
    local center_position=row.entity.position
    group.status="native_target_ray_pending_images"
    group.ray_observations={source=source_position,target=target_position,center=center_position}
    for index,definition in ipairs(group.definitions) do
        local position={x=40.5+(index-1)*4,y=group.row_y}
        local ray_origin=string.find(definition.ray_mode,"center",1,true)==1 and center_position or source_position
        if string.find(definition.ray_mode,"visual",1,true)==1 then
            ray_origin={x=source_position.x,y=source_position.y-definition.source_height}
        end
        local y_multiplier=string.find(definition.ray_mode,"twice",1,true) and 2
            or string.find(definition.ray_mode,"once",1,true) and math.sqrt(2) or 1
        local target={x=position.x+target_position.x-ray_origin.x,
            y=position.y+(target_position.y-ray_origin.y)*y_multiplier}
        -- Explosion rotation is initialized by its constructor target. Runtime
        -- orientation readback stays zero even for rotated native pixels, so it
        -- cannot establish heading. Compare these observed target-ray controls
        -- to the actual firing pixels before accepting any rotation method.
        local template=assert(storage.surface.create_entity{name=definition.heading_name,
            position=position,target=target,force="player",snap_to_grid=false})
        local entry={variation=definition.variation,height=definition.height,
            ray_mode=definition.ray_mode,ray_origin=ray_origin,constructor_target=target,
            ray_y_multiplier=y_multiplier,
            after=observer_entity(template)}
        group.spawned_entities[#group.spawned_entities+1]=entry
        group.spawned_positions[#group.spawned_positions+1]=template.position
    end
    capture_templates(group,tick,0)
end

local function capture_direction(row,tick,phase)
    local path="minigun-firing/"..row.case.id.."/"..row.variant.."/direction-"..phase..".png"
    game.take_screenshot{surface=storage.surface,position=row.entity.position,
        resolution={512,640},zoom=2,daytime=0,anti_alias=false,show_gui=false,
        show_entity_info=false,hide_clouds=true,hide_fog=true,force_render=true,path=path}
    local observation={path=path,tick=tick,orientation=row.entity.orientation,
        entity_center={256,320},zoom=2,marker_shift_tiles={0,3}}
    if phase=="shot" then row.direction_capture=observation
    elseif phase=="prefire" then row.prefire_direction_capture=observation end
    return observation
end

---@param row table Fixture-owned row.
---@return number
local function remaining(row)
    local stack = row.entity.get_inventory(defines.inventory.turret_ammo)[1]
    return stack.valid_for_read and ((stack.count-1)*row.magazine_size+stack.ammo) or 0
end

---@param row table
---@param tick uint32
---@param offset integer
local function capture(row,tick,offset)
    local key = tostring(offset)
    if row.captured[key] then return end
    row.captured[key] = true
    local path = "minigun-firing/"..row.case.id.."/"..row.variant.."/"..key..".png"
    local center = {x=row.entity.position.x+row.case.visual_offset_tiles[1],
        y=row.entity.position.y+row.case.visual_offset_tiles[2]}
    game.take_screenshot{surface=storage.surface,position=center,resolution={320,320},
        zoom=2,daytime=0,anti_alias=false,show_gui=false,show_entity_info=false,
        hide_clouds=true,hide_fog=true,force_render=true,path=path}
    row.captures[#row.captures+1] = {path=path,tick=tick,shot_offset=offset,
        orientation=row.entity.orientation,center=center,zoom=2,resolution={320,320},
        expected_anchor_pixels={160,160},remaining=remaining(row)}
end

local function begin_case(index,tick)
    local spec = cases[index]
    storage.active = {index=index,spec=spec,start_tick=tick,rows={}}
    if not storage.template_groups[spec.ammo] then
        storage.template_groups[spec.ammo]={ammo=spec.ammo,captures={},
            definitions=prototypes.mod_data["mg-firing-prototype-audit"].data.flash_templates[spec.ammo]}
        storage.active.template_group=storage.template_groups[spec.ammo]
    end
    storage.by_unit = {}
    for v,variant in ipairs(variants) do
        local center = {x=(v-1)*40+0.5,y=0.5}
        local entity = storage.surface.create_entity{name="mg-firing-candidate",position=center,force="player"}
        entity.orientation = spec.target_orientation
        local angle = spec.target_orientation*2*math.pi
        local target = storage.surface.create_entity{name="mg-firing-target",force="enemy",
            position={center.x+math.sin(angle)*20,center.y-math.cos(angle)*20},snap_to_grid=false}
        target.destructible = false
        entity.shooting_target = target
        local ammo = "mgf-"..spec.ammo.."-"..variant
        local row = {case=spec,variant=variant,entity=entity,target=target,ammo=ammo,
            magazine_size=prototypes.item[ammo].magazine_size,captures={},captured={},
            shots={},flashes={},projectiles={},inserted=0}
        storage.active.rows[#storage.active.rows+1] = row
        storage.by_unit[entity.unit_number] = row
        if config.heading_templates and spec.kind=="static" and (variant=="native" or variant=="flash") then
            local key=spec.id.."-"..variant
            local group={ammo=spec.ammo,case_id=spec.id,variant=variant,captures={},
                row_y=variant=="native" and -59.5 or -69.5,path_key="heading/"..key,definitions={}}
            local definitions=prototypes.mod_data["mg-firing-prototype-audit"].data.flash_templates[spec.ammo]
            if config.compact_heading_templates then
                group.control_layout="paired-background-native-height-v1"
                group.definitions=compact_definitions(assert(definitions[1]))
            else
            for _,ray_mode in ipairs(heading_ray_modes) do
                for _,definition in ipairs(definitions) do
                    group.definitions[#group.definitions+1]={heading_name=definition.heading_name,
                        variation=definition.variation,height=0,original=definition.original,
                        ray_mode=ray_mode,source_height=definition.source_height}
                end
            end
            for _,ray_mode in ipairs(heading_ray_modes) do
                for _,definition in ipairs(definitions) do
                    group.definitions[#group.definitions+1]={heading_name=definition.native_height_name,
                        variation=definition.variation,height=definition.source_height,original=definition.original,
                        ray_mode=ray_mode,source_height=definition.source_height}
                end
            end
            end
            storage.heading_template_groups[key]=group
            row.heading_template_group=group
        end
    end
end

local function export_report(done,tick)
    local report = {schema=1,done=done,tick=tick,started=storage.started,
        config=config,cases=storage.results,errors=storage.errors,wired=storage.wired_captures,
        flash_templates=storage.template_groups,
        heading_flash_templates=storage.heading_template_groups,
        engine=script.active_mods.base,prototype_audit=prototypes.mod_data["mg-firing-prototype-audit"].data}
    helpers.write_file("minigun-firing-report.json",helpers.table_to_json(report),false)
end

script.on_init(function()
    if remote.interfaces.freeplay then
        remote.call("freeplay","set_skip_intro",true)
        remote.call("freeplay","set_disable_crashsite",true)
    end
    storage.started = game.tick -- Lifecycle boundary has no event tick.
    storage.results,storage.errors,storage.by_unit,storage.wired_captures = {},{},{},{}
    storage.template_groups={}
    storage.heading_template_groups={}
    local map = game.create_surface("minigun-firing",{autoplace_controls={},
        autoplace_settings={entity={treat_missing_as_default=false},
            decorative={treat_missing_as_default=false}}})
    map.request_to_generate_chunks({60,0},6);map.force_generate_chunk_requests()
    map.freeze_daytime,map.daytime = true,0
    local tiles = {}
    for y=-12,12 do for x=-12,132 do tiles[#tiles+1]={name="refined-concrete",position={x,y}} end end
    for y=-44,-35 do for x=35,70 do tiles[#tiles+1]={name="refined-concrete",position={x,y}} end end
    if config.heading_templates then
        for y=-74,-55 do for x=35,245 do tiles[#tiles+1]={name="refined-concrete",position={x,y}} end end
    end
    map.set_tiles(tiles)
    -- Decorative foliage can occlude the native marker even on concrete. The
    -- disposable diagnostic surface must remain visually controlled.
    map.destroy_decoratives{area={{-160,-160},{280,160}}}
    storage.surface = map
    if config.compact_heading_templates then
        for _,row_y in ipairs{-59.5,-69.5} do
            for index=1,9 do
                local role=({"a","b","c"})[(index-1)%3+1]
                assert(map.create_entity{name="mgf-compact-background-"..role,
                    position={40.5+(index-1)*4,row_y},force="player",snap_to_grid=false})
            end
        end
    end
    game.forces.player.chart(map,{{-160,-160},{280,160}})
    storage.wired_connections={}
    if config.include_wired_preview then
        storage.wired_entity=map.create_entity{name="mg-firing-candidate",position={60.5,40.5},force="player"}
        storage.wired_entity.active=false
        local pole=map.create_entity{name="medium-electric-pole",position={64.5,42.5},force="player"}
        for _,color in ipairs({"circuit_red","circuit_green"}) do
            local left=storage.wired_entity.get_wire_connector(defines.wire_connector_id[color],true)
            local right=pole.get_wire_connector(defines.wire_connector_id[color],true)
            storage.wired_connections[color]=left and right and left.connect_to(right,false) or false
        end
    end
end)

---@param event EventData.on_script_trigger_effect
script.on_event(defines.events.on_script_trigger_effect,function(event)
    if not storage.active then return end
    local kind,name = event.effect_id:match("^mgf%-([^|]+)|(.+)$")
    if not kind then return end
    local row
    local source = event.source_entity
    if source and source.valid then row=storage.by_unit[source.unit_number] end
    if not row then
        -- Created-effect observers may have projectile/explosion as source.
        -- Private prototype ids identify the unique active variant; position
        -- and active case are recorded rather than guessing a production owner.
        for _,candidate in ipairs(storage.active.rows) do
            if name:sub(1,#candidate.ammo)==candidate.ammo then row=candidate;break end
        end
    end
    if not row then storage.errors[#storage.errors+1]={tick=event.tick,error="unattributed observer",effect=event.effect_id};return end
    local sample = {tick=event.tick,effect=event.effect_id,source=event.source_position,
        target=event.target_position,orientation=row.entity.orientation,center=row.entity.position,
        source_entity=observer_entity(event.source_entity),target_entity=observer_entity(event.target_entity)}
    -- Positional fields can be nil for created_effect. Preserve returned entity
    -- positions without substituting the turret center for a native FX origin.
    for _,key in ipairs({"target_entity","source_entity"}) do
        local snapshot=sample[key]
        if snapshot and ((kind=="flash" and snapshot.type=="explosion") or
            (kind=="projectile" and snapshot.type=="projectile")) then
            sample.effect_entity_position=snapshot.position
            sample.effect_entity=snapshot
            break
        end
    end
    if kind == "shot" then
        sample.phase=#row.shots==0 and "first_after_preparation" or "sustained"
        if row.case.kind=="moving" then
            -- Native screenshots resolve once per rendered tick. Preserve every
            -- shot event but share the actual frame for shots on that same tick.
            sample.capture_shared_tick=row.moving_capture_tick==event.tick
            if not sample.capture_shared_tick then
                row.moving_capture_tick=event.tick
                row.moving_tick_capture=capture_direction(row,event.tick,"burst-tick-"..event.tick)
            end
            sample.capture=row.moving_tick_capture
        end
        row.shots[#row.shots+1] = sample
        if not row.first_shot then
            row.first_shot=event.tick;capture(row,event.tick,0)
            capture_direction(row,event.tick,"shot")
            local group=storage.active.template_group
            if row.variant=="native" and group and not group.first_shot then
                group.first_shot=event.tick
                group.spawned_positions={}
                for index,definition in ipairs(group.definitions) do
                    local template=assert(storage.surface.create_entity{name=definition.name,
                        position={40.5+(index-1)*4,-39.5},force="player",snap_to_grid=false})
                    group.spawned_positions[#group.spawned_positions+1]=template.position
                end
                capture_templates(group,event.tick,0)
            end
        end
    elseif kind == "flash" then
        row.flashes[#row.flashes+1]=sample
        spawn_heading_templates(row,sample,event.tick)
    elseif kind == "projectile" then row.projectiles[#row.projectiles+1]=sample end
end)

---@param event EventData.on_tick
script.on_event(defines.events.on_tick,function(event)
    if storage.done then return end
    local player = game.get_player(1)
    if player and not storage.viewer then
        player.set_controller{type=defines.controllers.spectator}
        player.teleport({60,0},storage.surface)
        storage.viewer=true -- All only_when_visible effects stay within 200 tiles.
    end
    if not storage.active then
        local initial=event.tick-storage.started
        if config.include_wired_preview and initial>=10 and initial<18 then
            local direction=(initial-10)*32
            local angle=direction/256*2*math.pi
            storage.wired_entity.orientation=math.atan2(math.sqrt(2)*math.sin(angle),math.cos(angle))/(2*math.pi)%1
            local path="minigun-firing/wired/"..direction..".png"
            game.take_screenshot{surface=storage.surface,position={61.5,40.5},resolution={640,512},zoom=3,
                daytime=0,anti_alias=false,show_gui=false,show_entity_info=false,hide_clouds=true,
                hide_fog=true,force_render=true,path=path}
            storage.wired_captures[#storage.wired_captures+1]={direction=direction,path=path,
                tick=event.tick,connections=storage.wired_connections}
        end
        if initial < 30 then return end
        begin_case(1,event.tick)
    end
    local active = storage.active
    local elapsed = event.tick-active.start_tick
    local group=active.template_group
    if group then
        if elapsed==30 then capture_templates(group,event.tick,-1) end
        if group.first_shot then
            local offset=event.tick-group.first_shot
            if offset>=1 and offset<=12 then capture_templates(group,event.tick,offset) end
        end
    end
    for _,row in ipairs(active.rows) do
        local heading=row.heading_template_group
        if heading then
            if elapsed==30 then capture_templates(heading,event.tick,-1) end
            if heading.first_shot then
                local offset=event.tick-heading.first_shot
                if offset>=1 and offset<=(config.compact_heading_templates and 1 or 12) then
                    capture_templates(heading,event.tick,offset)
                end
            end
        end
        row.entity.energy=1000000
        if row.case.kind=="moving" and row.first_shot then
            local progress=math.min(1,(event.tick-row.first_shot)/row.case.slew_ticks)
            local angle=progress*2*math.pi
            row.target.teleport({row.entity.position.x+math.sin(angle)*20,
                row.entity.position.y-math.cos(angle)*20})
            row.entity.shooting_target=row.target
            if event.tick-row.first_shot>=row.case.slew_ticks+20 and not row.stopped_remaining then
                -- Cooldown below one tick can consume multiple rounds per update.
                -- Keep enough for the complete sweep, then stop deliberately;
                -- unspent ammunition is not counted as native consumption.
                row.stopped_remaining=remaining(row)
                row.entity.get_inventory(defines.inventory.turret_ammo).clear()
            end
        end
        if elapsed == 30 then
            capture_direction(row,event.tick,"prefire")
            capture(row,event.tick,-1)
        elseif elapsed == 40 then
            local stack=row.entity.get_inventory(defines.inventory.turret_ammo)[1]
            local rounds=row.case.rounds
            stack.set_stack{name=row.ammo,count=math.ceil(rounds/row.magazine_size)}
            stack.ammo=(rounds-1)%row.magazine_size+1
            -- Native stack capacity can clamp set_stack. Account from the actual
            -- readback; retain the requested budget separately for diagnosis.
            row.requested=rounds;row.inserted=remaining(row)
            row.entity.shooting_target=row.target
        end
        if row.first_shot then
            for _,offset in ipairs(capture_offsets) do
                if event.tick-row.first_shot==offset then capture(row,event.tick,offset) end
            end
        end
    end
    if elapsed == active.spec.case_ticks-1 then
        local result={id=active.spec.id,spec=active.spec,rows={}}
        for _,row in ipairs(active.rows) do
            result.rows[#result.rows+1]={variant=row.variant,ammo=row.ammo,shots=row.shots,
                flashes=row.flashes,projectiles=row.projectiles,captures=row.captures,
                direction_capture=row.direction_capture,prefire_direction_capture=row.prefire_direction_capture,
                requested=row.requested,inserted=row.inserted,
                consumed=row.inserted-(row.stopped_remaining or remaining(row)),
                unspent=row.stopped_remaining or remaining(row),first_shot=row.first_shot}
            row.entity.destroy();row.target.destroy()
        end
        storage.results[#storage.results+1]=result
        if active.index==#cases then
            storage.done=true;export_report(true,event.tick)
        else
            export_report(false,event.tick)
            begin_case(active.index+1,event.tick+1)
        end
    end
end)

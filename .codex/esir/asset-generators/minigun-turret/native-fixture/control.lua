-- Disposable QC mod: this control.lua is its sole event owner. It is never
-- imported by ESIR control.lua. Bounded rows, fixed end tick, no gameplay repair.
-- Lifecycle and ownership: README.md#contract in this directory.
local contract = require("contract")
local config = require("test-config")

---@param name string
---@param radius uint32
---@return LuaSurface
local function surface(name, radius)
    local result = game.create_surface(name, {autoplace_controls={},
        autoplace_settings={entity={treat_missing_as_default=false}}})
    result.request_to_generate_chunks({0,0},radius)
    result.force_generate_chunk_requests()
    result.freeze_daytime = true
    result.daytime = 0
    game.forces.player.chart(result, {{-160,-160},{160,160}})
    return result
end

---@param row table Fixture-owned row with valid entity and surface.
---@param heading number
---@param tick uint32
---@param assign boolean|nil
local function acquire(row, heading, tick, assign)
    if row.target and row.target.valid then row.target.destroy() end
    local angle = heading * 2 * math.pi
    row.target = row.surface.create_entity{name="mg-native-target",force="enemy",
        position={row.entity.position.x+math.sin(angle)*16,row.entity.position.y-math.cos(angle)*16}}
    row.target.health = 1000000000
    if assign ~= false then row.entity.shooting_target = row.target end
    row.events[#row.events+1] = {kind="acquire",tick=tick,elapsed=tick-storage.started,
        heading=heading,assigned=assign~=false}
end

local function lose(row, tick)
    if row.target and row.target.valid then row.target.destroy() end
    row.events[#row.events+1] = {kind="lose",tick=tick,elapsed=tick-storage.started}
end

local function remaining(row)
    local stack = row.entity.get_inventory(defines.inventory.turret_ammo)[1]
    return stack.valid_for_read and (stack.count-1)*row.magazine_size+stack.ammo or 0
end

local function capture(row, tick, elapsed)
    if row.variant == "legacy" then return end
    local path = "minigun-native/timing/"..row.id.."/"..elapsed..".png"
    game.take_screenshot{surface=row.surface,position=row.entity.position,
        resolution={160,224},zoom=2,daytime=0,anti_alias=false,show_gui=false,
        show_entity_info=false,hide_clouds=true,hide_fog=true,force_render=true,path=path}
    row.captures[#row.captures+1] = {path=path,tick=tick,elapsed=elapsed,
        orientation=row.entity.orientation,shots=row.shots,remaining=remaining(row)}
end

script.on_init(function()
    if remote.interfaces.freeplay then
        remote.call("freeplay","set_skip_intro",true)
        remote.call("freeplay","set_disable_crashsite",true)
    end
    storage.started = game.tick -- on_init has no supplied tick; boundary read only.
    storage.rows, storage.by_unit, storage.errors = {}, {}, {}
    storage.layout, storage.layout_captures, storage.shadow_captures = {}, {}, {}
    local specs = {
        {"legacy-0","legacy",0,"baseline"}, {"candidate-0","candidate",0,"baseline"},
        {"legacy-1","legacy",0.125,"baseline"}, {"candidate-1","candidate",0.125,"baseline"},
        {"state-probe","state-probe",0.125,"states"},
    }
    for _, delay in ipairs({3,6,9}) do specs[#specs+1] = {"interrupt-up-"..delay,"candidate",0,"up",delay} end
    for _, delay in ipairs({5,9,14}) do specs[#specs+1] = {"interrupt-down-"..delay,"candidate",0,"down",delay} end
    for _, spec in ipairs(specs) do
        local map = surface("mg-native-"..spec[1],2)
        local entity = map.create_entity{name="mg-native-"..spec[2],position={0.5,0.5},force="player"}
        entity.orientation = spec[3]
        local row = {id=spec[1],variant=spec[2],heading=spec[3],scenario=spec[4],delay=spec[5],
            surface=map,entity=entity,magazine_size=prototypes.item["piercing-rounds-magazine"].magazine_size,
            inserted=0,shots=0,curve={},captures={},events={},ammo_samples={}}
        row.inserted = entity.get_inventory(defines.inventory.turret_ammo).insert{name="piercing-rounds-magazine",count=100}*row.magazine_size
        storage.rows[#storage.rows+1] = row
        storage.by_unit[entity.unit_number] = row
    end
    storage.layout_surface = surface("mg-native-layout",5)
    for pose = 1, 28 do
        local position = {((pose-1)%14)*4+0.5,math.floor((pose-1)/14)*4+0.5}
        local entity = storage.layout_surface.create_entity{name="mg-native-layout-"..pose,position=position,force="player"}
        entity.active = false -- The renderer still reads all 28 physical sources.
        storage.layout[#storage.layout+1] = entity
    end
    storage.shadow_surface = surface("mg-native-shadows",5)
    for index, entry in ipairs(contract.shadows) do
        local position = {((index-1)%8)*8+0.5,math.floor((index-1)/8)*8+0.5}
        storage.shadow_surface.create_entity{name="mg-native-background",position=position}
        local entity = storage.shadow_surface.create_entity{name="mg-native-shadow-"..entry[1],position=position,force="player"}
        entity.active = false
        storage.shadow_captures[#storage.shadow_captures+1] = {name=entry[1],position=position,
            path="minigun-native/shadows/"..entry[1]..".png",alphas={entry[2],entry[3],entry[4]},reversed=entry[5]}
    end
end)

---@param event EventData.on_script_trigger_effect
script.on_event(defines.events.on_script_trigger_effect,function(event)
    if event.effect_id ~= "mg-native-launch" then return end
    local entity = event.source_entity
    local row = entity and entity.valid and storage.by_unit[entity.unit_number]
    if not row then storage.errors[#storage.errors+1] = {tick=event.tick,message="unattributed shot"};return end
    row.shots = row.shots + 1
    row.first_shot = row.first_shot or event.tick
    local key = tostring(event.tick-storage.started)
    row.curve[key] = (row.curve[key] or 0) + 1
end)

---@param event EventData.on_tick
script.on_event(defines.events.on_tick,function(event)
    if storage.done then return end
    local elapsed = event.tick-storage.started
    local player = game.get_player(1)
    if player and not storage.viewer then
        player.set_controller{type=defines.controllers.spectator}
        player.teleport({0,0},storage.rows[2].surface)
        storage.viewer = true
    end
    for _, row in ipairs(storage.rows) do
        if not row.entity.valid then error("Fixture turret disappeared: "..row.id) end
        row.entity.energy = 1000000
        local inventory = row.entity.get_inventory(defines.inventory.turret_ammo)
        if inventory.get_item_count("piercing-rounds-magazine") < 30 then
            row.inserted = row.inserted + inventory.insert{name="piercing-rounds-magazine",count=70}*row.magazine_size
        end
        if row.target and row.target.valid then row.target.health = 1000000000 end
        if elapsed == 60 then acquire(row,row.heading,event.tick) end
        if row.scenario == "baseline" then
            if elapsed == 760 then acquire(row,(row.heading+0.25)%1,event.tick) end
            if elapsed == 860 then lose(row,event.tick) end
            if elapsed == 1080 then acquire(row,row.heading,event.tick,false) end
            if elapsed == 1200 then lose(row,event.tick) end
        elseif row.scenario == "up" then
            if elapsed == 60+row.delay then lose(row,event.tick) end
            if elapsed == 120 then acquire(row,row.heading,event.tick) end
            if elapsed == 190 then lose(row,event.tick) end
        elseif row.scenario == "down" then
            if elapsed == 160 then lose(row,event.tick) end
            if elapsed == 160+config.fold_delay_ticks+row.delay then acquire(row,row.heading,event.tick) end
            if elapsed == 240 then lose(row,event.tick) end
        else
            if elapsed == 150 then lose(row,event.tick) end
            if elapsed == 220 then acquire(row,0.375,event.tick) end
            if elapsed == 270 then lose(row,event.tick) end
        end
        local window = row.scenario == "baseline" and
            ((elapsed>=55 and elapsed<=100) or (elapsed>=750 and elapsed<=810) or
             (elapsed>=850 and elapsed<=990) or (elapsed>=1075 and elapsed<=1135) or
             (elapsed>=1195 and elapsed<=1335)) or
            (row.scenario ~= "baseline" and elapsed>=55 and elapsed<=350+config.fold_delay_ticks)
        if window then capture(row,event.tick,elapsed) end
        if elapsed%10 == 0 then row.ammo_samples[#row.ammo_samples+1] = {
            elapsed=elapsed,shots=row.shots,consumed=row.inserted-remaining(row),orientation=row.entity.orientation} end
    end
    if elapsed>=20 and elapsed<=531 then
        local direction = math.floor((elapsed-20)/2)
        if elapsed%2 == 0 then
            local angle = direction/256*2*math.pi
            local heading = (math.atan2(math.sqrt(2)*math.sin(angle),math.cos(angle))/(2*math.pi))%1
            for _, entity in ipairs(storage.layout) do entity.orientation = heading end
        else
            local path = "minigun-native/layout/"..direction..".png"
            game.take_screenshot{surface=storage.layout_surface,position={26.5,2.5},resolution={1792,256},
                zoom=1,daytime=0,anti_alias=false,show_gui=false,show_entity_info=false,
                hide_clouds=true,hide_fog=true,force_render=true,path=path}
            storage.layout_captures[#storage.layout_captures+1] = {direction=direction,path=path,
                orientation=storage.layout[1].orientation,tick=event.tick}
        end
    end
    if elapsed == 40 then
        for _, entry in ipairs(storage.shadow_captures) do
            game.take_screenshot{surface=storage.shadow_surface,position=entry.position,
                resolution={128,128},zoom=2,daytime=0,anti_alias=false,show_gui=false,
                show_entity_info=false,hide_clouds=true,hide_fog=true,force_render=true,path=entry.path}
        end
    end
    if elapsed == contract.finish_tick then
        storage.done = true
        local report = {schema=1,started=storage.started,elapsed=elapsed,config=config,
            instrumentation=contract.instrumentation,
            ballistic=settings.startup["ei-ballistic-divergence"].value,errors=storage.errors,
            cases={},layout=storage.layout_captures,shadows=storage.shadow_captures}
        for _, row in ipairs(storage.rows) do
            report.cases[#report.cases+1] = {id=row.id,variant=row.variant,scenario=row.scenario,
                heading=row.heading,delay=row.delay,first_shot=row.first_shot,shots=row.shots,
                consumed=row.inserted-remaining(row),curve=row.curve,captures=row.captures,
                events=row.events,ammo_samples=row.ammo_samples}
        end
        helpers.write_file("minigun-native-report.json",helpers.table_to_json(report),false)
        game.set_wait_for_screenshots_to_finish()
    end
end)

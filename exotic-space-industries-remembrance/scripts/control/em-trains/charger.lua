local model = {}
ei_lib = require("lib/lib")
ei_rng = require("lib/ei_rng")
-- DOC

-- Charger gets registered when placed
-- Charger properties: Has x-tiles range, consumes energy proportional to rails in range
-- charger range can be increased by research
-- trains in range get charged with fuel that has certain acc and max speed buffs
-- those buffs can be increased by research
-- clicking on a charger shows a gui that displays the current stats and rails it charges

--====================================================================================================
--MAIN
--====================================================================================================

model.trains = {
    ["ei_em-locomotive"] = true,
    ["ei_em-locomotive-mu"] = true --multiple unit consist mod
}

model.techs = {
    ["ei_eff"] = "eff",
    ["ei_acc"] = "acc",
    ["ei_spd"] = "spd"
}

--UTIL
------------------------------------------------------------------------------------------------------

function model.entity_check(entity)

    if entity == nil then
        return false
    end

    if not entity.valid then
        return false
    end

    return true
end


function model.check_global()
    if not storage.ei_emt then
        storage.ei_emt = {}
    end

    -- [charger_id] = {entity, rail_count, surface}
    if not storage.ei_emt.chargers then
        storage.ei_emt.chargers = {}
    end
    -- chargers that are not in update cycle
    if not storage.ei_emt.chargers_register then
        storage.ei_emt.chargers_register = {}
    end

    -- list of chargers in update cycle, first element gets updated next
    if not storage.ei_emt.chargers_que then
        storage.ei_emt.chargers_que = {}
    end
    -- [train_id] = {entity, surface}
    if not storage.ei_emt.trains then
        storage.ei_emt.trains = {}
    end

    -- trains that are not in update cycle
    if not storage.ei_emt.trains_register then
        storage.ei_emt.trains_register = {}
    end

    -- list of trains in update cycle, first element gets updated next
    if not storage.ei_emt.trains_que then
        storage.ei_emt.trains_que = {}
    end

    if not storage.ei_emt.gui then
        storage.ei_emt.gui = {}
    end

    if not storage.ei_emt.buffs then
        storage.ei_emt.buffs = {
            charger_range = 96, -- max: 512
            charger_efficiency = 0, -- max: 0.9
            
            acc_level = 0,
            speed_level = 0
        }
    end

    -- here the power draw for each rail in charger range is calculated
    -- from ~eff*(acc_level + max_speed_level)

end
--formula is 1 - below gets multiplied by power_usage
model.effBuffMultipliers = {
    [1] = 0.25,
    [2] = 0.4,
    [3] = 0.55,
    [4] = 0.7,
    [5] = 0.9
    }

function model.printBuffStatus()
    -- ❂ Exotic Industries: Epiphany of the Crystalline Engine ❂
    -- Whispered by the Obsidian Choir of the 11th Harmonic Core
    -- Forbidden frequencies interpreted through thought-velum transduction

    local weight = em_trains.weight or 500
    local max_speed = em_trains.max_speed or 2
    local max_speed_wagon = em_trains.max_speed_wagon or 10
    local max_speed_sound_leveloff = em_trains.max_speed_sound_leveloff or 1.5
    local max_speed_sound_levelon = em_trains.max_speed_sound_levelon or 0.1
    local em_sound_minimum_speed = em_trains.em_sound_minimum_speed or 0.09
    local em_sound_maximum_speed = em_trains.em_sound_maximum_speed or 2
    local max_power = em_trains.max_power or "1MW"
    local braking_force = em_trains.braking_force or 35
    local braking_force_wagon = em_trains.braking_force_wagon or 10
    local friction_force = em_trains.friction_force or 0.01
    local air_resistance = em_trains.air_resistance or 0.0001

    local eff_level = storage.ei_emt.buffs.charger_efficiency or 1
    local speed_level = storage.ei_emt.buffs.speed_level or 0
    local acc_level = storage.ei_emt.buffs.acc_level or 0

    local acceleration_multiplier = 1 + (0.1 * acc_level)
    local top_speed_multiplier = 1 + (0.1 * speed_level)
    local power_consumption_modifier = 1 - (model.effBuffMultipliers[eff_level] or 0.25)

    -- ⟁ Liturgical Echo of the Luminous Spine ⟁
    local incantation = {
        "☲ EM-Train Diagnostic Invocation Initialized ☲",
        "Weight of the Outer Shell: "..weight.." quartzian masses",
        "Base Kinesis Velocity (Prime Engine): "..max_speed.." ∇tiles/s",
        "Secondary Pod Velocity Threshold: "..max_speed_wagon.." ∇tiles/s",
        "➣ Speed Amplifier Resonance: ×"..top_speed_multiplier.." (λ"..speed_level..")",
        "➣ Acceleration Spiral Gain: ×"..acceleration_multiplier.." (φ"..acc_level..")",
        "➣ Energy Bleed Correction (Null-Waste): ×"..power_consumption_modifier,
        "Divine Conduction Limit: "..max_power.." / ∂t",
        "Tether Brakes – Loco: "..braking_force.." force fragments",
        "Tether Brakes – Cart: "..braking_force_wagon.." force fragments",
        "Slip-Field Intensity: "..friction_force.." ψN",
        "Ambient Etheric Drag (Ω drift): "..air_resistance.." μR",
        "Auditory Phasegate - Entry: "..em_sound_minimum_speed.." Δν",
        "Auditory Phasegate - Severance: "..em_sound_maximum_speed.." Δν"
    }

    for _, line in ipairs(incantation) do
        if line == 1 then
            ei_lib.crystal_echo(line,"default-bold")
        else
            ei_lib.crystal_echo(line)
        end
    end
end

--Get buffs
function model.check_buffs()
    local got1 = false
    local got2 = false
    local got3 = false
    local output = output or false
    if not game.players then
        log("check_buffs detected no game.players")
        return
    elseif not game.players[1].force then
        log("check_buffs detected no game.players[1].force")
        return
    elseif not game.players[1].force.technologies then
        log("check_buffs detected no game.players[1].force.technologies")
        return
    end
    for tier=20,1, -1 do --reverse so we stop checking that buff when we find its highest value
        if not got1 and game.players[1].force.technologies["ei_acc_"..tier] and game.players[1].force.technologies["ei_acc_"..tier].researched then
            local accBuff = tonumber(tier)
            storage.ei_emt.buffs.acc_level = math.max(storage.ei_emt.buffs.acc_level,accBuff)
            got1 = true
        end
        if not got2 and game.players[1].force.technologies["ei_spd_"..tier] and game.players[1].force.technologies["ei_spd_"..tier].researched then
            local spdBuff = tonumber(tier)
            storage.ei_emt.buffs.speed_level = math.max(storage.ei_emt.buffs.speed_level,spdBuff)
            got2 = true
        end
        if not got3 and game.players[1].force.technologies["ei_eff_"..tier] and game.players[1].force.technologies["ei_eff_"..tier].researched then
            local effBuff = tonumber(tier)

            local actual = model.effBuffMultipliers[effBuff] or 0
            storage.ei_emt.buffs.charger_efficiency = actual
            got3 = true
        end
        if got1 and got2 and got3 then
            return
        end
    end
end
--UPDATE
------------------------------------------------------------------------------------------------------

function model.apply_buffs(buff, level, single, entity)
    level = tonumber(level)
    -- game.print(buff .. " - " .. level)
    loop = single or false --all or just entity
    target = entity or nil
    -- level = 15 -- debug
    local status = "buff"
    local override = true --works while beam is enabled
    local radius = storage.ei_emt.buffs.charger_range or 10
    local time = 10
    if single then
        if buff == "eff" then
            local effBuff = effBuffMultipliers[level] or 0
            model.render_status_rings(target,status,radius,ei_ticksPerFullUpdate,override)
            --model.make_rings(target, storage.ei_emt.buffs.charger_range, 0.5)
            model.update_charger(target)
        end
        if buff == "acc" then
            radius = 8
            model.render_status_rings(target,status,radius+level,ei_ticksPerFullUpdate,override)
            --model.make_rings(target, 1+level, 0.75)
        end
        if buff == "spd" then
            radius = 8
            model.render_status_rings(target,status,radius+level,ei_ticksPerFullUpdate,override)
            --model.make_rings(v.entity, 1+level, 0.75)
        end
    elseif not single then
       if buff == "eff" then
            local effBuff = 0.1 + 0.17 * level
            for i,v in pairs(storage.ei_emt.chargers) do

            --model.make_rings(v.entity, storage.ei_emt.buffs.charger_range, 0.5)
            if(v.entity) then
                target = entity
                model.update_charger(target)
            elseif(storage.ei_emt.chargers and v.unit_number and storage.ei_emt.chargers[v.unit_number]) then
                target = storage.ei_emt.chargers[v.unit_number].entity --yee SHALL NOT AVOID PAYMENT
                model.update_charger(target)
            end
            model.render_status_rings(target,status,radius,ei_ticksPerFullUpdate,override)
            end
        elseif buff == "acc" then
            for i,v in pairs(storage.ei_emt.trains) do
                radius = 8
                target = v.entity
                model.render_status_rings(target,status,radius+level,ei_ticksPerFullUpdate,override)
                --model.make_rings(v.entity, 1+level, 0.75)
            end
        elseif buff == "spd" then
            for i,v in pairs(storage.ei_emt.trains) do
                --model.make_rings(v.entity, 1+level, 0.75)
                radius = 8
                target = v.entity
                model.render_status_rings(target,status,radius+level,ei_ticksPerFullUpdate,override)
            end
        end
    end
end

function model.register_que_charger(charger)
    if not model.entity_check(charger) then
        return
    end

    model.check_global()
    table.insert(storage.ei_emt.chargers_register, charger)
end
function model.register_que_train(train)
    if not model.entity_check(train) then
        return
    end

    model.check_global()
    table.insert(storage.ei_emt.trains_register, train)
end
function model.que_charger(charger)
    if not model.entity_check(charger) then
        log("que_charger entity check failed")
        return
    end

    model.check_global()
    table.insert(storage.ei_emt.chargers_que, charger)

end

function model.que_train(train)

    if not model.entity_check(train) then
        return
    end

    model.check_global()
    table.insert(storage.ei_emt.trains_que, train)

end

function model.deregister_all_trains()
    --if  storage.ei_emt.trains and ei_lib.getn(storage.ei_emt.trains) > 0 then
    storage.ei_emt.trains = {}
--        for unit_number in pairs(storage.ei_emt.trains) do
--            if unit_number and unit_number.entity then
--                em_trains.deregister_train(unit_number)
--            end
--        end
--    end
end

function model.deregister_all_chargers()
        --if storage.ei_emt.chargers and ei_lib.getn(storage.ei_emt.chargers) > 0 then
        storage.ei_emt.chargers = {}
--            for unit_number in pairs(storage.ei_emt.chargers) do
--                if unit_number and unit_number.entity then
--                    em_trains.deregister_charger(unit_number)
--                end
--            end
--        end
end
function model.reinitialize_chargers()
    local effBuff =  storage.ei_emt.buffs.eff_level or 0
    for _, surface in pairs(game.surfaces) do
        local entities = surface.find_entities_filtered{name = "ei_charger"}
        if entities and ei_lib.getn(entities) > 0 then
            for _, entity in pairs(entities) do
                if entity and entity.valid then
                    em_trains.register_charger(entity)
                    if effBuff then
                        em_trains.apply_buffs(em_trains.techs["ei-eff"], effBuff, true, entity)
                    end
                end
            end
        end
    end
end

function model.reinitialize_trains()
    local accBuff =  storage.ei_emt.buffs.acc_level or 0
    local spdBuff =  storage.ei_emt.buffs.spd_level or 0
    for _, surface in pairs(game.surfaces) do
        local entities = surface.find_entities_filtered{name = "ei_em-locomotive"}
        if entities and ei_lib.getn(entities) then
            for _, entity in pairs(entities) do
                if entity and entity.valid then
                    em_trains.register_train(entity)
                    if spdBuff then
                         em_trains.apply_buffs(em_trains.techs["ei-spd"], spdBuff, true, entity)
                    end
                    if accBuff then
                        em_trains.apply_buffs(em_trains.techs["ei-acc"], accBuff, true, entity)
                    end
                end
            end
        end
    end
end

function model.update_chargers()
    model.check_global()
    -- first add new registries
    for i,v in ipairs(storage.ei_emt.chargers_register) do
        if model.entity_check(v) then
            model.que_charger(v)
            end
    end
    storage.ei_emt.chargers_register = {}
    if ei_lib.getn(storage.ei_emt.chargers_que) == 0 then
        return false
        end
    -- update and reque first element
    local charger = storage.ei_emt.chargers_que[1]
    model.update_charger(charger)
    model.que_charger(charger)
    table.remove(storage.ei_emt.chargers_que,1) -- very costly
    return true
end

function model.update_trains()

    -- update logic: cycle through train updates
    -- every train has a 1MW acc power, fuel always has 1GJ fuel == 1000s
    -- enough to update trains after n-ticks

    model.check_global()

    -- first add new registries
    for i,v in ipairs(storage.ei_emt.trains_register) do
        if model.entity_check(v) then model.que_train(v) end
    end
    storage.ei_emt.trains_register = {}

    if ei_lib.getn(storage.ei_emt.trains_que) == 0 then return false end
    -- update and reque first element
    local train = storage.ei_emt.trains_que[1]
    
    model.update_train(train)
    model.que_train(train)
    table.remove(storage.ei_emt.trains_que,1) -- very costly
    return true
end

function model.update_train(train)

    if not model.entity_check(train) then
        return
    end
    local status = model.set_burner(train, model.find_charger(train))
    model.render_status_rings(train,status,8,10)
end

function model.render_status_rings(entity, status, width, timeUntilFade, override)
    if not (entity and entity.valid) then return end
    if not override and not (storage.ei.em_train_que == 2) then return end

    local surface = entity.surface
    local pos = entity
    width = math.min(storage.ei.que_width,width) or 1
    timeUntilFade = storage.ei.que_timetolive or timeUntilFade
    status = status or "default"
    local alpha = storage.ei.que_transparency
    -- Define colors per status
    local status_colors = {
        idle =    {r = 0.3, g = 0.3, b = 0.3, a = alpha},
        working = {r = 0.0, g = 0.8, b = 0.4, a = alpha},
        error =   {r = 1.0, g = 0.1, b = 0.1, a = alpha},
        warning = {r = 1.0, g = 0.5, b = 0.0, a = alpha},
        offline = {r = 0.9, g = 0.2, b = 0.2, a = alpha},
        default = {r = 0.3, g = 0.5, b = 0.9, a = alpha},
        buff =    {r = 0.6, g = 0.1, b = 0.9, a = alpha}, -- royal purple glory
    }

    local ring_color = status_colors[status] or status_colors["default"]

    local ttl = math.ceil(timeUntilFade * 2)


    -- 🔥 Render the status ring — a singular expression of machine-truth
    rendering.draw_circle {
        color = ring_color,
        radius = width,
        width = 1.5,
        filled = false,
        target = pos,
        surface = surface,
        time_to_live = ttl,
        draw_on_ground = false,
        players = game.connected_players,
    }
end

function model.cast_beam(charger, train)
    if not charger or not train or not charger.surface or not train.surface then return end
    if storage.ei.em_train_que == 1 then --mapped in global from settings
        -- create a beam between the charger and the target
        local beam = charger.surface.create_entity({
            name = "ei_charger-beam",
            position = charger.position,
            source_offset = {0, -1},
            source = charger,
            target = train,
            duration = ei_ticksPerFullUpdate/ei_update_functions_length,
            force = charger.force,
        })
    end
end

function ei_draw_train_glow(train, params)
	if not (train and train.valid) or not storage.ei.em_train_glow_toggle then return end

	local glow_params = {
	sprite = "emt_train_glow",
	scale_range = {1, 4},
	intensity_range = {0.4, 0.77},
	color_pool = {
	  {r = 0, g = 0.4, b = 1.0},
	  {r = 0.4, g = 0.2, b = 1.0},
	  {r = 0.2, g = 0.2, b = 1.0},
	  {r = 0.4, g = 0.1, b = 0.8},
	},
	blend_mode = "multiplicative",
	apply_runtime_tint = true,
	draw_as_glow = true,
	time_to_live = storage.ei.em_train_glow_timeToLive,
	count = 1
	}

	if params then
        for k, v in pairs(params) do
        glow_params[k] = v
        end
	end


	local color_index = math.random(1, #glow_params.color_pool)
	local color = glow_params.color_pool[color_index]
	local scale = math.random(glow_params.scale_range[1],glow_params.scale_range[2])
	local intensity = math.random(glow_params.intensity_range[1],glow_params.intensity_range[2])

	rendering.draw_light {
	  sprite = glow_params.sprite,
	  scale = scale,
	  intensity = intensity,
	  color = color,
	  target = train,
	  surface = train.surface,
	  time_to_live = glow_params.time_to_live,
	  players = game.connected_players,
	  blend_mode = glow_params.blend_mode,
	  apply_runtime_tint = glow_params.apply_runtime_tint,
	  draw_as_glow = glow_params.draw_as_glow,
	}
  -- Apply the glow to each attached EM train car (wagon)
  if train.train and train.train.carriages then
	  for _, car in pairs(train.train.carriages) do
		if car and car.valid and (car.name == "ei_em-fluid-wagon" or car.name == "ei_em-cargo-wagon") then
		  rendering.draw_light {
			sprite = glow_params.sprite,
			scale = scale,
			intensity = intensity,
			color = color,
			target = car,
			surface = car.surface,
			time_to_live = glow_params.time_to_live,
			players = game.connected_players,
			blend_mode = glow_params.blend_mode,
			apply_runtime_tint = glow_params.apply_runtime_tint,
			draw_as_glow = glow_params.draw_as_glow,
		  }
		end
	  end
    end
end


function model.set_burner(train, state)
    if not train or not train.burner then return "error" end
    if state == 0 or state == inf then train.burner.remaining_burning_fuel = 0 return "offline" end

    local acc = storage.ei_emt.buffs.acc_level or 0
    local speed = storage.ei_emt.buffs.speed_level or 0
    if not train.burner then
        return "offline"
        end
    train.burner.currently_burning = prototypes.item["ei_emt-fuel_"..tostring(acc).."_"..tostring(speed)]
    -- error(serpent.block(train.burner.currently_burning.name.fuel_value))
    -- game.print("currently_burning: " .. serpent.line(train.burner.currently_burning.fuel_value))
    train.burner.remaining_burning_fuel = train.burner.currently_burning.name.fuel_value*state
    -- turn this into double, as its may be smthing like 0.534343 -> 0.5
    train.burner.remaining_burning_fuel = train.burner.currently_burning.name.fuel_value*state
    if not train.burner.remaining_burning_fuel then return "warning" end
    ei_draw_train_glow(train)
    return "working"
end

function ei_draw_charger_glow(charger, overrides)
    if not (charger and charger.valid) or not storage.ei.em_charger_glow then return end
     local glow_params = {
         sprite = "emt_charger_glow",
         time_to_live = storage.ei.em_charger_glow_timeToLive,
         surface = charger.surface,
         players = game.connected_players,
         blend_mode = "multiplicative-with-alpha",
         apply_runtime_tint = true,
         draw_as_glow = true,
 
         glow_sets = {
             {
                 scale = 2,
                 intensity = 0.25,
                 colors = {
                     {r = 0, g = 0.4, b = 1.0},
                     {r = 0.4, g = 0.2, b = 1.0},
                     {r = 0.2, g = 0.2, b = 1.0},
                     {r = 0.4, g = 0.1, b = 0.8},
                 }
             },
             {
                 scale = 14,
                 intensity = 0.15,
                 colors = {
                     {r = 0, g = 0.4, b = 1.0},
                     {r = 0.4, g = 0.2, b = 1.0},
                     {r = 0.2, g = 0.2, b = 1.0},
                     {r = 0.4, g = 0.1, b = 0.8},
                 }
             }
         }
     }
	if overrides then
		 -- override any top-level params if needed
		 for k, v in pairs(overrides or {}) do
			 glow_params[k] = v
		 end
	end
     -- always-on light
    rendering.draw_light {
         sprite = glow_params.sprite,
         scale = 2,
         intensity = 0.65,
         color = {r = 0, g = 0.4, b = 1.0},
         target = charger,
         surface = glow_params.surface,
         time_to_live = storage.ei.em_charger_glow_timeToLive,
         players = glow_params.players,
         blend_mode = glow_params.blend_mode,
         apply_runtime_tint = glow_params.apply_runtime_tint,
         draw_as_glow = glow_params.draw_as_glow,
     }
 
     -- randomize additional glow effects from each glow set
    local set = math.random(1, #glow_params.glow_sets)
	local color_index = math.random(1, #glow_params.color_pool)
	local color = glow_params.color_pool[color_index]
	local scale = math.random(glow_params.scale_range[1],glow_params.scale_range[2])
	local intensity = math.random(glow_params.intensity_range[1],glow_params.intensity_range[2])

        rendering.draw_light {
            sprite = glow_params.sprite,
            scale = scale,
            intensity = intensity,
            color = color,
            target = charger,
            surface = glow_params.surface,
            time_to_live = storage.ei.em_charger_glow_timeToLive,
            players = glow_params.players,
            blend_mode = glow_params.blend_mode,
            apply_runtime_tint = glow_params.apply_runtime_tint,
            draw_as_glow = glow_params.draw_as_glow,
        }
 end

function model.has_enough_energy(charger, train)

    if not model.entity_check(charger) or not charger or not charger.energy  then
        return 0
    end

    local energy = charger.energy
    local total_needed = (1 - storage.ei_emt.buffs.charger_efficiency) * (1 + 0.1*storage.ei_emt.buffs.acc_level) * (1 + 0.1*storage.ei_emt.buffs.speed_level) *1000*1000*100 -- in MJ, up to 400 MJ
    --game.print(total_needed)
    local left = 0
    if train and train.burner and train.burner.currently_burning and train.burner.remaining_burning_fuel then
        left = train.burner.remaining_burning_fuel/train.burner.currently_burning.name.fuel_value
    end
    total_needed = total_needed*(1 - left)
    -- TODO only charge when is over 50% full

    if not energy or energy == 0 then return 0 end

    if energy >= total_needed then
        charger.energy = charger.energy - total_needed
        ei_draw_charger_glow(charger,false)
        --game.print("dec")
        return 1
    end

    -- only charge partially
    local dec = (energy/2)/total_needed
    charger.energy = dec
    return dec

end


function model.find_charger(train)
    if not train or not train.surface or not train.position.x or not train.position.y then return 0 end
    local t_pos = {["x"] = train.position.x, ["y"] = train.position.y} -- avoid issues with shorthand notation, might be obsolete
    local surface = train.surface
    local max_range_sqr = storage.ei_emt.buffs.charger_range*storage.ei_emt.buffs.charger_range
    local parts = 0

    for i,v in pairs(storage.ei_emt.chargers) do
        if model.entity_check(v.entity) then

            if v.entity.surface == surface then

                local c_pos = {["x"] = v.entity.position.x, ["y"] = v.entity.position.y}
                if ((t_pos.x - c_pos.x)*(t_pos.x - c_pos.x) + (t_pos.y - c_pos.y)*(t_pos.y - c_pos.y)) <= max_range_sqr then
                    
                    parts = parts + model.has_enough_energy(v.entity, train)
                    if parts >= 1 then
                        local status = "working"
                        if(train) then
                            model.cast_beam(v.entity, train)
                            model.render_status_rings(v.entity,status,8,10)
                            end
                        if ei_rng.int("trainglowscale",1,40) == 1 then
                            local offset_x = (ei_rng.float("chargerbeamx")) * 50  -- random between -50 and +50
                            local offset_y = (ei_rng.float("chargerbeamy")) * 50
                            local target_position = {
                                x = v.entity.position.x + offset_x,
                                y = v.entity.position.y + offset_y
                            }
                            model.cast_beam(v.entity, target_position)
                            end
                        return 1
                    end
                end
            end
        end
    end
    if(ei_lib.is_valid_number(parts)) then
        return parts
    else
        log("parts is"..parts)
    end
end


function model.update_charger_from_rail(rail, sign)

    if not model.entity_check(rail) then
        return
    end

    local radius = storage.ei_emt.buffs.charger_range
    local chargers = rail.surface.find_entities_filtered({
        position = rail.position,
        radius = radius,
        name = "ei_charger"
    })

    for _, charger in ipairs(chargers) do
        local charger_id = charger.unit_number
        storage.ei_emt.chargers[charger_id].rail_count = storage.ei_emt.chargers[charger_id].rail_count + sign
        local charge = storage.ei_emt.chargers[charger_id].entity
        if charge then
            charge.power_usage = (storage.ei_emt.chargers[charger_id].rail_count *250*1000 + 10*1000*1000) * (1-storage.ei_emt.buffs.charger_efficiency) /  60  -- 250W per rail + 10MW idle
        end
    end
end

function model.update_rail_counts()
    if not storage.ei_emt.chargers then return end
    for charger in pairs(storage.ei_emt.chargers) do
        if storage.ei_emt.chargers[charger].entity then
            storage.ei_emt.chargers[charger].rail_count = model.get_rail_count(storage.ei_emt.chargers[charger].entity)
        end
    end
end
ei_rail_types = {"straight-rail", "half-diagonal-rail","curved-rail-a","curved-rail-b","elevated-straight-rail",
"elevated-half-diagonal-rail","elevated-curved-rail-a","elevated-curved-rail-b","legacy-straight-rail",
"legacy-curved-rail","rail-ramp"}

function model.get_rail_count(charger)
    if not charger or not charger.surface then return 0 end
    local radius = storage.ei_emt.buffs.charger_range
    local rail_count = charger.surface.count_entities_filtered({
        position = charger.position,
        radius = radius,
        type = ei_rail_types
    })
    return rail_count
    end

function model.update_charger(charger)
    visual = visual or false -- should highlight counted rails?

    -- charger stil exists/vaild?
    if not model.entity_check(charger) then return false end

    local charger_id = charger.unit_number
    storage.ei_emt.chargers[charger_id].rail_count = model.get_rail_count(charger)
    local rail_count = storage.ei_emt.chargers[charger_id].rail_count or 1

    local radius = 6
    charger.power_usage = (storage.ei_emt.chargers[charger_id].rail_count *250*1000 + 10*1000*1000) * (1-storage.ei_emt.buffs.charger_efficiency) /  60  -- 250W per rail + 10MW idle

    local status = "default"
    local has_power_usage = charger.power_usage ~= nil
    local has_rails = rail_count > 1
    local has_energy = charger.energy and charger.energy > 100000 -- 1MJ buffer sanity check
    if not has_power_usage and not has_energy then
        status = "error"
        radius = 10
    elseif has_rails and not has_energy then
        status = "offline"
        radius = 12
    elseif has_rails and has_energy then
        status = "working"
        radius = 8
    else
        status = "default"
        radius = 6
    end

    model.render_status_rings(charger, status, radius, 12)

    return true
end


function model.animate_range(charger, fade, player)

    fade = fade or false
    player = {player} or nil

    if not model.entity_check(charger) then
        return
    end

    local radius = storage.ei_emt.buffs.charger_range
    local status = "default"
    model.render_status_rings(charger,status,radius,10)
    rendering.draw_sprite{
        sprite = "ei_emt-radius_big",
        x_scale = radius / 16,
        y_scale = radius / 16,
        target = charger,
        surface = charger.surface,
        draw_on_ground = true,
        players = game.connected_players,
        time_to_live = ei_ticksPerFullUpdate,
    }

    -- 1 tile == 32 pixels
    -- make circles with 8 pixel width, and color fade
    -- {r = 0.1, g = 0.83, b = 0.87} -> r = 0.7

    --model.make_rings(charger, radius, 0.5)

end

--REGISTER
------------------------------------------------------------------------------------------------------

function model.register_charger(entity)
    if not entity or not entity.unit_number then return end
    model.check_global()

    local charger_id = entity.unit_number
    storage.ei_emt.chargers[charger_id] = {
        entity = entity,
        rail_count = model.get_rail_count(entity),
        surface = entity.surface
    }

    -- adjust its power usage
    entity.power_usage = (storage.ei_emt.chargers[charger_id].rail_count *250*1000 + 10*1000*1000) * (1-storage.ei_emt.buffs.charger_efficiency) /  60  -- 250W per rail + 10MW idle
    --game.print("register_charger power usage "..entity.power_usage)
    -- set energy to max so that it does not need the full charge
    -- no free lunch
    --entity.energy = entity.prototype.electric_energy_source_prototype.buffer_capacity

    model.register_que_charger(entity)

end


function model.unregister_charger(entity)

    model.check_global()
    if entity and entity.unit_number then
        local charger_id = entity.unit_number
        storage.ei_emt.chargers[charger_id] = nil
    else
        log("unregister_charger passed nil entity")
    end
end


function model.register_train(entity)

    model.check_global()

    local train_id = entity.unit_number
    storage.ei_emt.trains[train_id] = {
        entity = entity,
        surface = entity.surface
    }

    model.register_que_train(entity)

end


function model.unregister_train(entity)

    model.check_global()

    local train_id = entity.unit_number
    storage.ei_emt.trains[train_id] = nil
    --em_trails.remove_active_train(entity)
end


--GUI RELATED
------------------------------------------------------------------------------------------------------

function model.fix_toggle_range()

    for _, player in pairs(game.players) do
        
        local player_index = player.index
        if storage.ei_emt.gui[player_index] then
            model.toggle_range_highlight(player) -- remove all
            model.toggle_range_highlight(player) -- draw new
        end

    end

end


function model.toggle_range_highlight(player)

    model.check_global()

    local player_index = player.index

    if storage.ei_emt.gui[player_index] then
        
        -- remove all renderings
        for key,_ in pairs(storage.ei_emt.gui[player_index]) do
            rendering.destroy(key)
        end

        storage.ei_emt.gui[player_index] = nil
        return
    end

    storage.ei_emt.gui[player_index] = {}

    for id,charger in pairs(storage.ei_emt.chargers) do
        local render_id = model.animate_range(charger.entity, false, player)
        if render_id then storage.ei_emt.gui[player_index][render_id] = true end
    end

end

--HANDLERS 
------------------------------------------------------------------------------------------------------\

function model.train_updater()
   return model.update_trains()

end
function model.charger_updater()
    return model.update_chargers()
end

function model.on_research_finished(event)

    local name = event.research.name

    -- name starts with "ei_" and ends with a number
    if not string.match(name, "^ei_") then return end
    if not string.match(name, "%d$") then return end

    -- first always ei_xxx_ so 7 digits, where 7th is _, cut those
    local lenght = string.len(name)
    if lenght < 8 then return end

    -- only last digit is relevant
    local short_name = string.sub(name, 1, 6)

    tier = tonumber(string.sub(name, -2))
    
    if not tier then 
      tier = tonumber(string.sub(name, -1))
    end 

    if not tier then error("Can not get tier for tech "..name) end 

    if model.techs[short_name] then
      -- game.print(short_name .. " - " .. tier)
      model.apply_buffs(model.techs[short_name], tonumber(tier))
      model.printBuffStatus()
    end

end


function model.on_built_entity(entity)

    if not model.entity_check(entity) then
        return
    end

    if entity.name == "ei_charger" then
        model.register_charger(entity)
        model.animate_range(entity, true, nil)
        model.fix_toggle_range()
        em_trains_gui.mark_dirty()
    elseif ei_lib.table_contains_value(ei_rail_types,entity.name) then
        model.update_charger_from_rail(entity, 1)
        em_trains_gui.mark_dirty()
    elseif model.trains[entity.name] then
        model.register_train(entity)
        em_trains_gui.mark_dirty()
    end
end


function model.on_destroyed_entity(entity)

    if not model.entity_check(entity) then
        return
    end

    if entity.name == "ei_charger" then
        model.unregister_charger(entity)
        em_trains_gui.mark_dirty()
    elseif ei_lib.table_contains_value(ei_rail_types,entity.name) then
        model.update_charger_from_rail(entity, -1)
        em_trains_gui.mark_dirty()
    elseif model.trains[entity.name] then
        model.unregister_train(entity)
        em_trains_gui.mark_dirty()
    end
end


return model
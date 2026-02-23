local model = {}
ei_rng = require("lib/rng")

local DEBUG_TRACEROUTE = false

--====================================================================================================
--GATE
--current issues
--mp desync when activated/interacted
--need to recurse over all transferable items in data-updates-final and make a table
--along the lines of mass_weights to then charge energy based on some approximation
--of "mass"
--====================================================================================================
--depreciated
model.energy_costs = {
    ["player"] = 10,
    ["item"] = 1
}
--should be depreciated
model.inverse_surface = {
    ["gaia"] = "nauvis",
    ["nauvis"] = "gaia"
}
model.mass_weights = {
    ["ei-advanced-faulty-semiconductor"] = 2,
    ["ei-alien-beacon"] = 500,
    ["ei-alien-beacon_off-1"] = 500,
    ["ei-alien-beacon_off-2"] = 500,
    ["ei-alien-beacon_off-3"] = 500,
    ["ei-alien-flowers-1"] = 4,
    ["ei-alien-flowers-10"] = 4,
    ["ei-alien-flowers-11"] = 4,
    ["ei-alien-flowers-2"] = 4,
    ["ei-alien-flowers-3"] = 4,
    ["ei-alien-flowers-4"] = 4,
    ["ei-alien-flowers-5"] = 4,
    ["ei-alien-flowers-6"] = 4,
    ["ei-alien-flowers-7"] = 4,
    ["ei-alien-flowers-8"] = 4,
    ["ei-alien-flowers-9"] = 4,
    ["ei-alien-resin"] = 4,
    ["ei-alien-seed"] = 500,
    ["ei-alien-stabilizer"] = 50,
    ["ei-black-hole-data"] = 1,
    ["ei-blooming-alien-seed"] = 500,
    ["ei-charged-energy-crystal"] = 1.25,
    ["ei-coal-chunk"] = 2,
    ["ei-copper-chunk"] = 3,
    ["ei-crushed-sulfur"] = 1,
    ["ei-cryo-container-nitrogen"] = 2,
    ["ei-cryo-container-oxygen"] = 2,
    ["ei-crystal-accumulator_off-1"] = 125.0,
    ["ei-crystal-accumulator_off-2"] = 125.0,
    ["ei-crystal-accumulator_off-3"] = 125.0,
    ["ei-crystal-accumulator_off-4"] = 125.0,
    ["ei-empty-cryo-container"] = 2,
    ["ei-energy-crystal"] = 1.25,
    ["ei-exotic-matter-down"] = 1,
    ["ei-exotic-matter-up"] = 1,
    ["ei-exotic-ore"] = 10,
    ["ei-farstation_off-1"] = 100,
    ["ei-farstation_off-2"] = 100,
    ["ei-farstation_off-3"] = 100,
    ["ei-faulty-semiconductor"] = 2,
    ["ei-fluorite"] = 1,
    ["ei-gold-chunk"] = 5,
    ["ei-iron-chunk"] = 3,
    ["ei-lead-chunk"] = 3,
    ["ei-neodym-chunk"] = 10,
    ["ei-nuclear-waste"] = 100,
    ["ei-plasma-data"] = 1,
    ["ei-plutonium-239"] = 1,
    ["ei-pure-copper"] = 1,
    ["ei-pure-gold"] = 1,
    ["ei-pure-iron"] = 1,
    ["ei-pure-lead"] = 1,
    ["ei-rift-stabilizer"] = 50,
    ["ei-sulfur-chunk"] = 3,
    ["ei-thorium-232"] = 3,
    ["ei-uranium-233"] = 3,
    ["ei-uranium-chunk"] = 5,
    ["ei-used-plutonium-239-fuel"] = 10,
    ["ei-used-thorium-232-fuel"] = 10,
    ["ei-used-uranium-233-fuel"] = 10,
    ["ei-used-uranium-235-fuel"] = 10,
  }

--DOC
------------------------------------------------------------------------------------------------------

-- placing the gate will place hidden container ontop
-- gui allows selection of exit location
-- item transport is only possible, if exit location is coupled to exit point
-- item transport consumes energy
-- gui allows to set condition for item transport trigger

--UTIL
-----------------------------------------------------------------------------------------------------

function model.entity_check(entity)

    if entity == nil then
        return false
    end

    if not entity.valid then
        return false
    end

    return true
end


function model.check_global_init()

    if not storage.ei.gate then
        storage.ei.gate = {}
    end

    if not storage.ei.gate.gate then
        storage.ei.gate.gate = {}
    end

--    if not storage.ei.gate.gate_break_point then
--        storage.ei.gate.gate_break_point = nil

    if not storage.ei.gate.exit_platform then
        storage.ei.gate.exit_platform = {}
    end

    if not storage.ei.gate.remote then
        storage.ei.gate.remote = {}
    end

end


function model.get_transfer_inv(transfer)
    -- transfer is either a player index, a robot, or nil
    -- needed to prevent unregistration when the transferer cant mine due to full inv

    if not transfer then
        return nil
    end

    if type(transfer) == "number" then
        -- player index
        local player = game.get_player(transfer)
        return player.get_main_inventory()
    end

    if transfer.valid then
        -- robot
        local robot = transfer
        return robot.get_inventory(defines.inventory.robot_cargo)
    end

    return nil

end


function model.transfer_valid(transfer)

    local target_inv = model.get_transfer_inv(transfer)
    
    if not target_inv then
        -- case for when destroyed by gun f.e. -> need to unregister
        return true
    end

    -- check if target has space for gate item
    if target_inv.can_insert({name = "ei-gate", count = 1}) then
        target_inv.insert({name = "ei-gate", count = 1})
        return true
    end

    return false

end


function model.transfer(transfer)

    local target_inv = model.get_transfer_inv(transfer)
    
    if not target_inv then
        return
    end

    target_inv.insert({name = "ei-gate", count = 1})
end


function model.register_gate(gate, container)

    model.check_global_init()
    
    local gate_unit = gate.unit_number
    if storage.ei.gate.gate[gate_unit] or not gate or not gate.valid or not container or not container.valid then
        log("ei register_gate returned early due to pre-existing gate_unit or non-existent gate or non-existent container")
        return
    end

    storage.ei.gate.gate[gate_unit] = {}
    storage.ei.gate.gate[gate_unit].gate = gate
    storage.ei.gate.gate[gate_unit].container = container

    -- set endpoint to (0, 0)
    if model.inverse_surface[gate.surface.name] then
        storage.ei.gate.gate[gate_unit].exit = {surface = model.inverse_surface[gate.surface.name], x = 0, y = 0}
    end

    storage.ei.gate.gate[gate_unit].state = false


end


function model.find_gate(container)

    if not container or not container.valid then
        return nil
    end

    if container.name ~= "ei-gate-container" then
        return nil
    end

    local gate = container.surface.find_entity("ei-gate", container.position)

    if not gate then
        return nil
    end

    return gate

end

--GATE LOGIC
-----------------------------------------------------------------------------------------------------

function model.make_gate(gate)

    -- create and register cate-container
    local container = gate.surface.create_entity({
        name = "ei-gate-container",
        position = gate.position,
        force = gate.force
    })

    model.register_gate(gate, container)

end


function model.destroy_gate(gate, container)

    if not gate then
        -- look for gate at container position
        gate = container.surface.find_entity("ei-gate", container.position)
    end

    if not container then
        -- look for container at gate position
        container = gate.surface.find_entity("ei-gate-container", gate.position)
    end

    if not gate or not container then
        return
    end

    local gate_unit = gate.unit_number

    if model.entity_check(gate) then
        gate.destroy()
    end

    if model.entity_check(container) then
        container.destroy()
    end

    if storage.ei.gate.gate[gate_unit] then
        storage.ei.gate.gate[gate_unit] = nil
    end

end


function model.check_for_teleport(unit, gate)

    -- loop over all gates and check if there is a player in range
    -- if so check if enough power and if endpoint has exit
    -- spawn in exit if not and teleport

    if not model.gate_state(gate) then
        return
    end

    local dist = 2

    local exit_container = storage.ei.gate.gate[unit].exit_container

    if exit_container then

        -- is container still valid? if not try to find new one
        if not exit_container.valid then
            
            local position = {x = storage.ei.gate.gate[unit].exit.x, y = storage.ei.gate.gate[unit].exit.y}
            local surface = game.get_surface(storage.ei.gate.gate[unit].exit.surface)

            if not model.find_container(gate, surface, position) then
                return
            end   
            
            exit_container = storage.ei.gate.gate[unit].exit_container

        end

        local source_container = storage.ei.gate.gate[unit].container
        local source_inv = source_container.get_inventory(defines.inventory.chest)
        if source_inv.is_empty() then return end

        local target_inv = exit_container.get_inventory(defines.inventory.chest)
        if target_inv.is_full() then return end

        local success = false

        -- loop over source inv and try to transfer to target inv
        for i = 1, #source_inv do
            if source_inv[i].valid_for_read then
                local item_stack = source_inv[i]
                local item_name = item_stack.name
                local item_count = item_stack.count

                -- Simulate a full transfer first
                local simulated_stack = {{name = item_name, count = item_count}}

                if model.pay_energy(gate, simulated_stack) == true then
                    -- Try to insert into target inventory
                    local transfer_count = target_inv.insert(item_stack)

                    if transfer_count > 0 then
                        -- Actually pay energy for the amount successfully inserted
                        if model.pay_energy(gate, {{name = item_name, count = transfer_count}},true) == true then
                            item_stack.count = item_stack.count - transfer_count
                            success = true

                            ei_victory.count_value("gate_items_transported", transfer_count)
                        else
                            -- Energy check passed earlier, but failed here: rollback insertion
                            target_inv.remove({name = item_name, count = transfer_count})
                        end
                    end
                end
            end
        end

        if success then
            model.render_exit(gate, exit_container.bounding_box)
        end

    end

    return

end


function model.find_container(gate, surface, position, print_out)

    print_out = print_out or false
    local unit = gate.unit_number

    -- try to snap position to a container entity
    local containers = surface.find_entities_filtered(
        {
            area = {
                {position.x - 0.3, position.y - 0.3},
                {position.x + 0.3, position.y + 0.3}
            },
            type = {
                "container",
                "logistic-container",
            }
        }
    )

    if #containers > 0 and containers[1].name ~= "ei-gate-container" then
        position = containers[1].position
        storage.ei.gate.gate[unit].exit_container = containers[1]

        game.print({"exotic-industries.gate-exit-container-set", surface.name, position.x, position.y, containers[1].name})

    else
        storage.ei.gate.gate[unit].exit_container = nil

        game.print({"exotic-industries.gate-exit-set", surface.name, position.x, position.y})
        return false
    end

    -- set new exit
    storage.ei.gate.gate[unit].exit = {
        surface = surface.name,
        x = position.x,
        y = position.y
    }
    
    return true

end


function model.gate_state(gate)

    -- will be false if no exit is set

    if not storage.ei.gate.gate[gate.unit_number].exit then
        return false
    end

    -- also check if has power
    if gate.energy < 45 * 1e9 then -- 45 GJ
        return false
    end

    if not storage.ei.gate.gate[gate.unit_number].state then
        return false
    end

    return true
end
  
--Recursively expand raw ingredient cost of an item
--1 this doesn't work
--2 needs to be rewritten to compute costs in final-fixes
local function get_raw_ingredient_cost(item_name, multiplier, seen, depth)
    if not item_name or type(item_name) ~= "string" then
        log("[ERROR] Invalid item_name passed to get_raw_ingredient_cost: " .. serpent.block(item_name))
        return {}
    end
    -- SAFELY test for game.item_prototypes
    local ok, protos = pcall(function() return game.item_prototypes end)
    if not ok or type(protos) ~= "table" then
        -- prototypes table isn’t available yet, bail out
        return false
    end
    seen = seen or {}
    depth = (depth or 0) + 1

    if DEBUG_TRACEROUTE then
        game.print(string.rep("  ", depth) .. "[Trace] → " .. item_name .. " ×" .. multiplier .. " (depth " .. depth .. ")")
    end

    if seen[item_name] then
        if DEBUG_TRACEROUTE then
            game.print(string.rep("  ", depth) .. "[Trace] Skipping already seen: " .. item_name)
        end
        return {}
    end
    seen[item_name] = true

    local results = {}
    local proto = protos[item_name]
    if not proto then
        if DEBUG_TRACEROUTE then
            game.print(string.rep("  ", depth) .. "[Trace] No prototype for: " .. item_name)
        end
        results[item_name] = multiplier
        return results
    end

    local recipes = proto.recipes
    if not recipes or #recipes == 0 then
        results[item_name] = multiplier
        if DEBUG_TRACEROUTE then
            game.print(string.rep("  ", depth) .. "[Trace] No recipes for: " .. item_name)
        end
        return results
    end

    local recipe = recipes[1]  -- Assuming first recipe is correct
    for _, ing in ipairs(recipe.ingredients) do
        local name = ing.name
        local amount = ing.amount * multiplier

        if DEBUG_TRACEROUTE then
            game.print(string.rep("  ", depth) .. "[Trace] Ingredient: " .. name .. " ×" .. amount)
        end

        local sub_proto = protos[name]
        local sub_recipes = sub_proto and sub_proto.recipes
        if not sub_recipes or #sub_recipes == 0 then
            results[name] = (results[name] or 0) + amount
        else
            local sub_totals = get_raw_ingredient_cost(name, amount, seen, depth)
            for k, v in pairs(sub_totals) do
                results[k] = (results[k] or 0) + v
            end
        end
    end
    return results
end
  
--Master Function: Gate pays based on effective mass
function model.pay_energy(gate, tablein, actuallypay)
    local total_energy = 0

    for _, entry in ipairs(tablein) do
        if DEBUG_TRACEROUTE then
            game.print("[PayEnergy] Processing: " .. serpent.line(entry))
        end

        if type(entry) == "string" and entry == "player" then
            total_energy = total_energy + model.energy_costs.player

        elseif type(entry) == "table" and entry.name and entry.count then
            local count = tonumber(entry.count) or 0
            if count > 0 then
                local raw_costs = get_raw_ingredient_cost(entry.name, count)
                if not raw_costs then
                    local weight = model.mass_weights[entry] or 1
                    local energy_contrib = weight * entry.count

                    total_energy = total_energy + energy_contrib
                else
                    for raw, amt in pairs(raw_costs) do
                        local weight = model.mass_weights[raw] or 1
                        local energy_contrib = weight * amt

                        total_energy = total_energy + energy_contrib

                        if DEBUG_TRACEROUTE then
                            game.print("[Weight] " .. raw .. ": " .. amt .. " × " .. weight .. " = " .. energy_contrib)
                        end
                    end
                end
            end
        end
    end
    total_energy = (total_energy^1.2) * 100 --expensive
    total_energy = total_energy * 1e6  -- MJ to J
    if not actuallypay then
        if gate.energy < total_energy then
            return false
        else
            return true
        end
    end
    if gate.energy < total_energy then
       -- ei_lib.crystal_echo("☠ [Insufficient Offering] — " .. math.floor(total_energy/1e6) .. " MJ demanded; ritual aborted.", nil, gate, nil, true, nil, true, 30)
        return false
    end

    gate.energy = gate.energy - total_energy
    -- ei_lib.crystal_echo("⚡ [Void Toll Paid] — " .. math.floor(total_energy/1e6) .. " MJ consumed.", nil, gate, nil, true, nil, true, 30)
    return true
end

  

function model.teleport_player(character, gate)

    local player = character.player
    if not player then
        return
    end

    local exit = storage.ei.gate.gate[gate.unit_number].exit

    -- teleport player
    player.teleport({exit.x, exit.y}, exit.surface)

end


function model.update_energy(unit, gate)
    -- if energy below 90% of 50GJ turn off
    if gate.energy < 45 * 1e9 then -- 45 GJ

        if storage.ei.gate.gate[unit].state == true then
            game.print({"exotic-industries.gate-not-enough-energy", gate.position.x, gate.position.y, gate.surface.name})
        end

        storage.ei.gate.gate[unit].state = false
    end

    -- update gui if open
    for _, player in pairs(game.connected_players) do
        local root = player.gui.relative["ei-gate-console"]
        if root then
            local gui_gate_unit = root.tags and root.tags.gate_unit
            if gui_gate_unit == unit then
                local data = model.get_data(gate)
                model.update_gui(player, data, true)
            end
        end
    end

end


function model.create_gate_user_permission_group()

    local group = game.permissions.create_group("gate-user")

    -- disable all
    for action,_ in pairs(defines.input_action) do
        group.set_allows_action(defines.input_action[action], false)
    end

    -- allow movement + items
    group.set_allows_action(defines.input_action.start_walking, true)
    group.set_allows_action(defines.input_action.use_item, true)

end


--RENDERING
-----------------------------------------------------------------------------------------------------

function model.render_exit(gate, box)
    if not gate or not box then
        return
    end

    local gate_unit = gate.unit_number
    local exit = storage.ei.gate.gate[gate_unit].exit
    local animation

    -- check if exit already exists, if at same pos and surface extend time to live
    if storage.ei.gate.gate[gate_unit].exit_animation then

        animation = storage.ei.gate.gate[gate_unit].exit_animation  --[[@as LuaRenderObject]]

        -- check if still valid, might be very old
        if animation.valid then

            -- also test pos and surface  
            local target = animation.target
            local surface = animation.surface
            
            if target.position.x == exit.x and target.position.y == exit.y and surface.name == exit.surface then
                
                -- extend time to live
                animation.time_to_live = 180
                return
            end
        end
    end

    local x_scale = 1
    local y_scale = 1

    if box then
        -- bounding box of container
        -- both x,y = 1 <=> width: 6tiles, height: 5tiles

        local width = math.abs(box.right_bottom.x - box.left_top.x)
        local height = math.abs(box.right_bottom.y - box.left_top.y)

        x_scale = (width / 6) * 1.2
        y_scale = (height / 5) * 1.2
    end

    -- create new exit
    animation = rendering.draw_animation{
        animation = "ei-exit-simple",
        target = {exit.x, exit.y},
        surface = exit.surface,
        render_layer = "object",
        animation_speed = 0.6,
        x_scale = x_scale,
        y_scale = y_scale,
        time_to_live = 180,
    }

    storage.ei.gate.gate[gate_unit].exit_animation = animation
    
end


function model.render_animation(gate)
    local gate_unit = gate.unit_number
    local pick = ei_rng.int("gate_light", 1, 4, gate_unit, game.tick)

    local colors = {
        {r = 0, g = 0.4, b = 1.0},
        {r = 0.4, g = 0.2, b = 1.0},
        {r = 0.2, g = 0.2, b = 1.0},
        {r = 0.4, g = 0.1, b = 0.8},
    }
    local color = colors[pick]

    -- Reuse existing light if valid, otherwise create new
    local light = storage.ei.gate.gate[gate_unit].light
    if light and light.valid then
        light.color = color
        light.time_to_live = ei_ticksPerFullUpdate * 2
    else
        light = rendering.draw_light {
            sprite = "gate_glow",
            scale = 3,
            intensity = 0.2,
            color = color,
            target = gate,
            surface = gate.surface,
            time_to_live = ei_ticksPerFullUpdate * 2,
            blend_mode = "multiplicative",
            apply_runtime_tint = true,
            draw_as_glow = true,
        }
        storage.ei.gate.gate[gate_unit].light = light
    end

    if storage.ei.gate.gate[gate_unit].animation then return end

    local animation = rendering.draw_animation{
        animation = "ei-gate-running",
        target = gate,
        surface = gate.surface,
        render_layer = "object",
        x_scale = 1,
        y_scale = 1
    }

    storage.ei.gate.gate[gate_unit].animation = animation

end


function model.update_renders(unit, gate)

    local state = model.gate_state(gate)
    -- if state true -> check if need to render animation
    -- if state false -> check if need to destroy animation + cleanup

    if not state then
        if storage.ei.gate.gate[unit].animation then
            storage.ei.gate.gate[unit].animation.destroy()
            storage.ei.gate.gate[unit].animation = nil
        end
        if storage.ei.gate.gate[unit].light then
            storage.ei.gate.gate[unit].light.destroy()
            storage.ei.gate.gate[unit].light = nil
        end
    else
        model.render_animation(gate)
    end

end


--GUI
-----------------------------------------------------------------------------------------------------

function model.open_gui(player)

    if player.gui.relative["ei-gate-console"] then
        model.close_gui(player)
    end

    -- Get gate unit for tags
    local gate = model.find_gate(player.opened)
    local gate_unit = gate and gate.unit_number

    local root = player.gui.relative.add{
        type = "frame",
        name = "ei-gate-console",
        anchor = {
            gui = defines.relative_gui_type.container_gui,
            name = "ei-gate-container",
            position = defines.relative_gui_position.right,
        },
        direction = "vertical",
        tags = { gate_unit = gate_unit }
    }

    do -- Titlebar
        local titlebar = root.add{type = "flow", direction = "horizontal"}
        titlebar.add{
            type = "label",
            caption = {"exotic-industries.gate-gui-title"},
            style = "frame_title",
        }

        titlebar.add{
            type = "empty-widget",
            style = "ei_titlebar_nondraggable_spacer",
            ignored_by_interaction = true
        }

        titlebar.add{
            type = "sprite-button",
            sprite = "virtual-signal/informatron",
            tooltip = {"exotic-industries.gui-open-informatron"},
            style = "frame_action_button",
            tags = {
                parent_gui = "ei-gate-console",
                action = "goto-informatron",
                page = "gate"
            }
        }
    end

    local main_container = root.add{
        type = "frame",
        name = "main-container",
        direction = "vertical",
        style = "inside_shallow_frame",
    }

    do -- Status subheader
        main_container.add{
            type = "frame",
            style = "ei_subheader_frame",
        }.add{
            type = "label",
            caption = {"exotic-industries.gate-gui-status-title"},
            style = "subheader_caption_label",
        }
    
        local status_flow = main_container.add{
            type = "flow",
            name = "status-flow",
            direction = "vertical",
            style = "ei_inner_content_flow",
        }

        status_flow.add{
            type = "progressbar",
            name = "energy",
            caption = {"exotic-industries.gate-gui-status-energy", 0},
            tooltip = {"exotic-industries.gate-gui-status-energy-tooltip"},
            style = "ei_status_progressbar"
        }

    end


    do -- Control subheader
        main_container.add{
            type = "frame",
            style = "ei_subheader_frame",
        }.add{
            type = "label",
            caption = {"exotic-industries.gate-gui-control-title"},
            style = "subheader_caption_label",
        }
    
        local control_flow = main_container.add{
            type = "flow",
            name = "control-flow",
            direction = "horizontal",
            style = "ei_inner_content_flow_horizontal",
        }

        local target_flow = control_flow.add{
            type = "flow",
            name = "target-flow",
            direction = "vertical"
        }

        -- Surface
        local dropdown_flow = target_flow.add{
            type = "flow",
            name = "dropdown-flow",
            direction = "vertical"
        }
    
        dropdown_flow.add{
            type = "label",
            caption = {"exotic-industries.gate-gui-control-dropdown-label"},
            tooltip = {"exotic-industries.gate-gui-control-dropdown-label-tooltip"}
        }
        dropdown_flow.add{
            type = "drop-down",
            name = "surface",
            tags = {
                parent_gui = "ei-gate-console",
                action = "set-surface",
                gate_unit = gate_unit
            }
        }

        -- Position
        local position_flow = target_flow.add{
            type = "flow",
            name = "position-flow",
            direction = "vertical"
        }

        position_flow.add{
            type = "label",
            caption = {"exotic-industries.gate-gui-control-position-label"},
            tooltip = {"exotic-industries.gate-gui-control-position-label-tooltip"}
        }
        position_flow.add{
            type = "button",
            name = "position-button",
            caption = {"exotic-industries.gate-gui-control-position-button", 0, 0},
            style = "ei_small_button",
            tags = {
                action = "set-position",
                parent_gui = "ei-gate-console",
                gate_unit = gate_unit
            }
        }

        position_flow.add{
            type = "label",
            caption = {"exotic-industries.gate-gui-control-state-label"},
        }
        position_flow.add{
            type = "button",
            name = "state-button",
            caption = {"exotic-industries.gate-gui-control-state-button", "OFF"},
            tooltip = {"exotic-industries.gate-gui-control-state-button-tooltip"},
            style = "ei_small_red_button",
            tags = {
                action = "set-state",
                parent_gui = "ei-gate-console",
                gate_unit = gate_unit
            }
        }

        -- Target cam
        local camera_frame = control_flow.add{
            type = "frame",
            name = "camera-frame",
            style = "ei_small_camera_frame"
        }
        camera_frame.add{
            type = "camera",
            name = "target-camera",
            position = {0, 0},
            surface_index = 1,
            zoom = 0.25,
            style = "ei_small_camera"
        }

    end

    local data = model.get_data(gate)
    model.update_gui(player, data)

end


function model.update_gui(player, data, ontick)

    if not data then return end
    local root = player.gui.relative["ei-gate-console"]
    if not root then return end

    local status = root["main-container"]["status-flow"]
    local control = root["main-container"]["control-flow"]


    local energy = status["energy"]
    local dropdown = control["target-flow"]["dropdown-flow"]["surface"]
    local position = control["target-flow"]["position-flow"]["position-button"]
    local camera = control["camera-frame"]["target-camera"]
    local state = control["target-flow"]["position-flow"]["state-button"]

    -- Update status
    energy.caption = {"exotic-industries.gate-gui-status-energy", string.format("%.0f", data.energy/1000000)}
    energy.value = data.energy / data.max_energy

    -- if ontick update dont redo user input stuff
    if ontick then return end

    -- Surface dropdown
    local selected_index
    local surface_strings = {}
    for i, possible_surface in pairs(data.surfaces) do
      if game.get_surface(possible_surface) then
        surface_strings[i] = possible_surface
        if data.target_surface == possible_surface then
          selected_index = i
        end
      end
    end
    dropdown.items = surface_strings
    if selected_index then
        dropdown.selected_index = selected_index
    end
    dropdown.tags = {
        parent_gui = "ei-gate-console",
        action = "set-surface",
        surface_list = data.surfaces, -- to get surface later on with index
        gate_unit = dropdown.tags.gate_unit -- preserve gate_unit
    }

    -- Position button
    if data.target_pos and data.target_pos.x and data.target_pos.y then
        position.caption = {"exotic-industries.gate-gui-control-position-button", string.format("%.1f", data.target_pos.x), string.format("%.1f", data.target_pos.y)}
        camera.position = {data.target_pos.x, data.target_pos.y}
    else
        position.caption = {"exotic-industries.gate-gui-control-position-button", string.format("%.1f", 0), string.format("%.1f", 0)}
        camera.position = {0, 0}
    end
    -- Camera


    if not data.target_surface then return end
    if not game.get_surface(data.target_surface) then return end
    
    camera.surface_index = game.get_surface(data.target_surface).index or 1

    -- State button
    if data.state then
        state.style = "ei_small_green_button"
        state.caption = {"exotic-industries.gate-gui-control-state-button", "ON"}
    else
        state.style = "ei_small_red_button"
        state.caption = {"exotic-industries.gate-gui-control-state-button", "OFF"}
    end

end


function model.update_player_guis()
    for _, player in pairs(game.connected_players) do
        local root = player.gui.relative["ei-gate-console"]
        if root then
            local gate_unit = root.tags and root.tags.gate_unit
            if not gate_unit or not storage.ei.gate.gate[gate_unit] then
                model.close_gui(player)
                goto continue
            end

            local gate = storage.ei.gate.gate[gate_unit].gate
            if not gate or not gate.valid then
                model.close_gui(player)
                goto continue
            end

            local data = model.get_data(gate)
            model.update_gui(player, data, true)
        end
        ::continue::
    end

end


function model.update_surface(player, gate_unit)

    if not gate_unit then return end
    if not storage.ei.gate.gate[gate_unit] then return end

    local root = player.gui.relative["ei-gate-console"]
    if not root then return end

    local dropdown = root["main-container"]["control-flow"]["target-flow"]["dropdown-flow"]["surface"]
    local selected_surface = dropdown.tags.surface_list[dropdown.selected_index]

    local gate = storage.ei.gate.gate[gate_unit].gate
    if not gate or not gate.valid then return end

    if not storage.ei.gate.gate[gate_unit].exit then
        storage.ei.gate.gate[gate_unit].exit = {}
    end
    storage.ei.gate.gate[gate_unit].exit.surface = selected_surface

    local data = model.get_data(gate)
    model.update_gui(player, data)

end


function model.toggle_state(player, gate_unit)

    if not gate_unit then return end
    if not storage.ei.gate.gate[gate_unit] then return end

    local gate = storage.ei.gate.gate[gate_unit].gate
    if not gate or not gate.valid then return end

    -- try to toggle state, if not enough energy return
    local energy = gate.energy
    if energy < 1000000000 then
        game.print({"exotic-industries.gate-not-enough-energy", gate.position.x, gate.position.y, gate.surface.name})
    else
        -- toggle state
        storage.ei.gate.gate[gate_unit].state = not storage.ei.gate.gate[gate_unit].state
    end

    -- GUI update is cosmetic — guard against missing GUI
    local root = player.gui.relative["ei-gate-console"]
    if root then
        local data = model.get_data(gate)
        model.update_gui(player, data)
    end

end


function model.choose_position(player, gate_unit)

    if not gate_unit then return end
    if not storage.ei.gate.gate[gate_unit] then return end

    local gate = storage.ei.gate.gate[gate_unit].gate
    if not gate or not gate.valid then return end

    -- if currently a selection is in progress for this player
    if storage.ei.gate.remote and storage.ei.gate.remote[player.index] then return end

    -- Determine target surface and position for remote view
    local gate_data = storage.ei.gate.gate[gate_unit]
    local target_surface_name = gate_data.exit and gate_data.exit.surface or gate.surface.name
    local target_surface = game.get_surface(target_surface_name)
    if not target_surface then target_surface = gate.surface end

    local center_pos = {0, 0}
    if gate_data.exit and gate_data.exit.x then
        center_pos = {gate_data.exit.x, gate_data.exit.y}
    end

    -- Store state
    if not storage.ei.gate.remote then
        storage.ei.gate.remote = {}
    end

    local was_remote = player.controller_type == defines.controllers.remote
    storage.ei.gate.remote[player.index] = {
        gate_unit = gate_unit,
        was_remote = was_remote,
        original_character = not was_remote and player.character or nil
    }

    -- Switch to remote view on target surface
    if not was_remote then
        player.set_controller{type = defines.controllers.remote, surface = target_surface, position = center_pos}
    end

    -- Give player the selection tool
    player.cursor_stack.set_stack({name = "ei-gate-position-selector", count = 1})

    player.print({"exotic-industries.gate-position-selection-instructions"})

end


function model.get_data(gate)

    if not gate then return end

    local data = {}
    if gate.electric_buffer_size then
        data.max_energy = gate.electric_buffer_size
    end
    if gate.energy then
        data.energy = gate.energy
    else
        data.energy = 0
    end

    -- get list of all surfaces
    local surfaces = {}
    for i,v in pairs(game.surfaces) do
        table.insert(surfaces, v.name)
    end
    data.surfaces = surfaces

    local exit = storage.ei.gate.gate[gate.unit_number].exit
    if exit then
        if exit.surface then data.target_surface = exit.surface end
        if exit.x and exit.y then data.target_pos = {x = exit.x, y = exit.y} end
    end
    if storage.ei.gate.gate[gate.unit_number].state then
        data.state = storage.ei.gate.gate[gate.unit_number].state
    end

    return data

end


function model.change_permission(player, new_group, old_group)

    new_group = new_group or "Default"
    old_group = old_group or "Default"

    if not game.permissions.get_group(new_group) then
        -- print error
        game.print("Error: Permission group '" .. new_group .. "' does not exist!")
        return
    end

    if not game.permissions.get_group(old_group) then
        -- print error
        game.print("Error: Permission group '" .. old_group .. "' does not exist!")
        return
    end

    player.permission_group = game.permissions.get_group(new_group)

end

--[[
function model.update_player_permissions()

    if not script.active_mods["RemoteConfiguration"] then
        return
    end

    if not storage.ei.gate.gate_user_permission then
        return
    end

    for player_id,tick in pairs(storage.ei.gate.gate_user_permission) do
        if game.tick > tick then
            local player = game.get_player(player_id)
            if player then
                player.permission_group = game.permissions.get_group("gate-user")
            end
            storage.ei.gate.gate_user_permission[player_id] = nil
        end
    end

end
]]

--HANDLERS
-----------------------------------------------------------------------------------------------------

function model.on_built_entity(entity)

    if model.entity_check(entity) == false then
        return
    end

    if entity.name == "ei-gate" then
        model.make_gate(entity)
    end

end


function model.on_destroyed_entity(entity, transfer)

    if model.entity_check(entity) == false then
        return
    end

    if entity.name ~= "ei-gate" and entity.name ~= "ei-gate-container" then
        return
    end

    if not model.transfer_valid(transfer) then
        return
    end

    if entity.name == "ei-gate" then

        model.destroy_gate(entity, nil)
        return

    end

    -- normaly gate gets mined/destroyed first
    if entity.name == "ei-gate-container" then

        model.destroy_gate(nil, entity)
        return

    end

end


function model.update()

    if not storage.ei.gate then
        return false
    end

    if not storage.ei.gate.gate then
        return false
    end

    -- Initialize remote table for existing saves (before multiplayer fix)
    if not storage.ei.gate.remote then
        storage.ei.gate.remote = {}
    end

    model.update_player_guis()
    -- fixed in remote-config
    -- model.update_player_permissions()

    -- gate loop


    -- if no current break point then try to make a new one
    if not storage.ei.gate.gate_break_point and next(storage.ei.gate.gate) then
       storage.ei.gate.gate_break_point,_ = next(storage.ei.gate.gate)
    end

    -- if no current break point then return
    if not storage.ei.gate.gate_break_point then
        return false
    end

    -- get current break point
    local break_id = storage.ei.gate.gate_break_point
    if break_id and storage.ei.gate.gate and storage.ei.gate.gate[break_id] then
        local gate = storage.ei.gate.gate[break_id].gate
        if gate then
            model.check_for_teleport(break_id, gate)
            model.update_renders(break_id, gate)
            model.update_energy(break_id, gate)
        end
    end

    -- get next break point
    if next(storage.ei.gate.gate, break_id) then
        storage.ei.gate.gate_break_point,_ = next(storage.ei.gate.gate, break_id)
        return true
    else
       storage.ei.gate.gate_break_point = nil
       return false
    end

end

function model.used_remote(event)

    local position = event.target_position
    local surface = game.get_surface(event.surface_index)

    -- Identify the player from the source entity (the character that threw the capsule)
    if not event.source_entity or not event.source_entity.valid then return end
    local player = event.source_entity.player
    if not player then return end

    local player_index = player.index
    if not storage.ei.gate.remote or not storage.ei.gate.remote[player_index] then return end

    local gate_unit = storage.ei.gate.remote[player_index].gate_unit
    if not gate_unit then return end

    -- Set the gate exit position
    if storage.ei.gate.gate[gate_unit] then
        if not model.find_container(storage.ei.gate.gate[gate_unit].gate, surface, position, true) then
            storage.ei.gate.gate[gate_unit].exit = {
                surface = surface.name,
                x = position.x,
                y = position.y
            }
        end
    end

    -- Cleanup
    storage.ei.gate.remote[player_index] = nil

end


function model.on_player_selected_area(event)
    if event.item ~= "ei-gate-position-selector" then return end

    local player_index = event.player_index
    if not storage.ei.gate.remote or not storage.ei.gate.remote[player_index] then return end

    local gate_unit = storage.ei.gate.remote[player_index].gate_unit
    if not gate_unit then
        model.cleanup_position_selection(player_index)
        return
    end

    -- Calculate center of selection area (single-click = tiny area, center ≈ click pos)
    local area = event.area
    local position = {
        x = (area.left_top.x + area.right_bottom.x) / 2,
        y = (area.left_top.y + area.right_bottom.y) / 2
    }
    local surface = event.surface

    -- Set the gate exit position
    if storage.ei.gate.gate[gate_unit] then
        if not model.find_container(storage.ei.gate.gate[gate_unit].gate, surface, position, true) then
            storage.ei.gate.gate[gate_unit].exit = {
                surface = surface.name,
                x = position.x,
                y = position.y
            }
        end
    end

    model.cleanup_position_selection(player_index)
end


function model.cleanup_position_selection(player_index)
    if not storage.ei.gate.remote then return end
    local remote_data = storage.ei.gate.remote[player_index]
    if not remote_data then return end

    local player = game.get_player(player_index)
    if player then
        -- Clear selection tool from cursor if still held
        if player.cursor_stack and player.cursor_stack.valid_for_read
           and player.cursor_stack.name == "ei-gate-position-selector" then
            player.cursor_stack.clear()
        end

        -- Exit remote view if we entered it
        if not remote_data.was_remote and player.controller_type == defines.controllers.remote then
            local character = remote_data.original_character
            if character and character.valid then
                player.set_controller{type = defines.controllers.character, character = character}
            elseif player.character and player.character.valid then
                player.set_controller{type = defines.controllers.character, character = player.character}
            else
                player.set_controller{type = defines.controllers.character}
                log("[ESI:R gate] cleanup: no valid character for player " .. player.name .. ", created new one")
            end
        end
    end

    storage.ei.gate.remote[player_index] = nil
end


--GUI HANDLER
-----------------------------------------------------------------------------------------------------

function model.on_gui_selection_state_changed(event)
    local tags = event.element.tags

    if tags.action == "set-surface" then
        model.update_surface(game.get_player(event.player_index), tags.gate_unit)
    end
end


function model.close_gui(player)
    if player.gui.relative["ei-gate-console"] then
        player.gui.relative["ei-gate-console"].destroy()
    end
end


function model.on_gui_opened(event)
    model.open_gui(game.get_player(event.player_index))
end


function model.on_gui_click(event)
    local tags = event.element.tags
    local gate_unit = tags.gate_unit

    if tags.action == "set-state" then
        model.toggle_state(game.get_player(event.player_index), gate_unit)
        return
    end

    if tags.action == "set-position" then
        model.choose_position(game.get_player(event.player_index), gate_unit)
        return
    end

    if tags.action == "goto-informatron" then
        local player = game.get_player(event.player_index)
        if player and player.force.technologies["ei-gate"].enabled == true then
            remote.call("informatron", "informatron_open_to_page", {
                player_index = event.player_index,
                interface = "exotic-industries-informatron",
                page_name = tags.page
            })
            return
        end
    end
end


function model.on_player_left_game(player_index)
    if not storage.ei.gate then return end
    if not storage.ei.gate.remote then return end
    if not storage.ei.gate.remote[player_index] then return end

    -- Only clear cursor and storage, skip controller restoration (Factorio handles player state on disconnect)
    local player = game.get_player(player_index)
    if player then
        if player.cursor_stack and player.cursor_stack.valid_for_read
           and player.cursor_stack.name == "ei-gate-position-selector" then
            player.cursor_stack.clear()
        end
    end
    storage.ei.gate.remote[player_index] = nil
end


function model.on_player_cursor_stack_changed(event)
    if not storage.ei.gate then return end
    if not storage.ei.gate.remote then return end

    local player_index = event.player_index
    local remote_data = storage.ei.gate.remote[player_index]
    if not remote_data then return end

    local player = game.get_player(player_index)
    if not player then
        storage.ei.gate.remote[player_index] = nil
        return
    end

    -- If cursor no longer holds the gate position selector, clean up
    if not player.cursor_stack or not player.cursor_stack.valid_for_read
       or player.cursor_stack.name ~= "ei-gate-position-selector" then
        model.cleanup_position_selection(player_index)
    end
end

return model
-- TODO:
-- have gates that turned off due to power restart when power is back?
-- allow logistic chests as endpoints?
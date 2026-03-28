local model = {}
ei_rng = require("lib/rng")
local ei_lib = require("lib/lib")

local LOW_POWER_J = 45 * 1e9
local SIGNAL_GATE_DESTINATION = {type = "virtual", name = "signal-D", quality = "normal"}
local SIGNAL_GATE_ENABLE = {type = "virtual", name = "signal-E", quality = "normal"}
local SIGNAL_RECEIVER_ID = {type = "virtual", name = "signal-I", quality = "normal"}
local SIGNAL_GATE_ACTIVE = {type = "virtual", name = "ei-gate-active", quality = "normal"}
local SIGNAL_GATE_ENERGY = {type = "virtual", name = "ei-gate-energy", quality = "normal"}
local SIGNAL_GATE_STRESS = {type = "virtual", name = "ei-gate-stress", quality = "normal"}
local GATE_WIRE_PROXY_NAME = "ei-gate-circuit-interface"
local GATE_WIRE_PROXY_OFFSET = {x = 0, y = 0.75}
local MAX_GATE_STRESS = 100
local MAX_RECEIVER_SATURATION = 100
local RESIDUE_THRESHOLD = 250
local STRESS_DECAY_PER_SECOND = 1
local RECEIVER_SATURATION_DECAY_PER_SECOND = 1.5
local GATE_ARMED_UPKEEP_W = 30 * 1e6
local GATE_STRESS_UPKEEP_W = 1.5 * 1e6
local GATE_COOLDOWN_UPKEEP_W = 30 * 1e6

--====================================================================================================
-- GATE
--====================================================================================================
-- Runtime overview:
-- - `ei-gate` is the invisible EEI and main energy store.
-- - `ei-gate-container` is the visible source inventory, GUI anchor, and circuit input point.
-- - `ei-gate-circuit-interface` is the hidden constant combinator that exports telemetry.
-- - `ei-gate-receiver` is the explicit destination endpoint for all new routing.
--
-- The gate should behave like an expensive burst-transfer device, not a passive logistics
-- backbone. The control script therefore layers three concerns on top of basic transport:
-- route resolution, transfer quoting/payment, and post-transfer penalties.

-- Legacy compatibility for older call sites that still ask for a "player" energy toll.
model.energy_costs = {
    ["player"] = 10,
    ["item"] = 1
}

-- Legacy raw surface pairing is kept only so pre-receiver saves still load and function until
-- the player explicitly migrates that gate to a receiver ID.
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

-- File map:
-- - receiver registry + circuit ID refresh
-- - target resolution and transport gating
-- - quoted transfer cost, stress, cooldown, residue, and scripted upkeep
-- - GUI and remote helpers

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

    if not storage.ei.gate.receiver then
        storage.ei.gate.receiver = {}
    end

    if not storage.ei.gate.receiver_by_force then
        storage.ei.gate.receiver_by_force = {}
    end

    if not storage.ei.gate.remote then
        storage.ei.gate.remote = {}
    end

    if not storage.ei.gate.open_redirect then
        storage.ei.gate.open_redirect = {}
    end

    if storage.ei.gate.receiver_registry_dirty == nil then
        storage.ei.gate.receiver_registry_dirty = false
    end

end


local function clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end
    if value > maximum then
        return maximum
    end
    return value
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


function model.copy_exit(exit)

    if not exit then
        return nil
    end

    return {
        surface = exit.surface,
        x = exit.x,
        y = exit.y
    }

end


local function try_get_stack_field(item_stack, getter)
    local ok, value = pcall(getter, item_stack)
    if ok then
        return value
    end

    return nil
end


local function copy_localised_string(value)
    if type(value) == "table" then
        return table.deepcopy(value)
    end

    return value
end


function model.make_item_with_quality_id(item_stack)
    if not item_stack or not item_stack.valid_for_read then
        return nil
    end

    local item_with_quality = {
        name = item_stack.name
    }

    local quality = try_get_stack_field(item_stack, function(stack)
        local stack_quality = stack.quality
        return stack_quality and stack_quality.name or nil
    end)
    if quality then
        item_with_quality.quality = quality
    end

    return item_with_quality
end


function model.make_item_stack_definition(item_stack, count)
    if not item_stack or not item_stack.valid_for_read then
        return nil
    end

    local stack_definition = {
        name = item_stack.name,
        count = count or item_stack.count
    }

    local quality = item_stack.quality
    if quality and quality.name then
        stack_definition.quality = quality.name
    end

    local health = try_get_stack_field(item_stack, function(stack) return stack.health end)
    if health ~= nil then
        stack_definition.health = health
    end

    local durability = try_get_stack_field(item_stack, function(stack) return stack.durability end)
    if durability ~= nil then
        stack_definition.durability = durability
    end

    local ammo = try_get_stack_field(item_stack, function(stack) return stack.ammo end)
    if ammo ~= nil then
        stack_definition.ammo = ammo
    end

    local spoil_percent = try_get_stack_field(item_stack, function(stack) return stack.spoil_percent end)
    if spoil_percent ~= nil then
        stack_definition.spoil_percent = spoil_percent
    end

    local tags = try_get_stack_field(item_stack, function(stack) return stack.tags end)
    if tags ~= nil then
        stack_definition.tags = table.deepcopy(tags)
    end

    local custom_description = try_get_stack_field(item_stack, function(stack) return stack.custom_description end)
    if custom_description ~= nil then
        stack_definition.custom_description = copy_localised_string(custom_description)
    end

    return stack_definition
end


function model.ensure_gate_defaults(gate_unit, event)

    local gate_data = storage.ei.gate.gate[gate_unit]
    if not gate_data then
        return nil
    end

    if gate_data.manual_enabled == nil then
        gate_data.manual_enabled = gate_data.state == true
    end

    if gate_data.manual_receiver_id ~= nil then
        gate_data.manual_receiver_id = tonumber(gate_data.manual_receiver_id)
        if gate_data.manual_receiver_id then
            gate_data.manual_receiver_id = math.floor(gate_data.manual_receiver_id)
        end
        if not gate_data.manual_receiver_id or gate_data.manual_receiver_id < 1 then
            gate_data.manual_receiver_id = nil
        end
    end

    if gate_data.legacy_exit == nil and gate_data.exit then
        gate_data.legacy_exit = model.copy_exit(gate_data.exit)
    end

    if gate_data.last_low_power == nil then
        gate_data.last_low_power = false
    end

    if gate_data.stress == nil then
        gate_data.stress = 0
    end

    if gate_data.cooldown_until_tick == nil then
        gate_data.cooldown_until_tick = 0
    end

    if gate_data.residue_progress == nil then
        gate_data.residue_progress = 0
    end

    if gate_data.last_energy_tick == nil then
        gate_data.last_energy_tick = ei_lib.get_event_tick(event)
    end

    if gate_data.wire_proxy ~= nil and model.entity_check(gate_data.wire_proxy) == false then
        gate_data.wire_proxy = nil
        gate_data.wire_proxy_connected = nil
    end

    if gate_data.signal_cache ~= nil and type(gate_data.signal_cache) ~= "table" then
        gate_data.signal_cache = nil
    end

    if gate_data.last_signal_update_tick == nil then
        gate_data.last_signal_update_tick = -60
    end

    if gate_data.wire_proxy_wired == nil then
        gate_data.wire_proxy_wired = false
    end

    gate_data.state = gate_data.manual_enabled

    return gate_data

end


function model.get_lowest_free_receiver_id(force_index, skip_unit)

    local used = {}

    for unit, data in pairs(storage.ei.gate.receiver) do
        if unit ~= skip_unit then
            local receiver = data.entity
            if model.entity_check(receiver) and receiver.force.index == force_index then
                local auto_id = tonumber(data.auto_id)
                if auto_id and auto_id > 0 then
                    used[math.floor(auto_id)] = true
                end
            end
        end
    end

    local next_id = 1
    while used[next_id] do
        next_id = next_id + 1
    end

    return next_id

end


function model.ensure_receiver_defaults(receiver_unit, event)

    local receiver_data = storage.ei.gate.receiver[receiver_unit]
    if not receiver_data then
        return nil
    end

    local receiver = receiver_data.entity
    if not model.entity_check(receiver) then
        return nil
    end

    local force_index = receiver.force.index
    local auto_id = tonumber(receiver_data.auto_id)

    if not auto_id or auto_id < 1 or receiver_data.force_index ~= force_index then
        receiver_data.auto_id = model.get_lowest_free_receiver_id(force_index, receiver_unit)
    else
        receiver_data.auto_id = math.floor(auto_id)
    end

    receiver_data.force_index = force_index
    receiver_data.effective_id = receiver_data.effective_id or receiver_data.auto_id
    receiver_data.conflict = false

    if receiver_data.saturation == nil then
        receiver_data.saturation = 0
    end

    if receiver_data.residue_progress == nil then
        receiver_data.residue_progress = 0
    end

    if receiver_data.last_penalty_tick == nil then
        receiver_data.last_penalty_tick = ei_lib.get_event_tick(event)
    end

    return receiver_data

end


function model.register_receiver(receiver, event)

    model.check_global_init()

    local unit = receiver and receiver.unit_number
    if not unit then
        return
    end

    storage.ei.gate.receiver[unit] = storage.ei.gate.receiver[unit] or {}
    storage.ei.gate.receiver[unit].entity = receiver
    model.ensure_receiver_defaults(unit, event)
    model.refresh_receivers(event)

end


function model.destroy_receiver(receiver, event)

    model.check_global_init()

    local unit = receiver and receiver.unit_number
    if not unit then
        return
    end

    storage.ei.gate.receiver[unit] = nil
    model.refresh_receivers(event)

end


function model.get_signal_value(entity, signal)
    local seen_networks = {}
    local total = 0

    local function add_entity_signal(source)
        if not model.entity_check(source) then
            return
        end

        local ok, connectors = pcall(source.get_wire_connectors, false)
        if not ok or type(connectors) ~= "table" then
            return
        end

        for connector_id, connector in pairs(connectors) do
            if connector and connector.valid then
                local network_ok, network = pcall(source.get_circuit_network, connector_id)
                if network_ok and network and not seen_networks[network.network_id] then
                    seen_networks[network.network_id] = true

                    local signal_ok, value = pcall(network.get_signal, signal)
                    if signal_ok and value then
                        total = total + value
                    end
                end
            end
        end
    end

    if not model.entity_check(entity) then
        return 0
    end

    add_entity_signal(entity)
    return total

end


local function get_gate_wire_proxy_position(gate)
    return {
        x = gate.position.x + GATE_WIRE_PROXY_OFFSET.x,
        y = gate.position.y + GATE_WIRE_PROXY_OFFSET.y
    }
end


function model.get_gate_signal_value(gate_data, signal)
    if not gate_data then
        return 0
    end

    local seen_networks = {}
    local total = 0

    local function add_entity_signal(source)
        if not model.entity_check(source) then
            return
        end

        local ok, connectors = pcall(source.get_wire_connectors, false)
        if not ok or type(connectors) ~= "table" then
            return
        end

        for connector_id, connector in pairs(connectors) do
            if connector and connector.valid then
                local network_ok, network = pcall(source.get_circuit_network, connector_id)
                if network_ok and network and not seen_networks[network.network_id] then
                    seen_networks[network.network_id] = true

                    local signal_ok, value = pcall(network.get_signal, signal)
                    if signal_ok and value then
                        total = total + value
                    end
                end
            end
        end
    end

    add_entity_signal(gate_data.container)
    add_entity_signal(gate_data.wire_proxy)

    return total

end


function model.measure_transfer_burden(entries)
    local total_burden = 0

    for _, entry in ipairs(entries) do
        if type(entry) == "string" and entry == "player" then
            total_burden = total_burden + model.energy_costs.player
        elseif type(entry) == "table" and entry.name and entry.count then
            local count = tonumber(entry.count) or 0
            if count > 0 then
                total_burden = total_burden + ((model.mass_weights[entry.name] or 1) * count)
            end
        end
    end

    return total_burden
end


-- Convert the mass-table burden into the actual joule toll charged to the gate. The curve is
-- intentionally superlinear so bulk cargo becomes increasingly unattractive compared to normal
-- logistics once the gate is unlocked.
function model.energy_from_burden(burden)
    if not burden or burden <= 0 then
        return 0
    end

    return (burden ^ 1.2) * 100 * 1e6
end


-- Quote once from the amount we can actually move this update. The quote is then reused for:
-- - affordability checks
-- - final payment
-- - stress / cooldown / residue penalties
-- Keeping these values together avoids the old mismatch where the gate could reason about one
-- transfer size and end up paying for a different one.
function model.quote_transfer(entries)
    local total_count = 0
    for _, entry in ipairs(entries) do
        if type(entry) == "table" and entry.count then
            total_count = total_count + (tonumber(entry.count) or 0)
        end
    end

    local burden = model.measure_transfer_burden(entries)

    return {
        count = total_count,
        burden = burden,
        energy_j = model.energy_from_burden(burden),
        stress_delta = math.min(25, math.sqrt(math.max(burden, 0))),
        saturation_delta = math.min(20, math.sqrt(math.max(burden, 0)) * 0.8),
        residue_delta = burden,
    }
end


function model.can_pay_quote(gate, quote)
    return model.entity_check(gate) and quote and gate.energy >= (quote.energy_j or 0)
end


function model.commit_quote(gate, quote)
    if not quote then
        return false
    end

    if not model.can_pay_quote(gate, quote) then
        ei_lib.crystal_echo_floating("☠ [Insufficient Offering] — " .. math.floor((quote.energy_j or 0)/1e6) .. " MJ demanded; ritual aborted.", gate, 60, "serenity")
        return false
    end

    gate.energy = math.max(0, gate.energy - (quote.energy_j or 0))
    ei_lib.crystal_echo_floating("⚡ [Void Toll Paid] — " .. math.floor((quote.energy_j or 0)/1e6) .. " MJ consumed.", gate, 60, "wrath")
    return true
end


-- A successful transfer hurts both ends of the route:
-- - the source gate takes stress and cooldown
-- - the receiver takes saturation
-- - the route sheds breach residue once enough burden has accumulated
function model.apply_transfer_penalties(gate, gate_data, receiver_data, quote, event)
    if not gate_data or not quote then
        return
    end

    gate_data.stress = clamp((gate_data.stress or 0) + (quote.stress_delta or 0), 0, MAX_GATE_STRESS)
    gate_data.residue_progress = (gate_data.residue_progress or 0) + (quote.residue_delta or 0)

    if receiver_data then
        receiver_data.saturation = clamp((receiver_data.saturation or 0) + (quote.saturation_delta or 0), 0, MAX_RECEIVER_SATURATION)
        receiver_data.residue_progress = (receiver_data.residue_progress or 0) + (quote.residue_delta or 0)
        receiver_data.last_penalty_tick = ei_lib.get_event_tick(event)
    end

    local tick = ei_lib.get_event_tick(event)
    local cooldown_ticks = 30
        + math.floor(math.sqrt(math.max(quote.burden or 0, 0)) * 15)
        + math.floor((gate_data.stress or 0) * 2)
    gate_data.cooldown_until_tick = math.max(gate_data.cooldown_until_tick or 0, tick + cooldown_ticks)

    local residue_count = math.floor((gate_data.residue_progress or 0) / RESIDUE_THRESHOLD)
    if residue_count > 0 then
        gate_data.residue_progress = (gate_data.residue_progress or 0) - (residue_count * RESIDUE_THRESHOLD)
        local receiver_entity = receiver_data and receiver_data.entity or nil
        model.emit_breach_residue(gate, gate_data, receiver_entity, residue_count)
    end
end


function model.get_effective_receiver_data(gate_data, event)
    if not gate_data or gate_data.effective_target_type ~= "receiver" then
        return nil
    end

    local receiver = gate_data.effective_target_entity
    if not model.entity_check(receiver) then
        return nil
    end

    local receiver_data = storage.ei.gate.receiver[receiver.unit_number]
    if not receiver_data then
        return nil
    end

    return model.ensure_receiver_defaults(receiver.unit_number, event)
end


function model.is_receiver_saturated(receiver_data)
    return receiver_data and (receiver_data.saturation or 0) >= MAX_RECEIVER_SATURATION
end


-- "Armed" is the state exposed to circuits. The gate must be manually/circuit enabled, have a
-- resolved destination, and sit above the low-power floor before it should accept work.
function model.is_gate_armed(gate, gate_data)
    gate_data = gate_data or (gate and storage.ei.gate.gate[gate.unit_number])

    if not model.entity_check(gate) or not gate_data then
        return false
    end

    if not gate_data.effective_enabled then
        return false
    end

    if not model.entity_check(gate_data.effective_target_entity) then
        return false
    end

    if gate.energy < LOW_POWER_J then
        return false
    end

    return true
end


-- This is stricter than "armed": cooldown and receiver saturation both pause transport, but they
-- do not necessarily mean the gate should reject further insertion or report itself as unpowered.
function model.can_gate_transport(gate, gate_data, receiver_data, event)
    gate_data = gate_data or (gate and storage.ei.gate.gate[gate.unit_number])
    receiver_data = receiver_data or model.get_effective_receiver_data(gate_data, event)

    if not model.is_gate_armed(gate, gate_data) then
        return false
    end

    if (gate_data.cooldown_until_tick or 0) > ei_lib.get_event_tick(event) then
        return false
    end

    if model.is_receiver_saturated(receiver_data) then
        return false
    end

    return true
end


-- Input locking is reserved for truly inactive states where buffering more cargo is misleading:
-- disabled, unresolved, or below the minimum operating energy floor.
function model.should_lock_input(gate, gate_data)
    gate_data = gate_data or (gate and storage.ei.gate.gate[gate.unit_number])

    if not model.entity_check(gate) or not gate_data then
        return true
    end

    if not gate_data.effective_enabled then
        return true
    end

    if not model.entity_check(gate_data.effective_target_entity) then
        return true
    end

    if gate.energy < LOW_POWER_J then
        return true
    end

    return false
end


function model.decay_gate_penalties(gate_data, elapsed_ticks, event)
    if not gate_data or elapsed_ticks <= 0 then
        return
    end

    local decay = (elapsed_ticks / 60) * STRESS_DECAY_PER_SECOND
    gate_data.stress = clamp((gate_data.stress or 0) - decay, 0, MAX_GATE_STRESS)

    if (gate_data.cooldown_until_tick or 0) <= ei_lib.get_event_tick(event) then
        gate_data.cooldown_until_tick = 0
    end
end


function model.decay_receiver_penalties(receiver_data, elapsed_ticks)
    if not receiver_data or elapsed_ticks <= 0 then
        return
    end

    local decay = (elapsed_ticks / 60) * RECEIVER_SATURATION_DECAY_PER_SECOND
    receiver_data.saturation = clamp((receiver_data.saturation or 0) - decay, 0, MAX_RECEIVER_SATURATION)
end


-- Residue is first treated as inventory clutter so automation can clean it up. Only when neither
-- endpoint can accept it do we spill it into the world.
function model.emit_breach_residue(gate, gate_data, receiver_entity, residue_count)
    if residue_count <= 0 or not model.entity_check(gate) or not gate_data then
        return
    end

    local remaining = residue_count
    local source_inv = model.entity_check(gate_data.container) and gate_data.container.get_inventory(defines.inventory.chest) or nil
    local receiver_inv = model.entity_check(receiver_entity) and receiver_entity.get_inventory(defines.inventory.chest) or nil

    if source_inv then
        remaining = remaining - source_inv.insert({name = "ei-breach-residue", count = remaining})
    end

    if remaining > 0 and receiver_inv then
        remaining = remaining - receiver_inv.insert({name = "ei-breach-residue", count = remaining})
    end

    if remaining > 0 then
        gate.surface.spill_item_stack{
            position = gate.position,
            stack = {name = "ei-breach-residue", count = remaining},
            enable_looted = true,
            force = gate.force
        }
    end
end


function model.update_input_lock(gate, gate_data)
    gate_data = gate_data or (gate and storage.ei.gate.gate[gate.unit_number])
    if not gate_data or not model.entity_check(gate_data.container) then
        return
    end

    local inventory = gate_data.container.get_inventory(defines.inventory.chest)
    if not inventory then
        return
    end

    local bar = model.should_lock_input(gate, gate_data) and 0 or (#inventory + 1)
    local ok = pcall(inventory.set_bar, bar)
    if not ok and bar == 0 then
        pcall(inventory.set_bar, 1)
    end
end


function model.destroy_wire_proxy(gate_unit)
    local gate_data = storage.ei.gate.gate[gate_unit]
    if not gate_data then
        return
    end

    local proxy = gate_data.wire_proxy
    if model.entity_check(proxy) then
        proxy.destroy({raise_destroy = false})
    end

    gate_data.wire_proxy = nil
    gate_data.wire_proxy_connected = nil
    gate_data.signal_cache = nil
end


-- The visible gate container is the player-facing circuit endpoint. The hidden proxy is only a
-- script-owned signal source, so it must be physically bridged into the container's red/green
-- networks for players to see telemetry on the same wires they already use for control input.
local function connector_targets_match(source, target)
    if not source or not source.valid or not target or not target.valid then
        return false
    end

    for _, connection in ipairs(source.real_connections) do
        local target_connection = connection.target
        if target_connection
        and target_connection.valid
        and target_connection.owner == target.owner
        and target_connection.wire_connector_id == target.wire_connector_id then
            return true
        end
    end

    return false
end


local function ensure_internal_wire(source_entity, source_id, target_entity, target_id)
    local source = source_entity.get_wire_connector(source_id, true)
    local target = target_entity.get_wire_connector(target_id, true)

    if not source or not source.valid or not target or not target.valid then
        return false
    end

    if connector_targets_match(source, target) then
        return true
    end

    local ok, connected = pcall(
        source.connect_to,
        target,
        false,
        defines.wire_origin.script
    )

    if not ok then
        return false
    end

    if connected then
        return true
    end

    return connector_targets_match(source, target)
end


local function resolve_wire_connector_id(entity, preferred_ids)
    if not model.entity_check(entity) then
        return nil
    end

    local ok, connectors = pcall(entity.get_wire_connectors, false)
    if not ok or type(connectors) ~= "table" then
        return nil
    end

    for _, connector_id in ipairs(preferred_ids) do
        local connector = connectors[connector_id]
        if connector and connector.valid then
            return connector_id
        end
    end

    return nil
end


local function connector_has_external_peer(connector, ignored_owner)
    if not connector or not connector.valid then
        return false
    end

    for _, connection in ipairs(connector.real_connections) do
        local peer = connection.target
        if peer and peer.valid and peer.owner ~= ignored_owner then
            return true
        end
    end

    return false
end


function model.is_wire_proxy_externally_wired(gate_data)
    if not gate_data then
        return false
    end

    local container = gate_data.container
    local proxy = gate_data.wire_proxy
    if model.entity_check(container) == false or model.entity_check(proxy) == false then
        return false
    end

    local ok, container_connectors = pcall(container.get_wire_connectors, false)
    if ok and type(container_connectors) == "table" then
        for _, connector in pairs(container_connectors) do
            if connector_has_external_peer(connector, proxy) then
                return true
            end
        end
    end

    local proxy_ok, proxy_connectors = pcall(proxy.get_wire_connectors, false)
    if proxy_ok and type(proxy_connectors) == "table" then
        for _, connector in pairs(proxy_connectors) do
            if connector_has_external_peer(connector, container) then
                return true
            end
        end
    end

    return false
end


function model.attach_wire_proxy_to_container(gate_data)
    if not gate_data then
        return false
    end

    local proxy = gate_data.wire_proxy
    local container = gate_data.container
    if model.entity_check(proxy) == false or model.entity_check(container) == false then
        return false
    end

    local proxy_red_id = resolve_wire_connector_id(proxy, {
        defines.wire_connector_id.combinator_output_red,
        defines.wire_connector_id.circuit_red,
        defines.wire_connector_id.combinator_input_red,
    })
    local proxy_green_id = resolve_wire_connector_id(proxy, {
        defines.wire_connector_id.combinator_output_green,
        defines.wire_connector_id.circuit_green,
        defines.wire_connector_id.combinator_input_green,
    })

    if not proxy_red_id or not proxy_green_id then
        gate_data.wire_proxy_connected = false
        return false
    end

    local red_connected = ensure_internal_wire(
        container,
        defines.wire_connector_id.circuit_red,
        proxy,
        proxy_red_id
    )
    local green_connected = ensure_internal_wire(
        container,
        defines.wire_connector_id.circuit_green,
        proxy,
        proxy_green_id
    )

    local connected = red_connected and green_connected
    gate_data.wire_proxy_connected = connected
    gate_data.signal_cache = nil
    return connected
end


function model.ensure_wire_proxy(gate_unit)
    local gate_data = storage.ei.gate.gate[gate_unit]
    if not gate_data then
        return nil
    end

    local gate = gate_data.gate
    if not model.entity_check(gate) then
        return nil
    end

    local expected_position = get_gate_wire_proxy_position(gate)

    local proxy = gate_data.wire_proxy
    if model.entity_check(proxy) then
        if math.abs(proxy.position.x - expected_position.x) > 0.01
        or math.abs(proxy.position.y - expected_position.y) > 0.01 then
            pcall(proxy.teleport, expected_position)
        end
        if gate_data.wire_proxy_connected ~= true then
            model.attach_wire_proxy_to_container(gate_data)
        end
        return proxy
    end

    local ok, created_proxy = pcall(
        gate.surface.create_entity,
        {
            name = GATE_WIRE_PROXY_NAME,
            position = expected_position,
            force = gate.force,
            create_build_effect_smoke = false,
            raise_built = false,
        }
    )
    proxy = ok and created_proxy or nil

    if model.entity_check(proxy) == false then
        return nil
    end

    gate_data.wire_proxy = proxy
    gate_data.wire_proxy_connected = nil
    gate_data.signal_cache = nil
    model.attach_wire_proxy_to_container(gate_data)

    return proxy
end


-- The wire proxy mirrors only a tiny summary of the gate state so circuit logic can react without
-- poking at internal storage: armed flag, stored MJ, and stress.
function model.update_wire_proxy_signals(gate, gate_data, event)
    gate_data = gate_data or (gate and storage.ei.gate.gate[gate.unit_number])
    if not model.entity_check(gate) or not gate_data then
        return
    end

    local proxy = model.ensure_wire_proxy(gate.unit_number)
    if model.entity_check(proxy) == false then
        return
    end

    local externally_wired = model.is_wire_proxy_externally_wired(gate_data)
    if not externally_wired then
        if gate_data.wire_proxy_wired then
            local control = proxy.get_control_behavior()
            if control and control.valid then
                control.enabled = false

                local section = control.get_section(1)
                if section then
                    for i = 1, section.filters_count do
                        section.clear_slot(i)
                    end
                end
            end

            gate_data.signal_cache = nil
        end

        gate_data.wire_proxy_wired = false
        return
    end

    gate_data.wire_proxy_wired = true

    local current_tick = ei_lib.get_event_tick(event)
    if gate_data.signal_cache and current_tick < ((gate_data.last_signal_update_tick or -60) + 60) then
        return
    end

    local active = model.is_gate_armed(gate, gate_data) and 1 or 0
    local energy = math.max(0, math.floor(((gate.energy or 0) / 1e6) + 0.5))
    local stress = math.max(0, math.floor((gate_data.stress or 0) + 0.5))

    if gate_data.signal_cache
    and gate_data.signal_cache.active == active
    and gate_data.signal_cache.energy == energy
    and gate_data.signal_cache.stress == stress then
        return
    end

    local control = proxy.get_control_behavior()
    if not control or not control.valid then
        return
    end

    control.enabled = true

    local section = control.get_section(1)
    if not section then
        section = control.add_section("gate")
    end

    if not section then
        return
    end

    section.active = true

    for i = 1, section.filters_count do
        section.clear_slot(i)
    end

    section.set_slot(1, {value = SIGNAL_GATE_ACTIVE, min = active})

    if energy ~= 0 then
        section.set_slot(2, {value = SIGNAL_GATE_ENERGY, min = energy})
    end

    section.set_slot(3, {value = SIGNAL_GATE_STRESS, min = stress})

    gate_data.signal_cache = {
        active = active,
        energy = energy,
        stress = stress,
    }
    gate_data.last_signal_update_tick = current_tick
end


-- Scripted upkeep replaces the old always-on EEI drain. Dormant or invalid gates are free, while
-- armed, cooling, and stressed gates pay progressively more to stay ready.
function model.get_gate_upkeep_watts(gate, gate_data, event)
    gate_data = gate_data or (gate and storage.ei.gate.gate[gate.unit_number])
    if not gate_data then
        return 0
    end

    if not gate_data.effective_enabled then
        return 0
    end

    if not model.entity_check(gate_data.effective_target_entity) then
        return 0
    end

    if not model.entity_check(gate) or gate.energy < LOW_POWER_J then
        return 0
    end

    local upkeep = GATE_ARMED_UPKEEP_W
    local stress = gate_data.stress or 0
    if stress > 0 then
        upkeep = upkeep + (stress * GATE_STRESS_UPKEEP_W)
    end
    if (gate_data.cooldown_until_tick or 0) > ei_lib.get_event_tick(event) then
        upkeep = upkeep + GATE_COOLDOWN_UPKEEP_W
    end

    return upkeep
end


function model.refresh_gate_live_state(gate, event)
    if not model.entity_check(gate) then
        return
    end

    local gate_data = model.ensure_gate_defaults(gate.unit_number, event)
    if not gate_data then
        return
    end

    model.resolve_gate_target(gate, event)
    model.update_input_lock(gate, gate_data)
    model.update_wire_proxy_signals(gate, gate_data, event)
end


-- Rebuild the per-force receiver registry from live entities so both the manual dropdown and the
-- circuit destination signal resolve against the same table. Duplicate effective IDs are marked as
-- conflicts and become unroutable until the conflict is removed.
function model.refresh_receivers(event)

    model.check_global_init()

    local registry_by_force = {}
    local stale_units = {}
    local registry_changed = false

    for unit, receiver_data in pairs(storage.ei.gate.receiver) do
        local receiver = receiver_data.entity
        if not model.entity_check(receiver) then
            table.insert(stale_units, unit)
            registry_changed = true
            goto continue
        end

        receiver_data = model.ensure_receiver_defaults(unit, event)
        if not receiver_data then
            table.insert(stale_units, unit)
            registry_changed = true
            goto continue
        end

        local tick = ei_lib.get_event_tick(event)
        local elapsed_ticks = math.max(0, tick - (receiver_data.last_penalty_tick or 0))
        model.decay_receiver_penalties(receiver_data, elapsed_ticks)
        receiver_data.last_penalty_tick = tick

        local previous_effective_id = receiver_data.effective_id
        local previous_conflict = receiver_data.conflict
        local previous_surface = receiver_data.surface
        local previous_position = receiver_data.position

        local override_id = model.get_signal_value(receiver, SIGNAL_RECEIVER_ID)
        if override_id and override_id > 0 then
            receiver_data.effective_id = math.floor(override_id)
        else
            receiver_data.effective_id = receiver_data.auto_id
        end

        receiver_data.conflict = false
        receiver_data.surface = receiver.surface.name
        receiver_data.position = {x = receiver.position.x, y = receiver.position.y}

        if previous_effective_id ~= receiver_data.effective_id
        or previous_conflict ~= receiver_data.conflict
        or previous_surface ~= receiver_data.surface
        or not previous_position
        or previous_position.x ~= receiver_data.position.x
        or previous_position.y ~= receiver_data.position.y then
            registry_changed = true
        end

        local force_index = receiver.force.index
        local force_registry = registry_by_force[force_index]
        if not force_registry then
            force_registry = {
                valid = {},
                conflicts = {},
                sorted_ids = {}
            }
            registry_by_force[force_index] = force_registry
        end

        local effective_id = receiver_data.effective_id
        local existing_unit = force_registry.valid[effective_id]

        if existing_unit then
            force_registry.valid[effective_id] = nil
            force_registry.conflicts[effective_id] = {existing_unit, unit}
            receiver_data.conflict = true
            registry_changed = true
            if storage.ei.gate.receiver[existing_unit] then
                storage.ei.gate.receiver[existing_unit].conflict = true
            end
        elseif force_registry.conflicts[effective_id] then
            table.insert(force_registry.conflicts[effective_id], unit)
            receiver_data.conflict = true
            registry_changed = true
        else
            force_registry.valid[effective_id] = unit
        end

        ::continue::
    end

    for _, unit in ipairs(stale_units) do
        storage.ei.gate.receiver[unit] = nil
    end

    for _, force_registry in pairs(registry_by_force) do
        for id, _ in pairs(force_registry.valid) do
            table.insert(force_registry.sorted_ids, id)
        end
        table.sort(force_registry.sorted_ids)
    end

    storage.ei.gate.receiver_by_force = registry_by_force
    storage.ei.gate.receiver_registry_dirty = registry_changed

end


function model.get_receiver_by_id(force_index, receiver_id)

    if not receiver_id then
        return nil, false
    end

    local force_registry = storage.ei.gate.receiver_by_force[force_index]
    if not force_registry then
        return nil, false
    end

    if force_registry.conflicts[receiver_id] then
        return nil, true
    end

    local unit = force_registry.valid[receiver_id]
    if not unit then
        return nil, false
    end

    local receiver_data = storage.ei.gate.receiver[unit]
    if not receiver_data or not model.entity_check(receiver_data.entity) then
        return nil, false
    end

    return receiver_data, false

end


function model.make_receiver_label(receiver_data)

    return string.format(
        "ID %d | %s | %.1f, %.1f",
        receiver_data.effective_id,
        receiver_data.surface,
        receiver_data.position.x,
        receiver_data.position.y
    )

end


function model.find_container_entity(surface, position)

    if not surface or not position then
        return nil
    end

    local containers = surface.find_entities_filtered{
        area = {
            {position.x - 0.3, position.y - 0.3},
            {position.x + 0.3, position.y + 0.3}
        },
        type = {
            "container",
            "logistic-container",
        }
    }

    for _, container in ipairs(containers) do
        if container.name ~= "ei-gate-container" then
            return container
        end
    end

    return nil

end


function model.resolve_manual_target(gate_data, force_index)

    if gate_data.manual_receiver_id then
        local receiver_data, conflicted = model.get_receiver_by_id(force_index, gate_data.manual_receiver_id)
        if receiver_data then
            return {
                target_type = "receiver",
                entity = receiver_data.entity,
                exit = {
                    surface = receiver_data.surface,
                    x = receiver_data.position.x,
                    y = receiver_data.position.y
                },
                receiver_id = receiver_data.effective_id,
                conflicted = false
            }
        end

        return {
            target_type = nil,
            entity = nil,
            exit = nil,
            receiver_id = gate_data.manual_receiver_id,
            conflicted = conflicted
        }
    end

    if gate_data.legacy_exit then
        local exit = model.copy_exit(gate_data.legacy_exit)
        local legacy_entity = nil

        if model.entity_check(gate_data.exit_container) then
            legacy_entity = gate_data.exit_container
        elseif exit and exit.surface then
            local surface = game.get_surface(exit.surface)
            if surface then
                legacy_entity = model.find_container_entity(surface, exit)
            end
            gate_data.exit_container = legacy_entity
        end

        return {
            target_type = "legacy",
            entity = legacy_entity,
            exit = exit,
            receiver_id = nil,
            conflicted = false
        }
    end

    return {
        target_type = nil,
        entity = nil,
        exit = nil,
        receiver_id = nil,
        conflicted = false
    }

end


-- Resolve the gate state once and cache it onto gate_data. This keeps GUI, transport, upkeep, and
-- circuit telemetry consistent even when the destination is being overridden live by circuits.
function model.resolve_gate_target(gate, event)

    local gate_data = model.ensure_gate_defaults(gate.unit_number, event)
    if not gate_data then
        return nil
    end

    local manual_target = model.resolve_manual_target(gate_data, gate.force.index)
    local resolved_target = manual_target
    local control_source = "manual"
    local effective_enabled = gate_data.manual_enabled == true
    local enable_signal = model.get_gate_signal_value(gate_data, SIGNAL_GATE_ENABLE)

    if enable_signal ~= 0 then
        effective_enabled = enable_signal > 0
    end

    local circuit_receiver_id = model.get_gate_signal_value(gate_data, SIGNAL_GATE_DESTINATION)
    if circuit_receiver_id and circuit_receiver_id > 0 then
        circuit_receiver_id = math.floor(circuit_receiver_id)
        local circuit_target = model.get_receiver_by_id(gate.force.index, circuit_receiver_id)
        if circuit_target then
            resolved_target = {
                target_type = "receiver",
                entity = circuit_target.entity,
                exit = {
                    surface = circuit_target.surface,
                    x = circuit_target.position.x,
                    y = circuit_target.position.y
                },
                receiver_id = circuit_target.effective_id,
                conflicted = false
            }
            control_source = "circuit"

            if enable_signal == 0 then
                effective_enabled = true
            end
        end
    end

    gate_data.control_source = control_source
    gate_data.effective_enabled = effective_enabled
    gate_data.effective_target_type = resolved_target.target_type
    gate_data.effective_target_entity = resolved_target.entity
    gate_data.effective_exit = resolved_target.exit
    gate_data.effective_receiver_id = resolved_target.receiver_id
    gate_data.manual_target_conflicted = manual_target.conflicted

    return gate_data

end


function model.get_preview_exit(gate_data)

    if gate_data.effective_exit then
        return gate_data.effective_exit
    end

    local gate = gate_data.gate
    if gate_data.manual_receiver_id and model.entity_check(gate) then
        local receiver_data = model.get_receiver_by_id(gate.force.index, gate_data.manual_receiver_id)
        if receiver_data then
            return {
                surface = receiver_data.surface,
                x = receiver_data.position.x,
                y = receiver_data.position.y
            }
        end
    end

    return gate_data.legacy_exit

end


function model.set_manual_receiver(gate_unit, receiver_id, event)

    local gate_data = model.ensure_gate_defaults(gate_unit, event)
    receiver_id = tonumber(receiver_id)
    if receiver_id then
        receiver_id = math.floor(receiver_id)
    end

    if not gate_data or not receiver_id or receiver_id < 1 then
        return
    end

    gate_data.manual_receiver_id = receiver_id
    gate_data.legacy_exit = nil
    gate_data.exit = nil
    gate_data.exit_container = nil

end


function model.register_gate(gate, container, event)

    model.check_global_init()
    
    local gate_unit = gate.unit_number
    if storage.ei.gate.gate[gate_unit] or not gate or not gate.valid or not container or not container.valid then
        log("ei register_gate returned early due to pre-existing gate_unit or non-existent gate or non-existent container")
        return
    end

    storage.ei.gate.gate[gate_unit] = {}
    storage.ei.gate.gate[gate_unit].gate = gate
    storage.ei.gate.gate[gate_unit].container = container
    storage.ei.gate.gate[gate_unit].manual_enabled = false
    storage.ei.gate.gate[gate_unit].state = false
    storage.ei.gate.gate[gate_unit].manual_receiver_id = nil
    storage.ei.gate.gate[gate_unit].legacy_exit = nil
    storage.ei.gate.gate[gate_unit].last_low_power = false

    local gate_data = model.ensure_gate_defaults(gate_unit, event)
    if gate_data then
        gate_data.gate = gate
        gate_data.container = container
    end
    model.refresh_gate_live_state(gate, event)

end


function model.find_gate(container)

    if not container or not container.valid then
        return nil
    end

    if container.name == "ei-gate" then
        return container
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

function model.make_gate(container, event)

    if not model.entity_check(container) then
        return
    end

    -- The player places the visible container. Script then spawns the hidden EEI that actually
    -- stores energy and drives transport so placement preview and in-world interaction both use
    -- the visible gate silhouette.
    local gate = container.surface.create_entity({
        name = "ei-gate",
        position = container.position,
        force = container.force
    })

    model.register_gate(gate, container, event)

end


function model.destroy_gate(gate, container, event)

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
    model.cleanup_gate_remote_selection(gate_unit)
    model.destroy_wire_proxy(gate_unit)

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


function model.check_for_teleport(unit, gate, event)

    -- Transport intentionally stops after the first successful stack. Sustained throughput is
    -- supposed to look bursty and pay cooldown/stress costs instead of emptying a chest instantly.

    local gate_data = model.ensure_gate_defaults(unit, event)
    if not gate_data then
        return
    end

    local receiver_data = model.get_effective_receiver_data(gate_data, event)
    if not model.can_gate_transport(gate, gate_data, receiver_data, event) then
        return
    end

    local exit_container = gate_data.effective_target_entity
    if not model.entity_check(exit_container) then
        return
    end

    local source_container = gate_data.container
    local source_inv = model.entity_check(source_container) and source_container.get_inventory(defines.inventory.chest) or nil
    if not source_inv then return end
    if source_inv.is_empty() then return end

    local target_inv = exit_container.get_inventory(defines.inventory.chest)
    if not target_inv or target_inv.is_full() then return end

    local success = false

    for i = 1, #source_inv do
        if source_inv[i].valid_for_read then
            local item_stack = source_inv[i]
            local item_name = item_stack.name
            local item_count = item_stack.count
            local insertable_probe = model.make_item_with_quality_id(item_stack) or item_name

            local ok, insertable_count = pcall(target_inv.get_insertable_count, insertable_probe)
            local movable_count = math.min(item_count, ok and insertable_count or item_count)
            if movable_count > 0 then
                local transfer_stack = model.make_item_stack_definition(item_stack, movable_count)
                local quote = model.quote_transfer({{name = item_name, count = movable_count}})
                if transfer_stack and model.can_pay_quote(gate, quote) then
                    local transfer_count = target_inv.insert(transfer_stack)
                    if transfer_count > 0 then
                        local actual_quote = quote
                        if transfer_count ~= movable_count then
                            actual_quote = model.quote_transfer({{name = item_name, count = transfer_count}})
                        end

                        if model.commit_quote(gate, actual_quote) then
                            item_stack.count = item_stack.count - transfer_count
                            model.apply_transfer_penalties(gate, gate_data, receiver_data, actual_quote, event)
                            success = true
                            ei_victory.count_value("gate_items_transported", transfer_count)
                            break
                        end

                        local rollback_stack = model.make_item_stack_definition(item_stack, transfer_count)
                        local removed_count = rollback_stack and target_inv.remove(rollback_stack) or 0
                        if removed_count < transfer_count then
                            gate.surface.spill_item_stack{
                                position = gate.position,
                                stack = model.make_item_stack_definition(item_stack, transfer_count - removed_count),
                                enable_looted = true,
                                force = gate.force
                            }
                        end
                    end
                end
            end
        end
    end

    if success then
        model.render_exit(gate, exit_container.bounding_box)
    end

    return

end


function model.find_container(gate, surface, position, print_out, event)

    print_out = print_out or false
    local unit = gate.unit_number

    local gate_data = model.ensure_gate_defaults(unit, event)
    local container = model.find_container_entity(surface, position)

    if container then
        position = container.position
        gate_data.exit_container = container
        gate_data.legacy_exit = {
            surface = surface.name,
            x = position.x,
            y = position.y
        }
        gate_data.exit = model.copy_exit(gate_data.legacy_exit)
        gate_data.manual_receiver_id = nil

        if print_out then
            game.print({"exotic-industries.gate-exit-container-set", surface.name, position.x, position.y, container.name})
        end
    else
        gate_data.exit_container = nil
        gate_data.legacy_exit = {
            surface = surface.name,
            x = position.x,
            y = position.y
        }
        gate_data.exit = model.copy_exit(gate_data.legacy_exit)
        gate_data.manual_receiver_id = nil

        if print_out then
            game.print({"exotic-industries.gate-exit-set", surface.name, position.x, position.y})
        end
        model.refresh_gate_live_state(gate, event)
        return false
    end

    model.refresh_gate_live_state(gate, event)

    return true

end


function model.gate_state(gate)
    local gate_data = gate and storage.ei.gate.gate[gate.unit_number]
    return model.is_gate_armed(gate, gate_data)
end

-- Active payment path. Older versions tried to recurse recipe graphs at runtime; the gate now
-- relies on the static mass table and the quote helpers above so energy, stress, and residue all
-- derive from the same measured transfer.
function model.pay_energy(gate, tablein, actuallypay)
    local quote = model.quote_transfer(tablein)

    if not actuallypay then
        return model.can_pay_quote(gate, quote)
    end

    return model.commit_quote(gate, quote)
end


function model.teleport_player(character, gate)

    local player = character.player
    if not player then
        return
    end

    local exit = storage.ei.gate.gate[gate.unit_number].effective_exit
    if not exit then
        return
    end

    -- teleport player
    player.teleport({exit.x, exit.y}, exit.surface)

end


function model.update_energy(unit, gate, event)
    local gate_data = storage.ei.gate.gate[unit]
    if not gate_data then
        return
    end

    -- The global updater touches gates incrementally, so decay and scripted upkeep both need to be
    -- expressed in elapsed time rather than "once per tick" assumptions.
    local current_tick = ei_lib.get_event_tick(event)
    local last_tick = gate_data.last_energy_tick or current_tick
    local elapsed_ticks = math.max(0, current_tick - last_tick)

    if elapsed_ticks > 0 then
        local elapsed_seconds = elapsed_ticks / 60
        local start_stress = gate_data.stress or 0
        local end_stress = clamp(start_stress - (elapsed_seconds * STRESS_DECAY_PER_SECOND), 0, MAX_GATE_STRESS)

        if model.is_gate_armed(gate, gate_data) then
            local drain = GATE_ARMED_UPKEEP_W * elapsed_seconds
            local average_stress = (start_stress + end_stress) / 2

            if average_stress > 0 then
                drain = drain + (average_stress * GATE_STRESS_UPKEEP_W * elapsed_seconds)
            end

            local cooldown_until_tick = gate_data.cooldown_until_tick or 0
            local cooling_ticks = 0
            if cooldown_until_tick > last_tick then
                cooling_ticks = math.max(0, math.min(current_tick, cooldown_until_tick) - last_tick)
            end

            if cooling_ticks > 0 then
                drain = drain + (GATE_COOLDOWN_UPKEEP_W * (cooling_ticks / 60))
            end

            gate.energy = math.max(0, gate.energy - drain)
        end

        gate_data.stress = end_stress
        if (gate_data.cooldown_until_tick or 0) <= current_tick then
            gate_data.cooldown_until_tick = 0
        end
        gate_data.last_energy_tick = current_tick
    end

    local wants_power = gate_data.effective_enabled and model.entity_check(gate_data.effective_target_entity)
    if gate.energy < LOW_POWER_J then
        if wants_power and not gate_data.last_low_power then
            game.print({"exotic-industries.gate-not-enough-energy", gate.position.x, gate.position.y, gate.surface.name})
        end
        gate_data.last_low_power = wants_power
    else
        gate_data.last_low_power = false
    end

    model.update_input_lock(gate, gate_data)
    model.update_wire_proxy_signals(gate, gate_data, event)

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
    local exit = storage.ei.gate.gate[gate_unit].effective_exit
    if not exit then
        return
    end
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


function model.render_animation(gate, event)
    local gate_unit = gate.unit_number
    local pick = math.random(1,4) --ei_rng.int("gate_light", 1, 4, gate_unit, event.tick)

    local colors = {
        {r = 0, g = 0.4, b = 1.0},
        {r = 0.4, g = 0.2, b = 1.0},
        {r = 0.2, g = 0.2, b = 1.0},
        {r = 0.4, g = 0.1, b = 0.8},
    }
    local color = colors[pick]

    -- Reuse existing light if valid, otherwise create new
    --local light = storage.ei.gate.gate[gate_unit].light
--[[    if light and light.valid then
        light.color = color
        light.time_to_live = ei_ticksPerFullUpdate * 2
    else]]
    local light = rendering.draw_light {
        sprite = "gate_glow",
        scale = 4,
        intensity = 0.22,
        color = color,
        target = gate,
        surface = gate.surface,
        time_to_live = ei_ticksPerFullUpdate * 2,
        blend_mode = "multiplicative",
        apply_runtime_tint = true,
        draw_as_glow = true,
    }
        --storage.ei.gate.gate[gate_unit].light = light
    --end

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


function model.update_renders(unit, gate, event)

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
        model.render_animation(gate, event)
    end

end


--GUI
-----------------------------------------------------------------------------------------------------

function model.get_gui_elements(player)

    if not player or not player.valid then
        return nil
    end

    local root = player.gui.relative["ei-gate-console"]
    if not (root and root.valid) then
        return nil
    end

    local main_container = root["main-container"]
    local status_flow = main_container and main_container["status-flow"]
    local control_flow = main_container and main_container["control-flow"]
    local target_flow = control_flow and control_flow["target-flow"]
    local dropdown_flow = target_flow and target_flow["dropdown-flow"]
    local camera_frame = control_flow and control_flow["camera-frame"]

    local elements = {
        root = root,
        energy = status_flow and status_flow["energy"],
        stress = status_flow and status_flow["stress"],
        dropdown = dropdown_flow and dropdown_flow["receiver"],
        legacy_status = target_flow and target_flow["legacy-status"],
        control_source = target_flow and target_flow["control-source"],
        runtime = target_flow and target_flow["runtime-state"],
        receiver_strain = target_flow and target_flow["receiver-strain"],
        camera = camera_frame and camera_frame["target-camera"],
        state = target_flow and target_flow["state-button"],
    }

    if not (elements.root and elements.root.valid) then
        return nil
    end
    if not (elements.energy and elements.energy.valid) then
        return nil
    end
    if not (elements.stress and elements.stress.valid) then
        return nil
    end
    if not (elements.dropdown and elements.dropdown.valid) then
        return nil
    end
    if not (elements.legacy_status and elements.legacy_status.valid) then
        return nil
    end
    if not (elements.control_source and elements.control_source.valid) then
        return nil
    end
    if not (elements.runtime and elements.runtime.valid) then
        return nil
    end
    if not (elements.receiver_strain and elements.receiver_strain.valid) then
        return nil
    end
    if not (elements.camera and elements.camera.valid) then
        return nil
    end
    if not (elements.state and elements.state.valid) then
        return nil
    end

    return elements

end


function model.build_gui(player, gate)

    if not player or not player.valid then
        return nil
    end

    if not model.entity_check(gate) then
        return nil
    end

    if player.gui.relative["ei-gate-console"] then
        model.close_gui(player)
    end

    local gate_unit = gate.unit_number

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
        status_flow.add{
            type = "progressbar",
            name = "stress",
            caption = {"exotic-industries.gate-gui-status-stress", 0},
            tooltip = {"exotic-industries.gate-gui-status-stress-tooltip"},
            style = "ei_status_progressbar_red"
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
            name = "receiver",
            tags = {
                parent_gui = "ei-gate-console",
                action = "set-receiver",
                gate_unit = gate_unit
            }
        }

        target_flow.add{
            type = "label",
            caption = {"exotic-industries.gate-gui-legacy-label"},
        }
        target_flow.add{
            type = "label",
            name = "legacy-status",
            caption = {"exotic-industries.gate-gui-legacy-none"}
        }

        target_flow.add{
            type = "label",
            name = "control-source",
            caption = {"exotic-industries.gate-gui-control-source-label", {"exotic-industries.gate-gui-control-source-manual"}},
        }
        target_flow.add{
            type = "label",
            name = "runtime-state",
            caption = {"exotic-industries.gate-gui-control-runtime-label", {"exotic-industries.gate-gui-runtime-stable"}},
        }
        target_flow.add{
            type = "label",
            name = "receiver-strain",
            caption = {"exotic-industries.gate-gui-receiver-strain-label", {"exotic-industries.gate-gui-receiver-strain-low"}},
        }
        target_flow.add{
            type = "label",
            caption = {"exotic-industries.gate-gui-control-state-label"},
        }
        target_flow.add{
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
        -- Shows the currently resolved destination. This follows manual receiver selection,
        -- circuit receiver overrides, and legacy exits for old saves.
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

    return model.get_gui_elements(player)

end


function model.open_gui(player, event)

    local gate = model.find_gate(player.opened)
    if not gate then
        return
    end

    model.refresh_receivers(event)
    model.resolve_gate_target(gate, event)

    model.build_gui(player, gate)

    local data = model.get_data(gate, event)
    model.update_gui(player, data, false, gate)

end


function model.update_gui(player, data, ontick, gate)

    if not data then return end
    local gui = model.get_gui_elements(player)
    if not gui then
        local open_gate = model.find_gate(player.opened)
        if not gate or gate ~= open_gate then
            model.close_gui(player)
            return
        end

        gui = model.build_gui(player, gate)
        if not gui then
            model.close_gui(player)
            return
        end
    end

    local energy = gui.energy
    local stress = gui.stress
    local dropdown = gui.dropdown
    local legacy_status = gui.legacy_status
    local control_source = gui.control_source
    local runtime = gui.runtime
    local receiver_strain = gui.receiver_strain
    local camera = gui.camera
    local state = gui.state

    -- Update the view from a precomputed gate snapshot. update_gui should stay dumb and avoid
    -- poking back into storage except when it needs to rebuild a stale GUI shell.
    energy.caption = {"exotic-industries.gate-gui-status-energy", string.format("%.0f", data.energy/1000000)}
    energy.value = data.energy / data.max_energy
    stress.caption = {"exotic-industries.gate-gui-status-stress", data.stress}
    stress.value = data.stress_ratio

    dropdown.items = data.receiver_items
    dropdown.selected_index = data.selected_index
    dropdown.tags = {
        parent_gui = "ei-gate-console",
        action = "set-receiver",
        receiver_ids = data.receiver_ids,
        gate_unit = gate and gate.unit_number or (dropdown.tags and dropdown.tags.gate_unit)
    }

    legacy_status.caption = data.legacy_status
    control_source.caption = {"exotic-industries.gate-gui-control-source-label", data.control_source_text}
    runtime.caption = {"exotic-industries.gate-gui-control-runtime-label", data.runtime_status}
    receiver_strain.caption = {"exotic-industries.gate-gui-receiver-strain-label", data.receiver_strain_text}

    if data.preview_surface and game.get_surface(data.preview_surface) then
        camera.surface_index = game.get_surface(data.preview_surface).index or 1
        camera.position = {data.preview_pos.x, data.preview_pos.y}
    else
        camera.position = {0, 0}
    end

    -- State button
    if data.state then
        state.style = "ei_small_green_button"
        state.caption = {"exotic-industries.gate-gui-control-state-button", "ON"}
    else
        state.style = "ei_small_red_button"
        state.caption = {"exotic-industries.gate-gui-control-state-button", "OFF"}
    end

end


function model.update_player_guis(event)
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

            local data = model.get_data(gate, event)
            model.update_gui(player, data, true, gate)
        end
        ::continue::
    end

end


function model.update_receiver_selection(player, gate_unit, event)

    if not gate_unit then return end
    if not storage.ei.gate.gate[gate_unit] then return end

    local gui = model.get_gui_elements(player)
    if not gui then return end

    local dropdown = gui.dropdown
    if not dropdown.tags or not dropdown.tags.receiver_ids then
        return
    end
    local receiver_id = dropdown.tags.receiver_ids[dropdown.selected_index]
    if not receiver_id then
        return
    end

    local gate = storage.ei.gate.gate[gate_unit].gate
    if not gate or not gate.valid then return end

    model.set_manual_receiver(gate_unit, receiver_id, event)
    model.refresh_gate_live_state(gate, event)

    local data = model.get_data(gate, event)
    model.update_gui(player, data, false, gate)

end


function model.toggle_state(player, gate_unit, event)

    if not gate_unit then return end
    if not storage.ei.gate.gate[gate_unit] then return end

    local gate = storage.ei.gate.gate[gate_unit].gate
    if not gate or not gate.valid then return end

    local gate_data = model.ensure_gate_defaults(gate_unit, event)
    gate_data.manual_enabled = not gate_data.manual_enabled
    gate_data.state = gate_data.manual_enabled

    if gate_data.manual_enabled and gate.energy < LOW_POWER_J then
        game.print({"exotic-industries.gate-not-enough-energy", gate.position.x, gate.position.y, gate.surface.name})
    end

    model.refresh_gate_live_state(gate, event)

    -- GUI update is cosmetic — guard against missing GUI
    local root = player.gui.relative["ei-gate-console"]
    if root then
        local data = model.get_data(gate, event)
        model.update_gui(player, data, false, gate)
    end

end


function model.choose_position(player, gate_unit, event)

    if not gate_unit then return end
    if not storage.ei.gate.gate[gate_unit] then return end

    local gate = storage.ei.gate.gate[gate_unit].gate
    if not gate or not gate.valid then return end

    -- if currently a selection is in progress for this player
    if storage.ei.gate.remote and storage.ei.gate.remote[player.index] then return end

    local gate_data = storage.ei.gate.gate[gate_unit]
    local target_exit = gate_data.legacy_exit or gate_data.effective_exit or gate_data.exit
    local target_surface_name = target_exit and target_exit.surface or gate.surface.name
    local target_surface = game.get_surface(target_surface_name)
    if not target_surface then target_surface = gate.surface end

    local center_pos = {0, 0}
    if target_exit and target_exit.x then
        center_pos = {target_exit.x, target_exit.y}
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


function model.get_data(gate, event)

    if not gate then return end

    local gate_data = model.ensure_gate_defaults(gate.unit_number, event)
    if not gate_data then
        return nil
    end

    -- Package everything the GUI needs up front so the renderer can stay declarative and does not
    -- need to understand storage layout or receiver resolution rules.
    model.resolve_gate_target(gate, event)

    local data = {}
    if gate.electric_buffer_size then
        data.max_energy = gate.electric_buffer_size
    end
    if gate.energy then
        data.energy = gate.energy
    else
        data.energy = 0
    end
    data.max_energy = math.max(data.max_energy or 0, 1)
    data.stress = math.floor((gate_data.stress or 0) + 0.5)
    data.stress_ratio = clamp((gate_data.stress or 0) / MAX_GATE_STRESS, 0, 1)

    local receiver_items = {
        {"exotic-industries.gate-gui-no-receivers"}
    }
    local receiver_ids = {
        [1] = false
    }
    local selected_index = 1

    local force_registry = storage.ei.gate.receiver_by_force[gate.force.index]
    if force_registry then
        for _, receiver_id in ipairs(force_registry.sorted_ids) do
            local unit = force_registry.valid[receiver_id]
            local receiver_data = storage.ei.gate.receiver[unit]
            if receiver_data then
                table.insert(receiver_items, model.make_receiver_label(receiver_data))
                receiver_ids[#receiver_items] = receiver_id
                if gate_data.manual_receiver_id == receiver_id then
                    selected_index = #receiver_items
                end
            end
        end
    end

    if gate_data.manual_receiver_id and selected_index == 1 then
        if gate_data.manual_target_conflicted then
            receiver_items[1] = {"exotic-industries.gate-gui-receiver-conflict", gate_data.manual_receiver_id}
        else
            receiver_items[1] = {"exotic-industries.gate-gui-receiver-unavailable", gate_data.manual_receiver_id}
        end
    end

    local preview_exit = model.get_preview_exit(gate_data)
    if preview_exit then
        data.preview_surface = preview_exit.surface
        data.preview_pos = {x = preview_exit.x, y = preview_exit.y}
    end

    if gate_data.legacy_exit and not gate_data.manual_receiver_id then
        data.legacy_status = {
            "exotic-industries.gate-gui-legacy-destination",
            gate_data.legacy_exit.surface,
            gate_data.legacy_exit.x,
            gate_data.legacy_exit.y,
            gate_data.legacy_exit.surface
        }
    else
        data.legacy_status = {"exotic-industries.gate-gui-legacy-none"}
    end

    data.receiver_items = receiver_items
    data.receiver_ids = receiver_ids
    data.selected_index = selected_index
    data.state = gate_data.manual_enabled

    if (gate_data.cooldown_until_tick or 0) > ei_lib.get_event_tick(event) then
        data.runtime_status = {"exotic-industries.gate-gui-runtime-cooling"}
    elseif (gate_data.stress or 0) >= 75 then
        data.runtime_status = {"exotic-industries.gate-gui-runtime-critical"}
    else
        data.runtime_status = {"exotic-industries.gate-gui-runtime-stable"}
    end

    local receiver_data = model.get_effective_receiver_data(gate_data, event)
    local receiver_saturation = receiver_data and receiver_data.saturation or 0
    if receiver_saturation >= MAX_RECEIVER_SATURATION then
        data.receiver_strain_text = {"exotic-industries.gate-gui-receiver-strain-saturated"}
    elseif receiver_saturation >= 60 then
        data.receiver_strain_text = {"exotic-industries.gate-gui-receiver-strain-high"}
    elseif receiver_saturation >= 25 then
        data.receiver_strain_text = {"exotic-industries.gate-gui-receiver-strain-medium"}
    else
        data.receiver_strain_text = {"exotic-industries.gate-gui-receiver-strain-low"}
    end

    if gate_data.control_source == "circuit" then
        data.control_source_text = {"exotic-industries.gate-gui-control-source-circuit"}
    else
        data.control_source_text = {"exotic-industries.gate-gui-control-source-manual"}
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

function model.on_built_entity(event)

    local entity = event and event.entity

    if model.entity_check(entity) == false then
        return
    end

    if entity.name == "ei-gate-container" then
        model.make_gate(entity, event)
        return
    end

    if entity.name == "ei-gate-receiver" then
        model.register_receiver(entity, event)
    end

end


function model.on_destroyed_entity(event)

    local entity = event and event.entity
    local transfer = nil or (event and event.robot) or (event and event.player_index)

    if model.entity_check(entity) == false then
        return
    end

    if entity.name == "ei-gate-receiver" then
        model.destroy_receiver(entity, event)
        return
    end

    if entity.name ~= "ei-gate" and entity.name ~= "ei-gate-container" then
        return
    end

    if not model.transfer_valid(transfer) then
        return
    end

    if entity.name == "ei-gate" then

        model.destroy_gate(entity, nil, event)
        return

    end

    -- normaly gate gets mined/destroyed first
    if entity.name == "ei-gate-container" then

        model.destroy_gate(nil, entity, event)
        return

    end

end


function model.update(event)

    model.check_global_init()

    if not storage.ei.gate then
        return false
    end

    if not storage.ei.gate.gate then
        return false
    end

    model.refresh_receivers(event)
    if storage.ei.gate.receiver_registry_dirty then
        for gate_unit, gate_data in pairs(storage.ei.gate.gate) do
            local gate = gate_data.gate
            if model.entity_check(gate) then
                model.ensure_gate_defaults(gate_unit, event)
                model.refresh_gate_live_state(gate, event)
            end
        end
        storage.ei.gate.receiver_registry_dirty = false
    end
    model.update_player_guis(event)

    if not storage.ei.gate.gate_break_point and next(storage.ei.gate.gate) then
       storage.ei.gate.gate_break_point,_ = next(storage.ei.gate.gate)
    end

    if not storage.ei.gate.gate_break_point then
        return false
    end

    local break_id = storage.ei.gate.gate_break_point
    local current_gate_exists = storage.ei.gate.gate[break_id] ~= nil
    if break_id and storage.ei.gate.gate and storage.ei.gate.gate[break_id] then
        local gate = storage.ei.gate.gate[break_id].gate
        if model.entity_check(gate) then
            model.ensure_gate_defaults(break_id, event)
            model.resolve_gate_target(gate, event)
            model.update_energy(break_id, gate, event)
            model.check_for_teleport(break_id, gate, event)
            model.update_renders(break_id, gate, event)
            model.update_wire_proxy_signals(gate, storage.ei.gate.gate[break_id], event)
        else
            storage.ei.gate.gate[break_id] = nil
        end
    end

    local next_break_id
    if current_gate_exists then
        next_break_id = next(storage.ei.gate.gate, break_id)
    else
        next_break_id = next(storage.ei.gate.gate)
    end

    if next_break_id then
        storage.ei.gate.gate_break_point = next_break_id
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
    if not gate_unit then
        model.cleanup_position_selection(player_index)
        return
    end

    -- Set the gate exit position
    if storage.ei.gate.gate[gate_unit] then
        if not model.find_container(storage.ei.gate.gate[gate_unit].gate, surface, position, true, event) then
            storage.ei.gate.gate[gate_unit].legacy_exit = {
                surface = surface.name,
                x = position.x,
                y = position.y
            }
            storage.ei.gate.gate[gate_unit].exit = model.copy_exit(storage.ei.gate.gate[gate_unit].legacy_exit)
            storage.ei.gate.gate[gate_unit].manual_receiver_id = nil
        end
        model.refresh_gate_live_state(storage.ei.gate.gate[gate_unit].gate, event)
    end

    model.cleanup_position_selection(player_index)

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
        if not model.find_container(storage.ei.gate.gate[gate_unit].gate, surface, position, true, event) then
            storage.ei.gate.gate[gate_unit].legacy_exit = {
                surface = surface.name,
                x = position.x,
                y = position.y
            }
            storage.ei.gate.gate[gate_unit].exit = model.copy_exit(storage.ei.gate.gate[gate_unit].legacy_exit)
            storage.ei.gate.gate[gate_unit].manual_receiver_id = nil
        end
        model.refresh_gate_live_state(storage.ei.gate.gate[gate_unit].gate, event)
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


function model.cleanup_gate_remote_selection(gate_unit)
    if not storage.ei.gate or not storage.ei.gate.remote then
        return
    end

    local affected_players = {}
    for player_index, remote_data in pairs(storage.ei.gate.remote) do
        if remote_data and remote_data.gate_unit == gate_unit then
            affected_players[#affected_players + 1] = player_index
        end
    end

    for _, player_index in ipairs(affected_players) do
        model.cleanup_position_selection(player_index)
    end
end


--GUI HANDLER
-----------------------------------------------------------------------------------------------------

function model.on_gui_selection_state_changed(event)
    local tags = event.element.tags

    if tags.action == "set-receiver" then
        model.update_receiver_selection(game.get_player(event.player_index), tags.gate_unit, event)
    end
end


function model.close_gui(player)
    if player.gui.relative["ei-gate-console"] then
        player.gui.relative["ei-gate-console"].destroy()
    end
end


function model.on_gui_opened(event)
    local player = game.get_player(event.player_index)
    if not player then
        return
    end

    model.check_global_init()

    local entity = event.entity
    if model.entity_check(entity) and entity.name == "ei-gate" then
        local gate_data = storage.ei.gate.gate and storage.ei.gate.gate[entity.unit_number]
        if gate_data and model.entity_check(gate_data.container) then
            storage.ei.gate.open_redirect[event.player_index] = true
            player.opened = gate_data.container
            return
        end
    end

    if storage.ei.gate.open_redirect[event.player_index] then
        storage.ei.gate.open_redirect[event.player_index] = nil
    end

    model.open_gui(player, event)
end


function model.on_gui_click(event)
    local tags = event.element.tags
    local gate_unit = tags.gate_unit

    if tags.action == "set-state" then
        model.toggle_state(game.get_player(event.player_index), gate_unit, event)
        return
    end

    if tags.action == "set-position" then
        model.choose_position(game.get_player(event.player_index), gate_unit, event)
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

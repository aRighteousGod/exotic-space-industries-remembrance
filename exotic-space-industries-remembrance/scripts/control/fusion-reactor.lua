--==============================================================================
-- ESIR FILE MAP
-- owns: fusion reactor GUI, manual/circuit control, and circuit telemetry proxy
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: build/destroy, scheduled tick step, GUI open/close/click/value-change, configuration rebuild
-- forwarded_events: check_global, close_gui, entity_check, get_pending_work_count, on_built_entity, on_configuration_changed, on_destroyed_entity, on_entity_settings_pasted, on_gui_click, on_gui_opened, on_gui_value_changed, on_player_left_game, open_gui, rebuild_runtime_state, update, update_gui, update_recipe
-- storage_roots: storage.ei.fusion_reactor
-- gui_ids: ei-fusion-reactor-console
-- remote_interfaces: none
-- rebuild_on: init, configuration change, entity topology changes
--==============================================================================

local model = {}
local get_entity_unit_number = ei_lib.get_entity_unit_number

local FUSION_RUNTIME_VERSION = 1
local FUSION_REACTOR_NAME = "ei-fusion-reactor"
local FUSION_WIRE_PROXY_NAME = "ei-fusion-reactor-circuit-interface"
local GUI_NAME = "ei-fusion-reactor-console"
local WIRE_SCAN_INTERVAL_TICKS = 60
local DEFAULT_SELECTION = {
    fuel_1 = "ei-heated-deuterium",
    fuel_2 = "ei-heated-tritium",
    temperature = "medium",
    injection_rate = "medium",
}
local CONTROL_SOURCE_MANUAL = "manual"
local CONTROL_SOURCE_CIRCUIT = "circuit"

model.slider_array = {"low", "medium", "high"}
model.slider_map = {low = 1, medium = 2, high = 3}
model.temp_map = {low = "1e8 K", medium = "1e9 K", high = "1e10 K"}

local FUEL_ORDER = {
    "ei-heated-protium",
    "ei-heated-deuterium",
    "ei-heated-tritium",
    "ei-heated-helium-3",
    "ei-heated-lithium-6",
}
local FUEL_INDEX = {}
local FUEL_BY_INDEX = {}
for index, fuel_name in ipairs(FUEL_ORDER) do
    FUEL_INDEX[fuel_name] = index
    FUEL_BY_INDEX[index] = fuel_name
end

local MODE_BY_INDEX = {
    [1] = "low",
    [2] = "medium",
    [3] = "high",
}

local function make_wire_signal(name)
    return {
        type = "virtual",
        name = name,
        quality = "normal",
        comparator = "=",
    }
end

local SIGNAL_INPUT_FUEL_1 = make_wire_signal("ei-fusion-set-fuel-1")
local SIGNAL_INPUT_FUEL_2 = make_wire_signal("ei-fusion-set-fuel-2")
local SIGNAL_INPUT_TEMPERATURE = make_wire_signal("ei-fusion-set-temperature")
local SIGNAL_INPUT_INJECTION = make_wire_signal("ei-fusion-set-injection")
local SIGNAL_STATE_FUEL_1 = make_wire_signal("ei-fusion-state-fuel-1")
local SIGNAL_STATE_FUEL_2 = make_wire_signal("ei-fusion-state-fuel-2")
local SIGNAL_STATE_TEMPERATURE = make_wire_signal("ei-fusion-state-temperature")
local SIGNAL_STATE_INJECTION = make_wire_signal("ei-fusion-state-injection")
local SIGNAL_POWER = make_wire_signal("ei-fusion-power")
local SIGNAL_NEUTRON_FLUX = make_wire_signal("ei-fusion-neutron-flux")
local SIGNAL_EFFICIENCY = make_wire_signal("ei-fusion-efficiency")
local SIGNAL_COOLANT_RATE = make_wire_signal("ei-fusion-coolant-rate")
local SIGNAL_CONTROL_AGENT = make_wire_signal("ei-fusion-control-agent")
local SIGNAL_FUEL_AGENT = make_wire_signal("ei-fusion-fuel-agent")
local SIGNAL_THERMAL_AGENT = make_wire_signal("ei-fusion-thermal-agent")
local SIGNAL_COOLANT_AGENT = make_wire_signal("ei-fusion-coolant-agent")
local SIGNAL_CIRCUIT_AGENT = make_wire_signal("ei-fusion-circuit-agent")

local function copy_selection(selection)
    selection = selection or DEFAULT_SELECTION
    return {
        fuel_1 = selection.fuel_1 or DEFAULT_SELECTION.fuel_1,
        fuel_2 = selection.fuel_2 or DEFAULT_SELECTION.fuel_2,
        temperature = selection.temperature or DEFAULT_SELECTION.temperature,
        injection_rate = selection.injection_rate or DEFAULT_SELECTION.injection_rate,
    }
end

local function first_valid_second_fuel(fuel_1)
    local combinations = ei_data.fusion.fuel_combinations[fuel_1]
    if type(combinations) ~= "table" then
        return DEFAULT_SELECTION.fuel_2
    end

    for _, fuel_name in ipairs(FUEL_ORDER) do
        if combinations[fuel_name] then
            return fuel_name
        end
    end

    return DEFAULT_SELECTION.fuel_2
end

local function normalize_selection(selection)
    local normalized = copy_selection(selection)
    local corrected = false

    if not ei_data.fusion.fuel_combinations[normalized.fuel_1] then
        normalized.fuel_1 = DEFAULT_SELECTION.fuel_1
        corrected = true
    end

    local combinations = ei_data.fusion.fuel_combinations[normalized.fuel_1]
    if not (combinations and combinations[normalized.fuel_2]) then
        normalized.fuel_2 = first_valid_second_fuel(normalized.fuel_1)
        corrected = true
    end

    if not ei_data.fusion.temp_modes[normalized.temperature] then
        normalized.temperature = DEFAULT_SELECTION.temperature
        corrected = true
    end

    if not ei_data.fusion.fuel_injection_modes[normalized.injection_rate] then
        normalized.injection_rate = DEFAULT_SELECTION.injection_rate
        corrected = true
    end

    normalized.corrected = corrected
    return normalized
end

local function build_recipe_name(selection)
    selection = normalize_selection(selection)
    return string.format(
        "ei-fusion-F1__%s-F2__%s-TM__%s-FM__%s",
        selection.fuel_1,
        selection.fuel_2,
        selection.temperature,
        selection.injection_rate
    )
end

local function parse_recipe_name(recipe_name)
    if type(recipe_name) ~= "string" then
        return nil
    end

    local selection = {
        fuel_1 = recipe_name:match("F1__(.+)%-F2__"),
        fuel_2 = recipe_name:match("F2__(.+)%-TM__"),
        temperature = recipe_name:match("TM__(.+)%-FM__"),
        injection_rate = recipe_name:match("FM__(.+)"),
    }

    if not (selection.fuel_1 and selection.fuel_2 and selection.temperature and selection.injection_rate) then
        return nil
    end

    return normalize_selection(selection)
end

local function get_entity_recipe_selection(entity)
    if not (entity and entity.valid and entity.get_recipe) then
        return nil
    end

    local recipe = entity.get_recipe()
    return parse_recipe_name(recipe and recipe.name or nil)
end

local function get_selection_metrics(selection)
    selection = normalize_selection(selection)
    local energy_value_MJ = ei_data.fusion.fuel_combinations[selection.fuel_1][selection.fuel_2] or 0
    local temp_multiplier = ei_data.fusion.temp_modes[selection.temperature] or 0
    local injection_mode = ei_data.fusion.fuel_injection_modes[selection.injection_rate] or {0, 0}
    local injection_multiplier = injection_mode[1] or 0
    local injection_amount = injection_mode[2] or 0
    local power_output_MW = energy_value_MJ * temp_multiplier * injection_multiplier
    local coolant_rate = ei_data.fusion.coolant_fuel_value and ei_data.fusion.coolant_fuel_value > 0
        and (power_output_MW / ei_data.fusion.coolant_fuel_value)
        or 0
    local neutron_flux = ei_neutron_collector.calc_fusion_flux(
        selection.fuel_1,
        selection.fuel_2,
        selection.temperature,
        selection.injection_rate
    )
    local efficiency = injection_amount > 0 and (temp_multiplier * injection_multiplier / injection_amount * 5) or 0

    return {
        power_output_MW = power_output_MW,
        coolant_rate = coolant_rate,
        neutron_flux = neutron_flux,
        efficiency = efficiency,
    }
end

local function get_runtime()
    storage.ei = storage.ei or {}
    local runtime = storage.ei.fusion_reactor
    if type(runtime) ~= "table" then
        runtime = {}
        storage.ei.fusion_reactor = runtime
    end

    runtime.version = FUSION_RUNTIME_VERSION
    runtime.reactors_by_unit = type(runtime.reactors_by_unit) == "table" and runtime.reactors_by_unit or {}
    runtime.reactor_units = type(runtime.reactor_units) == "table" and runtime.reactor_units or {}
    runtime.reactor_unit_index = type(runtime.reactor_unit_index) == "table" and runtime.reactor_unit_index or {}
    runtime.open_by_player = type(runtime.open_by_player) == "table" and runtime.open_by_player or {}
    runtime.update_cursor = tonumber(runtime.update_cursor) or 0
    return runtime
end

local function normalize_control_source(value)
    if value == CONTROL_SOURCE_CIRCUIT then
        return CONTROL_SOURCE_CIRCUIT
    end
    return CONTROL_SOURCE_MANUAL
end

local function register_unit(runtime, unit_number)
    if not runtime.reactor_unit_index[unit_number] then
        table.insert(runtime.reactor_units, unit_number)
        runtime.reactor_unit_index[unit_number] = #runtime.reactor_units
    end
end

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

    local ok, connected = pcall(source.connect_to, target, false, defines.wire_origin.script)
    if not ok then
        return false
    end

    return connected or connector_targets_match(source, target)
end

local function resolve_wire_connector_id(entity, preferred_ids)
    if not ei_lib.entity_check(entity) then
        return nil
    end

    local ok, connectors = pcall(entity.get_wire_connectors, true)
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

local function read_signal_value(entity, signal)
    if not model.entity_check(entity) then
        return 0
    end

    local seen_networks = {}
    local total = 0
    local ok, connectors = pcall(entity.get_wire_connectors, false)
    if not ok or type(connectors) ~= "table" then
        return 0
    end

    for connector_id, connector in pairs(connectors) do
        if connector and connector.valid and connector.real_connections and #connector.real_connections > 0 then
            local network_ok, network = pcall(entity.get_circuit_network, connector_id)
            if network_ok and network and not seen_networks[network.network_id] then
                seen_networks[network.network_id] = true

                local signal_ok, value = pcall(network.get_signal, signal)
                if signal_ok and value then
                    total = total + value
                end
            end
        end
    end

    return total
end

local function mode_from_signal(value, fallback)
    local index = math.floor((tonumber(value) or 0) + 0.5)
    return MODE_BY_INDEX[index] or fallback
end

local function fuel_from_signal(value, fallback)
    local index = math.floor((tonumber(value) or 0) + 0.5)
    return FUEL_BY_INDEX[index] or fallback
end

local function get_circuit_selection(entry)
    local fallback = normalize_selection(entry.manual_selection)
    local entity = entry.entity
    return normalize_selection({
        fuel_1 = fuel_from_signal(read_signal_value(entity, SIGNAL_INPUT_FUEL_1), fallback.fuel_1),
        fuel_2 = fuel_from_signal(read_signal_value(entity, SIGNAL_INPUT_FUEL_2), fallback.fuel_2),
        temperature = mode_from_signal(read_signal_value(entity, SIGNAL_INPUT_TEMPERATURE), fallback.temperature),
        injection_rate = mode_from_signal(read_signal_value(entity, SIGNAL_INPUT_INJECTION), fallback.injection_rate),
    })
end

local function clear_wire_proxy_output(proxy)
    if not ei_lib.entity_check(proxy) then
        return
    end

    local control = proxy.get_control_behavior()
    if not control or not control.valid then
        return
    end

    control.enabled = false
    local section = control.get_section(1)
    if not section then
        return
    end

    for i = 1, section.filters_count do
        section.clear_slot(i)
    end
end

local function set_wire_signal_slot(section, slot_index, signal, value)
    local ok = pcall(section.set_slot, slot_index, {value = signal, min = value})
    if ok then
        return true
    end

    pcall(section.clear_slot, slot_index)
    return false
end

local function build_signal_cache(entry)
    local selection = normalize_selection(entry.effective_selection or entry.manual_selection)
    local metrics = get_selection_metrics(selection)
    local wired = entry.wire_proxy_wired == true
    local circuit_live = entry.control_source == CONTROL_SOURCE_CIRCUIT and wired

    return {
        state_fuel_1 = FUEL_INDEX[selection.fuel_1] or 0,
        state_fuel_2 = FUEL_INDEX[selection.fuel_2] or 0,
        state_temperature = model.slider_map[selection.temperature] or 0,
        state_injection = model.slider_map[selection.injection_rate] or 0,
        power = math.floor(metrics.power_output_MW + 0.5),
        neutron_flux = math.floor((metrics.neutron_flux * 100) + 0.5),
        efficiency = math.floor((metrics.efficiency * 100) + 0.5),
        coolant_rate = math.floor((metrics.coolant_rate * 100) + 0.5),
        control_agent = entry.control_source == CONTROL_SOURCE_CIRCUIT and 2 or 1,
        fuel_agent = selection.corrected and 2 or 1,
        thermal_agent = model.slider_map[selection.temperature] or 0,
        coolant_agent = metrics.coolant_rate > 0 and 1 or 3,
        circuit_agent = (not wired and 1) or (circuit_live and 3 or 2),
    }
end

local function cache_matches(a, b)
    if not (a and b) then
        return false
    end

    for key, value in pairs(b) do
        if a[key] ~= value then
            return false
        end
    end

    return true
end

local function update_open_guis_for_unit(unit_number)
    local runtime = get_runtime()
    for player_index, open_unit in pairs(runtime.open_by_player) do
        if open_unit == unit_number then
            local player = game.get_player(player_index)
            if player then
                model.update_gui(player)
            end
        end
    end
end

function model.entity_check(entity)
    return ei_lib.entity_check(entity) and entity.name == FUSION_REACTOR_NAME
end

function model.check_global()
    get_runtime()
end

function model.destroy_wire_proxy(entry)
    if not entry then
        return
    end

    local proxy = entry.wire_proxy
    if ei_lib.entity_check(proxy) then
        proxy.destroy({raise_destroy = false})
    end

    entry.wire_proxy = nil
    entry.wire_proxy_connected = nil
    entry.wire_proxy_wired = nil
    entry.signal_cache = nil
end

function model.attach_wire_proxy_to_reactor(entry)
    if not entry then
        return false
    end

    local reactor = entry.entity
    local proxy = entry.wire_proxy
    if not (model.entity_check(reactor) and ei_lib.entity_check(proxy)) then
        return false
    end

    local reactor_red_id = resolve_wire_connector_id(reactor, {
        defines.wire_connector_id.circuit_red,
        defines.wire_connector_id.combinator_output_red,
        defines.wire_connector_id.combinator_input_red,
    })
    local reactor_green_id = resolve_wire_connector_id(reactor, {
        defines.wire_connector_id.circuit_green,
        defines.wire_connector_id.combinator_output_green,
        defines.wire_connector_id.combinator_input_green,
    })
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

    if (not reactor_red_id and not reactor_green_id) or (not proxy_red_id and not proxy_green_id) then
        entry.wire_proxy_connected = false
        return false
    end

    local connected = false
    if reactor_red_id and proxy_red_id then
        connected = ensure_internal_wire(reactor, reactor_red_id, proxy, proxy_red_id) or connected
    end
    if reactor_green_id and proxy_green_id then
        connected = ensure_internal_wire(reactor, reactor_green_id, proxy, proxy_green_id) or connected
    end

    entry.wire_proxy_connected = connected
    return connected
end

function model.ensure_wire_proxy(entry)
    if not entry or not model.entity_check(entry.entity) then
        return nil
    end

    local reactor = entry.entity
    local expected_position = {x = reactor.position.x, y = reactor.position.y}
    local proxy = entry.wire_proxy
    if ei_lib.entity_check(proxy) then
        if math.abs(proxy.position.x - expected_position.x) > 0.01
        or math.abs(proxy.position.y - expected_position.y) > 0.01 then
            pcall(proxy.teleport, expected_position)
        end
        if entry.wire_proxy_connected ~= true then
            model.attach_wire_proxy_to_reactor(entry)
        end
        return proxy
    end

    local ok, created_proxy = pcall(reactor.surface.create_entity, {
        name = FUSION_WIRE_PROXY_NAME,
        position = expected_position,
        force = reactor.force,
        create_build_effect_smoke = false,
        raise_built = false,
    })
    proxy = ok and created_proxy or nil

    if not ei_lib.entity_check(proxy) then
        return nil
    end

    entry.wire_proxy = proxy
    entry.wire_proxy_connected = nil
    entry.signal_cache = nil
    entry.wire_proxy_wired = false
    entry.last_wire_probe_tick = -WIRE_SCAN_INTERVAL_TICKS
    model.attach_wire_proxy_to_reactor(entry)
    return proxy
end

function model.is_reactor_externally_wired(entry)
    if not (entry and model.entity_check(entry.entity)) then
        return false
    end

    local reactor = entry.entity
    local ok, connectors = pcall(reactor.get_wire_connectors, false)
    if not ok or type(connectors) ~= "table" then
        return false
    end

    for _, connector in pairs(connectors) do
        if connector_has_external_peer(connector, entry.wire_proxy) then
            return true
        end
    end

    return false
end

function model.update_wire_proxy_signals(entry, event)
    if not (entry and entry.unit_number and model.entity_check(entry.entity)) then
        return false
    end

    local proxy = model.ensure_wire_proxy(entry)
    if not ei_lib.entity_check(proxy) then
        return false
    end

    if entry.wire_proxy_connected ~= true then
        clear_wire_proxy_output(proxy)
        entry.signal_cache = nil
        return false
    end

    local current_tick = ei_lib.get_event_tick(event)
    local externally_wired = entry.wire_proxy_wired == true
    if current_tick >= ((entry.last_wire_probe_tick or -WIRE_SCAN_INTERVAL_TICKS) + WIRE_SCAN_INTERVAL_TICKS) then
        externally_wired = model.is_reactor_externally_wired(entry)
        entry.wire_proxy_wired = externally_wired
        entry.last_wire_probe_tick = current_tick
    end

    if not externally_wired then
        clear_wire_proxy_output(proxy)
        entry.signal_cache = nil
        return false
    end

    local values = build_signal_cache(entry)
    if cache_matches(entry.signal_cache, values) then
        return false
    end

    local control = proxy.get_control_behavior()
    if not control or not control.valid then
        return false
    end

    control.enabled = true
    local section = control.get_section(1)
    if not section then
        section = control.add_section("fusion")
    end
    if not section then
        return false
    end

    section.active = true
    for i = 1, section.filters_count do
        section.clear_slot(i)
    end

    local wrote_all_slots = true
    wrote_all_slots = set_wire_signal_slot(section, 1, SIGNAL_STATE_FUEL_1, values.state_fuel_1) and wrote_all_slots
    wrote_all_slots = set_wire_signal_slot(section, 2, SIGNAL_STATE_FUEL_2, values.state_fuel_2) and wrote_all_slots
    wrote_all_slots = set_wire_signal_slot(section, 3, SIGNAL_STATE_TEMPERATURE, values.state_temperature) and wrote_all_slots
    wrote_all_slots = set_wire_signal_slot(section, 4, SIGNAL_STATE_INJECTION, values.state_injection) and wrote_all_slots
    wrote_all_slots = set_wire_signal_slot(section, 5, SIGNAL_POWER, values.power) and wrote_all_slots
    wrote_all_slots = set_wire_signal_slot(section, 6, SIGNAL_NEUTRON_FLUX, values.neutron_flux) and wrote_all_slots
    wrote_all_slots = set_wire_signal_slot(section, 7, SIGNAL_EFFICIENCY, values.efficiency) and wrote_all_slots
    wrote_all_slots = set_wire_signal_slot(section, 8, SIGNAL_COOLANT_RATE, values.coolant_rate) and wrote_all_slots
    wrote_all_slots = set_wire_signal_slot(section, 9, SIGNAL_CONTROL_AGENT, values.control_agent) and wrote_all_slots
    wrote_all_slots = set_wire_signal_slot(section, 10, SIGNAL_FUEL_AGENT, values.fuel_agent) and wrote_all_slots
    wrote_all_slots = set_wire_signal_slot(section, 11, SIGNAL_THERMAL_AGENT, values.thermal_agent) and wrote_all_slots
    wrote_all_slots = set_wire_signal_slot(section, 12, SIGNAL_COOLANT_AGENT, values.coolant_agent) and wrote_all_slots
    wrote_all_slots = set_wire_signal_slot(section, 13, SIGNAL_CIRCUIT_AGENT, values.circuit_agent) and wrote_all_slots

    if not wrote_all_slots then
        entry.signal_cache = nil
        return false
    end

    entry.signal_cache = values
    return true
end

function model.register_reactor(runtime, entity)
    local unit_number = get_entity_unit_number(entity)
    if not (model.entity_check(entity) and unit_number) then
        return nil
    end

    local entry = runtime.reactors_by_unit[unit_number]
    local recipe_selection = get_entity_recipe_selection(entity) or DEFAULT_SELECTION
    if not entry then
        entry = {
            unit_number = unit_number,
            entity = entity,
            control_source = CONTROL_SOURCE_MANUAL,
            manual_selection = normalize_selection(recipe_selection),
            effective_selection = normalize_selection(recipe_selection),
            wire_proxy = nil,
            wire_proxy_connected = nil,
            wire_proxy_wired = false,
            last_wire_probe_tick = -WIRE_SCAN_INTERVAL_TICKS,
            signal_cache = nil,
        }
        runtime.reactors_by_unit[unit_number] = entry
        register_unit(runtime, unit_number)
    else
        entry.entity = entity
        entry.control_source = normalize_control_source(entry.control_source)
        entry.manual_selection = normalize_selection(entry.manual_selection or recipe_selection)
        entry.effective_selection = normalize_selection(entry.effective_selection or recipe_selection)
        register_unit(runtime, unit_number)
    end

    return entry
end

local function apply_selection(entry, selection, event)
    if not (entry and model.entity_check(entry.entity)) then
        return false
    end

    selection = normalize_selection(selection)
    local recipe = build_recipe_name(selection)
    local current_recipe = entry.entity.get_recipe and entry.entity.get_recipe() or nil
    local changed = not current_recipe or current_recipe.name ~= recipe

    if changed and prototypes.recipe[recipe] then
        entry.entity.set_recipe(recipe)
        ei_neutron_collector.update_neutron_collectors_in_range(entry.entity)
    end

    entry.entity.recipe_locked = true
    entry.effective_selection = selection
    model.update_wire_proxy_signals(entry, event)
    update_open_guis_for_unit(entry.unit_number)
    return changed
end

local function service_reactor_entry(entry, event)
    if not (entry and model.entity_check(entry.entity)) then
        if entry then
            model.destroy_wire_proxy(entry)
        end
        return false
    end

    model.ensure_wire_proxy(entry)

    local selection = entry.manual_selection
    if entry.control_source == CONTROL_SOURCE_CIRCUIT then
        selection = get_circuit_selection(entry)
    end

    apply_selection(entry, selection, event)
    model.update_wire_proxy_signals(entry, event)
    return true
end

function model.rebuild_runtime_state(reason, event_or_tick)
    local runtime = get_runtime()
    for _, entry in pairs(runtime.reactors_by_unit) do
        model.destroy_wire_proxy(entry)
    end

    runtime.reactors_by_unit = {}
    runtime.reactor_units = {}
    runtime.reactor_unit_index = {}
    runtime.update_cursor = 0

    for _, surface in pairs(game.surfaces) do
        for _, proxy in pairs(surface.find_entities_filtered{name = FUSION_WIRE_PROXY_NAME}) do
            if ei_lib.entity_check(proxy) then
                proxy.destroy({raise_destroy = false})
            end
        end

        for _, entity in pairs(surface.find_entities_filtered{name = FUSION_REACTOR_NAME}) do
            local entry = model.register_reactor(runtime, entity)
            if entry then
                if not entity.get_recipe() then
                    entity.set_recipe(build_recipe_name(entry.manual_selection))
                end
                entity.recipe_locked = true
                service_reactor_entry(entry, event_or_tick)
            end
        end
    end
end

function model.on_configuration_changed(event)
    model.check_global()
    model.rebuild_runtime_state("configuration-changed", event)
end

function model.get_pending_work_count()
    local runtime = get_runtime()
    return #runtime.reactor_units
end

function model.update(limit, event)
    local runtime = get_runtime()
    local units = runtime.reactor_units
    local unit_count = #units
    if unit_count == 0 then
        return false
    end

    local budget = math.max(1, tonumber(limit) or 1)
    local processed = 0
    local checked = 0

    while processed < budget and checked < unit_count do
        runtime.update_cursor = (runtime.update_cursor % unit_count) + 1
        checked = checked + 1
        local unit_number = units[runtime.update_cursor]
        local entry = unit_number and runtime.reactors_by_unit[unit_number] or nil
        if entry then
            service_reactor_entry(entry, event)
            processed = processed + 1
        end
    end

    return processed > 0
end

function model.on_built_entity(entity)
    if model.entity_check(entity) == false then
        return
    end

    local runtime = get_runtime()
    local entry = model.register_reactor(runtime, entity)
    if not entry then
        return
    end

    if not entity.get_recipe() then
        entity.set_recipe(build_recipe_name(entry.manual_selection))
    end
    entity.recipe_locked = true
    service_reactor_entry(entry, game and game.tick or 0)
end

function model.on_destroyed_entity(entity, destroy_type)
    if not entity or entity.name ~= FUSION_REACTOR_NAME then
        return
    end

    local unit_number = get_entity_unit_number(entity)
    if not unit_number then
        return
    end

    local runtime = get_runtime()
    local entry = runtime.reactors_by_unit[unit_number]
    if entry then
        model.destroy_wire_proxy(entry)
    end
    runtime.reactors_by_unit[unit_number] = nil
    runtime.reactor_unit_index[unit_number] = nil

    for player_index, open_unit in pairs(runtime.open_by_player) do
        if open_unit == unit_number then
            local player = game.get_player(player_index)
            if player then
                model.close_gui(player)
            end
            runtime.open_by_player[player_index] = nil
        end
    end
end

function model.on_entity_settings_pasted(event)
    local source = event and event.source or nil
    local destination = event and event.destination or nil
    if not (model.entity_check(source) and model.entity_check(destination)) then
        return
    end

    local runtime = get_runtime()
    local source_entry = model.register_reactor(runtime, source)
    local destination_entry = model.register_reactor(runtime, destination)
    if not (source_entry and destination_entry) then
        return
    end

    destination_entry.control_source = source_entry.control_source
    destination_entry.manual_selection = normalize_selection(source_entry.manual_selection)
    apply_selection(destination_entry, source_entry.effective_selection or source_entry.manual_selection, event)
end

local function get_entry_for_player(player)
    local entity = ei_lib.get_valid_entity(player and player.opened)
    if not model.entity_check(entity) then
        return nil
    end

    local runtime = get_runtime()
    return model.register_reactor(runtime, entity)
end

local function add_fuel_buttons(control_flow, fuel_index)
    control_flow.add{type = "label", caption = {"exotic-industries.fusion-reactor-gui-fuel", fuel_index}}
    local button_frame = control_flow.add{
        type = "frame",
        name = "fuels-frame-" .. fuel_index,
        style = "slot_button_deep_frame"
    }
    button_frame.tags = {selected = DEFAULT_SELECTION["fuel_" .. fuel_index]}

    for _, fuel_name in ipairs(FUEL_ORDER) do
        button_frame.add{
            type = "sprite-button",
            sprite = "fluid/" .. fuel_name,
            tooltip = {"fluid-name." .. fuel_name},
            tags = {
                action = "set-fuel",
                parent_gui = GUI_NAME,
                fuel_name = fuel_name
            },
            style = "ei_slot_button_radio"
        }
    end
    control_flow.add{type = "empty-widget", style = "ei_vertical_pusher"}
end

function model.open_gui(player)
    if not player then
        return
    end

    if player.gui.relative[GUI_NAME] then
        model.close_gui(player)
    end

    local entry = get_entry_for_player(player)
    if not entry then
        return
    end

    local runtime = get_runtime()
    runtime.open_by_player[player.index] = entry.unit_number

    local root = player.gui.relative.add{
        type = "frame",
        name = GUI_NAME,
        anchor = {
            gui = defines.relative_gui_type.assembling_machine_gui,
            name = FUSION_REACTOR_NAME,
            position = defines.relative_gui_position.right
        },
        direction = "vertical"
    }

    do
        local titlebar = root.add{type = "flow", direction = "horizontal"}
        titlebar.add{
            type = "label",
            caption = {"exotic-industries.fusion-reactor-gui-title"},
            style = "frame_title"
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
                parent_gui = GUI_NAME,
                action = "goto-informatron",
                page = "fusion_power"
            }
        }
    end

    local main_container = root.add{
        type = "frame",
        name = "main-container",
        direction = "vertical",
        style = "inside_shallow_frame"
    }

    main_container.add{type = "frame", style = "ei_subheader_frame"}.add{
        type = "label",
        caption = {"exotic-industries.fusion-reactor-gui-status-title"},
        style = "subheader_caption_label"
    }

    local status_flow = main_container.add{
        type = "flow",
        name = "status-flow",
        direction = "vertical",
        style = "ei_inner_content_flow"
    }
    status_flow.add{type = "progressbar", name = "power-output", style = "ei_status_progressbar"}
    status_flow.add{type = "progressbar", name = "neutron-flux", style = "ei_status_progressbar_cyan"}
    status_flow.add{type = "progressbar", name = "efficiency", style = "ei_status_progressbar_grey"}

    main_container.add{type = "frame", style = "ei_subheader_frame_with_top_border"}.add{
        type = "label",
        caption = {"exotic-industries.fusion-reactor-gui-control-title"},
        style = "subheader_caption_label"
    }

    local control_flow = main_container.add{
        type = "flow",
        name = "control-flow",
        direction = "vertical",
        style = "ei_inner_content_flow"
    }

    add_fuel_buttons(control_flow, 1)
    add_fuel_buttons(control_flow, 2)

    local temperature_flow = control_flow.add{type = "flow", name = "temperature-flow", direction = "horizontal"}
    temperature_flow.add{
        type = "label",
        caption = {"exotic-industries.fusion-reactor-gui-temperature"},
        tooltip = {"exotic-industries.fusion-reactor-gui-temperature-tooltip"}
    }
    temperature_flow.add{type = "empty-widget", style = "ei_horizontal_pusher"}
    temperature_flow.add{type = "label", name = "level"}
    control_flow.add{
        type = "slider",
        name = "temperature-slider",
        minimum_value = 1,
        maximum_value = 3,
        tags = {parent_gui = GUI_NAME, action = "set-temperature"},
        style = "ei_relative_gui_slider"
    }

    control_flow.add{type = "empty-widget", style = "ei_vertical_pusher"}
    local injection_rate_flow = control_flow.add{type = "flow", name = "injection-rate-flow", direction = "horizontal"}
    injection_rate_flow.add{
        type = "label",
        caption = {"exotic-industries.fusion-reactor-gui-injection-rate"},
        tooltip = {"exotic-industries.fusion-reactor-gui-injection-rate-tooltip"}
    }
    injection_rate_flow.add{type = "empty-widget", style = "ei_horizontal_pusher"}
    injection_rate_flow.add{type = "label", name = "level"}
    control_flow.add{
        type = "slider",
        name = "injection-rate-slider",
        minimum_value = 1,
        maximum_value = 3,
        tags = {parent_gui = GUI_NAME, action = "set-injection-rate"},
        style = "ei_relative_gui_slider"
    }

    main_container.add{type = "frame", style = "ei_subheader_frame_with_top_border"}.add{
        type = "label",
        caption = {"exotic-industries.fusion-reactor-gui-interface-title"},
        style = "subheader_caption_label"
    }
    local interface_flow = main_container.add{
        type = "flow",
        name = "interface-flow",
        direction = "vertical",
        style = "ei_inner_content_flow"
    }
    local source_flow = interface_flow.add{type = "flow", name = "source-flow", direction = "horizontal"}
    source_flow.add{
        type = "button",
        name = "manual-source",
        caption = {"exotic-industries.fusion-reactor-gui-manual-source"},
        tags = {parent_gui = GUI_NAME, action = "set-control-source", control_source = CONTROL_SOURCE_MANUAL}
    }
    source_flow.add{
        type = "button",
        name = "circuit-source",
        caption = {"exotic-industries.fusion-reactor-gui-circuit-source"},
        tags = {parent_gui = GUI_NAME, action = "set-control-source", control_source = CONTROL_SOURCE_CIRCUIT}
    }
    interface_flow.add{type = "label", name = "interface-state"}

    main_container.add{type = "frame", style = "ei_subheader_frame_with_top_border"}.add{
        type = "label",
        caption = {"exotic-industries.fusion-reactor-gui-agents-title"},
        style = "subheader_caption_label"
    }
    local agents_flow = main_container.add{
        type = "flow",
        name = "agents-flow",
        direction = "vertical",
        style = "ei_inner_content_flow"
    }
    agents_flow.add{type = "label", name = "control-agent"}
    agents_flow.add{type = "label", name = "fuel-agent"}
    agents_flow.add{type = "label", name = "thermal-agent"}
    agents_flow.add{type = "label", name = "coolant-agent"}
    agents_flow.add{type = "label", name = "circuit-agent"}

    main_container.add{type = "frame", style = "ei_subheader_frame_with_top_border"}.add{
        type = "label",
        caption = {"exotic-industries.fusion-reactor-gui-options-title"},
        style = "subheader_caption_label"
    }
    local options_flow = main_container.add{
        type = "flow",
        name = "options-flow",
        direction = "vertical",
        style = "ei_inner_content_flow"
    }
    local preset_flow = options_flow.add{type = "flow", direction = "horizontal"}
    preset_flow.add{type = "button", caption = {"exotic-industries.fusion-reactor-gui-balanced-preset"}, tags = {parent_gui = GUI_NAME, action = "preset", preset = "balanced"}}
    preset_flow.add{type = "button", caption = {"exotic-industries.fusion-reactor-gui-power-preset"}, tags = {parent_gui = GUI_NAME, action = "preset", preset = "power"}}
    preset_flow.add{type = "button", caption = {"exotic-industries.fusion-reactor-gui-flux-preset"}, tags = {parent_gui = GUI_NAME, action = "preset", preset = "flux"}}
    local command_flow = options_flow.add{type = "flow", direction = "horizontal"}
    command_flow.add{type = "button", caption = {"exotic-industries.fusion-reactor-gui-reset-defaults"}, tags = {parent_gui = GUI_NAME, action = "reset-defaults"}}
    command_flow.add{type = "button", caption = {"exotic-industries.fusion-reactor-gui-refresh-collectors"}, tags = {parent_gui = GUI_NAME, action = "refresh-collectors"}}

    model.update_gui(player)
end

function model.update_gui(player)
    if not player then
        return
    end

    local root = player.gui.relative[GUI_NAME]
    local entry = get_entry_for_player(player)
    if not (root and entry) then
        model.close_gui(player)
        return
    end

    local selection = normalize_selection(entry.effective_selection or entry.manual_selection)
    local manual_selection = normalize_selection(entry.manual_selection)
    local metrics = get_selection_metrics(selection)
    local main_container = root["main-container"]
    local status = main_container["status-flow"]
    local control = main_container["control-flow"]
    local interface = main_container["interface-flow"]
    local agents = main_container["agents-flow"]

    status["power-output"].caption = {"exotic-industries.fusion-reactor-gui-power-output", math.floor(metrics.power_output_MW + 0.5)}
    status["power-output"].value = math.min(1, metrics.power_output_MW / ei_data.fusion.max_power)
    status["neutron-flux"].caption = {"exotic-industries.fusion-reactor-gui-neutron-flux", string.format("%.2f", metrics.neutron_flux)}
    status["neutron-flux"].value = math.min(1, metrics.neutron_flux / 2)
    status["efficiency"].caption = {"exotic-industries.fusion-reactor-gui-efficiency", string.format("%.2f", metrics.efficiency * 100)}
    status["efficiency"].value = math.min(1, metrics.efficiency)

    local fuel_1_frame = control["fuels-frame-1"]
    local fuel_2_frame = control["fuels-frame-2"]
    fuel_1_frame.tags = {selected = manual_selection.fuel_1}
    fuel_2_frame.tags = {selected = manual_selection.fuel_2}

    for _, elem in pairs(fuel_1_frame.children) do
        elem.enabled = elem.tags.fuel_name ~= manual_selection.fuel_1
        elem.style = elem.tags.fuel_name == selection.fuel_1 and "ei_slot_button_radio" or "slot_button"
    end

    for _, elem in pairs(fuel_2_frame.children) do
        if ei_data.fusion.fuel_combinations[manual_selection.fuel_1][elem.tags.fuel_name] then
            elem.style = elem.tags.fuel_name == selection.fuel_2 and "ei_slot_button_radio" or "slot_button"
            elem.enabled = elem.tags.fuel_name ~= manual_selection.fuel_2
        else
            elem.style = "slot_button"
            elem.enabled = false
        end
    end

    control["temperature-flow"].level.caption = model.temp_map[manual_selection.temperature]
    control["temperature-slider"].slider_value = model.slider_map[manual_selection.temperature]
    control["injection-rate-flow"].level.caption = {"exotic-industries.fusion-reactor-gui-" .. manual_selection.injection_rate}
    control["injection-rate-slider"].slider_value = model.slider_map[manual_selection.injection_rate]

    interface["source-flow"]["manual-source"].enabled = entry.control_source ~= CONTROL_SOURCE_MANUAL
    interface["source-flow"]["circuit-source"].enabled = entry.control_source ~= CONTROL_SOURCE_CIRCUIT
    interface["interface-state"].caption = entry.control_source == CONTROL_SOURCE_CIRCUIT
        and {"exotic-industries.fusion-reactor-gui-circuit-state"}
        or {"exotic-industries.fusion-reactor-gui-manual-state"}

    local signal_cache = build_signal_cache(entry)
    agents["control-agent"].caption = {"exotic-industries.fusion-reactor-gui-control-agent", signal_cache.control_agent}
    agents["fuel-agent"].caption = {"exotic-industries.fusion-reactor-gui-fuel-agent", signal_cache.fuel_agent}
    agents["thermal-agent"].caption = {"exotic-industries.fusion-reactor-gui-thermal-agent", signal_cache.thermal_agent}
    agents["coolant-agent"].caption = {"exotic-industries.fusion-reactor-gui-coolant-agent", signal_cache.coolant_agent}
    agents["circuit-agent"].caption = {"exotic-industries.fusion-reactor-gui-circuit-agent", signal_cache.circuit_agent}
end

function model.update_recipe(player)
    local entry = get_entry_for_player(player)
    local root = player and player.gui.relative[GUI_NAME] or nil
    if not (entry and root) then
        return
    end

    local control = root["main-container"]["control-flow"]
    entry.manual_selection = normalize_selection({
        fuel_1 = control["fuels-frame-1"].tags.selected,
        fuel_2 = control["fuels-frame-2"].tags.selected,
        temperature = model.slider_array[control["temperature-slider"].slider_value],
        injection_rate = model.slider_array[control["injection-rate-slider"].slider_value],
    })

    service_reactor_entry(entry, game and game.tick or 0)
end

function model.close_gui(player)
    if not player then
        return
    end

    local runtime = get_runtime()
    runtime.open_by_player[player.index] = nil
    if player.gui.relative[GUI_NAME] then
        player.gui.relative[GUI_NAME].destroy()
    end
end

function model.on_gui_opened(event)
    model.open_gui(game.get_player(event.player_index))
end

function model.on_player_left_game(player_index)
    local runtime = get_runtime()
    runtime.open_by_player[player_index] = nil
end

local function apply_preset(entry, preset)
    if preset == "power" then
        entry.manual_selection = normalize_selection({
            fuel_1 = "ei-heated-tritium",
            fuel_2 = "ei-heated-helium-3",
            temperature = "high",
            injection_rate = "high",
        })
    elseif preset == "flux" then
        entry.manual_selection = normalize_selection({
            fuel_1 = "ei-heated-deuterium",
            fuel_2 = "ei-heated-tritium",
            temperature = "low",
            injection_rate = "high",
        })
    else
        entry.manual_selection = normalize_selection(DEFAULT_SELECTION)
    end
end

function model.on_gui_click(event)
    if not (event and event.element and event.element.valid and event.element.tags) then
        return
    end

    local action = event.element.tags.action
    local player = game.get_player(event.player_index)
    local entry = get_entry_for_player(player)

    if action == "set-fuel" then
        event.element.parent.tags = {selected = event.element.tags.fuel_name}
        model.update_recipe(player)
    elseif action == "set-control-source" and entry then
        entry.control_source = normalize_control_source(event.element.tags.control_source)
        service_reactor_entry(entry, event)
    elseif action == "preset" and entry then
        apply_preset(entry, event.element.tags.preset)
        service_reactor_entry(entry, event)
    elseif action == "reset-defaults" and entry then
        entry.manual_selection = normalize_selection(DEFAULT_SELECTION)
        service_reactor_entry(entry, event)
    elseif action == "refresh-collectors" and entry and model.entity_check(entry.entity) then
        ei_neutron_collector.update_neutron_collectors_in_range(entry.entity)
        model.update_gui(player)
    elseif action == "goto-informatron" then
        remote.call("informatron", "informatron_open_to_page", {
            player_index = event.player_index,
            interface = "exotic-industries-informatron",
            page_name = event.element.tags.page,
        })
    end
end

function model.on_gui_value_changed(event)
    if not (event and event.element and event.element.valid and event.element.tags) then
        return
    end

    local action = event.element.tags.action
    local player = game.get_player(event.player_index)
    if action == "set-temperature" or action == "set-injection-rate" then
        model.update_recipe(player)
        player.play_sound{path = "utility/list_box_click"}
    end
end

return model

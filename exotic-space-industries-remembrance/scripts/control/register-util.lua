--==============================================================================
-- ESIR FILE MAP
-- owns: shared entity registration helpers
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: build/destroy helper dispatch
-- forwarded_events: add_spaced_update, deregister_collector_entity, deregister_fluid_entity, extend_beacon_table, init, init_beacon, link_slave, make_slave, register_collector_entity, register_fluid_entity, register_master_entity, setup_master_slave, subtract_spaced_update, teardown_master_slave, unregister_master_entity, unregister_slave_entity
-- storage_roots: storage.ei
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: init, entity rebuilds
--==============================================================================
--[[
==============storage structure================================
storage.ei = storage.ei

key is for according mechanic f.e. portal
sub_key for master/slave
indexed by master unit number

f.e portal machine with 2 slaves: master unit number = 1, slaves unit number = 2,3

storage.ei.portal.master[1].entity = entity of master
storage.ei.portal.master[1].slaves.slave_chest = 2
storage.ei.portal.master[1].slaves.slave_combinator = 3

storage.ei.portal.slave[2].master = 1
storage.ei.portal.slave[2].entity = slave_entity
storage.ei.portal.slave[3].master = 1
storage.ei.portal.slave[3].entity = slave_entity


--]]

--adds storage table entry for given table with keys 
local model = {}

---------------------------------------------------------------------
-- Initialization Utilities
---------------------------------------------------------------------

local function ensure_storage()
    if not storage.ei then
        storage.ei = {}
    end
end

local function ensure_subtables(key, ...)
    ensure_storage()
    storage.ei[key] = storage.ei[key] or {}
    for _, subkey in ipairs({...}) do
        storage.ei[key][subkey] = storage.ei[key][subkey] or {}
    end
end

local function get_unit_number(input)
    return type(input) == "number" and input or input.unit_number
end

---------------------------------------------------------------------
-- Model Initialization
---------------------------------------------------------------------

function model.init(keys, with_master_slave)
    ensure_storage()
    for _, key in ipairs(keys) do
        if not storage.ei[key] then
            storage.ei[key] = {}
        end
        if with_master_slave then
            if not storage.ei[key].master then
                storage.ei[key].master = {}
            end
            if not storage.ei[key].slave then
                storage.ei[key].slave = {}
            end
        end
    end
end

---------------------------------------------------------------------
-- Fluid Entity Registration
---------------------------------------------------------------------

function model.register_fluid_entity(entity)
    ensure_subtables("fluid_entity")
    if not (entity and entity.valid and entity.unit_number) then
        return false
    end

    if ei_fluid_safety and ei_fluid_safety.on_fluid_entity_registered then
        return ei_fluid_safety.on_fluid_entity_registered(entity)
    end

    if storage.ei.fluid_entity[entity.unit_number] then
        storage.ei.fluid_entity[entity.unit_number] = entity
        return false
    end

    storage.ei.fluid_entity_count = (storage.ei.fluid_entity_count or 0) + 1
    storage.ei.fluid_entity[entity.unit_number] = entity
    return true
end

function model.deregister_fluid_entity(entity)
    ensure_subtables("fluid_entity")
    if not entity then
        return false
    end

    if ei_fluid_safety and ei_fluid_safety.on_fluid_entity_deregistered then
        return ei_fluid_safety.on_fluid_entity_deregistered(entity)
    end

    if not storage.ei.fluid_entity[entity.unit_number] then
        return false
    end

    storage.ei.fluid_entity_count = math.max(0, (storage.ei.fluid_entity_count or 0) - 1)
    storage.ei.fluid_entity[entity.unit_number] = nil
    return true
end

---------------------------------------------------------------------
-- Master Entity Management
---------------------------------------------------------------------

function model.register_master_entity(key, entity, extra_data)
    ensure_subtables(key, "master")

    local unit = entity.unit_number
    local master_entry = {
        entity = entity,
        slaves = {}
    }

    if extra_data then
        for k, v in pairs(extra_data) do
            master_entry[k] = v
        end
    end

    storage.ei[key].master[unit] = master_entry
    return unit
end

function model.unregister_master_entity(key, master)
    ensure_subtables(key, "master")
    local unit = get_unit_number(master)

    if not storage.ei[key].master[unit] then return false end
    storage.ei[key].master[unit] = nil
    return true
end

---------------------------------------------------------------------
-- Slave Entity Management
---------------------------------------------------------------------

function model.unregister_slave_entity(key, slave, master, should_destroy)
    ensure_subtables(key, "slave", "master")

    local unit = get_unit_number(slave)
    local slave_entry = storage.ei[key].slave[unit]
    if not slave_entry then return false end

    local slave_entity = type(slave) == "number" and slave_entry.entity or slave
    local master_unit = slave_entry.master

    -- Unlink from master
    for k, v in pairs(storage.ei[key].master[master_unit].slaves) do
        if v == unit then
            storage.ei[key].master[master_unit].slaves[k] = nil
        end
    end

    storage.ei[key].slave[unit] = nil

    if should_destroy and slave_entity and slave_entity.valid then
        slave_entity.destroy()
    end

    return true
end

function model.make_slave(key, master, name, offset)
    ensure_subtables(key, "master", "slave")

    local unit = get_unit_number(master)
    local master_entity = storage.ei[key].master[unit].entity

    local slave = master_entity.surface.create_entity {
        name = name,
        position = {
            x = master_entity.position.x + (offset.x or 0),
            y = master_entity.position.y + (offset.y or 0)
        },
        force = master_entity.force
    }

    slave.destructible = false
    return slave
end

function model.link_slave(key, master, slave, name)
    ensure_subtables(key, "master", "slave")

    local master_unit = get_unit_number(master)
    local slave_unit = get_unit_number(slave)

    storage.ei[key].master[master_unit].slaves[name] = slave_unit
    storage.ei[key].slave[slave_unit] = {
        master = master_unit,
        entity = type(slave) ~= "number" and slave or nil
    }

    return true
end

---------------------------------------------------------------------
-- Beacon Helpers
---------------------------------------------------------------------

function model.extend_beacon_table(key, master)
    ensure_subtables(key, "master")
    local unit = get_unit_number(master)
    storage.ei[key].master[unit].status = false
end

function model.init_beacon(key, master)
    ensure_subtables(key, "master")
    local unit = get_unit_number(master)
    local entity = storage.ei[key].master[unit].entity
    if entity then
        entity.active = false
    end
end
---------------------------------------------------------------------
-- Sets up a master-slave pair for a given key and entity
-- Automatically:
--   - Registers the master
--   - Creates a slave at the given offset
--   - Links the slave to the master under given slave_name
--   - Initializes the beacon state (if applicable)
--   - Increments spaced update counter
-- Returns:
--   master_unit_number, slave_entity
---------------------------------------------------------------------
function model.setup_master_slave(key, entity, slave_entity_name, slave_name, offset)
    if not key or not entity or not slave_entity_name or not slave_name then
        log("Missing required arguments for setup_master_slave")
        return
    end
    model.init({key}, true)
    offset = offset or {x = 0, y = 0}

    local master_unit = model.register_master_entity(key, entity)
    local slave_entity = model.make_slave(key, master_unit, slave_entity_name, offset)
    model.link_slave(key, master_unit, slave_entity, slave_name)

    -- Safely try to initialize beacon state (if relevant)
    pcall(function()
        model.init_beacon(key, master_unit)
    end)

    model.add_spaced_update()

    return master_unit, slave_entity
end
---------------------------------------------------------------------
-- Tears down a copper_beacon master-slave pair
--   - Safely checks for master existence
--   - Unregisters slave and master
--   - Optionally destroys the slave entity
--   - Decrements spaced update counter
---------------------------------------------------------------------
function model.teardown_master_slave(key, entity, slave_name)
    local master_unit = entity.unit_number
    local master_data = storage.ei[key] and storage.ei[key].master and storage.ei[key].master[master_unit]

    if not master_data then return false end

    local slave_unit = master_data.slaves[slave_name]
    model.unregister_slave_entity(key, slave_unit, master_unit, true)
    model.unregister_master_entity(key, master_unit)
    model.subtract_spaced_update()

    return true
end

---------------------------------------------------------------------
-- Utility Bookkeeping
---------------------------------------------------------------------

function model.add_spaced_update()
    storage.ei.spaced_updates = (storage.ei.spaced_updates or 0) + 1
end

function model.subtract_spaced_update()
    storage.ei.spaced_updates = math.max(0, (storage.ei.spaced_updates or 0) - 1)
end

return model


--[[
function model.register_collector_entity(entity)
    if not check_init("solar_collector") then
        return
    end

    storage.ei["solar_collector"][entity.unit_number] = entity
    storage.ei.satellite.collectors = storage.ei.satellite.collectors + 1
end

function model.deregister_collector_entity(entity)
    if not check_init("solar_collector") then
        return
    end

    storage.ei["solar_collector"][entity.unit_number] = nil
    storage.ei.satellite.collectors = storage.ei.satellite.collectors - 1
end
]]

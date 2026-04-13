--==============================================================================
-- ESIR FILE MAP
-- owns: camp-fire periodic fire spawning
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: build/destroy and scheduled tick step 1
-- forwarded_events: on_built_entity, on_destroyed_entity, updater
-- storage_roots: storage.ei
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: init, configuration change, entity topology changes
--==============================================================================
-- campfire
local model = {}
ei_lib = require("lib/lib")
local FIRE_UPDATE_TICK = math.max(150,ei_ticksPerFullUpdate)
--------------------------------------------------------------------------------
local function register(entity)
    if entity and entity.unit_number then
        storage.ei.campfire[entity.unit_number] = entity
    end
end
function model.on_built_entity(event)
    if event and event.entity and event.entity.valid and event.entity.name == "ei-camp-fire" then
        register(event.entity)
    end
end
local function cleanup(entity)
    if entity and entity.unit_number then
        storage.ei.campfire[entity.unit_number] = nil
    end
end
function model.on_destroyed_entity(event)
    if event and event.entity and event.entity.valid and event.entity.name == "ei-camp-fire" then
        cleanup(event.entity)
    end
end
function model.updater(event)
    if not event or not event.tick or not storage.ei.campfire or ei_lib.getn(storage.ei.campfire) == 0 then
        return
    end

    local last_run_tick = storage.ei.campfire_last_run_tick or 0
    if event.tick - last_run_tick < FIRE_UPDATE_TICK then
        return
    end

    storage.ei.campfire_last_run_tick = event.tick

    for id, entity in pairs(storage.ei.campfire) do
        if entity.valid and entity.is_crafting() then
            local name = "ei-small-fire"
            if 0.25 > math.random() then -- roulette knight
                name = "fire-flame-on-tree"
            end
            entity.surface.create_entity{
                name = name,
                position = entity.position,
                force = "neutral",
                raise_built = true,
            }
        elseif not entity.valid then
            storage.ei.campfire[id] = nil
        end
    end
end

return model

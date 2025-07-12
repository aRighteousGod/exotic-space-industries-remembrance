-- campfire
local model = {}
ei_lib = require("lib/lib")
local FIRE_UPDATE_TICK = math.max(60,ei_ticksPerFullUpdate)
--------------------------------------------------------------------------------

function model.on_built_entity(event)
    if event.entity.name == "ei-camp-fire" then
        storage.ei.campfire[event.entity.unit_number] = event.entity
    end
end

local function cleanup(entity)
    if entity.unit_number then
        storage.ei.campfire[entity.unit_number] = nil
    end
end
function model.on_destroyed_entity(event)
    if event.entity.name == "ei-camp-fire" then
        cleanup(event.entity)
    end
end
function model.updater(event)
    if not event or (event.tick % FIRE_UPDATE_TICK > 0) or not storage.ei.campfire or ei_lib.getn(storage.ei.campfire) == 0 then return end
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
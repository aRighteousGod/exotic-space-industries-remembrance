--==============================================================================
-- ESIR FILE MAP
-- owns: one-time installed-module reconciliation when beacon permissions tighten
-- loaded_by: control.lua
-- cadence: init and configuration changes only; no tick work
-- forwarded_events: on_init, on_configuration_changed
-- storage_roots: storage.ei.beacon_module_policy
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: tightened family permissions
--==============================================================================
-- blueprint: .codex/esir/blueprints/beacon-overload.md#contract
local lib = require("lib/lib")
local config = require("lib/module-policy-config")
local model = {}

---@return table<string, BeaconModulePermissions>
local function current_policy()
    return {nitrogen = config.resolve("nitrogen"), alien = config.resolve("alien")}
end

function model.on_init()
    storage.ei.beacon_module_policy = current_policy()
end

-- blueprint-ref: .codex/esir/blueprints/beacon-overload.md#module-permissions
-- Native prototype restrictions do not evict installed modules on save reload.
-- Penalties remain legal: only positive quality/productivity admit these effects.
function model.on_configuration_changed()
    local previous = storage.ei.beacon_module_policy or {
        nitrogen = {quality = true, productivity = true}, alien = {quality = true, productivity = true},
    }
    local current = current_policy()
    local names = {}
    for name, family in pairs(config.beacon_families) do
        local old, new = previous[family], current[family]
        if (old.quality and not new.quality) or (old.productivity and not new.productivity) then
            names[#names + 1] = name
        end
    end
    table.sort(names)
    if #names > 0 then
        for _, surface in pairs(game.surfaces) do
            for _, entity in ipairs(surface.find_entities_filtered{name = names}) do
                if lib.entity_check(entity) then
                    local policy = current[config.beacon_families[entity.name]]
                    local inventory = entity.get_module_inventory()
                    for index = 1, inventory and #inventory or 0 do
                        local stack = inventory[index]
                        if stack.valid_for_read then
                            local effects = stack.prototype.module_effects or {}
                            if (not policy.quality and (effects.quality or 0) > 0)
                                or (not policy.productivity and (effects.productivity or 0) > 0) then
                                local before = stack.count
                                local spilled = surface.spill_item_stack{
                                    position = entity.position, stack = stack, enable_looted = true,
                                    allow_belts = false, use_start_position_on_failure = true, drop_full_stack = true,
                                }
                                local transferred = 0
                                for _, item in ipairs(spilled) do
                                    if lib.entity_check(item) and item.stack.valid_for_read then
                                        transferred = transferred + item.stack.count
                                    end
                                end
                                if transferred >= before then stack.clear()
                                elseif transferred > 0 then stack.count = before - transferred end
                                if transferred ~= before then
                                    error("ESIR beacon module reconciliation could not return every module at " .. entity.name)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    storage.ei.beacon_module_policy = current
end

return model

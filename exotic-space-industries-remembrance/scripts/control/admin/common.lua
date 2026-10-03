-- blueprint: .codex/esir/blueprints/admin-tools.md#contract
-- Admin state and trust boundary. No state is created by status inspection.
local config = require("lib/admin-tools-config")
local lib = require("lib/lib")
local model = {}

---@class EiAdminState
---@field version integer
---@field sessions table<uint,table> GUI handles, drafts and cached page state, owned per viewer.
---@field pending_selection table<uint,table> Native cursor/view restoration records.
---@field modes table<uint,table> Exact character, inventory and mode restoration ownership.
---@field jails table<uint,table> Simulation-clock sentences and prior permissions/location.
---@field players table<uint,table> Deferred offline restoration and ready-character spawning.
---@field force_spawns table<uint,table> Explicit destinations for future new/respawned characters.
---@field instant_research table<uint,{actor_index:uint}> Revalidated automation owners.
---@field research_due table<uint,table> One deferred native completion per selected technology.
---@field restrictions table<uint,table> Owned permission overlays.
---@field world table|nil Bounded creation/chart/generation jobs and explicit planet policies.
---@field inspection table|nil One bounded read-only registry inspection.
---@field ui_watch table<uint,boolean>|nil Visible countdown/progress sessions only.
---@field ui_due_tick MapTick|nil
---@field auto_refresh_buckets table<MapTick,uint[]>|nil Optional visible-only refresh ownership.
---@field auto_refresh_due_tick MapTick|nil Cached earliest due refresh; absent when idle.
---@field speed_before number|nil Restored when the toolkit is disabled.

---@return boolean
function model.enabled()
    return settings.startup[config.setting] and settings.startup[config.setting].value == true or false
end

---@return EiAdminState|nil
function model.peek()
    return storage.ei and storage.ei.admin_tools or nil
end

---@return EiAdminState
function model.state()
    storage.ei = storage.ei or {}
    local state = storage.ei.admin_tools
    if not state then
        state = {version=config.version, sessions={}, pending_selection={}, modes={}, jails={}, players={},
            policies={}, jobs={}, force_spawns={}, instant_research={}, research_due={}, restrictions={}}
        storage.ei.admin_tools = state
    end
    return state
end

---@param actor LuaPlayer|nil
---@param allow_console boolean|nil
---@return boolean,string|nil
function model.authorize(actor, allow_console)
    if not model.enabled() then return false, "Administration tools are disabled in startup settings." end
    if actor == nil and allow_console then return true end
    if not (actor and actor.valid and actor.admin) then return false, "Administrator access is required." end
    return true
end

---@param player_index uint|nil
---@param message LocalisedString
function model.notify(player_index, message)
    local player = player_index and game.get_player(player_index)
    if player and player.valid then player.print(message) else log("[ESIR admin] " .. serpent.line(message)) end
end

---@param actor LuaPlayer|nil
---@param action string
---@param args table
---@param result boolean
function model.audit(actor, action, args, result)
    local entity=lib.get_valid_entity(args.entity)
    log("[ESIR admin] " .. serpent.line({actor=actor and actor.name or "server", action=action,
        player=args.player_index, player_name=args.player_name, force=args.force_index, planet=args.planet, surface=args.surface_index,
        entity=entity and entity.name,unit=entity and entity.unit_number,module=args.module_id,
        position=args.position, success=result == true}))
end

---@param value any
---@param minimum number
---@param maximum number
---@return number|nil
function model.number(value, minimum, maximum)
    local number = tonumber(value)
    if not number or number ~= number or number < minimum or number > maximum then return nil end
    return number
end

return model

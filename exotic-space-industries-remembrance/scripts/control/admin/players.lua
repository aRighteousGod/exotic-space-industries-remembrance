--==============================================================================
-- ESIR FILE MAP
-- owns: admin player transit, spawn overrides, owned modes, and timed confinement
-- loaded_by: scripts/control/admin-tools.lua
-- cadence: player lifecycle events; one displayed-second job per connected prisoner
-- forwarded_events: execute, on_player_event, on_player_left_game, on_player_removed, on_player_changed_surface, on_player_controller_changed, on_permission_group_edited, on_permission_group_deleted, on_surface_deleted, on_display_changed, on_force_removed, on_forces_merged, on_configuration_changed, has_tick_work, updater, peek_summary
-- storage_roots: storage.ei.admin_tools.players, modes, jails, pending_spawns
-- gui_ids: ei-admin-jail-status (persistent read-only prisoner status)
-- remote_interfaces: none
-- rebuild_on: configuration changes; pending offline recovery on player entry
--==============================================================================
-- blueprint: .codex/esir/blueprints/admin-tools.md#contract
local model = {}
local lib = require("lib/lib")
local ctx
local transitioning = {}
local JAIL_SURFACE = "ei-admin-jail"
local JAIL_GROUP = "ei-admin-jail"
local JAIL_HUD = "ei-admin-jail-status"
local editing_jail_group = false
local RETRY_TICKS = 60
local MAX_RETRIES = 10
local JOB_BUDGET = 16

---@class ESIRAdminPlayerContext
---@field enabled fun():boolean
---@field state fun():table
---@field valid_entity fun(entity:any):LuaEntity|nil
---@field scheduler table
---@field notify fun(player_index:integer|nil,message:LocalisedString)
---@field changed fun(page:string,target:any)
---@field resolve_surface fun(name:string|integer,create:boolean):LuaSurface|nil
---@class ESIRAdminPlayerMode
---@field character LuaEntity|nil Original body; never cloned.
---@field destructible_before boolean|nil
---@field invulnerable boolean|nil
---@field cheat_before boolean|nil
---@field god table|nil
---@field escrow LuaInventory|nil Exact native stacks awaiting return.
---@field cleanup_pending boolean|nil
---@class ESIRAdminJail
---@field surface_index integer
---@field return_surface_index integer
---@field return_position MapPosition
---@field permission_group_id integer|nil
---@field remaining_ticks integer
---@field timer_mode string
---@field online_since integer|nil
---@field deadline integer|nil
---@field release_pending boolean|nil
---@field suspended table
---@field reason string
---@field character LuaEntity|nil Jail-owned protected body.
---@field destructible_before boolean|nil
---@field hud LuaGuiElement|nil
---@field hud_second integer|nil
---@field group_deleted boolean|nil Native deletion moved membership to Default.

---@param context ESIRAdminPlayerContext
function model.configure(context)
    ctx = context
end

-- Only mutation boundaries call state(); peek paths never initialize storage.
local function state()
    local root = ctx.state()
    root.players = root.players or {}
    root.modes = root.modes or {}
    root.jails = root.jails or {}
    root.pending_spawns = root.pending_spawns or {}
    local players = root.players
    players.spawn_by_force = players.spawn_by_force or {}
    players.due_by_player = players.due_by_player or {}
    players.retry_attempts = players.retry_attempts or {}
    players.due_buckets = ctx.scheduler.ensure_delayed_buckets(players.due_buckets)
    return root
end

local function peek()
    return storage and storage.ei and storage.ei.admin_tools or nil
end

local function changed(index)
    if ctx.changed then ctx.changed("players", index) end
end

local function notify(index, message)
    if ctx.notify then ctx.notify(index, message) end
end

local function schedule(index, tick)
    local root = state()
    local players = root.players
    local existing = players.due_by_player[index]
    if existing and existing <= tick then return end
    players.due_by_player[index] = tick
    ctx.scheduler.delayed_schedule(players.due_buckets, tick, {index = index, tick = tick})
    if not players.next_due_tick or tick < players.next_due_tick then players.next_due_tick = tick end
end

local function unschedule(index)
    local root = state()
    root.players.due_by_player[index] = nil
end

-- Failed controller/landing recovery gets ten attempts, then waits for a new
-- player lifecycle event or explicit action. Sentence deadlines are not retries.
local function schedule_retry(index, tick)
    local root = state()
    local attempts = (root.players.retry_attempts[index] or 0) + 1
    root.players.retry_attempts[index] = attempts
    if attempts <= MAX_RETRIES then schedule(index, tick + RETRY_TICKS) end
end

local function reset_retries(index)
    state().players.retry_attempts[index] = nil
end

local function position(value)
    if value == nil then return nil end
    if type(value) ~= "table" then return false end
    local x, y = tonumber(value.x or value[1]), tonumber(value.y or value[2])
    if not lib.is_valid_number(x) or not lib.is_valid_number(y)
        or math.abs(x) > 1000000 or math.abs(y) > 1000000 then return false end
    return {x = x, y = y}
end

local function mode_for(index)
    local root = state()
    root.modes[index] = root.modes[index] or {}
    return root.modes[index]
end

local function restore_body_property(record)
    local character = ctx.valid_entity(record.character)
    if character and record.destructible_before ~= nil then
        character.destructible = record.destructible_before
    end
    record.character = nil
    record.destructible_before = nil
end

local function sync_body(player, record)
    local character = record.god and ctx.valid_entity(record.god.character)
        or ctx.valid_entity(player.character)
    if record.character ~= character then
        restore_body_property(record)
        if character and (record.invulnerable or record.god) then
            record.character = character
            record.destructible_before = character.destructible
        end
    end
    if character and (record.invulnerable or record.god) then
        character.destructible = false
    elseif record.character then
        restore_body_property(record)
    end
end

local function physical_ready(player)
    if not player or not player.valid or not player.connected then
        return false, "The selected player must be connected."
    end
    if player.controller_type == defines.controllers.remote then
        local previous = transitioning[player.index]
        transitioning[player.index] = true
        local ok = pcall(player.exit_remote_view)
        transitioning[player.index] = previous
        if not ok then return false, "Remote view could not be exited." end
        if player.controller_type == defines.controllers.remote then
            return false, "Remote view cannot be exited while this player is in transit."
        end
    end
    local kind = player.physical_controller_type
    if kind ~= defines.controllers.character and kind ~= defines.controllers.god then
        return false, "Wait until the player has an active character or god controller."
    end
    return true
end

local function resolve_destination(args, create)
    if args.planet then return ctx.resolve_surface(args.planet, create) end
    if args.surface_index then return ctx.resolve_surface(args.surface_index, false) end
    return nil
end

-- A finite search never substitutes terrain clearing or the API's infinite radius.
local function safe_position(player, surface, requested, character_name)
    if not surface or not surface.valid then return nil end
    local anchor = requested or player.force.get_spawn_position(surface)
    surface.request_to_generate_chunks(anchor, 1)
    surface.force_generate_chunk_requests()
    local character = ctx.valid_entity(player.character)
    local name = character_name or (character and character.name) or "character"
    if not prototypes.entity[name] then name = "character" end
    return surface.find_non_colliding_position(name, anchor, 64, 0.5)
end

local function teleport(player, surface, requested)
    local ready, message = physical_ready(player)
    if not ready then return false, message end
    local target = safe_position(player, surface, requested)
    if not target then return false, "No safe landing position was found." end
    if player.physical_vehicle then player.driving = false end
    if player.physical_vehicle then return false, "The player could not leave the vehicle." end
    local success = player.teleport(target, surface)
    if not success then return false, "Factorio refused the teleport." end
    return true
end

local function escrow_slot(record)
    if not record.escrow or not record.escrow.valid then record.escrow = game.create_inventory(1) end
    for i = 1, #record.escrow do
        if not record.escrow[i].valid_for_read then return record.escrow[i] end
    end
    local size = #record.escrow
    if size >= 65535 then return nil end
    record.escrow.resize(size + 1)
    return record.escrow[size + 1]
end

local function escrow_stack(record, stack)
    if not stack or not stack.valid_for_read then return true end
    local slot = escrow_slot(record)
    return slot and slot.swap_stack(stack) or false
end

local function escrow_god_inventory(player, record)
    -- Move, never copy. Native stacks retain equipment, spoilage, tags and quality.
    if not escrow_stack(record, player.cursor_stack) then return false end
    player.cursor_ghost = nil
    if player.physical_controller_type ~= defines.controllers.god then return true end
    local inventory = player.get_inventory(defines.inventory.god_main)
    if inventory then
        for i = 1, #inventory do
            if not escrow_stack(record, inventory[i]) then return false end
        end
    end
    return true
end

local function recover_escrow(player, record, recovery_character)
    local inventory = record.escrow
    if not inventory or not inventory.valid then record.escrow = nil; return true end
    local character = ctx.valid_entity(recovery_character) or (player and ctx.valid_entity(player.character))
    if not character then return false end
    local main = character.get_inventory(defines.inventory.character_main)
    local remaining = false
    for i = 1, #inventory do
        local stack = inventory[i]
        if stack.valid_for_read then
            if main then
                for j = 1, #main do
                    main[j].transfer_stack(stack)
                    if not stack.valid_for_read then break end
                end
            end
            if stack.valid_for_read then
                local before = stack.count
                local spilled = character.surface.spill_item_stack{
                    position = character.position, stack = stack,
                    enable_looted = true, allow_belts = false, max_radius = 16,
                    use_start_position_on_failure = false, drop_full_stack = true,
                }
                local count = 0
                for _, entity in ipairs(spilled or {}) do
                    local item = ctx.valid_entity(entity)
                    if item and item.stack and item.stack.valid_for_read then count = count + item.stack.count end
                end
                if count >= before then stack.clear()
                elseif count > 0 then stack.count = before - count end
                if stack.valid_for_read then remaining = true end
            end
        end
    end
    if not remaining then inventory.destroy(); record.escrow = nil end
    return not remaining
end

local function enable_god(player, record)
    if record.god then return true end
    local ready, message = physical_ready(player)
    if not ready then return false, message end
    if player.physical_controller_type ~= defines.controllers.character then
        return false, "This god controller is not owned by the admin toolkit."
    end
    local character = ctx.valid_entity(player.character)
    if not character then return false, "No physical character is available." end
    if not player.clear_cursor() then return false, "Empty the player's cursor before changing controller." end
    if player.physical_vehicle then player.driving = false end
    if player.physical_vehicle then return false, "The player could not leave the vehicle." end
    local cheat = player.cheat_mode
    record.god = {character = character, surface_index = character.surface.index,
        position = {x = character.position.x, y = character.position.y},
        character_name = character.name, quality = character.quality.name}
    sync_body(player, record)
    transitioning[player.index] = true
    local ok, failure = pcall(function()
        player.character = nil
        player.associate_character(character)
        player.set_controller{type = defines.controllers.god}
        player.cheat_mode = cheat
    end)
    transitioning[player.index] = nil
    if not ok then
        if character.valid then player.set_controller{type = defines.controllers.character, character = character} end
        player.cheat_mode = cheat
        record.god = nil
        sync_body(player, record)
        return false, "God controller could not be enabled: " .. tostring(failure)
    end
    return true
end

local function disable_god(player, record)
    local saved = record.god
    if not saved then
        local recovered = recover_escrow(player, record)
        if recovered then record.god_return_pending = nil end
        return recovered
    end
    if not player.connected then record.god_return_pending = true; return false end
    if player.controller_type == defines.controllers.remote then
        local previous = transitioning[player.index]
        transitioning[player.index] = true
        local exited = pcall(player.exit_remote_view)
        transitioning[player.index] = previous
        if not exited then return false end
        if player.controller_type == defines.controllers.remote then return false end
    end
    -- If another mod attached a different body, do not abandon or destroy it.
    local current = ctx.valid_entity(player.character)
    if current and current ~= ctx.valid_entity(saved.character) then
        record.god = nil
        record.god_return_pending = nil
        restore_body_property(record)
        return recover_escrow(player, record)
    end
    if not escrow_god_inventory(player, record) then return false end
    local cheat = player.cheat_mode
    local body = ctx.valid_entity(saved.character)
    transitioning[player.index] = true
    local ok = pcall(function()
        if body then
            -- Native attachment requires the controller and character to share
            -- a surface. A god player can travel or reload in a different view.
            if player.physical_surface ~= body.surface then
                if not player.teleport(body.position, body.surface) then error("Could not return to the saved character's surface.") end
                body = ctx.valid_entity(saved.character)
                if not body then error("The saved character disappeared during controller return.") end
            end
            player.set_controller{type = defines.controllers.character, character = body}
        else
            -- Destroyed bodies are not cloned; corpse inventories remain authoritative.
            local surface = game.get_surface(saved.surface_index)
                or ctx.resolve_surface("nauvis", false) or game.surfaces[1]
            local landing = safe_position(player, surface, saved.position, saved.character_name)
            if not landing then error("No safe recovery position.") end
            player.set_controller{type = defines.controllers.god}
            if not player.teleport(landing, surface) then error("Recovery teleport failed.") end
            local name = prototypes.entity[saved.character_name] and saved.character_name or "character"
            local quality = prototypes.quality[saved.quality] and saved.quality or "normal"
            if not player.create_character{name = name, quality = quality} then
                error("Character recovery failed.")
            end
        end
        player.cheat_mode = cheat
    end)
    transitioning[player.index] = nil
    if not ok then record.god_return_pending = true; return false end
    record.god = nil
    record.god_return_pending = nil
    sync_body(player, record)
    return recover_escrow(player, record)
end

local function clear_modes(player, tick)
    local root = state()
    local record = root.modes[player.index]
    if not record then return true end
    record.invulnerable = false
    record.cleanup_pending = true
    if not disable_god(player, record) then
        if player.connected then schedule_retry(player.index, tick) end
        return false
    end
    restore_body_property(record)
    if record.cheat_before ~= nil and player.connected then
        player.cheat_mode = record.cheat_before
        record.cheat_before = nil
    elseif record.cheat_before ~= nil then
        return false
    end
    record.cleanup_pending = nil
    record.god_return_pending = nil
    if not record.escrow then root.modes[player.index] = nil end
    return true
end

local function set_mode(player, action, enabled, tick)
    local root = state()
    if root.jails[player.index] then return false, "Release this player from jail before changing modes." end
    if not player.connected then return false, "The selected player must be connected." end
    local record = mode_for(player.index)
    if record.cleanup_pending then return false, "Finish pending mode recovery before changing modes." end
    record.cleanup_pending = nil
    if action == "cheat" then
        if record.cheat_before == nil then record.cheat_before = player.cheat_mode end
        player.cheat_mode = enabled
    elseif action == "invulnerable" then
        if enabled and not (ctx.valid_entity(player.character) or (record.god and ctx.valid_entity(record.god.character))) then
            return false, "No physical character is available."
        end
        record.invulnerable = enabled
        sync_body(player, record)
    elseif action == "god" then
        local ok, message
        if enabled then record.god_return_pending = nil; ok, message = enable_god(player, record)
        else ok, message = disable_god(player, record) end
        if not ok then
            if not enabled then record.god_return_pending = true; schedule_retry(player.index, tick) end
            return false, message or "Controller recovery is pending."
        end
    end
    changed(player.index)
    return true, action .. " " .. (enabled and "enabled." or "disabled.")
end

local function jail_time_left(jail, tick)
    if jail.release_pending then return 0 end
    if jail.timer_mode == "elapsed" then return math.max(0, (jail.deadline or tick) - tick) end
    return math.max(0, (jail.remaining_ticks or 0) - (jail.online_since and (tick - jail.online_since) or 0))
end

local function close_jail_hud(player, jail)
    local frame = jail.hud or (player and player.gui.left[JAIL_HUD])
    if frame and frame.valid then frame.destroy() end
    jail.hud = nil
    jail.hud_second = nil
    jail.hud_width = nil
end

-- The prisoner owns no interactive controls. Keep the native element identity;
-- only the countdown caption changes when its displayed second changes.
local function refresh_jail_hud(player, jail, tick)
    if not player.connected or jail.release_pending then close_jail_hud(player, jail); return end
    local frame = jail.hud
    if not (frame and frame.valid) then
        frame = player.gui.left[JAIL_HUD]
        if frame then frame.destroy() end
        frame = player.gui.left.add{type="frame", name=JAIL_HUD, direction="vertical", caption={"ei-admin.jail-status-title"}}
        local reason = frame.add{type="label", name="reason", caption={"ei-admin.jail-status-reason", jail.reason or "Administrative action"}}
        reason.style.single_line = false
        reason.style.maximal_height = 96
        reason.tooltip = jail.reason or "Administrative action"
        local clock = frame.add{type="label", name="clock", caption={"ei-admin.jail-status-" .. jail.timer_mode}}
        clock.style.single_line = false
        frame.add{type="label", name="remaining", caption=""}
        jail.hud = frame
        jail.hud_second = nil
        jail.hud_width = nil
    end
    local width = math.max(120, math.min(360, math.floor(player.display_resolution.width / player.display_scale - 32)))
    if jail.hud_width ~= width then
        frame.style.maximal_width = width
        frame.reason.style.maximal_width = math.max(80, width - 24)
        frame.clock.style.maximal_width = math.max(80, width - 24)
        jail.hud_width = width
    end
    local seconds = math.ceil(jail_time_left(jail, tick) / 60)
    if jail.hud_second ~= seconds then
        frame.remaining.caption = {"ei-admin.jail-status-remaining", string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)}
        jail.hud_second = seconds
    end
end

local function protect_jail_body(player, jail)
    local character = ctx.valid_entity(player.character)
    if jail.character ~= character then
        restore_body_property(jail)
        if character then jail.character = character; jail.destructible_before = character.destructible end
    end
    if character and character.destructible then character.destructible = false end
end

local function queue_jail_hud(player, jail, tick)
    local remaining = jail_time_left(jail, tick)
    schedule(player.index, tick + math.max(1, remaining % 60 == 0 and 60 or remaining % 60))
end

local function ensure_jail()
    local root = state()
    local surface = root.players.jail_surface_index and game.get_surface(root.players.jail_surface_index)
    if not surface then surface = game.get_surface(JAIL_SURFACE) end
    if not surface then
        surface = game.create_surface(JAIL_SURFACE, {
            width = 64, height = 64,
            autoplace_settings = {
                entity = {treat_missing_as_default = false},
                tile = {treat_missing_as_default = false},
                decorative = {treat_missing_as_default = false},
            },
        })
        surface.request_to_generate_chunks({0, 0}, 1)
        surface.force_generate_chunk_requests()
        local tiles = {}
        for x = -24, 23 do for y = -24, 23 do
            tiles[#tiles + 1] = {name = "refined-concrete", position = {x, y}}
        end end
        surface.set_tiles(tiles, true, false, true, false)
        surface.peaceful_mode = true
        surface.always_day = true
    end
    root.players.jail_surface_index = surface.index
    local group = root.players.jail_group_id and game.permissions.get_group(root.players.jail_group_id)
        or game.permissions.get_group(JAIL_GROUP)
    local created = not group
    if created then
        group = game.permissions.create_group(JAIL_GROUP)
        if not group then return nil, nil end
    end
    if created or root.players.jail_group_dirty or root.players.jail_permissions_version ~= 1 then
        editing_jail_group = true
        for _, action in pairs(defines.input_action) do group.set_allows_action(action, false) end
        -- Native movement and chat stay usable inside the finite isolated surface.
        group.set_allows_action(defines.input_action.start_walking, true)
        group.set_allows_action(defines.input_action.write_to_console, true)
        editing_jail_group = false
        root.players.jail_group_dirty = nil
        root.players.jail_permissions_version = 1
    end
    root.players.jail_group_id = group.group_id
    return surface, group
end

local function resume_suspended(player, jail, tick, enabled)
    local saved = jail.suspended or {}
    if enabled then player.cheat_mode = saved.cheat == true
    else player.cheat_mode = saved.cleanup_cheat == true end
    if not enabled then return end
    if saved.cheat_before ~= nil then mode_for(player.index).cheat_before = saved.cheat_before end
    if saved.invulnerable then set_mode(player, "invulnerable", true, tick) end
    if saved.god then set_mode(player, "god", true, tick) end
end

local function release_player(player, tick)
    local root = state()
    local jail = root.jails[player.index]
    if not jail then return true, "The player is not jailed." end
    if not jail.release_pending then reset_retries(player.index) end
    jail.release_pending = true
    close_jail_hud(player, jail)
    restore_body_property(jail)
    if not player.connected then return true, "Release will finish when the player reconnects." end
    local ready = physical_ready(player)
    if not ready then schedule_retry(player.index, tick); return false, "Release is waiting for the player's character." end
    local destination = game.get_surface(jail.return_surface_index)
    local return_position = jail.return_position
    if not destination or destination.index == root.players.jail_surface_index then
        local spawn = root.players.spawn_by_force[player.force.index]
        destination = (spawn and ctx.resolve_surface(spawn.planet, false))
            or ctx.resolve_surface("nauvis", false) or game.surfaces[1]
        return_position = destination and player.force.get_spawn_position(destination)
    end
    transitioning[player.index] = true
    local ok, message = teleport(player, destination, return_position)
    transitioning[player.index] = nil
    if not ok then schedule_retry(player.index, tick); return false, message end
    local group = jail.permission_group_id and game.permissions.get_group(jail.permission_group_id) or nil
    local owned_group = root.players.jail_group_id and game.permissions.get_group(root.players.jail_group_id)
    local current_group = player.permission_group
    -- Native deletion assigns the Default group (id 0), not nil. Only the
    -- recorded deletion fallback is ours to restore; other groups survive.
    if current_group == owned_group or current_group == nil
        or (jail.group_deleted and current_group.group_id == 0) then player.permission_group = group end
    root.jails[player.index] = nil
    unschedule(player.index)
    reset_retries(player.index)
    resume_suspended(player, jail, tick, ctx.enabled())
    changed(player.index)
    notify(player.index, "Your jail sentence has ended.")
    return true, "Player released."
end

local function enforce_jail(player, tick)
    local root = state()
    local jail = root.jails[player.index]
    if not jail then return end
    if jail.release_pending or jail_time_left(jail, tick) <= 0 or not ctx.enabled() then
        release_player(player, tick)
        return
    end
    if not player.connected then
        close_jail_hud(player, jail)
        if jail.timer_mode == "elapsed" then schedule(player.index, math.max(tick + 1, jail.deadline or tick + 1)) end
        return
    end
    if jail.timer_mode == "online" and not jail.online_since then jail.online_since = tick end
    refresh_jail_hud(player, jail, tick)
    -- The required visible countdown also bounds recovery after external group,
    -- body or surface changes without any all-player polling loop.
    queue_jail_hud(player, jail, tick)
    local ready = physical_ready(player)
    if not ready then return end
    local surface, group = ensure_jail()
    if not surface or not group then schedule_retry(player.index, tick); return end
    jail.surface_index = surface.index
    if player.permission_group ~= group then player.permission_group = group end
    jail.group_deleted = nil
    if player.cheat_mode then player.cheat_mode = false end
    protect_jail_body(player, jail)
    if player.physical_surface.index ~= surface.index then
        if player.opened then player.opened = nil end
        transitioning[player.index] = true
        local ok = teleport(player, surface, {x = 0, y = 0})
        transitioning[player.index] = nil
        if not ok then schedule_retry(player.index, tick) end
    end
end

local function jail_player(player, args, tick)
    local root = state()
    if root.jails[player.index] then return false, "The player is already jailed." end
    if player.admin then return false, "Demote an administrator before jailing them." end
    local minutes = tonumber(args.minutes) or 5
    if not lib.is_valid_number(minutes) or minutes < 1 or minutes > 1440 then
        return false, "Jail duration must be between 1 and 1440 minutes."
    end
    local timer = args.timer_mode or "online"
    if timer ~= "online" and timer ~= "elapsed" then return false, "Unknown jail timer mode." end
    local ready, message = physical_ready(player)
    if not ready then return false, message end
    local record = root.modes[player.index]
    local suspended = {
        cheat = player.cheat_mode,
        cleanup_cheat = record and record.cheat_before,
        cheat_before = record and record.cheat_before,
        invulnerable = record and record.invulnerable == true,
        god = record and record.god ~= nil,
    }
    if suspended.cleanup_cheat == nil then suspended.cleanup_cheat = player.cheat_mode end
    local surface, group = ensure_jail()
    if not surface or not group then return false, "Could not create the native jail permission group." end
    if not clear_modes(player, tick) then return false, "Controller recovery must finish before jailing." end
    local permission = player.permission_group
    local old_surface = player.physical_surface
    local old_position = player.physical_position
    local jail = {
        surface_index = surface.index, return_surface_index = old_surface.index,
        return_position = {x = old_position.x, y = old_position.y},
        permission_group_id = permission and permission.group_id or nil,
        remaining_ticks = math.ceil(minutes * 3600), timer_mode = timer,
        suspended = suspended, reason = tostring(args.reason and args.reason ~= "" and args.reason or "Administrative action"),
    }
    if timer == "elapsed" then jail.deadline = tick + jail.remaining_ticks
    else jail.online_since = tick end
    root.jails[player.index] = jail
    transitioning[player.index] = true
    local ok, failure = teleport(player, surface, {x = 0, y = 0})
    transitioning[player.index] = nil
    if not ok then
        root.jails[player.index] = nil
        resume_suspended(player, jail, tick, true)
        return false, failure
    end
    enforce_jail(player, tick)
    if player.opened then player.opened = nil end
    changed(player.index)
    notify(player.index, "You have been jailed for " .. tostring(minutes) .. " minutes: " .. tostring(args.reason or "Administrative action"))
    return true, "Player jailed."
end

local function apply_pending_spawn(player, tick)
    local root = state()
    local pending = root.pending_spawns[player.index]
    if not pending or root.jails[player.index] then return end
    local config = root.players.spawn_by_force[player.force.index]
    if not ctx.enabled() or not config then root.pending_spawns[player.index] = nil; return end
    if not player.connected or not ctx.valid_entity(player.character)
        or player.physical_controller_type ~= defines.controllers.character then
        if player.connected then schedule_retry(player.index, tick) end
        return
    end
    local surface = ctx.resolve_surface(config.planet, true)
    if not surface then schedule_retry(player.index, tick); return end
    transitioning[player.index] = true
    local ok = teleport(player, surface, config.position)
    transitioning[player.index] = nil
    if ok then root.pending_spawns[player.index] = nil; changed(player.index)
    else schedule_retry(player.index, tick) end
end

local function admin_count()
    local count = 0
    for _, player in pairs(game.players) do if player.admin then count = count + 1 end end
    return count
end

---@param actor LuaPlayer|nil nil denotes the server console, authorized by the root.
---@param action string
---@param args table
---@param tick integer
---@return boolean, LocalisedString
function model.execute(actor, action, args, tick)
    if not ctx or not ctx.enabled() then return false, "The admin toolkit is disabled." end
    if actor and (not actor.valid or not actor.admin) then return false, "Administrator access is required." end
    args = args or {}
    tick = lib.get_event_tick(tick)
    local root = state()
    if action == "set_spawn" then
        local force = game.forces[tonumber(args.force_index) or (actor and actor.force.index) or 0]
        if not force or not force.valid then return false, "Unknown force." end
        local desired = position(args.position)
        if desired == false then return false, "Invalid spawn position." end
        local planet = args.planet
        if type(planet) ~= "string" or not game.planets[planet] then return false, "Select a valid planet." end
        local surface = ctx.resolve_surface(planet, true)
        if not surface then return false, "The spawn planet could not be created." end
        local target = desired or force.get_spawn_position(surface)
        surface.request_to_generate_chunks(target, 1)
        surface.force_generate_chunk_requests()
        local safe = surface.find_non_colliding_position("character", target, 64, 0.5)
        if not safe then return false, "No safe spawn position was found." end
        force.set_spawn_position(safe, surface)
        root.players.spawn_by_force[force.index] = {planet = planet, position = {x = safe.x, y = safe.y}}
        changed(force.index)
        return true, "Spawn planet changed for " .. force.name .. "."
    end
    if action == "unban" then
        if not game.is_multiplayer() then return false, "Bans are multiplayer-only." end
        local name = args.player_name
        if type(name) ~= "string" or name == "" then return false, "Enter a player name." end
        game.unban_player(name)
        changed(name)
        return true, "Unban requested for " .. name .. "."
    end
    -- A typed ban name is an explicit target; the GUI also carries its current
    -- dropdown index, which must not silently replace that name.
    local named_ban = action == "ban" and type(args.player_name) == "string" and args.player_name ~= ""
    local target_id = not named_ban and tonumber(args.player_index) or nil
    if target_id and (not lib.is_valid_number(target_id) or target_id < 1 or target_id % 1 ~= 0) then
        return false, "Invalid player index."
    end
    if named_ban then target_id = args.player_name
    elseif not target_id and type(args.player_name) == "string" and args.player_name ~= "" then target_id = args.player_name end
    if not target_id then target_id = actor and actor.index end
    local target = target_id and game.get_player(target_id) or nil
    if named_ban and not target then
        -- Name lookup casing is not part of the documented native contract. A
        -- spelling variant of a known administrator must still reach the guards.
        local folded=string.lower(args.player_name)
        for _,known in pairs(game.players) do
            if string.lower(known.name)==folded then
                if target then return false,"The player name is ambiguous; select the exact player." end
                target=known
            end
        end
    end
    if action == "ban" and not target and type(args.player_name) == "string" and args.player_name ~= "" then
        if not game.is_multiplayer() then return false, "Bans are multiplayer-only." end
        game.ban_player(args.player_name, tostring(args.reason or "Administrative action"))
        changed(args.player_name)
        return true, "Ban requested for " .. args.player_name .. "."
    end
    if not target or not target.valid then return false, "The selected player no longer exists." end
    reset_retries(target.index)
    if action == "travel" then
        if root.jails[target.index] then return false, "Release this player before teleporting them." end
        local desired = position(args.position)
        if desired == false then return false, "Invalid destination position." end
        local destination = resolve_destination(args, true)
        if not destination then return false, "The destination surface is unavailable." end
        local ok, message = teleport(target, destination, desired)
        if ok then changed(target.index) end
        return ok, message or "Player teleported."
    end
    if action == "cheat" or action == "invulnerable" or action == "god" then
        if type(args.enabled) ~= "boolean" then return false, "Choose enabled or disabled." end
        return set_mode(target, action, args.enabled, tick)
    end
    local self_action = actor and actor.index == target.index
    if self_action and (action == "promote" or action == "release") then
        return false, "Self-moderation is not available."
    end
    if action == "kick" or action == "ban" or action == "demote" or action == "jail" then
        if self_action then return false, "Self-moderation is not available." end
        if target.admin and action ~= "demote" then return false, "Demote this administrator first." end
    end
    if action == "jail" then return jail_player(target, args, tick) end
    if action == "release" then return release_player(target, tick) end
    if action == "promote" then
        if root.jails[target.index] then return false, "Release this player before promoting them." end
        target.admin = true
    elseif action == "demote" then
        if target.admin and admin_count() <= 1 then return false, "The last administrator cannot be demoted." end
        clear_modes(target, tick)
        target.admin = false
    elseif action == "kick" or action == "ban" then
        if not game.is_multiplayer() then return false, "Kick and ban are multiplayer-only." end
        if action == "kick" and not target.connected then return false,"The player must be online to be kicked." end
        clear_modes(target, tick)
        if action == "kick" then game.kick_player(target, tostring(args.reason or "Administrative action"))
        else game.ban_player(target, tostring(args.reason or "Administrative action")) end
    else return false, "Unknown player action." end
    changed(target.index)
    return true, action .. " applied to " .. target.name .. "."
end

local function reconcile(player, tick, event_name)
    if transitioning[player.index] then return end
    local root = state()
    if root.jails[player.index] then enforce_jail(player, tick); return end
    local record = root.modes[player.index]
    if record then
        if not ctx.enabled() or record.cleanup_pending or event_name == defines.events.on_player_demoted then
            clear_modes(player, tick)
        elseif player.connected then
            if record.god_return_pending or (record.god and player.physical_controller_type ~= defines.controllers.god) then
                if not disable_god(player, record) then schedule_retry(player.index, tick) end
            end
            sync_body(player, record)
            if record.escrow then recover_escrow(player, record) end
        end
    end
    if ctx.enabled() then apply_pending_spawn(player, tick) end
end

---@param event EventData
function model.on_player_event(event)
    if not ctx or not event or not event.player_index then return end
    if not ctx.enabled() and not peek() then return end
    local player = game.get_player(event.player_index)
    if not player then return end
    local root = state()
    reset_retries(player.index)
    if root.jails[player.index] and event.name == defines.events.on_player_changed_surface then
        -- Surface deletion may raise a player move before its deletion callback.
        -- Reconfine on the next owner slice, after native surface teardown ends.
        protect_jail_body(player, root.jails[player.index])
        schedule(player.index, lib.get_event_tick(event) + 1)
        return
    end
    if ctx.enabled() and (event.name == defines.events.on_player_created or event.name == defines.events.on_player_respawned) then
        if root.players.spawn_by_force[player.force.index] then root.pending_spawns[player.index] = {attempts = 0} end
    end
    reconcile(player, lib.get_event_tick(event), event.name)
end

function model.on_player_changed_surface(event) model.on_player_event(event) end
function model.on_player_controller_changed(event) model.on_player_event(event) end

-- Native permission callbacks can run inside a group mutation. Queue recovery
-- through the existing owner, never recreate a group inside its deletion event.
function model.on_permission_group_edited(event)
    if editing_jail_group then return end
    local root = peek()
    if not (root and root.players and next(root.jails or {})) then return end
    local group = event.group
    local owned = group and group.valid and group.group_id == root.players.jail_group_id
    if owned and event.type ~= "add-player" and event.type ~= "remove-player" then
        root.players.jail_group_dirty = true
    end
    if owned then
        for index in pairs(root.jails) do schedule(index, event.tick + 1) end
    elseif event.other_player_index and root.jails[event.other_player_index] then
        schedule(event.other_player_index, event.tick + 1)
    end
end

function model.on_permission_group_deleted(event)
    local root = peek()
    if not (root and root.players and root.players.jail_group_id == event.id) then return end
    root.players.jail_group_id = nil
    root.players.jail_group_dirty = true
    for index, jail in pairs(root.jails or {}) do
        jail.group_deleted = true
        schedule(index, event.tick + 1)
    end
end

function model.on_surface_deleted(event)
    local root = peek()
    if not (root and root.players and root.players.jail_surface_index == event.surface_index) then return end
    root.players.jail_surface_index = nil
    for index in pairs(root.jails or {}) do schedule(index, event.tick + 1) end
end

function model.on_display_changed(event)
    local root = peek()
    local jail = root and root.jails and root.jails[event.player_index]
    local player = jail and game.get_player(event.player_index)
    if player then refresh_jail_hud(player, jail, event.tick) end
end

---@param event EventData.on_pre_player_left_game|EventData.on_player_left_game
function model.on_player_left_game(event)
    if not event then return end
    if not ctx.enabled() and not peek() then return end
    local root = state()
    local jail = root.jails[event.player_index]
    local tick = lib.get_event_tick(event)
    if jail then
        close_jail_hud(game.get_player(event.player_index), jail)
        unschedule(event.player_index)
        if jail.timer_mode == "online" then
            jail.remaining_ticks = jail_time_left(jail, tick)
            jail.online_since = nil
        elseif not jail.release_pending then schedule(event.player_index, math.max(tick + 1, jail.deadline or tick + 1)) end
    end
    -- Associated parked characters are logged off by Factorio; retain owned mode state.
end

---@param event EventData.on_pre_player_removed|EventData.on_player_removed
function model.on_player_removed(event)
    if not event then return end
    if not ctx.enabled() and not peek() then return end
    local root = state()
    local player = game.get_player(event.player_index)
    if player then
        local record = root.modes[player.index]
        if record and record.god and event.name == defines.events.on_pre_player_removed then
            -- God inventory remains distinct from the parked body. Capture its
            -- exact stacks before Factorio removes the native player controller.
            pcall(escrow_god_inventory, player, record)
        end
        if root.jails[player.index] then release_player(player, lib.get_event_tick(event)) end
        clear_modes(player, lib.get_event_tick(event))
    end
    local record = root.modes[event.player_index]
    if record then
        local body = record.god and ctx.valid_entity(record.god.character) or ctx.valid_entity(record.character)
        if body then recover_escrow(player, record, body) end
        restore_body_property(record)
        -- Unrecoverable stacks remain in escrow under the removed index for explicit recovery;
        -- never destroy an inventory just because a player record was removed.
        if record.escrow and record.escrow.valid and not record.escrow.is_empty() then
            record.cleanup_pending = true
            record.removed = true
        else
            if record.escrow and record.escrow.valid then record.escrow.destroy() end
            root.modes[event.player_index] = nil
        end
    end
    local jail = root.jails[event.player_index]
    if jail then restore_body_property(jail); close_jail_hud(player, jail) end
    root.jails[event.player_index] = nil
    root.pending_spawns[event.player_index] = nil
    unschedule(event.player_index)
    root.players.retry_attempts[event.player_index] = nil
end

function model.on_force_removed(event)
    if not ctx.enabled() and not peek() then return end
    local root = state()
    local index = event and (event.force_index or event.source_index)
    if index then root.players.spawn_by_force[index] = nil end
end

function model.on_forces_merged(event)
    if not ctx.enabled() and not peek() then return end
    local root = state()
    local source = event and event.source_index
    local destination = event and event.destination
    if source and destination and destination.valid then
        if not root.players.spawn_by_force[destination.index] then
            root.players.spawn_by_force[destination.index] = root.players.spawn_by_force[source]
        end
        root.players.spawn_by_force[source] = nil
    end
end

---@param tick integer
---@param enabled boolean
function model.on_configuration_changed(tick, enabled)
    local root = state()
    root.players.due_buckets = {}
    root.players.due_by_player = {}
    root.players.retry_attempts = {}
    root.players.next_due_tick = nil
    root.players.jail_group_dirty = true
    for index, jail in pairs(root.jails) do
        local player = game.get_player(index)
        if player then
            if not enabled then
                jail.release_pending = true
                restore_body_property(jail)
                close_jail_hud(player, jail)
            end
            if player.connected then enforce_jail(player, tick)
            elseif jail.timer_mode == "elapsed" and not jail.release_pending then
                schedule(index, math.max(tick + 1, jail.deadline or tick + 1))
            end
        else restore_body_property(jail); close_jail_hud(nil, jail); root.jails[index] = nil end
    end
    for index, record in pairs(root.modes) do
        local player = game.get_player(index)
        if player then
            if not enabled then record.cleanup_pending = true end
            reconcile(player, tick)
        end
    end
    if not enabled then root.pending_spawns = {}
    else
        -- Pending spawn readiness can be the only work a player owns. Rebuilding
        -- the due buckets must retain this job even without a mode/jail record.
        for index in pairs(root.pending_spawns) do
            local player = game.get_player(index)
            if player and player.connected then schedule(index, tick + 1)
            elseif not player then root.pending_spawns[index] = nil end
        end
    end
end

---@param tick integer
---@return boolean
function model.has_tick_work(tick)
    local root = peek()
    local next_tick = root and root.players and root.players.next_due_tick
    return next_tick ~= nil and tick >= next_tick
end

---@param tick integer
function model.updater(tick)
    if not model.has_tick_work(tick) then return end
    local root = state()
    local jobs = ctx.scheduler.delayed_take_due_through(root.players.due_buckets, tick)
    root.players.next_due_tick = ctx.scheduler.delayed_next_due_tick(root.players.due_buckets) or nil
    local serviced = 0
    for _, job in ipairs(jobs) do
        if root.players.due_by_player[job.index] == job.tick then
            root.players.due_by_player[job.index] = nil
            if serviced >= JOB_BUDGET then
                schedule(job.index, tick + 1)
            else
                serviced = serviced + 1
                local player = game.get_player(job.index)
                if player then
                    local jail = root.jails[job.index]
                    local group = jail and root.players.jail_group_id and game.permissions.get_group(root.players.jail_group_id)
                    local body = jail and ctx.valid_entity(jail.character)
                    if jail and ctx.enabled() and player.connected and not jail.release_pending
                        and jail_time_left(jail, tick) > 0 and not root.players.jail_group_dirty
                        and group and group == player.permission_group and body and body == player.character
                        and not body.destructible and not player.cheat_mode
                        and player.controller_type == defines.controllers.character
                        and player.physical_surface.index == jail.surface_index then
                        -- Stable prisoners need only the displayed countdown: no
                        -- permission writes, controller changes or opened-GUI reset.
                        refresh_jail_hud(player, jail, tick)
                        queue_jail_hud(player, jail, tick)
                    else reconcile(player, tick) end
                end
            end
        end
    end
end

---@param tick integer
---@return table
function model.peek_summary(tick)
    local root = peek()
    local result = {modes = {}, jails = {}, spawn_by_force = {}, pending_spawns = 0, next_due_tick = nil}
    if not root then return result end
    for index, record in pairs(root.modes or {}) do
        result.modes[index] = {invulnerable = record.invulnerable == true, god = record.god ~= nil,
            cleanup_pending = record.cleanup_pending == true,
            god_return_pending = record.god_return_pending == true, removed = record.removed == true,
            escrow_slots = record.escrow and record.escrow.valid and #record.escrow or 0}
    end
    for index, jail in pairs(root.jails or {}) do
        result.jails[index] = {remaining_ticks = jail_time_left(jail, tick), timer_mode = jail.timer_mode,
            release_pending = jail.release_pending == true, reason = jail.reason}
    end
    for index, config in pairs(root.players and root.players.spawn_by_force or {}) do
        result.spawn_by_force[index] = {planet = config.planet,
            position = config.position and {x = config.position.x, y = config.position.y} or nil}
    end
    for _ in pairs(root.pending_spawns or {}) do result.pending_spawns = result.pending_spawns + 1 end
    result.next_due_tick = root.players and root.players.next_due_tick
    return result
end

-- Legacy travel commands remain usable with the optional console disabled.
-- They share native landing/controller checks without bypassing an active jail.
function model.travel_legacy(actor,planet,tick)
    if not (actor and actor.valid and actor.admin) then return false,"Administrator access is required." end
    local root=peek()
    if root and root.jails and root.jails[actor.index] then return false,"Release this player before teleporting them." end
    local surface=ctx.resolve_surface(planet,true)
    if not surface then return false,"The destination surface is unavailable." end
    return teleport(actor,surface,nil)
end

return model

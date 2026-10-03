-- Connected-player native API fixture. Never load this mod in a valuable save.
local players = require("players")
local lib = require("lib/lib")
local scheduler = require("lib/runtime-scheduler")
local config = require("fixture-config")
local loaded = false
local function root()
    storage.ei = storage.ei or {}
    storage.ei.admin_tools = storage.ei.admin_tools or {}
    return storage.ei.admin_tools
end
local function fixture()
    storage.admin_player_fixture = storage.admin_player_fixture or {checks = {}, enabled = true, stage = "start"}
    return storage.admin_player_fixture
end
local function record(label, details)
    local q = fixture()
    q.checks[#q.checks + 1] = {label = label, tick = game.tick, details = details}
    log("ADMIN_PLAYER_QC PASS " .. label .. " " .. helpers.table_to_json(details or {}))
end
local function expect(value, label, details)
    assert(value, "ADMIN_PLAYER_QC FAILED " .. label .. " " .. helpers.table_to_json(details or {}))
    record(label, details)
end
local function resolve_surface(name, create)
    if type(name) == "number" then return game.get_surface(name) end
    local surface = game.get_surface(name)
    if surface then return surface end
    local planet = game.planets[name]
    return planet and (planet.surface or (create and planet.create_surface())) or nil
end
players.configure{
    enabled = function() return fixture().enabled end,
    state = root, valid_entity = lib.get_valid_entity, scheduler = scheduler,
    notify = function(index, message) log("ADMIN_PLAYER_QC NOTICE " .. tostring(index) .. " " .. tostring(message)) end,
    changed = function() end, resolve_surface = resolve_surface,
}
local function execute(action, args)
    local ok, message = players.execute(nil, action, args, game.tick)
    assert(ok, "ADMIN_PLAYER_QC action " .. action .. ": " .. tostring(message))
    return message
end
local function event(player, name, tick)
    return {player_index = player.index, name = defines.events[name], tick = tick or game.tick}
end
script.on_init(function() fixture(); root() end)
script.on_load(function() loaded = storage.admin_player_fixture and storage.admin_player_fixture.saved == true end)
script.on_configuration_changed(function() players.on_configuration_changed(game.tick, fixture().enabled) end)
for _, name in ipairs({"on_player_created", "on_player_joined_game", "on_player_respawned", "on_player_demoted", "on_player_changed_force", "on_player_changed_surface", "on_player_controller_changed", "on_cutscene_cancelled", "on_cutscene_finished"}) do
    if defines.events[name] then script.on_event(defines.events[name], players.on_player_event) end
end
script.on_event({defines.events.on_pre_player_left_game, defines.events.on_player_left_game}, players.on_player_left_game)
script.on_event({defines.events.on_pre_player_removed, defines.events.on_player_removed}, players.on_player_removed)
script.on_event(defines.events.on_forces_merged, players.on_forces_merged)
script.on_event(defines.events.on_permission_group_edited, players.on_permission_group_edited)
script.on_event(defines.events.on_permission_group_deleted, players.on_permission_group_deleted)
script.on_event(defines.events.on_surface_deleted, players.on_surface_deleted)
script.on_event({defines.events.on_player_display_resolution_changed, defines.events.on_player_display_scale_changed}, players.on_display_changed)

local function surface(name)
    local result = game.get_surface(name) or game.create_surface(name, {width = 96, height = 96,
        autoplace_settings = {entity = {treat_missing_as_default = false}, decorative = {treat_missing_as_default = false}}})
    result.request_to_generate_chunks({0, 0}, 2)
    result.force_generate_chunk_requests()
    for _, entity in pairs(result.find_entities_filtered{area = {{-32, -32}, {32, 32}}}) do
        if entity.type ~= "character" then entity.destroy() end
    end
    local tiles = {}
    for x = -32, 31 do for y = -32, 31 do tiles[#tiles + 1] = {name = "refined-concrete", position = {x, y}} end end
    result.set_tiles(tiles)
    result.peaceful_mode = true
    return result
end
local function ready_player(player)
    if config.capture_hud and player.controller_type == defines.controllers.editor then player.toggle_map_editor() end
    if player.controller_type == defines.controllers.remote then player.exit_remote_view() end
    if not player.character then
        player.set_controller{type = defines.controllers.god}
        assert(player.create_character())
    end
    player.admin = true
    player.cheat_mode = false
    player.character.destructible = true
    player.clear_cursor()
    player.get_main_inventory().clear()
    player.get_inventory(defines.inventory.character_armor).clear()
    player.permission_group = nil
    return player
end
local function find_stack(player, name, quality)
    local inv = player.get_main_inventory()
    for i = 1, #inv do
        local stack = inv[i]
        if stack.valid_for_read and stack.name == name and (not quality or stack.quality.name == quality) then return stack end
    end
    for _, entity in pairs(player.physical_surface.find_entities_filtered{type = "item-entity", position = player.physical_position, radius = 20}) do
        local stack = entity.stack
        if stack.valid_for_read and stack.name == name and (not quality or stack.quality.name == quality) then return stack end
    end
    return nil
end
local function setup_inventory(player)
    local body = player.character
    player.get_main_inventory().insert{name = "copper-plate", count = 19, quality = "rare"}
    local armor = player.get_inventory(defines.inventory.character_armor)[1]
    armor.set_stack{name = "power-armor-mk2", quality = "epic"}
    local battery = armor.grid.put{name = "battery-equipment", position = {0, 0}}
    battery.energy = 12345
    return body
end
local function god_inventory(player)
    local inv = player.get_inventory(defines.inventory.god_main)
    assert(inv and #inv >= 6)
    inv[1].set_stack{name = "iron-plate", count = 37, quality = "epic"}
    inv[2].set_stack{name = "admin-player-qc-tag", quality = "rare"}
    inv[2].tags = {identity = "god-tag", nested = {value = 419}}
    inv[3].set_stack{name = "power-armor-mk2", quality = "rare"}
    local equipment = inv[3].grid.put{name = "battery-equipment", position = {0, 0}}
    equipment.energy = 23456
    inv[4].set_stack{name = "blueprint"}
    inv[4].set_blueprint_entities{{entity_number = 1, name = "transport-belt", position = {0, 0}}}
    inv[4].label = "God escrow blueprint"
    inv[5].set_stack{name = "admin-player-qc-inventory"}
    inv[5].get_inventory(defines.inventory.item_main).insert{name = "steel-plate", count = 13, quality = "rare"}
    inv[6].set_stack{name = "bioflux", count = 11, quality = "uncommon"}
    inv[6].spoil_percent = 0.35
    local spoil_tick = inv[6].spoil_tick
    player.cursor_stack.set_stack{name = "admin-player-qc-tag"}
    player.cursor_stack.tags = {identity = "cursor-tag"}
    return spoil_tick
end
local function verify_inventory(player, old_body, spoil_tick)
    expect(player.character == old_body, "original-character-identity")
    local plate = find_stack(player, "iron-plate", "epic")
    expect(plate and plate.count == 37, "god-quality-stack-return")
    local tags = find_stack(player, "admin-player-qc-tag", "rare")
    expect(tags and tags.tags.identity == "god-tag" and tags.tags.nested.value == 419, "nested-tags-return")
    local cursor = find_stack(player, "admin-player-qc-tag", "normal")
    expect(cursor and cursor.tags.identity == "cursor-tag", "cursor-stack-return")
    local armor = find_stack(player, "power-armor-mk2", "rare")
    expect(armor and armor.grid.get{0, 0}.energy == 23456, "equipment-energy-return")
    local blueprint = find_stack(player, "blueprint")
    expect(blueprint and blueprint.label == "God escrow blueprint" and #blueprint.get_blueprint_entities() == 1, "blueprint-identity-return")
    local nested = find_stack(player, "admin-player-qc-inventory")
    expect(nested and nested.get_inventory(defines.inventory.item_main).get_item_count{name = "steel-plate", quality = "rare"} == 13, "nested-inventory-return")
    local spoil = find_stack(player, "bioflux", "uncommon")
    expect(spoil and spoil.spoil_tick == spoil_tick and spoil.count == 11, "spoil-deadline-return")
    expect(player.get_inventory(defines.inventory.character_armor)[1].grid.get{0, 0}.energy == 12345, "original-equipped-armor-preserved")
    expect(player.get_main_inventory().get_item_count{name = "copper-plate", quality = "rare"} == 19, "original-body-inventory-preserved")
end
local function complete()
    local q = fixture()
    q.complete = true
    helpers.write_file("admin-player-qc.json", helpers.table_to_json({complete = true, suite = config.suite, checks = q.checks}), false)
    log("ADMIN_PLAYER_QC ALL_COMPLETE " .. tostring(#q.checks))
end
local function removed_god_stack(q, name, quality)
    local record = root().modes[q.player_index]
    local inventories = {}
    if record and record.escrow and record.escrow.valid then inventories[#inventories + 1] = record.escrow end
    if q.god_body and q.god_body.valid then
        inventories[#inventories + 1] = q.god_body.get_inventory(defines.inventory.character_main)
    end
    for _, inventory in ipairs(inventories) do
        for i = 1, #inventory do
            local stack = inventory[i]
            if stack.valid_for_read and stack.name == name and stack.quality.name == quality then return stack end
        end
    end
    local old_surface = game.get_surface(q.god_surface)
    for _, entity in pairs(old_surface.find_entities_filtered{type = "item-entity", position = q.god_position, radius = 20}) do
        if entity.stack.valid_for_read and entity.stack.name == name and entity.stack.quality.name == quality then return entity.stack end
    end
end
local function basic(player)
    local q = fixture()
    local a, b = surface("admin-player-qc-a"), surface("admin-player-qc-b")
    player.teleport({0, 0}, a)
    player.admin = false
    local denied = players.execute(player, "invulnerable", {player_index = player.index, enabled = true}, game.tick)
    expect(not denied, "non-admin-actor-rejected")
    player.admin = true
    player.set_controller{type = defines.controllers.remote, surface = b, position = {10, 10}}
    expect(player.physical_surface == a and player.surface == b, "remote-view-physical-separation")
    execute("travel", {player_index = player.index, surface_index = b.index, position = {0, 0}})
    expect(player.physical_surface == b and player.physical_controller_type == defines.controllers.character, "remote-travel-exits-view")
    local old_body = setup_inventory(player)
    execute("invulnerable", {player_index = player.index, enabled = true})
    execute("god", {player_index = player.index, enabled = true})
    expect(player.physical_controller_type == defines.controllers.god and old_body.valid and not old_body.destructible, "native-god-parks-protected-body")
    local spoil_tick = god_inventory(player)
    execute("travel", {player_index=player.index, surface_index=a.index, position={0,0}})
    expect(player.physical_surface == a and old_body.surface == b, "god-travel-leaves-original-body-on-prior-surface")
    execute("god", {player_index = player.index, enabled = false})
    expect(player.physical_surface == b and player.character == old_body, "cross-surface-god-off-reattaches-original-body")
    verify_inventory(player, old_body, spoil_tick)
    expect(not player.character.destructible, "independent-invulnerability-survives-god-off")
    execute("invulnerable", {player_index = player.index, enabled = false})
    expect(player.character.destructible, "original-destructible-restored")
    player.character.destructible = false
    execute("invulnerable", {player_index = player.index, enabled = true})
    execute("invulnerable", {player_index = player.index, enabled = false})
    expect(not player.character.destructible, "preexisting-invulnerability-restored")
    player.character.destructible = true
    execute("god", {player_index = player.index, enabled = true})
    local full = old_body.get_inventory(defines.inventory.character_main)
    for i = 1, #full do full[i].set_stack{name = "coal", count = prototypes.item.coal.stack_size} end
    local overflow = player.get_inventory(defines.inventory.god_main)[1]
    overflow.set_stack{name = "admin-player-qc-tag", quality = "legendary"}
    overflow.tags = {identity = "overflow-tag"}
    execute("god", {player_index = player.index, enabled = false})
    local recovered = find_stack(player, "admin-player-qc-tag", "legendary")
    expect(recovered and recovered.tags.identity == "overflow-tag", "full-inventory-native-spill-preserves-tags")
    full.clear()
    execute("god", {player_index = player.index, enabled = true})
    local destroyed = root().modes[player.index].god.character
    destroyed.destroy{raise_destroy = true}
    player.get_inventory(defines.inventory.god_main)[1].set_stack{name = "uranium-235", count = 3, quality = "rare"}
    execute("god", {player_index = player.index, enabled = false})
    expect(player.character and player.character.valid and find_stack(player, "uranium-235", "rare"), "destroyed-body-native-recovery")
    execute("cheat", {player_index = player.index, enabled = true})
    execute("invulnerable", {player_index = player.index, enabled = true})
    execute("god", {player_index = player.index, enabled = true})
    q.enabled = false
    players.on_configuration_changed(game.tick, false)
    expect(player.character and player.character.destructible and not player.cheat_mode and not root().modes[player.index], "system-disable-reversible-mode-cleanup")
    q.enabled = true
    players.on_configuration_changed(game.tick, true)
    q.surface_a = a.index
    q.surface_b = b.index
    record("native-api-sequence-complete")
end
local function start_jail(player, timer)
    local q = fixture()
    player.admin = false
    local group = game.permissions.create_group("admin-player-qc-original")
    player.permission_group = group
    player.cheat_mode = true
    execute("cheat", {player_index = player.index, enabled = false})
    execute("invulnerable", {player_index = player.index, enabled = true})
    execute("god", {player_index = player.index, enabled = true})
    local return_surface = root().modes[player.index].god.character.surface.index
    local short = players.execute(nil, "jail", {player_index=player.index, minutes=0.5}, game.tick)
    expect(not short and not root().jails[player.index], "jail-rejects-sub-minute-sentence")
    execute("jail", {player_index = player.index, minutes = 1,
        timer_mode = timer, reason = config.capture_hud and "Administrative review: remain here while the incident is checked." or "fixture"})
    local jail = root().jails[player.index]
    q.jail_started = game.tick
    q.original_group = group.group_id
    q.return_surface = return_surface
    expect(jail and player.physical_surface.name == "ei-admin-jail" and not player.cheat_mode, "jail-suspends-modes")
    expect(player.permission_group.allows_action(defines.input_action.start_walking)
        and player.permission_group.allows_action(defines.input_action.write_to_console), "native-jail-permissions")
    expect(not player.permission_group.allows_action(defines.input_action.build)
        and not player.permission_group.allows_action(defines.input_action.open_gui), "jail-blocks-world-interaction")
    expect((config.capture_hud or jail.reason == "fixture") and jail.remaining_ticks == 3600, "jail-persists-reason-and-valid-duration")
    expect(jail.hud and jail.hud.valid and jail.hud_second == 60, "prisoner-hud-native-reason-clock-countdown")
    expect(jail.character == player.character and not player.character.destructible and jail.destructible_before,
        "jail-owns-character-protection")
    q.hud = jail.hud
    q.stage = "jailed"
end
script.on_event(defines.events.on_tick, function(e)
    local q = fixture()
    if q.complete then return end
    if loaded and q.saved then
        local player = game.get_player(q.player_index)
        if not q.offline_start then
            q.offline_start = e.tick
            expect(player and not player.connected, "server-load-player-is-offline")
            q.offline_expected = q.saved_remaining
        end
        if config.suite == "save-god" then
            if e.tick - q.offline_start == 3 then
                local name = "AdminPlayerQcUnknownName"
                local banned, ban_message = players.execute(nil, "ban", {player_index = player.index, player_name = name, reason = "isolated QC"}, e.tick)
                expect(banned and tostring(ban_message):find(name, 1, true), "explicit-ban-name-overrides-dropdown-index")
                local unbanned = players.execute(nil, "unban", {player_index = player.index, player_name = name}, e.tick)
                expect(unbanned, "native-unban-explicit-name")
                expect(player.physical_controller_type == defines.controllers.god, "saved-god-controller-offline")
                local native = player.get_inventory(defines.inventory.god_main)
                expect(native and native.valid and native[1].valid_for_read, "offline-god-inventory-accessible")
                game.remove_offline_players{q.player_index}
                expect(not game.get_player(q.player_index), "native-offline-player-removed")
                local tagged = removed_god_stack(q, "admin-player-qc-tag", "rare")
                expect(tagged and tagged.tags.identity == "god-tag" and tagged.tags.nested.value == 419,
                    "pre-remove-escrow-preserves-exact-god-stack", {body_valid = q.god_body.valid,
                        escrow = root().modes[q.player_index] and root().modes[q.player_index].escrow ~= nil})
                local nested = removed_god_stack(q, "admin-player-qc-inventory", "normal")
                expect(nested and nested.get_inventory(defines.inventory.item_main).get_item_count{name = "steel-plate", quality = "rare"} == 13,
                    "pre-remove-nested-inventory-preserved")
                complete()
            end
            return
        end
        if players.has_tick_work(e.tick) then players.updater(e.tick) end
        if e.tick - q.offline_start == 180 then
            local jail = root().jails[q.player_index]
            if config.timer_mode == "online" then
                local remaining = players.peek_summary(e.tick).jails[q.player_index].remaining_ticks
                expect(jail and not jail.release_pending and math.abs(remaining - q.offline_expected) <= 1,
                    "online-jail-pauses-across-offline-server-load", {actual = remaining, expected = q.offline_expected})
            else
                local remaining = players.peek_summary(e.tick).jails[q.player_index].remaining_ticks
                expect(remaining <= q.offline_expected - 180, "elapsed-jail-advances-offline",
                    {actual = remaining, saved = q.offline_expected})
            end
            complete()
        end
        return
    end
    local player = q.player_index and game.get_player(q.player_index) or game.connected_players[1]
    if not player then
        q.waited = (q.waited or 0) + 1
        assert(q.waited < 120, "Fixture requires a saved connected player or a client launch.")
        return
    end
    if q.stage == "start" then
        q.player_index = player.index
        ready_player(player)
        record("connected-player", {index = player.index, connected = player.connected, count = #game.connected_players})
        if config.suite == "save-god" then
            player.teleport({0, 0}, surface("admin-player-qc-god"))
            q.god_body = setup_inventory(player)
            q.god_surface = player.physical_surface.index
            q.god_position = player.physical_position
            execute("god", {player_index = player.index, enabled = true})
            god_inventory(player)
            q.save_started = e.tick
            q.stage = "god-save"
        else
            if config.suite == "all" then basic(player) end
            start_jail(player, config.timer_mode)
        end
    end
    if q.stage == "god-save" and e.tick - q.save_started == 30 then
        q.saved = true
        game.auto_save("admin-player-god")
        log("ADMIN_PLAYER_QC SAVE_REQUEST")
    end
    if q.stage == "jailed" then
        local elapsed = e.tick - q.jail_started
        if config.capture_hud and not q.hud_captured and elapsed >= 15
            and player.display_resolution.width == 1280 and player.display_resolution.height == 720
            and math.abs(player.display_scale - 1.5) < 0.001 then
            players.on_display_changed(event(player, "on_player_display_resolution_changed"))
            local jail = root().jails[player.index]
            game.take_screenshot{player=player,path="jail-hud.png",show_gui=true,resolution=player.display_resolution}
            helpers.write_file("jail-hud.json",helpers.table_to_json{resolution=player.display_resolution,scale=player.display_scale,
                reason=jail.reason,timer_mode=jail.timer_mode,remaining_ticks=players.peek_summary(e.tick).jails[player.index].remaining_ticks},false)
            q.hud_captured = true
        end
        if config.suite == "all" then
            if elapsed == 1 then
                players.on_player_event(event(player, "on_player_controller_changed"))
                local jail = root().jails[player.index]
                expect(jail.hud == q.hud and jail.hud_second == 60, "same-second-hud-retains-elements-and-caption-signature")
                local old = player.character
                local replacement = assert(old.surface.create_entity{name=old.name, position={old.position.x+3,old.position.y}, force=old.force})
                player.set_controller{type=defines.controllers.character, character=replacement}
                players.on_player_event(event(player, "on_player_controller_changed"))
                expect(old.destructible and not replacement.destructible and jail.character == replacement, "jail-body-replacement-restores-old-protects-new")
                player.set_controller{type=defines.controllers.character, character=old}
                players.on_player_event(event(player, "on_player_controller_changed"))
                expect(replacement.destructible and not old.destructible, "jail-body-return-restores-replacement")
                replacement.destroy()
            elseif elapsed == 10 then
                player.permission_group.destroy()
            elseif elapsed == 12 then
                expect(player.permission_group and player.permission_group.group_id == root().players.jail_group_id
                    and player.permission_group.allows_action(defines.input_action.start_walking), "deleted-jail-group-recovered-next-slice")
            elseif elapsed == 20 then
                player.permission_group.set_allows_action(defines.input_action.build, true)
            elseif elapsed == 22 then
                expect(not player.permission_group.allows_action(defines.input_action.build), "edited-jail-permissions-repaired-next-slice")
            elseif elapsed == 30 then
                local jail_surface = player.physical_surface
                player.teleport({0,0}, game.get_surface(q.return_surface))
                expect(game.delete_surface(jail_surface), "jail-surface-deletion-queued")
            elseif elapsed == 32 then
                expect(player.physical_surface.name == "ei-admin-jail" and player.physical_surface.index == root().jails[player.index].surface_index,
                    "deleted-jail-surface-recreated-and-prisoner-reconfined")
            elseif elapsed == 60 then
                players.on_player_event(event(player, "on_player_controller_changed"))
                expect(root().jails[player.index].hud == q.hud and root().jails[player.index].hud_second == 59, "hud-countdown-updates-next-displayed-second")
                q.pause_remaining = players.peek_summary(e.tick).jails[player.index].remaining_ticks
                players.on_player_left_game(event(player, "on_player_left_game"))
                record("online-clock-hook-paused", {remaining = q.pause_remaining})
            elseif elapsed == 100 then
                expect(players.peek_summary(e.tick).jails[player.index].remaining_ticks == q.pause_remaining,
                    "online-clock-hook-excludes-disconnected-interval")
                players.on_player_event(event(player, "on_player_joined_game"))
                q.release_hud = root().jails[player.index].hud
            elseif elapsed == 221 then
                -- Keep real one-minute input validation; advance only the service
                -- tick for this expiry assertion, not the native simulation clock.
                players.updater(q.jail_started + 3641)
                expect(not root().jails[player.index], "online-jail-expiry")
                expect(q.release_hud and not q.release_hud.valid, "jail-release-removes-prisoner-hud")
                expect(player.physical_controller_type == defines.controllers.god and not player.cheat_mode,
                    "jail-restores-independent-modes")
                execute("god", {player_index = player.index, enabled = false})
                expect(player.permission_group and player.permission_group.group_id == q.original_group
                    and player.physical_surface.index == q.return_surface, "jail-restores-group-and-location")
                q.enabled = false
                players.on_configuration_changed(e.tick, false)
                expect(player.cheat_mode and player.character.destructible, "jail-suspended-cheat-baseline-restored-on-disable")
                q.enabled = true
                player.admin = true
                players.on_configuration_changed(e.tick, true)
                execute("set_spawn", {force_index = player.force.index, planet = "nauvis", position = {0, 0}})
                player.teleport({0, 0}, game.get_surface(q.surface_b))
                local body = player.character
                player.character = nil
                player.associate_character(body)
                root().pending_spawns[player.index] = {attempts = 0}
                players.on_configuration_changed(e.tick, true)
                expect(players.has_tick_work(e.tick + 60), "configuration-reschedules-pending-spawn")
                player.set_controller{type = defines.controllers.character, character = body}
                players.on_player_event(event(player, "on_player_respawned"))
                expect(player.physical_surface.name == "nauvis" and not root().pending_spawns[player.index], "pending-spawn-on-character-readiness")
                player.teleport({0, 0}, game.get_surface(q.surface_b))
                player.character.die()
                player.ticks_to_respawn = nil
                expect(player.character and player.physical_surface.name == "nauvis", "native-death-respawn-applies-spawn-override")
                player.admin = false
                local original = player.permission_group
                local body = player.character
                body.destructible = false
                execute("jail", {player_index=player.index, minutes=1, reason="fallback fixture"})
                root().jails[player.index].return_surface_index = 4294967295
                root().jails[player.index].return_position = {x=9999,y=9999}
                player.permission_group.destroy()
                execute("release", {player_index=player.index})
                local spawn = player.force.get_spawn_position(game.surfaces.nauvis)
                expect(player.physical_surface.name == "nauvis" and math.abs(player.physical_position.x-spawn.x)<64
                    and math.abs(player.physical_position.y-spawn.y)<64, "missing-origin-uses-force-spawn-position")
                expect(player.permission_group == original, "release-after-owned-group-deletion-restores-saved-group")
                expect(not body.destructible, "jail-restores-originally-indestructible-body")
                body.destructible = true
                execute("jail", {player_index=player.index, minutes=1})
                local external = game.permissions.create_group("admin-player-qc-external")
                player.permission_group = external
                execute("release", {player_index=player.index})
                expect(player.permission_group == external and body.destructible, "release-preserves-external-group-and-restores-body")
                execute("jail", {player_index=player.index, minutes=1})
                local hud = root().jails[player.index].hud
                q.enabled = false
                players.on_configuration_changed(e.tick, false)
                expect(not root().jails[player.index] and not hud.valid and body.destructible,
                    "disabled-toolkit-releases-jail-protection-and-hud")
                complete()
            end
        elseif elapsed >= 30 and not q.saved and (not config.capture_hud or q.hud_captured) then
            q.saved = true
            q.saved_remaining = players.peek_summary(e.tick).jails[player.index].remaining_ticks
            q.save_tick = e.tick
            game.auto_save("admin-player-jail")
            log("ADMIN_PLAYER_QC SAVE_REQUEST")
        end
    end
    if players.has_tick_work(e.tick) then players.updater(e.tick) end
end)

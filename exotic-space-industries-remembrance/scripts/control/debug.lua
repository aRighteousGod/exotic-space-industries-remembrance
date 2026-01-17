local model = {}
local ei_lib = require("lib/lib")
-- command '/tp SURFACE_NAME_OR_INDEX'
function model.teleport_to(event)
  if event.command ~= 'tp' then
    return
  end

  if not event.parameters then
    return
  end

  if not event.player_index then
    return
  end

  local player = game.get_player(event.player_index)

  if not player.admin then
    return
  end

  local destination = game.get_surface(event.parameters)

  if destination == nil then
    return
  end

  ei_lib.crystal_echo("Teleporting")
  player.teleport({0,0}, destination)
end

-- Debugs proclaim
commands.add_command("codex_test", "Triggers a test echo message from echo_codex", function(cmd)
    ei_echo_codex.proclaim("que_width", {
        val = 6,
        --tint = "solar flare",           -- must match a key in your tint_palette
        --tint_adj = "radiant",           -- optional
        player = cmd.player_index,      -- critical: sets who receives the message
        intent = "signal",              -- optional: activates fallback tint if tint=nil
        font = "default",               -- optional
        force_full_tint = false,        -- optional
        as_floating_text = true,        -- set to true for draw_text
        floating_time_to_live = 6000
    })
end)
commands.add_command("refresh_beacon_overload", "Recalculates all machines beacon overload status", function(cmd)
    local player = game.get_player(cmd.player_index)
    if not player or not player.admin then return end
    ei_lib.crystal_echo("Beacon overload recalculates across the cosmos")
    ei_beacon_overload.refresh_all_overloads()
end)
commands.add_command("goto-gaia", "Teleport to Gaia's surface", function(cmd)
    local player = game.get_player(cmd.player_index)
    if not player or not player.admin then return end
    local planet = game.planets["gaia"]
    local surface = planet and planet.surface
    if not surface then
        game.planets["gaia"]:create_surface("gaia")
        ei_lib.crystal_echo("✈ [Astral Transit] - Gaia begins to remember why she came...")
        --reforge_gaia_surface()
        return
    end
    local position = {0, 0}  -- center of the world
    player.teleport(position, surface)
    ei_lib.crystal_echo("✈ [Astral Transit] — " .. player.name .. " arrives upon Gaia’s crust.")
    log(player.name.." used goto-gaia")
end)

commands.add_command("goto-fulgora", "Teleport to Fulgoras's surface", function(cmd)
    local player = game.get_player(cmd.player_index)
    if not player or not player.admin then return end
    local planet = game.planets["fulgora"]
    local surface = planet and planet.surface
    if not surface then
        game.planets["fulgora"]:create_surface("fulgora")
        ei_lib.crystal_echo("✈ [Astral Transit] - Fulgora shakes off the dust of ages.")
        return
    end
    local position = {0, 0}  -- center of the world
    player.teleport(position, surface)
    ei_lib.crystal_echo("✈ [Astral Transit] — " .. player.name .. " arrives upon Fulgora's crust.")
    log(player.name.." used goto-fulgora")
end)

commands.add_command("goto-vulcanus", "Teleport to Vulcanus's surface", function(cmd)
    local player = game.get_player(cmd.player_index)
    if not player or not player.admin then return end
    local planet = game.planets["vulcanus"]
    local surface = planet and planet.surface
    if not surface then
        game.planets["vulcanus"]:create_surface("vulcanus")
        ei_lib.crystal_echo("✈ [Astral Transit] - Vulcanus erupts into existence.")
        return
    end
    local position = {0, 0}  -- center of the world
    player.teleport(position, surface)
    ei_lib.crystal_echo("✈ [Astral Transit] — " .. player.name .. " arrives upon Vulcanus' crust.")
    log(player.name.." used goto-vulcanus")
end)

commands.add_command("goto-gleba", "Teleport to Gleba's surface", function(cmd)
    local player = game.get_player(cmd.player_index)
    if not player or not player.admin then return end
    local planet = game.planets["gleba"]
    local surface = planet and planet.surface
    if not surface then
        game.planets["gleba"]:create_surface("gleba")
        ei_lib.crystal_echo("✈ [Astral Transit] - Gleba awakens from its slumber.")
        return
    end
    local position = {0, 0}  -- center of the world
    player.teleport(position, surface)
    ei_lib.crystal_echo("✈ [Astral Transit] — " .. player.name .. " arrives upon Gleba's crust.")
    log(player.name.." used goto-gleba")
end)
commands.add_command("goto-aquilo", "Teleport to Aquillo's surface", function(cmd)
    local player = game.get_player(cmd.player_index)
    if not player or not player.admin then return end
    local planet = game.planets["aquilo"]
    local surface = planet and planet.surface
    if not surface then
        game.planets["aquilo"]:create_surface("aquilo")
        ei_lib.crystal_echo("✈ [Astral Transit] - Aquilo shivers into being.")
        return
    end
    local position = {0, 0}  -- center of the world
    player.teleport(position, surface)
    ei_lib.crystal_echo("✈ [Astral Transit] — " .. player.name .. " arrives upon Aquilo's crust.")
    log(player.name.." used goto-aquilo")
end)
commands.add_command("goto-nauvis", "Teleport to Nauvis' surface", function(cmd)
    local player = game.get_player(cmd.player_index)
    if not player or not player.admin then return end
    local planet = game.planets["nauvis"]
    local surface = planet and planet.surface
    if not surface then
        game.planets["nauvis"]:create_surface("nauvis")
        ei_lib.crystal_echo("✈ [Astral Transit] - Nauvis radiates with life once more.")
        return
    end
    local position = {0, 0}  -- center of the world
    player.teleport(position, surface)
    ei_lib.crystal_echo("✈ [Astral Transit] — " .. player.name .. " arrives upon Nauvis' crust.")
    log(player.name.." used goto-nauvis")
end)


return model
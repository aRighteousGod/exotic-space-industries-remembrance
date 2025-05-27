-- Init storage variables for Exotic Industries
ei_lib = require("lib/lib")
ei_echo_codex = require("lib/echo_codex")
local ei_global = {}
--Crystal Echo color library

local crystal_colors = {
    {112, 48, 160},   -- Royal purple
    {0, 123, 167},    -- Cerulean
    {186, 85, 211},   -- Orchid flare
    {72, 209, 204},   -- Crystal teal
    {255, 105, 180},  -- Etheric pink
    {240, 230, 140},  -- Dream gold
    {50, 205, 50},    -- Verdant flux
    {255, 69, 0}      -- Solar flare
  }

local tint_palette = {
    ["mirage"]      = { name = "mirage",     adj = "eldritch",    hex = "#2af9aa", intent = "mystery" },
    ["specter"]     = { name = "specter",    adj = "entropic",    hex = "#d19e79", intent = "signal" },
    ["singularity"] = { name = "singularity",adj = "mirrored",    hex = "#c58681", intent = "mystery" },
    ["void"]        = { name = "void",       adj = "entropic",    hex = "#cccba7", intent = "signal" },
    ["mycelium"]    = { name = "mycelium",   adj = "mystic",      hex = "#ef7ef4", intent = "mystery" },
    ["halo"]        = { name = "halo",       adj = "mystic",      hex = "#708a43", intent = "mystery" },
    ["aurora"]      = { name = "aurora",     adj = "silent",      hex = "#404f7d", intent = "serenity" },
    ["frost"]       = { name = "frost",      adj = "celestial",   hex = "#222a9f", intent = "divine" },
    ["pulse"]       = { name = "pulse",      adj = "encrypted",   hex = "#88dba5", intent = "signal" },
    ["venom"]       = { name = "venom",      adj = "toxic",       hex = "#2b6624", intent = "wrath" },
    ["dusk"]        = { name = "dusk",       adj = "luminous",    hex = "#49bad9", intent = "serenity" },
    ["starlight"]   = { name = "starlight",  adj = "radiant",     hex = "#bd3097", intent = "divine" },
    ["flux"]        = { name = "flux",       adj = "toxic",       hex = "#a5c3f0", intent = "wrath" },
    ["node"]        = { name = "node",        adj = "dormant",    hex = "#4c7759", intent = "serenity" },
    ["resonance"]   = { name = "resonance",   adj = "glacial",    hex = "#2dbd66", intent = "serenity" },
    ["core"]        = { name = "core",        adj = "lunar",      hex = "#d77ec1", intent = "divine" },
    ["glyph"]       = { name = "glyph",       adj = "dissonant",  hex = "#e56af6", intent = "signal" },
    ["chime"]       = { name = "chime",       adj = "auric",      hex = "#b7cc29", intent = "divine" },
    ["matrix"]      = { name = "matrix",      adj = "volatile",   hex = "#ae8fff", intent = "wrath" },
    ["spire"]       = { name = "spire",       adj = "dissonant",  hex = "#e8a893", intent = "signal" },
    ["veil"]        = { name = "veil",        adj = "eternal",    hex = "#32e4aa", intent = "mystery" },
    ["rift"]        = { name = "rift",        adj = "iridescent", hex = "#a57880", intent = "mystery" },
    ["sigil"]       = { name = "sigil",       adj = "unstable",   hex = "#8189d0", intent = "wrath" },
    ["shard"]       = { name = "shard",       adj = "quantum",    hex = "#b982bd", intent = "signal" },
    ["beam"]        = { name = "beam",        adj = "solar",      hex = "#44caee", intent = "wrath" }
--    ["pulse"]       = { name = "pulse",       adj = "radiant",    hex = "#624385", intent = "divine" }
  }  

local intent_tint_map = {
    mystery = {
      "mirage",
      "singularity",
      "mycelium",
      "halo",
      "veil",
      "rift"
    },
    signal = {
      "specter",
      "void",
      "pulse",
      "glyph",
      "spire",
      "shard"
    },
    serenity = {
      "aurora",
      "dusk",
      "node",
      "resonance"
    },
    divine = {
      "frost",
      "pulse",
      "starlight",
      "core",
      "chime"
    },
    wrath = {
      "venom",
      "flux",
      "matrix",
      "sigil",
      "beam"
    }
  }

--====================================================================================================
--GLOBAL VARIABLES
--====================================================================================================

function ei_global.init()
    storage.ei = {}

    storage.ei["tech_scaling"] = {}
    storage.ei["tech_scaling"].maxCost = 0
    storage.ei["tech_scaling"].startPrice = 0
    storage.ei["tech_scaling"].techCount = 0

    storage.ei["overload_icons"] = {}
    storage.ei["neutron_collector_animation"] = {}
    storage.ei["neutron_sources"] = {}
    storage.ei["spawner_queue"] = {}
    storage.ei["orbital_combinators"] = {}
    storage.ei.spaced_updates = 0
	storage.ei.rng_counter = 0
    storage.ei.last_tick = 0
    storage.ei.arrival_waves = {}
    storage.ei.alien = {}
    storage.ei.tint_palette_checksum         = 646507522
    storage.ei.tint_palette = tint_palette
    storage.ei.crystal_colors_checksum       = 134327789
    storage.ei.crystal_colors = crystal_colors
    storage.ei.intent_tint_map_checksum      = 1936040709
    storage.ei.intent_tint_map = intent_tint_map

    storage.ei.gaia_reforged = 0    --Leaving room for planetary evolution down the road
    ei_lib.crystal_echo("»» INITIALIZING SYSTEM CORE: ＥＸＯＴＩＣ ＳＰΛＣΣ ＩＮＤＵＳＴＲＩＥＳ ««","default-bold")
    ei_lib.crystal_echo(">> Integrating chronometric lattices... Binding entropy to mass... Stand by.","default-semibold")
end

function ei_global.check_init()
    -- TODO: dont hardcode this
    if not storage.ei then
	    storage.ei = {}
    end
    if not storage.ei.tint_palette then
        storage.ei.tint_palette         = tint_palette
    end
    if not storage.ei.tint_palette_checksum then
        storage.ei.tint_palette_checksum         = 646507522
    end
    if not storage.ei.crystal_colors then
        storage.ei.crystal_colors       = crystal_colors
    end
    if not storage.ei.crystal_colors_checksum then
        storage.ei.crystal_colors_checksum       = 134327789
    end
    if not storage.ei.intent_tint_map then
        storage.ei.intent_tint_map      = intent_tint_map
    end
    if not storage.ei.intent_tint_map_checksum then
        storage.ei.intent_tint_map_checksum      = 1936040709
    end
    if not storage.ei.arrival_waves then
        storage.ei.arrival_waves = {}
    end
    if not storage.ei.original_gaia_settings then
        storage.ei.original_gaia_settings = full_gaia_map_gen_settings
    end
    if not storage.ei.gaia_reforged_version then
        storage.ei.gaia_reforged = 0    --Leaving room for planetary evolution down the road
    end
--[[
    local val = ei_lib.config("em_updater_que") or "Beam"
    if val == "Beam" then
        storage.ei.em_train_que = 1
    elseif val == "Ring" then
        storage.ei.em_train_que = 2 --faster to compare a number
    else
        storage.ei.em_train_que = 0
    end

    val = ei_lib.config("em_updater_que_width")
    storage.ei.que_width = (val ~= nil) and val or 6

    val = ei_lib.config("em_updater_que_transparency")
    storage.ei.que_transparency = ((val ~= nil) and val or 80) / 100

    val = ei_lib.config("em_updater_que_timetolive")
    storage.ei.que_timetolive = (val ~= nil) and val or 60

    val = ei_lib.config("em_train_glow_toggle")
    storage.ei.em_train_glow_toggle = (val ~= nil) and val or true

    val = ei_lib.config("em_train_glow_timetolive")
    storage.ei.em_train_glow_timeToLive = (val ~= nil) and val or 60

    val = ei_lib.config("em_charger_glow_toggle")
    storage.ei.em_charger_glow = (val ~= nil) and val or true

    val = ei_lib.config("em_charger_glow_timetolive")
    storage.ei.em_charger_glow_timeToLive = (val ~= nil) and val or 60
]]
    if not storage.ei["tech_scaling"] then
        storage.ei["tech_scaling"] = {}
    end

    if not storage.ei["tech_scaling"].maxCost then
        storage.ei["tech_scaling"].maxCost = 0
    end

    if not storage.ei["tech_scaling"].startPrice then
        storage.ei["tech_scaling"].startPrice = 0
    end

    if not storage.ei["tech_scaling"].techCount then
        storage.ei["tech_scaling"].techCount = 0
    end

    if not storage.ei["overload_icons"] then
        storage.ei["overload_icons"] = {}
    end

    if not storage.ei["neutron_collector_animation"] then
        storage.ei["neutron_collector_animation"] = {}
    end

    if not storage.ei["neutron_sources"] then
        storage.ei["neutron_sources"] = {}
    end

    if not storage.ei["spawner_queue"] then
        storage.ei["spawner_queue"] = {}
    end

    if not storage.ei["orbital_combinators"] then
        storage.ei["orbital_combinators"] = {}
    end

    if not storage.ei.spaced_updates then
        storage.ei.spaced_updates = 0
    end

	if not storage.ei.rng_counter then
		storage.ei.rng_counter = 0
	end
    
    if not storage.ei.last_tick then
        storage.ei.last_tick = 0
    end

    if not storage.ei.alien then
        storage.ei.alien = {}
        storage.ei.alien.state = {}
    end
end

return ei_global
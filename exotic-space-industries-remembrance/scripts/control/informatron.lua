local model = {}

local function add_centered_sprite_row(element, sprites)
    local image_container = element.add{type = "flow"}
    image_container.style.horizontal_align = "center"
    image_container.style.horizontally_stretchable = true

    for _, sprite in ipairs(sprites) do
        image_container.add{type = "sprite", sprite = sprite}
    end
end

--====================================================================================================
--INFORMATRON
--====================================================================================================

remote.add_interface("exotic-industries-informatron", {
    informatron_menu = function(data)
      return model.menu(data.player_index)
    end,
    informatron_page_content = function(data)
      return model.page_content(data.page_name, data.player_index, data.element)
    end
})

--MENU
------------------------------------------------------------------------------------------------------

function model.menu(player_index)

    local player = game.get_player(player_index)
    local force = nil

    if player then
        force = player.force
    end

    local model = {
        game_related = {
            overall = 1,
            ages_and_tech = 1,
            tech_scaling = 1,
            nauvis_pressure_grace = 1,
            rocket_launch_pollution = 1,
            turrets = 1,
        },
        world_gen_related = {
            resources = 1,
            mining_scars = 1,
            asteroid_variants = 1,
            fulgora_day_variation = 1,
            artifacts = 1,
            gate = 1,
        },
        new_logistics = {
            train_progression = 1,
            em_trains = 1,
            orbital_scanner = 1,
            cranes_and_belts = 1,
            loaders = 1,
            bots = 1,
        },
        new_mechanics = {
            beacon_overhaul = 1,
            specialised_pipes = 1,
            induction_matrix = 1,
            teslas_legacy = 1,
            exotic_stabilizer = 1,
        },
        nuclear_fission_and_fusion = {
            fission = 1,
            --htr_reactor = 1,
            fusion_power = 1,
            --neutrons = 1,
        },
    }

    -- optional pages
    if force then

        model.new_mechanics.black_hole = 1

    end

    --[[
    if game.forces["player"] and game.forces["player"].technologies and game.forces["player"].technologies["ei_black-hole-exploration"].enabled == true then
        model.new_mechanics.black_hole = 1
    end
    ]]

    return model

    -- NOTE: here the force is hardcoded to player, support for multiple forces is not implemented therefore

end

-- strucure of stuff

-- GAME RELATED:
--  - remind to check settings
--  - ages and tech (tiered labs)
--  - how age progress and research works

-- WORLD GEN REALTED:
--  - resources: stone, surface patches and veins
--  - artifacts
--  - knowledge system

-- NEW LOGISTCS:
--  - EI has tons of new logistic options
--  - train progression + fuel for trains / spidertrons
--  - inserter cranes
--  - bots

-- NEW MECHANICS:
--  - Beacon overhaul
--  - spezialised pipes and cables
--  - space destinations
--  - Induction matrix
--  - Exotic explosives

-- NUCLEAR FISSION AND FUSION:
--  - changes to fission + nuclear waste
--  - HTR reactor
--  - Fusion power
--  - Neutrons and you

-- DISCOVERIES:
-- - TODO new things


--CONTENT
------------------------------------------------------------------------------------------------------

function model.exotic_industries_informatron(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.welcome"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.welcome-text"}}

    local image_container = element.add{type = "flow"}
    image_container.style.horizontal_align = "center"
    image_container.style.horizontally_stretchable = true
    image_container.add{type = "sprite", sprite = "ei_plasma-cube-logo"}

    element.add{type = "label", caption = {"exotic-industries-informatron.welcome-text-2"}}
end


function model.game_related(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.game-related"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.game-related-text"}}
end

function model.overall(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.overall"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.overall-text"}}

    element.add{type = "label", caption = {"exotic-industries-informatron.biters"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.biters-text"}}
end

function model.ages_and_tech(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.ages-and-tech"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.ages-and-tech-text"}}

    local image_container = element.add{type = "flow"}
    image_container.style.horizontal_align = "center"
    image_container.style.horizontally_stretchable = true

    element.add{type = "label", caption = {"exotic-industries-informatron.ages-and-tech-2"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.ages-and-tech-text-2"}}

    -- element.add{type = "label", caption = {"exotic-industries-informatron.tech"}, style = "heading_1_label"}
    -- element.add{type = "label", caption = {"exotic-industries-informatron.tech-text"}}

end

function model.tech_scaling(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.tech"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.tech-text"}}

    element.add{type = "label", caption = {"exotic-industries-informatron.tech-2"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.tech-text-2"}}

    element.add{type = "label", caption = {"exotic-industries-informatron.tech-3"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.tech-text-3"}}
end

function model.nauvis_pressure_grace(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.nauvis-pressure-grace"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.nauvis-pressure-grace-text"}}

    element.add{type = "label", caption = {"exotic-industries-informatron.nauvis-pressure-grace-2"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.nauvis-pressure-grace-text-2"}}
end

function model.rocket_launch_pollution(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.rocket-launch-pollution"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.rocket-launch-pollution-text"}}

    add_centered_sprite_row(element, {
        "item/rocket-silo",
    })

    element.add{type = "label", caption = {"exotic-industries-informatron.rocket-launch-pollution-2"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.rocket-launch-pollution-text-2"}}
end

function model.turrets(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.turrets"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.turrets-text"}}

    add_centered_sprite_row(element, {
        "item/ei-shotgun-turret",
        "item/ei-auto-shotgun-turret",
        "item/ei-acidthrower-turret",
        "item/ei-cannon-turret-mk1",
        "item/ei-cannon-turret",
        "item/ei-gatling-turret",
    })

    element.add{type = "label", caption = {"exotic-industries-informatron.turrets-2"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.turrets-text-2"}}

    element.add{type = "label", caption = {"exotic-industries-informatron.turrets-3"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.turrets-text-3"}}

    add_centered_sprite_row(element, {
        "item/flamethrower-turret",
        "item/laser-turret",
    })

    element.add{type = "label", caption = {"exotic-industries-informatron.turrets-4"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.turrets-text-4"}}

    element.add{type = "label", caption = {"exotic-industries-informatron.turrets-5"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.turrets-text-5"}}

    add_centered_sprite_row(element, {
        "item/ei-plasma-turret",
        "item/zeus-wrath-zeus-turret",
    })
end


function model.world_gen_related(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.world-gen-related"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.world-gen-related-text"}}
end

function model.resources(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.resources"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.resources-text"}}

    element.add{type = "label", caption = {"exotic-industries-informatron.surface-patches"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.surface-patches-text"}}

    add_centered_sprite_row(element, {
        "item/ei-poor-iron-chunk",
        "item/ei-poor-copper-chunk",
        "item/ei-poor-uranium-chunk",
        "item/coal",
        "item/stone",
        "fluid/crude-oil",
    })

    element.add{type = "label", caption = {"exotic-industries-informatron.veins"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.veins-text"}}

    add_centered_sprite_row(element, {
        "item/ei-iron-chunk",
        "item/ei-copper-chunk",
        "item/ei-coal-chunk",
        "item/ei-sulfur-chunk",
        "item/ei-lead-chunk",
        "item/ei-gold-chunk",
        "item/ei-uranium-chunk",
        "item/ei-neodym-chunk",
    })

    element.add{type = "label", caption = {"exotic-industries-informatron.chunk-grades"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.chunk-grades-text"}}

    add_centered_sprite_row(element, {
        "item/ei-poor-iron-chunk",
        "item/ei-poor-copper-chunk",
        "item/ei-poor-uranium-chunk",
        "item/ei-iron-chunk",
        "item/ei-copper-chunk",
        "item/ei-uranium-chunk",
    })

    element.add{type = "label", caption = {"exotic-industries-informatron.chunk-refining"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.chunk-refining-text"}}

    add_centered_sprite_row(element, {
        "item/ei-purifier",
        "item/ei-pure-iron",
        "item/ei-pure-copper",
    })

    element.add{type = "label", caption = {"exotic-industries-informatron.chunk-refining-2"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.chunk-refining-text-2"}}

    add_centered_sprite_row(element, {
        "item/ei-arc-furnace",
        "fluid/ei-molten-iron",
        "fluid/ei-molten-copper",
        "item/ei-plasma-heater",
    })
end

function model.mining_scars(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.mining-scars"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.mining-scars-text"}}

    add_centered_sprite_row(element, {
        "item/ei-burner-quarry",
        "item/ei-steam-quarry",
        "item/ei-electric-quarry",
        "item/big-mining-drill",
    })

    element.add{type = "label", caption = {"exotic-industries-informatron.mining-scars-2"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.mining-scars-text-2"}}
end

function model.asteroid_variants(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.asteroid-variants"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.asteroid-variants-text"}}

    add_centered_sprite_row(element, {
        "item/ei-chemical-asteroid-chunk",
        "item/ei-organic-asteroid-chunk",
        "item/ei-rock-asteroid-chunk",
        "item/ei-uranium-asteroid-chunk",
        "item/ei-petrified-asteroid-chunk",
        "item/ei-scrap-asteroid-chunk",
    })

    element.add{type = "label", caption = {"exotic-industries-informatron.chemical-asteroid"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.chemical-asteroid-text"}}

    element.add{type = "label", caption = {"exotic-industries-informatron.organic-asteroid"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.organic-asteroid-text"}}

    element.add{type = "label", caption = {"exotic-industries-informatron.rock-asteroid"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.rock-asteroid-text"}}

    element.add{type = "label", caption = {"exotic-industries-informatron.uranium-asteroid"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.uranium-asteroid-text"}}

    element.add{type = "label", caption = {"exotic-industries-informatron.petrified-asteroid"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.petrified-asteroid-text"}}

    element.add{type = "label", caption = {"exotic-industries-informatron.scrap-asteroid"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.scrap-asteroid-text"}}

    element.add{type = "label", caption = {"exotic-industries-informatron.asteroid-anomalies"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.asteroid-anomalies-text"}}

    add_centered_sprite_row(element, {
        "item/ei-neuro-reactive-residue",
        "item/ei-sporeglass-heart",
        "item/ei-gravity-braided-ore",
        "item/ei-isotopic-ghost-shell",
        "item/ei-chrono-fossil-shard",
        "item/ei-worm-torn-relay-core",
    })
end

function model.fulgora_day_variation(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.fulgora-day-variation"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.fulgora-day-variation-text"}}

    element.add{type = "label", caption = {"exotic-industries-informatron.fulgora-day-variation-2"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.fulgora-day-variation-text-2"}}
end

function model.artifacts(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.artifacts"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.artifacts-text"}}

    local image_container = element.add{type = "flow"}
    image_container.style.horizontal_align = "center"
    image_container.style.horizontally_stretchable = true
    image_container.add{type = "sprite", sprite = "ei_artifact"}
end

function model.gate(player_index, element)
    local function add_section(section_key, text_key, sprite_name)
        element.add{type = "label", caption = {"exotic-industries-informatron." .. section_key}, style = "heading_1_label"}
        element.add{type = "label", caption = {"exotic-industries-informatron." .. text_key}}

        if sprite_name then
            local image_container = element.add{type = "flow"}
            image_container.style.horizontal_align = "center"
            image_container.style.horizontally_stretchable = true
            image_container.add{type = "sprite", sprite = sprite_name}
        end
    end

    add_section("gate", "gate-text", "ei_gate")
    add_section("gate-2", "gate-text-2")
    add_section("gate-3", "gate-text-3")
    add_section("gate-4", "gate-text-4")
    add_section("gate-5", "gate-text-5")
    add_section("gate-6", "gate-text-6")
end

function model.repair(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.artifacts"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.artifacts-text"}}

    local image_container = element.add{type = "flow"}
    image_container.style.horizontal_align = "center"
    image_container.style.horizontally_stretchable = true
    image_container.add{type = "sprite", sprite = "ei_artifact"}

    element.add{type = "label", caption = {"exotic-industries-informatron.repair"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.repair-text"}}
end

function model.knowledge(player_index, element)
    ei_knowledge_system.knowledge_page(player_index, element)
end


function model.new_logistics(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.new-logistics"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.new-logistics-text"}}
end

function model.train_progression(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.train-progression"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.train-progression-text-2"}}

    local image_container = element.add{type = "flow"}
    image_container.style.horizontal_align = "center"
    image_container.style.horizontally_stretchable = true
    image_container.add{type = "sprite", sprite = "ei_train_progression"}

    element.add{type = "label", caption = {"exotic-industries-informatron.spidertron"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.spidertron-text"}}
end

function model.em_trains(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.em-trains"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.em-trains-text"}}

    add_centered_sprite_row(element, {
        "item/ei_charger",
        "item/ei_em-locomotive",
        "item/ei_em-cargo-wagon",
        "item/ei_em-fluid-wagon",
    })

    element.add{type = "label", caption = {"exotic-industries-informatron.em-trains-2"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.em-trains-text-2"}}

    element.add{type = "label", caption = {"exotic-industries-informatron.em-trains-3"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.em-trains-text-3"}}
end

function model.orbital_scanner(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.orbital-scanner"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.orbital-scanner-text"}}

    local image_container = element.add{type = "flow"}
    image_container.style.horizontal_align = "center"
    image_container.style.horizontally_stretchable = true
    image_container.add{type = "sprite", sprite = "item/ei-orbital-combinator"}

    element.add{type = "label", caption = {"exotic-industries-informatron.orbital-scanner-2"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.orbital-scanner-text-2"}}

    element.add{type = "label", caption = {"exotic-industries-informatron.orbital-scanner-3"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.orbital-scanner-text-3"}}
end

function model.cranes_and_belts(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.cranes-and-belts"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.cranes-and-belts-text"}}
end

function model.loaders(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.loaders"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.loaders-text"}}

    add_centered_sprite_row(element, {
        "item/ei-loader",
        "item/ei-fast-loader",
        "item/ei-express-loader",
        "item/ei-turbo-loader",
        "item/ei-neo-loader",
    })

    element.add{type = "label", caption = {"exotic-industries-informatron.loaders-2"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.loaders-text-2"}}

    element.add{type = "label", caption = {"exotic-industries-informatron.loaders-3"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.loaders-text-3"}}

    element.add{type = "label", caption = {"exotic-industries-informatron.loaders-4"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.loaders-text-4"}}

    element.add{type = "label", caption = {"exotic-industries-informatron.loaders-5"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.loaders-text-5"}}
end

function model.bots(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.bots"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.bots-text"}}

    element.add{type = "label", caption = {"exotic-industries-informatron.steam-bots"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.steam-bots-text"}}

    add_centered_sprite_row(element, {
        "item/rp-steam-roboport",
        "item/rp-steam-logistic-bot",
        "item/rp-steam-construction-bot",
    })

    element.add{type = "label", caption = {"exotic-industries-informatron.steam-bots-2"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.steam-bots-text-2"}}

    element.add{type = "label", caption = {"exotic-industries-informatron.bots-2"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.bots-text-2"}}

    add_centered_sprite_row(element, {
        "ei_robots",
    })
end


function model.new_mechanics(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.new-mechanics"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.new-mechanics-text"}}
end

function model.beacon_overhaul(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.beacon-overhaul"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.beacon-overhaul-text"}}

    local image_container = element.add{type = "flow"}
    image_container.style.horizontal_align = "center"
    image_container.style.horizontally_stretchable = true
    image_container.add{type = "sprite", sprite = "ei_beacons"}
end

function model.specialised_pipes(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.specialised-pipes"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.specialised-pipes-text"}}

    add_centered_sprite_row(element, {
        "ei_pipes",
    })

    element.add{type = "label", caption = {"exotic-industries-informatron.specialised-pipes-2"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.specialised-pipes-text-2"}}

    add_centered_sprite_row(element, {
        "item/ei-insulated-pipe",
        "item/ei-insulated-underground-pipe",
        "item/ei-insulated-tank",
    })

    element.add{type = "label", caption = {"exotic-industries-informatron.specialised-pipes-3"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.specialised-pipes-text-3"}}
end

function model.induction_matrix(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.induction-matrix"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.induction-matrix-text"}}

    local image_container = element.add{type = "flow"}
    image_container.style.horizontal_align = "center"
    image_container.style.horizontally_stretchable = true
    image_container.add{type = "sprite", sprite = "ei_induction_matrix"}

    element.add{type = "label", caption = {"exotic-industries-informatron.induction-matrix-2"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.induction-matrix-2-text"}}
end

function model.teslas_legacy(player_index, element)
    local behavior_mode = "legacy-fidelity"
    if settings and settings.startup and settings.startup["ei-tl-behavior-mode"] then
        behavior_mode = settings.startup["ei-tl-behavior-mode"].value or behavior_mode
    end

    element.add{type = "label", caption = {"exotic-industries-informatron.teslas-legacy"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.teslas-legacy-text"}}

    add_centered_sprite_row(element, {
        "item/tl-basic-tesla-coil",
        "item/tl-advanced-tesla-coil",
        "item/tl-tesla-tank",
    })

    element.add{type = "label", caption = {"exotic-industries-informatron.teslas-legacy-2"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.teslas-legacy-text-2", {"string-mod-setting.ei-tl-behavior-mode-" .. behavior_mode}}}

    element.add{type = "label", caption = {"exotic-industries-informatron.teslas-legacy-3"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.teslas-legacy-text-3"}}

    add_centered_sprite_row(element, {
        "item/teslagun",
        "item/tesla-ammo",
        "item/tesla-turret",
    })

    element.add{type = "label", caption = {"exotic-industries-informatron.teslas-legacy-4"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.teslas-legacy-text-4"}}

    element.add{type = "label", caption = {"exotic-industries-informatron.teslas-legacy-5"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.teslas-legacy-text-5"}}

    element.add{type = "label", caption = {"exotic-industries-informatron.teslas-legacy-6"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.teslas-legacy-text-6"}}

    element.add{type = "label", caption = {"exotic-industries-informatron.teslas-legacy-7"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.teslas-legacy-text-7"}}
end

function model.exotic_stabilizer(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.exotic-stabilizers"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.exotic-stabilizers-text"}}

    local image_container = element.add{type = "flow"}
    image_container.style.horizontal_align = "center"
    image_container.style.horizontally_stretchable = true
    image_container.add{type = "sprite", sprite = "ei_exotic_stabilizers"}
end

function model.black_hole(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.black-hole"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.black-hole-text"}}

    local image_container = element.add{type = "flow"}
    image_container.style.horizontal_align = "center"
    image_container.style.horizontally_stretchable = true
    image_container.add{type = "sprite", sprite = "ei_black_hole"}

    element.add{type = "label", caption = {"exotic-industries-informatron.black-hole-2"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.black-hole-2-text"}}

    element.add{type = "label", caption = {"exotic-industries-informatron.black-hole-3"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.black-hole-3-text"}}
end


function model.nuclear_fission_and_fusion(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.nuclear-fission-and-fusion"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.nuclear-fission-and-fusion-text"}}
end

function model.fission(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.fission-reactors"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.fission-reactors-text"}}

    local image_container = element.add{type = "flow"}
    image_container.style.horizontal_align = "center"
    image_container.style.horizontally_stretchable = true
    image_container.add{type = "sprite", sprite = "ei_fission_reactors"}

    element.add{type = "label", caption = {"exotic-industries-informatron.fission-reactors-2"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.fission-reactors-2-text"}}
end

function model.fusion_power(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.fusion-power"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.fusion-power-text"}}

    local image_container = element.add{type = "flow"}
    image_container.style.horizontal_align = "center"
    image_container.style.horizontally_stretchable = true
    image_container.add{type = "sprite", sprite = "ei_fusion_power"}

    element.add{type = "label", caption = {"exotic-industries-informatron.fusion-power-2"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.fusion-power-2-text"}}
end

function model.page_content(page_name, player_index, element)
    if page_name == "exotic-industries-informatron" then
        model.exotic_industries_informatron(player_index, element)
    end

    -- =======================================================
    if page_name == "game_related" then
        model.game_related(player_index, element)
    end

    if page_name == "overall" then
        model.overall(player_index, element)
    end

    if page_name == "ages_and_tech" then
        model.ages_and_tech(player_index, element)
    end

    if page_name == "tech_scaling" then
        model.tech_scaling(player_index, element)
    end

    if page_name == "nauvis_pressure_grace" then
        model.nauvis_pressure_grace(player_index, element)
    end

    if page_name == "rocket_launch_pollution" then
        model.rocket_launch_pollution(player_index, element)
    end

    if page_name == "turrets" then
        model.turrets(player_index, element)
    end

    -- =======================================================
    if page_name == "world_gen_related" then
        model.world_gen_related(player_index, element)
    end

    if page_name == "resources" then
        model.resources(player_index, element)
    end

    if page_name == "mining_scars" then
        model.mining_scars(player_index, element)
    end

    if page_name == "asteroid_variants" then
        model.asteroid_variants(player_index, element)
    end

    if page_name == "fulgora_day_variation" then
        model.fulgora_day_variation(player_index, element)
    end

    if page_name == "repair" then
        model.repair(player_index, element)
    end

    if page_name == "artifacts" then
        model.artifacts(player_index, element)
    end

    if page_name == "knowledge" then
        model.knowledge(player_index, element)
    end

    if page_name == "gate" then
        model.gate(player_index, element)
    end

    -- =======================================================
    if page_name == "new_logistics" then
        model.new_logistics(player_index, element)
    end

    if page_name == "train_progression" then
        model.train_progression(player_index, element)
    end

    if page_name == "em_trains" then
        model.em_trains(player_index, element)
    end

    if page_name == "orbital_scanner" then
        model.orbital_scanner(player_index, element)
    end

    if page_name == "cranes_and_belts" then
        model.cranes_and_belts(player_index, element)
    end

    if page_name == "loaders" then
        model.loaders(player_index, element)
    end

    if page_name == "bots" then
        model.bots(player_index, element)
    end

    -- =======================================================
    if page_name == "new_mechanics" then
        model.new_mechanics(player_index, element)
    end

    if page_name == "beacon_overhaul" then
        model.beacon_overhaul(player_index, element)
    end

    if page_name == "specialised_pipes" then
        model.specialised_pipes(player_index, element)
    end

    if page_name == "induction_matrix" then
        model.induction_matrix(player_index, element)
    end

    if page_name == "teslas_legacy" then
        model.teslas_legacy(player_index, element)
    end

    if page_name == "exotic_stabilizer" then
        model.exotic_stabilizer(player_index, element)
    end

    if page_name == "black_hole" then
        model.black_hole(player_index, element)
    end

    -- =======================================================
    if page_name == "nuclear_fission_and_fusion" then
        model.nuclear_fission_and_fusion(player_index, element)
    end

    if page_name == "fission" then
        model.fission(player_index, element)
    end

    if page_name == "fusion_power" then
        model.fusion_power(player_index, element)
    end

end

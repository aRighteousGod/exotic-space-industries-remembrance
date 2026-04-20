--====================================================================================================
--PRE UPDATES
--====================================================================================================

-- info

ei_mod.stage = "data-updates"
ei_lib = require("lib/lib")

--====================================================================================================
--CONTENT UPDATES
--====================================================================================================

-- reorganize vanilla data

-- set up the branded default map-gen preset
require("scripts/data-updates/vanilla-resources")
-- set science costs to startPrice and set prerequisite to "ei-temp" tech for vanilla techs
require("scripts/data-updates/tech-flattening")
-- set prerequisites of vanilla techs for IE
require("scripts/data-updates/tech-structure")

-- apply vanilla patches
require("scripts/data-updates/vanilla-patches")
require("scripts/data-updates/flammable-fluids")
require("scripts/data-updates/rocket-ammo")
require("scripts/data-updates/railgun-cooling")

-- add metalworks
require("prototypes/metalworks")
--Make sure icon updates get put on top of the overridden solar panel item icons
require("scripts/data-updates/solar-matrix")
-- apply icon patches
require("scripts/data-updates/icon-updates")
-- apply locale patches
require("scripts/data-updates/locale-updates")
-- more asteroids
require("scripts/data-updates/more-asteroids")

--nauvis soundtrack override
require("scripts/data-updates/music-patches")

-- apply mod patches
require("scripts/data-updates/nanobot-patches")
require("scripts/data-updates/fmf-patches")
require("scripts/data-updates/sp-patches")
require("scripts/data-updates/flow-control-patches")
require("scripts/data-updates/teleporters-patches")
require("scripts/data-updates/solar-patches")
require("scripts/data-updates/text-plates-patches")
require("scripts/data-updates/extra-storage-tanks-patches")
require("scripts/data-updates/zeus-wrath")
require("scripts/data-updates/rp-steam-roboports")
require("scripts/data-updates/atan-air-scrubber")
require("scripts/data-updates/atan-ash")
require("scripts/data-updates/pollution-combinator-jamie-fork")
require("scripts/data-updates/disco-science")
require("scripts/data-updates/extinguisher")
require("scripts/data-updates/vehicle-inventory-limiter")
require("scripts/data-updates/accumulator-v2")
require("scripts/data-updates/colorful-biochamber")
require("scripts/data-updates/flamethrower-wagon")
require("scripts/data-updates/doeworks")
require("scripts/data-updates/enhanced-walls")
require("scripts/data-updates/castra-loaders")
require("scripts/data-updates/factorio-plus-loaders")
require("scripts/data-updates/5dim-loaders")
require("scripts/data-updates/advanced-belts-loaders")
require("scripts/data-updates/ultimate-belts-loaders")
require("scripts/data-updates/krastorio-loaders")
require("scripts/data-updates/teslas-legacy")
require("scripts/data-updates/steampunk-lamp")
require("scripts/data-updates/repair-turret")

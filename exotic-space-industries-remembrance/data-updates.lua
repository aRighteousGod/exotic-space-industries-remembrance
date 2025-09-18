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

-- remove vanilla resources from autoplace-controls
require("scripts/data-updates/vanilla_resources")
-- set science costs to startPrice and set prerequisite to "ei-temp" tech for vanilla techs
require("scripts/data-updates/tech_flattening")
-- set prerequisites of vanilla techs for IE
require("scripts/data-updates/tech_structure")

-- apply vanilla patches
require("scripts/data-updates/vanilla_patches")

-- add metalworks
require("prototypes/metalworks")
--Make sure icon updates get put on top of the overridden solar panel item icons
require("scripts/data-updates/solar_matrix")
-- apply icon patches
require("scripts/data-updates/icon_updates")
-- apply locale patches
require("scripts/data-updates/locale_updates")
-- more asteroids
require("scripts/data-updates/more_asteroids")

--nauvis soundtrack override
require("scripts/data-updates/music_patches")

-- apply mod patches
require("scripts/data-updates/nanobot_patches")
require("scripts/data-updates/fmf_patches")
require("scripts/data-updates/sp_patches")
require("scripts/data-updates/flow_control_patches")
require("scripts/data-updates/teleporters_patches")
require("scripts/data-updates/solar_patches")
require("scripts/data-updates/text_plates_patches")
require("scripts/data-updates/extra_storage_tanks_patches")
require("scripts/data-updates/zeus_wrath")
require("scripts/data-updates/rp_steam_roboports")
require("scripts/data-updates/atan_air_scrubber")
require("scripts/data-updates/atan_ash")
require("scripts/data-updates/pollution_combinator_jamie_fork")
require("scripts/data-updates/disco_science")
require("scripts/data-updates/extinguisher")
require("scripts/data-updates/vehicle_inventory_limiter")
require("scripts/data-updates/accumulator_v2")
require("scripts/data-updates/colorful_biochamber")
require("scripts/data-updates/flamethrower_wagon")
require("scripts/data-updates/doeworks")
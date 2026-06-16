--==============================================================================
-- ESIR FILE MAP
-- owns: data-stage prototype aggregation for dark-age
-- loaded_by: exotic-space-industries-remembrance\data.lua
-- cadence: data-stage load
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: data stage reload, prototype cache rebuild
--==============================================================================
-- require all prototypes for dark age here
-- for data stage only

--====================================================================================================
--MAIN CONTENT CODE
--====================================================================================================

-- prototype definitions for buildable entities get seperate files
-- those include prototype definitions for recipes, items, techs and categories

require("lab")
require("burner-assembler")
require("burner-quarry")
require("shotgun-turret")
require("dark-prototypes")
require("mechanical-inserter")
require("camp-fire")
require("burner-surface-harvester")
require("stone-well-pump")
require("burner-offshore-pump")

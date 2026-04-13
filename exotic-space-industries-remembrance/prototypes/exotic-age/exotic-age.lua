--==============================================================================
-- ESIR FILE MAP
-- owns: data-stage prototype aggregation for exotic-age
-- loaded_by: exotic-space-industries-remembrance\data.lua
-- cadence: data-stage load
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: data stage reload, prototype cache rebuild
--==============================================================================
-- require all prototypes for exotic age here
-- for data stage only

--====================================================================================================
--MAIN CONTENT CODE
--====================================================================================================

-- prototype definitions for buildable entities get seperate files
-- those include prototype definitions for recipes, items, techs and categories

-- add general prototypes
require("exotic-prototypes")
-- add black hole
require("black-hole")
-- add holo signs
require("holo")
--==============================================================================
-- ESIR FILE MAP
-- owns: data-stage prototype aggregation for alien-system
-- loaded_by: exotic-space-industries-remembrance\data.lua
-- cadence: data-stage load
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: data stage reload, prototype cache rebuild
--==============================================================================
--====================================================================================================
--MAIN CONTENT CODE
--====================================================================================================

-- prototype definitions for buildable entities get seperate files
-- those include prototype definitions for recipes, items, techs and categories

-- add alien beacon
require("alien-beacon")
-- add alien stabilizer
require("alien-stabilizer")
-- add gate
require("gate")
-- add crystal accumulator
require("crystal-accumulator")
-- add farsation
require("farstation")
-- add other
require("alien-structures")

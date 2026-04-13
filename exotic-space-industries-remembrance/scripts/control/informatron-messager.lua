--==============================================================================
-- ESIR FILE MAP
-- owns: research-finished messaging
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: research-finished
-- forwarded_events: notify, on_research_finished
-- storage_roots: none
-- gui_ids: exotic-industries.message-informatron
-- remote_interfaces: none
-- rebuild_on: progression text changes
--==============================================================================
local model = {}

--====================================================================================================
--INFORMATRON MESSAGER
--====================================================================================================

function model.notify(page)

    -- notfy for this page in the informatron

    if page == "black-hole" then
        game.print({"exotic-industries.message-informatron", "Black hole generators"})
    end

end

--HANDLERS
------------------------------------------------------------------------------------------------------

function model.on_research_finished(event)

    local research = event.research

    -- research of LuaTechnology

end

return model
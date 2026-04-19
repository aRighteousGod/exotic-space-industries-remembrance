--==============================================================================
-- ESIR FILE MAP
-- owns: research-finished messaging
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: research-finished
-- forwarded_events: notify, on_research_finished, on_scripted_research_burst
-- storage_roots: storage.ei.informatron_messager
-- gui_ids: exotic-industries.message-informatron
-- remote_interfaces: none
-- rebuild_on: progression text changes
--==============================================================================
local model = {}

local PAGE_RESEARCH = {
    ["ei-black-hole"] = {{
        page = "black-hole",
        caption = {"exotic-industries-informatron.title_black_hole"},
    }},
    ["ei-cooler"] = {{
        page = "specialised_pipes",
        caption = {"exotic-industries-informatron.title_specialised_pipes"},
    }},
    ["ei-tank"] = {{
        page = "flammable_ruptures",
        caption = {"exotic-industries-informatron.title_flammable_ruptures"},
    }},
    ["planet-discovery-vulcanus"] = {
        {
            page = "auric_fumarole",
            caption = {"exotic-industries-informatron.title_auric_fumarole"},
        },
        {
            page = "asteroid_variants",
            caption = {"exotic-industries-informatron.title_asteroid_variants"},
        },
    },
    ["planet-discovery-fulgora"] = {
        {
            page = "fulgora_day_variation",
            caption = {"exotic-industries-informatron.title_fulgora_day_variation"},
        },
        {
            page = "asteroid_variants",
            caption = {"exotic-industries-informatron.title_asteroid_variants"},
        },
    },
    ["planet-discovery-gleba"] = {{
        page = "asteroid_variants",
        caption = {"exotic-industries-informatron.title_asteroid_variants"},
    }},
    ["planet-discovery-aquilo"] = {{
        page = "asteroid_variants",
        caption = {"exotic-industries-informatron.title_asteroid_variants"},
    }},
}

local function ensure_state()
    storage.ei = storage.ei or {}
    storage.ei.informatron_messager = storage.ei.informatron_messager or {}

    local state = storage.ei.informatron_messager
    state.notified_by_force = state.notified_by_force or {}
    return state
end

local function mark_notified(force, page)
    local state = ensure_state()
    local force_index = force and tonumber(force.index) or nil
    if not force_index or not page then
        return false
    end

    local notified_pages = state.notified_by_force[force_index]
    if not notified_pages then
        notified_pages = {}
        state.notified_by_force[force_index] = notified_pages
    end

    if notified_pages[page] then
        return false
    end

    notified_pages[page] = true
    return true
end

--====================================================================================================
--INFORMATRON MESSAGER
--====================================================================================================

function model.notify(notification, force)
    local caption = notification and notification.caption or nil
    if not (notification and notification.page and caption) then
        return false
    end

    if force and force.valid and force.print then
        force.print({"exotic-industries.message-informatron", caption})
    else
        game.print({"exotic-industries.message-informatron", caption})
    end

    return true
end

local function notify_once(force, notification)
    local page = notification and notification.page or nil
    if not (page and mark_notified(force, page)) then
        return false
    end

    return model.notify(notification, force)
end

--HANDLERS
------------------------------------------------------------------------------------------------------

function model.on_research_finished(event)
    local research = event and event.research or nil
    local notifications = research and PAGE_RESEARCH[research.name] or nil
    if not (research and research.force and notifications) then
        return false
    end

    local did_notify = false
    for _, notification in ipairs(notifications) do
        did_notify = notify_once(research.force, notification) or did_notify
    end

    return did_notify
end

function model.on_scripted_research_burst(force)
    if not (force and force.valid and force.technologies) then
        return false
    end

    local did_notify = false
    for research_name, notifications in pairs(PAGE_RESEARCH) do
        local technology = force.technologies[research_name]
        if technology and technology.researched then
            for _, notification in ipairs(notifications) do
                did_notify = notify_once(force, notification) or did_notify
            end
        end
    end

    if did_notify then
        return true
    end

    return false
end

return model

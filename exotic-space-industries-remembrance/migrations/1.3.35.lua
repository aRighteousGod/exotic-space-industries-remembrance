local FINITE_TECH = "electric-weapons-damage-4"
local REPEATABLE_TECH = "electric-weapons-damage-5"
local LEGACY_REPEATABLE_LEVEL = 4
local NEW_REPEATABLE_LEVEL = 5

local function get_technology(force, name)
    if not force or not force.valid or not force.technologies then
        return nil
    end

    return force.technologies[name]
end

local function technology_level(technology, fallback)
    local level = tonumber(technology and technology.level) or fallback
    if level < fallback then
        return fallback
    end

    return math.floor(level)
end

local function technology_progress(technology)
    if not technology then
        return 0
    end

    local ok, progress = pcall(function()
        return technology.saved_progress
    end)

    if not ok then
        return 0
    end

    progress = tonumber(progress) or 0
    if progress < 0 then
        return 0
    end
    if progress >= 1 then
        return 0.999999
    end

    return progress
end

local function set_technology_progress(technology, progress)
    if not technology then
        return
    end

    pcall(function()
        technology.saved_progress = progress
    end)
end

local function current_research_name(force)
    local ok, current = pcall(function()
        return force.current_research
    end)

    if ok and current then
        return current.name
    end

    return nil
end

local function active_repeatable_research_progress(force)
    if current_research_name(force) ~= REPEATABLE_TECH then
        return false, 0
    end

    return true, tonumber(force.research_progress) or 0
end

local function restore_repeatable_research_progress(force, was_active, progress)
    if not was_active then
        return
    end

    if current_research_name(force) ~= REPEATABLE_TECH then
        return
    end

    pcall(function()
        force.research_progress = progress
    end)
end

local function replace_queued_research(force, from_name, to_technology)
    local ok, queue = pcall(function()
        return force.research_queue
    end)

    if not ok or type(queue) ~= "table" or not to_technology then
        return false
    end

    local changed = false
    local inserted_replacement = false
    local rewritten = {}

    for _, technology in ipairs(queue) do
        if technology and technology.name == from_name then
            if not inserted_replacement then
                rewritten[#rewritten + 1] = to_technology
                inserted_replacement = true
            end
            changed = true
        else
            rewritten[#rewritten + 1] = technology
        end
    end

    if changed then
        pcall(function()
            force.research_queue = rewritten
        end)
    end

    return changed
end

local function move_active_research_to_finite_gate(force, finite, repeatable)
    local active_progress = 0
    local active_was_repeatable = current_research_name(force) == REPEATABLE_TECH

    if active_was_repeatable then
        active_progress = tonumber(force.research_progress) or 0
    end

    local saved_progress = technology_progress(repeatable)
    if saved_progress > technology_progress(finite) then
        set_technology_progress(finite, saved_progress)
    end
    set_technology_progress(repeatable, 0)

    local replaced_queue = replace_queued_research(force, REPEATABLE_TECH, finite)
    if active_was_repeatable and not replaced_queue then
        pcall(function()
            force.current_research = finite
        end)
    end

    if active_was_repeatable then
        pcall(function()
            force.research_progress = active_progress
        end)
    end
end

for _, force in pairs(game.forces) do
    local finite = get_technology(force, FINITE_TECH)
    local repeatable = get_technology(force, REPEATABLE_TECH)

    if finite and repeatable then
        local migrated_level = technology_level(repeatable, NEW_REPEATABLE_LEVEL)

        if repeatable.researched then
            local completed_legacy_levels = math.max(1, migrated_level - LEGACY_REPEATABLE_LEVEL)
            local active_was_repeatable, active_progress = active_repeatable_research_progress(force)
            local saved_progress = technology_progress(repeatable)
            finite.researched = true

            -- LuaTechnology.level is the next level to research. The completed old
            -- repeatable level 4 becomes finite level 4, so progress toward old
            -- level N should remain progress toward new level N.
            if completed_legacy_levels == 1 then
                repeatable.level = NEW_REPEATABLE_LEVEL
                repeatable.researched = false
            else
                repeatable.level = NEW_REPEATABLE_LEVEL + completed_legacy_levels - 1
            end

            set_technology_progress(repeatable, saved_progress)
            restore_repeatable_research_progress(force, active_was_repeatable, active_progress)
        else
            move_active_research_to_finite_gate(force, finite, repeatable)
            repeatable.level = NEW_REPEATABLE_LEVEL
            repeatable.researched = false
        end
    end
end

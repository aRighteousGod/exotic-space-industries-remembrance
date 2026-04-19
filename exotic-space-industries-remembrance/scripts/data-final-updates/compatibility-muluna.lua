if not mods["planet-muluna"] then
    return
end

local interstellar_science = data.raw.technology["interstellar-science-pack"]
if not interstellar_science then
    return
end

-- Muluna expects this tech to stay trigger-based; ESIR's generic final passes convert it into
-- a normal science-pack technology otherwise, which deadlocks Aquilo behind cryogenic science.
local restored_prerequisites = {}
for _, prerequisite in ipairs({
    "low-density-space-platform-foundation",
    "muluna-telescope",
    "automation-3",
}) do
    if data.raw.technology[prerequisite] then
        table.insert(restored_prerequisites, prerequisite)
    end
end

interstellar_science.prerequisites = restored_prerequisites
interstellar_science.unit = nil
interstellar_science.research_trigger = {
    type = "craft-item",
    item = "low-density-space-platform-foundation",
    count = 10,
}
interstellar_science.enabled = true
interstellar_science.visible_when_disabled = true

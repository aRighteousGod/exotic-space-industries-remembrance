--==============================================================================
-- ESIR FILE MAP
-- owns: native 2.1 quality inheritance for every authored rolling-stock tier
-- loaded_by: data-final-fixes.lua after all ESIR rolling-stock definitions
-- cadence: final data pass only
-- storage_roots: none
--==============================================================================
-- blueprint: .codex/esir/blueprints/transport-quality.md#contract

-- Quality enables these on the native bodies during data-updates, after some
-- ESIR definitions have already been copied. The user approved the same native
-- scaling for every ESIR train tier. Inherit flags, not frozen bonus numbers.
---@type {kind: string, field: string, names: string[]}[]
local families = {
    {kind = "locomotive", field = "quality_affects_max_speed", names = {
        "ei-steam-basic-locomotive", "ei-steam-basic-locomotive-placement-entity",
        "ei-steam-advanced-locomotive", "ei-nuclear-locomotive", "ei_em-locomotive",
    }},
    {kind = "cargo-wagon", field = "quality_affects_inventory_size", names = {
        "ei-steam-basic-wagon", "ei-steam-advanced-wagon", "ei-advanced-cargo-wagon", "ei_em-cargo-wagon",
    }},
    {kind = "fluid-wagon", field = "quality_affects_capacity", names = {
        "ei-steam-advanced-fluid-wagon", "ei-advanced-fluid-wagon", "ei_em-fluid-wagon",
    }},
}
for _, family in ipairs(families) do
    local prototypes = data.raw[family.kind]
    local native = prototypes and prototypes[family.kind]
    if native then
        for _, name in ipairs(family.names) do
            if prototypes[name] then prototypes[name][family.field] = native[family.field] end
        end
    end
end

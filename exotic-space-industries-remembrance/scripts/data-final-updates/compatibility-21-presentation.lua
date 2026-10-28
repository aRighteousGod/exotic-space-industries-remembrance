--==============================================================================
-- ESIR FILE MAP
-- owns: bounded 2.1 presentation and generator-admission repairs for optional mods
-- loaded_by: data-final-fixes.lua after canonical presentation and generated bodies
-- cadence: final data pass only
-- storage_roots: none
--==============================================================================
-- blueprint: .codex/esir/blueprints/entity-presentation.md#contract
-- blueprint-ref: .codex/esir/blueprints/entity-presentation.md#optional-copies
if mods["tenebris-prime"] then
    -- Tenebris copies machines before ESIR's final graphics repairs. Refresh
    -- their inherited graphics while retaining its own glow, void energy,
    -- crafting-speed multiplier, surface restrictions and prototype identities.
    for _, prototypes in pairs(data.raw) do
        for name, copy in pairs(prototypes) do
            local base_name = copy.bioluminescent and name:match("^bioluminescent%-(ei%-.+)$")
            local base = base_name and prototypes[base_name]
            if base and base.graphics_set then
                copy.graphics_set = table.deepcopy(base.graphics_set)
            end
        end
    end
end

if mods["corrundum"] then
    -- The published red engine still carries its 100 C admission floor on a
    -- removed FluidBox field. Conversion efficiency uses a separate maximum.
    local generator = data.raw.generator["red-steam-engine"]
    if generator and generator.fluid_box then
        for _, bound in ipairs({"minimum", "maximum"}) do
            local old_key, new_key = bound .. "_temperature", bound .. "_input_temperature"
            if generator.fluid_box[old_key] ~= nil then
                if generator[new_key] == nil then generator[new_key] = generator.fluid_box[old_key] end
                generator.fluid_box[old_key] = nil
            end
        end
    end
end

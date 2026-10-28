--==============================================================================
-- ESIR FILE MAP
-- owns: zero-frequency resource noise compatibility for native 2.1 save admission
-- loaded_by: data-final-fixes.lua
-- cadence: data final fixes only
-- storage_roots: none
--==============================================================================
-- blueprint: .codex/esir/blueprints/map-settings.md#contract
-- blueprint-ref: .codex/esir/blueprints/map-settings.md#resource-off
-- The engine compiles imported map settings before Lua migrations. Guard the
-- native helper's two zero denominators here; retain every positive-frequency
-- expression and the original saved Off controls, including zero richness.
local resource_noise = data.raw["noise-function"].resource_autoplace_all_patches
if resource_noise then
    local starting = resource_noise.local_expressions or {}
    local regular = (resource_noise.local_functions or {}).regular_spot_quantity_base_at
    if regular and starting.starting_area_spot_quantity == "starting_amount / starting_patches_split / frequency_multiplier"
        and regular.expression == "1000000 / base_spots_per_km2 / frequency_multiplier * regular_density_at(distance)" then
        starting.starting_area_spot_quantity =
            "starting_amount / starting_patches_split / if(frequency_multiplier == 0, 1, frequency_multiplier)"
        regular.expression =
            "1000000 / base_spots_per_km2 / if(frequency_multiplier == 0, 1, frequency_multiplier) * regular_density_at(distance)"
        resource_noise.expression = "if(frequency_multiplier == 0, 0, "..resource_noise.expression..")"
    else
        log("ESIR resource-Off guard skipped a replaced resource_autoplace_all_patches helper; compatibility needs review.")
    end
end

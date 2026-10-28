--==============================================================================
-- ESIR FILE MAP
-- owns: frozen Electric Flying Enemies 0.1.9 generation closure for saved surfaces
-- loaded_by: scripts/data-final-updates/planet-enemies.lua
-- cadence: data stage only
-- dependency_sources: Electric_flying_enemies 0.1.9 prototypes/enemy-autoplace.lua (preserved baseline)
--==============================================================================
-- blueprint: .codex/esir/blueprints/planet-enemies.md#contract
-- blueprint-ref: .codex/esir/blueprints/planet-enemies.md#seed-compatibility
-- Derived from mferrari's Electric Flying Enemies 0.1.9. Keep symbolic ee_*
-- references: saved per-surface overrides must still resolve inside the closure.
local definitions = {
    radius = {type = "noise-expression", name = "ei-legacy20-electric-radius",
        expression = "sqrt(var('control:electric_enemies:size')) * (10 + 2 * enemy_base_intensity)"},
    frequency = {type = "noise-expression", name = "ei-legacy20-electric-frequency",
        expression = "(0.00003 + 0.000005 * enemy_base_intensity) * var('control:electric_enemies:frequency')"},
    probability = {type = "noise-expression", name = "ei-legacy20-electric-probability",
        expression = "spot_noise{x = x, y = y,\z
            density_expression = spot_quantity_expression * max(0, ee_enemy_base_frequency)/2,\z
            spot_quantity_expression = spot_quantity_expression, spot_radius_expression = spot_radius_expression,\z
            spot_favorability_expression = 1, seed0 = map_seed, seed1 = 654733, region_size = 512,\z
            candidate_point_count = 100, hard_region_target_quantity = 0, basement_value = -1000,\z
            maximum_spot_basement_radius = 128} +\z
            (blob(1/8, 1) + blob(1/24, 1) + blob(1/64, 2) - 0.5) * spot_radius_expression / 150 *\z
            (0.1 + 0.9 * clamp(distance / 3000, 0, 1)) - 0.3 + min(0, 20 / starting_area_radius * distance - 20)",
        local_expressions = {spot_radius_expression = "max(0, ee_enemy_base_radius)",
            spot_quantity_expression = "pi/90 * spot_radius_expression ^ 3"},
        local_functions = {blob = {parameters = {"input_scale", "output_scale"},
            expression = "basis_noise{x = x, y = y, seed0 = map_seed, seed1 = 654733, input_scale = input_scale, output_scale = output_scale}"}}},
    autoplace = {type = "noise-function", name = "ei_legacy20_electric_autoplace_base",
        parameters = {"distance_factor", "seed"},
        expression = "random_penalty{x = x + seed, y = y,\z
            source = min(ee_enemy_base_probability * max(0, 1 + 0.004 * distance_factor *\z
            (-312 * distance_factor - starting_area_radius + distance)), 0.25 + distance_factor * 0.05), amplitude = 0.1}"},
}
for _, definition in pairs(definitions) do data:extend{definition} end
for _, suffix in ipairs({"radius", "frequency"}) do
    if not data.raw["noise-expression"]["ee_enemy_base_" .. suffix] then
        local fallback = table.deepcopy(definitions[suffix])
        fallback.name = "ee_enemy_base_" .. suffix
        data:extend{fallback}
    end
end
for index, name in ipairs({"flying-electric-unit-spawner", "walker-electric-unit-spawner"}) do
    data:extend{{type = "noise-expression", name = "ei-legacy20-electric-" .. name,
        expression = "ei_legacy20_electric_autoplace_base(0," .. (46864 + index) .. ")"}}
end
return definitions

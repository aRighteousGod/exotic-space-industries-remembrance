--==============================================================================
-- ESIR FILE MAP
-- owns: one-time Gaia robot-cost, recycling and native discovery travel unlocks
-- loaded_by: Factorio migration loader
-- cadence: ESIR 1.4.0 migration only
-- storage_roots: reads storage.gaia_surfaces and storage.ei.reforge_gaia
--==============================================================================
-- blueprint: .codex/esir/blueprints/gaia-and-alien-systems.md#contract
-- blueprint-ref: .codex/esir/blueprints/gaia-and-alien-systems.md#lifecycle
-- 2.0 derived robot cost from gravity/pressure. 2.1 makes that an independent
-- property. Read each saved surface, including legacy/custom Gaia, rather than
-- imposing the canonical planet's 0.96875 value on all existing surfaces.
local seen = {}
local function preserve_robot_energy(surface)
    if not (surface and surface.valid) or seen[surface.index] then return end
    seen[surface.index] = true
    local pressure = surface.get_property("pressure")
    if pressure > 0 then
        surface.set_property("robot-energy-usage", 100 * surface.get_property("gravity") / pressure)
    end
end
local gaia = game.planets.gaia
preserve_robot_energy(gaia and gaia.surface)
for _, name in ipairs({"gaia", "Gaia", "gaia-reforge-staging"}) do preserve_robot_energy(game.surfaces[name]) end
for name, enabled in pairs(storage.gaia_surfaces or {}) do
    if enabled then preserve_robot_energy(game.surfaces[name]) end
end
local reforge = storage.ei and storage.ei.reforge_gaia
if reforge and reforge.staging_surface_name then preserve_robot_energy(game.surfaces[reforge.staging_surface_name]) end

-- The native Recycler generator now locks its generated recipes behind research.
-- Restore only unlocks from already researched recycling; preserve other mods'
-- force adjustments and any recipes deliberately enabled before the upgrade.
for _, force in pairs(game.forces) do
    local technology = force.technologies.recycling
    if technology and technology.researched then
        for _, effect in pairs(technology.prototype.effects) do
            if effect.type == "unlock-recipe" and force.recipes[effect.recipe] then force.recipes[effect.recipe].enabled = true end
        end
    end
    -- blueprint-ref: .codex/esir/blueprints/research-and-progression.md#platform-travel
    -- Adopt native travel effects from already researched discoveries. Rocket
    -- silo alone has no such effect. Respect compatible mods' research grants
    -- without resetting unrelated force bonuses or technology effects.
    for _, researched in pairs(force.technologies) do
        if researched.researched then
            for _, effect in pairs(researched.prototype.effects) do
                if effect.type == "unlock-travel-to-space-platforms" and effect.modifier then
                    force.unlock_travel_to_space_platforms = true
                end
            end
        end
    end
end

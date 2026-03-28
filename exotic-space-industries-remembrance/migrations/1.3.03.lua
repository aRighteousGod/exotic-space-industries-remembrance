local gaia_planet = game.planets["gaia"]
if not gaia_planet then
    return
end

-- Older saves on this branch can already contain both the live "gaia" planet
-- and the hidden legacy "Gaia" placeholder. Keep compatibility at the surface
-- association level instead of renaming the legacy space-location onto "gaia".
local gaia_surface = gaia_planet.surface
if gaia_surface and gaia_surface.valid then
    return
end

local legacy_surface = game.surfaces["Gaia"]
if not legacy_surface or not legacy_surface.valid then
    return
end

gaia_planet:associate_surface(legacy_surface)

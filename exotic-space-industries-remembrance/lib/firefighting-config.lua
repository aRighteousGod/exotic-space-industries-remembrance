-- Shared prototype/runtime identities and balance for ESIR firefighting.
local model = {
    gun = "ei-extinguisher",
    ammo = "ei-extinguisher-ammo",
    turret = "ei-water-turret",
    power = "ei-water-turret-power",
    handheld_effect = "ei-extinguisher-impact",
    protect_effect = "ei-water-suppression-protected",
    all_effect = "ei-water-suppression-all",
    check_setting = "ei-water-turret-fire-check-seconds",
    range = 24,
    radius = 1.5,
    pulse_water = 15,
    pulse_ticks = 60,
    power_ticks = 15,
    power_start = 40000,
    power_stop = 30000,
    fire_budget = 32,
    -- Shared with the 3x3 model's measured tip, projected by the Factorio preset.
    muzzle_length = 2.5962124,
    muzzle_height = 1.3620957621,
}
model.modes = {"enemy-first", "fire-first", "fire-only"}
model.thermal_fires = {
    ["fire-flame-on-tree"] = true,
    ["ei-oil-fire-flame"] = true,
    ["ei-oil-platform-fire-flame"] = true,
    ["ei-gas-fire-flame"] = true,
    ["ei-gas-platform-fire-flame"] = true,
    ["ei-exotic-fire-flame"] = true,
    ["ei-exotic-platform-fire-flame"] = true,
}
return model

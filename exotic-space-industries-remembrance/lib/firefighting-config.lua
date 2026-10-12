-- blueprint: .codex/esir/blueprints/firefighting-and-water-turret.md#contract
-- Shared prototype/runtime identities and balance for ESIR firefighting.
local model = {
    gun = "ei-extinguisher",
    ammo = "ei-extinguisher-ammo",
    turret = "ei-water-turret",
    power = "ei-water-turret-power",
    handheld_effect = "ei-extinguisher-impact",
    protect_effect = "ei-water-suppression-protected",
    all_effect = "ei-water-suppression-all",
    targeting_setting = "ei-water-turret-fire-targeting",
    created_effect = "ei-water-fire-created",
    range = 24,
    radius = 1.5,
    pulse_water = 15,
    pulse_ticks = 60,
    rotation_speed = 0.02,
    power_ticks = 15,
    power_start = 40000,
    power_stop = 30000,
    hot_budget = 32,
    cold_slices = 8,
    slice_size = 64,
    wake_budget = 32,
    chunk_size = 32,
    -- Shared with the 3x3 model's measured tip, projected by the Factorio preset.
    muzzle_length = 2.5962124,
    muzzle_height = 1.3620957621,
}
model.modes = {"enemy-first", "fire-first", "fire-only"}
model.thermal_fires = {
    ["ei-ecology-fire"] = true,
    ["fire-flame-on-tree"] = true,
    ["ei-oil-fire-flame"] = true,
    ["ei-oil-platform-fire-flame"] = true,
    ["ei-gas-fire-flame"] = true,
    ["ei-gas-platform-fire-flame"] = true,
    ["ei-exotic-fire-flame"] = true,
    ["ei-exotic-platform-fire-flame"] = true,
}
return model

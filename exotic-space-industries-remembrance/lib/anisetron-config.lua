-- blueprint: .codex/esir/blueprints/anisetron.md#contract
-- Shared data/runtime tuning. A native shot pays for the entire burst upfront.
return {
    vehicle = "ei-anisetron",
    ammo_damage_category = "ei-anisetron-crystal",
    charge_effect = "ei-anisetron-charge",
    duration_ticks = 20 * 60,
    contact_ticks = 12,
    sweep_ticks = 12,
    -- Like the Lance, retain living targets and unwrap angular waypoints.
    -- Contact opportunities spent acquiring a replacement are not banked.
    acquisition = {degrees_per_tick = 6, minimum_ticks = 8, maximum_ticks = 60},
    contact_hold_ticks = 12,
    arc_degrees = 120,
    range = 30, -- Historical v1/v2 and the current facade's center-distance limit.
    crown_range = require("lib/singularity-lance-config").range,
    contact_damage = 240,
    -- Version-one paid records retain contact_damage and their frontal sweep.
    contract_version = 3,
    crown_damage = 320,
    facade_damage = 160,
    crown_arc_degrees = 360,
    -- Reserved timing hook: zero keeps this version at 20 seconds for all qualities.
    -- Extended paid bursts queue in order; a retrigger never discards paid ammo.
    duration_quality_bonus_per_level = 0,
    beam_scale_factor = 0.6,
    crown_beam_scale_factor = 1.2,
}

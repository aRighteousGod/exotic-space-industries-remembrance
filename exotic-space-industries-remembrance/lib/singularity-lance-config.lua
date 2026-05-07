--====================================================================================================
--SINGULARITY LANCE VISUAL FIDELITY CONFIG
--====================================================================================================

local ei_lib = require("lib/lib")
local singularity_lance_config = {}

singularity_lance_config.setting_name = "ei-singularity-lance-visual-fidelity"
singularity_lance_config.default_fidelity = "standard"
singularity_lance_config.allowed_values = {"lean", "standard", "cinematic", "maximal", "unbounded"}
singularity_lance_config.damage_type = "laser"
singularity_lance_config.ammo_damage_category = "ei-singularity-lance"
singularity_lance_config.direct_damage = 500
singularity_lance_config.splash_damage = 125
singularity_lance_config.splash_radius = 1.5
singularity_lance_config.range = 85
singularity_lance_config.attack_cooldown = 1
singularity_lance_config.ticks_per_second = 60
singularity_lance_config.shot_energy_mj = 125
singularity_lance_config.input_flow_limit_mw = 400
singularity_lance_config.drain_mw = 20
singularity_lance_config.energy_buffer_capacity = "700MJ"
singularity_lance_config.energy_input_flow_limit = "400MW"
singularity_lance_config.energy_drain = "20MW"
singularity_lance_config.sustained_shots_per_second =
    singularity_lance_config.shot_energy_mj > 0
    and math.max(singularity_lance_config.input_flow_limit_mw - singularity_lance_config.drain_mw, 0) /
        singularity_lance_config.shot_energy_mj
    or 0
singularity_lance_config.burst_shots_per_second =
    singularity_lance_config.ticks_per_second / singularity_lance_config.attack_cooldown
singularity_lance_config.direct_burst_dps =
    singularity_lance_config.direct_damage * singularity_lance_config.burst_shots_per_second
singularity_lance_config.direct_sustained_dps =
    singularity_lance_config.direct_damage * singularity_lance_config.sustained_shots_per_second

local presets = {
    lean = {
        slice_base = 1,
        slice_perf_multiplier = 0.30,
        slice_min = 3,
        slice_max = 5,
        visual_job_cap_multiplier = 1,
        visual_job_cap_min = 4,
        visual_job_cap_max = 36,
        update_limit_ratio = 0.08,
        impact_witness_limit_ratio = 0.25,
        impact_witness_cap_min = 1,
        impact_witness_cap_max = 18,
        beam_duration_ticks = 9,
        impact_witness_duration_ticks = 5,
        impact_witness_length = 1.0,
        impact_effect_delay_ticks = 1,
        visual_job_ttl = 120,
        min_shot_interval = 12,
        hit_fire_unit_interval = 12,
        hit_fire_global_interval = 4,
        fire_sticker_global_interval = 6,
        scorchmark_unit_interval = 90,
        scorchmark_global_interval = 20,
        fire_sticker_duration = 10,
        hit_fire_duration = 14,
        scorchmark_duration = 60 * 30,
        visual_beam_width = 1.8,
        visual_beam_light_intensity = 0.60,
        visual_beam_light_size = 24,
        impact_beam_width = 2.6,
        impact_beam_light_intensity = 0.80,
        impact_beam_light_size = 36,
        hit_fire_light_intensity = 0.50,
        hit_fire_light_size = 8,
        start_sound_cap = 2,
        middle_sound_cap = 2,
        end_sound_cap = 2,
        impact_sound_cap = 2,
    },
    standard = {
        slice_base = 2,
        slice_perf_multiplier = 0.50,
        slice_min = 3,
        slice_max = 9,
        visual_job_cap_multiplier = 2,
        visual_job_cap_min = 6,
        visual_job_cap_max = 72,
        update_limit_ratio = 0.10,
        impact_witness_limit_ratio = 0.50,
        impact_witness_cap_min = 1,
        impact_witness_cap_max = 36,
        beam_duration_ticks = 14,
        impact_witness_duration_ticks = 8,
        impact_witness_length = 1.25,
        impact_effect_delay_ticks = 2,
        visual_job_ttl = 240,
        min_shot_interval = 8,
        hit_fire_unit_interval = 6,
        hit_fire_global_interval = 2,
        fire_sticker_global_interval = 2,
        scorchmark_unit_interval = 30,
        scorchmark_global_interval = 8,
        fire_sticker_duration = 18,
        hit_fire_duration = 30,
        scorchmark_duration = 60 * 60 * 2,
        visual_beam_width = 2.6,
        visual_beam_light_intensity = 0.85,
        visual_beam_light_size = 36,
        impact_beam_width = 3.6,
        impact_beam_light_intensity = 1.15,
        impact_beam_light_size = 54,
        hit_fire_light_intensity = 0.88,
        hit_fire_light_size = 13,
        start_sound_cap = 3,
        middle_sound_cap = 3,
        end_sound_cap = 3,
        impact_sound_cap = 3,
    },
    cinematic = {
        slice_base = 3,
        slice_perf_multiplier = 0.65,
        slice_min = 5,
        slice_max = 12,
        visual_job_cap_multiplier = 3,
        visual_job_cap_min = 10,
        visual_job_cap_max = 108,
        update_limit_ratio = 0.15,
        impact_witness_limit_ratio = 0.75,
        impact_witness_cap_min = 2,
        impact_witness_cap_max = 72,
        beam_duration_ticks = 18,
        impact_witness_duration_ticks = 12,
        impact_witness_length = 1.5,
        impact_effect_delay_ticks = 2,
        visual_job_ttl = 300,
        min_shot_interval = 5,
        hit_fire_unit_interval = 4,
        hit_fire_global_interval = 1,
        fire_sticker_global_interval = 1,
        scorchmark_unit_interval = 20,
        scorchmark_global_interval = 5,
        fire_sticker_duration = 30,
        hit_fire_duration = 45,
        scorchmark_duration = 60 * 60 * 4,
        visual_beam_width = 3.3,
        visual_beam_light_intensity = 1.00,
        visual_beam_light_size = 48,
        impact_beam_width = 4.4,
        impact_beam_light_intensity = 1.35,
        impact_beam_light_size = 66,
        hit_fire_light_intensity = 1.00,
        hit_fire_light_size = 18,
        start_sound_cap = 4,
        middle_sound_cap = 4,
        end_sound_cap = 4,
        impact_sound_cap = 4,
    },
    maximal = {
        slice_base = 4,
        slice_perf_multiplier = 1.00,
        slice_min = 7,
        slice_max = 18,
        visual_job_cap_multiplier = 6,
        visual_job_cap_min = 18,
        visual_job_cap_max = 240,
        update_limit_ratio = 0.25,
        impact_witness_limit_ratio = 1.50,
        impact_witness_cap_min = 7,
        impact_witness_cap_max = 999,
        beam_duration_ticks = 24,
        impact_witness_duration_ticks = 16,
        impact_witness_length = 2.0,
        impact_effect_delay_ticks = 2,
        visual_job_ttl = 600,
        min_shot_interval = 1,
        hit_fire_unit_interval = 0,
        hit_fire_global_interval = 0,
        fire_sticker_global_interval = 0,
        scorchmark_unit_interval = 1,
        scorchmark_global_interval = 0,
        fire_sticker_duration = 60,
        hit_fire_duration = 90,
        scorchmark_duration = 60 * 60 * 10,
        visual_beam_width = 4.0,
        visual_beam_light_intensity = 1.20,
        visual_beam_light_size = 72,
        impact_beam_width = 5.2,
        impact_beam_light_intensity = 1.55,
        impact_beam_light_size = 96,
        hit_fire_light_intensity = 1.20,
        hit_fire_light_size = 24,
        start_sound_cap = 6,
        middle_sound_cap = 6,
        end_sound_cap = 6,
        impact_sound_cap = 6,
    },
    unbounded = {
        slice_base = 8,
        slice_perf_multiplier = 2.00,
        slice_min = 10,
        slice_max = nil,
        visual_job_cap_unbounded = true,
        update_limit_unbounded = true,
        drain_pending_work = true,
        impact_witness_cap_unbounded = true,
        beam_duration_ticks = 36,
        impact_witness_duration_ticks = 24,
        impact_witness_length = 2.4,
        impact_effect_delay_ticks = 2,
        visual_job_ttl = 60 * 30,
        min_shot_interval = 0,
        hit_fire_unit_interval = 0,
        hit_fire_global_interval = 0,
        fire_sticker_global_interval = 0,
        scorchmark_unit_interval = 0,
        scorchmark_global_interval = 0,
        fire_sticker_duration = 60 * 2,
        hit_fire_duration = 60 * 3,
        scorchmark_duration = 60 * 60 * 24,
        visual_beam_width = 5.0,
        visual_beam_light_intensity = 1.45,
        visual_beam_light_size = 108,
        impact_beam_width = 6.5,
        impact_beam_light_intensity = 1.85,
        impact_beam_light_size = 144,
        hit_fire_light_intensity = 1.50,
        hit_fire_light_size = 32,
        start_sound_cap = nil,
        middle_sound_cap = nil,
        end_sound_cap = nil,
        impact_sound_cap = nil,
    },
}

singularity_lance_config.presets = presets

local function normalize_fidelity(value)
    if presets[value] then
        return value
    end

    return singularity_lance_config.default_fidelity
end

local function read_startup_fidelity()
    local setting = settings
        and settings.startup
        and settings.startup[singularity_lance_config.setting_name]

    return normalize_fidelity(setting and setting.value)
end

local function normalize_preset(preset_or_name)
    if type(preset_or_name) == "table" then
        return preset_or_name
    end

    return presets[normalize_fidelity(preset_or_name)] or presets[singularity_lance_config.default_fidelity]
end

local function normalize_perf(perf)
    return ei_lib.clamp_number(perf, 1, 100, 1)
end

local function clamp_optional_max(value, minimum, maximum)
    return ei_lib.clamp_integer(value, minimum, maximum, minimum)
end

function singularity_lance_config.startup_setting_definition()
    return {
        name = singularity_lance_config.setting_name,
        type = "string-setting",
        setting_type = "startup",
        default_value = singularity_lance_config.default_fidelity,
        allowed_values = ei_lib.copy_array(singularity_lance_config.allowed_values),
        order = "b5a",
    }
end

function singularity_lance_config.resolve(fidelity)
    local normalized = normalize_fidelity(fidelity or read_startup_fidelity())
    return ei_lib.copy_preset(normalized, presets[normalized], singularity_lance_config.setting_name)
end

function singularity_lance_config.get_slice_count(preset_or_name, perf)
    local preset = normalize_preset(preset_or_name)
    perf = normalize_perf(perf)
    return clamp_optional_max(
        math.floor(preset.slice_base + perf * preset.slice_perf_multiplier),
        preset.slice_min,
        preset.slice_max
    )
end

function singularity_lance_config.get_visual_job_cap(preset_or_name, perf)
    local preset = normalize_preset(preset_or_name)
    if preset.visual_job_cap_unbounded then
        return nil
    end

    perf = normalize_perf(perf)
    return ei_lib.clamp(
        math.floor(perf * preset.visual_job_cap_multiplier),
        preset.visual_job_cap_min,
        preset.visual_job_cap_max
    )
end

function singularity_lance_config.get_update_limit_cap(preset_or_name, perf)
    local preset = normalize_preset(preset_or_name)
    if preset.update_limit_unbounded then
        return nil
    end

    perf = normalize_perf(perf)
    return math.max(1, math.floor(perf * preset.update_limit_ratio))
end

function singularity_lance_config.get_impact_witness_cap(preset_or_name, perf)
    local preset = normalize_preset(preset_or_name)
    if preset.impact_witness_cap_unbounded then
        return nil
    end

    perf = normalize_perf(perf)
    return ei_lib.clamp(
        math.floor(perf * preset.impact_witness_limit_ratio),
        preset.impact_witness_cap_min,
        preset.impact_witness_cap_max
    )
end

function singularity_lance_config.runtime_snapshot(preset_or_name, perf)
    local preset = singularity_lance_config.resolve(
        type(preset_or_name) == "table" and preset_or_name.visual_fidelity or preset_or_name
    )

    preset.visual_drag_slices = singularity_lance_config.get_slice_count(preset, perf)
    preset.visual_job_cap = singularity_lance_config.get_visual_job_cap(preset, perf) or "unbounded"
    preset.update_limit_cap = singularity_lance_config.get_update_limit_cap(preset, perf) or "unbounded"
    preset.impact_witness_cap = singularity_lance_config.get_impact_witness_cap(preset, perf) or "unbounded"

    return preset
end

return singularity_lance_config

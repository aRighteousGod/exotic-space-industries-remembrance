# Preset Config Pattern

Use this when creating or refactoring ESIR startup preset modules such as visual-fidelity, UPS budget, or effect-style configs.

## Shape

- Keep the module narrow: `setting_name`, `default_fidelity`, `allowed_values`, local `presets`, public cap/budget helpers, and optional `runtime_snapshot`.
- Require `ei_lib` locally with `local ei_lib = require("lib/lib")`; do not rely on the global because settings-stage modules can load before `data.lua` or `control.lua`.
- Use dense string arrays for `allowed_values`, ordered from cheapest/least visual to richest/highest UPS cost. Include `off` only when the feature can truly disable tracking and emission.
- Keep `normalize_fidelity` local unless multiple modules share the same preset table. It depends on that module's `presets` and `default_fidelity`.
- Keep `read_startup_fidelity` local and only read `settings.startup[setting_name]`.
- Use `ei_lib.copy_array(allowed_values)` in `startup_setting_definition()` so Factorio receives a fresh ordered values table.
- Use `ei_lib.copy_preset(normalized, presets[normalized], setting_name)` in `resolve()` so callers receive a fresh shallow snapshot. Runtime modules may add derived fields to that returned preset.
- Use `ei_lib.clamp_number` for ratios/scalars and `ei_lib.clamp_integer` for ticks, caps, counts, and optional max clamps.
- Use `nil` to mean unbounded in runtime helpers, and convert nil to `"unbounded"` only in status or `runtime_snapshot` output.

## Skeleton

```lua
local ei_lib = require("lib/lib")

local config = {}

config.setting_name = "ei-example-visual-fidelity"
config.default_fidelity = "standard"
config.allowed_values = {"lean", "standard", "cinematic", "maximal", "unbounded"}

local presets = {
    lean = { update_interval = 8, service_cap = 8 },
    standard = { update_interval = 4, service_cap = 32 },
    cinematic = { update_interval = 3, service_cap = 64 },
    maximal = { update_interval = 2, service_cap = 128 },
    unbounded = { update_interval = 1, service_cap_unbounded = true },
}

config.presets = presets

local function normalize_fidelity(value)
    if presets[value] then
        return value
    end
    return config.default_fidelity
end

local function read_startup_fidelity()
    local setting = settings
        and settings.startup
        and settings.startup[config.setting_name]

    return normalize_fidelity(setting and setting.value)
end

local function normalize_preset(preset_or_name)
    if type(preset_or_name) == "table" then
        return preset_or_name
    end
    return presets[normalize_fidelity(preset_or_name)] or presets[config.default_fidelity]
end

function config.startup_setting_definition()
    return {
        name = config.setting_name,
        type = "string-setting",
        setting_type = "startup",
        default_value = config.default_fidelity,
        allowed_values = ei_lib.copy_array(config.allowed_values),
        order = "b5x",
    }
end

function config.resolve(fidelity)
    local normalized = normalize_fidelity(fidelity or read_startup_fidelity())
    return ei_lib.copy_preset(normalized, presets[normalized], config.setting_name)
end

function config.get_service_cap(preset_or_name)
    local preset = normalize_preset(preset_or_name)
    if preset.service_cap_unbounded then
        return nil
    end
    return ei_lib.clamp_integer(preset.service_cap, 0, nil, 0)
end

function config.runtime_snapshot(preset_or_name)
    local preset = config.resolve(
        type(preset_or_name) == "table" and preset_or_name.visual_fidelity or preset_or_name
    )
    preset.service_cap = config.get_service_cap(preset) or "unbounded"
    return preset
end

return config
```

## Style Notes

- Prefer explicit field names over positional tuples; these preset tables become living documentation for UPS tradeoffs.
- Put the setting order near related visual-fidelity settings, usually the `b5*` block.
- Keep flavor and locale text out of config modules. Config files should be quiet machinery.
- Do not store functions or LuaObjects in presets; settings, data, and runtime stages all require plain serializable values.
- Do not mutate `presets` from runtime. Mutate the fresh result from `resolve()` when caching derived values.

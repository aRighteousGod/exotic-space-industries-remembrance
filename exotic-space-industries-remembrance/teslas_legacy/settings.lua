-- Tesla's Legacy now ships as a built-in EI module.
-- The intentionally exposed knobs are the doctrine behavior mode, the advanced-coil attack
-- animation, and the combat-readout toggles. The underlying numeric balance stays hidden so
-- the owned EI defaults define the supported experience and later maintenance has a much
-- narrower, more predictable surface.
data:extend({
  {
    -- This is the one high-level compatibility switch we still expose. Legacy-fidelity is
    -- now the default so the built-in TL branch boots into the exact original helper
    -- recursion unless the player deliberately opts into the lighter hybrid lattice.
    name = "ei-tl-behavior-mode",
    type = "string-setting",
    setting_type = "startup",
    default_value = "legacy-fidelity",
    allowed_values = {"hybrid", "legacy-fidelity"},
    order = "zzzzzz1",
  },
  {
    name = "tl-advanced-attack-anim",
    type = "string-setting",
    setting_type = "startup",
    default_value = "charge-up",
    allowed_values = {"simple", "charge-up"},
    order = "zzzzzz2",
  },
  {
    -- The tower/tank stat knobs remain in the prototype namespace for compatibility with the
    -- vendored TL data files, but they stay hidden because EI now treats them as internal
    -- balancing constants rather than a supported public tuning surface.
    name = "tl-advanced-health",
    type = "int-setting",
    setting_type = "startup",
    default_value = 1600,
    order = "0120",
    hidden = true,
  },
  {
    name = "tl-advanced-damage",
    type = "int-setting",
    setting_type = "startup",
    default_value = 100,
    order = "0130",
    hidden = true,
  },
  {
    name = "tl-advanced-fire-rate",
    type = "double-setting",
    setting_type = "startup",
    default_value = 0.25,
    order = "0140",
    hidden = true,
  },
  {
    name = "tl-advanced-range",
    type = "int-setting",
    setting_type = "startup",
    default_value = 18,
    order = "0150",
    hidden = true,
  },
  {
    name = "tl-basic-health",
    type = "int-setting",
    setting_type = "startup",
    default_value = 750,
    order = "0200",
    hidden = true,
  },
  {
    name = "tl-basic-damage",
    type = "int-setting",
    setting_type = "startup",
    default_value = 10,
    order = "0210",
    hidden = true,
  },
  {
    name = "tl-basic-fire-rate",
    type = "double-setting",
    setting_type = "startup",
    default_value = 0.5,
    order = "0220",
    hidden = true,
  },
  {
    name = "tl-basic-range",
    type = "int-setting",
    setting_type = "startup",
    default_value = 12,
    order = "0230",
    hidden = true,
  },
  {
    name = "tl-tank-health",
    type = "int-setting",
    setting_type = "startup",
    default_value = 5000,
    order = "0300",
    hidden = true,
  },
  {
    name = "tl-tank-damage",
    type = "int-setting",
    setting_type = "startup",
    default_value = 400,
    order = "0310",
    hidden = true,
  },
  {
    name = "tl-tank-fire-rate",
    type = "double-setting",
    setting_type = "startup",
    default_value = 1,
    order = "0320",
    hidden = true,
  },
  {
    name = "tl-tank-range",
    type = "int-setting",
    setting_type = "startup",
    default_value = 35,
    order = "0330",
    hidden = true,
  },
  {
    name = "tl-critical-multiplier",
    type = "double-setting",
    setting_type = "startup",
    default_value = 2,
    order = "0400",
    hidden = true,
  },
  {
    name = "tl-critical-chance",
    type = "double-setting",
    setting_type = "startup",
    default_value = 0.5,
    minimum_value = 0,
    maximum_value = 100,
    order = "0410",
    hidden = true,
  },
  {
    name = "tl-flying-text-critical",
    type = "bool-setting",
    setting_type = "startup",
    default_value = true,
    order = "zzzzzz3",
  },
  {
    name = "tl-flying-text-vaporize",
    type = "bool-setting",
    setting_type = "startup",
    default_value = true,
    order = "zzzzzz4",
  },
  {
    name = "tl-flying-text-damage",
    type = "bool-setting",
    setting_type = "startup",
    default_value = false,
    order = "zzzzzz5",
  },
})

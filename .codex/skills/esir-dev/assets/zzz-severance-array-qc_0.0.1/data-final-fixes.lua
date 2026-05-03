local TURRET_NAME = "ei-severance-array"
local EXTREME_ALPHA_DAMAGE = 5000000

local TURRET_TYPES = {
  "electric-turret",
  "ammo-turret",
  "fluid-turret",
  "artillery-turret",
}

local function number_or_nil(value)
  local parsed = tonumber(value)
  if parsed then
    return parsed
  end

  return nil
end

local function raise_number_field(tbl, field_name, minimum)
  if type(tbl) ~= "table" then
    return
  end

  local value = number_or_nil(tbl[field_name])
  if value and value < minimum then
    tbl[field_name] = minimum
  end
end

local function lower_number_field(tbl, field_name, maximum)
  if type(tbl) ~= "table" then
    return
  end

  local value = number_or_nil(tbl[field_name])
  if value and value > maximum then
    tbl[field_name] = maximum
  end
end

local function patch_damage_effect(effect)
  if type(effect) ~= "table" or effect.type ~= "damage" then
    return false
  end

  effect.damage = type(effect.damage) == "table" and effect.damage or {}
  local current = number_or_nil(effect.damage.amount) or 0
  if current < EXTREME_ALPHA_DAMAGE then
    effect.damage.amount = EXTREME_ALPHA_DAMAGE
  end
  effect.damage.type = effect.damage.type or "physical"

  return true
end

local function walk_action_tree(value, seen)
  if type(value) ~= "table" then
    return false
  end

  seen = seen or {}
  if seen[value] then
    return false
  end
  seen[value] = true

  local changed = patch_damage_effect(value)
  if value.energy_consumption then
    value.energy_consumption = "1kJ"
    changed = true
  end

  for _, inner in pairs(value) do
    if type(inner) == "table" and walk_action_tree(inner, seen) then
      changed = true
    end
  end

  return changed
end

local function patch_attack_parameters(attack_parameters)
  if type(attack_parameters) ~= "table" then
    return false
  end

  raise_number_field(attack_parameters, "range", 48)
  lower_number_field(attack_parameters, "cooldown", 60)
  lower_number_field(attack_parameters, "warmup", 1)

  return walk_action_tree(attack_parameters.ammo_type)
end

for _, turret_type in ipairs(TURRET_TYPES) do
  local turret = data.raw[turret_type] and data.raw[turret_type][TURRET_NAME]
  if turret then
    if type(turret.energy_source) == "table" then
      turret.energy_source.buffer_capacity = "10GJ"
      turret.energy_source.input_flow_limit = "10GW"
      turret.energy_source.drain = "1W"
    end

    patch_attack_parameters(turret.attack_parameters)
  end
end

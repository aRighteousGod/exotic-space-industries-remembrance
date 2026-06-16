-- EI-owned data-stage overlay for the vendored Tesla's Legacy content.
--
-- The vendored `teslas_legacy` tree keeps TL's public prototype surface intact, while this
-- overlay is where Remembrance layers on its bridge logic, harmonics techs, recipe tweaks,
-- and Space Age Tesla-effect reuse. Keeping those changes here makes later merges against an
-- updated TL source much easier than scattering EI-specific patches across the vendored tree.
local ei_lib = require("lib/lib")
local ei_data = require("lib/data")
require("teslas_legacy.config.research")
require("teslas_legacy.config.settings")
require("teslas_legacy.lib.technology")

local raw = ei_lib.raw
local tl_settings = get_settings()
local tl_research = get_research_array()
-- Mirror the owned startup default here so data-stage helper behavior and control-stage
-- runtime assumptions stay in sync even in stripped-down dump/test environments.
local BEHAVIOR_MODE = tl_settings.behavior_mode or "legacy-fidelity"
local DEFAULT_TESLA_COIL_SOUND_VOLUME = 0.7
local TESLA_COIL_BEAM_MAX_SOUNDS = 4

-- Bridge categories split the vanilla Tesla family from TL's original categories so EI can
-- decide exactly which upgrades spill over into teslagun/tesla-ammo/tesla-turret.
local LEGACY_FAMILY_CATEGORY = "ei-legacy-tesla-family"
local LEGACY_TURRET_CATEGORY = "ei-legacy-tesla-turret"

-- Exact script-effect ids mirrored by the runtime dispatcher in
-- `scripts/control/teslas-legacy.lua`.
local EFFECT_ID = {
  critical = "ei-tl-crit-text",
  tl_basic_hit = "ei-tl-hit-basic",
  tl_advanced_hit = "ei-tl-hit-advanced",
  tl_tank_hit = "ei-tl-hit-tank",
  tl_basic_chain = "ei-tl-basic-chain-hit",
  tl_basic_chain_h3 = "ei-tl-basic-chain-hit-h3",
  tl_basic_chain_exotic = "ei-tl-basic-chain-hit-exotic",
  tl_advanced_chain = "ei-tl-advanced-chain-hit",
  tl_advanced_chain_h3 = "ei-tl-advanced-chain-hit-h3",
  tl_advanced_chain_exotic = "ei-tl-advanced-chain-hit-exotic",
  tl_tank_chain = "ei-tl-tank-chain-hit",
  tl_tank_chain_h3 = "ei-tl-tank-chain-hit-h3",
  tl_tank_chain_exotic = "ei-tl-tank-chain-hit-exotic",
  bridge_family_hit = "ei-tl-hit-bridge-family",
  bridge_turret_hit = "ei-tl-hit-bridge-turret",
  bridge_family_chain = "ei-tl-bridge-family-chain-hit",
  bridge_turret_chain = "ei-tl-bridge-turret-chain-hit",
  bridge_turret_chain_h3 = "ei-tl-bridge-turret-chain-hit-h3",
  bridge_turret_chain_exotic = "ei-tl-bridge-turret-chain-hit-exotic",
}

-- Hidden helper prototype names used to express harmonized Tesla beams/chains in data stage.
local BRIDGE = {
  family_start_beam = "ei-legacy-tesla-family-beam-start",
  family_bounce_beam = "ei-legacy-tesla-family-beam-bounce",
  family_chain = "ei-legacy-tesla-family-chain",
  turret_start_beam = "ei-legacy-tesla-turret-beam-start",
  turret_bounce_beam = "ei-legacy-tesla-turret-beam-bounce",
  turret_chain = "ei-legacy-tesla-turret-chain",
  family_chain_beam = "ei-legacy-tesla-family-chain-beam",
  turret_chain_beam = "ei-legacy-tesla-turret-chain-beam",
  turret_chain_beam_h3 = "ei-legacy-tesla-turret-chain-beam-h3",
  turret_chain_beam_exotic = "ei-legacy-tesla-turret-chain-beam-exotic",
}

-- Doctrine-specific helper families. These are the hidden namespaces that sit above the
-- legacy TL substrate:
-- - the vendored TL helpers remain the authoritative "legacy substrate",
-- - these `DOCTRINE.*` helpers are the TL-specific hybrid lattice and fidelity overlays,
-- - `BRIDGE.*` remains the vanilla tesla-family bridge lattice.
local DOCTRINE = {
  basic_exotic_variant = "tl-basic-tesla-coil__exotic",
  advanced_exotic_variant = "tl-advanced-tesla-coil__exotic",
  basic_primary_exotic_beam = "ei-tl-basic-field-arc-primary-beam",
  advanced_primary_legacy_beam = "ei-tl-advanced-primary-beam",
  advanced_primary_exotic_beam = "ei-tl-advanced-overcharge-lance-beam",
  basic_chain_beam_h2 = "ei-tl-basic-field-arc-chain-beam-h2",
  basic_chain_beam_h3 = "ei-tl-basic-field-arc-chain-beam-h3",
  basic_chain_beam_exotic = "ei-tl-basic-field-arc-chain-beam-exotic",
  advanced_chain_beam_h2 = "ei-tl-advanced-overcharge-chain-beam-h2",
  advanced_chain_beam_h3 = "ei-tl-advanced-overcharge-chain-beam-h3",
  advanced_chain_beam_exotic = "ei-tl-advanced-overcharge-chain-beam-exotic",
  tank_chain_beam_h2 = "ei-tl-tank-stormbeam-chain-beam-h2",
  tank_chain_beam_h3 = "ei-tl-tank-stormbeam-chain-beam-h3",
  tank_chain_beam_exotic = "ei-tl-tank-stormbeam-chain-beam-exotic",
  advanced_overcharge_impact = "ei-tl-advanced-overcharge-impact",
  tank_stormbeam_impact = "ei-tl-tank-stormbeam-impact",
}

local TECH_ICON = {
  harmonics = "__space-age__/graphics/technology/tesla-weapons.png",
  storm = "__exotic-space-industries-remembrance-graphics-3__/teslas_legacy/graphics/technology/icons/tl-multi-zap-range-technology.png",
  dielectric = "__exotic-space-industries-remembrance-graphics-3__/teslas_legacy/graphics/technology/icons/tl-single-zap-damage-technology.png",
  bridge = "__space-age__/graphics/technology/tesla-weapons.png",
  reactance = "__exotic-space-industries-remembrance-graphics-3__/teslas_legacy/graphics/technology/icons/tl-volatility-modulation-technology.png",
  exotic = "__space-age__/graphics/technology/tesla-weapons.png",
}

local EXTRA_FUELS = {
  "ei-rocket-fuel",
  "ei-nuclear-fuel",
  "ei-nuclear-fuel-cell",
  "ei-fusion-fuel",
  "ei-diesel-fuel",
}

local ELECTRIC_WEAPONS_DAMAGE_GATE = "electric-weapons-damage-4"
local ELECTRIC_WEAPONS_DAMAGE_REPEATABLE = "electric-weapons-damage-5"

local function starts_with(value, prefix)
  return string.find(value, prefix, 1, true) == 1
end

local function append_unique(list, value)
  if not list or value == nil then
    return
  end

  for _, existing in pairs(list) do
    if existing == value then
      return
    end
  end

  table.insert(list, value)
end

local function recipe_has_ingredient(recipe, ingredient_name)
  if not recipe or not recipe.ingredients then
    return false
  end

  for _, ingredient in pairs(recipe.ingredients) do
    if ingredient.name == ingredient_name or ingredient[1] == ingredient_name then
      return true
    end
  end

  return false
end

local function add_recipe_ingredient(recipe_name, ingredient)
  local recipe = raw.recipe[recipe_name]
  if not recipe then
    return
  end

  recipe.ingredients = recipe.ingredients or {}
  if not recipe_has_ingredient(recipe, ingredient.name) then
    table.insert(recipe.ingredients, ingredient)
  end
end

local function ingredient_list_has_name(ingredients, ingredient_name)
  for _, ingredient in pairs(ingredients or {}) do
    local name = ingredient.name or ingredient[1]
    if name == ingredient_name then
      return true
    end
  end

  return false
end

local function effect_matches(effect, candidate)
  if effect.type ~= candidate.type then
    return false
  end

  if effect.type == "script" then
    return effect.effect_id == candidate.effect_id
  end

  if effect.type == "ammo-damage" or effect.type == "gun-speed" then
    return effect.ammo_category == candidate.ammo_category
  end

  if effect.type == "create-sticker" then
    return effect.sticker == candidate.sticker
  end

  return false
end

local function append_effect(target_effects, effect)
  if not target_effects or not effect then
    return
  end

  for _, existing in pairs(target_effects) do
    if effect_matches(existing, effect) then
      return
    end
  end

  table.insert(target_effects, effect)
end

local function remove_effects(target_effects, predicate)
  if not target_effects then
    return
  end

  for index = #target_effects, 1, -1 do
    if predicate(target_effects[index]) then
      table.remove(target_effects, index)
    end
  end
end

local function add_technology_effect(technology_name, effect)
  local technology = raw.technology[technology_name]
  if not technology then
    return
  end

  technology.effects = technology.effects or {}
  for _, existing in pairs(technology.effects) do
    if effect_matches(existing, effect) then
      if existing.modifier and effect.modifier then
        existing.modifier = existing.modifier + effect.modifier
      end
      return
    end
  end

  table.insert(technology.effects, effect)
end

local function ensure_ammo_category(name)
  if raw["ammo-category"][name] then
    return
  end

  local category = {
    type = "ammo-category",
    name = name,
  }

  local tesla_category = raw["ammo-category"]["tesla"]
  if tesla_category and tesla_category.bonus_gui_order then
    category.bonus_gui_order = tesla_category.bonus_gui_order
  end

  data:extend({category})
end

local function ensure_placeable_by(prototype, item_name, count)
  if not prototype or not item_name then
    return
  end

  prototype.placeable_by = {
    item = item_name,
    count = count or 1,
  }
end

local function set_sound_definition_volume(sound_definition, volume)
  if type(sound_definition) ~= "table" or type(volume) ~= "number" then
    return
  end

  if sound_definition.variations then
    for _, variation in pairs(sound_definition.variations) do
      set_sound_definition_volume(variation, volume)
    end
  end

  if sound_definition.layers then
    for _, layer in pairs(sound_definition.layers) do
      set_sound_definition_volume(layer, volume)
    end
  end

  if sound_definition.filename
    or sound_definition.name
    or sound_definition.volume
    or sound_definition.min_volume
    or sound_definition.max_volume
  then
    sound_definition.volume = volume
    sound_definition.min_volume = nil
    sound_definition.max_volume = nil
  end
end

local function set_working_sound_volume(working_sound, volume)
  if type(working_sound) ~= "table" then
    return
  end

  set_sound_definition_volume(working_sound.sound, volume)
  set_sound_definition_volume(working_sound.idle_sound, volume)
  set_sound_definition_volume(working_sound.activate_sound, volume)
  set_sound_definition_volume(working_sound.deactivate_sound, volume)

  if working_sound.main_sounds then
    for _, main_sound in pairs(working_sound.main_sounds) do
      set_sound_definition_volume(main_sound.sound, volume)
    end
  end
end

local function set_beam_working_sound_volume(beam, volume)
  if beam and beam.working_sound then
    set_working_sound_volume(beam.working_sound, volume)
  end

  return beam
end

local function apply_tl_coil_beam_sound_properties(beam)
  if not beam or type(beam.working_sound) ~= "table" then
    return beam
  end

  local working_sound = beam.working_sound
  working_sound.max_sounds_per_prototype = TESLA_COIL_BEAM_MAX_SOUNDS

  if type(working_sound.sound) == "table" then
    working_sound.sound.category = "weapon"
  end

  return beam
end

local function polish_tl_coil_beam_working_sound(beam, volume)
  set_beam_working_sound_volume(beam, volume)
  apply_tl_coil_beam_sound_properties(beam)

  return beam
end

local function copy_beam(base_name, new_name, effect_id, zero_damage)
  local prototype = raw.beam[base_name]
  if not prototype then
    return nil
  end

  local beam = table.deepcopy(prototype)
  beam.name = new_name
  beam.hidden = true
  beam.hidden_in_factoriopedia = true

  local effects = beam.action and beam.action.action_delivery and beam.action.action_delivery.target_effects
  if effects then
    if zero_damage then
      for _, effect in pairs(effects) do
        if effect.type == "damage" and effect.damage then
          effect.damage.amount = 0
        end
      end
    end

    if effect_id then
      append_effect(effects, {type = "script", effect_id = effect_id})
    end
  end

  return beam
end

local function clone_beam_with_graphics(base_name, graphics_source_name, new_name, effect_id, zero_damage)
  local beam = copy_beam(base_name, new_name, effect_id, zero_damage)
  local graphics_source = raw.beam[graphics_source_name]
  if not beam or not graphics_source then
    return beam
  end

  beam.graphics_set = table.deepcopy(graphics_source.graphics_set)
  beam.working_sound = table.deepcopy(graphics_source.working_sound)
  beam.width = graphics_source.width or beam.width
  return beam
end

local function get_beam_effects(beam)
  if not beam
    or not beam.action
    or not beam.action.action_delivery
  then
    return nil
  end

  return beam.action.action_delivery.target_effects
end

local function strip_beam_damage_effects(beam)
  local effects = get_beam_effects(beam)
  if not effects then
    return
  end

  remove_effects(effects, function(effect)
    return effect.type == "damage"
      or effect.type == "nested-result"
      or effect.type == "script"
  end)
end

local function make_damage_effect(amount, damage_type)
  return {
    type = "damage",
    damage = {
      amount = amount,
      type = damage_type or "electric",
    },
  }
end

local function make_script_effect(effect_id)
  return {
    type = "script",
    effect_id = effect_id,
  }
end

local function make_tl_crit_effect(amount)
  if not tl_settings.critical or not tl_settings.critical.probability then
    return nil
  end

  return {
    type = "nested-result",
    probability = tl_settings.critical.probability,
    action = {
      type = "direct",
      action_delivery = {
        type = "instant",
        target_effects = {
          make_script_effect(EFFECT_ID.critical),
          make_damage_effect(amount * tl_settings.critical.multiplier),
          {
            type = "create-fire",
            entity_name = "fire-flame",
            initial_ground_flame_count = 3,
          },
        },
      },
    },
  }
end

local function copy_chain(base_name, new_name, beam_name, max_jumps, jump_range)
  local prototype = raw["chain-active-trigger"][base_name]
  if not prototype then
    return nil
  end

  local chain = table.deepcopy(prototype)
  chain.name = new_name
  chain.max_jumps = max_jumps
  chain.max_range_per_jump = jump_range
  if chain.action and chain.action.action_delivery then
    chain.action.action_delivery.beam = beam_name
    chain.action.action_delivery.max_length = jump_range + 0.5
  end

  return chain
end

local function make_chain_helper(name, chain_name, ammo_category, trigger_radius)
  if not get_empty_picture then
    return nil
  end

  return {
    type = "land-mine",
    name = name,
    icon = "__base__/graphics/icons/land-mine.png",
    icon_size = 64,
    icon_mipmaps = 4,
    hidden = true,
    hidden_in_factoriopedia = true,
    minable = nil,
    max_health = 15000,
    is_military_target = false,
    alert_when_damaged = false,
    picture_safe = get_empty_picture(),
    picture_set = get_empty_picture(),
    picture_set_enemy = get_empty_picture(),
    ammo_category = ammo_category or LEGACY_TURRET_CATEGORY,
    timeout = 0,
    -- These helpers are spawned by EI runtime code to continue enemy-facing Tesla arcs.
    -- Letting "all" forces trigger them means the hidden helper can wake up off the owning
    -- coil, the player, or other nearby friendlies and then arc from that origin, which reads
    -- like friendly fire. Restrict activation to enemies and keep the follow-up chain enemy-only.
    trigger_force = "enemy",
    trigger_radius = trigger_radius or 32,
    force_die_on_attack = true,
    action = {
      type = "direct",
      force = "enemy",
      action_delivery = {
        type = "chain",
        chain = chain_name,
      },
    },
  }
end

local function ensure_space_age_stickers(target_effects)
  remove_effects(target_effects, function(effect)
    return effect.type == "create-sticker" and starts_with(effect.sticker or "", "tl-shock-sticker")
  end)

  append_effect(target_effects, {
    type = "create-sticker",
    sticker = "tesla-turret-stun",
  })
  append_effect(target_effects, {
    type = "create-sticker",
    sticker = "tesla-turret-slow",
  })
end

local function patch_basic_tl_beams()
  local turret_beam = raw.beam[get_beam_name_turret()]
  if turret_beam and turret_beam.action and turret_beam.action.action_delivery then
    local effects = turret_beam.action.action_delivery.target_effects
    append_effect(effects, {
      type = "script",
      effect_id = EFFECT_ID.tl_basic_hit,
    })
  end
end

local function patch_advanced_tl_turret()
  local turret = raw["electric-turret"]["tl-advanced-tesla-coil"]
  if not turret or not turret.attack_parameters or not turret.attack_parameters.ammo_type then
    return
  end

  -- TL's original advanced coil relied on a target-side beam-shaped explosion plus a
  -- `source_offset = {0, -100}` hack instead of firing a real beam entity. Modern Factorio
  -- now renders that combination as an invisible shot followed by a bogus lance arriving
  -- from off-screen. Move the public advanced coil onto a proper beam-delivery path while
  -- keeping TL's original beam family for the non-exotic turret.
  turret.attack_parameters.source_offset = nil
  turret.attack_parameters.ammo_type.action = {
    type = "direct",
    action_delivery = {
      type = "beam",
      beam = DOCTRINE.advanced_primary_legacy_beam,
      max_length = tl_settings.turret.advanced.range.max,
      duration = 12,
      add_to_shooter = false,
      destroy_with_source_or_target = false,
      source_offset = {0, -2.8},
    },
  }
end

local function patch_tl_tank_ammo()
  local ammo = raw.ammo["tl-tesla-coil-ammo"]
  if not ammo or not ammo.ammo_type or not ammo.ammo_type.action then
    return
  end

  local delivery = ammo.ammo_type.action.action_delivery
  if not delivery then
    return
  end

  local effects = delivery.target_effects or {}
  delivery.target_effects = effects
  append_effect(effects, {
    type = "script",
    effect_id = EFFECT_ID.tl_tank_hit,
  })
end

-- The old TL helper mines still exist as part of the public prototype surface.
-- In legacy-fidelity they remain the authoritative helper substrate, including their
-- persistence semantics. Hybrid is allowed to trim that old helper lifetime down because
-- the TL-specific doctrine lattice becomes the primary continuation path there.
local function patch_tl_helpers()
  for name, mine in pairs(raw["land-mine"]) do
    if starts_with(name, "tl-basic-tesla-coil-multi-zap-")
      or starts_with(name, "tl-basic-tesla-coil-single-zap-")
      or starts_with(name, "tl-tesla-coil-zap-explosion-")
    then
      if BEHAVIOR_MODE == "legacy-fidelity" then
        mine.force_die_on_attack = false
      else
        mine.force_die_on_attack = true
        mine.timeout = 0
      end
    end
  end

  local turret = raw["electric-turret"]["tl-basic-tesla-coil"]
  if turret then
    turret.max_health = tl_settings.turret.basic.health
    ensure_placeable_by(turret, "tl-basic-tesla-coil")
  end

  local advanced_turret = raw["electric-turret"]["tl-advanced-tesla-coil"]
  if advanced_turret then
    ensure_placeable_by(advanced_turret, "tl-advanced-tesla-coil")
  end

  local tesla_tank = raw.car["tl-tesla-tank"]
  if tesla_tank then
    ensure_placeable_by(tesla_tank, "tl-tesla-tank")
  end
end

-- Space Age already ships the beam/chain language we want visually, so the bridge mostly
-- clones those prototypes and swaps in EI-owned effect ids instead of inventing a parallel
-- graphics stack.
local function create_bridge_prototypes()
  local prototypes = {}

  append_unique(prototypes, copy_beam("chain-tesla-gun-beam-start", BRIDGE.family_start_beam, EFFECT_ID.bridge_family_hit, false))
  append_unique(prototypes, copy_beam("chain-tesla-gun-beam-bounce", BRIDGE.family_bounce_beam, nil, false))
  append_unique(prototypes, copy_beam("chain-tesla-turret-beam-start", BRIDGE.turret_start_beam, EFFECT_ID.bridge_turret_hit, false))
  append_unique(prototypes, copy_beam("chain-tesla-turret-beam-bounce", BRIDGE.turret_bounce_beam, nil, false))

  append_unique(prototypes, copy_beam("chain-tesla-gun-beam-bounce", BRIDGE.family_chain_beam, EFFECT_ID.bridge_family_chain, true))
  append_unique(prototypes, copy_beam("chain-tesla-turret-beam-bounce", BRIDGE.turret_chain_beam, EFFECT_ID.bridge_turret_chain, true))
  append_unique(prototypes, copy_beam("chain-tesla-turret-beam-bounce", BRIDGE.turret_chain_beam_h3, EFFECT_ID.bridge_turret_chain_h3, true))

  local bridge_turret_chain_beam_exotic = copy_beam("chain-tesla-turret-beam-bounce", BRIDGE.turret_chain_beam_exotic, EFFECT_ID.bridge_turret_chain_exotic, true)
  if bridge_turret_chain_beam_exotic then
    bridge_turret_chain_beam_exotic.width = 0.82
    append_unique(prototypes, bridge_turret_chain_beam_exotic)
  end

  append_unique(prototypes, copy_chain("chain-tesla-gun-chain", BRIDGE.family_chain, BRIDGE.family_bounce_beam, 12, 12))
  append_unique(prototypes, copy_chain("chain-tesla-turret-chain", BRIDGE.turret_chain, BRIDGE.turret_bounce_beam, 10, 12))

  for range_index, range_value in pairs(tl_research.multi_zap.range) do
    local family_chain_name = "ei-legacy-tesla-family-burst-chain-" .. range_index
    local turret_chain_name = "ei-legacy-tesla-turret-burst-chain-" .. range_index
    local jump_range = 6 + range_value
    local max_jumps = 2 + range_index
    local trigger_radius = math.ceil(jump_range + 2)

    append_unique(prototypes, copy_chain("chain-tesla-gun-chain", family_chain_name, BRIDGE.family_chain_beam, max_jumps, jump_range))
    append_unique(prototypes, copy_chain("chain-tesla-turret-chain", turret_chain_name, BRIDGE.turret_chain_beam, max_jumps, jump_range))
    -- The bridge layer is the last modern helper family still inheriting a generic wake
    -- radius, so these helpers are sized to their actual burst geometry instead.
    append_unique(prototypes, make_chain_helper("ei-legacy-tesla-family-burst-" .. range_index, family_chain_name, LEGACY_TURRET_CATEGORY, trigger_radius))
    append_unique(prototypes, make_chain_helper("ei-legacy-tesla-turret-burst-" .. range_index, turret_chain_name, LEGACY_TURRET_CATEGORY, trigger_radius))
  end

  local aftershock_range = math.max(3, math.floor(tl_settings.turret.advanced.range.max / 4))
  for count_index, count_value in pairs(tl_research.single_zap.count) do
    local turret_chain_name = "ei-legacy-tesla-turret-aftershock-chain-" .. count_index
    local turret_h3_chain_name = "ei-legacy-tesla-turret-aftershock-h3-chain-" .. count_index
    local turret_exotic_chain_name = "ei-legacy-tesla-turret-aftershock-exotic-chain-" .. count_index
    local trigger_radius = math.ceil(aftershock_range + 2)
    local trigger_radius_h3 = math.ceil((aftershock_range * 1.15) + 2)
    local trigger_radius_exotic = math.ceil((aftershock_range * 1.30) + 2)

    append_unique(prototypes, copy_chain("chain-tesla-turret-chain", turret_chain_name, BRIDGE.turret_chain_beam, count_value, aftershock_range))
    append_unique(prototypes, copy_chain("chain-tesla-turret-chain", turret_h3_chain_name, BRIDGE.turret_chain_beam_h3, count_value + 1, aftershock_range * 1.15))
    append_unique(prototypes, copy_chain("chain-tesla-turret-chain", turret_exotic_chain_name, BRIDGE.turret_chain_beam_exotic, count_value + 2, aftershock_range * 1.30))
    -- Aftershock helpers also wake from the real continuation geometry, not the generic
    -- 32-tile helper bubble that the bridge layer inherited from the old prototype model.
    append_unique(prototypes, make_chain_helper("ei-legacy-tesla-turret-aftershock-" .. count_index, turret_chain_name, LEGACY_TURRET_CATEGORY, trigger_radius))
    append_unique(prototypes, make_chain_helper("ei-legacy-tesla-turret-aftershock-h3-" .. count_index, turret_h3_chain_name, LEGACY_TURRET_CATEGORY, trigger_radius_h3))
    append_unique(prototypes, make_chain_helper("ei-legacy-tesla-turret-aftershock-exotic-" .. count_index, turret_exotic_chain_name, LEGACY_TURRET_CATEGORY, trigger_radius_exotic))
  end

  local filtered = {}
  for _, prototype in pairs(prototypes) do
    if prototype then
      filtered[#filtered + 1] = prototype
    end
  end

  if #filtered > 0 then
    data:extend(filtered)
  end
end

local function copy_explosion(base_name, new_name)
  local prototype = raw.explosion[base_name]
  if not prototype then
    return nil
  end

  local explosion = table.deepcopy(prototype)
  explosion.name = new_name
  explosion.hidden = true
  explosion.hidden_in_factoriopedia = true
  return explosion
end

local function build_basic_chain_names(range_index, storm_level)
  local suffix = range_index .. "-" .. storm_level
  return {
    h2_chain = "ei-tl-basic-field-arc-h2-chain-" .. suffix,
    h2_helper = "ei-tl-basic-field-arc-h2-" .. suffix,
    h3_chain = "ei-tl-basic-field-arc-h3-chain-" .. suffix,
    h3_helper = "ei-tl-basic-field-arc-h3-" .. suffix,
  }
end

local function build_advanced_chain_names(count_index, dielectric_level)
  local suffix = count_index .. "-" .. dielectric_level
  return {
    h2_chain = "ei-tl-advanced-overcharge-h2-chain-" .. suffix,
    h2_helper = "ei-tl-advanced-overcharge-h2-" .. suffix,
    h3_chain = "ei-tl-advanced-overcharge-h3-chain-" .. suffix,
    h3_helper = "ei-tl-advanced-overcharge-h3-" .. suffix,
  }
end

local function build_tank_chain_names(range_index, overdrive_level)
  local suffix = range_index .. "-" .. overdrive_level
  return {
    h2_chain = "ei-tl-tank-stormbeam-h2-chain-" .. suffix,
    h2_helper = "ei-tl-tank-stormbeam-h2-" .. suffix,
    h3_chain = "ei-tl-tank-stormbeam-h3-chain-" .. suffix,
    h3_helper = "ei-tl-tank-stormbeam-h3-" .. suffix,
  }
end

local function build_basic_exotic_names(range_index)
  local suffix = tostring(range_index)
  return {
    chain = "ei-tl-basic-field-arc-exotic-chain-" .. suffix,
    helper = "ei-tl-basic-field-arc-exotic-" .. suffix,
  }
end

local function build_advanced_exotic_names(count_index)
  local suffix = tostring(count_index)
  return {
    chain = "ei-tl-advanced-overcharge-exotic-chain-" .. suffix,
    helper = "ei-tl-advanced-overcharge-exotic-" .. suffix,
  }
end

local function build_tank_exotic_names(range_index)
  local suffix = tostring(range_index)
  return {
    chain = "ei-tl-tank-stormbeam-exotic-chain-" .. suffix,
    helper = "ei-tl-tank-stormbeam-exotic-" .. suffix,
  }
end

-- Doctrine prototypes stay intentionally localized here so the late-game modernization can
-- evolve without rewriting the vendored TL prototypes. The public TL names remain stable;
-- only hidden helper families and hidden exotic-capstone variants are introduced.
local function create_doctrine_prototypes()
  local prototypes = {}

  local basic_exotic_beam = clone_beam_with_graphics(
    get_beam_name_turret(),
    "chain-tesla-gun-beam-start",
    DOCTRINE.basic_primary_exotic_beam,
    EFFECT_ID.tl_basic_hit,
    false
  )
  if basic_exotic_beam then
    basic_exotic_beam.width = 0.42
    if raw.beam["chain-tesla-turret-beam-start"] and raw.beam["chain-tesla-turret-beam-start"].working_sound then
      -- Exotic convergence should make the basic coil feel upgraded immediately on fire,
      -- not just visually. Keep the lighter basic-coil beam shape, but let it speak with
      -- the fuller Tesla-turret beam voice once the exotic variant is active.
      basic_exotic_beam.working_sound = table.deepcopy(raw.beam["chain-tesla-turret-beam-start"].working_sound)
    end
    polish_tl_coil_beam_working_sound(basic_exotic_beam, tl_settings.sound.basic_volume)
    append_unique(prototypes, basic_exotic_beam)
  end

  local advanced_overcharge_impact = copy_explosion("spark-explosion-higher", DOCTRINE.advanced_overcharge_impact)
  if advanced_overcharge_impact then
    -- Exotic convergence should feel richer than a plain electric pop, but it still needs to
    -- stay local to the hit point so the player reads one actual beam per shot. This impact
    -- flash uses Space Age lightning strike sprites plus a lateral spray of sparks to give the
    -- endpoint a "strafing overcharge" feel without reintroducing a second beam body.
    advanced_overcharge_impact.height = 1.8
    advanced_overcharge_impact.animations = {
      util.sprite_load("__space-age__/graphics/entity/lightning/lightning-explosion", {
        draw_as_glow = true,
        scale = 0.40,
        frame_count = 36,
        tint = {0.30, 0.95, 1.00, 0.95},
      }),
      util.sprite_load("__space-age__/graphics/entity/lightning/lightning-explosion-2", {
        draw_as_glow = true,
        scale = 0.44,
        frame_count = 36,
        tint = {0.75, 0.98, 1.00, 0.78},
      }),
    }
    advanced_overcharge_impact.created_effect = {
      type = "direct",
      action_delivery = {
        type = "instant",
        target_effects = {
          {
            type = "create-explosion",
            entity_name = "medium-electric-pole-explosion",
            offset_deviation = {{-0.10, -0.10}, {0.10, 0.10}},
          },
          {
            type = "create-entity",
            entity_name = "spark-explosion-higher",
            repeat_count = 2,
            offsets = {
              {-0.52, 0.06},
              {0.52, -0.06},
            },
            offset_deviation = {{-0.14, -0.06}, {0.14, 0.06}},
          },
          {
            type = "create-entity",
            entity_name = "spark-explosion",
            repeat_count = 2,
            offsets = {
              {-0.22, 0.02},
              {0.22, -0.02},
            },
            offset_deviation = {{-0.12, -0.05}, {0.12, 0.05}},
          },
          {
            type = "create-particle",
            repeat_count = 12,
            affects_target = false,
            particle_name = "spark-particle",
            offset_deviation = {{-0.85, -0.15}, {0.85, 0.15}},
            initial_height = 1.20,
            initial_height_deviation = 0.30,
            initial_vertical_speed = 0.02,
            initial_vertical_speed_deviation = 0.05,
            speed_from_center = 0.04,
            speed_from_center_deviation = 0.08,
            frame_speed = 0.60,
            frame_speed_deviation = 0.15,
            tail_length = 9,
            tail_length_deviation = 4,
            tail_width = 3,
            only_when_visible = true,
          },
          {
            type = "create-particle",
            repeat_count = 8,
            affects_target = false,
            particle_name = "pole-spark-particle",
            offset_deviation = {{-0.95, -0.12}, {0.95, 0.12}},
            initial_height = 1.05,
            initial_height_deviation = 0.22,
            initial_vertical_speed = 0.02,
            initial_vertical_speed_deviation = 0.04,
            speed_from_center = 0.02,
            speed_from_center_deviation = 0.06,
            frame_speed = 0.55,
            frame_speed_deviation = 0.10,
            tail_length = 10,
            tail_length_deviation = 4,
            tail_width = 4,
            only_when_visible = true,
          },
        },
      },
    }
    advanced_overcharge_impact.smoke_count = 0
    advanced_overcharge_impact.sound = table.deepcopy(raw.explosion["medium-electric-pole-explosion"] and raw.explosion["medium-electric-pole-explosion"].sound)
    advanced_overcharge_impact.light = {intensity = 1.8, size = 96, color = {r = 0.35, g = 0.90, b = 1.00}}
    append_unique(prototypes, advanced_overcharge_impact)
  end

  local advanced_legacy_beam = copy_beam(
    get_beam_name_turret(),
    DOCTRINE.advanced_primary_legacy_beam,
    nil,
    true
  )
  if advanced_legacy_beam then
    local effects = get_beam_effects(advanced_legacy_beam) or {}
    advanced_legacy_beam.action.action_delivery.target_effects = effects
    strip_beam_damage_effects(advanced_legacy_beam)
    append_effect(effects, make_tl_crit_effect(tl_settings.turret.advanced.damage))
    append_effect(effects, make_damage_effect(tl_settings.turret.advanced.damage))
    append_effect(effects, make_script_effect(EFFECT_ID.tl_advanced_hit))
    advanced_legacy_beam.width = 0.75
    polish_tl_coil_beam_working_sound(advanced_legacy_beam, tl_settings.sound.advanced_volume)
    append_unique(prototypes, advanced_legacy_beam)
  end

  local tank_stormbeam_impact = copy_explosion("tl-tesla-coil-explosion", DOCTRINE.tank_stormbeam_impact)
  if tank_stormbeam_impact then
    tank_stormbeam_impact.light = {intensity = 1.1, size = 90, color = {r = 0.15, g = 0.75, b = 0.90}}
    append_unique(prototypes, tank_stormbeam_impact)
  end

  local advanced_exotic_beam = clone_beam_with_graphics(
    get_beam_name_turret(),
    "chain-tesla-turret-beam-start",
    DOCTRINE.advanced_primary_exotic_beam,
    nil,
    false
  )
  if advanced_exotic_beam then
    local effects = get_beam_effects(advanced_exotic_beam) or {}
    advanced_exotic_beam.action.action_delivery.target_effects = effects
    strip_beam_damage_effects(advanced_exotic_beam)

    -- Keep the underlying delivery semantics from the rebuilt TL direct turret beam and only
    -- borrow the Space Age beam graphics/sound package. That preserves the visible origin at
    -- the coil head while still letting exotic convergence modernize the beam language.
    advanced_exotic_beam.random_target_offset = false
    append_effect(effects, make_tl_crit_effect(tl_settings.turret.advanced.damage))
    append_effect(effects, make_damage_effect(tl_settings.turret.advanced.damage))
    append_effect(effects, make_script_effect(EFFECT_ID.tl_advanced_hit))
    append_effect(effects, {type = "create-explosion", entity_name = DOCTRINE.advanced_overcharge_impact})
    advanced_exotic_beam.width = 0.75
    polish_tl_coil_beam_working_sound(advanced_exotic_beam, tl_settings.sound.advanced_volume)
    append_unique(prototypes, advanced_exotic_beam)
  end

  local basic_chain_beam_h2 = copy_beam(get_beam_name_turret(), DOCTRINE.basic_chain_beam_h2, EFFECT_ID.tl_basic_chain, true)
  if basic_chain_beam_h2 then
    strip_beam_damage_effects(basic_chain_beam_h2)
    append_effect(get_beam_effects(basic_chain_beam_h2), make_script_effect(EFFECT_ID.tl_basic_chain))
    polish_tl_coil_beam_working_sound(basic_chain_beam_h2, tl_settings.sound.basic_volume)
    append_unique(prototypes, basic_chain_beam_h2)
  end

  local basic_chain_beam_h3 = copy_beam("chain-tesla-gun-beam-bounce", DOCTRINE.basic_chain_beam_h3, EFFECT_ID.tl_basic_chain_h3, true)
  if basic_chain_beam_h3 then
    polish_tl_coil_beam_working_sound(basic_chain_beam_h3, tl_settings.sound.basic_volume)
    append_unique(prototypes, basic_chain_beam_h3)
  end

  local basic_chain_beam_exotic = copy_beam("chain-tesla-gun-beam-bounce", DOCTRINE.basic_chain_beam_exotic, EFFECT_ID.tl_basic_chain_exotic, true)
  if basic_chain_beam_exotic then
    strip_beam_damage_effects(basic_chain_beam_exotic)
    append_effect(get_beam_effects(basic_chain_beam_exotic), make_script_effect(EFFECT_ID.tl_basic_chain_exotic))
    basic_chain_beam_exotic.width = 0.30
    polish_tl_coil_beam_working_sound(basic_chain_beam_exotic, tl_settings.sound.basic_volume)
    append_unique(prototypes, basic_chain_beam_exotic)
  end

  local advanced_chain_beam_h2 = copy_beam(get_beam_name_turret(), DOCTRINE.advanced_chain_beam_h2, EFFECT_ID.tl_advanced_chain, true)
  if advanced_chain_beam_h2 then
    strip_beam_damage_effects(advanced_chain_beam_h2)
    append_effect(get_beam_effects(advanced_chain_beam_h2), make_script_effect(EFFECT_ID.tl_advanced_chain))
    polish_tl_coil_beam_working_sound(advanced_chain_beam_h2, tl_settings.sound.advanced_volume)
    append_unique(prototypes, advanced_chain_beam_h2)
  end

  local advanced_chain_beam_h3 = copy_beam("chain-tesla-turret-beam-bounce", DOCTRINE.advanced_chain_beam_h3, EFFECT_ID.tl_advanced_chain_h3, true)
  if advanced_chain_beam_h3 then
    polish_tl_coil_beam_working_sound(advanced_chain_beam_h3, tl_settings.sound.advanced_volume)
    append_unique(prototypes, advanced_chain_beam_h3)
  end

  local advanced_chain_beam_exotic = copy_beam("chain-tesla-turret-beam-bounce", DOCTRINE.advanced_chain_beam_exotic, EFFECT_ID.tl_advanced_chain_exotic, true)
  if advanced_chain_beam_exotic then
    strip_beam_damage_effects(advanced_chain_beam_exotic)
    append_effect(get_beam_effects(advanced_chain_beam_exotic), make_script_effect(EFFECT_ID.tl_advanced_chain_exotic))
    advanced_chain_beam_exotic.width = 0.82
    polish_tl_coil_beam_working_sound(advanced_chain_beam_exotic, tl_settings.sound.advanced_volume)
    append_unique(prototypes, advanced_chain_beam_exotic)
  end

  local tank_chain_beam_h2 = copy_beam(get_beam_name_turret(), DOCTRINE.tank_chain_beam_h2, EFFECT_ID.tl_tank_chain, true)
  if tank_chain_beam_h2 then
    strip_beam_damage_effects(tank_chain_beam_h2)
    append_effect(get_beam_effects(tank_chain_beam_h2), make_script_effect(EFFECT_ID.tl_tank_chain))
    set_beam_working_sound_volume(tank_chain_beam_h2, DEFAULT_TESLA_COIL_SOUND_VOLUME)
    append_unique(prototypes, tank_chain_beam_h2)
  end

  append_unique(prototypes, copy_beam("chain-tesla-gun-beam-bounce", DOCTRINE.tank_chain_beam_h3, EFFECT_ID.tl_tank_chain_h3, true))

  local tank_chain_beam_exotic = copy_beam("chain-tesla-gun-beam-bounce", DOCTRINE.tank_chain_beam_exotic, EFFECT_ID.tl_tank_chain_exotic, true)
  if tank_chain_beam_exotic then
    strip_beam_damage_effects(tank_chain_beam_exotic)
    append_effect(get_beam_effects(tank_chain_beam_exotic), make_script_effect(EFFECT_ID.tl_tank_chain_exotic))
    tank_chain_beam_exotic.width = 0.56
    append_unique(prototypes, tank_chain_beam_exotic)
  end

  for range_index, range_value in pairs(tl_research.multi_zap.range) do
    for storm_level = 0, 3 do
      local names = build_basic_chain_names(range_index, storm_level)
      local jump_range = 6 + range_value + storm_level
      local max_jumps = 2 + range_index + storm_level

      append_unique(prototypes, copy_chain("chain-tesla-gun-chain", names.h2_chain, DOCTRINE.basic_chain_beam_h2, max_jumps, jump_range))
      append_unique(prototypes, copy_chain("chain-tesla-gun-chain", names.h3_chain, DOCTRINE.basic_chain_beam_h3, max_jumps + 1, jump_range * 1.15))
      append_unique(prototypes, make_chain_helper(names.h2_helper, names.h2_chain, "tl-basic-tesla-coil-turret-category", jump_range + 2))
      append_unique(prototypes, make_chain_helper(names.h3_helper, names.h3_chain, "tl-basic-tesla-coil-turret-category", jump_range + 2))
    end
  end

  -- Exotic convergence layers a guaranteed field-arc side branch on top of the normal
  -- multi-zap/storm-lattice flow, so it needs a dedicated helper family rather than another
  -- reuse of the H3 chains.
  for range_index, range_value in pairs(tl_research.multi_zap.range) do
    local names = build_basic_exotic_names(range_index)
    local jump_range = (9 + range_value) * 1.25
    local max_jumps = 7 + range_index

    append_unique(prototypes, copy_chain("chain-tesla-gun-chain", names.chain, DOCTRINE.basic_chain_beam_exotic, max_jumps, jump_range))
    append_unique(prototypes, make_chain_helper(names.helper, names.chain, "tl-basic-tesla-coil-turret-category", jump_range + 2))
  end

  local aftershock_range = math.max(3, math.floor(tl_settings.turret.advanced.range.max / 4))
  for count_index, count_value in pairs(tl_research.single_zap.count) do
    for dielectric_level = 0, 3 do
      local names = build_advanced_chain_names(count_index, dielectric_level)
      local jump_range = aftershock_range + dielectric_level
      local max_jumps = count_value + dielectric_level

      append_unique(prototypes, copy_chain("chain-tesla-turret-chain", names.h2_chain, DOCTRINE.advanced_chain_beam_h2, max_jumps, jump_range))
      append_unique(prototypes, copy_chain("chain-tesla-turret-chain", names.h3_chain, DOCTRINE.advanced_chain_beam_h3, max_jumps + 1, jump_range * 1.15))
      append_unique(prototypes, make_chain_helper(names.h2_helper, names.h2_chain, "tl-advanced-tesla-coil-turret-category", jump_range + 2))
      append_unique(prototypes, make_chain_helper(names.h3_helper, names.h3_chain, "tl-advanced-tesla-coil-turret-category", jump_range + 2))
    end
  end

  -- The advanced capstone is a dedicated execution-storm overlay: longer reach, more jumps,
  -- and heavier overcharge support than the dielectric H3 helpers, but still kill-gated in
  -- runtime so it does not flatten into the basic coil's branching behavior.
  for count_index, count_value in pairs(tl_research.single_zap.count) do
    local names = build_advanced_exotic_names(count_index)
    local jump_range = (aftershock_range + 4) * 1.20
    local max_jumps = count_value + 5

    append_unique(prototypes, copy_chain("chain-tesla-turret-chain", names.chain, DOCTRINE.advanced_chain_beam_exotic, max_jumps, jump_range))
    append_unique(prototypes, make_chain_helper(names.helper, names.chain, "tl-advanced-tesla-coil-turret-category", jump_range + 2))
  end

  for range_index, range_value in pairs(tl_research.multi_zap.range) do
    for overdrive_level = 0, 3 do
      local names = build_tank_chain_names(range_index, overdrive_level)
      local jump_range = 6 + range_value + overdrive_level
      local max_jumps = 2 + range_index + overdrive_level

      append_unique(prototypes, copy_chain("chain-tesla-gun-chain", names.h2_chain, DOCTRINE.tank_chain_beam_h2, max_jumps, jump_range))
      append_unique(prototypes, copy_chain("chain-tesla-gun-chain", names.h3_chain, DOCTRINE.tank_chain_beam_h3, max_jumps + 1, jump_range * 1.15))
      append_unique(prototypes, make_chain_helper(names.h2_helper, names.h2_chain, "tl-tesla-coil-ammo-category", jump_range + 2))
      append_unique(prototypes, make_chain_helper(names.h3_helper, names.h3_chain, "tl-tesla-coil-ammo-category", jump_range + 2))
    end
  end

  -- The tank participates only partially in exotic convergence, so its stormfront helpers
  -- stay more restrained than the tower capstones and only come online from tank-side proc
  -- logic in runtime.
  for range_index, range_value in pairs(tl_research.multi_zap.range) do
    local names = build_tank_exotic_names(range_index)
    local jump_range = (9 + range_value) * 1.10
    local max_jumps = 5 + range_index

    append_unique(prototypes, copy_chain("chain-tesla-gun-chain", names.chain, DOCTRINE.tank_chain_beam_exotic, max_jumps, jump_range))
    append_unique(prototypes, make_chain_helper(names.helper, names.chain, "tl-tesla-coil-ammo-category", jump_range + 2))
  end

  local basic_variant = raw["electric-turret"]["tl-basic-tesla-coil"]
  if basic_variant then
    basic_variant = table.deepcopy(basic_variant)
    basic_variant.name = DOCTRINE.basic_exotic_variant
    basic_variant.hidden = true
    basic_variant.hidden_in_factoriopedia = true
    basic_variant.localised_name = {"entity-name.tl-basic-tesla-coil"}
    basic_variant.localised_description = {"entity-description.tl-basic-tesla-coil"}
    ensure_placeable_by(basic_variant, "tl-basic-tesla-coil")
    if basic_variant.attack_parameters
      and basic_variant.attack_parameters.ammo_type
      and basic_variant.attack_parameters.ammo_type.action
      and basic_variant.attack_parameters.ammo_type.action.action_delivery
    then
      basic_variant.attack_parameters.ammo_type.action.action_delivery.beam = DOCTRINE.basic_primary_exotic_beam
    end
    -- The basic coil never does the tesla-turret head-rise/rotation routine, so giving it
    -- the full turret sound profile reads strangely in play. Keep the exotic upgrade focused
    -- on the actual attack voice by leaving the turret-level movement/idle sounds alone and
    -- letting the exotic beam's working_sound carry the upgraded firing feel.
    append_unique(prototypes, basic_variant)
  end

  local advanced_variant = raw["electric-turret"]["tl-advanced-tesla-coil"]
  if advanced_variant then
    advanced_variant = table.deepcopy(advanced_variant)
    advanced_variant.name = DOCTRINE.advanced_exotic_variant
    advanced_variant.hidden = true
    advanced_variant.hidden_in_factoriopedia = true
    advanced_variant.localised_name = {"entity-name.tl-advanced-tesla-coil"}
    advanced_variant.localised_description = {"entity-description.tl-advanced-tesla-coil"}
    ensure_placeable_by(advanced_variant, "tl-advanced-tesla-coil")
    if advanced_variant.attack_parameters and advanced_variant.attack_parameters.ammo_type then
      advanced_variant.attack_parameters.ammo_type.action = {
        type = "direct",
        action_delivery = {
          type = "beam",
          beam = DOCTRINE.advanced_primary_exotic_beam,
          max_length = tl_settings.turret.advanced.range.max,
          duration = 12,
          -- Mirror the vanilla Space Age beam-delivery shape closely enough that the
          -- hidden exotic-capstone variant still emits from the coil head instead of
          -- inheriting odd-looking fallback geometry from the old TL turret setup.
          add_to_shooter = false,
          destroy_with_source_or_target = false,
          source_offset = {0, -2.8},
        },
      }
    end
    append_unique(prototypes, advanced_variant)
  end

  local filtered = {}
  for _, prototype in pairs(prototypes) do
    if prototype then
      filtered[#filtered + 1] = prototype
    end
  end

  if #filtered > 0 then
    data:extend(filtered)
  end
end

local function patch_bridge_weapons()
  local tesla_turret_item = raw.item["tesla-turret"]
  if tesla_turret_item then
    tesla_turret_item.localised_name = {"item-name.ei-tesla-turret"}
    tesla_turret_item.localised_description = {"item-description.ei-tesla-turret"}
  end

  local tesla_turret = raw["electric-turret"]["tesla-turret"]
  if tesla_turret and tesla_turret.attack_parameters then
    tesla_turret.localised_name = {"item-name.ei-tesla-turret"}
    tesla_turret.localised_description = {"item-description.ei-tesla-turret"}
    tesla_turret.attack_parameters.ammo_category = LEGACY_TURRET_CATEGORY

    local target_effects = tesla_turret.attack_parameters.ammo_type.action.action_delivery.target_effects
    if target_effects and target_effects[1] and target_effects[1].action and target_effects[1].action.action_delivery then
      target_effects[1].action.action_delivery.chain = BRIDGE.turret_chain
    end
    if target_effects and target_effects[2] and target_effects[2].action and target_effects[2].action.action_delivery then
      target_effects[2].action.action_delivery.beam = BRIDGE.turret_start_beam
    end
  end

  local tesla_gun = raw.gun["teslagun"]
  if tesla_gun and tesla_gun.attack_parameters then
    tesla_gun.attack_parameters.ammo_category = LEGACY_FAMILY_CATEGORY
  end

  local tesla_ammo = raw.ammo["tesla-ammo"]
  if tesla_ammo then
    tesla_ammo.ammo_category = LEGACY_FAMILY_CATEGORY

    local target_effects = tesla_ammo.ammo_type.action.action_delivery.target_effects
    if target_effects and target_effects[1] and target_effects[1].action and target_effects[1].action.action_delivery then
      target_effects[1].action.action_delivery.chain = BRIDGE.family_chain
    end
    if target_effects and target_effects[2] and target_effects[2].action and target_effects[2].action.action_delivery then
      target_effects[2].action.action_delivery.beam = BRIDGE.family_start_beam
    end
  end
end

local function split_electric_weapons_damage_repeatable()
  local technologies = data.raw.technology
  local gate = technologies and technologies[ELECTRIC_WEAPONS_DAMAGE_GATE]
  if not gate or not gate.unit then
    return
  end

  local is_repeatable_gate = gate.max_level == "infinite"
    or gate.unit.count_formula ~= nil

  if not is_repeatable_gate then
    return
  end

  if not technologies[ELECTRIC_WEAPONS_DAMAGE_REPEATABLE] then
    local repeatable = table.deepcopy(gate)
    repeatable.name = ELECTRIC_WEAPONS_DAMAGE_REPEATABLE
    repeatable.prerequisites = {ELECTRIC_WEAPONS_DAMAGE_GATE}
    repeatable.max_level = "infinite"
    data:extend({repeatable})
  end

  gate.max_level = nil
  gate.unit.count = gate.unit.count or 2000
  gate.unit.count_formula = nil
end

local function mirror_existing_effects()
  for technology_name, technology in pairs(raw.technology) do
    if technology.effects then
      for _, effect in pairs(table.deepcopy(technology.effects)) do
        if effect.type == "ammo-damage" or effect.type == "gun-speed" then
          if effect.ammo_category == "tesla" then
            effect.ammo_category = LEGACY_FAMILY_CATEGORY
            add_technology_effect(technology_name, effect)

            local turret_effect = table.deepcopy(effect)
            turret_effect.ammo_category = LEGACY_TURRET_CATEGORY
            add_technology_effect(technology_name, turret_effect)
          elseif effect.ammo_category == "tl-basic-tesla-coil-turret-category" then
            effect.ammo_category = LEGACY_FAMILY_CATEGORY
            add_technology_effect(technology_name, effect)
          elseif effect.ammo_category == "tl-advanced-tesla-coil-turret-category" then
            effect.ammo_category = LEGACY_TURRET_CATEGORY
            add_technology_effect(technology_name, effect)
          elseif effect.ammo_category == "tl-tesla-coil-ammo-category" then
            effect.ammo_category = LEGACY_FAMILY_CATEGORY
            add_technology_effect(technology_name, effect)
          elseif effect.ammo_category == "beam" then
            -- Space Age's `electric-weapons-damage-*` line buffs `beam` directly for the
            -- turret-side Tesla weapons instead of using the public `tesla` ammo category.
            -- TL's coils and their doctrine helpers live on their own ammo categories, so
            -- without copying this family over they miss the same beam damage ladder that the
            -- vanilla electric beam ecosystem gets.
            local basic_effect = table.deepcopy(effect)
            basic_effect.ammo_category = "tl-basic-tesla-coil-turret-category"
            add_technology_effect(technology_name, basic_effect)

            local advanced_effect = table.deepcopy(effect)
            advanced_effect.ammo_category = "tl-advanced-tesla-coil-turret-category"
            add_technology_effect(technology_name, advanced_effect)

            local bridge_turret_effect = table.deepcopy(effect)
            bridge_turret_effect.ammo_category = LEGACY_TURRET_CATEGORY
            add_technology_effect(technology_name, bridge_turret_effect)
          elseif effect.ammo_category == "electric" then
            -- The same vanilla tech line uses `electric` for the handheld/launcher side.
            -- Mirror that onto TL's tank ammo and the bridged teslagun/tesla-ammo family so
            -- their scripted follow-up damage tracks the same late electric-weapon ladder.
            local tank_effect = table.deepcopy(effect)
            tank_effect.ammo_category = "tl-tesla-coil-ammo-category"
            add_technology_effect(technology_name, tank_effect)

            local bridge_family_effect = table.deepcopy(effect)
            bridge_family_effect.ammo_category = LEGACY_FAMILY_CATEGORY
            add_technology_effect(technology_name, bridge_family_effect)
          end
        end
      end
    end
  end
end

local function make_modifier_effect(icon_path, description_key)
  return {
    type = "nothing",
    icon = icon_path,
    icon_size = 128,
    effect_description = {description_key},
  }
end

local function make_age_ingredients(age, extra_ingredients)
  local ingredients = table.deepcopy(ei_data.science[age] or {})
  for _, ingredient in pairs(extra_ingredients or {}) do
    if not ingredient_list_has_name(ingredients, ingredient[1]) then
      ingredients[#ingredients + 1] = {ingredient[1], ingredient[2]}
    end
  end
  return ingredients
end

local function create_doctrine_technology(spec)
  if data.raw.technology[spec.name] then
    return nil
  end

  return {
    type = "technology",
    name = spec.name,
    icon = spec.icon,
    -- Tesla doctrine techs mostly reuse the legacy 128px icon set. Defaulting these
    -- to 256 makes Factorio read past the actual sprite bounds for icons like
    -- tl-single-zap-damage-technology.png, so keep the doctrine constructor aligned
    -- with the TL icon atlas unless a specific tech opts out.
    icon_size = spec.icon_size or 128,
    icon_mipmaps = spec.icon_mipmaps or 4,
    localised_name = {"technology-name." .. spec.name},
    localised_description = {"technology-description." .. spec.name},
    prerequisites = spec.prerequisites,
    effects = spec.effects or {},
    unit = {
      count = spec.count,
      ingredients = make_age_ingredients(spec.age, spec.extra_ingredients),
      time = spec.time or 60,
    },
    age = spec.age,
    upgrade = spec.upgrade,
    order = spec.order,
  }
end

local function add_doctrine_technologies()
  local technologies = {}

  local harmonics_extra = {{"electromagnetic-science-pack", 1}}
  local harmonics = {
    {
      name = "ei-waveform-harmonics-1",
      age = "advanced-computer-age-space",
      extra_ingredients = harmonics_extra,
      count = 700,
      icon = TECH_ICON.harmonics,
      icon_size = 256,
      prerequisites = {
        "tesla-weapons",
        "tl-advanced-tesla-coils-technology",
        "electric-weapons-damage-3",
        "tl-tesla-coil-damage-technology-2",
      },
      effects = {
        {type = "ammo-damage", ammo_category = LEGACY_FAMILY_CATEGORY, modifier = 0.10},
        {type = "ammo-damage", ammo_category = LEGACY_TURRET_CATEGORY, modifier = 0.10},
        make_modifier_effect(TECH_ICON.harmonics, "modifier-description.ei-waveform-harmonics-1-effect"),
      },
      order = "e-j-z-a",
      upgrade = true,
    },
    {
      name = "ei-waveform-harmonics-2",
      age = "advanced-computer-age-space",
      extra_ingredients = harmonics_extra,
      count = 1000,
      icon = TECH_ICON.harmonics,
      icon_size = 256,
      prerequisites = {
        "ei-waveform-harmonics-1",
        "electric-weapons-damage-4",
        "tl-multi-zap-probability-technology-2",
        "tl-slowdown-duration-technology-2",
      },
      effects = {
        {type = "ammo-damage", ammo_category = LEGACY_FAMILY_CATEGORY, modifier = 0.10},
        {type = "ammo-damage", ammo_category = LEGACY_TURRET_CATEGORY, modifier = 0.10},
        make_modifier_effect(TECH_ICON.harmonics, "modifier-description.ei-waveform-harmonics-2-effect"),
      },
      order = "e-j-z-b",
      upgrade = true,
    },
    {
      name = "ei-waveform-harmonics-3",
      age = "advanced-computer-age-space",
      extra_ingredients = harmonics_extra,
      count = 1400,
      icon = TECH_ICON.harmonics,
      icon_size = 256,
      prerequisites = {
        "ei-waveform-harmonics-2",
        "tl-single-zap-probability-technology-3",
        "tl-flames-probability-technology-3",
        "tl-tesla-ammo-upgrade-technology-3",
      },
      effects = {
        {type = "ammo-damage", ammo_category = LEGACY_FAMILY_CATEGORY, modifier = 0.10},
        {type = "ammo-damage", ammo_category = LEGACY_TURRET_CATEGORY, modifier = 0.10},
        make_modifier_effect(TECH_ICON.harmonics, "modifier-description.ei-waveform-harmonics-3-effect"),
      },
      order = "e-j-z-c",
      upgrade = true,
    },
  }

  for _, spec in pairs(harmonics) do
    append_unique(technologies, create_doctrine_technology(spec))
  end

  local quantum_specs = {
    {
      name = "ei-storm-lattice-1",
      age = "quantum-age",
      count = 1200,
      icon = TECH_ICON.storm,
      prerequisites = {
        "ei-waveform-harmonics-3",
        "ei-quantum-age",
        "tl-multi-zap-probability-technology-5",
        "tl-multi-zap-range-technology-5",
        "tl-slowdown-duration-technology-5",
      },
      effects = {
        {type = "ammo-damage", ammo_category = "tl-basic-tesla-coil-turret-category", modifier = 0.05},
        {type = "gun-speed", ammo_category = "tl-basic-tesla-coil-turret-category", modifier = 0.03},
        make_modifier_effect(TECH_ICON.storm, "modifier-description.ei-storm-lattice-1-effect"),
      },
      order = "e-j-z-d-a",
      upgrade = true,
    },
    {
      name = "ei-storm-lattice-2",
      age = "quantum-age",
      count = 1800,
      icon = TECH_ICON.storm,
      prerequisites = {"ei-storm-lattice-1"},
      effects = {
        {type = "ammo-damage", ammo_category = "tl-basic-tesla-coil-turret-category", modifier = 0.075},
        {type = "gun-speed", ammo_category = "tl-basic-tesla-coil-turret-category", modifier = 0.03},
        make_modifier_effect(TECH_ICON.storm, "modifier-description.ei-storm-lattice-2-effect"),
      },
      order = "e-j-z-d-b",
      upgrade = true,
    },
    {
      name = "ei-storm-lattice-3",
      age = "quantum-age",
      count = 2400,
      icon = TECH_ICON.storm,
      prerequisites = {"ei-storm-lattice-2"},
      effects = {
        {type = "ammo-damage", ammo_category = "tl-basic-tesla-coil-turret-category", modifier = 0.10},
        {type = "gun-speed", ammo_category = "tl-basic-tesla-coil-turret-category", modifier = 0.04},
        make_modifier_effect(TECH_ICON.storm, "modifier-description.ei-storm-lattice-3-effect"),
      },
      order = "e-j-z-d-c",
      upgrade = true,
    },
    {
      name = "ei-dielectric-rupture-1",
      age = "quantum-age",
      count = 1300,
      icon = TECH_ICON.dielectric,
      prerequisites = {
        "ei-waveform-harmonics-3",
        "ei-quantum-age",
        "tl-single-zap-probability-technology-5",
        "tl-single-zap-count-technology-5",
        "tl-flames-explosion-technology-5",
      },
      effects = {
        {type = "ammo-damage", ammo_category = "tl-advanced-tesla-coil-turret-category", modifier = 0.08},
        {type = "gun-speed", ammo_category = "tl-advanced-tesla-coil-turret-category", modifier = 0.02},
        make_modifier_effect(TECH_ICON.dielectric, "modifier-description.ei-dielectric-rupture-1-effect"),
      },
      order = "e-j-z-e-a",
      upgrade = true,
    },
    {
      name = "ei-dielectric-rupture-2",
      age = "quantum-age",
      count = 1900,
      icon = TECH_ICON.dielectric,
      prerequisites = {"ei-dielectric-rupture-1"},
      effects = {
        {type = "ammo-damage", ammo_category = "tl-advanced-tesla-coil-turret-category", modifier = 0.10},
        {type = "gun-speed", ammo_category = "tl-advanced-tesla-coil-turret-category", modifier = 0.02},
        make_modifier_effect(TECH_ICON.dielectric, "modifier-description.ei-dielectric-rupture-2-effect"),
      },
      order = "e-j-z-e-b",
      upgrade = true,
    },
    {
      name = "ei-dielectric-rupture-3",
      age = "quantum-age",
      count = 2600,
      icon = TECH_ICON.dielectric,
      prerequisites = {"ei-dielectric-rupture-2"},
      effects = {
        {type = "ammo-damage", ammo_category = "tl-advanced-tesla-coil-turret-category", modifier = 0.12},
        {type = "gun-speed", ammo_category = "tl-advanced-tesla-coil-turret-category", modifier = 0.03},
        make_modifier_effect(TECH_ICON.dielectric, "modifier-description.ei-dielectric-rupture-3-effect"),
      },
      order = "e-j-z-e-c",
      upgrade = true,
    },
    {
      name = "ei-bridge-coupling-1",
      age = "quantum-age",
      count = 1250,
      icon = TECH_ICON.bridge,
      icon_size = 256,
      prerequisites = {
        "ei-waveform-harmonics-3",
        "ei-quantum-age",
        "tesla-weapons",
        "electric-weapons-damage-4",
      },
      effects = {
        {type = "ammo-damage", ammo_category = LEGACY_FAMILY_CATEGORY, modifier = 0.10},
        {type = "ammo-damage", ammo_category = LEGACY_TURRET_CATEGORY, modifier = 0.10},
        make_modifier_effect(TECH_ICON.bridge, "modifier-description.ei-bridge-coupling-1-effect"),
      },
      order = "e-j-z-f-a",
      upgrade = true,
    },
    {
      name = "ei-bridge-coupling-2",
      age = "quantum-age",
      count = 1850,
      icon = TECH_ICON.bridge,
      icon_size = 256,
      prerequisites = {"ei-bridge-coupling-1"},
      effects = {
        {type = "ammo-damage", ammo_category = LEGACY_FAMILY_CATEGORY, modifier = 0.10},
        {type = "ammo-damage", ammo_category = LEGACY_TURRET_CATEGORY, modifier = 0.20},
        make_modifier_effect(TECH_ICON.bridge, "modifier-description.ei-bridge-coupling-2-effect"),
      },
      order = "e-j-z-f-b",
      upgrade = true,
    },
  }

  for _, spec in pairs(quantum_specs) do
    append_unique(technologies, create_doctrine_technology(spec))
  end

  local fusion_specs = {
    {
      name = "ei-reactance-overdrive-1",
      age = "fusion-quantum-age",
      count = 1700,
      icon = TECH_ICON.reactance,
      prerequisites = {
        "tl-tesla-tank-technology",
        "ei-fusion-data",
        "tl-volatility-modulation-technology-5",
        "tl-volatility-probability-technology-5",
      },
      effects = {
        {type = "ammo-damage", ammo_category = "tl-tesla-coil-ammo-category", modifier = 0.15},
        {type = "gun-speed", ammo_category = "tl-tesla-coil-ammo-category", modifier = 0.05},
        make_modifier_effect(TECH_ICON.reactance, "modifier-description.ei-reactance-overdrive-1-effect"),
      },
      order = "e-j-z-g-a",
      upgrade = true,
    },
    {
      name = "ei-reactance-overdrive-2",
      age = "fusion-quantum-age",
      count = 2300,
      icon = TECH_ICON.reactance,
      prerequisites = {"ei-reactance-overdrive-1"},
      effects = {
        {type = "ammo-damage", ammo_category = "tl-tesla-coil-ammo-category", modifier = 0.20},
        {type = "gun-speed", ammo_category = "tl-tesla-coil-ammo-category", modifier = 0.05},
        make_modifier_effect(TECH_ICON.reactance, "modifier-description.ei-reactance-overdrive-2-effect"),
      },
      order = "e-j-z-g-b",
      upgrade = true,
    },
    {
      name = "ei-reactance-overdrive-3",
      age = "fusion-quantum-age",
      count = 3000,
      icon = TECH_ICON.reactance,
      prerequisites = {"ei-reactance-overdrive-2"},
      effects = {
        {type = "ammo-damage", ammo_category = "tl-tesla-coil-ammo-category", modifier = 0.25},
        {type = "gun-speed", ammo_category = "tl-tesla-coil-ammo-category", modifier = 0.10},
        make_modifier_effect(TECH_ICON.reactance, "modifier-description.ei-reactance-overdrive-3-effect"),
      },
      order = "e-j-z-g-c",
      upgrade = true,
    },
  }

  for _, spec in pairs(fusion_specs) do
    append_unique(technologies, create_doctrine_technology(spec))
  end

  append_unique(technologies, create_doctrine_technology({
    name = "ei-exotic-waveform-convergence",
    age = "exotic-age",
    count = 4200,
    icon = TECH_ICON.exotic,
    icon_size = 256,
    prerequisites = {
      "ei-exotic-age",
      "ei-storm-lattice-3",
      "ei-dielectric-rupture-3",
      "ei-bridge-coupling-2",
    },
    effects = {make_modifier_effect(TECH_ICON.exotic, "modifier-description.ei-exotic-waveform-convergence-effect")},
    order = "e-j-z-h",
    upgrade = false,
  }))

  local filtered = {}
  for _, technology in pairs(technologies) do
    if technology then
      filtered[#filtered + 1] = technology
    end
  end

  if #filtered > 0 then
    data:extend(filtered)
  end
end


-- Some generic EI data-update passes run after the vendored TL technology files
-- are created and can legitimately touch ages or packs as part of broader tech
-- restructuring. Reapply the Tesla-direct mapping here, late in Tesla's own
-- overlay, so the branch finishes data-updates in the exact age buckets we
-- want without going back to ingredient-based inference.
local function set_tesla_technology_layout(name, age, extra_ingredients)
  local technology = raw.technology[name]
  if not technology or not technology.unit then
    return
  end

  technology.age = age
  technology.unit.ingredients = make_age_ingredients(age, extra_ingredients)
  technology.icon_size = technology.icon_size or 128
  if technology.icon_mipmaps == nil or technology.icon_mipmaps == 0 then
    technology.icon_mipmaps = 4
  end
end

local function set_tesla_technology_range(prefix, first_level, last_level, age, extra_ingredients)
  for level = first_level, last_level do
    set_tesla_technology_layout(prefix .. level, age, extra_ingredients)
  end
end

local function reassert_tesla_technology_layouts()
  -- Root technologies define the two major Tesla branches.
  set_tesla_technology_layout("tl-basic-tesla-coils-technology", "electricity-age")
  set_tesla_technology_layout("tl-advanced-tesla-coils-technology", "advanced-computer-age")
  set_tesla_technology_layout("tl-tesla-tank-technology", "advanced-computer-age")

  -- Basic-coil branch families.
  set_tesla_technology_range("tl-tesla-coil-shooting-speed-", 1, 5, "electricity-age")
  set_tesla_technology_layout("tl-tesla-coil-shooting-speed-6", "advanced-computer-age")
  set_tesla_technology_layout("tl-tesla-coil-shooting-speed-7", "advanced-computer-age-space")

  set_tesla_technology_range("tl-multi-zap-probability-technology-", 1, 4, "electricity-age")
  set_tesla_technology_range("tl-multi-zap-damage-technology-", 1, 4, "electricity-age")
  set_tesla_technology_range("tl-multi-zap-range-technology-", 1, 4, "electricity-age")
  set_tesla_technology_layout("tl-multi-zap-probability-technology-5", "advanced-computer-age")
  set_tesla_technology_layout("tl-multi-zap-damage-technology-5", "advanced-computer-age")
  set_tesla_technology_layout("tl-multi-zap-range-technology-5", "advanced-computer-age")

  set_tesla_technology_range("tl-slowdown-probability-technology-", 1, 5, "electricity-age")
  set_tesla_technology_range("tl-slowdown-duration-technology-", 1, 5, "electricity-age")
  set_tesla_technology_range("tl-slowdown-multiplier-technology-", 1, 4, "electricity-age")
  set_tesla_technology_layout("tl-slowdown-multiplier-technology-5", "advanced-computer-age")

  -- Advanced-coil branch families.
  set_tesla_technology_range("tl-tesla-coil-damage-technology-", 1, 6, "advanced-computer-age")
  set_tesla_technology_layout("tl-tesla-coil-damage-technology-7", "advanced-computer-age-space")

  set_tesla_technology_range("tl-single-zap-probability-technology-", 1, 5, "advanced-computer-age")
  set_tesla_technology_range("tl-single-zap-damage-technology-", 1, 5, "advanced-computer-age")
  set_tesla_technology_range("tl-single-zap-count-technology-", 1, 5, "advanced-computer-age")

  set_tesla_technology_range("tl-flames-probability-technology-", 1, 5, "advanced-computer-age")
  set_tesla_technology_range("tl-flames-count-technology-", 1, 5, "advanced-computer-age")
  set_tesla_technology_range("tl-flames-explosion-technology-", 1, 5, "advanced-computer-age")

  -- Tank branch families.
  set_tesla_technology_range("tl-tesla-ammo-upgrade-technology-", 1, 6, "advanced-computer-age")
  set_tesla_technology_layout("tl-tesla-ammo-upgrade-technology-7", "advanced-computer-age-space")
  set_tesla_technology_range("tl-volatility-modulation-technology-", 1, 5, "advanced-computer-age")
  set_tesla_technology_range("tl-volatility-probability-technology-", 1, 5, "advanced-computer-age")

  -- Shared modernization spine.
  set_tesla_technology_range("ei-waveform-harmonics-", 1, 3, "advanced-computer-age-space", {{"electromagnetic-science-pack", 1}})

  -- Late doctrine families.
  set_tesla_technology_range("ei-storm-lattice-", 1, 3, "quantum-age")
  set_tesla_technology_range("ei-dielectric-rupture-", 1, 3, "quantum-age")
  set_tesla_technology_range("ei-bridge-coupling-", 1, 2, "quantum-age")
  set_tesla_technology_range("ei-reactance-overdrive-", 1, 3, "fusion-quantum-age")
  set_tesla_technology_layout("ei-exotic-waveform-convergence", "exotic-age")
end

-- These progression patches keep TL's public names but move the line into EI's own age and
-- recipe structure so it feels native instead of hanging off the side as an external ladder.
local function patch_tl_progression()
  local tesla_weapons = raw.technology["tesla-weapons"]
  if tesla_weapons then
    tesla_weapons.localised_name = {"technology-name.ei-tesla-weapons"}
    tesla_weapons.localised_description = {"technology-description.ei-tesla-weapons"}
    ei_lib.add_prerequisite("tesla-weapons", "tl-advanced-tesla-coils-technology")
  end

  if raw.technology["tl-advanced-tesla-coils-technology"] then
    ei_lib.add_prerequisite("tl-advanced-tesla-coils-technology", "ei-advanced-computer-age-tech")
    ei_lib.add_prerequisite("tl-advanced-tesla-coils-technology", "ei-electronic-parts")
  end

  local advanced_tesla_coil = raw.recipe["tl-advanced-tesla-coil"]
  if advanced_tesla_coil then
    advanced_tesla_coil.additional_categories = advanced_tesla_coil.additional_categories or {}
    append_unique(advanced_tesla_coil.additional_categories, "electromagnetics")
    advanced_tesla_coil.ingredients = {
      {type = "item", name = "tl-basic-tesla-coil", amount = 1},
      {type = "item", name = "substation", amount = 2},
      {type = "item", name = "accumulator", amount = 2},
      {type = "item", name = "copper-cable", amount = 200},
      {type = "item", name = "ei-electronic-parts", amount = 10},
      {type = "item", name = "steel-plate", amount = 40},
    }
  end

  local basic_tesla_coil = raw.recipe["tl-basic-tesla-coil"]
  if basic_tesla_coil then
    basic_tesla_coil.additional_categories = basic_tesla_coil.additional_categories or {}
    append_unique(basic_tesla_coil.additional_categories, "electromagnetics")
    basic_tesla_coil.ingredients = {
      {type = "item", name = "medium-electric-pole", amount = 1},
      {type = "item", name = "ei-copper-beam", amount = 2},
      {type = "item", name = "copper-cable", amount = 50},
      {type = "item", name = "electronic-circuit", amount = 5},
      {type = "item", name = "battery", amount = 3},
    }
  end

  if raw.technology["tl-tesla-tank-technology"] then
    ei_lib.add_prerequisite("tl-tesla-tank-technology", "ei-advanced-computer-age-tech")
    ei_lib.add_prerequisite("tl-tesla-tank-technology", "ei-carbon-manipulation")
  end

  local tesla_tank_recipe = raw.recipe["tl-tesla-tank"]
  if tesla_tank_recipe then
    tesla_tank_recipe.additional_categories = tesla_tank_recipe.additional_categories or {}
    append_unique(tesla_tank_recipe.additional_categories, "electromagnetics")
    tesla_tank_recipe.ingredients = {
      {type = "item", name = "tank", amount = 1},
      {type = "item", name = "ei-electronic-parts", amount = 20},
      {type = "item", name = "accumulator", amount = 20},
      {type = "item", name = "ei-advanced-motor", amount = 50},
      {type = "item", name = "ei-carbon", amount = 40},
      {type = "item", name = "tl-advanced-tesla-coil", amount = 2},
    }
  end

  local tesla_tank = raw.car["tl-tesla-tank"]
  if tesla_tank then
    tesla_tank.inventory_size = 16
    tesla_tank.max_health = tl_settings.vehicle.tank.health

    local fuel_categories = tesla_tank.energy_source and tesla_tank.energy_source.fuel_categories
    if fuel_categories then
      for _, fuel_category in pairs(EXTRA_FUELS) do
        append_unique(fuel_categories, fuel_category)
      end
    end
  end

  add_recipe_ingredient("tesla-turret", {
    type = "item",
    name = "tl-advanced-tesla-coil",
    amount = 1,
  })
end

-- Single overlay entrypoint so `scripts/data-updates/teslas-legacy.lua` can stay as a tiny
-- require-only shim and the vendored tree remains easy to diff against upstream later.
local function apply_overlay()
  if not raw.technology["tl-basic-tesla-coils-technology"] then
    return
  end

  ensure_ammo_category(LEGACY_FAMILY_CATEGORY)
  ensure_ammo_category(LEGACY_TURRET_CATEGORY)

  patch_tl_progression()
  patch_tl_helpers()
  patch_basic_tl_beams()
  patch_advanced_tl_turret()
  patch_tl_tank_ammo()
  create_bridge_prototypes()
  create_doctrine_prototypes()
  patch_bridge_weapons()
  split_electric_weapons_damage_repeatable()
  mirror_existing_effects()
  add_doctrine_technologies()
  reassert_tesla_technology_layouts()
end

apply_overlay()

return {
  categories = {
    family = LEGACY_FAMILY_CATEGORY,
    turret = LEGACY_TURRET_CATEGORY,
  },
  effects = EFFECT_ID,
}

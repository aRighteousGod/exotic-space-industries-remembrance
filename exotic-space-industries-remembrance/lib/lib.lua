--==============================================================================
-- ESIR FILE MAP
-- owns: runtime module: lib
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: on-demand helper calls
-- forwarded_events: add_item_level, add_prerequisite, add_unlock_recipe, clamp, clean_nils, config, contains, convert_short_ingredients_to_full, copy_science_packs, crystal_echo, crystal_echo_floating, debug_crafting_categories, disable, do_fluid_merge, do_item_merge, empty_sprite, enable, enable_from_start, endswith, entity_check, entity_icon_scaler, fix_recipe, format_echo, generate_crystal_gradient_stops, get_adjective_and_tint, get_box_area, get_entity_area, get_entity_area_change, get_entity_unit_number, get_event_tick, get_player_setting_value, get_random_different_value, get_valid_entity, getn, hex_to_rgb_normalized, hex_to_rgb_raw, is_valid_number, lerp_color, make_4way_animation_from_spritesheet, make_circuit_connector, merge_fluid, merge_item, modify_data_raw, notify_connected_players, overwrite_description, overwrite_entity_and_description, overwrite_entity_name, patch_nested_value, pick_gradient_stops, pick_tint_from_intent, player_allows_notification, recipe_add, recipe_hard_overwrite, recipe_new, recipe_output_add, recipe_remove, recipe_swap, recursive_copy, recursive_insert, remove_prerequisite, remove_tech, remove_tech_ingredient, remove_unlock_recipe, rgb_to_hex, sb, set_age_packs, set_prerequisites, set_properties, set_science_packs, starts_with, startswith, strike_lightning, switch_string, table_contains_value, table_to_string, unique_values_only
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: owner-specific behavior changes
--==============================================================================
-- commonly used functions for the mod

local ei_lib = {}
local quality_level_bounds_cache = nil

--====================================================================================================
--FUNCTIONS
--====================================================================================================

function ei_lib.endswith(str,suf) return str:sub(-string.len(suf)) == suf end
function ei_lib.startswith(text, prefix)
    if type(prefix) ~= "string" then
        return false
    end

    return string.find(text or "", prefix, 1, true) == 1
end
ei_lib.starts_with = ei_lib.startswith
function ei_lib.contains(s, word) return tostring(s):find(word, 1, true) ~= nil end
function ei_lib.sb(s) error(serpent.block(s)) end

function ei_lib.is_valid_number(x)
    return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

function ei_lib.clean_nils(t)
  local ans = {}
  for _,v in pairs(t) do
    ans[ #ans+1 ] = v
  end
  return ans
end

-- clamp a number into [lo, hi].
function ei_lib.clamp(x, lo, hi)
  if x < lo then return lo end
  if x > hi then return hi end
  return x
end

function ei_lib.entity_check(entity)
    return entity ~= nil and entity.valid == true
end

function ei_lib.get_valid_entity(entity)
    if ei_lib.entity_check(entity) then
        return entity
    end

    return nil
end

function ei_lib.get_entity_unit_number(entity)
    if entity == nil then
        return nil
    end

    local ok, unit_number = pcall(function()
        return entity.unit_number
    end)
    if not ok then
        return nil
    end

    return unit_number
end

--returns input tbl minus duplicates
function ei_lib.unique_values_only(tbl)
    local seen, out = {}, {}
    for _, val in ipairs(tbl) do
        if not seen[val] then
            seen[val] = true
            table.insert(out, #out+1,val)
        end
    end
    return out
end

function ei_lib.table_contains_value(table_in, value)
    for i,v in pairs(table_in) do
        if v == value then
            return true
        end
    end
    return false
end

function ei_lib.upsert_resistance(prototype, resistance)
    if type(prototype) ~= "table" or type(resistance) ~= "table" or type(resistance.type) ~= "string" then
        return nil
    end

    prototype.resistances = prototype.resistances or {}
    for _, existing in pairs(prototype.resistances) do
        if type(existing) == "table" and existing.type == resistance.type then
            return existing
        end
    end

    local inserted = table.deepcopy(resistance)
    table.insert(prototype.resistances, inserted)
    return inserted
end

--Look through a nested table and set a value at a given path
function ei_lib.patch_nested_value(root, path_str, new_value)
  -- Split the path string into keys (supports dot and bracket notation)
  local keys = {}
  for part in string.gmatch(path_str, "[^%.%[%]]+") do
    local num = tonumber(part)
    table.insert(keys, num or part)
  end

  -- Traverse the table
  local ref = root
  for i = 1, #keys - 1 do
    ref = ref[keys[i]]
    if not ref then
      log("🛑 ei_lib.patch_nested_value failed at key: " .. tostring(keys[i]))
      return false
    end
  end

  -- Set the final value
  local final_key = keys[#keys]
  ref[final_key] = new_value
  return true
end

--Pick a value from table other than the previous
function ei_lib.get_random_different_value(tbl, previous, entropy1, entropy2, entropy3, entropy4)
    if not tbl then return end

    -- Convert table values into an array, excluding previous
    local values = {}
    for _, v in pairs(tbl) do
        if v ~= previous then
            table.insert(values, v)
        end
    end

    if #values == 1 then return values[1] end -- no choice

    local choice
    local entropy = 0
    repeat
        choice = values[ei_rng.int(tostring(tbl), 1, #values,entropy1, entropy2, entropy3, (entropy4 or 0)+ entropy)]
        entropy = entropy + 1
    until choice ~= previous

    return choice
end

--turn a table into one contiguous string with optional indent spacing
function ei_lib.table_to_string(tbl, indent)
    if not tbl then
        log("table_to_string got null table")
        return
    end
    indent = indent or 0
    local lines = {}
    local prefix = string.rep("  ", indent)
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            table.insert(lines, prefix .. tostring(k) .. " = {")
            table.insert(lines, table_to_string(v, indent + 1))
            table.insert(lines, prefix .. "}")
        else
            table.insert(lines, prefix .. tostring(k) .. " = " .. tostring(v))
        end
    end
    return table.concat(lines, "\n")
end

-- emulate switch-case in Lua for checking given string with a list of strings
-- retruns the matched element of the switch_table or nil if no match was found
-- switch_table = { ["string_condition"] = return vale, ... }

function ei_lib.switch_string(switch_table, string)
    
    -- retrun if no switch_table is given or no string is given
    if not switch_table or not string then
        return nil
    end

    -- loop over switch_table and check if string is in it
    for i,v in pairs(switch_table) do
        if string == i then
            return v
        end
    end

    -- return nil if no match was found
    return nil
end

function ei_lib.get_event_tick(event)
    if type(event) == "number" then
        return event
    end

    if type(event) == "table" then
        return event.tick or 0
    end

    return 0
end

-- quick access to startup settings
function ei_lib.config(name)
    local setting = settings.startup["ei-" .. name]
    if not setting then
      log("ei_lib.config: Setting 'ei-" .. name .. "' not found.")
      return false
    end

    local val = setting.value

    if type(val) == "boolean" or type(val) == "number" or type(val) == "string" then
        return val
    else
        return false -- Unknown or unsupported type
    end
end


-- count how many keys are in a table
function ei_lib.getn(table_in)
    if not table_in then return 0 end
    local count = 0
    for _,_ in pairs(table_in) do
        count = count + 1
    end
    return count
end

function ei_lib.count_sequence(tbl, sparse_fallback)
    if type(tbl) ~= "table" then
        return 0
    end

    if #tbl > 0 or not sparse_fallback then
        return #tbl
    end

    return ei_lib.getn(tbl)
end

function ei_lib.get_surface_index(surface)
    return surface and surface.index or nil
end

function ei_lib.get_chunk_coordinate(tile_coordinate, chunk_size)
    if not ei_lib.is_valid_number(chunk_size) or chunk_size == 0 then
        return nil
    end

    return math.floor(tile_coordinate / chunk_size)
end

function ei_lib.get_chunk_coordinates(position, chunk_size)
    if not position then
        return nil, nil
    end

    return ei_lib.get_chunk_coordinate(position.x, chunk_size), ei_lib.get_chunk_coordinate(position.y, chunk_size)
end

function ei_lib.get_chunk_coverage(position, radius, chunk_size)
    if not position then
        return nil, nil, nil, nil
    end

    radius = radius or 0
    return ei_lib.get_chunk_coordinate(position.x - radius, chunk_size),
        ei_lib.get_chunk_coordinate(position.x + radius, chunk_size),
        ei_lib.get_chunk_coordinate(position.y - radius, chunk_size),
        ei_lib.get_chunk_coordinate(position.y + radius, chunk_size)
end

function ei_lib.is_within_range_squared(source_position, target_position, max_range_sqr)
    if not source_position or not target_position then
        return false
    end

    local delta_x = source_position.x - target_position.x
    local delta_y = source_position.y - target_position.y
    return (delta_x * delta_x + delta_y * delta_y) <= max_range_sqr
end

function ei_lib.get_item_prototypes()
    if prototypes and prototypes.item then
        return prototypes.item
    end

    if game and game.item_prototypes then
        return game.item_prototypes
    end
end

function ei_lib.get_quality_prototypes()
    if prototypes and prototypes.quality then
        return prototypes.quality
    end

    if game and game.quality_prototypes then
        return game.quality_prototypes
    end
end

function ei_lib.get_quality_level_bounds(force_refresh)
    if not force_refresh and quality_level_bounds_cache then
        return quality_level_bounds_cache.min_level, quality_level_bounds_cache.max_level
    end

    local min_level = 1
    local max_level = 1
    local found_level = false
    local quality_prototypes = ei_lib.get_quality_prototypes()

    if quality_prototypes then
        for _, quality in pairs(quality_prototypes) do
            local level = quality.level
            if ei_lib.is_valid_number(level) then
                if not found_level then
                    min_level = level
                    max_level = level
                    found_level = true
                else
                    min_level = math.min(min_level, level)
                    max_level = math.max(max_level, level)
                end
            end
        end
    end

    quality_level_bounds_cache = {
        min_level = min_level,
        max_level = max_level
    }

    return min_level, max_level
end

function ei_lib.get_normalized_quality_factor(entity_or_stack)
    if not entity_or_stack then
        return 0
    end

    local quality = entity_or_stack.quality
    local level = quality and quality.level or nil
    if not ei_lib.is_valid_number(level) then
        return 0
    end

    local min_level, max_level = ei_lib.get_quality_level_bounds()
    if not ei_lib.is_valid_number(min_level) or not ei_lib.is_valid_number(max_level) or max_level <= min_level then
        return 0
    end

    return ei_lib.clamp((level - min_level) / (max_level - min_level), 0, 1)
end

function ei_lib.try_get_stack_field(item_stack, getter)
    local ok, value = pcall(getter, item_stack)
    if ok then
        return value
    end

    return nil
end

function ei_lib.copy_localised_string(value)
    if type(value) == "table" then
        return table.deepcopy(value)
    end

    return value
end

function ei_lib.get_quality_name(item_like, default_quality)
    if not item_like then
        return default_quality
    end

    local quality = ei_lib.try_get_stack_field(item_like, function(stack)
        local stack_quality = stack.quality
        if type(stack_quality) == "table" and stack_quality.name then
            return stack_quality.name
        end
        return stack_quality
    end)

    if quality ~= nil then
        return quality
    end

    return default_quality
end

function ei_lib.make_item_with_quality_id(item_like, default_quality)
    if not item_like then
        return nil
    end

    if item_like.valid_for_read ~= nil and not item_like.valid_for_read then
        return nil
    end

    if not item_like.name then
        return nil
    end

    local item_with_quality = {
        name = item_like.name
    }

    local quality = ei_lib.get_quality_name(item_like, default_quality)
    if quality then
        item_with_quality.quality = quality
    end

    return item_with_quality
end

function ei_lib.make_item_stack_definition(item_stack, count)
    if not item_stack or not item_stack.valid_for_read then
        return nil
    end

    local stack_definition = ei_lib.make_item_with_quality_id(item_stack) or {name = item_stack.name}
    stack_definition.count = count or item_stack.count

    local health = ei_lib.try_get_stack_field(item_stack, function(stack) return stack.health end)
    if health ~= nil then
        stack_definition.health = health
    end

    local durability = ei_lib.try_get_stack_field(item_stack, function(stack) return stack.durability end)
    if durability ~= nil then
        stack_definition.durability = durability
    end

    local ammo = ei_lib.try_get_stack_field(item_stack, function(stack) return stack.ammo end)
    if ammo ~= nil then
        stack_definition.ammo = ammo
    end

    local spoil_percent = ei_lib.try_get_stack_field(item_stack, function(stack) return stack.spoil_percent end)
    if spoil_percent ~= nil then
        stack_definition.spoil_percent = spoil_percent
    end

    local tags = ei_lib.try_get_stack_field(item_stack, function(stack) return stack.tags end)
    if tags ~= nil then
        stack_definition.tags = table.deepcopy(tags)
    end

    local custom_description = ei_lib.try_get_stack_field(item_stack, function(stack) return stack.custom_description end)
    if custom_description ~= nil then
        stack_definition.custom_description = ei_lib.copy_localised_string(custom_description)
    end

    return stack_definition
end

function ei_lib.entity_can_take_health_damage(entity)
    if not entity or not entity.valid then
        return false
    end

    local ok, health = pcall(function()
        return entity.health
    end)

    return ok and health ~= nil
end
-- Use ei_lib.raw to access this
--- Modifies a prototype in `data.raw` using one of three modes:
--- 1. Recursively merges fields from `properties` (default behavior)
--- 2. Replaces the prototype entirely if `properties.force_replace` is true
--- 3. Executes a custom `func(prototype, properties)` if provided
---
--- Fields in `properties` beginning with "_" will be ignored during merge.
--- Logs an error if the category or name do not exist in `data.raw`.
---
--- @param category string               The prototype category, e.g., "item", "recipe", etc.
--- @param name string                   The name of the prototype to modify.
--- @param properties table              The table of fields to apply. Can include `force_replace` to override the prototype.
--- @param func fun(prototype: table, properties: table) | nil
---     Optional callback that receives the prototype and properties table directly for custom mutation.
---
--- @return nil
function ei_lib.modify_data_raw(category, name, properties, func)
    -- Check if the category exists
    if not data.raw[category] then
        log("ei_lib.modify_data_raw: Category '" .. category .. "' does not exist.")
        return
    end
    -- Check if the name exists in the category
    if not data.raw[category][name] then
        log("ei_lib.modify_data_raw: Name '" .. name .. "' does not exist in category '" .. category .. "'.")
        return
    end
    -- func? is it weally?
    if func and type(func) ~= "function" then
        log("ei_lib.modify_data_raw: Provided func is not a function.")
        return
    end

    if not func and not properties.force_replace and not properties.force_insert then
      -- Update the properties of the prototype
      ei_lib.recursive_copy(data.raw[category][name], properties)
    elseif not func and properties.force_insert then --for ie crafting_categories
      properties.force_insert = nil
      ei_lib.recursive_insert(data.raw[category][name], properties)
    elseif not func and properties.force_replace then
      properties.force_replace = nil
      for key,value in pairs(properties) do
      -- Force replace the prototype with the new properties
        data.raw[category][name][key] = value
      end
    elseif func then
      -- Call the provided function with the prototype
      func(data.raw[category][name], properties)
    end
end

--- @alias PrototypeCategory
--- | "item"
--- | "recipe"
--- | "technology"
--- | "entity"
--- | "electric-turret"
--- | "assembling-machine"
--- | "fluid"
--- | "ammo"
--- | "module"
--- | "tool"
--- | "tile"
--- | string  # Any other valid `data.raw` category

--- @alias PrototypeName string
--- @alias Prototype table<string, any>

--- @class RawProxyCategory
--- @field [PrototypeName] Prototype | nil
---        Access to a specific prototype in a category. Returns nil if not found, with logging.

--- @class RawProxy
--- @field [PrototypeCategory] RawProxyCategory
---        Proxy table for a given prototype category, supports read and write with logging.
---        - `ei_lib.raw["item"]["ei-core"]`: read
---        - `ei_lib.raw["recipe"]["ei-fusion"] = {enabled = false}`: write (uses `modify_data_raw`)

--- A proxy interface for safely interacting with `data.raw` via `ei_lib.raw`.
--- Read:
---   - Returns prototype if it exists.
---   - Logs if category or name is missing.
---
--- Write:
---   - Routes to `ei_lib.modify_data_raw`.
---   - Logs if target category/prototype does not exist.
---   - Skips invalid assignments.
---
--- Example:
--- ```lua
--- ei_lib.raw["item"]["ei-core"].stack_size = 200
--- ei_lib.raw["recipe"]["ei-infusion"] = { energy_required = 20 }
--- ```
--- @type RawProxy

ei_lib.raw = setmetatable({}, {
  __index = function(_, category)
    return setmetatable({}, {
      __index = function(_, name)
        local cat = data.raw[category]
        if not cat then
          log("ei_lib.raw: ❌ Category '" .. category .. "' does not exist.")
          return nil
        end
        local proto = cat[name]
        if not proto then
          log("ei_lib.raw: ❌ Prototype '" .. name .. "' missing in category '" .. category .. "'.")
          return nil
        end
        return proto
      end,

      __newindex = function(_, name, properties)
        local cat = data.raw[category]
        if not cat then
          log("ei_lib.raw: ❌ Cannot modify. Category '" .. category .. "' does not exist.")
          return
        end
        if not cat[name] then
          log("ei_lib.raw: ❌ Cannot modify. Prototype '" .. name .. "' missing in category '" .. category .. "'.")
          return
        end
        ei_lib.modify_data_raw(category, name, properties)
      end
    })
  end
})


--====================================================================================================
--DESCRIPTION AND NAME RELATED
--====================================================================================================
---@param target_name string         -- The name of the entity prototype to rename
---@param target_type string         -- The type of the entity prototype (e.g., "electric-turret")
---@param new_name string            -- New name to assign (leave blank to look in name_alt in the .cfg)
---@param new_description string     -- New description to assign (leave blank to look in name_alt in the .cfg)

function ei_lib.overwrite_entity_and_description(target_name,target_type,new_name,new_description)
  ei_lib.overwrite_entity_name(target_name, target_type, new_name)
  ei_lib.overwrite_description(target_name, target_type, new_description)
end
function ei_lib.overwrite_entity_name(entity_name, entity_type, new_name)
    -- test if item exists in data.raw.item
    if not entity_name then
        log("ei_lib.overwrite_item_name: entity_name is not defined")
        return
    end
    if not entity_type then
        log("ei_lib.overwrite_item_name: entity_type is not defined for item "..entity_name)
        return
    end
    --default to looking for localized item-name_alt in cfg
    if not data.raw[entity_type] or not data.raw[entity_type][entity_name] then
        log("ei_lib.overwrite_item_name: entity "..entity_name.." does not exist in data.raw."..entity_type)
        return
    end
    if not new_name and entity_type ~= "technology" and entity_type ~= "item" and entity_type ~= "ammo" then    --default to looking for localized item-name_alt in cfg
      data.raw[entity_type][entity_name].localised_name =  {"entity-name." .. entity_name .. "_alt"}
    elseif not new_name and entity_type == "item" or entity_type == "ammo" then
      data.raw[entity_type][entity_name].localised_name = {"item-name." .. entity_name .. "_alt"}
    elseif not new_name and entity_type == "technology" then
      data.raw[entity_type][entity_name].localised_name = {"technology-name." .. entity_name .. "_alt"}
    elseif new_name then --otherwise you can force it and skip localization
      data.raw[entity_type][entity_name].localised_name = new_name
    else
        log("ei_lib.overwrite_entity_name: undefined exception occurred for "..entity_name)
    end
end

function ei_lib.overwrite_description(target, target_type, new_description)
    -- test if item exists in data.raw.item
    if not target then
        log("ei_lib.overwrite_description: target is not defined")
        return
    end
    if not target_type then
        log("ei_lib.overwrite_description: target_type is not defined for item "..target)
        return
    end
    --default to looking for localized item-description_alt in cfg
    if not data.raw[target_type] or not data.raw[target_type][target] then
        log("ei_lib.overwrite_description: target "..target.." does not exist in data.raw."..target_type)
        return
    end
    if not new_description and target_type ~= "technology" and target_type ~= "item" and target_type ~= "ammo" then    --default to looking for localized item-name_alt in cfg
      data.raw[target_type][target].localised_description =  {"entity-description." .. target .. "_alt"}
    elseif not new_description and target_type == "item" or target_type == "ammo" then
      data.raw[target_type][target].localised_description = {"item-description." .. target .. "_alt"}
    elseif not new_description and target_type == "technology" then
      data.raw[target_type][target].localised_description = {"technology-description." .. target .. "_alt"}
    elseif new_description then --otherwise you can force it and skip localization
      data.raw[target_type][target].localised_description = new_description
    else
        log("ei_lib.overwrite_target: undefined exception occurred for "..target)
    end
end

--RECIPE RELATED
------------------------------------------------------------------------------------------------------

-- change ingredient in a recipe for another
function ei_lib.recipe_swap(recipe, old_ingredient, new_ingredient, amount, results)
    -- return if recipe or old_ingredient or new_ingredient is not given
    if not recipe or not old_ingredient or not new_ingredient then
        return
    end

    -- test if recipe exists in data.raw.recipe
    if not data.raw.recipe[recipe] then
        log("recipe "..recipe.." does not exist in data.raw.recipe")
        return
    end
    --input or output
    local target = "ingredients"
    if results then
      target = "results"
    end
    target = data.raw.recipe[recipe][target]
    --validate
    if not target then
      log("recipe "..recipe.." had invalid target")
      return
    end
  
    -- check if amount is given
    if not amount then
        
        -- if we got an amount of old_ingredient in the recipe
        -- set amount to that amount
        for i,v in pairs(target or {}) do
            local item_amount = v[2] or v["amount"]
            local item_name = v[1] or v["name"]
            if item_name == old_ingredient then
                amount = item_amount
            end
        end

        -- if amount is still nil, set it to 1
        if not amount then
            amount = 1
        end
    end

    -- loop over all ingredients of the recipe
    for i,v in pairs(target or {}) do

        local item_amount = v[2] or v["amount"]
        local item_name = v[1] or v["name"]

        -- if ingredient is found, replace it
        -- here first index is ingredient name, second index is amount
        if item_name == old_ingredient then
            if v["name"] then
                target[i]["name"] = new_ingredient
                target[i]["amount"] = amount
            else
                target[i][1] = new_ingredient
                target[i][2] = amount
            end
        end

        ei_lib.fix_recipe(recipe, results)
    end
end


-- fix recipes for multiple ingredients
function ei_lib.fix_recipe(recipe,results)
    -- look if an ingredient is multiple times in the recipe, if so, add the amounts
    local ingredients = {}
    local target = "ingredients"
    if results then
      target = "results"
    end
    target = data.raw.recipe[recipe][target]
    if not target then
      log("fix recipe got invalid target for "..recipe)
      return
    end

    if not target[1] then
        return
    end

    -- loop over all ingredients
    for i,v in ipairs(target) do
        local total_amount = v[2] or v["amount"] or 1
        for j,x in ipairs(target) do
            -- exclude same index
            if i ~= j then

                -- if is entry for the same ingredient
                if (v["name"] == x["name"] and v["name"]) or (v[1] == x[1] and v[1]) then
                    if x["amount"] then
                        total_amount = total_amount + x["amount"]
                    else
                        total_amount = total_amount + x[2]
                    end
                    
                    table.remove(target, j)
                end
            end
        end
        if v[2] then
            v[2] = total_amount
        else
            v["amount"] = total_amount
        end
    end

end


-- add new ingredient with variability to recipe output (made for ash, slag, trace mineral chunks)
--[[]
args = {["recipe"],["type"],["ingredient"],["amountmin"],
["amountmax"],["probability"],["fluid"],["allowproductivity"]}
]]
function ei_lib.recipe_output_add(args)
    if not args then log("no args") return end
    local recipe = args.recipe
    -- test if recipe exists in data.raw.recipe
    if not data.raw.recipe[recipe] then
        log("recipe "..recipe.." does not exist in data.raw.recipe")
        return
    end
    local type = args.type

    local ingredient = args.ingredient
    if not ingredient then log("recipe "..recipe.." lacks ingredient") return end
    local amountmin = args.amountmin or 1
    local amountmax = args.amountmax
    local probability = args.probability or 1
    local fluid = args.fluid
    local allowproductivity = args.allowproductivity or false
    -- amount is optional if not give default to 1
    local amount = amountmin or 1
    local amountmax = amountmax or 1
    local _probability = probability or false --boolean by default, 0 -> 1 otherwise
    local allow_productivity = allow_productivity or false
    fluid = fluid or false
    local typus = type
    if not type then
        log("recipe "..recipe.." lacks type, setting to item")
        typus = "item"
        end

    -- add ingredient to recipe

    if fluid then typus = "fluid" end
    if amount and not amountmax and not probability and not allowproductivity then  --guaranteed each time
        table.insert(data.raw.recipe[recipe].results, {type = typus, name = ingredient, amount = amount})
    elseif amountmin and amountmax and probability > 0 and probability < 1 and not allowproductivity then --min_max between
        table.insert(data.raw.recipe[recipe].results, {type = typus, name = ingredient, amount_min = amountmin, amount_max = amountmax})
    elseif amountmin and amountmax and probability > 0 and probability < 1 and not allowproductivity then --min_max between, probability
        table.insert(data.raw.recipe[recipe].results, {type = typus, name = ingredient, amount_min = amountmin, amount_max = amountmax, probability = _probability})
    elseif amountmin and amountmax and probability > 0 and probability < 1 and allowproductivity then--min_max between, probability, affected by productivity
        table.insert(data.raw.recipe[recipe].results, {type = typus, name = ingredient, amount_min = amountmin, amount_max = amountmax, probability = _probability, allow_productivity = allowproductivity})
    else
        log("recipe "..recipe.." ingredient "..ingredient.." probability cannot be 0")
        return
    end
end

-- add new ingredient in recipe
function ei_lib.recipe_add(recipe, ingredient, amount, fluid)
    -- amount is optional if not give default to 1
    amount = amount or 1
    fluid = fluid or false

    -- test if recipe exists in data.raw.recipe
    if not data.raw.recipe[recipe] then
        log("recipe "..recipe.." does not exist in data.raw.recipe")
        return
    end

    -- add ingredient to recipe
    local typus = "item"
    if fluid then typus = "fluid" end

    table.insert(data.raw.recipe[recipe].ingredients, {type = typus, name = ingredient, amount = amount})
end


-- remove ingredient from recipe
function ei_lib.recipe_remove(recipe, ingredient)
    -- test if recipe exists in data.raw.recipe
    if not data.raw.recipe[recipe] then
        log("recipe "..recipe.." does not exist in data.raw.recipe")
        return
    end

    
    -- loop over all ingredients of the recipe
    for i,v in pairs(data.raw.recipe[recipe].ingredients) do

        -- if ingredient is found, remove it
        -- here first index is ingredient name, second index is amount
        if v.name == ingredient then
            table.remove(data.raw.recipe[recipe].ingredients, i)
        end
    end
end

-- set a completly new set of ingredients for recipe
-- opts supports:
--   clear_difficulty_variants = true -> clears legacy normal/expensive tables
--   enabled = boolean -> explicitly sets recipe.enabled
function ei_lib.recipe_new(recipe, table_in, category, opts)
    if type(category) == "table" and opts == nil then
        opts = category
        category = nil
    end

    opts = opts or {}

    -- test if recipe exists in data.raw.recipe
    if not data.raw.recipe[recipe] then
        log("recipe "..recipe.." does not exist in data.raw.recipe")
        return
    end
    if category then
      if data.raw.recipe[recipe].category then
        data.raw.recipe[recipe].category = category
        else
        log("recipe "..recipe.." does not have a category field, cannot set category to "..category)
      end
    end
    if opts.clear_difficulty_variants then
      data.raw.recipe[recipe].normal = nil
      data.raw.recipe[recipe].expensive = nil
    end
    -- set ingredients
    data.raw.recipe[recipe].ingredients = table_in
    if opts.enabled ~= nil then
      data.raw.recipe[recipe].enabled = opts.enabled
    end
end

function ei_lib.make_icons(base_icon, base_size, overlay_icon, overlay_size, overlay_scale, overlay_shift, overlay_tint, options)
    local base_mipmaps
    local overlay_mipmaps
    local base_scale
    local base_shift

    if type(options) == "table" then
        base_mipmaps = options.base_mipmaps or options.icon_mipmaps or options.base_icon_mipmaps
        overlay_mipmaps = options.overlay_mipmaps or options.overlay_icon_mipmaps
        base_scale = options.base_scale
        base_shift = options.base_shift
    end

    local icons = {
        {
            icon = base_icon,
            icon_size = base_size or 64,
            icon_mipmaps = base_mipmaps,
            scale = base_scale,
            shift = base_shift,
        },
    }

    if overlay_icon then
        icons[#icons + 1] = {
            icon = overlay_icon,
            icon_size = overlay_size or 64,
            icon_mipmaps = overlay_mipmaps,
            scale = overlay_scale or 0.45,
            shift = overlay_shift or {8, 8},
            tint = overlay_tint,
        }
    end

    return icons
end

function ei_lib.recipe_hard_overwrite(recipe, ingredients)

    -- adjust old recipe
    local old_recipe = table.deepcopy(data.raw.recipe[recipe])
    old_recipe.name = old_recipe.name.."_alt"
    old_recipe.hidden = false
    old_recipe.ingredients = ingredients

    -- swap place with original and remove original
    data:extend({old_recipe})
    local swapped = false
    for tech, _ in pairs(data.raw.technology) do
        if ei_lib.remove_unlock_recipe(tech, recipe) then
            ei_lib.add_unlock_recipe(tech, old_recipe.name)
            swapped = true
        end
    end

    if not swapped then old_recipe.enabled = true end
    data.raw.recipe[recipe].hidden = true

end

--TECH RELATED
------------------------------------------------------------------------------------------------------

function ei_lib.set_prerequisites(tech, prerequisites)
    -- check if tech exists in data.raw.technology
    if not data.raw.technology[tech] then
      log("tech "..tech.." does not exist in data.raw.technology")
      return
    end

    for i,v in ipairs(prerequisites) do 
      if not data.raw.technology[v] then
        log("tech "..v.." does not exist in data.raw.technology")
        return
      end
    end
    data.raw.technology[tech].prerequisites = prerequisites
end


-- add new prerequisites for tech
function ei_lib.add_prerequisite(tech, prerequisite)
    -- check if tech exists in data.raw.technology
    if not data.raw.technology[tech] then
      log("tech "..tech.." does not exist in data.raw.technology")
      return
    end

    if not data.raw.technology[prerequisite] then
      log("tech "..prerequisite.." does not exist in data.raw.technology")
      return
    end

    -- if this tech has no prerequisites, create an empty table
    if not data.raw.technology[tech].prerequisites then
        data.raw.technology[tech].prerequisites = {}
    end

    -- check if prerequisite is already in tech
    for i,v in ipairs(data.raw.technology[tech].prerequisites) do
        if v == prerequisite then
            log("tech "..tech.." already has prerequisite "..prerequisite..", skipping...")
            return
        end
    end
    
    -- add prerequisite to tech
    table.insert(data.raw.technology[tech].prerequisites, prerequisite)
end

-- remove prerequisite from tech
function ei_lib.remove_prerequisite(tech, prerequisite)
    -- check if tech exists in data.raw.technology
    if not data.raw.technology[tech] then
        log("tech "..tech.." does not exist in data.raw.technology")
        return
    end

    if not data.raw.technology[tech].prerequisites then
        log("tech "..tech.." has no prerequisites; skipping...")
        return
    end

    -- loop over all prerequisites of the tech
    for i,v in ipairs(data.raw.technology[tech].prerequisites) do

        -- if prerequisite is found, remove it
        if v == prerequisite then

            -- skip this tech if it is a dummy tech :dummy in name
            if string.find(tech, "-dummy") then
                goto continue
            end

            table.remove(data.raw.technology[tech].prerequisites, i)
            ::continue::
        end
    end
end

function ei_lib.remove_tech_ingredient(tech, ingredient)
    if not data.raw.technology[tech] then
        log("ei_lib.remove_tech_ingredient: "..tech.." not found in data.raw.technology")
        return
    end
    if not data.raw.technology[tech].unit.ingredients then
        log("ei_lib.remove_tech_ingredient: "..tech.." doesn't have ingredients to remove "..ingredient.." from")
        return
    end

    for cur in pairs(data.raw.technology[tech].unit.ingredients) do
        if cur then
            if data.raw.technology[tech].unit.ingredients[cur] == ingredient then
                table.remove(data.raw.technology[tech].unit.ingredients,cur)
            end
        end
    end
end

-- remove a unlock recipe effect from tech
function ei_lib.remove_unlock_recipe(tech, recipe)
    -- check if tech exists in data.raw.technology
    if not data.raw.technology[tech] then
        log("tech "..tech.." does not exist in data.raw.technology")
        return
    end

    if not data.raw.technology[tech].effects then return false end

    -- loop over all effects of the tech
    for i,v in ipairs(data.raw.technology[tech].effects) do

        -- if effect is found, remove it
        if v.type == "unlock-recipe" and v.recipe == recipe then
            table.remove(data.raw.technology[tech].effects, i)
            return true
        end
    end

    return false
end

function ei_lib.add_unlock_recipe(tech, recipe)
    if not data.raw.technology[tech] then
        log("ei_lib.add_unlock_recipe: tech '"..tech.."' does not exist in data.raw.technology")
        return
    end

    if not data.raw.recipe[recipe] then
        log("ei_lib.add_unlock_recipe: "..recipe.." does not exist in data.raw.recipe")
        return
    end

    if type(data.raw.technology[tech].effects) ~= "table" then
        data.raw.technology[tech].effects = {}
    end

    data.raw.recipe[recipe].enabled = false
    local unlock_already_exists = false

    for _,effect in pairs(data.raw.technology[tech].effects) do
      if effect.type == "unlock-recipe" and effect.recipe == recipe then 
        unlock_already_exists = true
        goto unlock
      end 
    end 
    ::unlock::
    if not unlock_already_exists then
      table.insert(data.raw.technology[tech].effects, {type = "unlock-recipe", recipe = recipe})
      log("ei_lib.add_unlock_recipe: "..recipe.." successfully added to "..tech.."")
    end
end

function ei_lib.convert_short_ingredients_to_full(ingredients)
  for k, v in pairs(ingredients) do
    if v.type == nil then
      ingredients[k] = {
        type = "item",
        name = v[1],
        amount = v[2],
      }
    end
  end
end


science_unit_template =  {
  count = 10,
  ingredients = {},
  time = 10
}

function ei_lib.set_science_packs(tech,ingredients)
  if not ingredients then error("Tech "..tech.." set with no ingredients.") end
  -- if not data.raw.technology[tech] then error("Tech "..tech.."not exists") end
  if not data.raw.technology[tech] then return end
  data.raw.technology[tech]["research_trigger"] = nil
  if not data.raw.technology[tech]['unit'] then 
    data.raw.technology[tech]['unit'] = table.deepcopy(science_unit_template)
  end
  data.raw.technology[tech].unit.ingredients = table.deepcopy(ingredients)
end

function ei_lib.set_age_packs(tech,age)
  if not ei_data.science[age] then error("ei_data.science does not have age "..age) end
  ei_lib.set_science_packs(tech,ei_data.science[age])
end

function ei_lib.copy_science_packs(tech_to,tech_from)
  -- if not data.raw.technology[tech_to] then error("Tech "..tech_to.."not exists") end
  -- if not data.raw.technology[tech_from] then error("Tech "..tech_from.."not exists") end
  -- if not data.raw.technology[tech_from]['unit'] then error("Tech "..tech_from.."does not have unit field") end
  if not data.raw.technology[tech_to] then return end
  if not data.raw.technology[tech_from] then return end
  if not data.raw.technology[tech_from]['unit'] then return end
  data.raw.technology[tech_to]["research_trigger"] = nil
  data.raw.technology[tech_to]['unit'] = table.deepcopy(data.raw.technology[tech_from]['unit'])
  data.raw.technology[tech_to].hidden = false
  data.raw.technology[tech_from].hidden = false
end

function ei_lib.remove_tech(tech)
    -- hide this tech in the tech tree
    -- remove it from all techs prerequisites

    -- check if tech exists in data.raw.technology
    if not data.raw.technology[tech] then
        log("tech "..tech.." does not exist in data.raw.technology")
        return
    end

    -- loop over all techs
    for i,v in pairs(data.raw.technology) do
        -- remove tech from all techs prerequisites
        ei_lib.remove_prerequisite(v.name, tech)
    end

    -- hide the tech in the tech tree
    data.raw.technology[tech].enabled = false
    data.raw.technology[tech].hidden = true
end

function ei_lib.disable(id)
  ei_lib.remove_tech(id)

  for _,tech in pairs(data.raw.technology) do
    ei_lib.remove_unlock_recipe(tech.name, id)
  end

  for category_name, _ in pairs(data.raw) do
    if data.raw[category_name][id] then 
      data.raw[category_name][id].hidden = true
    end
  end
end

function ei_lib.enable(id)
  for category_name, _ in pairs(data.raw) do
    if data.raw[category_name][id] then 
      data.raw[category_name][id].hidden = false
    end
  end
end

function ei_lib.enable_from_start(id)
  for category_name, _ in pairs(data.raw) do
    if data.raw[category_name][id] then 
      data.raw[category_name][id].hidden = false
      data.raw[category_name][id].enabled = true
    end
  end
end

--GENERAL PROTOTYPES RELATED
------------------------------------------------------------------------------------------------------



--- Set each attribute of source into target
function ei_lib.recursive_copy(target, source)
    for key, value in pairs(source) do
        if tostring(key):find('^_') ~= 1 then
            if type(value) == 'table' then
                target[key] = target[key] or {}
                ei_lib.recursive_copy(target[key], source[key])
            else
                target[key] = source[key]
            end
        end
    end
end

function ei_lib.recursive_insert(target, source)
    for key, value in pairs(source) do
        if tostring(key):find('^_') ~= 1 then
            if type(value) == 'table' then
                target[key] = target[key] or {}
                if #value > 0 then
                    -- it's an array-like table, insert elements
                    for _, v in ipairs(value) do
                        -- check if the value is already in the target array
                        if not ei_lib.table_contains_value(target[key], v) then
                          table.insert(target[key], v)
                        end
                    end
                else
                    -- it's a dictionary, recurse
                    ei_lib.recursive_insert(target[key], value)
                end
            else
                target[key] = value
            end
        end
    end
end

--- Updates (overwriting) a given prototype's attributes with the given data
--- properties starting with underscore "_property" will be ignored
--- compared to modify_data_raw or ei_lib.raw, this is better to call from, ie, looping over a table
---@param obj Prototype
---@field name String mandatory
---@field type String mandatory
function ei_lib.set_properties(obj)
    if not (obj and obj.name and obj.type) then
        log(serpent.log({["Invalid object:"] = obj}))
        return
    end
    local prototype = data.raw[obj.type][obj.name]
    if not prototype then
        log("Could not find prototype"..obj.type.."/"..obj.name)
        return
    end
    ei_lib.recursive_copy(prototype, obj)
end

--====================================================================================================
--GRAPHICS FUNCTIONS
--====================================================================================================

-- get path of 64x64 empty sprite from graphics mod
function ei_lib.empty_sprite(size)
    size = size or 64

    if size == 64 then
        return ei_graphics_path.."graphics/64_empty.png"
    end

    if size == 128 then
        return ei_graphics_path.."graphics/128_empty.png"
    end
    
    if size == 256 then
        return ei_graphics_path.."graphics/256_empty.png"
    end

    return ei_graphics_path.."graphics/64_empty.png"
end

-- from base factorio
function ei_lib.make_4way_animation_from_spritesheet(animation)
    local function make_animation_layer(idx, anim)
      local start_frame = (anim.frame_count or 1) * idx
      local x = 0
      local y = 0
      if anim.line_length then
        y = anim.height * math.floor(start_frame / (anim.line_length or 1))
      else
        x = idx * anim.width
      end
      return
      {
        filename = anim.filename,
        priority = anim.priority or "high",
        flags = anim.flags,
        x = x,
        y = y,
        width = anim.width,
        height = anim.height,
        frame_count = anim.frame_count or 1,
        line_length = anim.line_length,
        repeat_count = anim.repeat_count,
        shift = anim.shift,
        draw_as_shadow = anim.draw_as_shadow,
        force_hr_shadow = anim.force_hr_shadow,
        apply_runtime_tint = anim.apply_runtime_tint,
        animation_speed = anim.animation_speed,
        scale = anim.scale or 1,
        tint = anim.tint,
        blend_mode = anim.blend_mode
      }
    end
  
    local function make_animation(idx)
      if animation.layers then
        local tab = { layers = {} }
        for k,v in ipairs(animation.layers) do
          table.insert(tab.layers, make_animation_layer(idx, v))
        end
        return tab
      else
        return make_animation_layer(idx, animation)
      end
    end
  
    return
    {
      north = make_animation(0),
      east = make_animation(1),
      south = make_animation(2),
      west = make_animation(3)
    }
end

function ei_lib.make_circuit_connector(Dx, Dy)

    local circuit_wire_connection_point = {
        shadow = {
            green = {0.671875+Dx, 0.609375+Dy},
            red = {0.890625+Dx, 0.5625+Dy}
        },
        wire = {
            green = {0.453125+Dx, 0.453125+Dy},
            red = {0.390625+Dx, 0.21875+Dy}
        }
    }

    local circuit_connector_sprites = {
        blue_led_light_offset = {0.125+Dx, 0.46875+Dy},
        connector_main = {
          filename = "__base__/graphics/entity/circuit-connector/ccm-universal-04a-base-sequence.png",
          height = 50,
          priority = "low",
          scale = 0.5,
          shift = {
            0.09375+Dx,
            0.203125+Dy
          },
          width = 52,
          x = 104,
          y = 150
        },
        connector_shadow = {
          draw_as_shadow = true,
          filename = "__base__/graphics/entity/circuit-connector/ccm-universal-04b-base-shadow-sequence.png",
          height = 46,
          priority = "low",
          scale = 0.5,
          shift = {
            0.3125+Dx,
            0.3125+Dy
          },
          width = 62,
          x = 124,
          y = 138
        },
        led_blue = {
          draw_as_glow = true,
          filename = "__base__/graphics/entity/circuit-connector/ccm-universal-04e-blue-LED-on-sequence.png",
          height = 60,
          priority = "low",
          scale = 0.5,
          shift = {
            0.09375+Dx,
            0.171875+Dy
          },
          width = 60,
          x = 120,
          y = 180
        },
        led_blue_off = {
          filename = "__base__/graphics/entity/circuit-connector/ccm-universal-04f-blue-LED-off-sequence.png",
          height = 44,
          priority = "low",
          scale = 0.5,
          shift = {
            0.09375+Dx,
            0.171875+Dy
          },
          width = 46,
          x = 92,
          y = 132
        },
        led_green = {
          draw_as_glow = true,
          filename = "__base__/graphics/entity/circuit-connector/ccm-universal-04h-green-LED-sequence.png",
          height = 46,
          priority = "low",
          scale = 0.5,
          shift = {
            0.09375+Dx,
            0.171875+Dy
          },
          width = 48,
          x = 96,
          y = 138
        },
        led_light = {
          intensity = 0,
          size = 0.9
        },
        led_red = {
          draw_as_glow = true,
          filename = "__base__/graphics/entity/circuit-connector/ccm-universal-04i-red-LED-sequence.png",
          height = 46,
          priority = "low",
          scale = 0.5,
          shift = {
            0.09375+Dx,
            0.171875+Dy
          },
          width = 48,
          x = 96,
          y = 138
        },
        red_green_led_light_offset = {
          0.109375+Dx,
          0.359375+Dy
        },
        wire_pins = {
          filename = "__base__/graphics/entity/circuit-connector/ccm-universal-04c-wire-sequence.png",
          height = 58,
          priority = "low",
          scale = 0.5,
          shift = {
            0.09375+Dx,
            0.171875+Dy
          },
          width = 62,
          x = 124,
          y = 174
        },
        wire_pins_shadow = {
          draw_as_shadow = true,
          filename = "__base__/graphics/entity/circuit-connector/ccm-universal-04d-wire-shadow-sequence.png",
          height = 54,
          priority = "low",
          scale = 0.5,
          shift = {
            0.25+Dx,
            0.296875+Dy
          },
          width = 70,
          x = 140,
          y = 162
        }
    }


    return {
        circuit_wire_connection_point,
        circuit_connector_sprites
    }

end

--rescales entities or corpses
--entity should be data.raw, scale_multiplier a double
function ei_lib.entity_icon_scaler(entity,scale_multiplier)
    if not entity then
        log("ei_lib.entity_icon_scaler received invalid entity prototype")
        return
    end
    if not scale_multiplier then
        log("ei_lib.entity_icon_scaler received invalid scale_multiplier for entity: "..entity.name)
        return
    end

    local sm = scale_multiplier
    local e = entity
    --tile_width, tile_height are corpse variables
    if e.tile_width then
      e.tile_width = e.tile_width * sm
    end
    if e.tile_height then
      e.tile_height = e.tile_height  * sm
    end

    --build_grid_size -- not sure what adjustment to make here if any
    --static
    if e.picture and e.picture.layers then
        for _,layer in pairs(e.picture.layers) do
            layer.scale = layer.scale * sm
            if layer.shift then
              if layer.shift[1] then
                layer.shift[1] = layer.shift[1] * sm
              end
              if layer.shift[2] then
                layer.shift[2] = layer.shift[2] * sm
              end
            end
        end
    --animated, particularly corpses
    elseif e.animation then
        for count,_ in pairs(e.animation) do
            if e.animation[count] and e.animation[count].layers then
                for _,layer in pairs (e.animation[count].layers) do
                    layer.scale = layer.scale * sm
                    if layer.shift then
                      if layer.shift[1] then
                        layer.shift[1] = layer.shift[1] * sm
                      end
                      if layer.shift[2] then
                        layer.shift[2] = layer.shift[2] * sm
                      end
                    end
                end
            end
        end
    else
      log("ei_lib.entity_icon_scaler had valid entity: "..e.name.." and multiplier: "..sm.." but didn't have valid picture or animation layers to modify")
      return
    end
    --These are last in case the visuals don't take
    local boxes = {
        "collision_box",
        "selection_box"
    }
    for _,box in pairs(boxes) do
        if e[box] then
            for _,extent in pairs(e[box]) do
                extent[1] = extent[1] * sm
                extent[2] = extent[2] * sm
            end
        end
    end
    log("ei_lib.entity_icon_scaler successfully rescaled entity: "..e.name.." with scale multiplier: "..sm)
end
--Get area of an entity's collision box
function ei_lib.get_entity_area(entity)
  if not entity or not entity.valid then
      log("ei_lib.get_entity_area got invalid entity")
      return
  end
  if not entity.collision_box then
      log("ei_lib.get_entity_area got invalid collision_box for entity: "..entity.name)
      return
  end
  local box = entity.collision_box
  return ei_lib.get_box_area(box)
end

function ei_lib.get_box_area(box)
  if not box then
      log("ei_lib.get_entity_area got invalid box")
      return
  end
  -- box is of form {{x1, y1}, {x2, y2}}
  local x1, y1 = box[1][1], box[1][2]
  local x2, y2 = box[2][1], box[2][2]

  local width = x2 - x1
  local height = y2 - y1

  return width * height
end
--returns absolute and percent differences in collision area
function ei_lib.get_entity_area_change(boxA, boxB)
  local areaA = ei_lib.get_box_area(boxA)
  local areaB = ei_lib.get_box_area(boxB)

  local diff = areaB - areaA
  local pct_change = 0
  if areaA ~= 0 then
    pct_change = (diff / areaA)-- * 100
  end

  return {
    areaA = areaA,
    areaB = areaB,
    difference = diff,
    percent = pct_change
  }
end
function ei_lib.add_item_level(item, level)

    -- add level overlay to item icon

    local item = data.raw.item[item]

    if not item then
        return
    end

    if not item.icon then
        return
    end

    if not item.icon_size then
        return
    end

    local icon_size = item.icon_size or 64
    local current_icon = item.icon
    if not item.icons then
      item.icons = {
          {
              icon = current_icon,
              icon_size = icon_size,
          },
          {
              icon = ei_graphics_other_path.."overlay_"..level..".png",
              icon_size = 64,
          }
      }
      item.icon = nil
      item.icon_size = nil
    else
      table.insert(item.icons,
            {
              icon = ei_graphics_other_path.."overlay_"..level..".png",
              icon_size = 64,
            })
    end
end

function ei_lib.merge_fluid(target, fluid, icon_transfer)

    if not data.raw.fluid[target] then return end
    if not data.raw.fluid[fluid] then return end
    icon_transfer = icon_transfer or false

    -- loop over all recipes and swap
    for recipe_name,_ in pairs(data.raw.recipe) do
        local recipe = data.raw.recipe[recipe_name]
        
        ei_lib.do_fluid_merge(recipe, target, fluid)
    end

    -- icon transfer needed?
    if icon_transfer then
        data.raw.fluid[target].icon = data.raw.fluid[fluid].icon
        data.raw.fluid[target].icon_size = data.raw.fluid[fluid].icon_size
    end

    -- hide the old fluid
    data.raw.fluid[fluid].hidden = true

end

function ei_lib.do_fluid_merge(recipe, target, fluid)
    -- handle ingredients
    if recipe.ingredients then
        for i,ingredient in pairs(recipe.ingredients) do
            if ingredient.name == fluid then
                ingredient.name = target
            end

            if ingredient[1] == fluid then
                ingredient[1] = target
            end
        end
    end

    --fixup main product
    if recipe.main_product == fluid then
        recipe.main_product = target
    end

    if recipe.result == fluid then
        recipe.result = target
    end

    if recipe.results then
        for i,result in pairs(recipe.results) do
            if result.name == fluid then
                result.name = target
            end
        end
    end
end

function ei_lib.merge_item(target, item, icon_transfer, placeables)

  if not data.raw.item[target] then return end
  if not data.raw.item[item] then return end
  icon_transfer = icon_transfer or false

  -- loop over all recipes and swap
  for recipe_name,_ in pairs(data.raw.recipe) do
      local recipe = data.raw.recipe[recipe_name]
      ei_lib.do_item_merge(recipe, target, item)
  end

  for _,spoiler in pairs(data.raw.item) do
    if spoiler and spoiler.spoil_result then
      if spoiler.spoil_result == item then
        spoiler.spoil_result = target
      end
    end
  end
  --also iterate iover placeables?
  if placeables then
    local ps = {
      "simple-entity",
      "tree"
    }
    for _,category in pairs(ps) do
      for pname, placeable in pairs(data.raw[category]) do
        if placeable.minable and placeable.minable.results then
          for i, result in ipairs(placeable.minable.results) do
            if result.type == "item" and result.name == item then
                log("ei: Replacing '"..result.name.."' with '"..target.."' in placeable: " .. pname)
                result.name = target
            end
          end
        end
      end
    end
  end
  -- icon transfer needed?
  if icon_transfer then
      data.raw.item[target].icon = data.raw.item[item].icon
      data.raw.item[target].icon_size = data.raw.item[item].icon_size
  end

  -- hide the old item
  data.raw.item[item].hidden = true

end

function ei_lib.do_item_merge(recipe, target, item)
    -- handle ingredients
    if recipe.ingredients then
        for i,ingredient in pairs(recipe.ingredients) do
            if ingredient.name == item then
                ingredient.name = target
            end

            if ingredient[1] == item then
                ingredient[1] = target
            end
        end
    end

    --fixup main product
    if recipe.main_product == item then
        recipe.main_product = target
    end

    if recipe.result == item then
        recipe.result = target
    end

    if recipe.results then
        for i,result in pairs(recipe.results) do
            if result.name == item then
                result.name = target
            end
        end
    end
end

--====================================================================================================
--OTHER
--====================================================================================================
function ei_lib.debug_crafting_categories()
    local output = {}
    local blacklist_category = {
        ["void-crushing"] = true,
        ["fuel-burning"] = true,
    }
    
    for name, _ in pairs(data.raw["recipe-category"]) do
        if not blacklist_category[name] then
            local info = {}
            info.category = name

            info.recipes = {}
            for _, recipe in pairs(data.raw.recipe) do
                if recipe.category == name then
                    if not (ei_lib.starts_with(recipe.name, "fill-") or ei_lib.starts_with(recipe.name, "empty-")) then
                        table.insert(info.recipes, recipe.name)
                    end
                end
            end

            info.machines = {}
            for _, source in pairs({"assembling-machine", "furnace", "rocket-silo"}) do
                for _, entity in pairs(data.raw[source]) do
                    if ei_lib.table_contains_value(entity.crafting_categories or {}, name) then
                        table.insert(info.machines, entity.type .. "/" .. entity.name)
                    end
                end
            end

            output[name] = info
        end
    end
    log(serpent.block(output))
end



-- Simulate lightning strike at position
function ei_lib.strike_lightning(surface, pos)
  if not surface or not pos then return end
  local palette = ei_lib.tint_palette
  if not palette then
    log("ei_lib.strike_lightning: no tint_palette available")
    return
  end

  -- Randomly pick a tint
  local tint_names = {}
  for name, _ in pairs(palette) do
    table.insert(tint_names, name)
  end
  local tint_name = tint_names[ei_rng.int("lightning_tint", 1, #tint_names)]
  local tint_data = palette[tint_name]
  local tint_rgb = ei_lib.hex_to_rgb_normalized(tint_data.hex)

  -- Smoke pulse
  surface.create_trivial_smoke{
    name = "train-smoke",
    position = pos
  }
--[[
  -- Thunder sound (crackling)
  surface.create_entity{
    name = "programmable-speaker",
    position = {x = pos.x, y = pos.y - 1},
    parameters = {
      playback_volume = 1,
      playback_globally = true,
      sound_path = "utility/armor_insert"
    }
  }
]]
  -- Beam from above
  surface.create_entity{
    name = "electric-beam",
    source = {x = pos.x, y = pos.y - 20},
    position = {x= pos.x, y = pos.y},
    target = {x = pos.x, y = pos.y + 20},
    force = "neutral",
    duration = 80
  }

  -- Colored light burst
  rendering.draw_light{
    sprite = "utility/light_medium",
    target = pos,
    surface = surface,
    color = tint_rgb,
    intensity = 2.7,
    scale = 5.5,
    time_to_live = 18
  }

  -- Explosive mark
  surface.create_entity{
    name = "explosion",
    position = pos
  }

end

--=====================================================================================================
-------------------------------Crystal Messages
--=====================================================================================================
--Crystal Echo color library

ei_lib.tint_palette = {
    ["mirage"]      = { name = "mirage",     adj = "eldritch",    hex = "#2af9aa", intent = "mystery" },
    ["specter"]     = { name = "specter",    adj = "entropic",    hex = "#d19e79", intent = "signal" },
    ["singularity"] = { name = "singularity",adj = "mirrored",    hex = "#c58681", intent = "mystery" },
    ["void"]        = { name = "void",       adj = "entropic",    hex = "#cccba7", intent = "signal" },
    ["mycelium"]    = { name = "mycelium",   adj = "mystic",      hex = "#ef7ef4", intent = "mystery" },
    ["halo"]        = { name = "halo",       adj = "mystic",      hex = "#708a43", intent = "mystery" },
    ["aurora"]      = { name = "aurora",     adj = "silent",      hex = "#404f7d", intent = "serenity" },
    ["frost"]       = { name = "frost",      adj = "celestial",   hex = "#222a9f", intent = "divine" },
    ["pulse"]       = { name = "pulse",      adj = "encrypted",   hex = "#88dba5", intent = "signal" },
    ["venom"]       = { name = "venom",      adj = "toxic",       hex = "#2b6624", intent = "wrath" },
    ["dusk"]        = { name = "dusk",       adj = "luminous",    hex = "#49bad9", intent = "serenity" },
    ["starlight"]   = { name = "starlight",  adj = "radiant",     hex = "#bd3097", intent = "divine" },
    ["flux"]        = { name = "flux",       adj = "toxic",       hex = "#a5c3f0", intent = "wrath" },
    ["node"]        = { name = "node",        adj = "dormant",    hex = "#4c7759", intent = "serenity" },
    ["resonance"]   = { name = "resonance",   adj = "glacial",    hex = "#2dbd66", intent = "serenity" },
    ["core"]        = { name = "core",        adj = "lunar",      hex = "#d77ec1", intent = "divine" },
    ["glyph"]       = { name = "glyph",       adj = "dissonant",  hex = "#e56af6", intent = "signal" },
    ["chime"]       = { name = "chime",       adj = "auric",      hex = "#b7cc29", intent = "divine" },
    ["matrix"]      = { name = "matrix",      adj = "volatile",   hex = "#ae8fff", intent = "wrath" },
    ["spire"]       = { name = "spire",       adj = "dissonant",  hex = "#e8a893", intent = "signal" },
    ["veil"]        = { name = "veil",        adj = "eternal",    hex = "#32e4aa", intent = "mystery" },
    ["rift"]        = { name = "rift",        adj = "iridescent", hex = "#a57880", intent = "mystery" },
    ["sigil"]       = { name = "sigil",       adj = "unstable",   hex = "#8189d0", intent = "wrath" },
    ["shard"]       = { name = "shard",       adj = "quantum",    hex = "#b982bd", intent = "signal" },
    ["beam"]        = { name = "beam",        adj = "solar",      hex = "#44caee", intent = "wrath" }
--    ["pulse"]       = { name = "pulse",       adj = "radiant",    hex = "#624385", intent = "divine" }
  }  

local intent_tint_map = {
    mystery = {
      "mirage",
      "singularity",
      "mycelium",
      "halo",
      "veil",
      "rift"
    },
    signal = {
      "specter",
      "void",
      "pulse",
      "glyph",
      "spire",
      "shard"
    },
    serenity = {
      "aurora",
      "dusk",
      "node",
      "resonance"
    },
    divine = {
      "frost",
      "pulse",
      "starlight",
      "core",
      "chime"
    },
    wrath = {
      "venom",
      "flux",
      "matrix",
      "sigil",
      "beam"
    }
  }
local crystal_colors = {
    {112, 48, 160},   -- Royal purple
    {0, 123, 167},    -- Cerulean
    {186, 85, 211},   -- Orchid flare
    {72, 209, 204},   -- Crystal teal
    {255, 105, 180},  -- Etheric pink
    {240, 230, 140},  -- Dream gold
    {50, 205, 50},    -- Verdant flux
    {255, 69, 0},      -- Solar flare
    {128, 64, 192},   -- Amethyst Surge (darker variant of royal purple)
    {0, 139, 180},    -- Deep Cerulean (slightly more saturated, oceanic)
    {199, 112, 221},  -- Radiant Orchid (brighter, richer orchid tone)
    {64, 224, 208},   -- Iced Teal (closer to turquoise, retains clarity)
    {255, 99, 187},   -- Magenta Pulse (pinker hue, saturated etherwave)
    {255, 239, 100},  -- Starlight Gold (brighter, ethereal yellow)
    {60, 220, 80},    -- Vivid Verdance (more neon, energetic green)
    {255, 80, 20}     -- Inferno Ember (darker orange-red, volatile)
  }

-------------------------------Crystal Messages
---
----- Utility to substitute placeholders in the message
function ei_lib.format_echo(message, replacements)
    return (string.gsub(message, "{(.-)}", function(key)
        if key == "tint_adj" and replacements["tint"] then
            local tint = ei_lib.tint_palette[replacements["tint"]]
            return (tint and tint.adj) or "mysterious"
        end
        return tostring(replacements[key] or "{"..key.."}")
    end))
end
function ei_lib.lerp_color(c1, c2, t)
    return {
      math.floor(c1[1] + (c2[1] - c1[1]) * t + 0.5),
      math.floor(c1[2] + (c2[2] - c1[2]) * t + 0.5),
      math.floor(c1[3] + (c2[3] - c1[3]) * t + 0.5)
    }
  end

function ei_lib.rgb_to_hex(rgb)
    return string.format("%02x%02x%02x", rgb[1], rgb[2], rgb[3])
  end

--0 - 1
-- For rendering, glow, tints
function ei_lib.hex_to_rgb_normalized(hex)
  hex = hex:gsub("#", "")
  if #hex ~= 6 then error("Invalid hex color: "..hex) end
  return {
    r = tonumber(hex:sub(1,2), 16)/255,
    g = tonumber(hex:sub(3,4), 16)/255,
    b = tonumber(hex:sub(5,6), 16)/255
  }
end
--0-255
-- For gradient interpolation, math, storage
function ei_lib.hex_to_rgb_raw(hex)
  hex = hex:gsub("#", "")
  return {
    tonumber(hex:sub(1,2), 16),
    tonumber(hex:sub(3,4), 16),
    tonumber(hex:sub(5,6), 16)
  }
end


function ei_lib.get_adjective_and_tint(tint)
tint.display = tint.adj:gsub("^%l", string.upper) .. " " .. tint.name
    return tint.display
    end
function ei_lib.pick_tint_from_intent(intent)
  local pool = intent_tint_map[intent or ""] or {}
  return #pool > 0 and pool[math.random(1,#pool)] or nil
end

-- Controlled variation (+/- 15)
local function vary(c)
  local v = c + ei_rng.int("vary",-15, 15)
  return math.max(0, math.min(255, v))
end

function ei_lib.generate_crystal_gradient_stops(min_stops, max_stops,msg)
  local stops = {}
  local count = math.random(min_stops,max_stops)

  for var = 1, count do
    -- Pick a base color
    local base = crystal_colors[var]
    table.insert(stops, {
      vary(base[1]),
      vary(base[2]),
      vary(base[3])
    })
  end

  return stops
end

function ei_lib.pick_gradient_stops(msg)
  return ei_lib.generate_crystal_gradient_stops(2, math.random(2,#crystal_colors),msg)
end
--[[]
ei_lib.crystal_echo(
  msg,                 -- string with {tint} and/or {tint_adj} tokens
  font,                -- optional font style (e.g., "default-bold")
  player,              -- player index to send to (or nil for global)
  tint,                -- tint name (or nil to use intent)
  force_full_tint,     -- boolean: override all characters with tint color
  intent,              -- fallback theme (e.g., "serenity", "wrath", etc.)
  as_floating_text,    -- boolean: render as floating text instead of chat
  floating_timetolive  -- optional number of ticks for float duration
)

  crystal_echo:
  A multifaceted message renderer that:
    - Prints gradient-colored messages to chat or as floating text.
    - Supports color themes ("tints") with linked adjectives and hex values.
    - Honors "intent" (emotional/semantic theme) if tint isn't specified.
    - Optionally overrides all character colors with a single tint (force_full_tint).
    - Can display messages as floating text above the player.
--]]

function ei_lib.crystal_echo(msg, font, player, tint, force_full_tint, intent, as_floating_text, floating_timetolive)
  -- === INTENT→TINT FALLBACK SYSTEM ===
  -- If no tint is specified, try to select one based on declared emotional "intent".
  -- These two tables should be defined externally and kept updated at runtime:
  local raw_msg = msg
  local string_msg = nil

  if type(raw_msg) == "string" then
    string_msg = raw_msg
  elseif type(raw_msg) ~= "table" then
    raw_msg = tostring(raw_msg)
    string_msg = raw_msg
  end

  local intent_tint_map = intent_tint_map  -- {intent = {"tint_name", ...}}
  local tint_palette = ei_lib.tint_palette        -- {tint_name = {hex, adj, intent, ...}}

  if not tint and intent and intent_tint_map[intent] then
    local pool = intent_tint_map[intent]
    tint = pool[math.random(1,#pool)]
  end

  -- === EXTRACT TINT DATA FROM PALETTE ===
  local tint_info = tint and tint_palette[tint]
  local tint_color = tint_info and tint_info.hex and tint_info.hex:gsub("#", "")  -- remove leading #
  local tint_rgb = tint_color and ei_lib.hex_to_rgb_normalized(tint_color)                   -- convert to RGB {r,g,b}
  local tint_label = tint_info and tint_info.name or nil                          -- full name of tint (e.g., "solar flare")

  -- === SUBSTITUTE PLACEHOLDER TOKENS ===
  -- Replace {tint} and {tint_adj} in the message with correct values from the tint_palette
  if tint_label and string_msg then
    string_msg = string_msg:gsub("{tint}", tint_label)
    string_msg = string_msg:gsub("{tint_adj}", tint_info.adj or "mysterious")
    raw_msg = string_msg
  end

  -- === DETERMINE POSITION OF TINT IN FINAL STRING ===
  -- This allows us to apply a specific color to just the {tint} portion later.
  local tint_start, tint_end = nil, nil
  if tint_label and string_msg then
    local start_pos = string_msg:find(tint_label, 1, true)
    if start_pos then
      tint_start = start_pos
      tint_end = start_pos + #tint_label - 1
    end
  end

  -- === PREPARE COLOR GRADIENT ===
  -- If not using force_full_tint, generate a multi-color gradient for text
  local gradient = string_msg and not force_full_tint and ei_lib.pick_gradient_stops(string_msg) or nil
  local segments = gradient and (ei_lib.getn(gradient) - 1) or nil

  -- === BUILD COLORED MESSAGE, CHARACTER BY CHARACTER ===
  local result = {}
  local total_chars = string_msg and #string_msg or 0

  for i = 1, total_chars do
    local char = string_msg:sub(i, i)
    local hex

    local in_tint = tint_start and i >= tint_start and i <= tint_end

    -- === DETERMINE COLOR FOR THIS CHARACTER ===
    if force_full_tint and tint_color then
      hex = tint_color  -- override everything with one tint
    elseif in_tint and tint_color then
      hex = tint_color  -- special styling for the {tint} word only
    elseif gradient then
      -- Interpolate between two colors from the gradient
      local t = (i - 1) / math.max(1, total_chars - 1)
      local segment = math.floor(t * segments) + 1
      local local_t = (t * segments) % 1
      local c1 = gradient[segment]
      local c2 = gradient[segment + 1] or c1
      local interp = ei_lib.lerp_color(c1, c2, local_t)
      hex = ei_lib.rgb_to_hex(interp)
    else
      hex = "ffffff"  -- fallback to white
    end

    -- === WRAP CHARACTER IN COLOR AND FONT TAGS ===
    local styled = font
      and ("[font=" .. font .. "][color=#" .. hex .. "]" .. char .. "[/color][/font]")
      or ("[color=#" .. hex .. "]" .. char .. "[/color]")

    table.insert(result, styled)
  end

  -- === FINALIZE THE MESSAGE STRING ===
  local final_msg = string_msg and table.concat(result) or raw_msg
  local target
  local canPrint
  local render_surface
  local render_target
  local render_forces
  local render_players
  -- === DETERMINE TARGET OUTPUT LOCATION ===
  if type(player) == "table"
    and not player.valid
    and player.surface
    and (player.target or player.position) then
    render_surface = player.surface
    render_target = player.target or player.position
    render_forces = player.forces
    render_players = player.players
  elseif pcall(function() return game.get_player(player) end) then
    target = game.get_player(player)
    canPrint = true
  else
    target = player --technically can be any entity
    if as_floating_text and target and target.valid then
      render_surface = target.surface
      render_target = target
    end
  end
  -- === EMIT AS FLOATING TEXT OR CHAT ===
  if as_floating_text and render_surface and render_target then
      rendering.draw_text{
        text = raw_msg,
        surface = render_surface,
        target = render_target,
        color = tint_rgb or {r = 1, g = 1, b = 1},          -- fallback white
        alignment = "center",
        vertical_alignment = "middle",
        scale = 1.5,
        time_to_live = floating_timetolive or 180,          -- custom TTL or 3 seconds
        forces = render_forces,
        players = render_players
      }
  elseif target and target.valid then
    if as_floating_text then
      rendering.draw_text{
        text = raw_msg,
        surface = target.surface,
        target = target,
        color = tint_rgb or {r = 1, g = 1, b = 1},          -- fallback white
        alignment = "center",
        vertical_alignment = "middle",
        scale = 1.5,
        time_to_live = floating_timetolive or 180          -- custom TTL or 3 seconds
      }
    elseif canPrint then
      target.print(final_msg)
    end
  else
    game.print(final_msg)
  end
end

function ei_lib.crystal_echo_floating(msg, target, floating_timetolive, intent, tint)
    ei_lib.crystal_echo(msg, nil, target, tint or nil, nil, intent or nil, true, floating_timetolive)
end

ei_lib.notification_setting_names = {
    gate = "ei-gate-notifications",
    black_hole = "ei-black-hole-notifications",
    matter_machine = "ei-matter-machine-notifications",
    insulated_pipe = "ei-insulated-pipe-notifications"
}

local function resolve_notification_player(player_or_index)
    if type(player_or_index) == "number" then
        return game and game.get_player(player_or_index) or nil
    end

    return player_or_index
end

function ei_lib.get_player_setting_value(player_or_index, setting_name, default_value)
    local fallback = default_value
    if fallback == nil then
        fallback = true
    end

    if not settings or not settings.get_player_settings then
        return fallback
    end

    local player = resolve_notification_player(player_or_index)
    if not player or not player.valid then
        return fallback
    end

    local ok, player_settings = pcall(settings.get_player_settings, player)
    if not ok or not player_settings then
        return fallback
    end

    local setting = player_settings[setting_name]
    if not setting or setting.value == nil then
        return fallback
    end

    return setting.value
end

function ei_lib.player_allows_notification(player_or_index, notification_kind)
    local setting_name = ei_lib.notification_setting_names[notification_kind] or notification_kind
    return ei_lib.get_player_setting_value(player_or_index, setting_name, true)
end

-- Route gameplay notifications through connected players so each player can opt in or out per
-- system without changing the message call sites across the control scripts.
function ei_lib.notify_connected_players(notification_kind, message, options)
    if not game or not game.connected_players then
        return
    end

    options = options or {}
    local mode = options.mode or "print"

    for _, player in pairs(game.connected_players) do
        if player and player.valid and ei_lib.player_allows_notification(player, notification_kind) then
            if mode == "crystal_echo" and type(message) == "string" then
                ei_lib.crystal_echo(
                    message,
                    options.font,
                    player.index,
                    options.tint,
                    options.force_full_tint,
                    options.intent,
                    options.as_floating_text,
                    options.floating_timetolive
                )
            else
                player.print(message)
            end
        end
    end
end


return ei_lib

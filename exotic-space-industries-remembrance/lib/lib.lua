-- commonly used functions for the mod

local ei_lib = {}

--====================================================================================================
--FUNCTIONS
--====================================================================================================

function ei_lib.endswith(str,suf) return str:sub(-string.len(suf)) == suf end
function ei_lib.startswith(text, prefix) return text:find(prefix, 1, true) == 1 end
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

function ei_lib.table_contains_value(table_in, value)
    for i,v in pairs(table_in) do
        if v == value then
            return true
        end
    end
    return false
end

--Pick a value from table other than the previous
function ei_lib.get_random_different_value(tbl, previous)
    if not tbl then return end

    -- Convert table values into an array
    local values = {}
    for _, v in pairs(tbl) do
        table.insert(values, v)
    end

    if #values == 1 then return values[1] end -- no choice

    local choice
    repeat
        choice = values[ei_rng.int("randtblvalu", 1, #values)]
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


-- quick access to startup settings
function ei_lib.config(name)
    local setting = settings.startup["ei-" .. name]
    if not setting then return false end

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

---@param inputstr string
---@param start string
function ei_lib.starts_with(inputstr, start) 
    return inputstr:sub(1, #start) == start 
end


--RECIPE RELATED
------------------------------------------------------------------------------------------------------

-- change ingredient in a recipe for another
function ei_lib.recipe_swap(recipe, old_ingredient, new_ingredient, amount)
    -- return if recipe or old_ingredient or new_ingredient is not given
    if not recipe or not old_ingredient or not new_ingredient then
        return
    end

    -- test if recipe exists in data.raw.recipe
    if not data.raw.recipe[recipe] then
        log("recipe "..recipe.." does not exist in data.raw.recipe")
        return
    end

    -- check if amount is given
    if not amount then
        
        -- if we got an amount of old_ingredient in the recipe
        -- set amount to that amount
        for i,v in pairs(data.raw.recipe[recipe].ingredients or {}) do
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
    for i,v in pairs(data.raw.recipe[recipe].ingredients or {}) do

        local item_amount = v[2] or v["amount"]
        local item_name = v[1] or v["name"]

        -- if ingredient is found, replace it
        -- here first index is ingredient name, second index is amount
        if item_name == old_ingredient then
            if v["name"] then
                data.raw.recipe[recipe].ingredients[i]["name"] = new_ingredient
                data.raw.recipe[recipe].ingredients[i]["amount"] = amount
            else
                data.raw.recipe[recipe].ingredients[i][1] = new_ingredient
                data.raw.recipe[recipe].ingredients[i][2] = amount
            end
        end

        ei_lib.fix_recipe(recipe)
    end
end


-- fix recipes for multiple ingredients
function ei_lib.fix_recipe(recipe)
    -- look if an ingredient is multiple times in the recipe, if so, add the amounts
    local ingredients = {}
    if not data.raw.recipe[recipe].ingredients then
        return
    end

    if not data.raw.recipe[recipe].ingredients[1] then
        return
    end
    ingredients = data.raw.recipe[recipe].ingredients

    -- loop over all ingredients
    for i,v in ipairs(ingredients) do
        local total_amount = v[2] or v["amount"] or 1
        for j,x in ipairs(ingredients) do
            -- exclude same index
            if i ~= j then

                -- if is entry for the same ingredient
                if (v["name"] == x["name"] and v["name"]) or (v[1] == x[1] and v[1]) then
                    if x["amount"] then
                        total_amount = total_amount + x["amount"]
                    else
                        total_amount = total_amount + x[2]
                    end
                    
                    table.remove(data.raw.recipe[recipe].ingredients, j)
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
        if v[1] == ingredient then
            table.remove(data.raw.recipe[recipe].ingredients, i)
        end
    end
end
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

-- set a completly new set of ingredients for recipe
function ei_lib.recipe_new(recipe, table_in, category)
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
    -- set ingredients
    data.raw.recipe[recipe].ingredients = table_in
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
local function recursive_copy(target, source)
    for key, value in pairs(source) do
        if tostring(key):find('^_') ~= 1 then
            if type(value) == 'table' then
                target[key] = target[key] or {}
                recursive_copy(target[key], source[key])
            else
                target[key] = source[key]
            end
        end
    end
end

--- Updates (overwriting) a given prototype's attributes with the given data
--- properties starting with underscore "_property" will be ignored
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
    recursive_copy(prototype, obj)
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

function ei_lib.merge_item(target, item, icon_transfer)

    if not data.raw.item[target] then return end
    if not data.raw.item[item] then return end
    icon_transfer = icon_transfer or false

    -- loop over all recipes and swap
    for recipe_name,_ in pairs(data.raw.recipe) do
        local recipe = data.raw.recipe[recipe_name]
        
        ei_lib.do_item_merge(recipe, target, item)
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

-- Simulate lightning strike at position
function ei_lib.strike_lightning(surface, pos)
  if not surface or not pos then return end
  local palette = storage.ei and storage.ei.tint_palette
  if not palette then
    log("strike_lightning: no tint_palette available")
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

  local colors = {
    {112, 48, 160},  -- Royal purple
    {0, 123, 167},   -- Cerulean
    {186, 85, 211},  -- Orchid flare
    {72, 209, 204},  -- Crystal teal
    {255, 105, 180}, -- Etheric pink
    {240, 230, 140}, -- Dream gold
    {50, 205, 50},   -- Verdant flux
    {255, 69, 0}     -- Solar flare
  }

function ei_lib.pick_gradient_stops()
    local stops = {}
    local num_stops = math.random(2, 4)
    for i = 1, num_stops do
      table.insert(stops, colors[math.random(8)]) --#colors
    end
    return stops
  end


-------------------------------Crystal Messages
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


function ei_lib.compute_palette_checksum(palette)
  local keys = {}
  for name in pairs(palette) do table.insert(keys, name) end
  table.sort(keys)

  local checksum = 0
  for _, name in ipairs(keys) do
    local data = palette[name]
    local str = name .. ":" .. (data.adj or "") .. ":" .. (data.hex or "") .. ":" .. (data.intent or "")
    for i = 1, #str do
      checksum = (checksum + str:byte(i)) % 2147483647
    end
  end
  return checksum
end
    local palette = {
    mirage      = { adj = "eldritch",    hex = "#2af9aa", intent = "mystery" },
    specter     = { adj = "entropic",    hex = "#d19e79", intent = "signal" },
    singularity = { adj = "mirrored",    hex = "#c58681", intent = "mystery" },
    void        = { adj = "entropic",    hex = "#cccba7", intent = "signal" },
    mycelium    = { adj = "mystic",      hex = "#ef7ef4", intent = "mystery" },
    halo        = { adj = "mystic",      hex = "#708a43", intent = "mystery" },
    aurora      = { adj = "silent",      hex = "#404f7d", intent = "serenity" },
    frost       = { adj = "celestial",   hex = "#222a9f", intent = "divine" },
    pulse       = { adj = "radiant",     hex = "#624385", intent = "divine" },
    venom       = { adj = "toxic",       hex = "#2b6624", intent = "wrath" },
    dusk        = { adj = "luminous",    hex = "#49bad9", intent = "serenity" },
    starlight   = { adj = "radiant",     hex = "#bd3097", intent = "divine" },
    flux        = { adj = "toxic",       hex = "#a5c3f0", intent = "wrath" },
    node        = { adj = "dormant",     hex = "#4c7759", intent = "serenity" },
    resonance   = { adj = "glacial",     hex = "#2dbd66", intent = "serenity" },
    core        = { adj = "lunar",       hex = "#d77ec1", intent = "divine" },
    glyph       = { adj = "dissonant",   hex = "#e56af6", intent = "signal" },
    chime       = { adj = "auric",       hex = "#b7cc29", intent = "divine" },
    matrix      = { adj = "volatile",    hex = "#ae8fff", intent = "wrath" },
    spire       = { adj = "dissonant",   hex = "#e8a893", intent = "signal" },
    veil        = { adj = "eternal",     hex = "#32e4aa", intent = "mystery" },
    rift        = { adj = "iridescent",  hex = "#a57880", intent = "mystery" },
    sigil       = { adj = "unstable",    hex = "#8189d0", intent = "wrath" },
    shard       = { adj = "quantum",     hex = "#b982bd", intent = "signal" },
    beam        = { adj = "solar",       hex = "#44caee", intent = "wrath" }
    }
function ei_lib.initialize_crystal_data(override, altpal)
  override = override or false

  -- === PRIMARY TINT PALETTE ===
  local palette = {
    mirage      = { adj = "eldritch",    hex = "#2af9aa", intent = "mystery" },
    specter     = { adj = "entropic",    hex = "#d19e79", intent = "signal" },
    singularity = { adj = "mirrored",    hex = "#c58681", intent = "mystery" },
    void        = { adj = "entropic",    hex = "#cccba7", intent = "signal" },
    mycelium    = { adj = "mystic",      hex = "#ef7ef4", intent = "mystery" },
    halo        = { adj = "mystic",      hex = "#708a43", intent = "mystery" },
    aurora      = { adj = "silent",      hex = "#404f7d", intent = "serenity" },
    frost       = { adj = "celestial",   hex = "#222a9f", intent = "divine" },
    pulse       = { adj = "radiant",     hex = "#624385", intent = "divine" },
    venom       = { adj = "toxic",       hex = "#2b6624", intent = "wrath" },
    dusk        = { adj = "luminous",    hex = "#49bad9", intent = "serenity" },
    starlight   = { adj = "radiant",     hex = "#bd3097", intent = "divine" },
    flux        = { adj = "toxic",       hex = "#a5c3f0", intent = "wrath" },
    node        = { adj = "dormant",     hex = "#4c7759", intent = "serenity" },
    resonance   = { adj = "glacial",     hex = "#2dbd66", intent = "serenity" },
    core        = { adj = "lunar",       hex = "#d77ec1", intent = "divine" },
    glyph       = { adj = "dissonant",   hex = "#e56af6", intent = "signal" },
    chime       = { adj = "auric",       hex = "#b7cc29", intent = "divine" },
    matrix      = { adj = "volatile",    hex = "#ae8fff", intent = "wrath" },
    spire       = { adj = "dissonant",   hex = "#e8a893", intent = "signal" },
    veil        = { adj = "eternal",     hex = "#32e4aa", intent = "mystery" },
    rift        = { adj = "iridescent",  hex = "#a57880", intent = "mystery" },
    sigil       = { adj = "unstable",    hex = "#8189d0", intent = "wrath" },
    shard       = { adj = "quantum",     hex = "#b982bd", intent = "signal" },
    beam        = { adj = "solar",       hex = "#44caee", intent = "wrath" },
  }

  -- === PREPROCESS: ADD NAME + RGB ===
  for name, data in pairs(palette) do
    data.name = name
    data.rgb = ei_lib.hex_to_rgb_raw(data.hex)
  end

  -- === CHECKSUM GUARD ===
  local checksum = ei_lib.compute_palette_checksum(palette)
  if storage.ei.tint_palette_checksum == checksum then
    if not override then
      log("ei_lib.initialize_crystal_data: checksum match, skipping")
      return
    elseif override and not altpal then
      log("ei_lib.initialize_crystal_data: override without altpal, skipping")
      return
    else
      log("ei_lib.initialize_crystal_data: override with altpal, proceeding")
    end
  end

  -- === DERIVED TABLES ===
  local tint_adjectives = {}              -- [tint_name] = { adj, hex }
  local crystal_colors = {}              -- { {r,g,b}, ... }
  local intent_tint_map = {}             -- [intent] = { tint_name, ... }

  for name, data in pairs(palette) do
    tint_adjectives[name] = { adj = data.adj, hex = data.hex }
    table.insert(crystal_colors, data.rgb)

    local intents = type(data.intent) == "table" and data.intent or {data.intent}
    for _, intent in ipairs(intents) do
      intent_tint_map[intent] = intent_tint_map[intent] or {}
      table.insert(intent_tint_map[intent], name)
    end
  end

  -- === PERSIST TO GLOBAL STORAGE ===
  storage.ei.tint_palette = palette
  storage.ei.tint_palette_checksum = checksum

  storage.ei.tint_adjectives = tint_adjectives
  storage.ei.tint_adjectives_checksum = ei_lib.compute_palette_checksum(tint_adjectives)

  storage.ei.crystal_colors = crystal_colors
  storage.ei.crystal_colors_checksum = ei_lib.compute_palette_checksum(crystal_colors)

  storage.ei.intent_tint_map = intent_tint_map
  storage.ei.intent_tint_map_checksum = ei_lib.compute_palette_checksum(intent_tint_map)

  log("ei_lib.initialize_crystal_data: Reinstantiation complete")
end



function ei_lib.rebuild_tint_intent_table()
    if ei_lib.compute_palette_checksum(tint_palette) == storage.ei.intent_tint_checksum then
        log("ei_lib.rebuild_tint_intent_table returned due to same checksum")
        return
    end
    local intent_tint_map = {}
    for tint_name, data in pairs(tint_palette) do
      local intents = type(data.intent) == "table" and data.intent or {data.intent}
      for _, intent in ipairs(intents) do
        intent_tint_map[intent] = intent_tint_map[intent] or {}
        table.insert(intent_tint_map[intent], tint_name)
      end
    end
    storage.ei.intent_tint_map = intent_tint_map
end

function ei_lib.get_adjective_and_tint(tint)
tint.display = tint.adj:gsub("^%l", string.upper) .. " " .. tint.name
    return tint.display
    end
function ei_lib.pick_tint_from_intent(intent)
  local pool = intent_tint_map[intent or ""] or {}
  return #pool > 0 and pool[ei_rng.int("picktint",1,#pool)] or nil
end

-- Controlled variation (+/- 15)
local function vary(c)
  local v = c + ei_rng.int("vary",-15, 15)
  return math.max(0, math.min(255, v))
end

function ei_lib.generate_crystal_gradient_stops(min_stops, max_stops)
  local stops = {}
  local count = ei_rng.int("trainglowscale",min_stops or 2, max_stops or 4)

  for _ = 1, count do
    -- Pick a base color
    local base = storage.ei.crystal_colors[ei_rng.int("crystalgradient",1,#storage.ei.crystal_colors)]
    table.insert(stops, {
      vary(base[1]),
      vary(base[2]),
      vary(base[3])
    })
  end

  return stops
end


function ei_lib.pick_gradient_stops()
  return ei_lib.generate_crystal_gradient_stops(2, 4)
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
  local intent_tint_map = storage.ei.intent_tint_map  -- {intent = {"tint_name", ...}}
  local tint_palette = storage.ei.tint_palette        -- {tint_name = {hex, adj, intent, ...}}

  if not tint and intent and intent_tint_map[intent] then
    local pool = intent_tint_map[intent]
    tint = pool[ei_rng.int("trainglowscale",1,#pool)]
  end

  -- === EXTRACT TINT DATA FROM PALETTE ===
  local tint_info = tint and tint_palette[tint]
  local tint_color = tint_info and tint_info.hex and tint_info.hex:gsub("#", "")  -- remove leading #
  local tint_rgb = tint_color and ei_lib.hex_to_rgb_normalized(tint_color)                   -- convert to RGB {r,g,b}
  local tint_label = tint_info and tint_info.name or nil                          -- full name of tint (e.g., "solar flare")

  -- === SUBSTITUTE PLACEHOLDER TOKENS ===
  -- Replace {tint} and {tint_adj} in the message with correct values from the tint_palette
  if tint_label then
    msg = msg:gsub("{tint}", tint_label)
    msg = msg:gsub("{tint_adj}", tint_info.adj or "mysterious")
  end

  -- === DETERMINE POSITION OF TINT IN FINAL STRING ===
  -- This allows us to apply a specific color to just the {tint} portion later.
  local tint_start, tint_end = nil, nil
  if tint_label then
    local start_pos = msg:find(tint_label, 1, true)
    if start_pos then
      tint_start = start_pos
      tint_end = start_pos + #tint_label - 1
    end
  end

  -- === PREPARE COLOR GRADIENT ===
  -- If not using force_full_tint, generate a multi-color gradient for text
  local gradient = not force_full_tint and ei_lib.pick_gradient_stops() or nil
  local segments = gradient and (ei_lib.getn(gradient) - 1) or nil

  -- === BUILD COLORED MESSAGE, CHARACTER BY CHARACTER ===
  local result = {}
  local total_chars = #msg

  for i = 1, total_chars do
    local char = msg:sub(i, i)
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
  local final_msg = table.concat(result)
  local target
  local canPrint
  -- === DETERMINE TARGET OUTPUT LOCATION ===
  if pcall(function() return game.get_player(player) end) then
    target = game.get_player(player)
    canPrint = true
  else
    target = player --technically can be any entity
  end
  -- === EMIT AS FLOATING TEXT OR CHAT ===
  if target and target.valid then
    if as_floating_text then
      rendering.draw_text{
        text = final_msg,
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

function ei_lib.crystal_echo_floating(msg, target, floating_timetolive)
    ei_lib.crystal_echo(msg, nil, target, nil, nil, nil, true, floating_timetolive)
end


return ei_lib

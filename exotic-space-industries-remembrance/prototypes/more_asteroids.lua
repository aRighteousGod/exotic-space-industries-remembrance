--Imported from More Asteroids ESI fork
--Tweaked for flavor and crunch profile
--================================================================================================
-- FUNCTIONS
--=================================================================================================
function create_asteroid_chunk_parameter(number)
    data:extend(
    {
      {
        type = "asteroid-chunk",
        name = "parameter-" .. number,
        icon = "__base__/graphics/icons/parameter/parameter-" .. number .. ".png",
        localised_name = {"parameter-x", tostring(number)},
        subgroup = "parameters",
        order = "a",
        parameter = true
      }
    })
  end
  
  for n = 0, 9 do
    create_asteroid_chunk_parameter(n)
  end
  
  
  -- damage-type.lua must run first.
  --[[
  small asteroids: use lasers because they are free
  medium asteroids: use gun turrets
  big asteroids: use rockets or railgun
  huge asteroids: use railgun
  
  We need a new damage type for the final railgun shot, something like Armor Piercing High Explosive (APHE)
    but we need a shorter more general term for the damage type, representing internal inside-out damage.
  Potential names: internal, trojan, detonate, depth, siege
  
  // Asteroid normals:
  // Directions match factorio screen space.
  // red is x, 1 if facing east, 0 is facing west.
  // green is y, 1 is facing south, 0 is facing north
  // blue is z, 1 is facing up, 0 is a tangent.
  // Red and green must have a neutral value of 0.5 for faces facing the camera.
  // Blender output settings: color management: Override, display device: XYZ, View: Raw, Look:None, Exposure:0, Gamma: 1
  ]]
  
  local simulations = require("__space-age__.prototypes.factoriopedia-simulations")
  
  local sounds = require("__base__.prototypes.entity.sounds")
  local space_age_sounds = require ("__space-age__.prototypes.entity.sounds")
  
  local asteroid_sizes = {"chunk", "small", "medium", "big", "huge"}
  local shared_resistances =
  {
    physical =
    {
      decrease = {0, 0, 0, 2000, 3000},
      percent = {0, 0, 10, 10, 10}
    },
    explosion =
    {
      decrease = {0, 0, 0, 0, 0},
      percent = {0, 50, 30, 10, 99}
    },
    laser =
    {
      decrease = {0, 0, 0, 0, 0},
      percent = {0, 20, 90, 95, 99}
    }
  }
  local shared_health = {0, 100, 400, 2000, 5000}
  local shared_mass = {0, 200000, 500000, 5000000, 100000000}
  local asteroids_data =
  {
    scrap =
    {
      order = "bc",
      mass = shared_mass,
      max_health = shared_health,
      resistances = shared_resistances,
      shading_data =
      {
        normal_strength = 1.2,
        light_width = 0,
        brightness = 0.9,
        specular_strength = 2,
        specular_power = 2,
        specular_purity = 0,
        sss_contrast = 1,
        sss_amount = 0,
        lights = {
          { color = {0.96,1,0.99}, direction = {0.7,0.6,-1} },
          { color = {0.57,0.33,0.23}, direction = {-0.72,-0.46,1} },
          { color = {0.1,0.1,0.1}, direction = {-0.4,-0.25,-0.5} },
        },
        ambient_light = {0.01, 0.01, 0.01},
      }
    },
    rock =
    {
      order = "ab",
      mass = shared_mass,
      max_health = shared_health,
      resistances = shared_resistances,
      shading_data =
      {
        normal_strength = 1.2,
        light_width = 0,
        brightness = 0.9,
        specular_strength = 2,
        specular_power = 2,
        specular_purity = 0,
        sss_contrast = 1,
        sss_amount = 0,
        lights = {
          { color = {0.96,1,0.99}, direction = {0.7,0.6,-1} },
          { color = {0.57,0.33,0.23}, direction = {-0.72,-0.46,1} },
          { color = {0.1,0.1,0.1}, direction = {-0.4,-0.25,-0.5} },
        },
        ambient_light = {0.01, 0.01, 0.01},
      }
    },
    uranium =
    {
      order = "ab",
      mass = shared_mass,
      max_health = shared_health,
      resistances = shared_resistances,
      shading_data =
      {
        normal_strength = 1.2,
        light_width = 0,
        brightness = 0.9,
        specular_strength = 2,
        specular_power = 2,
        specular_purity = 0,
        sss_contrast = 1,
        sss_amount = 0,
        lights = {
          { color = {0.96,1,0.99}, direction = {0.7,0.6,-1} },
          { color = {0.57,0.33,0.23}, direction = {-0.72,-0.46,1} },
          { color = {0.1,0.1,0.1}, direction = {-0.4,-0.25,-0.5} },
        },
        ambient_light = {0.01, 0.01, 0.01},
      }
    },
    chemical =
    {
      order = "cd",
      mass = shared_mass,
      max_health = shared_health,
      resistances = shared_resistances,
      shading_data =
      {
        normal_strength = 1.2,
        light_width = 0,
        brightness = 0.9,
        specular_strength = 2,
        specular_power = 2,
        specular_purity = 0,
        sss_contrast = 1,
        sss_amount = 0,
        lights = {
          { color = {0.96,1,0.99}, direction = {0.7,0.6,-1} },
          { color = {0.57,0.33,0.23}, direction = {-0.72,-0.46,1} },
          { color = {0.1,0.1,0.1}, direction = {-0.4,-0.25,-0.5} },
        },
        ambient_light = {0.01, 0.01, 0.01},
      }
    },
    organic =
    {
      order = "cd",
      mass = shared_mass,
      max_health = shared_health,
      resistances = shared_resistances,
      shading_data =
      {
        normal_strength = 1.2,
        light_width = 0,
        brightness = 0.9,
        specular_strength = 2,
        specular_power = 2,
        specular_purity = 0,
        sss_contrast = 1,
        sss_amount = 0,
        lights = {
          { color = {0.96,1,0.99}, direction = {0.7,0.6,-1} },
          { color = {0.57,0.33,0.23}, direction = {-0.72,-0.46,1} },
          { color = {0.1,0.1,0.1}, direction = {-0.4,-0.25,-0.5} },
        },
        ambient_light = {0.01, 0.01, 0.01},
      }
    },
    petrified =
    {
      order = "cd",
      mass = shared_mass,
      max_health = shared_health,
      resistances = shared_resistances,
      shading_data =
      {
        normal_strength = 1.2,
        light_width = 0,
        brightness = 0.9,
        specular_strength = 2,
        specular_power = 2,
        specular_purity = 0,
        sss_contrast = 1,
        sss_amount = 0,
        lights = {
          { color = {0.96,1,0.99}, direction = {0.7,0.6,-1} },
          { color = {0.57,0.33,0.23}, direction = {-0.72,-0.46,1} },
          { color = {0.1,0.1,0.1}, direction = {-0.4,-0.25,-0.5} },
        },
        ambient_light = {0.01, 0.01, 0.01},
      }
    }
  }
  
  local collision_radiuses =
  {
    0.4, -- chunk
    0.5, -- small
    1, -- medium
    2, -- big
    4.5  -- huge
  }
  
  local graphics_scale =
  {
    0.5, -- chunk
    0.5, -- small
    0.5, -- medium
    0.6, -- big
    0.75 -- huge
  }
  
  local sizes_resolution = {
    {50,1}, -- chunk
    {128,1}, -- small
    {230,0}, -- medium
    {304,6}, -- big
    {512,0} -- huge
  }
  
  local letter = {"a","b","c","d","e"}

  --temporary fix to get some graphics working so that I can differentiate them during debugging, will remove later if i learn how to do normals, roughness.
  --color textures for each asteroid are simply copies of each mapped out asteroid with different basic filter options to distinguish them
  --the filters were done in Windows base Photos app
  --Rock: Brightness, Exposure, Contrast, Shadow, and Saturation all -50
  --Uranium: Saturation 100, Warmth 100, Tint -100
  --chemical: warmth 100, tint -100
  --organic: exposure 100, saturation 100, warmth 100, tint -100, i think,  i did it then walked away and forgot to write the settings down
  --petrified: saturation 100, warmth 100, tint 100

  local asteroid_map = {
    ["scrap"] = "metallic",
    ["rock"] = "metallic",
    ["uranium"] = "metallic",
    ["chemical"] = "oxide",
    ["organic"] = "carbonic",
    ["petrified"] = "carbonic"

  }


  
  local function asteroid_variation(asteroid_type, suffix, scale, size)
    return
    {
      color_texture =
      {
        filename = ei_graphics_3_path.."graphics/entity/asteroid/".. asteroid_type .."/"..asteroid_sizes[size].."/".."asteroid-" .. asteroid_type .. "-" .. asteroid_sizes[size] .. "-colour-" .. suffix .. ".png",
        size =  sizes_resolution[size][1],
        scale = scale
      },
  
      shadow_shift = { 0.25 * size, 0.25 * size },
  
      normal_map =
      {
        filename = "__space-age__/graphics/entity/asteroid/".. asteroid_map[asteroid_type] .."/"..asteroid_sizes[size].."/".."asteroid-" .. asteroid_map[asteroid_type] .. "-" .. asteroid_sizes[size] .. "-normal-" .. suffix .. ".png",
        premul_alpha = false,
        size = sizes_resolution[size][1],
        scale = scale
      },
  
      roughness_map =
      {
        filename = "__space-age__/graphics/entity/asteroid/".. asteroid_map[asteroid_type] .."/"..asteroid_sizes[size].."/".."asteroid-" .. asteroid_map[asteroid_type] .. "-" .. asteroid_sizes[size] .. "-roughness-" .. suffix .. ".png",
        premul_alpha = false,
        size = sizes_resolution[size][1],
        scale = scale
      }
    }
  end
  
  local function asteroid_graphics_set(rotation_speed, shading_data, variations)
    local result = table.deepcopy(shading_data)
    result.rotation_speed = rotation_speed
    result.variations = variations
    return result
  end
  
  for asteroid_size, asteroid_size_name in pairs(asteroid_sizes) do
    for asteroid_type, asteroid_data in pairs(asteroids_data) do
  
      local graphics_scale = graphics_scale[asteroid_size]
      local collision_radius = collision_radiuses[asteroid_size]
      local selection_radius = collision_radius * 1.1 + 0.1
      local max_health = asteroid_data.max_health[asteroid_size] > 0 and asteroid_data.max_health[asteroid_size] or nil
      local asteroid_name, resistances, factoriopedia_sim
      local dying_trigger_effects =
      {
        {
          type = asteroid_size_name == "chunk" and "create-entity" or "create-explosion",
          entity_name = asteroid_map[asteroid_type].."-asteroid-explosion-"..asteroid_size,
        }
      }
  
      if asteroid_size_name == "chunk" then
        asteroid_name = "ei-"..asteroid_type .. "-asteroid-chunk"
      else
        asteroid_name = "ei-"..asteroid_size_name .. "-"..asteroid_type.."-asteroid"
        factoriopedia_sim = simulations["factoriopedia_ei_" .. asteroid_size_name .. "_" .. asteroid_type .. "_asteroid"]
        local spread = collision_radius * 0.5
  
        if asteroid_size == 2 then
          table.insert(dying_trigger_effects,
          {
            type = "create-asteroid-chunk",
            asteroid_name = "ei-"..asteroid_type.."-asteroid-chunk",
            offset_deviation = {{-spread, -spread}, {spread, spread}},
            offsets =
            {
              {-spread/2, -spread/4},
              {spread/2, -spread/4}
            }
          })
        else
          table.insert(dying_trigger_effects,
          {
            type = "create-entity",
            entity_name = "ei-"..asteroid_sizes[asteroid_size-1] .. "-"..asteroid_type.."-asteroid",
            offset_deviation = {{-spread, -spread}, {spread, spread}},
            offsets =
            {
              {-spread, -spread/4},
              {0, -spread/2},
              {spread, -spread/4}
            }
          })
        end
  
        resistances = {}
        for damage_name, damage_type in pairs(data.raw["damage-type"]) do
          if asteroid_data.resistances[damage_name] then
            table.insert(resistances,
            {
              type = damage_name,
              decrease = asteroid_data.resistances[damage_name].decrease[asteroid_size],
              percent = asteroid_data.resistances[damage_name].percent[asteroid_size]
            })
          else
            if damage_name ~= "impact" and damage_name ~= "poison" and damage_name ~= "acid" then
              table.insert(resistances,
              {
                type = damage_name,
                percent = 100
              })
            end
          end
        end
      end
  
  
      local variations ={}
      if (asteroid_size_name == "chunk") then
        table.insert(variations, asteroid_variation(asteroid_type, "01", graphics_scale, asteroid_size))
      elseif (asteroid_size_name == "small") then
        table.insert(variations, asteroid_variation(asteroid_type, "01", graphics_scale, asteroid_size))
      elseif  (asteroid_size_name == "medium") then
        table.insert(variations, asteroid_variation(asteroid_type, "01", graphics_scale, asteroid_size))
      elseif (asteroid_size_name == "big") then
        table.insert(variations, asteroid_variation(asteroid_type, "01", graphics_scale, asteroid_size))
      elseif  (asteroid_size_name == "huge") then
        table.insert(variations, asteroid_variation(asteroid_type, "01", graphics_scale, asteroid_size))
      end

  
      data:extend
      {
        {
          type = asteroid_size_name == "chunk" and "asteroid-chunk" or "asteroid",
          name = asteroid_name,
          overkill_fraction = asteroid_size_name ~= "chunk" and 0.01 or nil,
          localised_description = {"entity-description.ei-"..asteroid_type.."-asteroid"},
          icon = ei_graphics_3_path.."graphics/icons/"..string.sub(asteroid_name, 4)..".png", --remove "ei-"
          icon_size = 64,
          selection_box = asteroid_size_name ~= "chunk" and {{-selection_radius, -selection_radius}, {selection_radius, selection_radius}} or nil,
          collision_box = asteroid_size_name ~= "chunk" and {{-collision_radius, -collision_radius}, {collision_radius, collision_radius}} or nil,
          collision_mask = asteroid_size_name ~= "chunk" and {layers={object=true}, not_colliding_with_itself=true} or nil,
          graphics_set = asteroid_graphics_set(0.0003 * (6 - asteroid_size), asteroids_data[asteroid_type].shading_data, variations),
          dying_trigger_effect = dying_trigger_effects,
  
          subgroup = asteroid_size_name == "chunk" and "space-material" or "space-environment",
          order = asteroid_data.order .. "["..asteroid_type.."]-"..letter[asteroid_size].."["..asteroid_size_name.."]",
          factoriopedia_simulation = factoriopedia_sim,
  
          -- asteroid-chunk properties
          minable = asteroid_size_name == "chunk" and {mining_time = 0.2, result = asteroid_name, mining_particle = asteroid_map[asteroid_type].."-asteroid-chunk-particle-medium" } or nil,
  
          -- asteroid properties
          flags = asteroid_size_name ~= "chunk" and {"placeable-enemy", "placeable-off-grid", "not-repairable", "not-on-map"} or nil,
          max_health = asteroid_size_name ~= "chunk" and asteroid_data.max_health[asteroid_size] or nil,
          mass = asteroid_size_name ~= "chunk" and asteroid_data.mass[asteroid_size] or nil,
          resistances = resistances,
        }
      }
    end
  end
  
  -- chunk backlight overrides
  data.raw["asteroid-chunk"]["metallic-asteroid-chunk"].graphics_set.lights[2] = { color = {0.85,0.5,0.4}, direction = {-1,-45,0.1} }
  data.raw["asteroid-chunk"]["oxide-asteroid-chunk"].graphics_set.lights[2] = { color = {0.0,0.55,0.65}, direction = {-1,-1,0.1} }

--================================================================================================
-- ITEMS
--================================================================================================

local sounds = require("__base__.prototypes.entity.sounds")
local space_age_sounds = require("__space-age__.prototypes.entity.sounds")
local item_sounds = require("__base__.prototypes.item_sounds")
local space_age_item_sounds = require("__space-age__.prototypes.item_sounds")
local item_tints = require("__base__.prototypes.item-tints")
local item_effects = require("__space-age__.prototypes.item-effects")

data:extend({
    {
        type = "item",
        name = "ei-rock-asteroid-chunk",
        icon = ei_graphics_3_path.."graphics/icons/rock-asteroid-chunk.png",
        subgroup = "space-material",
        order = "a[metallic]-e[chunk]",
        inventory_move_sound = space_age_item_sounds.rock_inventory_move,
        pick_sound = space_age_item_sounds.rock_inventory_pickup,
        drop_sound = space_age_item_sounds.rock_inventory_move,
        stack_size = 1,
        weight = 100 * kg,
        random_tint_color = item_tints.iron_rust
      },
      {
        type = "item",
        name = "ei-uranium-asteroid-chunk",
        icon = ei_graphics_3_path.."graphics/icons/uranium-asteroid-chunk.png",
        subgroup = "space-material",
        order = "a[metallic]-e[chunk]",
        inventory_move_sound = space_age_item_sounds.rock_inventory_move,
        pick_sound = space_age_item_sounds.rock_inventory_pickup,
        drop_sound = space_age_item_sounds.rock_inventory_move,
        stack_size = 1,
        weight = 100 * kg,
        random_tint_color = item_tints.iron_rust
      },
      {
        type = "item",
        name = "ei-scrap-asteroid-chunk",
        icon = ei_graphics_3_path.."graphics/icons/scrap-asteroid-chunk.png",
        subgroup = "space-material",
        order = "a[metallic]-e[chunk]",
        inventory_move_sound = space_age_item_sounds.rock_inventory_move,
        pick_sound = space_age_item_sounds.rock_inventory_pickup,
        drop_sound = space_age_item_sounds.rock_inventory_move,
        stack_size = 1,
        weight = 100 * kg,
        random_tint_color = item_tints.iron_rust
      },
      {
        type = "item",
        name = "ei-organic-asteroid-chunk",
        icon = ei_graphics_3_path.."graphics/icons/organic-asteroid-chunk.png",
        subgroup = "space-material",
        order = "a[metallic]-e[chunk]",
        inventory_move_sound = space_age_item_sounds.sulfur_inventory_move,
        pick_sound = space_age_item_sounds.resource_inventory_pickup,
        drop_sound = space_age_item_sounds.sulfur_inventory_move,
        stack_size = 1,
        weight = 100 * kg,
        random_tint_color = item_tints.iron_rust
      },
      {
        type = "item",
        name = "ei-petrified-asteroid-chunk",
        icon = ei_graphics_3_path.."graphics/icons/petrified-asteroid-chunk.png",
        subgroup = "space-material",
        order = "a[metallic]-e[chunk]",
        inventory_move_sound = space_age_item_sounds.sulfur_inventory_move,
        pick_sound = space_age_item_sounds.resource_inventory_pickup,
        drop_sound = space_age_item_sounds.sulfur_inventory_move,
        stack_size = 1,
        weight = 100 * kg,
        random_tint_color = item_tints.iron_rust
      },
      {
        type = "item",
        name = "ei-chemical-asteroid-chunk",
        icon = ei_graphics_3_path.."graphics/icons/chemical-asteroid-chunk.png",
        subgroup = "space-material",
        order = "a[metallic]-e[chunk]",
        inventory_move_sound = space_age_item_sounds.sulfur_inventory_move,
        pick_sound = space_age_item_sounds.resource_inventory_pickup,
        drop_sound = space_age_item_sounds.sulfur_inventory_move,
        stack_size = 1,
        weight = 100 * kg,
        random_tint_color = item_tints.iron_rust
      }
})
--===================================================================================================================
-- RECIPES
--===================================================================================================================
data:extend(
{
    {
        type = "recipe",
        name = "ei-uranium-asteroid-crushing",
        icon = ei_graphics_3_path.."graphics/icons/uranium-asteroid-crushing.png",
        category = "crushing",
        subgroup="space-crushing",
        order = "b-a-a",
        auto_recycle = false,
        enabled = false,
        ingredients =
        {
        {type = "item", name = "ei-uranium-asteroid-chunk", amount = 1},
        {type = "fluid", name = "sulfuric-acid", amount = 20}
        },
        energy_required = 2,
        results =
        {
        {type = "item", name = "uranium-ore", amount_min = 2,amount_max=10,probability=0.70},
        {type = "item", name = "uranium-235", amount_min = 1,amount_max=2, probability = 0.005},
        {type = "item", name = "uranium-238", amount_min = 1,amount_max=2, probability = 0.04},
		{type = "item", name = "ei-pure-lead", amount_min = 1,amount_max=4,probability=0.6},
        {type = "item", name = "ei-uranium-asteroid-chunk", amount = 1, probability = 0.01}
        },
        allow_productivity = true,
        allow_decomposition = false
    },
    {
        type = "recipe",
        name = "ei-advanced-uranium-asteroid-crushing",
        icon = ei_graphics_3_path.."graphics/icons/advanced-uranium-asteroid-crushing.png",
        category = "crushing",
        subgroup="space-crushing",
        order = "b-a-a",
        auto_recycle = false,
        enabled = false,
        ingredients =
        {
        {type = "item", name = "ei-uranium-asteroid-chunk", amount = 1},
        {type = "fluid", name = "sulfuric-acid", amount = 20}
        },
        energy_required = 2,
        results =
        {
        {type = "item", name = "uranium-ore", amount_min=4,amount_max = 14,probability=0.95},
        {type = "item", name = "uranium-235", amount_min = 1,amount_max=2, probability = 0.05},
        {type = "item", name = "uranium-238", amount = 1,amount_max=2, probability = 0.16},
		{type = "item", name = "ei-pure-lead", amount_min = 1,amount_max=4,probability=0.85},
        {type = "item", name = "ei-uranium-asteroid-chunk", amount = 1, probability = 0.02}
        },
        allow_productivity = true,
        allow_decomposition = false
    },
    {
        type = "recipe",
        name = "ei-rock-asteroid-crushing",
        icon = ei_graphics_3_path.."graphics/icons/rock-asteroid-crushing.png",
        category = "crushing",
        subgroup="space-crushing",
        order = "b-a-a",
        auto_recycle = false,
        enabled = false,
        ingredients =
        {
        {type = "item", name = "ei-rock-asteroid-chunk", amount = 1},
        },
        energy_required = 2,
        results =
        {
        {type = "item", name = "stone", amount_min = 10,amount_max=20},
        {type = "item", name = "ei-rock-asteroid-chunk", amount = 1, probability = 0.2}
        },
        allow_productivity = true,
        allow_decomposition = false
    },
    {
        type = "recipe",
        name = "ei-advanced-rock-asteroid-crushing",
        icon = ei_graphics_3_path.."graphics/icons/advanced-rock-asteroid-crushing.png",
        category = "crushing",
        subgroup="space-crushing",
        order = "b-a-a",
        auto_recycle = false,
        enabled = false,
        ingredients =
        {
        {type = "item", name = "ei-rock-asteroid-chunk", amount = 1},
        },
        energy_required = 2,
        results =
        {
        {type = "item", name = "stone", amount_min = 5,amount_max=10},
        {type = "item", name = "tungsten-ore", amount_min = 1,amount_max=5,probability=0.08},
		{type = "item", name = "ei-pure-gold", amount_min = 1,amount_max=2,probability=0.12},
        {type = "item", name = "ei-rock-asteroid-chunk", amount = 1, probability = 0.05}
        },
        allow_productivity = true,
        allow_decomposition = false
    },
    {
        type = "recipe",
        name = "ei-chemical-asteroid-crushing",
        icon = ei_graphics_3_path.."graphics/icons/chemical-asteroid-crushing.png",
        category = "crushing",
        subgroup="space-crushing",
        order = "b-a-a",
        auto_recycle = false,
        enabled = false,
        ingredients =
        {
        {type = "item", name = "ei-chemical-asteroid-chunk", amount = 1},
        },
        energy_required = 2,
        results =
        {
        {type = "fluid", name = "ammonia", amount_min = 5, amount_max=20,probability=0.5},
        {type = "item", name = "ei-fluorite", amount_min = 1,amount_max=5, probability=0.06},
        {type = "fluid", name = "fluorine", amount_min = 1,amount_max=5, probability=0.06},
        {type = "item", name = "ei-chemical-asteroid-chunk", amount = 1, probability = 0.2}
        },
        allow_productivity = true,
        allow_decomposition = false
    },
    {
        type = "recipe",
        name = "ei-advanced-chemical-asteroid-crushing",
        icon = ei_graphics_3_path.."graphics/icons/advanced-chemical-asteroid-crushing.png",
        category = "crushing",
        subgroup="space-crushing",
        order = "b-a-a",
        auto_recycle = false,
        enabled = false,
        ingredients =
        {
        {type = "item", name = "ei-chemical-asteroid-chunk", amount = 1},
        },
        energy_required = 2,
        results =
        {
        {type = "fluid", name = "ammonia", amount_min = 10, amount_max=20,probability=0.75},
        {type = "item", name = "ei-fluorite", amount_min = 1,amount_max=5, probability=0.33},
        {type = "fluid", name = "fluorine", amount_min = 1,amount_max=5, probability=0.33},
        {type = "fluid", name = "lithium-brine", amount_min = 1,amount_max=5,probability=0.08},
        {type = "item", name = "ei-chemical-asteroid-chunk", amount = 1, probability = 0.05}
        },
        allow_productivity = true,
        allow_decomposition = false
    },
    {
        type = "recipe",
        name = "ei-scrap-asteroid-crushing",
        icon = ei_graphics_3_path.."graphics/icons/scrap-asteroid-crushing.png",
        category = "crushing",
        subgroup="space-crushing",
        order = "b-a-a",
        auto_recycle = false,
        enabled = false,
        ingredients =
        {
        {type = "item", name = "ei-scrap-asteroid-chunk", amount = 1},
        },
        energy_required = 2,
        results =
        {
        {type = "item", name = "scrap", amount_min = 5,amount_max=20},
		{type = "item", name = "ei-crushed-neodym", amount = 1, probability=0.001},
        {type = "item", name = "ei-scrap-asteroid-chunk", amount = 1, probability = 0.2}
        },
        allow_productivity = true,
        allow_decomposition = false
    },
    {
        type = "recipe",
        name = "ei-advanced-scrap-asteroid-crushing",
        icon = ei_graphics_3_path.."graphics/icons/advanced-scrap-asteroid-crushing.png",
        category = "crushing",
        subgroup="space-crushing",
        order = "b-a-a",
        auto_recycle = false,
        enabled = false,
        ingredients =
        {
        {type = "item", name = "ei-scrap-asteroid-chunk", amount = 1},
        },
        energy_required = 2,
        results =
        {
        {type = "item", name = "scrap", amount_min = 10, amount_max = 20},
		{type = "item", name = "ei-crushed-neodym", amount = 1, probability=0.004},
        {type = "item", name = "ei-scrap-asteroid-chunk", amount = 1, probability = 0.05}
        },
        allow_productivity = true,
        allow_decomposition = false
    },
    {
        type = "recipe",
        name = "ei-organic-asteroid-crushing",
        icon = ei_graphics_3_path.."graphics/icons/organic-asteroid-crushing.png",
        category = "crushing",
        subgroup="space-crushing",
        order = "b-a-a",
        auto_recycle = false,
        enabled = false,
        ingredients =
        {
        {type = "item", name = "ei-organic-asteroid-chunk", amount = 1},
        {type = "fluid", name = "water", amount = 50},
        },
        energy_required = 2,
        results =
        {
        {type = "item", name = "spoilage", amount_min = 5, amount_max = 50},
        {type = "fluid", name = "ei-bio-sludge", amount_min = 1,amount_max=4, probability=0.35},
		{type = "fluid", name = "ei-ammonia-gas", amount_min = 1,amount_max=5,probability=0.5},
        {type = "item", name = "ei-organic-asteroid-chunk", amount = 1, probability = 0.2}
        },
        allow_productivity = true,
        allow_decomposition = false
    },
    {
        type = "recipe",
        name = "ei-advanced-organic-asteroid-crushing",
        icon = ei_graphics_3_path.."graphics/icons/advanced-organic-asteroid-crushing.png",
        category = "crushing",
        subgroup="space-crushing",
        order = "b-a-a",
        auto_recycle = false,
        enabled = false,
        ingredients =
        {
        {type = "item", name = "ei-organic-asteroid-chunk", amount = 1},
        {type = "item", name = "nutrients", amount = 5},
        {type = "fluid", name = "water", amount = 50},
    
        },
        energy_required = 2,
        results =
        {
        {type = "item", name = "pentapod-egg", amount = 1, probability = 0.001},
        {type = "item", name = "yumako", amount = 5, probability = 0.13},
        {type = "item", name = "jellynut", amount = 10, probability = 0.125},
		{type = "item", name = "ei-bio-matter", amount_min=2,amount_max = 12, probability=0.25},
        {type = "fluid", name = "ei-bio-sludge", amount_min = 1,amount_max=8, probability=0.25},
		{type = "fluid", name = "ei-ammonia-gas", amount_min = 5,amount_max=10,probability=0.8},
        {type = "item", name = "ei-organic-asteroid-chunk", amount = 1, probability = 0.05}
        },
        allow_productivity = true,
        allow_decomposition = false
    },
    {
        type = "recipe",
        name = "ei-petrified-asteroid-crushing",
        icon = ei_graphics_3_path.."graphics/icons/petrified-asteroid-crushing.png",
        category = "crushing",
        subgroup="space-crushing",
        order = "b-a-a",
        auto_recycle = false,
        enabled = false,
        ingredients =
        {
        {type = "item", name = "ei-petrified-asteroid-chunk", amount = 1},
        },
        energy_required = 2,
        results =
        {
        {type = "item", name = "wood", amount_min = 5, amount_max = 20},
        {type = "item", name = "raw-fish", amount = 1, probability = 0.4},
		{type = "fluid", name = "ei-phythogas", amount_min = 5,amount_max=10,probability=0.5},
        {type = "item", name = "ei-petrified-asteroid-chunk", amount = 1, probability = 0.2}
        },
        allow_productivity = true,
        allow_decomposition = false
    },
    {
        type = "recipe",
        name = "ei-advanced-petrified-asteroid-crushing",
        icon = ei_graphics_3_path.."graphics/icons/advanced-petrified-asteroid-crushing.png",
        category = "crushing",
        subgroup="space-crushing",
        order = "b-a-a",
        auto_recycle = false,
        enabled = false,
        ingredients =
        {
        {type = "item", name = "ei-petrified-asteroid-chunk", amount = 1},
        {type = "item", name = "bioflux", amount = 5},
        {type = "fluid", name = "fluoroketone-cold", amount = 10},
        },
        energy_required = 2,
        results =
        {
        {type = "item", name = "wood", amount_min = 10, amount_max = 20},
        {type = "item", name = "raw-fish", amount = 1, probability = 0.6},
        {type = "item", name = "biter-egg", amount = 1,probability=0.05},
		{type = "fluid", name = "ei-phythogas", amount_min = 10,amount_max=20,probability=0.65},
        {type = "item", name = "ei-petrified-asteroid-chunk", amount = 1, probability = 0.05}
        },
        allow_productivity = true,
        allow_decomposition = false
    }
  })

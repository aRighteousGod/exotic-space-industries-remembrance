local ei_lib = require("lib/lib")
local ei_data = require("lib/data")

--TECHS
------------------------------------------------------------------------------------------------------
---
---make automation obey tech multiplier
local auto_tech = ei_lib.raw.technology["automation"]
if auto_tech then
    auto_tech.ignore_tech_cost_multiplier = false
end
--match with recipe changes
ei_lib.add_prerequisite("big-mining-drill","ei-advanced-motor")
ei_lib.add_prerequisite("big-mining-drill","ei-electronic-parts")
ei_lib.add_prerequisite("big-mining-drill","ei-carbon-manipulation")

ei_lib.raw.technology["radar"].age = "electricity-age"
local removerecipes = {
    "iron-stick",
    "iron-gear-wheel"
}
for _,technology in pairs(data.raw.technology) do
    if technology and technology.effects then
        for _,unlock in pairs(technology.effects) do
            if ei_lib.table_contains_value(removerecipes,unlock) then
                table.remove(technology.effects,unlock)
            end
        end
    end
end
ei_lib.remove_unlock_recipe("kovarex-enrichment-process", "kovarex-enrichment-process")
if data.raw.recipe["kovarex-enrichment-process"] then
    data.raw.recipe["kovarex-enrichment-process"].hidden = true
end

local kovarex_tech = ei_lib.raw["technology"]["kovarex-enrichment-process"]
if kovarex_tech then
    kovarex_tech.hidden = true
    kovarex_tech.localised_name = {"technology-name.ei-kovarex-fuel-enrichment"}
    kovarex_tech.localised_description = {"technology-description.ei-kovarex-fuel-enrichment"}
end

ei_lib.overwrite_entity_and_description("logistic-system","technology") -- overwrite to theory fluff because ei logistic containers is an post-grad tech
ei_lib.remove_unlock_recipe("logistic-system", "active-provider-chest")
ei_lib.remove_unlock_recipe("logistic-system", "buffer-chest")
ei_lib.remove_unlock_recipe("logistic-system", "requester-chest")
ei_lib.remove_unlock_recipe("logistic-robotics", "requester-chest")
ei_lib.remove_unlock_recipe("logistic-robotics", "passive-provider-chest")
ei_lib.remove_unlock_recipe("logistic-robotics", "storage-chest")
ei_lib.remove_unlock_recipe("construction-robotics", "passive-provider-chest")
ei_lib.remove_unlock_recipe("construction-robotics", "storage-chest")

--hide and disable vanilla logistic chests
local default_logi_chests = {
    "active-provider-chest",
    "buffer-chest",
    "requester-chest",
    "passive-provider-chest",
    "storage-chest"
}

for chest in pairs(default_logi_chests) do
    local hide_item = ei_lib.raw.item[chest]
    if hide_item then
        hide_item.hidden = true
        hide_item.enabled = false
    end
    local hide_recipe = ei_lib.raw.recipe[chest]
    if hide_recipe then
        hide_recipe.hidden = true
        hide_recipe.enabled = false
    end
end
--need investigate why the pre-req table doesn't always stick
ei_lib.raw["technology"]["flamethrower"].age = "steam-age"
ei_lib.raw["technology"]["concrete"].age = "steam-age"
ei_lib.set_prerequisites("concrete", {"advanced-material-processing"})
ei_lib.remove_unlock_recipe("concrete","iron-stick")
local new_prerequisites_table = {}

-- first index is tech second is prerequisite
-- changing things here can have inadvertent knock-on effects on science pack
-- requirements for technologies which use these as a prerequisite before
-- they're updated, double check things and make the changes in
-- final-updates/set_age_packs and set_prerequisites if it won't behave
new_prerequisites_table["steam-age"] = {
    {"flammables", "ei-steam-oil-processing"},
    {"automated-rail-transportation", "ei-steam-basic-train"},
    {"rail-signals", "ei-steam-basic-train"},
    {"braking-force-1", "ei-steam-basic-train"},
    {"steel-processing", "ei-steam-crusher"},
    {"engine", "ei-steam-oil-processing"},
    {"electronics", "ei-glass"},
    {"flamethrower","flammables"},
    {"concrete","advanced-material-processing"},
    {"advanced-material-processing","steel-processing"},
    {"automobilism","engine"}
}

new_prerequisites_table["electricity-age"] = {
    {"automation", "ei-electricity-power"},
    {"automation", "advanced-circuit"},
    {"fast-inserter", "automation"},
    {"fast-inserter", "ei-grower"},
    {"circuit-network", "ei-electricity-power"},
    {"lamp", "ei-electricity-power"},
    {"robotics", "ei-electronic-parts"},
--    {"lubricant", "ei-destill-tower"}, --moved to set_prerequisites
    {"sulfur-processing", "ei-destill-tower"},
    {"coal-liquefaction", "ei-benzol"},
--    {"advanced-oil-processing", "ei-electricity-age-tech"}, --moved to data
    {"laser", "ei-grower"},
    {"power-armor", "ei-grower"},
    {"solar-energy", "ei-waver-factory"},
    {"advanced-material-processing-2", "ei-electricity-power"},
    {"solar-panel-equipment", "solar-energy"},
    {"solar-panel-equipment", "advanced-circuit"},
    {"radar", "ei-electricity-power"},
    {"tank","advanced-circuit"},
    {"tank","explosives"},
    {"logistics-2","plastics"}
}

new_prerequisites_table["computer-age"] = {
    {"speed-module-2", "ei-computer-core"},
    {"productivity-module-2", "ei-computer-core"},
    {"efficiency-module-2", "ei-computer-core"},
    {"quality-module-2", "ei-computer-core"},
    {"rocket-silo", "ei-computer-age"},
    {"low-density-structure", "ei-advanced-steel"},
    {"ei-rocket-parts", "rocket-fuel"},
    {"rocket-silo", "ei-rocket-parts"},
    {"rocket-silo", "ei-advanced-motor"},
    {"rocket-silo", "processing-unit"},
    {"fission-reactor-equipment", "ei-high-temperature-reactor"},
    {"bulk-inserter","ei-advanced-motor"},
    {"inserter-capacity-bonus-1","ei-advanced-motor"}
}


new_prerequisites_table["advanced-computer-age"] = {
}

new_prerequisites_table["quantum-age"] = {

}

local numbered_buffs = {
    "stronger-explosives-7",
    "mining-productivity-4",
    "research-speed-6",
    "worker-robots-speed-6",
    "worker-robots-storage-3",
    "laser-weapons-damage-7",
    "physical-projectile-damage-7",
    "refined-flammables-7",
    "inserter-capacity-bonus-7",
    "braking-force-7",
    "laser-shooting-speed-7",
    "weapon-shooting-speed-6",
    "follower-robot-count-5"
}

local prereqs_to_remove = {}

local function make_numbered_buff_prerequisite(tech)

    -- get last char of tech name as number
    local tech_number = tonumber(string.sub(tech, -1))

    if tech_number == 1 then
        return 
    end

    -- get previous tech name by removing last char
    local pre = tonumber(tech_number - 1)
    local previous_tech = string.sub(tech, 1, -2)..tostring(pre)

    if not data.raw["technology"][previous_tech] then
        return
    end

    -- add previous tech to prerequisites, if it not already is there
    if data.raw["technology"][tech] then
      if data.raw["technology"][tech].prerequisites then
        if not ei_lib.table_contains_value(data.raw["technology"][tech].prerequisites, previous_tech) then
          table.insert(data.raw["technology"][tech].prerequisites, previous_tech)
        end
      end
    end

    -- remove the age tech prerequisite if the previous tech and this tech share the same age
    if data.raw["technology"][tech] then
      if data.raw["technology"][tech].age and data.raw["technology"][previous_tech].age then

          if data.raw["technology"][tech].age == data.raw["technology"][previous_tech].age then

              -- check if this tech has the age tech as prerequisite
              local age_tech = ei_data.tech_ages_with_sub_reverse[data.raw["technology"][tech].age]

              if ei_lib.table_contains_value(data.raw["technology"][tech].prerequisites, age_tech) then
                  table.insert(prereqs_to_remove, {tech, age_tech})
              end

              -- also check if the main age tech is in the previous techs prerequisites
              if ei_data.sub_age[data.raw["technology"][tech].age] then

                  local main_age_tech = ei_data.tech_ages_with_sub_reverse[ei_data.sub_age[data.raw["technology"][tech].age]]

                  if ei_lib.table_contains_value(data.raw["technology"][previous_tech].prerequisites, main_age_tech) then
                      table.insert(prereqs_to_remove, {previous_tech, main_age_tech})
                  end

              end

          end

      end
    end

    make_numbered_buff_prerequisite(previous_tech)

end
--Nerf the beacon to promote the EI specific varieties
ei_lib.raw.beacon["beacon"] = {
    localised_description = {"entity-description.ei-beacon"},
    distribution_effectivity = 0.375,
    distribution_effectivity_bonus_per_quality_level = 0.125,
    module_slots = 1,
    energy_usage = "900kW",
}
ei_lib.raw.item["beacon"] = {
    localised_description = {"item-description.ei-beacon"},
}
ei_lib.raw.technology["effect-transmission"] = {
    localised_description = {"technology-description.ei-effect-transmission"},
}
ei_lib.raw.technology["steel-processing"].icon = ei_graphics_tech_path.."steel-processing.png"
ei_lib.raw.technology["fluid-handling"] = {
    icon = ei_graphics_tech_path.."barreling.png",
    icon_size = 256,
}

ei_lib.add_unlock_recipe("automation-2", "ei-ceramic")

ei_lib.add_unlock_recipe("landfill", "ei-landfill-sand")

ei_lib.raw.technology.electronics.effects = {
    {
        type = "unlock-recipe",
        recipe = "ei-electron-tube"
    },
    {
        type = "unlock-recipe",
        recipe = "electronic-circuit"
    },
    {
        type = "unlock-recipe",
        recipe = "copper-cable"
    },
    {
        type = "unlock-recipe",
        recipe = "ei-ceramic-steam-assembler"
    },
}
--rename to Electric chemical plant
ei_lib.raw.technology["oil-processing"] = {
    localised_name = {"technology-name.ei-oil-processing"},
    localised_description = {"technology-description.ei-oil-processing"}
}
--remove doubled up unlocks
ei_lib.remove_unlock_recipe("oil-processing", "oil-refinery")
ei_lib.remove_unlock_recipe("oil-processing", "basic-oil-processing")
ei_lib.remove_unlock_recipe("oil-processing", "solid-fuel-from-petroleum-gas")
--remove advanced oil processing
ei_lib.remove_unlock_recipe("advanced-oil-processing", "advanced-oil-processing")
ei_lib.raw.technology["advanced-oil-processing"] = {
    localised_name = {"technology-name.ei-advanced-oil-processing"},
    localised_description = {"technology-description.ei-advanced-oil-processing"}
}
--delete it outright to prevent misunderstandings of whether removal is intentional
ei_lib.raw.recipe["advanced-oil-processing"].hidden = true


-- edit electric enigne tech to use only steam age science for progression
--ei_lib.set_age_packs("electric-engine","steam-age")

-- make inserter-capaity-bonus-1 buff normal inserters

table.insert(ei_lib.raw.technology["inserter-capacity-bonus-1"].effects,
{
        type = "inserter-stack-size-bonus",
        modifier = 1
    }
)

--Remove vanilla nuclear fuel reprocessing
ei_lib.remove_unlock_recipe("nuclear-fuel-reprocessing","nuclear-fuel-reprocessing")
--Remove vanilla uranium processing in favor of EI complex processing
ei_lib.remove_unlock_recipe("uranium-processing", "uranium-processing")
ei_lib.remove_unlock_recipe("uranium-processing", "uranium-fuel-cell")
ei_lib.raw.recipe["uranium-processing"].hidden = true
ei_lib.raw.technology["nuclear-fuel-reprocessing"].hidden = true
--Move the recipe to 235 recycling
ei_lib.add_unlock_recipe("ei-uranium-235-recycling","nuclear-fuel-reprocessing")

--Bring nuclear fuel aka Uranium-235 fuel cell recipe in line with fuel rods
ei_lib.recipe_add("nuclear-fuel","ei-lead-ingot",1)
ei_lib.recipe_add("nuclear-fuel","ei-ceramic",4)
ei_lib.recipe_add("nuclear-fuel","uranium-238",1)
--Move fuel cell and depleted cell into Nuclear category
ei_lib.raw.recipe["nuclear-fuel"] = {
    subgroup = "ei-nuclear-fission-fuel",
}
--Update names and descriptions, set spent result
ei_lib.raw.item["nuclear-fuel"] = {
    localised_name = {"item-name.ei-nuclear-fuel"},
    localised_description = {"item-description.ei-nuclear-fuel"},
    subgroup = "ei-nuclear-fission-fuel",
    burnt_result = "depleted-uranium-fuel-cell",
    icon = ei_graphics_3_path.."graphics/items/uranium-fuel-cell.png",
    icon_size = 256,
    icon_mipmaps = 4,
    stack_size=20,
    fuel_top_speed_multiplier=1.25,
}
ei_lib.raw.recipe["nuclear-fuel-reprocessing"] = {
    localised_name = {"recipe-name.ei-depleted-uranium-fuel-cell"},
    subgroup = "ei-nuclear-processing",
    category="chemistry"
    
}
ei_lib.raw.item["depleted-uranium-fuel-cell"] = {
    localised_name = {"item-name.ei-depleted-uranium-fuel-cell"},
    localised_description = {"item-description.ei-depleted-uranium-fuel-cell"},
    subgroup = "ei-nuclear-fission-fuel",
    icon = ei_graphics_3_path.."graphics/items/depleted-uranium-fuel-cell.png",
    icon_size = 256,
    icon_mipmaps = 4,
    stack_size=20,
}
--Remove vanilla uranium fuel cell
ei_lib.remove_unlock_recipe("nuclear-power","uranium-fuel-cell")
--set fuel cell recycling to use fuel aka 235 fuel cell, etc
ei_lib.raw.recipe["nuclear-fuel-reprocessing"] = {
    ingredients = {
        {type="item",name="depleted-uranium-fuel-cell",amount=1},
        {type="fluid",name="ei-nitric-acid",amount=15}
    },
    results = {
        {type="item",name="ei-nuclear-waste",amount=1,probability=0.33},
        {type="fluid",name="ei-nitric-acid-uranium-235",amount=15}
    },
    main_product = "ei-nitric-acid-uranium-235",
}

for age,table_in in pairs(new_prerequisites_table) do
    for i,v in pairs(table_in) do
        ei_lib.add_prerequisite(v[1], v[2])
        ei_lib.remove_prerequisite(v[1], "ei-"..age)
    end
end

for _, tech in ipairs(numbered_buffs) do
    make_numbered_buff_prerequisite(tech)
end

for i,v in ipairs(prereqs_to_remove) do
    ei_lib.remove_prerequisite(v[1], v[2])
end

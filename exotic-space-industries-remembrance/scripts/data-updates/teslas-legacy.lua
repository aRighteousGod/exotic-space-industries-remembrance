--====================================================================================================
--CHECK FOR MOD
--====================================================================================================

if not mods["tesla_legacy_sa"] then
    return
end

local ei_lib = require("lib/lib")

--vanilla tesla weapons tech
local twt = ei_lib.raw.technology["tesla-weapons"]
if twt then
    twt.localised_name = {"technology-name.ei-tesla-weapons"}
    twt.localised_description = {"technology-description.ei-tesla-weapons"}
    ei_lib.add_prerequisite("tesla-weapons","tl-advanced-tesla-coils-technology")
end
--vanilla tesla turret item
local vtti = ei_lib.raw.item["tesla-turret"]
if vtti then
    vtti.localised_name = {"item-name.ei-tesla-turret"}
    vtti.localised_description = {"item-description.ei-tesla-turret"}
end
--vanilla tesla turret turret
local vttt = ei_lib.raw["electric-turret"]["tesla-turret"]
if vttt then
    vttt.localised_name = {"item-name.ei-tesla-turret"}
    vttt.localised_description = {"item-description.ei-tesla-turret"}
end

--vanilla electric weapon damage technology
table.insert(data.raw.technology["electric-weapons-damage-1"].effects,
    {
      type = "ammo-damage",
      ammo_category = "tl-basic-tesla-coil-turret-category",
      modifier = 0.15
    }
)
table.insert(data.raw.technology["electric-weapons-damage-1"].effects,
    {
      type = "ammo-damage",
      ammo_category = "tl-advanced-tesla-coil-turret-category",
      modifier = 0.15
    }
)
--2
table.insert(data.raw.technology["electric-weapons-damage-2"].effects,
    {
      type = "ammo-damage",
      ammo_category = "tl-basic-tesla-coil-turret-category",
      modifier = 0.15
    }
)
table.insert(data.raw.technology["electric-weapons-damage-2"].effects,
    {
      type = "ammo-damage",
      ammo_category = "tl-advanced-tesla-coil-turret-category",
      modifier = 0.15
    }
)
--3
table.insert(data.raw.technology["electric-weapons-damage-3"].effects,
    {
      type = "ammo-damage",
      ammo_category = "tl-basic-tesla-coil-turret-category",
      modifier = 0.15
    }
)
table.insert(data.raw.technology["electric-weapons-damage-3"].effects,
    {
      type = "ammo-damage",
      ammo_category = "tl-advanced-tesla-coil-turret-category",
      modifier = 0.15
    }
)
--4
table.insert(data.raw.technology["electric-weapons-damage-4"].effects,
    {
      type = "ammo-damage",
      ammo_category = "tl-basic-tesla-coil-turret-category",
      modifier = 0.3
    }
)
table.insert(data.raw.technology["electric-weapons-damage-4"].effects,
    {
      type = "ammo-damage",
      ammo_category = "tl-advanced-tesla-coil-turret-category",
      modifier = 0.3
    }
)

--vanilla tesla turret recipe
local vttr = ei_lib.raw.recipe["tesla-turret"]
if vttr then
    table.insert(vttr.ingredients,
    {type="item",name="tl-advanced-tesla-coil", amount=1}
    )
end
--advanced tesla coils technology
local atc = ei_lib.raw.technology["tl-advanced-tesla-coils-technology"]
if atc then
    ei_lib.add_prerequisite("tl-advanced-tesla-coils-technology","ei-advanced-computer-age-tech")
    ei_lib.add_prerequisite("tl-advanced-tesla-coils-technology","ei-electronic-parts")
end
--advanced tesla coil recipe
local atcr = ei_lib.raw.recipe["tl-advanced-tesla-coil"]
if atcr then
    atcr.additional_categories = {"electromagnetics"}
    atcr.ingredients = {
        {type="item",name="tl-basic-tesla-coil", amount=1},
        {type="item",name="substation", amount=2},
        {type="item",name="accumulator", amount=2},
        {type="item",name="copper-cable",amount=200},
        {type="item",name="ei-electronic-parts", amount=10},
        {type="item",name="steel-plate", amount=40},
    }
end
--basic tesla coils technology
local btct = ei_lib.raw.technology["tl-basic-tesla-coils-technology"]
if btct then
    --ei_lib.add_prerequisite("ti-basic-tesla-coils-technology","advanced-circuits")
end
--basic tesla coil recipe
local btcr = ei_lib.raw.recipe["tl-basic-tesla-coil"]
if btcr then
    btcr.additional_categories = {"electromagnetics"}
    btcr.ingredients = {
        {type="item",name="medium-electric-pole", amount=1},
        {type="item",name="ei-copper-beam", amount=2},
        {type="item",name="copper-cable",amount=50},
        {type="item",name="electronic-circuit", amount=5},
        {type="item",name="battery", amount=3},
    }
end

--tesla tank technology
local ttt = ei_lib.raw.technology["tl-tesla-tank-technology"]
if ttt then
    ei_lib.add_prerequisite("tl-tesla-tank-technology","ei-advanced-computer-age-tech")
    ei_lib.add_prerequisite("tl-tesla-tank-technology","ei-carbon-manipulation")
end

--tesla tank recipe
local ttr = ei_lib.raw.recipe["tl-tesla-tank"]
if ttr then
    ttr.additional_categories = {"electromagnetics"}
    ttr.ingredients = {
        {type="item",name="tank",amount=1},
        {type="item",name="ei-electronic-parts", amount=20},
        {type="item",name="accumulator", amount=20},
        {type="item",name="ei-advanced-motor",amount=50},
        {type="item",name="ei-carbon", amount=40},
        {type="item",name="tl-advanced-tesla-coil", amount=2},
    }
end

ei_lib.raw["car"]["tl-tesla-tank"].inventory_size = 16

local t_extra_fuels = {
    "ei-rocket-fuel",
    "ei-nuclear-fuel",
    "ei-nuclear-fuel-cell",
    "ei-fusion-fuel",
    "ei-diesel-fuel"
}
local t = {
    "tl-tesla-tank",
}
for _,ent in pairs(t) do
    local target = data.raw.car[ent]
    if target and target.energy_source and target.energy_source.fuel_categories then
        for _,f in pairs(t_extra_fuels) do
            table.insert(target.energy_source.fuel_categories,f)
        end
    end
end
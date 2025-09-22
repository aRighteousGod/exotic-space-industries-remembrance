--====================================================================================================
--CHECK FOR MOD
--====================================================================================================

--fire extinguisher
if not mods["enhanced-walls"] then
    return
end

ei_lib = require("lib/lib")
--tough wall
local twi = ei_lib.raw.item["tough-wall"]
twi.subgroup = "defensive-structure"
twi.order = "a[stone-wall]-a[stone-wall]2"
twi.localised_name = {"item-name.ei-tough-wall"}
twi.localised_description = {"item-description.ei-tough-wall"}
local twr = ei_lib.raw.recipe["tough-wall"]
twr.energy_required = 2
twr.localised_name = {"item-name.ei-tough-wall"}
ei_lib.set_prerequisites("tough-wall",{"stone-wall","military-2","concrete","steel-processing","electronics"})
ei_lib.set_age_packs("tough-wall","steam-age")
ei_lib.recipe_new("tough-wall",{
    {type="item", name="stone-wall", amount=1},
    {type="item", name="ei-steel-beam", amount=2},
    {type="item", name="ei-ceramic", amount=2},
    {type="item", name="concrete", amount=4},
})
local tw = ei_lib.raw.wall["tough-wall"]
tw.resistances = {
  {
    type = "physical",
    decrease = 10,
    percent = 45
  },
  {
    type = "impact",
    decrease = 70,
    percent = 70
  },
  {
    type = "explosion",
    decrease = 20,
    percent = 45
  },
  {
    type = "fire",
    percent = 100
  },
  {
    type = "acid",
    decrease = 10,
    percent = 85
  },
  {
    type = "cold",
    decrease = 10,
    percent = 75
  },
  {
    type = "laser",
    percent = 87.5,
    decrease = 2,
  }
}

--plated wall
local pwi = ei_lib.raw.item["plated-wall"]
pwi.subgroup = "defensive-structure"
pwi.order = "a[stone-wall]-a[stone-wall]3"
pwi.localised_name = {"item-name.ei-plated-wall"}
pwi.localised_description = {"item-description.ei-plated-wall"}
local pwr = ei_lib.raw.recipe["plated-wall"]
pwr.energy_required = 4
pwr.localised_name = {"item-name.ei-plated-wall"}
ei_lib.set_prerequisites("plated-wall",{"tough-wall","military-3","plastics"})
ei_lib.set_age_packs("plated-wall","electricity-age")
ei_lib.recipe_new("plated-wall",{
    {type="item", name="tough-wall", amount=1},
    {type="item", name="ei-lead-ingot", amount=3},
    {type="item", name="plastic-bar", amount=2},
    {type="item", name="refined-concrete", amount=4},
})
local pw = ei_lib.raw.wall["plated-wall"]
pw.resistances = {
  {
    type = "physical",
    decrease = 20,
    percent = 70
  },
  {
    type = "impact",
    decrease = 95,
    percent = 85
  },
  {
    type = "explosion",
    decrease = 40,
    percent = 60
  },
  {
    type = "fire",
    percent = 100
  },
  {
    type = "acid",
    decrease = 20,
    percent = 90
  },
  {
    type = "cold",
    decrease = 20,
    percent = 85
  },
  {
    type = "laser",
    percent = 95,
    decrease = 4,
  }
}
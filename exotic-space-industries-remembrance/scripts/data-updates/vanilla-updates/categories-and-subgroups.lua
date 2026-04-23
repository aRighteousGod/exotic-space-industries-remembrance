local ei_lib = require("lib/lib")

--FUEL CATEGORIES
------------------------------------------------------------------------------------------------------

ei_lib.raw.item["rocket-fuel"].fuel_category = "ei-rocket-fuel"

ei_lib.raw.item["nuclear-fuel"].fuel_category = "ei-nuclear-fuel-cell"

--ITEM SUBGROUPS
------------------------------------------------------------------------------------------------------

-- move iron and copper plates to plates subgroup
ei_lib.raw["item"]["iron-plate"] = {
    subgroup = "ei-refining-plate",
    order = "a1",
}
ei_lib.raw["item"]["copper-plate"].subgroup = "ei-refining-plate"
ei_lib.raw["item"]["copper-plate"].order = "a2"

-- set train, cargo wagon, fluid wagon and artillery wagon to new ei_trains subgroup
ei_lib.raw["item-with-entity-data"]["locomotive"].subgroup = "ei-trains"
ei_lib.raw["item-with-entity-data"]["locomotive"].order = "c1"
ei_lib.raw["item-with-entity-data"]["cargo-wagon"].subgroup = "ei-trains"
ei_lib.raw["item-with-entity-data"]["cargo-wagon"].order = "c2"
ei_lib.raw["item-with-entity-data"]["fluid-wagon"].subgroup = "ei-trains"
ei_lib.raw["item-with-entity-data"]["fluid-wagon"].order = "c3"
ei_lib.raw["item-with-entity-data"]["artillery-wagon"].subgroup = "ei-trains"
ei_lib.raw["item-with-entity-data"]["artillery-wagon"].order = "c4"

ei_lib.raw["item"]["steel-plate"].subgroup = "ei-refining-plate"
ei_lib.raw["item"]["steel-plate"].order = "a3"

ei_lib.raw["item"]["lab"].subgroup = "ei-labs"
ei_lib.raw["item"]["lab"].order = "a2"

ei_lib.raw["fluid"]["lubricant"].order = "a[fluid]-d[lubricant]"

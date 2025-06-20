ei_containers_lib = require("lib/ei_containers_lib")

--====================================================================================================
--1x1 CONTAINER
--====================================================================================================

-- add new subgroups
data:extend({
    {
        type = "item-subgroup",
        name = "ei-containers-1x1",
        group = "logistics",
        order = "z-z-a"
    },
    {
        type = "item-subgroup",
        name = "ei-containers-2x2",
        group = "logistics",
        order = "z-z-b"
    },
    {
        type = "item-subgroup",
        name = "ei-containers-6x6",
        group = "logistics",
        order = "z-z-c"
    }
})

ei_containers_lib.make_all(1, nil, 20, 2, false, {
    {type="item", name="steel-plate", amount=10},
    {type="item", name="ei-steel-beam", amount=4}
})

ei_containers_lib.make_all(1, "blue", 20, 2, false, {
    {type="item", name="ei-1x1-container", amount=1},
    {type="item", name="electronic-circuit", amount=5},
    {type="item", name="ei-steel-mechanical-parts", amount=1},
    {type="item", name="ei-simulation-data",amount=10}
})

ei_containers_lib.make_all(1, "red", 20, 2, false, {
    {type="item", name="ei-1x1-container", amount=1},
    {type="item", name="electronic-circuit", amount=5},
    {type="item", name="ei-steel-mechanical-parts", amount=1},
    {type="item", name="ei-simulation-data",amount=10}
})

ei_containers_lib.make_all(1, "pink", 20, 2, false, {
    {type="item", name="ei-1x1-container", amount=1},
    {type="item", name="electronic-circuit", amount=5},
    {type="item", name="ei-steel-mechanical-parts", amount=1},
    {type="item", name="ei-simulation-data",amount=10}
})

ei_containers_lib.make_all(1, "yellow", 20, 2, false, {
    {type="item", name="ei-1x1-container", amount=1},
    {type="item", name="electronic-circuit", amount=5},
    {type="item", name="ei-steel-mechanical-parts", amount=1},
    {type="item", name="ei-simulation-data",amount=10}
})

ei_containers_lib.make_all(1, "green", 20, 2, false, {
    {type="item", name="ei-1x1-container", amount=1},
    {type="item", name="electronic-circuit", amount=5},
    {type="item", name="ei-steel-mechanical-parts", amount=1},
    {type="item", name="ei-simulation-data",amount=10}
})

ei_containers_lib.make_all(1, "filter", 18, 2, false, {
    {type="item", name="ei-1x1-container", amount=1},
    {type="item", name="ei-steel-mechanical-parts", amount=1}
})

--====================================================================================================
--2x2 CONTAINER
--====================================================================================================

ei_containers_lib.make_all(2, nil, 32, 4, false, {
    {type="item", name="ei-1x1-container", amount=1},
    {type="item", name="steel-plate", amount=25},
    {type="item",name="ei-steel-beam",amount=10}
})

ei_containers_lib.make_all(2, "blue", 32, 4, true, {
    {type="item", name="ei-2x2-container", amount=1},
    {type="item", name="electronic-circuit", amount=10},
    {type="item", name="advanced-circuit", amount=6},
    {type="item", name="ei-steel-mechanical-parts", amount=5},
    {type="item", name="ei-simulation-data",amount=20}
})

ei_containers_lib.make_all(2, "red", 32, 4, true, {
    {type="item", name="ei-2x2-container", amount=1},
    {type="item", name="electronic-circuit", amount=10},
    {type="item", name="advanced-circuit", amount=6},
    {type="item", name="ei-steel-mechanical-parts", amount=5},
    {type="item", name="ei-simulation-data",amount=20}
})

ei_containers_lib.make_all(2, "pink", 32, 4, true, {
    {type="item", name="ei-2x2-container", amount=1},
    {type="item", name="electronic-circuit", amount=10},
    {type="item", name="advanced-circuit", amount=6},
    {type="item", name="ei-steel-mechanical-parts", amount=5},
    {type="item", name="ei-simulation-data",amount=20}
})

ei_containers_lib.make_all(2, "yellow", 32, 4, true, {
    {type="item", name="ei-2x2-container", amount=1},
    {type="item", name="electronic-circuit", amount=10},
    {type="item", name="advanced-circuit", amount=6},
    {type="item", name="ei-steel-mechanical-parts", amount=5},
    {type="item", name="ei-simulation-data",amount=20}
})

ei_containers_lib.make_all(2, "green", 32, 4, true, {
    {type="item", name="ei-2x2-container", amount=1},
    {type="item", name="electronic-circuit", amount=10},
    {type="item", name="advanced-circuit", amount=6},
    {type="item", name="ei-steel-mechanical-parts", amount=5},
    {type="item", name="ei-simulation-data",amount=20}
})

ei_containers_lib.make_all(2, "filter", 22, 4, false, {
    {type="item", name="ei-2x2-container", amount=1},
    {type="item", name="ei-steel-mechanical-parts", amount=10}
})

--====================================================================================================
--6x6 CONTAINER
--====================================================================================================

ei_containers_lib.make_all(6, nil, 64, 8, false, {
    {type="item", name="ei-2x2-container", amount=1},
    {type="item", name="steel-plate", amount=50},
    {type="item", name="ei-steel-beam", amount=20}
})

ei_containers_lib.make_all(6, "blue", 64, 8, true, {
    {type="item", name="ei-6x6-container", amount=1},
    {type="item", name="electronic-circuit", amount=20},
    {type="item", name="advanced-circuit", amount=10},
    {type="item", name="ei-steel-mechanical-parts", amount=10},
    {type="item", name="ei-simulation-data",amount=40}
})

ei_containers_lib.make_all(6, "red", 64, 8, true, {
    {type="item", name="ei-6x6-container", amount=1},
    {type="item", name="electronic-circuit", amount=20},
    {type="item", name="advanced-circuit", amount=10},
    {type="item", name="ei-steel-mechanical-parts", amount=10},
    {type="item", name="ei-simulation-data",amount=40}
})

ei_containers_lib.make_all(6, "pink", 64, 8, true, {
    {type="item", name="ei-6x6-container", amount=1},
    {type="item", name="electronic-circuit", amount=20},
    {type="item", name="advanced-circuit", amount=10},
    {type="item", name="ei-steel-mechanical-parts", amount=10},
    {type="item", name="ei-simulation-data",amount=40}
})

ei_containers_lib.make_all(6, "yellow", 64, 8, true, {
    {type="item", name="ei-6x6-container", amount=1},
    {type="item", name="electronic-circuit", amount=20},
    {type="item", name="advanced-circuit", amount=10},
    {type="item", name="ei-steel-mechanical-parts", amount=10},
    {type="item", name="ei-simulation-data",amount=40}
})

ei_containers_lib.make_all(6, "green", 64, 8, true, {
    {type="item", name="ei-6x6-container", amount=1},
    {type="item", name="electronic-circuit", amount=20},
    {type="item", name="advanced-circuit", amount=10},
    {type="item", name="ei-steel-mechanical-parts", amount=10},
    {type="item", name="ei-simulation-data",amount=40}
})

ei_containers_lib.make_all(6, "filter", 26, 8, false, {
    {type="item", name="ei-6x6-container", amount=1},
    {type="item", name="ei-steel-mechanical-parts", amount=20}
})
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

ei_containers_lib.make_all(1, nil, 50, 2, false, {
    {type="item", name="steel-plate", amount=10}
})

ei_containers_lib.make_all(1, "blue", 50, 2, false, {
    {type="item", name="ei-1x1-container", amount=1},
    {type="item", name="electronic-circuit", amount=5},
})

ei_containers_lib.make_all(1, "red", 50, 2, false, {
    {type="item", name="ei-1x1-container", amount=1},
    {type="item", name="electronic-circuit", amount=5},
})

ei_containers_lib.make_all(1, "pink", 50, 2, false, {
    {type="item", name="ei-1x1-container", amount=1},
    {type="item", name="electronic-circuit", amount=5},
})

ei_containers_lib.make_all(1, "yellow", 50, 2, false, {
    {type="item", name="ei-1x1-container", amount=1},
    {type="item", name="electronic-circuit", amount=5},
})

ei_containers_lib.make_all(1, "green", 50, 2, false, {
    {type="item", name="ei-1x1-container", amount=1},
    {type="item", name="electronic-circuit", amount=5},
})

ei_containers_lib.make_all(1, "filter", 20, 2, false, {
    {type="item", name="ei-1x1-container", amount=1},
    {type="item", name="electronic-circuit", amount=1}
})

--====================================================================================================
--2x2 CONTAINER
--====================================================================================================

ei_containers_lib.make_all(2, nil, 250, 2, false, {
    {type="item", name="ei-1x1-container", amount=4},
    {type="item", name="steel-plate", amount=25}
})

ei_containers_lib.make_all(2, "blue", 250, 2, true, {
    {type="item", name="ei-2x2-container", amount=1},
    {type="item", name="electronic-circuit", amount=10},
    {type="item", name="advanced-circuit", amount=6},
    {type="item", name="steel-plate", amount=5}
})

ei_containers_lib.make_all(2, "red", 250, 2, true, {
    {type="item", name="ei-2x2-container", amount=1},
    {type="item", name="electronic-circuit", amount=10},
    {type="item", name="advanced-circuit", amount=6},
    {type="item", name="steel-plate", amount=5}
})

ei_containers_lib.make_all(2, "pink", 250, 2, true, {
    {type="item", name="ei-2x2-container", amount=1},
    {type="item", name="electronic-circuit", amount=10},
    {type="item", name="advanced-circuit", amount=6},
    {type="item", name="steel-plate", amount=5}
})

ei_containers_lib.make_all(2, "yellow", 250, 2, true, {
    {type="item", name="ei-2x2-container", amount=1},
    {type="item", name="electronic-circuit", amount=10},
    {type="item", name="advanced-circuit", amount=6},
    {type="item", name="steel-plate", amount=5}
})

ei_containers_lib.make_all(2, "green", 250, 2, true, {
    {type="item", name="ei-2x2-container", amount=1},
    {type="item", name="electronic-circuit", amount=10},
    {type="item", name="advanced-circuit", amount=6},
    {type="item", name="steel-plate", amount=5}
})

ei_containers_lib.make_all(2, "filter", 40, 2, false, {
    {type="item", name="ei-2x2-container", amount=1},
    {type="item", name="electronic-circuit", amount=10}
})

--====================================================================================================
--6x6 CONTAINER
--====================================================================================================

ei_containers_lib.make_all(6, nil, 1000, 2, false, {
    {type="item", name="ei-2x2-container", amount=4},
    {type="item", name="steel-plate", amount=50},
    {type="item", name="stone-brick", amount=25}
})

ei_containers_lib.make_all(6, "blue", 1000, 2, true, {
    {type="item", name="ei-6x6-container", amount=1},
    {type="item", name="electronic-circuit", amount=20},
    {type="item", name="advanced-circuit", amount=10},
    {type="item", name="steel-plate", amount=10}
})

ei_containers_lib.make_all(6, "red", 1000, 2, true, {
    {type="item", name="ei-6x6-container", amount=1},
    {type="item", name="electronic-circuit", amount=20},
    {type="item", name="advanced-circuit", amount=10},
    {type="item", name="steel-plate", amount=10}
})

ei_containers_lib.make_all(6, "pink", 1000, 2, true, {
    {type="item", name="ei-6x6-container", amount=1},
    {type="item", name="electronic-circuit", amount=20},
    {type="item", name="advanced-circuit", amount=10},
    {type="item", name="steel-plate", amount=10}
})

ei_containers_lib.make_all(6, "yellow", 1000, 2, true, {
    {type="item", name="ei-6x6-container", amount=1},
    {type="item", name="electronic-circuit", amount=20},
    {type="item", name="advanced-circuit", amount=10},
    {type="item", name="steel-plate", amount=10}
})

ei_containers_lib.make_all(6, "green", 1000, 2, true, {
    {type="item", name="ei-6x6-container", amount=1},
    {type="item", name="electronic-circuit", amount=20},
    {type="item", name="advanced-circuit", amount=10},
    {type="item", name="steel-plate", amount=10}
})

ei_containers_lib.make_all(6, "filter", 120, 2, false, {
    {type="item", name="ei-6x6-container", amount=1},
    {type="item", name="electronic-circuit", amount=20}
})
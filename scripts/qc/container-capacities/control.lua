local test = require("test-config")
local function setup()
    local surface = game.surfaces["container-qc"] or game.create_surface("container-qc", {width=64,height=64})
    surface.request_to_generate_chunks({0,0}, 1)
    surface.force_generate_chunk_requests()
    local entities = {}
    for index, quality in ipairs({"normal", "legendary"}) do
        local entity = surface.create_entity{name="ei-6x6-container-filter", position={index*8,0}, force="player", quality=quality}
        local inventory = entity.get_inventory(defines.inventory.chest)
        inventory.set_filter(1, "copper-plate")
        inventory.set_filter(#inventory, "iron-plate")
        inventory[1].set_stack{name="copper-plate",count=3}
        inventory[#inventory].set_stack{name="iron-plate",count=17}
        entities[#entities+1] = entity
    end
    local first = surface.create_entity{name="container-qc-linked",position={0,10},force="player"}
    local second = surface.create_entity{name="container-qc-linked",position={4,10},force="player"}
    first.link_id = 7
    second.link_id = 7
    local inv = first.get_inventory(defines.inventory.chest)
    inv[#inv].set_stack{name="iron-plate",count=23}
    entities[#entities+1] = first
    entities[#entities+1] = second
    storage.entities = entities
    storage.original_profile = test.profile
end
script.on_init(setup)
script.on_event(defines.events.on_tick, function(event)
    if event.tick % 10 ~= 0 then return end
    local report = {profile=settings.startup["ei-container-capacity-profile"].value, original_profile=storage.original_profile, inventories={}}
    for _, entity in ipairs(storage.entities) do
        local inv = entity.get_inventory(defines.inventory.chest)
        report.inventories[#report.inventories+1] = {
            name=entity.name, quality=entity.quality.name, slots=#inv,
            copper=inv.get_item_count("copper-plate"), iron=inv.get_item_count("iron-plate"),
            first_filter=inv.supports_filters() and inv.get_filter(1) or nil,
        }
    end
    assert(report.inventories[1].copper == 3)
    assert(report.inventories[1].first_filter.name == "copper-plate")
    assert(report.inventories[2].slots > report.inventories[1].slots)
    assert(report.inventories[3].iron == report.inventories[4].iron)
    local spilled = 0
    for _, entity in pairs(game.surfaces["container-qc"].find_entities_filtered{type="item-entity"}) do
        if entity.stack.valid_for_read then spilled = spilled + entity.stack.count end
    end
    report.spilled_items = spilled
    report.all_pass = true
    helpers.write_file("container-capacity-runtime.json", helpers.table_to_json(report), false)
    log("CONTAINER_QC_RUNTIME " .. helpers.table_to_json(report))
    script.on_event(defines.events.on_tick, nil)
end)

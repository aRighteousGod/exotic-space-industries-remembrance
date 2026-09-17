-- Synthetic storage covers unknown mod names, item subtypes, and exclusions.
local function fixture(suffix, width, height, options)
    options = options or {}
    local entity = table.deepcopy(data.raw.container["steel-chest"])
    entity.name = "container-qc-" .. suffix
    entity.minable = {mining_time = 0.1, result = entity.name}
    entity.next_upgrade = nil
    entity.inventory_size = 80
    entity.selection_box = {{-width/2, -height/2}, {width/2, height/2}}
    entity.collision_box = {{-0.3, -0.3}, {0.3, 0.3}}
    entity.inventory_type = "with_filters_and_bar"
    for key, value in pairs(options) do entity[key] = value end
    local item = table.deepcopy(data.raw.item["steel-chest"])
    item.name = entity.name
    item.place_result = entity.name
    item.hidden = options.hidden
    data:extend({entity, item})
end
fixture("small", 1, 1)
fixture("medium", 2, 2)
fixture("boundary", 4, 4)
fixture("warehouse", 5, 5)
fixture("rectangle", 1, 17)
fixture("declared", 1, 1, {tile_width = 5, tile_height = 5})
fixture("hidden", 1, 1, {hidden = true})
fixture("zero", 1, 1, {inventory_size = 0})
fixture("weight", 1, 1, {inventory_type = "with_weight_limit", inventory_weight_limit = 1000000})
fixture("custom", 1, 1, {inventory_type = "with_custom_stack_size", inventory_properties = {stack_size = 10}})
fixture("unplaced", 1, 1)
data.raw.item["container-qc-unplaced"].place_result = nil
fixture("linked", 2, 2, {type = "linked-container", inventory_type = "with_filters_and_bar"})
data.raw["linked-container"]["container-qc-linked"].gui_mode = "all"

container_qc_untouched = {}
for _, kind in ipairs({"container", "logistic-container"}) do
    for name, entity in pairs(data.raw[kind] or {}) do
        if name == "ei-fueler" or name == "ei-black-hole" or name:find("ei-gate", 1, true) then
            container_qc_untouched[name] = {kind = kind, slots = entity.inventory_size}
        end
    end
end

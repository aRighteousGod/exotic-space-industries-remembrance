-- Test the actual merged recipes, plus exact product copies with productivity
-- enabled solely for stress testing. No shipping recipe is modified by this mod.
local jobs = {}
for name, recipe in pairs(data.raw.recipe) do
    local consumes, high, ordinary = false, false, false
    for _, ingredient in pairs(recipe.ingredients or {}) do
        if ingredient.name == "ei-high-energy-crystal" then consumes = true end
    end
    for _, result in pairs(recipe.results or {}) do
        if result.name == "ei-high-energy-crystal" then high = true end
        if result.name == "ei-energy-crystal" then ordinary = true end
    end
    if consumes and high and ordinary then jobs[#jobs + 1] = name end
end
table.sort(jobs)
assert(#jobs == 24, "Expected the 24 core return recipes; audit new/generated pairs before changing this fixture")
for index, name in ipairs(jobs) do
    local source = data.raw.recipe[name]
    local stress = table.deepcopy(source)
    stress.name = "esir-qc-productivity-" .. name
    stress.allow_productivity = true
    stress.hidden = true
    stress.auto_recycle = false
    data:extend({stress})
    for _, mode in ipairs({"original", "productivity"}) do
        local machine = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
        machine.name = "esir-qc-crystal-" .. mode .. "-" .. index
        machine.next_upgrade = nil
        machine.fast_replaceable_group = nil
        machine.minable = nil
        machine.hidden = true
        machine.crafting_categories = table.deepcopy(source.categories or {"crafting"})
        machine.fixed_recipe = mode == "original" and name or stress.name
        machine.crafting_speed = (source.energy_required or 0.5) * 12
        machine.energy_source = {type = "void"}
        machine.energy_usage = "1W"
        machine.module_slots = 4
        machine.allowed_effects = {"speed", "consumption", "pollution", "productivity", "quality"}
        machine.effect_receiver = {uses_beacon_effects = false}
        machine.fluid_boxes = {}
        for i = 1, 2 do
            machine.fluid_boxes[#machine.fluid_boxes + 1] = {production_type = "input", volume = 100000,
                pipe_connections = {{flow_direction = "input", direction = defines.direction.north, position = {i == 1 and -1 or 1, -1}}}}
        end
        for i = 1, 2 do
            machine.fluid_boxes[#machine.fluid_boxes + 1] = {production_type = "output", volume = 100000,
                pipe_connections = {{flow_direction = "output", direction = defines.direction.south, position = {i == 1 and -1 or 1, 1}}}}
        end
        data:extend({machine})
    end
end

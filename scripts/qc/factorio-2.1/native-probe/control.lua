-- Disposable native API evidence. No ESIR runtime handler or source is replaced.
script.on_init(function()
    local report = {version = script.active_mods.base, spoil_ticks = {}, recipes = {}, forces = {}}
    for name, item in pairs(prototypes.item) do
        if item.get_spoil_ticks("normal") > 0 then
            local ticks = {}
            for quality in pairs(prototypes.quality) do
                ticks[quality] = item.get_spoil_ticks(quality)
            end
            report.spoil_ticks[name] = ticks
        end
    end
    for _, name in ipairs({"ei-neutron-container-recycling", "cb_alien_cold_artifact-recycling", "piercing-shotgun-shell-recycling"}) do
        local recipe = prototypes.recipe[name]
        if recipe then report.recipes[name] = {energy = recipe.energy, products = recipe.products} end
    end
    helpers.write_file("native-probe.json", helpers.table_to_json(report), false)
    log("ESIR NATIVE PROBE COMPLETE " .. report.version)
end)

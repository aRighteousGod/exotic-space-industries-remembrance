return function(stage)
    local report = data.raw["mod-data"]["esir-qc-research-bootstrap"].data
    local snapshot = {}
    for name, tech in pairs(data.raw.technology) do
        snapshot[name] = {age=tech.age, unit=table.deepcopy(tech.unit),
            prerequisites=table.deepcopy(tech.prerequisites), effects=table.deepcopy(tech.effects),
            research_trigger=table.deepcopy(tech.research_trigger), enabled=tech.enabled, hidden=tech.hidden}
    end
    report[stage] = snapshot
    report[stage.."_science_templates"] = ei_data and table.deepcopy(ei_data.science) or {}
    for _, name in ipairs({"planet-discovery-vulcanus", "calcite-processing", "tungsten-carbide", "foundry", "tungsten-steel", "metallurgic-science-pack"}) do
        local tech = snapshot[name]
        log("ESIR BOOTSTRAP "..stage.." "..name.." "..serpent.line(tech))
    end
    if stage == "final" then
        local config = require("test-config")
        report.settings = {no_triggers=settings.startup["ei-no-triggers"].value,
            flatten=settings.startup["ei-tech-tree-flatten"].value}
        assert(report.settings.no_triggers == config.no_triggers, "Wrong no-triggers test selection")
        assert(report.settings.flatten == config.flatten, "Wrong flatten test selection")
        report.mods = table.deepcopy(mods)
        report.recipes = {}
        for name, recipe in pairs(data.raw.recipe) do
            report.recipes[name] = {enabled=recipe.enabled, hidden=recipe.hidden,
                ingredients=table.deepcopy(recipe.ingredients), results=table.deepcopy(recipe.results)}
        end
        report.science = {}
        for name in pairs(ei_lib.get_science_prototypes()) do report.science[name] = true end
    end
end

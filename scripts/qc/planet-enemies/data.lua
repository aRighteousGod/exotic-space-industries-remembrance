-- Staging-only snapshot, appended after the production data-final-fixes file.
do
    local config=require("lib/planet-enemies-config")
    local fields={"dying_explosion","dying_trigger_effect","corpse","damaged_trigger_effect",
        "open_sound","close_sound","working_sound","dying_sound","walking_sound",
        "factoriopedia_simulation","factoriopedia_alternative","hidden_in_factoriopedia",
        "attack_parameters","max_health","resistances","minable","created_effect"}
    local snapshot={entities={},controls={},planets={},autoplace={},noise={},spawn_results={}}
    for kind,entries in pairs(data.raw) do
        for name,prototype in pairs(entries) do
            if config.family(name,kind) or (kind=="segmented-unit" and config.is_demolisher(name)) then
                local row={type=kind}
                for _,field in ipairs(fields) do row[field]=table.deepcopy(prototype[field]) end
                snapshot.entities[name]=row
                snapshot.autoplace[name]=table.deepcopy(prototype.autoplace)
                snapshot.spawn_results[name]=table.deepcopy(prototype.result_units)
            end
        end
    end
    for _,kind in ipairs({"noise-expression","noise-function"}) do
        for name,prototype in pairs(data.raw[kind]) do
            if name:find("enemy_base",1,true) or name:find("enemy_autoplace",1,true) then
                snapshot.noise[name]=table.deepcopy(prototype)
            end
        end
    end
    for planet,controls in pairs(config.controls) do
        snapshot.planets[planet]=table.deepcopy(data.raw.planet[planet].map_gen_settings)
        for _,name in pairs(controls) do snapshot.controls[name]=table.deepcopy(data.raw["autoplace-control"][name]) end
    end
    data:extend{{type="mod-data",name="ei-planet-enemies-qc",data=snapshot}}
end

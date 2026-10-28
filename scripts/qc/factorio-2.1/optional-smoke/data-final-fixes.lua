local rows={}
for name,recipe in pairs(data.raw.recipe) do
    local consumed=0
    for _,ingredient in ipairs(recipe.ingredients or {}) do
        if ingredient.name=="ei-high-energy-crystal" then consumed=consumed+ingredient.amount end
    end
    if consumed>0 then
        local high,low
        for _,result in ipairs(recipe.results or {}) do
            if result.name=="ei-high-energy-crystal" then high=result end
            if result.name=="ei-energy-crystal" then low=result end
        end
        if high and low then
            local a,b=high.shared_probability,low.shared_probability
            assert(a and b and a.min==0 and a.max==b.min and b.max==1 and a.max>0 and a.max<1,"Crystal shared partition " .. name)
            assert(high.amount==1 and low.amount==1,"Crystal return amount " .. name)
            assert(not high.probability and not low.probability and not high.independent_probability and not low.independent_probability,"Extra crystal probability gate " .. name)
            assert(high.ignored_by_productivity==1 and low.ignored_by_productivity==1,"Crystal productivity " .. name)
            -- Muluna's required Rigor Module copies recipes under this exact
            -- generator-owned suffix. The science exception follows its source.
            local base=name:match("^(.-)__rigor_module_mod__%d+$") or name
            assert(base==name or (mods["rigor-module"] and data.raw.recipe[base]),"Unknown crystal variant owner " .. name)
            assert(consumed==(base=="ei-alien-computer-age-tech" and 2 or 1),"Review generated crystal input exception " .. name)
            local expected=base=="ei-uranium-extraction" and 0.9 or base=="ei-neodym-extraction-morphium" and 0.92 or 0.98
            assert(math.abs(a.max-expected)<1e-10,"Changed crystal split " .. name)
            rows[#rows+1]={name=name,base=base,input=consumed,high=a.max,ordinary=1-a.max}
        end
    end
end
assert(#rows>=24,"Missing core crystal return recipes")
table.sort(rows,function(a,b) return a.name<b.name end)
log("ESIR OPTIONAL FINAL CRYSTAL CONTRACT " .. serpent.line(rows))
data:extend{{type="mod-data",name="esir-qc-optional-crystals",data={recipes=rows}}}

if mods["planet-muluna"] then
    local technologies={}
    for name,technology in pairs(data.raw.technology) do
        if name:match("^rocket%-part%-productivity") then
            local values={}
            for _,effect in ipairs(technology.effects or {}) do
                if effect.type=="change-recipe-productivity" then
                    assert(effect.recipe~="rocket-part","Duplicate silo productivity: "..name)
                    values[effect.recipe]=effect.change
                end
            end
            local expected=settings.startup["muluna-easy-vanilla-rocket-part-costs"].value and 0.1
                or name:match("^rocket%-part%-productivity%-aquilo") and 0.2 or 0.1
            for _,recipe in ipairs{"ei-rocket-parts","ei-rocket-parts-advanced",
                "ei-rocket-parts-odd-plating","ei-rocket-parts-odd-plating-advanced"} do
                assert(values[recipe]==expected,"Muluna rocket manufacturing productivity: "..name.."/"..recipe)
            end
            technologies[name]=values
        end
    end
    assert(next(technologies),"Missing Muluna rocket productivity technologies")
    data:extend{{type="mod-data",name="esir-qc-optional-productivity",data=technologies}}
end

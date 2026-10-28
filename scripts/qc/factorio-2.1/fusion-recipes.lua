-- Exercise every final-data fusion selection with native craft/output blocking.
local modern=script.active_mods.base:match("^2%.1%.")~=nil

---@param entity LuaEntity
---@param index integer
local function filter_name(entity,index)
    local filter=modern and entity.get_fluid_filter(index) or entity.fluidbox.get_filter(index)
    return filter and filter.name
end

local function put(entity,index,fluid)
    if modern then
        if fluid then entity.set_fluid(index,fluid) else entity.clear_fluid(index) end
    else entity.fluidbox[index]=fluid end
end

local function contents(entity)
    local result={}
    for index=1,entity.fluids_count do
        local fluid=entity.get_fluid(index)
        if fluid then result[fluid.name]=(result[fluid.name] or 0)+fluid.amount end
    end
    return result
end

local function check(condition,label)
    storage.report.assertions=storage.report.assertions+1
    assert(condition,label)
end

script.on_event(defines.events.on_tick,function(event)
    if event.tick==1 then
        local surface=game.create_surface("fusion-recipes-qc",{width=640,height=448,peaceful_mode=true})
        surface.request_to_generate_chunks({0,0},10);surface.force_generate_chunk_requests()
        for _,entity in pairs(surface.find_entities()) do entity.destroy() end
        local names={}
        for name in pairs(prototypes.recipe) do
            if name:find("^ei%-fusion%-F1__") then table.insert(names,name) end
        end
        table.sort(names)
        assert(#names==135,"Unexpected final fusion recipe count: "..#names)
        storage.cases={};storage.report={engine=script.active_mods.base,assertions=0,cases={},completed=0}
        for index,name in ipairs(names) do
            local entity=assert(surface.create_entity{name="ei-fusion-reactor",position={
                (index-1)%15*36-250,math.floor((index-1)/15)*36-140},force="player"})
            entity.set_recipe(name)
            remote.call("esir-fusion-qc","register",entity,event.tick)
            check(entity.get_recipe().name==name,name.." registration changed selection")
            check(entity.recipe_locked,name.." recipe not locked")
            local recipe=entity.get_recipe()
            local amounts,boxes,output_index={},{},nil
            for _,ingredient in pairs(recipe.ingredients) do amounts[ingredient.name]=(amounts[ingredient.name] or 0)+ingredient.amount end
            for box=1,entity.fluids_count do
                local fluid=filter_name(entity,box)
                if fluid=="ei-hot-coolant" then output_index=box
                elseif fluid then boxes[fluid]=(boxes[fluid] or 0)+1 end
            end
            assert(output_index,"Missing fusion output storage")
            for box=1,entity.fluids_count do
                local fluid=filter_name(entity,box)
                if fluid and amounts[fluid] then put(entity,box,{name=fluid,amount=amounts[fluid]/boxes[fluid]*1.001,
                    temperature=prototypes.fluid[fluid].default_temperature}) end
            end
            local before=contents(entity)
            local capacity=modern and entity.get_fluid_capacity(output_index) or entity.fluidbox.get_capacity(output_index)
            put(entity,output_index,{name="ei-hot-coolant",amount=capacity,temperature=prototypes.fluid["ei-hot-coolant"].default_temperature})
            local row={recipe=name,ingredients=amounts,products=recipe.products,input_before=before,
                output_capacity=capacity,completed=false}
            storage.cases[index]={entity=entity,row=row,output_index=output_index}
            storage.report.cases[index]=row
            entity.energy=1e12
        end
    elseif storage.cases then
        for _,case in ipairs(storage.cases) do
            local entity,row=case.entity,case.row
            if not row.completed then
                entity.energy=1e12
                if event.tick==121 then
                    check(entity.products_finished==0,row.recipe.." completed into blocked output")
                    row.blocked_progress=entity.crafting_progress
                    put(entity,case.output_index,nil)
                elseif event.tick>121 and entity.products_finished>0 then
                    local after=contents(entity)
                    row.input_after=after;row.products_finished=entity.products_finished
                    row.completion_tick=event.tick;row.consumed={}
                    for name,amount in pairs(row.ingredients) do
                        local consumed=row.input_before[name]-(after[name] or 0)
                        row.consumed[name]=consumed
                        check(math.abs(consumed-amount)<=math.max(1e-5,amount*1e-6),row.recipe.." consumption "..name)
                    end
                    local expected=0
                    for _,product in pairs(row.products) do
                        assert(product.name=="ei-hot-coolant","Unexpected fusion output")
                        expected=expected+product.amount
                    end
                    check(math.abs((after["ei-hot-coolant"] or 0)-expected)<=math.max(1e-5,expected*1e-6),row.recipe.." output")
                    check(entity.get_recipe().name==row.recipe and entity.recipe_locked,row.recipe.." owner selection changed")
                    row.completed=true;storage.report.completed=storage.report.completed+1
                    if modern then entity.disabled_by_script=true else entity.active=false end
                end
            end
        end
        if storage.report.completed==#storage.cases and not storage.done then
            storage.done=true;storage.report.passed=true
            helpers.write_file("fusion-recipes.json",helpers.table_to_json(storage.report),false)
            log("FUSION RECIPES COMPLETE")
        end
        assert(event.tick<400 or storage.done,"Fusion native crafts timed out")
    end
end)

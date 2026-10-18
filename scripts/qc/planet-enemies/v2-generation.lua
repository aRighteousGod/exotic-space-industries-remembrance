-- Staging-only native generation comparison. The same fixture runs on frozen v1.
do
    local previous=script.get_event_handler(defines.events.on_tick)
    local config=require("lib/planet-enemies-config")
    local split=prototypes.autoplace_control["ei-nauvis-arachnid-enemies"]~=nil
    local jobs,results={}, {v2=split,cases={}}
    local family_controls={ordinary="enemy-base",explosive="hot_enemy_base",cold="frost_enemy_base",
        arachnid="ei-nauvis-arachnid-enemies",toxic="ei-nauvis-toxic-enemies",armoured="ei-nauvis-armoured-enemies"}
    for _,seed in ipairs({1000,421337}) do
        for _,planet in ipairs({"nauvis","vulcanus","aquilo","fulgora","gaia","gleba"}) do
            jobs[#jobs+1]={planet=planet,seed=seed,case="default"}
        end
        if split then
            for family,control in pairs(family_controls) do
                for _,case in ipairs({{"off",0,0},{"frequency-zero",0,1},{"size-zero",1,0},
                    {"frequency-low",1/6,1},{"frequency-high",6,1},{"size-low",1,1/6},{"size-high",1,6},
                    {"extreme-small",6,1/6},{"extreme-large",1/6,6}}) do
                    jobs[#jobs+1]={planet="nauvis",seed=seed,family=family,control=control,case=case[1],frequency=case[2],size=case[3]}
                end
            end
            local ordered={"ordinary","explosive","cold","arachnid","toxic","armoured"}
            for a=1,#ordered do for b=a+1,#ordered do
                jobs[#jobs+1]={planet="nauvis",seed=seed,case="mixed-"..ordered[a].."-"..ordered[b],
                    mixed={[ordered[a]]="frequency-high",[ordered[b]]="frequency-high"},frequency=6,size=1}
            end end
            for _,variant in ipairs({{"frequency-high",6,1},{"size-low",1,1/6},{"extreme-small",6,1/6}}) do
                local mixed={};for _,family in ipairs(ordered) do mixed[family]=variant[1] end
                jobs[#jobs+1]={planet="nauvis",seed=seed,case="mixed-all-"..variant[1],mixed=mixed,frequency=variant[2],size=variant[3]}
            end
        end
    end
    local positions={}
    for x=-2048,4096,64 do for y=-2048,4096,64 do positions[#positions+1]={x,y} end end
    local function digest(values)
        local h1,h2,positive=0,0,0
        for _,value in ipairs(values) do
            assert(value==value and math.abs(value)<math.huge,"nonfinite noise")
            if value>0 then positive=positive+1 end
            local text=string.format("%.17g;",value)
            for i=1,#text do
                h1=(h1*131+text:byte(i))%2147483647
                h2=(h2*137+text:byte(i))%2147483629
            end
        end
        return {hash=h1..":"..h2,positive=positive,count=#values}
    end
    local index=0
    script.on_event(defines.events.on_tick,function(event)
        previous(event);index=index+1
        local job=jobs[index];if not job then return end
        local mgs=table.deepcopy(prototypes.space_location[job.planet].map_gen_settings);mgs.seed=job.seed
        if job.control then mgs.autoplace_controls[job.control]={frequency=job.frequency,size=job.size,richness=1} end
        for family in pairs(job.mixed or {}) do mgs.autoplace_controls[family_controls[family]]={frequency=job.frequency,size=job.size,richness=1} end
        local surface=game.create_surface("enemy-v2-generation",mgs)
        local properties={"elevation","temperature","moisture"}
        local families={}
        for name,prototype in pairs(prototypes.entity) do
            if prototype.autoplace_specification and (prototype.type=="unit-spawner" or prototype.type=="turret")
                and (mgs.autoplace_settings.entity.settings[name] or
                    (prototype.autoplace_specification.control and mgs.autoplace_controls[prototype.autoplace_specification.control])) then
                local property="entity:"..name..":probability"
                properties[#properties+1]=property
                families[property]=config.family(name,prototype.type)
                if not split and job.planet=="nauvis" then
                    if name:find("arachnid",1,true) then families[property]="arachnid"
                    elseif name:find("toxic",1,true) then families[property]="toxic"
                    elseif name:find("armoured",1,true) then families[property]="armoured"
                    elseif not families[property] then families[property]="ordinary" end
                end
            end
        end
        if job.planet=="vulcanus" then
            for _,name in ipairs({"demolisher_territory_radius","demolisher_territory_expression","demolisher_variation_expression"}) do properties[#properties+1]=name end
        end
        table.sort(properties)
        local noise=surface.calculate_tile_properties(properties,positions)
        local record={planet=job.planet,seed=job.seed,case=job.case,family=job.family,mixed=job.mixed,noise={},families=families,entities={},territories={}}
        for _,name in ipairs(properties) do
            if noise[name] then record.noise[name]=digest(noise[name])
            else assert(job.control and (job.frequency==0 or job.size==0),name);record.noise[name]={omitted=true,positive=0} end
        end
        if job.case=="default" or job.case=="off" then
            for _,position in ipairs({{0,0},{1024,1024},{2048,0},{0,2048}}) do surface.request_to_generate_chunks(position,3) end
            surface.force_generate_chunk_requests()
            for _,entity in pairs(surface.find_entities_filtered{type={"unit-spawner","turret"}}) do
                record.entities[#record.entities+1]=entity.name..":"..entity.position.x..":"..entity.position.y
            end
            table.sort(record.entities)
            for _,territory in pairs(surface.get_territories()) do
                local chunks,units={},{}
                for _,chunk in pairs(territory.get_chunks()) do chunks[#chunks+1]=chunk.x..":"..chunk.y end
                for _,unit in pairs(territory.get_segmented_units()) do units[#units+1]=unit.prototype.name end
                table.sort(chunks);table.sort(units);record.territories[#record.territories+1]={chunks=chunks,units=units}
            end
            table.sort(record.territories,function(a,b)return table.concat(a.chunks,",")<table.concat(b.chunks,",") end)
        end
        local restored=helpers.parse_map_exchange_string(surface.get_map_exchange_string()).map_gen_settings
        record.roundtrip=true
        for name,values in pairs(surface.map_gen_settings.autoplace_controls) do
            for _,field in ipairs({"frequency","size","richness"}) do
                if (values[field] or 1)~=((restored.autoplace_controls[name] or {})[field] or 1) then record.roundtrip=false end
            end
        end
        results.cases[#results.cases+1]=record;game.delete_surface(surface)
        if index==#jobs then helpers.write_file("enemy-v2-generation.json",helpers.table_to_json(results),false);log("V2 GENERATION COMPLETE "..index) end
    end)
end

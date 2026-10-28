-- Native power/fuel comparison. Private on_tick sampling is not shipping cadence.
local modern = script.active_mods.base:match("^2%.1%.") ~= nil
local config = require("power-config")
local bodies = config.bodies or {
    {name="ei-combustion-turbine", fuel="coal"},
    {name="ei-combustion-turbine-fluid", fluid="ei-diesel", temperature=60},
    {name="steam-engine", fluid="steam", temperature=165},
    {name="steam-turbine", fluid="steam", temperature=500},
    {name="ei-big-turbine", fluid="ei-critical-steam", temperature=1500},
}
local regimes = {{name="idle", ratio=0}, {name="quarter", ratio=0.25},
    {name="full", ratio=1}, {name="overload", ratio=2}, {name="disabled", ratio=1, disabled=true}}

---@param case table Private rig with one generator and isolated electrical network.
---@return number
local function fluid_total(case)
    if modern then
        local fluid = case.entity.get_fluid_segment_fluid(1)
        return fluid and fluid.amount or 0
    end
    -- In 2.0 a generator has a private consumer store in addition to its segment.
    local segment = case.entity.fluidbox.get_fluid_segment_contents(1)
    return case.entity.get_fluid_count(case.fluid) + (segment and segment[case.fluid] or 0)
end

local function top_up(case)
    if not case.fluid then return end
    local before = fluid_total(case)
    local fluid = {name=case.fluid, amount=100, temperature=case.temperature}
    if modern then case.entity.set_fluid(1,fluid) else case.entity.fluidbox[1]=fluid end
    case.inserted = case.inserted + fluid_total(case)-before
end

local function snapshot(case, tick)
    local stats = case.pole.electric_network_statistics
    -- Electric statistics describe entity output/input, unlike item production.
    local result = {tick=tick, generated=stats.get_output_count{name=case.entity.name,quality=case.entity.quality.name},
        delivered_electricity=stats.get_input_count("esir-qc-power-load"),
        generator_buffer=case.entity.energy, load_buffer=case.load.energy,
        status=case.entity.status, inserted=case.inserted,
        generator_connected=case.entity.is_connected_to_electric_network(),
        load_connected=case.load.is_connected_to_electric_network(),
        input_counts=stats.input_counts,output_counts=stats.output_counts}
    if case.fluid then
        result.fluid = fluid_total(case)
    else
        result.fuel_count = case.entity.get_fuel_inventory().get_item_count("coal")
        result.remaining_burning_fuel = case.entity.burner.remaining_burning_fuel
    end
    return result
end

local function record_sample(case, tick, report)
    local after = snapshot(case,tick)
    if case.baseline then
        local before = case.baseline
        local duration = after.tick-before.tick
        local produced = after.generated-before.generated
        local expected = case.disabled and 0 or case.maximum*math.min(case.ratio,1)*duration
        local check = {from=before.tick,to=tick,generated_joules=produced,
            expected_joules=expected,average_watts=produced/duration*60,
            delivered_joules=after.delivered_electricity-before.delivered_electricity,
            generator_buffer_change=after.generator_buffer-before.generator_buffer,
            load_buffer_change=after.load_buffer-before.load_buffer}
        if case.fluid then
            check.fluid_consumed=before.fluid+after.inserted-before.inserted-after.fluid
        else
            check.items_consumed=before.fuel_count-after.fuel_count
            check.burning_reserve_change=after.remaining_burning_fuel-before.remaining_burning_fuel
            check.fuel_joules_consumed=check.items_consumed*prototypes.item.coal.fuel_value-check.burning_reserve_change
        end
        table.insert(case.report.samples,check)
        if math.abs(produced-expected)>math.max(1,expected*0.0001) then
            table.insert(report.failures,case.report.key.." power "..produced.." expected "..expected)
        end
        report.assertions=report.assertions+1
        if not after.generator_connected or not after.load_connected
            or math.abs(produced-check.delivered_joules)>1 then
            table.insert(report.failures,case.report.key.." electrical delivery")
        end
        report.assertions=report.assertions+1
        local consumed_correctly
        if case.fluid then
            consumed_correctly=expected==0 and math.abs(check.fluid_consumed)<1e-6
                or expected>0 and check.fluid_consumed>0
        else
            consumed_correctly=expected==0 and check.items_consumed==0 and math.abs(check.burning_reserve_change)<1e-6
                or expected>0 and (check.items_consumed>0 or check.burning_reserve_change<0)
        end
        if not consumed_correctly then table.insert(report.failures,case.report.key.." fuel consumption") end
        report.assertions=report.assertions+1
    end
    case.baseline=after
    case.report.last_state=after
end

script.on_event(defines.events.on_tick,function(event)
    if event.tick==1 then
        local surface=game.create_surface("power-output-qc",{width=704,height=448,peaceful_mode=true})
        surface.request_to_generate_chunks({0,0},11)
        surface.force_generate_chunk_requests()
        for _,entity in pairs(surface.find_entities()) do entity.destroy() end
        storage.cases={}
        storage.report={engine=script.active_mods.base,assertions=0,cases={},failures={}}
        for _,body in ipairs(bodies) do
            for _,quality in ipairs{"normal","rare"} do
                for _,regime in ipairs(regimes) do
                    local index=#storage.cases+1
                    local x=(index-1)%10*60-270
                    local y=math.floor((index-1)/10)*60-120
                    local entity=assert(surface.create_entity{name=body.name,position={x,y},force="player",quality=quality})
                    local pole=assert(surface.create_entity{name="substation",position={x+9,y},force="player"})
                    local load=assert(surface.create_entity{name="esir-qc-power-load",position={x+8,y+4},force="player"})
                    local maximum=entity.prototype.get_max_energy_production(quality)
                    assert(maximum>0,"No production limit for "..body.name)
                    local demand=maximum*regime.ratio
                    load.electric_buffer_size=math.max(1,demand*10)
                    load.power_usage=demand
                    if modern then entity.disabled_by_script=regime.disabled or false
                    else entity.active=not regime.disabled end
                    if body.fuel then assert(entity.get_fuel_inventory().insert{name=body.fuel,count=300}>0) end
                    local key=body.name.."/"..quality.."/"..regime.name
                    local row={key=key,name=body.name,quality=quality,regime=regime.name,
                        maximum_watts=maximum*60,demand_watts=demand*60,samples={}}
                    local case={entity=entity,pole=pole,load=load,fluid=body.fluid,temperature=body.temperature,
                        ratio=regime.ratio,disabled=regime.disabled,maximum=maximum,inserted=0,report=row}
                    table.insert(storage.cases,case)
                    table.insert(storage.report.cases,row)
                    top_up(case)
                end
            end
        end
    elseif storage.cases then
        if event.tick==601 or event.tick==1201 or event.tick==1801 then
            for _,case in ipairs(storage.cases) do record_sample(case,event.tick,storage.report) end
            helpers.write_file("power-output.json",helpers.table_to_json(storage.report),false)
            if event.tick==1801 then
                assert(#storage.report.failures==0,"Power fixture failures: "..#storage.report.failures)
                log("POWER OUTPUT COMPLETE")
            end
        end
        for _,case in ipairs(storage.cases) do top_up(case) end
    end
end)

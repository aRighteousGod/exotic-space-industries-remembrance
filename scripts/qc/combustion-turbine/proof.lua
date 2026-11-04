local support = require("support")
local p = "esir-turbine-proof-"
local records, started = {}, nil
local function amount(entity, index)
    local fluid = entity.get_fluid(index)
    return fluid and fluid.amount or 0
end
local function snapshot(r)
    local fuel=r.fuel_index and (r.body.has_fluid_segment(r.fuel_index)
        and r.body.get_fluid_segment_fluid(r.fuel_index) or r.body.get_fluid(r.fuel_index))
    return {oxygen=amount(r.body,r.oxygen_index),working=amount(r.body,r.working_index or 2)+amount(r.generator,1),
        co2=amount(r.generator,2),fuel=r.body.burner and
            (r.body.get_fuel_inventory().get_item_count("coal")*prototypes.item.coal.fuel_value+r.body.burner.remaining_burning_fuel)
            or (fuel and fuel.amount or 0)*200000,energy=r.body.energy,body_status=r.body.status,
        generator_status=r.generator.status,load_energy=r.load.energy,fluid_storages=r.body.fluids_count}
end
local function check(name, value, detail) support.record(name,value,detail) end
local function near(a,b,tolerance) return math.abs(a-b)<(tolerance or 0.001) end
local function poll(tick)
    if not started then
        started=tick
        local surface=game.create_surface("turbine-native-proof",{width=128,height=128})
        surface.request_to_generate_chunks({0,0},2);surface.force_generate_chunk_requests()
        local tiles={}
        for x=-10,60 do for y=-10,15 do tiles[#tiles+1]={name="lab-dark-1",position={x,y}} end end
        surface.set_tiles(tiles)
        for i,mode in ipairs({"solid","fluid"}) do
            local x=(i-1)*32
            local body=assert(surface.create_entity{name=p..mode,position={x,0},force="player"})
            local generator=assert(surface.create_entity{name=p.."generator",position={x,6},force="player"})
            local load=assert(surface.create_entity{name=p.."load",position={x+5,4},force="player"})
            surface.create_entity{name="substation",position={x+5,0},force="player"}
            body.add_fluid_box_linked_connection(1,generator,1)
            local oxygen_index=mode=="fluid" and 2 or 1
            body.set_fluid(oxygen_index,{name=p.."oxygen",amount=200})
            local fuel_index,working_index
            if mode=="solid" then body.insert{name="coal",count=50}
            else
                local boxes={}
                for index=1,body.fluids_count do
                    boxes[#boxes+1]={index=index,capacity=body.get_fluid_capacity(index),segment=body.has_fluid_segment(index)}
                    if body.get_fluid_capacity(index)==400 then fuel_index=index end
                end
                check("fluid-fuel-storage-found",fuel_index~=nil,helpers.table_to_json(boxes))
                assert(fuel_index,"Native fluid-energy storage absent")
                working_index=fuel_index==3 and 2 or 3
                local fuel={name=p.."diesel",amount=400,temperature=15}
                if body.has_fluid_segment(fuel_index) then body.set_fluid_segment_fluid(fuel_index,fuel)
                else body.set_fluid(fuel_index,fuel) end
                local stored=body.has_fluid_segment(fuel_index) and body.get_fluid_segment_fluid(fuel_index) or body.get_fluid(fuel_index)
                check("fluid-fuel-inserted",stored and near(stored.amount,400),helpers.table_to_json(boxes))
            end
            records[#records+1]={mode=mode,body=body,generator=generator,load=load,fuel_index=fuel_index,working_index=working_index,oxygen_index=oxygen_index}
            check(mode.."-linked",body.get_fluid_box_linked_connection(1)==generator)
            check(mode.."-oxygen-capacity",near(amount(body,oxygen_index),200),amount(body,oxygen_index))
        end
        return
    end
    local elapsed=tick-started
    for _,r in ipairs(records) do
        local mode=r.mode
        if elapsed==120 then r.start=snapshot(r) end
        if elapsed==300 then
            local before,after=r.start,snapshot(r)
            check(mode.."-oxygen-20-per-second",near(before.oxygen-after.oxygen,60,1.01),helpers.table_to_json{before=before,after=after})
            check(mode.."-co2-20-per-second",near(after.co2-before.co2,60,0.7),after.co2-before.co2)
            local expected=36000000/(mode=="solid" and 3 or 2.25)
            check(mode.."-fuel-efficiency",near(before.fuel-after.fuel,expected,300000),before.fuel-after.fuel)
            check(mode.."-working-buffer-bound",after.working<=6.001,after.working)
            local exhaust=r.generator.get_fluid(2)
            check(mode.."-co2-temperature",exhaust and near(exhaust.temperature,15),helpers.table_to_json(after))
            r.generator.set_fluid(2,{name=p.."co2",amount=200})
            r.body.set_fluid(r.oxygen_index,{name=p.."oxygen",amount=200})
        end
        if elapsed==360 then r.blocked=snapshot(r) end
        if elapsed==480 then
            local after=snapshot(r)
            check(mode.."-blocked-exhaust-stops-oxygen",near(after.oxygen,r.blocked.oxygen),helpers.table_to_json{before=r.blocked,after=after})
            check(mode.."-blocked-exhaust-stops-fuel",near(after.fuel,r.blocked.fuel,1))
            check(mode.."-blocked-exhaust-preserved",near(after.co2,200))
            r.generator.clear_fluid(2)
            r.body.clear_fluid(r.oxygen_index)
        end
        if elapsed==540 then r.starved=snapshot(r) end
        if elapsed==660 then
            local after=snapshot(r)
            check(mode.."-oxygen-starvation-stops-fuel",near(after.fuel,r.starved.fuel,1))
            check(mode.."-oxygen-starvation-stops-exhaust",near(after.co2,r.starved.co2))
            r.body.set_fluid(r.oxygen_index,{name=p.."oxygen",amount=200})
            r.load.power_usage=0
        end
        if elapsed==780 then r.idle=snapshot(r) end
        if elapsed==900 then
            local after=snapshot(r)
            check(mode.."-idle-stops-oxygen",near(after.oxygen,r.idle.oxygen))
            check(mode.."-idle-stops-fuel",near(after.fuel,r.idle.fuel,1))
        end
    end
    if elapsed==900 then support.complete();return support.poll() end
end
return {poll=function(tick)
    local ok, result=pcall(poll,tick)
    if not ok then
        support.record("fixture-exception",false,result)
        support.complete()
        return support.poll()
    end
    return result
end}

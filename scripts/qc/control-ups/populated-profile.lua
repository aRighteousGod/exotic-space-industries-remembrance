-- Staging-only attribution lane. Never use this lane for whole-engine timing.
do
    local names={"neutron-collector","teslas-legacy","emerald-apocalypse-hover-tank",
        "emerald-apocalypse-orbital-shards","orbital-combinator","gaia","alien-spawner",
        "vulcanus-fumaroles","water-turret","firefighting","singularity-lance",
        "fluid-safety","matter-stabilizer","fueler/fueler","gate","em-trains/charger",
        "orbital-logistics","fusion-reactor","spider-vehicles","beacon-overload",
        "flammable-rupture-scheduler","crystal-accumulator","induction-matrix","black-hole",
        "auric-inoculation-vat","steam-train","gaian-saucer-wake","rocket-launch-pollution",
        "fulgora-day-length-variation","hemocrystal-wall","flamethrower-fuels","combustion-turbine"}
    local methods={"check_global","get_pending_work_count","has_tick_work","update","updater",
        "has_hot_tick_work","hot_update","on_entity_damaged","on_script_trigger_effect",
        "has_damage_tick_work","has_reforge_tick_work","reforge_on_tick",
        "get_fluid_work_count","service_fluid_runtime","get_train_pending_work_count",
        "get_charger_pending_work_count","train_updater","charger_updater",
        "has_surface_tick_work","has_ui_tick_work","update_ui"}
    local profiles={}
    local enabled=false
    local function wrap(module,method,label)
        local original=module[method]
        if type(original)~="function" then return end
        local row={label=label,calls=0,depth=0}
        profiles[#profiles+1]=row
        local function capture(...)
            row.depth=row.depth-1
            if row.depth==0 then row.profiler.stop() end
            return ...
        end
        local function wrapped(...)
            if not enabled then return original(...) end
            row.calls=row.calls+1
            if row.depth==0 then row.profiler.restart() end
            row.depth=row.depth+1
            return capture(original(...))
        end
        module[method]=wrapped
        for id,handler in pairs(SINGLE_OWNER_SCRIPT_EFFECT_HANDLERS) do
            if handler==original then SINGLE_OWNER_SCRIPT_EFFECT_HANDLERS[id]=wrapped end
        end
    end
    for _,name in ipairs(names) do
        local module=require("scripts/control/"..name)
        for _,method in ipairs(methods) do wrap(module,method,name.."."..method) end
    end
    local function count(value)
        local n=0
        for _ in pairs(value) do n=n+1 end
        return n
    end
    local function summarize(value,depth)
        if type(value)~="table" then
            if type(value)=="number" or type(value)=="boolean" or type(value)=="string" then return value end
            return nil
        end
        local result={keys=count(value)}
        if depth>0 then
            for key,item in pairs(value) do
                if type(key)=="string" then result[key]=summarize(item,depth-1) end
            end
        end
        if type(value.head)=="number" and type(value.tail)=="number" then result.span=math.max(0,value.tail-value.head+1) end
        return result
    end
    local function settings_values(values)
        local result={}
        for name,setting in pairs(values) do result[name]=setting.value end
        return result
    end
    local function census(label)
        local result={label=label,tick=game.tick,connected=#game.connected_players,
            ei=summarize(storage.ei,3),emt=summarize(storage.ei_emt,2),surfaces={},players={},
            startup=settings_values(settings.startup),runtime_global=settings_values(settings.global)}
        for _,surface in pairs(game.surfaces) do
            result.surfaces[#result.surfaces+1]={name=surface.name,index=surface.index,
                player_entities=surface.count_entities_filtered{force="player"}}
        end
        for _,player in pairs(game.players) do
            result.players[#result.players+1]={index=player.index,connected=player.connected,settings=settings_values(settings.get_player_settings(player))}
        end
        helpers.write_file("control-ups-population-"..label..".json",helpers.table_to_json(result),false)
        log("CONTROL_UPS_POPULATION "..label.." tick="..game.tick)
    end
    local original=script.get_event_handler(defines.events.on_tick)
    local ticks=0
    script.on_event(defines.events.on_tick,function(event)
        ticks=ticks+1
        if ticks==1 then census("start") end
        if ticks==121 then
            for _,row in ipairs(profiles) do row.profiler=game.create_profiler(true) end
            enabled=true
        end
        original(event)
        if ticks==3600 then
            enabled=false
            for _,row in ipairs(profiles) do
                log({"","CONTROL_UPS_MODULE ",row.label," calls=",row.calls," ",row.profiler})
            end
            census("end")
            log("CONTROL_UPS_POPULATION ALL_COMPLETE")
        end
    end)
end

-- Private bridge: exercise the shipping owner without a production remote API.
remote.add_interface("esir-turbine-qc", {
    swap=function(entity, mode, tick, failures)
        storage.ei.qc_turbine_failures=failures or 0
        return ei_combustion_turbine.swap_to_mode(entity, mode, tick)
    end,
    register=function(entity, tick, tags)
        ei_combustion_turbine.on_built_entity{entity=entity,tick=tick,tags=tags}
    end,
    record=function(entity)
        return storage.ei.combustion_turbine.turbines_by_unit[entity.unit_number]
    end,
    rebuild=function(tick) ei_combustion_turbine.rebuild_runtime_state("qc",tick) end,
    status=function() return ei_combustion_turbine.get_runtime_status() end,
    open=function(index,entity,tick)
        local player=game.get_player(index)
        local record=storage.ei.combustion_turbine.turbines_by_unit[entity.unit_number]
        local anchor=record and record.proxy and record.proxy.valid and record.proxy or entity
        player.opened=anchor
        ei_combustion_turbine.open_gui(player,anchor,tick)
    end,
    gui=function(index,mode,tick,failures)
        local player=game.get_player(index)
        local name=ei_combustion_turbine.gui_name
        local root=player.gui.relative[name] or player.gui.screen[name]
        if mode then
            storage.ei.qc_turbine_failures=failures or 0
            ei_combustion_turbine.on_gui_click{player_index=index,tick=tick,
                element=root["main-container"]["mode-button-flow"][mode.."-mode-button"]}
            root=player.gui.relative[name] or player.gui.screen[name]
        end
        local runtime=storage.ei.combustion_turbine
        local unit=runtime.open_by_player[index]
        local record=unit and runtime.turbines_by_unit[unit]
        return {valid=root and root.valid or false,unit=unit,
            entity=record and record.entity,mode=record and record.mode,
            tags=root and root.tags}
    end,
    paste=function(source,destination,tick)
        ei_combustion_turbine.on_entity_settings_pasted{source=source,destination=destination,tick=tick}
    end,
    leave=function(index) ei_combustion_turbine.on_player_left_game(index) end,
    native_close=function(index) game.get_player(index).opened=nil end,
})

-- Focused native event ordering trace; this bridge never ships.
for _,key in ipairs{"open_gui","update_gui","close_gui","on_gui_closed"} do
    local name,original=key,ei_combustion_turbine[key]
    ei_combustion_turbine[name]=function(...)
        local args={...}
        local player=name=="on_gui_closed" and game.get_player(args[1].player_index) or args[1]
        local function state()
            local runtime=storage.ei.combustion_turbine
            local opened=player.opened
            local root=player.gui.relative[ei_combustion_turbine.gui_name] or player.gui.screen[ei_combustion_turbine.gui_name]
            return helpers.table_to_json{tick=game.tick,opened=opened and opened.valid and opened.name,
                unit=runtime.open_by_player[player.index],proxy_tick=runtime.proxy_open_tick_by_player[player.index],
                root=root and root.valid,event_entity=name=="on_gui_closed" and args[1].entity and args[1].entity.valid and args[1].entity.name}
        end
        log("TURBINE GUI ENTER "..name.." "..state())
        local result=original(...)
        log("TURBINE GUI EXIT "..name.." "..state())
        return result
    end
end

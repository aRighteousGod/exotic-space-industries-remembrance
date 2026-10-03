-- Separate observational replay only. Never append this to timed sources.
do
    local previous=script.get_event_handler(defines.events.on_tick)
    local started,report
    local function count(values)
        local n=0;for _ in pairs(values or {}) do n=n+1 end;return n
    end
    local function snapshot(tick)
        local result={tick=tick,connected_players=#game.connected_players,players={}}
        local ei=storage.ei or {}
        local neutron=ei.neutron_runtime or {}
        result.neutron_gui_sessions={}
        for index,session in pairs(neutron.open_by_player or {}) do
            result.neutron_gui_sessions[#result.neutron_gui_sessions+1]={player_index=index,unit=type(session)=="table" and session.unit_number or nil,pending_tick=type(session)=="table" and session.pending_tick or nil}
        end
        local admin=ei.admin_tools or {}
        result.admin_state_present=ei.admin_tools~=nil
        result.admin_jails=count(admin.jails);result.admin_sessions=count(admin.sessions)
        result.shared_camera_windows=count(storage.ei_camera_windows and storage.ei_camera_windows.windows)
        for _,player in pairs(game.players) do
            local row={index=player.index,connected=player.connected,controller=player.controller_type,roots={}}
            local opened=player.opened
            if opened then
                local ok,name=pcall(function()return opened.object_name end)
                row.opened=ok and name or type(opened)
                if ok and name=="LuaEntity" and opened.valid then row.opened_entity=opened.name end
            else row.opened="none" end
            for _,parent in ipairs{"screen","relative","left","top","center"} do
                local values={}
                for _,child in pairs(player.gui[parent].children) do values[#values+1]={name=child.name,visible=child.visible,type=child.type} end
                table.sort(values,function(a,b)return a.name<b.name end)
                row.roots[parent]=values
            end
            result.players[#result.players+1]=row
        end
        return result
    end
    script.on_event(defines.events.on_tick,function(event)
        if not started then
            started=event.tick
            local setting=settings.startup["ei-admin-tools-enabled"]
            report={factorio=script.active_mods.base,esir=script.active_mods["exotic-space-industries-remembrance"],
                admin_startup_enabled=setting and setting.value or false,first_before_update=snapshot(event.tick)}
        end
        if previous then previous(event) end
        if event.tick==started+119 then
            report.after_120_updates=snapshot(event.tick)
            helpers.write_file("admin-benchmark-scope.json",helpers.table_to_json(report),false)
            log("ADMIN_BENCHMARK_SCOPE_COMPLETE")
        end
    end)
end

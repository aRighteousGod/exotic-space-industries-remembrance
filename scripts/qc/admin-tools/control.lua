local config=require("test-config")
local features=require("features")
local callbacks=require("world-callbacks")
script.on_event(defines.events.script_raised_built,callbacks.on_built)
local checks={}
local function check(name,ok,detail)checks[#checks+1]={name=name,ok=not not ok,detail=detail}end
local function call(name,...)return remote.call("esir-admin-qc",name,...)end
local function report()
    local pass=true;for _,entry in ipairs(checks)do if not entry.ok then pass=false end end
    if config.enabled and not config.visual and not (storage.admin_feature_qc and storage.admin_feature_qc.done) then pass=false end
    helpers.write_file("admin-qc.json",helpers.table_to_json{all_pass=pass,checks=checks,version=script.active_mods.base,tick=game.tick},false)
end
script.on_init(function() storage.started=false end)
script.on_event(defines.events.on_tick,function(event)
    if storage.started then
        if storage.repair_queue and #storage.repair_queue>0 then
            local id=table.remove(storage.repair_queue,1)
            local invoked,ok,message=pcall(call,"execute",nil,"repair",{module_id=id},event.tick)
            check("repeated owner repair "..id,invoked and ok,invoked and message or tostring(ok))
            if #storage.repair_queue==0 then
                local ok,why=pcall(features.start,game.connected_players[1],event.tick,check)
                check("feature fixture started",ok,ok and nil or tostring(why));report()
            end
        end
        if storage.admin_feature_qc and not storage.admin_feature_qc.done then
            local ok,done=pcall(features.tick,event.tick,check)
            if not ok then check("feature fixture completed",false,tostring(done));storage.admin_feature_qc.done=true;report()
            elseif done then check("feature fixture completed",true);report() end
        end
        if config.visual and event.tick%30==0 then
            storage.visual_step=(storage.visual_step or 0)+1
            local page=({"planets","chunks","players","moderation","creation","fluids","enemies","effects","research","diagnostics","repairs","cameras"})[storage.visual_step]
            local player=game.connected_players[1]
            if page and player then
                call("open",player.index,page,event.tick)
                if page=="cameras" then call("camera",player.index,{owner="admin",id="player",player_index=player.index},event.tick) end
                game.take_screenshot{player=player,path="admin-visual/"..page..".png",show_gui=true,show_entity_info=false,resolution=player.display_resolution}
            end
        end
        return
    end
    storage.started=true
    local success,error=pcall(function()
        check("startup gate",settings.startup["ei-admin-tools-enabled"].value==config.enabled)
        check("diagnostic enabled state reads startup switch",call("diagnostics","admin-tools",event.tick).enabled==config.enabled)
        check("legacy goto command",commands.commands["goto-gaia"]~=nil)
        check("legacy repair command",commands.commands["refresh_beacon_overload"]~=nil)
        local before=call("peek")
        local summaries=call("diagnostics",nil,event.tick)
        check("diagnostic owner coverage",#summaries.owners>=47)
        check("pure summary storage",call("peek")==before)
        local seen={};for _,entry in ipairs(call("owners"))do seen[entry.id]=true end
        check("admin owner covered",seen["admin-tools"])
        check("shared camera owner covered",seen["camera-windows"])
        local ok,message=call("execute",nil,"repair",{module_id="camp-fire"},event.tick)
        check("server repair gate",ok==config.enabled,message)
        local player=game.connected_players[1]
        if not player then check("connected player fixture",false,"Use -PlayerSave with a connected-player seed.");return end
        check("connected player fixture",player.connected)
        player.admin=false
        local denied=call("execute",player.index,"speed",{speed=4},event.tick)
        check("nonadmin rejected",not denied)
        player.admin=true
        if config.enabled then
            for _,entry in ipairs(call("defaults_position",player.index,event.tick)) do
                check(entry.name,entry.ok,entry.detail)
            end
        end
        local speed=game.speed
        local allowed=call("execute",player.index,"speed",{speed=2},event.tick)
        check("admin action gate",allowed==config.enabled)
        check("speed result",game.speed==(config.enabled and 2 or speed))
        if config.enabled then
            local peaceful=call("execute",player.index,"planet_peaceful",{planet="nauvis",enabled=true},event.tick)
            check("native planet policy",peaceful and game.surfaces.nauvis.peaceful_mode)
            local blocked=call("execute",player.index,"speed",{speed=65},event.tick)
            check("speed bounds",not blocked and game.speed==2)
            for _,page in ipairs({"planets","chunks","players","moderation","creation","fluids","enemies","effects","research","diagnostics","repairs","cameras"})do
                local opened,why=pcall(call,"open",player.index,page,event.tick)
                check("build page "..page,opened,opened and nil or tostring(why))
            end
            if not config.visual then
                for _,entry in ipairs(call("restriction_permissions",player.index,event.tick)) do
                    check(entry.name,entry.ok,entry.detail)
                end
                for _,entry in ipairs(call("camera_checks",player.index,event.tick)) do
                    check(entry.name,entry.ok,entry.detail)
                end
                for _,entry in ipairs(call("preservation",player.index,event.tick)) do
                    check(entry.name,entry.ok,entry.detail)
                end
                storage.repair_queue={}
                for _=1,2 do for _,owner in ipairs(call("owners")) do if owner.repair then storage.repair_queue[#storage.repair_queue+1]=owner.id end end end
            end
        end
    end)
    check("native fixture completed",success,success and nil or tostring(error))
    report()
end)

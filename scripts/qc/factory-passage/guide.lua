-- Private native Informatron acceptance. Opens actual host pages and translates
-- their captions; no shipping GUI or passage state is replaced by this fixture.
local passage=require("scripts/control/factory-passage")
local config=require("lib/factory-passage-config")
local previous=script.get_event_handler(defines.events.on_tick)
local previous_translation=script.get_event_handler(defines.events.on_string_translated)
local interface="exotic-industries-informatron"
local keys={"walking","modes","controls","recipes","scanner","troubleshooting","current"}
local function check(value,name)
    local q=storage.ei.passage_guide_qc
    q.checks[#q.checks+1]={name=name,passed=not not value};assert(value,name)
end
local function request(player,tag,caption)
    local id=player.request_translation(caption);check(id~=nil,"translation admitted: "..tag)
    storage.ei.passage_guide_qc.pending[id]=tag
end
local function pane(player)
    return player.gui.screen.informatron["main-flow"]["content-container"]["content-pane"]
end
local function capture(player,name)
    local q=storage.ei.passage_guide_qc
    local path="factory-passage/guide-"..player.locale.."-"..name..".png"
    game.take_screenshot{player=player,resolution={1280,960},path=path,show_gui=true,force_render=true}
    q.frames[#q.frames+1]={path=path,scene=name,tick=game.tick}
end
script.on_event(defines.events.on_string_translated,function(e)
    if previous_translation then previous_translation(e) end
    local q=storage.ei.passage_guide_qc;local tag=q and q.pending[e.id]
    if not tag then return end
    check(e.translated and e.result~="" and not e.result:find("Unknown key",1,true) and not e.result:find("__%d+__"),"translated: "..tag)
    q.translations[tag]=e.result;q.pending[e.id]=nil
end)
script.on_event(defines.events.on_tick,function(e)
    previous(e)
    local player=game.connected_players[1];if not player then return end
    local q=storage.ei.passage_guide_qc
    if not q then
        q={started=e.tick,checks={},pending={},translations={},frames={}};storage.ei.passage_guide_qc=q
        player.opened=nil
        local before=serpent.line(storage.ei.factory_passage)
        local menu=remote.call(interface,"informatron_menu",{player_index=player.index})
        check(menu.new_mechanics.factory_passage==1,"ungated New mechanics navigation")
        remote.call("informatron","informatron_open_to_page",{player_index=player.index,interface=interface,page_name="factory_passage"})
        check(serpent.line(storage.ei.factory_passage)==before,"opening guide has no gameplay side effects")
        local frame=player.gui.screen.informatron
        -- Bound the private capture viewport explicitly: hidden Windows clients
        -- may report the desktop resolution instead of the requested window size.
        frame.style.height=680;frame.force_auto_center();frame.bring_to_front()
        pane(player).style.height=520
        local main=frame["main-flow"];local entry=main["menu-frame"]["menu-pane"][interface.."/factory_passage"]
        request(player,"navigation",entry.caption)
        request(player,"title",main["content-container"]["content-subheader"]["content-title"].caption)
        main["menu-frame"]["menu-pane"].style.height=590
        main["menu-frame"]["menu-pane"].scroll_to_element(entry,"top-third")
        local rows=pane(player).children;check(#rows==14,"seven complete guide sections")
        for index,key in ipairs(keys) do
            local heading,body=rows[index*2-1],rows[index*2]
            check(heading.caption[1]=="ei-factory-passage-guide."..key.."-heading" and body.caption[1]=="ei-factory-passage-guide."..key,"section identity: "..key)
            check(not heading.style.single_line and not body.style.single_line,"wrapped section: "..key)
            request(player,key.." heading",heading.caption);request(player,key,body.caption)
        end
        local summary=rows[14].caption;local status=passage.status()
        check(tonumber(summary[5])==status.update_budget and tonumber(summary[7])==status.circuit_scan_budget,"summary uses native budgets")
        check(summary[4][1]=="ei-factory-passage.value-"..status.inactive_reason,"summary explains effective inactivity")
        check(tonumber(rows[10].caption[2])==config.circuit_budget and config.circuit_budget==1,"displayed scan default derives from owner")
        for _,definition in ipairs(config.runtime_setting_definitions()) do
            request(player,definition.name.." name",{"mod-setting-name."..definition.name})
            request(player,definition.name.." description",{"mod-setting-description."..definition.name})
        end
        return
    end
    if q.finished then return end
    local age=e.tick-q.started
    if age==2 then
        local menu=player.gui.screen.informatron["main-flow"]["menu-frame"]["menu-pane"]
        menu.scroll_to_element(menu[interface.."/factory_passage"],"top-third")
    elseif age==4 then capture(player,"top")
    elseif age==6 then pane(player).scroll_to_element(pane(player).children[9],"top-third")
    elseif age==10 then capture(player,"scanner")
    elseif age==12 then pane(player).scroll_to_bottom()
    elseif age==16 then capture(player,"settings")
    elseif age>=30 and next(q.pending)==nil then
        q.finished=true;check(player.locale~="","native locale present")
        helpers.write_file("factory-passage/guide.json",helpers.table_to_json{passed=true,engine=script.active_mods.base,
            locale=player.locale,checks=q.checks,frames=q.frames,translations=q.translations,status=passage.status()},false)
    end
end)

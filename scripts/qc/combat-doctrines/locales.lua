-- Native connected-player fixture: exercise Informatron's real lookup and dispatch.
local test=require("test-config")
local interface="exotic-industries-informatron"
local families={"pyric-radiance","ballistic-divergence"}
local pages={"pyric_radiance","ballistic_divergence"}
local configs={require("__exotic-space-industries-remembrance__/lib/pyric-radiance-config"),
    require("__exotic-space-industries-remembrance__/lib/ballistic-divergence-config")}

script.on_init(function()
    if remote.interfaces.freeplay then
        remote.call("freeplay","set_skip_intro",true)
        remote.call("freeplay","set_disable_crashsite",true)
    end
    storage.locale_qc={phase=test.phase,start_tick=game.tick,pending={},translations={},pages={},requested=0,received=0,next_page=1}
end)

local function request(player,tag,caption)
    local s=storage.locale_qc
    local id=player.request_translation(caption)
    assert(id~=nil,"Translation request rejected: "..tag)
    s.pending[id]=tag;s.requested=s.requested+1
end

local function open_page(player,index)
    local s=storage.locale_qc
    local page,family,config=pages[index],families[index],configs[index]
    remote.call("informatron","informatron_open_to_page",{player_index=player.index,interface=interface,page_name=page})
    local root=assert(player.gui.screen.informatron,"Missing Informatron window")
    local main=assert(root["main-flow"])
    local menu=assert(main["menu-frame"]["menu-pane"][interface.."/"..page])
    local container=assert(main["content-container"])
    local title=assert(container["content-subheader"]["content-title"])
    local rows=container["content-pane"].children
    assert(menu.caption[1]==interface..".menu_"..page,"Incorrect menu lookup: "..page)
    assert(title.caption[1]==interface..".title_"..page,"Incorrect title lookup: "..page)
    assert(#rows==14,"Doctrine page must contain fourteen labels: "..page)
    assert(rows[1].caption[1]==interface.."."..family,"Missing doctrine heading")
    assert(rows[2].caption[1]==interface.."."..family.."-text","Missing doctrine body")
    assert(rows[3].caption[1]=="combat-doctrines.selected","Missing selected-doctrine status")
    assert(rows[3].caption[2][1]=="string-mod-setting."..config.setting_name.."-"..config.resolve().visual_fidelity,"Incorrect selected doctrine")
    assert(rows[3].caption[3][1]==(config.enabled() and "combat-doctrines.on" or "combat-doctrines.off"),"Incorrect enabled status")
    assert(rows[14].caption[1]=="combat-doctrines.credit","Missing concept credit")
    for j,name in ipairs(config.allowed_values) do
        assert(helpers.table_to_json(rows[j+3].caption)==helpers.table_to_json(config.describe(name)),
            "Displayed doctrine must match its shared configuration: "..name)
    end
    request(player,page.."/menu",menu.caption)
    request(player,page.."/title",title.caption)
    for j,row in ipairs(rows) do
        assert(row.type=="label","Unexpected doctrine page element")
        request(player,page.."/label/"..j,row.caption)
    end
    s.pages[#s.pages+1]={page=page,labels=#rows,enabled=config.enabled(),preset=config.resolve().visual_fidelity}
    for _,definition in ipairs(config.startup_setting_definitions()) do
        request(player,definition.name.."/name",{"mod-setting-name."..definition.name})
        request(player,definition.name.."/tooltip",definition.localised_description or {"mod-setting-description."..definition.name})
    end
    request(player,page.."/warning",{"combat-doctrines.overlap-warning",{interface.."."..family}})
end

script.on_event(defines.events.on_string_translated,function(event)
    local s=storage.locale_qc
    local tag=s and s.pending[event.id]
    if not tag or event.player_index~=1 then return end
    assert(event.translated,"Untranslated caption: "..tag)
    assert(event.result~="","Empty caption: "..tag)
    assert(not event.result:find("Unknown key",1,true),"Unknown nested key: "..tag)
    assert(not event.result:find("__%d+__"),"Unsubstituted parameter: "..tag)
    s.pending[event.id]=nil;s.received=s.received+1
    s.translations[#s.translations+1]={tag=tag,result=event.result}
end)

script.on_event(defines.events.on_tick,function(event)
    local s=storage.locale_qc
    if s.all_pass then return end
    local player=game.get_player(1)
    -- Locale arrives after player creation, so wait for the native client to report it.
    if player and player.valid and player.connected and player.locale==test.locale then
        s.locale=player.locale
        if s.next_page<=#pages then
            if not s.opened_tick then
                open_page(player,s.next_page);s.opened_tick=event.tick
            elseif event.tick-s.opened_tick>=10 then
                -- Give the native GUI a rendered frame before requesting its capture.
                local resolution=player.display_resolution
                s.display_resolution=resolution
                game.take_screenshot{player=player,resolution={resolution.width,resolution.height},show_gui=true,
                    path="combat-doctrines/locales-"..test.locale.."-"..pages[s.next_page]..".png"}
                s.opened_tick=nil;s.next_page=s.next_page+1
            end
        elseif not s.submitted then
            request(player,"status/on",{"combat-doctrines.on"})
            request(player,"status/off",{"combat-doctrines.off"})
            s.submitted=true
            assert(s.requested==44,"Unexpected localization coverage")
        end
    end
    if s.submitted and s.received==s.requested then
        s.all_pass=true
        helpers.write_file("combat-doctrines-locales.json",helpers.table_to_json(s),false)
    end
    assert(s.all_pass or event.tick-s.start_tick<280,"Localization timeout: expected "..test.locale.."; completed "..s.received.."/"..s.requested)
end)

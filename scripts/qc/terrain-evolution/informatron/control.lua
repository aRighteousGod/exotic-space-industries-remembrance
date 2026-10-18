-- Native page routing, complete sections, wrapping and actual translations.
-- Documentation only: no terrain mutations or service timing claims.
local options=require("guide-config")
local interface="exotic-industries-informatron"
local pages={
    {name="terrain_evolution",sections={"intro","defaults","observation","protection"}},
    {name="ecology_ground",sections={"soil","recovery","depletion","working","mining-recovery","blood","paving"}},
    {name="ecology_woodland",sections={"stress","greening","regrowth","aging","rot","thermal","wildfire"}},
    {name="ecology_hazards",sections={"flood","drought","cliff"}},
    {name="ecology_seasons",sections={"calendar","daylight","modulation","nauvis","gaia","vulcanus","gleba","fulgora","aquilo"}},
    {name="ecology_controls",sections={"settings","presets","reports","alerts","maintenance","troubleshooting"}},
}
local function check(name,pass)
    local s=storage.guide
    s.count=s.count+1;s.cases[name]={pass=not not pass}
    assert(pass,name)
end
local function translate(player,name,caption)
    if not options.connected then return end
    local s=storage.guide;local id=player.request_translation(caption)
    check("translation accepted "..name,id~=nil)
    s.pending[id]=name;s.requested=s.requested+1
end
local function open(player,page)
    local menu=remote.call(interface,"informatron_menu",{player_index=player.index})
    local branch=menu.world_gen_related.terrain_evolution
    check(page.name.." nested overview remains navigable",type(branch)=="table")
    check(page.name.." child menu admission",page.name=="terrain_evolution" or branch[page.name]==1)
    remote.call("informatron","informatron_open_to_page",{player_index=player.index,interface=interface,page_name=page.name})
    local root=assert(player.gui.screen.informatron)
    if options.connected then
        -- Informatron 0.4.0 fixes its host frame at 800 pixels. Fit only this
        -- test frame into the capture; do not change shipping host styles.
        root.style.height=math.floor((player.display_resolution.height-40)/player.display_scale)
        root.force_auto_center()
    end
    local main=assert(root["main-flow"])
    local entry=assert(main["menu-frame"]["menu-pane"][interface.."/"..page.name])
    local container=assert(main["content-container"])
    local title=container["content-subheader"]["content-title"]
    local pane=container["content-pane"]
    pane.scroll_to_top()
    main["menu-frame"]["menu-pane"].scroll_to_element(entry,"top-third")
    check(page.name.." menu locale",entry.caption[1]==interface..".menu_"..page.name)
    check(page.name.." title locale",title.caption[1]==interface..".title_"..page.name)
    translate(player,page.name.." menu",entry.caption)
    translate(player,page.name.." title",title.caption)
    local rows=pane.children
    check(page.name.." complete sections",#rows==#page.sections*2+(page.name=="terrain_evolution" and 1 or 0))
    for i,key in ipairs(page.sections) do
        local heading,body=rows[i*2-1],rows[i*2]
        check(page.name.." heading "..key,heading.caption[1]=="ei-ecology-guide."..key.."-heading")
        check(page.name.." body "..key,body.caption[1]=="ei-ecology-guide."..key)
        check(page.name.." wrapping "..key,not heading.style.single_line and not body.style.single_line)
        translate(player,page.name.." heading "..key,heading.caption)
        translate(player,page.name.." body "..key,body.caption)
    end
    if page.name=="terrain_evolution" then
        local readout=rows[#rows].caption
        check("overview keeps final effective readout",readout[1]=="ei-terrain.effective")
        if options.disabled then check("startup off is disabled, not unsupported",readout[2][1]=="ei-terrain.status-disabled") end
        translate(player,"effective status",readout)
    end
    storage.guide.pages[#storage.guide.pages+1]={name=page.name,sections=#page.sections,rows=#rows}
end
local function capture(player,page,suffix)
    if not options.connected then return end
    player.gui.screen.informatron.bring_to_front()
    game.take_screenshot{player=player,path="ecology-guide/"..(options.captures or options.locale).."/"..page.name.."-"..suffix..".png",
        resolution=player.display_resolution,show_gui=true,show_entity_info=false,force_render=true}
end
script.on_event(defines.events.on_string_translated,function(event)
    local s=storage.guide;local name=s and s.pending[event.id]
    if not name then return end
    check("translated "..name,event.translated and event.result~="" and not event.result:find("Unknown key",1,true)
        and not event.result:find("__%d+__"))
    s.pending[event.id]=nil;s.received=s.received+1
    s.translations[name]=event.result
end)
script.on_event(defines.events.on_tick,function(event)
    if storage.guide and storage.guide.complete then return end
    local player=game.get_player(1)
    if not player or options.connected and (not player.connected or player.locale~=options.locale) then return end
    if options.connected and (player.display_resolution.width~=1280 or player.display_resolution.height~=720 or player.display_scale~=1) then return end
    local s=storage.guide
    if not s then
        s={count=0,cases={},pages={},next_page=1,start=event.tick,ready_tick=event.tick+2,pending={},requested=0,received=0,translations={}}
        storage.guide=s
        if player.controller_type==defines.controllers.editor then player.set_controller{type=defines.controllers.god} end
        check("effective startup setting",settings.startup["ei-terrain-evolution-enabled"].value==not options.disabled)
    end
    if event.tick<s.ready_tick then return end
    local page=pages[s.next_page]
    if page then
        if not s.opened then open(player,page);s.opened=event.tick
        elseif event.tick-s.opened==10 then capture(player,page,"top")
        elseif event.tick-s.opened==20 then
            local pane=player.gui.screen.informatron["main-flow"]["content-container"]["content-pane"]
            pane.scroll_to_bottom()
        elseif event.tick-s.opened>=30 then
            capture(player,page,"bottom");s.next_page=s.next_page+1;s.opened=nil
        end
    elseif s.received==s.requested then
        check("all six native pages",#s.pages==6)
        if options.connected then check("all guide captions translated",s.requested==85) end
        s.complete=true;s.all_pass=true;s.locale=player.locale;s.connected=player.connected
        s.display_resolution=player.display_resolution;s.display_scale=player.display_scale;s.fixture_host_frame_fit=options.connected
        if options.connected then game.set_wait_for_screenshots_to_finish() end
        helpers.write_file("terrain-qc.json",helpers.table_to_json(s),false)
        log("ECOLOGY_GUIDE_QC PASS pages=6 checks="..s.count.." translations="..s.received)
    end
    assert(event.tick-s.start<1200,"Guide fixture timed out")
end)

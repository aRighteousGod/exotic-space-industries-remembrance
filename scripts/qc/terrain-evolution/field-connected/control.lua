-- Real connected-client runner. Requests translations in this helper's context,
-- so its on_string_translated receiver owns every outstanding request.
local options=require("config")
local function state()
    storage.field_driver=storage.field_driver or {queue={},head=1,pending={},requested=0,received=0,translations={},checks={}}
    return storage.field_driver
end
local function check(name,ok,detail)
    assert(ok,name..(detail and ": "..tostring(detail) or ""))
    local s=state();s.checks[#s.checks+1]={name=name,ok=true,detail=detail}
end
local function finish(result)
    local s=state();if s.complete then return end
    s.complete=true
    local checks={};for _,r in ipairs(result.checks or {}) do checks[#checks+1]=r end
    for _,r in ipairs(s.checks) do checks[#checks+1]=r end
    checks[#checks+1]={name="all actual report captions translated",ok=s.requested>0 and s.received==s.requested}
    local pass=result.all_pass and checks[#checks].ok
    for _,r in ipairs(checks) do if not r.ok then pass=false end end
    game.set_wait_for_screenshots_to_finish()
    helpers.write_file("terrain-admin-qc.json",helpers.table_to_json{
        complete=true,all_pass=pass,checks=checks,count=#checks,locale=options.locale,
        requested=s.requested,received=s.received,translations=s.translations,
        native=result,version=script.active_mods.base,tick=game.tick,
        scope="Native connected field-report construction, translations, captures and instrumented work limits; separate unwrapped profiling records do not measure whole-engine cost."},false)
    log("ECOLOGY_FIELD_QC COMPLETE locale="..options.locale.." pass="..tostring(pass).." translations="..s.received)
end
script.on_event(defines.events.on_string_translated,function(event)
    local s=state();local tag=s.pending[event.id]
    if not tag then return end
    local good=event.translated and event.result~="" and not event.result:find("Unknown key",1,true)
        and not event.result:find("__%d+__")
    if not good then
        s.checks[#s.checks+1]={name="native translated "..tag,ok=false,detail=event.result}
        s.failed=true
    end
    s.pending[event.id]=nil;s.received=s.received+1;s.translations[tag]=event.result
end)
script.on_event(defines.events.on_tick,function(event)
    local s=state();if s.complete then return end
    local player=game.connected_players[1];if not player then return end
    s.start_tick=s.start_tick or event.tick
    local ok,err=pcall(function()
        if player.locale~=options.locale then return end
        if player.display_resolution.width~=1280 or player.display_resolution.height~=720 or player.display_scale~=(options.scale or 1) then return end
        if not s.ready then
            s.ready=true;check("real connected player uses intended locale",player.connected and player.locale==options.locale)
            check("native viewport uses requested scale",player.display_resolution.width==1280 and player.display_resolution.height==720 and player.display_scale==(options.scale or 1))
        end
        if not s.native_complete then
            local response=remote.call("ei-field-report-qc","step",player.index,event.tick)
            for _,row in ipairs(response.captions or {}) do s.queue[#s.queue+1]=row end
            if response.complete then s.native_complete=true;s.native=response end
        end
        for _=1,8 do
            local row=s.queue[s.head];if not row then break end
            local id=player.request_translation(row.caption)
            check("native translation admitted "..row.tag,id~=nil)
            s.pending[id]=row.tag;s.requested=s.requested+1;s.head=s.head+1
        end
        if s.native_complete and s.head>#s.queue and s.received==s.requested then
            if s.failed then s.native.all_pass=false end
            finish(s.native)
        end
    end)
    if not ok or event.tick-s.start_tick>(options.timeout_ticks or 10000) then
        s.checks[#s.checks+1]={name="connected fixture completes without Lua errors or timeout",ok=false,
            detail=not ok and tostring(err) or "timeout; requested="..s.requested.." received="..s.received}
        local good,result=pcall(remote.call,"ei-field-report-qc","result")
        result=good and result or {checks={},all_pass=false};result.all_pass=false
        finish(result)
    end
end)

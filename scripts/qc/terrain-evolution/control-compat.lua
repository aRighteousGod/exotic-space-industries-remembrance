local expected=script.active_mods["diurnal-dynamics"] and "diurnal-dynamics" or script.active_mods.TerrainEvolution2 and "TerrainEvolution2" or "TerrainEvolution"
script.on_init(function()storage.baseline=game.surfaces.nauvis.daytime_parameters end)
script.on_event(defines.events.on_tick,function(event)
    if event.tick~=1199 then return end
    local s=game.surfaces.nauvis
    local status=remote.call("ei-terrain-qc","snapshot",s.index)
    local cases={}
    for _,key in ipairs{"dusk","evening","morning","dawn"}do cases[key]={pass=s.daytime_parameters[key]==storage.baseline[key]}end
    cases.calendar_status={pass=status.calendar.status==expected or (expected~="diurnal-dynamics" and status.status==expected)}
    cases.ecology_overlap={pass=expected=="diurnal-dynamics" and status.effective.enabled or expected~="diurnal-dynamics" and not status.effective.enabled}
    cases.no_ownership={pass=not status.calendar.owns_daylight}
    local all=true;for _,r in pairs(cases)do all=all and r.pass end
    helpers.write_file("terrain-qc.json",helpers.table_to_json{all_pass=all,count=7,cases=cases},false)
end)

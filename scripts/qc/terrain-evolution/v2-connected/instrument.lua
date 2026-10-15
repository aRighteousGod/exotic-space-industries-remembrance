-- Staged-only bridge: real player, native GUI and shipping dispatchers.
local ecology_v2_fixture=require("__zzz-esir-ecology-v2-qc__/fixture")
local ecology_v2_context={terrain=require("scripts/control/terrain-evolution"),gui=require("scripts/control/terrain-gui"),
    alerts=require("scripts/control/terrain-alerts"),preferences=require("lib/terrain-alert-config")}
-- Attribution excludes engine rendering and the fixture's own setup/captures.
for _,name in ipairs{"gui","alerts"} do
    local module=ecology_v2_context[name];local update=module.updater
    module.updater=function(event)
        local profiler=helpers.create_profiler();update(event);profiler.stop()
        log({"","ECOLOGY_PRESENTATION_PROFILE owner="..name.." tick="..event.tick.." elapsed=",profiler})
    end
end
local ecology_launcher_update=ecology_v2_context.gui.launcher_updater
ecology_v2_context.gui.launcher_updater=function(event)
    local profiler=helpers.create_profiler();ecology_launcher_update(event);profiler.stop()
    log({"","ECOLOGY_PRESENTATION_PROFILE owner=launcher tick="..event.tick.." elapsed=",profiler})
end
remote.add_interface("ei-ecology-v2-qc",{step=function(index,phase,tick) return ecology_v2_fixture.step(ecology_v2_context,game.get_player(index),phase,tick) end,
    capture=function(index,phase,tick) ecology_v2_fixture.capture(game.get_player(index),phase,tick) end})

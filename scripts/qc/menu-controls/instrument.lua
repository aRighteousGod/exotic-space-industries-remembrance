-- Appended only to the disposable current-source copy by the terrain runner.
local menu_fixture=require("__zzz-esir-menu-controls-qc__/fixture")
local menu_context={gui=require("scripts/control/terrain-gui"),
    terrain=require("scripts/control/terrain-evolution"),admin=require("scripts/control/admin-tools")}
remote.add_interface("ei-menu-controls-qc",{
    step=function(index,tick) return menu_fixture.step(menu_context,game.get_player(index),tick) end,
})

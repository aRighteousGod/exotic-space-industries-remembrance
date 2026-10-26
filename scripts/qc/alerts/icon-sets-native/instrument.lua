-- Appended only to the staged gameplay control. No production remote interface.
local icon_sets_fixture=require("__zzz-esir-icon-sets-qc__/scenario")
local icon_sets_context={alerts=require("lib/alerts"),sets=require("lib/alert-icon-sets"),catalog=require("lib/alert-catalog"),
    ecology=require("scripts/control/terrain-alerts"),terrain=require("scripts/control/terrain-evolution"),
    gui=require("scripts/control/terrain-gui"),
    click=function(event) script.get_event_handler(defines.events.on_gui_click)(event) end,
    selection=function(event) script.get_event_handler(defines.events.on_gui_selection_state_changed)(event) end,
    tabs=function(event) script.get_event_handler(defines.events.on_gui_selected_tab_changed)(event) end}
remote.add_interface("ei-icon-sets-qc",{step=function(index,tick,first)
    return icon_sets_fixture.step(icon_sets_context,game.get_player(index),tick,first)
end})

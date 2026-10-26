-- Appended only to a staged main mod; the production mod exposes no remote API.
local alert_fixture=require("__zzz-esir-alerts-qc__/fixture")
local alert_context={alerts=require("lib/alerts"),catalog=require("lib/alert-catalog"),
    ecology=require("scripts/control/terrain-alerts"),terrain=require("scripts/control/terrain-evolution"),
    gate=require("scripts/control/gate"),gui=require("scripts/control/terrain-gui")}
remote.add_interface("ei-alerts-qc",{step=function(index,tick,first) return alert_fixture.step(alert_context,game.get_player(index),tick,first) end})

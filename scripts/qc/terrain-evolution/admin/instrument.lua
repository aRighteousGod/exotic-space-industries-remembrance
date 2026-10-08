
-- Append only to the copied ESIR control.lua in an isolated QC mod directory.
-- Dependencies are loaded while control is parsed, never inside the callbacks.
local terrain_admin_qc_fixture=require("__zzz-esir-terrain-admin-qc__/ecology")
local terrain_admin_qc_context={
    admin=require("scripts/control/admin-tools"),
    gui=require("scripts/control/admin/gui"),
    common=require("scripts/control/admin/common"),
    ecology=require("scripts/control/admin/ecology"),
    terrain=require("scripts/control/terrain-evolution"),
    config=require("lib/terrain-evolution-config"),
}
remote.add_interface("esir-terrain-admin-qc",{
    start=function(index,tick)return terrain_admin_qc_fixture.start(terrain_admin_qc_context,game.get_player(index),tick)end,
    idle_begin=function(index,tick)return terrain_admin_qc_fixture.idle_begin(terrain_admin_qc_context,game.get_player(index),tick)end,
    finish=function(index,tick)return terrain_admin_qc_fixture.finish(terrain_admin_qc_context,game.get_player(index),tick)end,
    cleanup=function(index,tick)return terrain_admin_qc_fixture.cleanup(terrain_admin_qc_context,game.get_player(index),tick)end,
})

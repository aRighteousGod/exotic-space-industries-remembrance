
-- Fixture-only bridge; appended to the isolated runtime copy by the QC driver.
local admin_qc_common=require("scripts/control/admin/common")
local admin_qc_preservation=require("__zzz-esir-admin-qc__/preservation")
local admin_qc_effects=require("scripts/control/fluid-rupture-effects")
local admin_qc_targeting=require("scripts/control/admin/targeting")
local admin_qc_target_fixture=require("__zzz-esir-admin-qc__/targeting")
local admin_qc_world_gui_fixture=require("__zzz-esir-admin-qc__/world-gui")
local admin_qc_world=require("scripts/control/admin/world")
local admin_qc_gui=require("scripts/control/admin/gui")
local admin_qc_world_callbacks=require("__zzz-esir-admin-qc__/world-callbacks")
local admin_qc_camera_fixture=require("__zzz-esir-admin-qc__/camera")
local admin_qc_restrictions=require("scripts/control/admin/restrictions")
local admin_qc_restriction_permissions=require("__zzz-esir-admin-qc__/restriction-permissions")
local admin_qc_defaults_position=require("__zzz-esir-admin-qc__/defaults-and-position")
remote.add_interface("esir-admin-qc",{
    diagnostics=function(id,tick)return ei_admin_tools.diagnostics(id,tick)end,
    coverage=function()return ei_admin_tools.registry.coverage()end,
    owners=function()return ei_admin_tools.registry.list()end,
    execute=function(index,action,args,tick)return ei_admin_tools.execute(index and game.get_player(index),action,args,tick)end,
    open=function(index,page,tick)ei_admin_tools.open(game.get_player(index),page,tick)end,
    peek=function()return admin_qc_common.peek()~=nil end,
    preservation=function(index,tick)
        return admin_qc_preservation.run({fusion=ei_fusion_reactor,crystal=ei_crystal_accumulator,
            railgun=ei_railgun_cooling,emerald=ei_emerald_apocalypse_hover_tank,
            effects=admin_qc_effects,em=em_trains,neutron=ei_neutron_collector,matter=ei_matter_stabilizer},ei_admin_tools.registry,game.get_player(index),tick)
    end,
    camera=function(index,options,tick)local root,error=ei_lib.camera_open(game.get_player(index),options,tick);return root~=nil,error end,
    reforge=function(tick)ei_gaia.reforge_gaia_surface{tick=tick}end,
    reforge_pending=function()return storage.ei.reforge_gaia~=nil end,
    peaceful_default=function(value)settings.global["ei-admin-new-planets-peaceful"]={value=value}end,
    targeting=function(index,tick)return admin_qc_target_fixture.run(ei_admin_tools,admin_qc_targeting,admin_qc_common,game.get_player(index),tick)end,
    camera_checks=function(index,tick)return admin_qc_camera_fixture.run(ei_admin_tools,ei_lib,admin_qc_common,game.get_player(index),tick)end,
    restriction_permissions=function(index,tick)return admin_qc_restriction_permissions.run(admin_qc_restrictions,admin_qc_common,game.get_player(index),tick)end,
    defaults_position=function(index,tick)return admin_qc_defaults_position.run(ei_admin_tools,admin_qc_gui,admin_qc_common,game.get_player(index),tick)end,
    rupture_pending=function()return admin_qc_effects.admin_has_work()end,
    world_gui_start=function(index,surface_index,tick)return admin_qc_world_gui_fixture.start(ei_admin_tools,admin_qc_common,admin_qc_world,game.get_player(index),game.get_surface(surface_index),tick)end,
    world_gui_finish=function(index,tick)return admin_qc_world_gui_fixture.finish(ei_admin_tools,admin_qc_gui,admin_qc_common,admin_qc_world,game.get_player(index),tick)end,
    world_summary=function()return admin_qc_world.peek_summary()end,
    travel_catalog_fixture=function(index,tick)return admin_qc_world_callbacks.travel(ei_admin_tools,admin_qc_gui,admin_qc_common,game.get_player(index),tick)end,
})

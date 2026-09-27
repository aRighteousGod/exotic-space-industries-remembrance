-- Appended only to the staged ESIR copy; no public production interface.
remote.add_interface("esir-flame-qc",{
    status=function() return ei_flamethrower_fuels.get_status() end,
    has_tick_work=function() return ei_flamethrower_fuels.has_tick_work{tick=game.tick} end,
    rebuild=function() ei_flamethrower_fuels.rebuild() end,
    fail=function(value) storage.ei.flame_qc_fail=value end,
    sync_force=function(index) ei_flamethrower_fuels.sync_force(game.forces[index]) end,
    blueprint=function(index) ei_flamethrower_fuels.on_blueprint{player_index=index} end,
    profile=function(action) ei_flamethrower_fuels.qc_profile(action) end,
})

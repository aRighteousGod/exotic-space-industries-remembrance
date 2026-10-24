-- Appended only to the staged ESIR control.lua; production has no QC interface.
remote.add_interface("alien-beacon-repair-qc", {
    repair = ei_alien_system.on_player_selected_area,
})

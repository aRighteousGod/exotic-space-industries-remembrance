-- Private central-dispatch bridge: native GUI events cannot be raised by mods.
remote.add_interface("esir-orbital-gui-qc",{
    opened=function(event) return script.get_event_handler(defines.events.on_gui_opened)(event) end,
    closed=function(event) return script.get_event_handler(defines.events.on_gui_closed)(event) end,
})

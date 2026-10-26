for _,name in ipairs{"ei-toggle-admin-menu","ei-toggle-ecology-menu"} do
    local input=assert(data.raw["custom-input"][name],name)
    assert(input.key_sequence=="" and not input.alternative_key_sequence,name.." must start unbound")
    assert(input.consuming=="none" and not input.linked_game_control and not input.hidden,name.." must be independently assignable")
end
log("MENU_CONTROLS_QC unbound visible prototypes passed")

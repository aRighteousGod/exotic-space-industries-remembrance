--==============================================================================
-- ESIR FILE MAP
-- owns: ecology menu input, GUI artwork and private contained-flame prototype
-- loaded_by: data.lua
-- cadence: data stage; artwork and entities gated by ei-terrain-evolution-enabled
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none (runtime terrain GUI owns instances)
-- remote_interfaces: none
-- rebuild_on: data stage reload, startup setting changes
--==============================================================================
-- blueprint: .codex/esir/blueprints/terrain-evolution.md#contract
-- Keep the unbound control assignable even while ecology is disabled.
data:extend{{type="custom-input",name="ei-toggle-ecology-menu",key_sequence="",consuming="none"}}
-- Owned contained flame. Never mutate the global native forest-fire prototype.
if settings.startup["ei-terrain-evolution-enabled"].value then
    for _,planet in ipairs{"nauvis","gaia","vulcanus","gleba","fulgora","aquilo"} do
        data:extend{{type="sprite",name="ei-ecology-banner-"..planet,
            filename=ei_graphics_6_path.."graphics/gui/ecology-field-"..planet..".png",
            width=1536,height=384,flags={"gui"}}}
    end
    data:extend{{type="sprite",name="ei-ecology-banner-neutral",
        filename=ei_graphics_destination_path.."space.png",size=144,flags={"gui"}}}
    for _,season in ipairs{"spring","summer","autumn","winter"} do
        data:extend{{type="sprite",name="ei-ecology-tree-"..season,
            filename=ei_graphics_6_path.."graphics/gui/ecology-tree-"..season..".png",
            size=128,flags={"gui"},scale=0.25}}
    end
    local fire=table.deepcopy(data.raw.fire["fire-flame"])
    fire.name="ei-ecology-fire"
    fire.spawn_entity=nil
    fire.maximum_spread_count=0
    fire.tree_dying_factor=nil
    fire.lifetime_increase_by=0
    fire.initial_lifetime=600
    fire.maximum_lifetime=600
    fire.burnt_patch_lifetime=0
    data:extend{fire}
end

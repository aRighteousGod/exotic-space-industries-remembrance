-- blueprint: .codex/esir/blueprints/terrain-evolution.md#contract
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
    -- Notification anchor: nonselectable, noncombat helper. Intentionally has no
    -- death effects, interaction sounds, item, or Factoriopedia presentation.
    data:extend{fire,{
        type="simple-entity-with-owner",name="ei-ecology-alert-anchor",hidden=true,hidden_in_factoriopedia=true,
        flags={"not-on-map","placeable-off-grid","not-blueprintable","not-deconstructable","not-upgradable","not-repairable","not-flammable","not-in-kill-statistics","hide-alt-info"},
        selectable_in_game=false,collision_mask={layers={}},collision_box={{0,0},{0,0}},selection_box={{0,0},{0,0}},
        is_military_target=false,max_health=1,random_variation_on_create=false,
        picture={filename=ei_lib.empty_sprite(),width=64,height=64}
    }}
end

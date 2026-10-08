-- blueprint: .codex/esir/blueprints/terrain-evolution.md#contract
-- Owned contained flame. Never mutate the global native forest-fire prototype.
if settings.startup["ei-terrain-evolution-enabled"].value then
    local fire=table.deepcopy(data.raw.fire["fire-flame"])
    fire.name="ei-ecology-fire"
    fire.spawn_entity=nil
    fire.maximum_spread_count=0
    fire.tree_dying_factor=nil
    fire.lifetime_increase_by=0
    fire.initial_lifetime=600
    fire.maximum_lifetime=600
    data:extend{fire}
end

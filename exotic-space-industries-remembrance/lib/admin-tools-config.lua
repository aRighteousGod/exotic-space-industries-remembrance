-- blueprint: .codex/esir/blueprints/admin-tools.md#contract
-- Shared identifiers only: safe in settings, data and runtime stages.
local config = {
    setting = "ei-admin-tools-enabled",
    peaceful_setting = "ei-admin-new-planets-peaceful",
    restricted_setting = "ei-admin-restrict-new-players",
    gui = "ei-admin-console",
    launcher = "ei-admin-launcher",
    selector = "ei-admin-location-selector",
    version = 1,
    pages = {
        {id="planets", group="world"}, {id="chunks", group="world"}, {id="ecology", group="world"},
        {id="players", group="players"}, {id="moderation", group="players"},
        {id="creation", group="sandbox"}, {id="fluids", group="sandbox"},
        {id="enemies", group="sandbox"}, {id="effects", group="sandbox"},
        {id="research", group="system"}, {id="diagnostics", group="system"},
        {id="repairs", group="system"}, {id="cameras", group="system"},
    },
}
return config

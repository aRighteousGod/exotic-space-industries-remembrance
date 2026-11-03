if not mods["exotic-space-industries-remembrance"] then
    data:extend(require("lib/factory-passage-config").startup_setting_definitions())
    data:extend(require("lib/factory-passage-config").runtime_setting_definitions())
end

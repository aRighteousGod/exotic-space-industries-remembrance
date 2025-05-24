local flib_migration = require("__flib__.migration")

local function ensure_turret_force()
  if not game.forces["kr-internal-turrets"] then
    game.create_force("kr-internal-turrets")
  end
end

local migrations = {}

migrations.on_init = ensure_turret_force

function migrations.on_configuration_changed(e)
  if flib_migration.on_config_changed(e, migrations.versions) then
    ensure_turret_force()
  end
end

return migrations
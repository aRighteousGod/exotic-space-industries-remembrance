-- Appended only to an isolated ESIR control.lua by invoke-control-ups-qc.ps1.
do
    local policy = require("scripts/control/planet-enemies")
    local config = require("lib/planet-enemies-config")
    local gaia_data = require("scripts/control/gaia-mapgen-data")
    local gaia_model = require("scripts/control/gaia")
    local previous = script.get_event_handler(defines.events.on_tick)
    local previous_load = assert(__control_ups_load)
    local loaded = false
    script.on_load(function()
        if previous_load then previous_load() end
        loaded = storage.planet_enemy_qc ~= nil and storage.planet_enemy_qc.burst ~= nil
    end)
    local function check(name, pass, detail)
        local state = storage.planet_enemy_qc
        state.checks[#state.checks + 1] = {name = name, pass = not not pass, detail = detail}
        if not pass then state.all_pass = false; log("PLANET_ENEMY_QC FAIL " .. name .. " " .. serpent.line(detail)) end
    end
    local function set_control(surface, control, value)
        local settings = surface.map_gen_settings
        settings.autoplace_controls[control] = {frequency = value, size = value, richness = 1}
        surface.map_gen_settings = settings
    end
    local function spawn(surface, name, position, force)
        return surface.create_entity{name = name, position = position or {1800, 1800}, force = force or "enemy"}
    end
    local previous_robot=script.get_event_handler(defines.events.on_robot_pre_mined)
    script.on_event(defines.events.on_robot_pre_mined,function(event)
        if previous_robot then previous_robot(event) end
        local state=storage.planet_enemy_qc
        if state and event.entity.name=="fulgoran-ruin-vault" then
            state.robot_mined=true
            local guardians=event.entity.surface.find_entities_filtered{position=event.entity.position,radius=2,name="walking-electric-unit-boss-1"}
            check("robot-mining-guardian-safe",#guardians==1 and guardians[1].disabled_by_script)
            state.robot_guardian=guardians[1]
        end
    end)
    script.on_event(defines.events.on_tick, function(event)
        if loaded and storage.planet_enemy_qc and not storage.planet_enemy_qc.reloaded then
            storage.planet_enemy_qc.reloaded = true
            local queue=storage.ei.planet_enemies
            -- server_save finishes after a tick boundary; the first budget may
            -- already have drained. The tail must still be inert and pending.
            local entity=storage.planet_enemy_qc.burst[2600]
            check("reload-preserves-queue",queue and queue.items[queue.head]
                and #storage.planet_enemy_qc.burst==2600 and entity.valid and entity.disabled_by_script,
                {tick=event.tick,head=queue and queue.head,tail_valid=entity.valid})
        end
        previous(event)
        if not storage.planet_enemy_qc then
            helpers.write_file("planet-enemies-final-data.json",helpers.table_to_json(prototypes.mod_data["ei-planet-enemies-qc"].data),false)
            storage.planet_enemy_qc = {checks = {}, all_pass = true, start = event.tick, pending = {}, kept = {}}
            local state = storage.planet_enemy_qc
            local surfaces = {}
            for _, name in ipairs({"nauvis", "vulcanus", "aquilo", "fulgora", "gaia", "gleba"}) do
                local surface = game.planets[name].create_surface()
                surface.no_enemies_mode = false
                surfaces[name] = surface
                surface.request_to_generate_chunks({1800, 1800}, 2)
                surface.force_generate_chunk_requests()
                local tiles = {}
                for x = 1760, 1860 do
                    for y = 1760, 1860 do tiles[#tiles + 1] = {name = "landfill", position = {x, y}} end
                end
                surface.set_tiles(tiles)
            end
            state.surfaces = surfaces
            local old = spawn(surfaces.aquilo,"small-cold-biter",{1840,1840})
            state.kept[#state.kept+1]=old
            for planet, controls in pairs(config.controls) do
                for family, control in pairs(controls) do
                    set_control(surfaces[planet], control, 0)
                    check(planet .. "-" .. family .. "-off", policy.is_disabled(surfaces[planet], family))
                end
            end
            local families = {
                vulcanus = {"small-explosive-biter", "explosive-biter-spawner", "small-explosive-worm-turret"},
                aquilo = {"small-cold-biter", "small-cold-spitter", "cb-cold-spawner", "small-cold-worm-turret"},
                fulgora = {"walking-electric-unit-1", "flying-electric-unit-1", "walking-electric-unit-boss-1", "walker-electric-unit-spawner"},
                gaia = {"flying-electric-unit-spawner", "walker-electric-unit-spawner"},
                gleba = {"small-wriggler-pentapod", "big-wriggler-pentapod-premature", "small-stomper-pentapod", "small-strafer-pentapod"},
            }
            for planet, names in pairs(families) do
                for i, name in ipairs(names) do
                    local entity = spawn(surfaces[planet], name, {1770 + i * 15, 1770})
                    check("created-return-" .. name, entity and entity.valid)
                    if entity then
                        check("inert-" .. name, entity.disabled_by_script and not entity.destructible,
                            {updatable = entity.is_updatable, disabled = entity.disabled_by_script})
                        state.pending[#state.pending + 1] = {entity = entity, name = name}
                    end
                end
            end
            for i, name in ipairs({"gleba-spawner", "gleba-spawner-small"}) do
                local raft = spawn(surfaces.gleba, name, {1790 + i * 20, 1830})
                check("inactive-" .. name, raft and raft.disabled_by_script and raft.destructible)
            state.kept[#state.kept + 1] = raft
            if i == 1 then state.large_raft = raft end
            end
            local unit = surfaces.vulcanus.create_segmented_unit{name = "small-demolisher", position = {2500,2500}}
            check("whole-demolisher-off", unit == nil)
            set_control(surfaces.vulcanus, config.demolisher_control, 1)
            unit = surfaces.vulcanus.create_segmented_unit{name = "small-demolisher", position = {2500,2500}}
            check("demolisher-independent-from-explosive", unit and unit.valid)
            if unit then unit.destroy() end
            -- Fulgora's actual dependency callback creates and boosts the guardian.
            local vault = spawn(surfaces.fulgora, "fulgoran-ruin-vault", {1800, 1820}, "neutral")
            check("vault-created", vault and vault.valid)
            if vault then vault.die(game.forces.player) end
            local guardians = surfaces.fulgora.find_entities_filtered{position={1800,1820},radius=5,name="walking-electric-unit-boss-1"}
            check("vault-script-return-safe", #guardians == 1 and guardians[1].disabled_by_script)
            if guardians[1] then state.pending[#state.pending+1] = {entity=guardians[1],name="vault-guardian"} end
            local custom = game.create_force("planet-enemy-qc-hostile")
            local nearby = spawn(surfaces.fulgora,"small-biter",{1819,1820},custom)
            local attacker = spawn(surfaces.fulgora,"character",{1825,1820},"player")
            local custom_vault = spawn(surfaces.fulgora,"fulgoran-ruin-vault",{1820,1820},"neutral")
            custom_vault.die(game.forces.player,attacker)
            local custom_guardians=surfaces.fulgora.find_entities_filtered{force=custom,name="walking-electric-unit-boss-1"}
            check("custom-force-vault-safe",#custom_guardians==1 and custom_guardians[1].disabled_by_script)
            for _,entity in pairs(custom_guardians) do state.pending[#state.pending+1]={entity=entity,name="custom-guardian"} end
            nearby.destroy();attacker.destroy()
            local player=game.get_player(1)
            -- Headless checkpoint creation has no connected player; the ordinary
            -- benchmark fixture exercises the real player mining callback.
            if not game.is_multiplayer() or player.connected then
                player.teleport({1800,1810},surfaces.fulgora)
                if not player.character then
                    player.set_controller{type=defines.controllers.god}
                    player.create_character()
                end
                local mined=spawn(surfaces.fulgora,"fulgoran-ruin-vault",{1800,1810},"neutral")
                check("player-vault-mined",player.mine_entity(mined,true))
                local mined_guardians=surfaces.fulgora.find_entities_filtered{position={1800,1810},radius=3,name="walking-electric-unit-boss-1"}
                check("player-mining-guardian-safe",#mined_guardians==1 and mined_guardians[1].disabled_by_script)
                for _,entity in pairs(mined_guardians) do state.pending[#state.pending+1]={entity=entity,name="mined-guardian"} end
                player.teleport({0,0},game.surfaces.nauvis)
            end
            -- Real egg spoilage trigger, not a direct handler call.
            local chest = spawn(surfaces.gleba, "steel-chest", {1780, 1820}, "player")
            chest.insert{name="pentapod-egg",count=1}
            chest.get_inventory(defines.inventory.chest)[1].spoil()
            state.egg_area = {{1775,1815},{1785,1825}}
            -- Defaults/fallback and legacy Gaia settings preserve explicit Off.
            local mgs = surfaces.gaia.map_gen_settings
            mgs.seed = 421337; mgs.no_enemies_mode = true; mgs.peaceful_mode = true
            mgs.cliff_settings.cliff_elevation_interval = 123
            mgs.autoplace_controls[config.gaia_control] = nil
            mgs.autoplace_controls.electric_enemies = {frequency=0,size=0,richness=1}
            local rebuilt = gaia_data.get_map_gen_settings(mgs)
            check("gaia-builder-preserves-off", rebuilt.autoplace_controls[config.gaia_control].size == 0)
            check("gaia-builder-preserves-flags", rebuilt.seed == 421337 and rebuilt.no_enemies_mode and rebuilt.peaceful_mode)
            check("gaia-builder-preserves-cliffs",rebuilt.cliff_settings.cliff_elevation_interval==123)
            surfaces.gaia.map_gen_settings = mgs
            policy.on_configuration_changed({})
            local migrated = surfaces.gaia.map_gen_settings
            check("gaia-legacy-migration", migrated.autoplace_controls[config.gaia_control].size == 0
                and migrated.autoplace_controls.electric_enemies == nil)
            -- Other planet and player force must remain untouched.
            set_control(surfaces.fulgora, "electric_enemies", 1)
            local allowed = spawn(surfaces.fulgora, "walking-electric-unit-1", {1840, 1840})
            check("gaia-off-fulgora-on", allowed and not allowed.disabled_by_script)
            state.kept[#state.kept+1] = allowed
            local friendly = spawn(surfaces.gaia, "walking-electric-unit-1", {1840, 1840}, "player")
            check("player-force-excluded", friendly and not friendly.disabled_by_script)
            state.kept[#state.kept+1] = friendly
            surfaces.fulgora.no_enemies_mode = true
            local blocked = spawn(surfaces.fulgora, "walking-electric-unit-1", {1840, 1810})
            check("native-no-enemies-wins", blocked and blocked.disabled_by_script)
            if blocked then state.pending[#state.pending+1] = {entity=blocked,name="global-off"} end
        end
        local state = storage.planet_enemy_qc
        local age = event.tick - state.start
        if age == 3 then
            for _, entry in ipairs(state.pending) do check("removed-" .. entry.name, not entry.entity.valid) end
            for i, entity in ipairs(state.kept) do check("retained-" .. i, entity and entity.valid) end
            local hostile = state.surfaces.gleba.find_entities_filtered{area=state.egg_area,force="enemy",type="unit"}
            check("egg-hatch-suppressed", #hostile == 0)
            local raft = state.large_raft
            state.raft_position = raft.position
            raft.die(game.forces.player)
            local drops = state.surfaces.gleba.find_entities_filtered{position=state.raft_position,radius=10,type="item-entity"}
            local eggs = 0
            for _, drop in pairs(drops) do if drop.stack.name == "pentapod-egg" then eggs = eggs + drop.stack.count end end
            check("raft-egg-loot", eggs >= 9, eggs)
            local deleted=game.create_surface("planet-enemy-deleted",gaia_data.get_map_gen_settings(state.surfaces.gaia.map_gen_settings))
            storage.gaia_surfaces[deleted.name]=true
            set_control(deleted,config.gaia_control,0)
            local doomed=spawn(deleted,"walking-electric-unit-1",{0,0})
            check("deleted-surface-birth-queued",doomed and doomed.disabled_by_script)
            game.delete_surface(deleted)
        elseif age == 6 then
            local offspring = state.surfaces.gleba.find_entities_filtered{position=state.raft_position,radius=10,type="unit"}
            check("raft-death-offspring-suppressed", #offspring == 0)
            -- Queue more than the budget, with a stale entry, then allow the real dispatcher to drain.
            state.burst = {}
            for i=1,2600 do
                local entity = spawn(state.surfaces.gaia, "walking-electric-unit-1", {2000+i*2,2000})
                if entity then state.burst[#state.burst+1] = entity end
            end
            check("burst-created", #state.burst == 2600, #state.burst)
            state.burst[1].destroy()
            game.server_save("planet-enemies-pending")
        elseif age == 7 then
            local alive = 0
            for _, entity in ipairs(state.burst) do if entity.valid then alive=alive+1 end end
            check("bounded-128-record-drain", alive == 2472, alive)
        elseif age == 30 then
            local alive = 0
            for _, entity in ipairs(state.burst) do if entity.valid then alive=alive+1 end end
            check("queue-drained", alive == 0 and not policy.has_tick_work(event.tick), alive)
            local fulgora=state.surfaces.fulgora
            local port=spawn(fulgora,"roboport",{1800,1800},"player")
            port.energy=100000000
            port.get_inventory(defines.inventory.roboport_robot).insert{name="construction-robot",count=5}
            spawn(fulgora,"storage-chest",{1810,1800},"player")
            local robot_vault=spawn(fulgora,"fulgoran-ruin-vault",{1820,1800},"neutral")
            check("robot-vault-deconstruction-ordered",robot_vault.order_deconstruction("player"))
            local gaia=state.surfaces.gaia
            local settings=gaia.map_gen_settings
            settings.property_expression_names.elevation="0"
            gaia.map_gen_settings=settings
            state.old_gaia_index=gaia.index
            gaia_model.reforge_gaia_surface(event)
        elseif age > 30 and not state.complete and not storage.ei.reforge_gaia and state.robot_mined then
            local gaia=game.planets.gaia.surface
            check("actual-reforge-replaced-surface",gaia and gaia.index~=state.old_gaia_index)
            local settings=gaia.map_gen_settings
            check("actual-reforge-preserves-settings",settings.autoplace_controls[config.gaia_control].size==0
                and settings.seed==421337 and settings.no_enemies_mode and settings.peaceful_mode
                and settings.cliff_settings.cliff_elevation_interval==123)
            check("robot-guardian-removed",not state.robot_guardian or not state.robot_guardian.valid)
            state.complete=true
            helpers.write_file("planet-enemies-runtime.json", helpers.table_to_json{all_pass=state.all_pass,checks=state.checks,reloaded=state.reloaded or false}, false)
            log("PLANET_ENEMY_QC COMPLETE " .. tostring(state.all_pass))
        end
    end)
end

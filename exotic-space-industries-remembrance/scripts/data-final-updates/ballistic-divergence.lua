--==============================================================================
-- ESIR FILE MAP
-- owns: native ballistic payload conversion, flight coverage and terrain floors
-- loaded_by: data-final-fixes.lua, after fleet finalization and before spider probes
-- cadence: data stage once; no runtime handlers, storage or scripted damage
--==============================================================================
-- blueprint: .codex/esir/blueprints/combat-doctrines.md#contract
-- Independently implemented ESIR combat doctrines; concept credit: DataCpt.
local config = require("lib/ballistic-divergence-config")
local ei_lib = require("lib/lib")
local doctrine, enabled = config.resolve(), config.enabled()
local aliases, exclusions = {}, {}
local consumers = {bullet={}, ["shotgun-shell"]={}}
local uniform_bullets = true
local quality_range = 1
for _, quality in pairs(data.raw.quality or {}) do
    quality_range = math.max(quality_range, quality.range_multiplier or math.min(1 + 0.1 * quality.level, 3))
end

-- These visitors are specific to native trigger structure, not generic table utilities.
---@param value table|nil
---@return table[]
local function entries(value)
    if not value then return {} end
    return value.type and {value} or value
end

---@param attack table
---@param category string
---@return boolean
local function accepts(attack, category)
    return attack.ammo_category == category or ei_lib.table_contains_value(attack.ammo_categories or {}, category)
end

---@param attack table
---@return number
local function muzzle_allowance(attack)
    local center = attack.projectile_center or {0,0}
    local x, y = center.x or center[1] or 0, center.y or center[2] or 0
    local offset = 0
    for _, vector in ipairs(attack.projectile_creation_offsets or {}) do
        offset = math.max(offset, math.sqrt((vector.x or vector[1] or 0)^2 + (vector.y or vector[2] or 0)^2))
    end
    for _, parameter in ipairs(attack.projectile_creation_parameters or {}) do
        local vector = parameter[2] or {}
        offset = math.max(offset, math.sqrt((vector.x or vector[1] or 0)^2 + (vector.y or vector[2] or 0)^2))
    end
    return 2 + math.sqrt(x*x+y*y) + math.abs(attack.projectile_creation_distance or 0) + offset
end

---@param prototype table
---@param source_type string
local function register_shooter(prototype, source_type)
    local attack = prototype.attack_parameters
    if not attack then return end
    for category, list in pairs(consumers) do
        if accepts(attack, category) then
            local margin = muzzle_allowance(attack)
            list[#list+1] = {attack=attack, source_type=source_type, margin=margin}
        end
    end
end
for _, gun in pairs(data.raw.gun or {}) do register_shooter(gun, "player") end
-- Guns also serve cars and spider mounts. Include both source branches without
-- raising any attack range or exposing hidden gun/item/technology prototypes.
for _, gun in pairs(data.raw.gun or {}) do register_shooter(gun, "vehicle") end
for _, turret in pairs(data.raw["ammo-turret"] or {}) do register_shooter(turret, "turret") end

---@param category string
---@param kind table
---@param attack table|nil Inline robot attack parameters.
---@param original_range number
---@return number
local function flight_baseline(category, kind, attack, original_range)
    local baseline = math.max(category == "bullet" and 30 or 0, original_range or 0)
    if attack then
        return math.max(baseline, (attack.range or 0) * (kind.range_modifier or 1) * quality_range + muzzle_allowance(attack))
    end
    for _, consumer in ipairs(consumers[category]) do
        -- The engine falls back to the first source branch when no exact match
        -- exists. Cover every compatible consumer conservatively for each branch.
            baseline = math.max(baseline, (consumer.attack.range or 0) * (kind.range_modifier or 1)
                * quality_range + consumer.margin)
    end
    return baseline
end

---@param effects table|nil
---@return boolean
local function has_script(effects)
    if type(effects) ~= "table" then return false end
    if effects.type == "script" then return true end
    for _, value in pairs(effects) do
        if type(value) == "table" and has_script(value) then return true end
    end
    return false
end

---@param kind table
---@return boolean
local function supported(kind, category)
    if not kind.action or kind.target_filter then return false end
    for _, action in ipairs(entries(kind.action)) do
        if action.type ~= "direct" or action.entity_flags or action.trigger_target_mask or action.collision_mask
            or (action.force and action.force ~= "all") then return false end
        for _, delivery in ipairs(entries(action.action_delivery)) do
            if delivery.type ~= "instant" and delivery.type ~= "projectile" then return false end
            if has_script(delivery.target_effects) then return false end
            if delivery.type == "projectile" and not data.raw.projectile[delivery.projectile] then return false end
            if delivery.type == "instant" and delivery.target_effects and category == "shotgun-shell" then return false end
        end
    end
    return true
end

---@param delivery table
---@param category string
---@return number
local function range_deviation(delivery, category)
    return category == "bullet" and 0.40 * doctrine.scatter
        or (delivery.range_deviation or 0) * doctrine.shotgun_variation
end

---@param effects table|nil
---@return number
local function physical_damage(effects)
    local total = 0
    for _, effect in ipairs(entries(effects)) do
        if effect.type == "damage" and effect.damage.type == "physical" then total = total + effect.damage.amount end
    end
    return total
end

---@param id string
---@param effects table
---@param ammo_name string
---@return data.ProjectilePrototype
local function bullet_projectile(id, effects, ammo_name)
    local color = {r=1, g=0.85, b=0.55}
    -- Curated ammunition palettes come from its authored source flash, not its id.
    local flash = data.raw.explosion[ammo_name.."-source-flash"]
    if flash and flash.light and flash.light.color then color = table.deepcopy(flash.light.color)
    elseif ammo_name == "uranium-rounds-magazine" then color = {r=0.4,g=1,b=0.3} end
    return {
        type="projectile", name=id, flags={"not-on-map"}, hidden=true,
        collision_box={{-0.05,-0.25},{0.05,0.25}}, acceleration=0, direction_only=true,
        force_condition="not-same", hit_at_collision_position=true,
        hit_collision_mask={layers={object=true,player=true,trigger_target=true,train=true},not_colliding_with_itself=true},
        piercing_damage=(ammo_name == "piercing-rounds-magazine" or ammo_name == "uranium-rounds-magazine")
            and 25 * physical_damage(effects) or 0,
        action={type="direct",action_delivery={type="instant",target_effects=table.deepcopy(effects)}},
        animation={filename="__base__/graphics/entity/bullet/bullet.png",width=3,height=50,frame_count=1,
            priority="high",blend_mode="additive",tint=color},
    }
end

-- blueprint-ref: .codex/esir/blueprints/combat-doctrines.md#payloads
-- Preserve launch gates/multiplicity and source effects in place. Each delivery
-- owns one impact payload; copying action repeat_count into impact would square it.
---@param owner string
---@param category string
---@param kind table
---@param branch integer
---@param attack table|nil
---@return boolean changed
---@return boolean all_supported
local function transform_kind(owner, category, kind, branch, attack)
    if not supported(kind, category) then
        exclusions[owner..":"..branch] = true
        if category == "bullet" then uniform_bullets = false end
        return false, false
    end
    -- An external pellet cone can exceed the native travel interval under a
    -- doctrine. Preserve the whole branch, but still declare its saved helpers.
    local valid_range = true
    for _, action in ipairs(entries(kind.action)) do
        for _, delivery in ipairs(entries(action.action_delivery)) do
            local deviation = range_deviation(delivery, category)
            if deviation < 0 or deviation >= 2 then valid_range = false end
        end
    end
    if enabled and not valid_range then exclusions[owner..":"..branch] = true end
    local changed = false
    for ai, action in ipairs(entries(kind.action)) do
        for di, delivery in ipairs(entries(action.action_delivery)) do
            local id = "ei-ballistic-divergence-"..owner.."-"..branch.."-"..ai.."-"..di
            local projectile
            if delivery.type == "instant" and delivery.target_effects and category == "bullet" then
                projectile = bullet_projectile(id, delivery.target_effects, owner)
            elseif delivery.type == "projectile" then
                projectile = table.deepcopy(data.raw.projectile[delivery.projectile])
                projectile.name, projectile.hidden = id, true
                projectile.force_condition = "not-same"
                if category == "bullet" then projectile.direction_only = true end
                if category == "bullet" and (delivery.starting_speed ~= 1 or (delivery.starting_speed_deviation or 0) ~= 0
                    or (projectile.acceleration or 0) ~= 0 or (projectile.max_speed or 1) < 1) then uniform_bullets = false end
            end
            if projectile then
                aliases[#aliases+1] = projectile
                if enabled and valid_range then
                    local deviation = range_deviation(delivery, category)
                    delivery.max_range = flight_baseline(category, kind, attack,
                        delivery.max_range or (delivery.type == "projectile" and 1000 or 0))
                        * doctrine.flight / (1 - deviation / 2)
                    delivery.range_deviation = deviation
                    if category == "bullet" then
                        delivery.direction_deviation = 0.16 * doctrine.scatter
                        if delivery.type == "instant" then delivery.starting_speed = 1 end
                    end
                    if delivery.type == "instant" then delivery.target_effects = nil end
                    delivery.type, delivery.projectile = "projectile", id
                    changed = true
                end
            end
        end
    end
    if changed and category == "bullet" then kind.target_type = "direction" end
    return changed, valid_range
end

---@param owner string
---@param category string
---@param ammo_types table
---@param attack table|nil
---@return boolean all_supported
local function transform_types(owner, category, ammo_types, attack)
    local all_supported = true
    local kinds = ammo_types.action and {ammo_types} or ammo_types
    for index, kind in ipairs(kinds) do
        local _, branch_supported = transform_kind(owner, category, kind, index, attack)
        if not branch_supported then all_supported = false end
    end
    return all_supported
end

for name, ammo in pairs(data.raw.ammo or {}) do
    if consumers[ammo.ammo_category] and ammo.ammo_type then
        local all_supported = transform_types(name, ammo.ammo_category, ammo.ammo_type)
        if enabled and all_supported and ammo.ammo_category == "bullet" then
            ammo.magazine_size = math.max(1, math.ceil((ammo.magazine_size or 1) * doctrine.magazine))
        end
    end
end
local robot_leading = {}
for name, robot in pairs(data.raw["combat-robot"] or {}) do
    local attack = robot.attack_parameters
    if attack and accepts(attack, "bullet") and attack.ammo_type then
        local own_uniform = true
        for _, kind in ipairs(attack.ammo_type.action and {attack.ammo_type} or attack.ammo_type) do
            for _, action in ipairs(entries(kind.action)) do
                for _, delivery in ipairs(entries(action.action_delivery)) do
                    if delivery.type == "projectile" then
                        local p = data.raw.projectile[delivery.projectile]
                        if delivery.starting_speed ~= 1 or (delivery.starting_speed_deviation or 0) ~= 0
                            or not p or (p.acceleration or 0) ~= 0 or (p.max_speed or 1) < 1 then own_uniform = false end
                    end
                end
            end
        end
        if transform_types("robot-"..name, "bullet", attack.ammo_type, attack) and own_uniform then
            robot_leading[#robot_leading+1] = attack
        end
    end
end
-- All helper identities exist even when disabled. The data stage rebuild leaves
-- original references untouched in that mode, while active saved projectiles load.
data:extend(aliases)

if enabled then
    for _, attack in ipairs(robot_leading) do
        if not attack.lead_target_for_projectile_speed or attack.lead_target_for_projectile_speed == 0 then
            attack.lead_target_for_projectile_speed = 1
        end
    end
end
if enabled and uniform_bullets then
    for _, consumer in ipairs(consumers.bullet) do
        local attack = consumer.attack
        if (not attack.ammo_categories or #attack.ammo_categories == 1)
            and (not attack.lead_target_for_projectile_speed or attack.lead_target_for_projectile_speed == 0)
            then attack.lead_target_for_projectile_speed = 1 end
    end
end

---@param prototype table
---@param flat number
---@param percent number
local function resistance_floor(prototype, flat, percent)
    prototype.resistances = prototype.resistances or {}
    for _, resistance in ipairs(prototype.resistances) do
        if resistance.type == "physical" then
            resistance.decrease = math.max(resistance.decrease or 0, flat)
            resistance.percent = math.max(resistance.percent or 0, percent)
            return
        end
    end
    prototype.resistances[#prototype.resistances+1] = {type="physical",decrease=flat,percent=percent}
end
if enabled and doctrine.terrain then
    for _, tree in pairs(data.raw.tree or {}) do resistance_floor(tree, 2, 65) end
    for name, rock in pairs(data.raw["simple-entity"] or {}) do
        if rock.count_as_rock_for_filtered_deconstruction or ei_lib.contains(name, "rock") then
            resistance_floor(rock, 4, 75)
        end
    end
end
local skipped = {}
for owner in pairs(exclusions) do skipped[#skipped+1] = owner end
table.sort(skipped)
if #skipped > 0 then log("Ballistic Divergence preserved unsupported branches: "..table.concat(skipped, ", ")) end

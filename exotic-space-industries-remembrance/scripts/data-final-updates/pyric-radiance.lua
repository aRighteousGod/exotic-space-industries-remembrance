--==============================================================================
-- ESIR FILE MAP
-- owns: bounded thermal and combat illumination on final effect prototypes
-- loaded_by: data-final-fixes.lua, after fuel/performance aliases and ballistics
-- cadence: data stage once; native visual effects only, no runtime state
--==============================================================================
-- blueprint: .codex/esir/blueprints/combat-doctrines.md#contract
-- Independently implemented ESIR presentation doctrines; concept credit: DataCpt.
local config = require("lib/pyric-radiance-config")
local ei_lib = require("lib/lib")
local fuels = require("lib/flamethrower-fuels")
local doctrine, enabled = config.resolve(), config.enabled()
local warm = {r=1,g=0.65,b=0.3}
local fire_colors, sticker_colors, stream_colors = {}, {}, {}
for name in pairs(fuels.ground_fires) do fire_colors[name] = warm end
fire_colors["fire-flame-on-tree"] = warm
for name in pairs(fuels.fire_stickers) do sticker_colors[name] = warm end
for _, name in ipairs{"flamethrower-fire-stream", "handheld-flamethrower-fire-stream", "tank-flamethrower-fire-stream",
    "ei-thrower-performance-flamethrower-fire-stream"} do stream_colors[name] = warm end
for _, fuel in ipairs(fuels.fuels) do
    local color = {r=fuel.flame[1],g=fuel.flame[2],b=fuel.flame[3]}
    for _, kind in ipairs{"ammo", "turret"} do
        fire_colors["ei-flame-"..fuel.id.."-"..kind.."-fire"] = color
        sticker_colors["ei-flame-"..fuel.id.."-"..kind.."-sticker"] = color
    end
    for _, suffix in ipairs{"flamethrower-fire-stream", "handheld-flamethrower-fire-stream", "tank-flamethrower-fire-stream"} do
        stream_colors["ei-flame-"..fuel.id.."-"..suffix] = color
    end
end

---@param light table|nil
---@param multiplier number
---@param fallback_size number
---@param intensity number
---@param color table
---@return table
local function illuminate(light, multiplier, fallback_size, intensity, color)
    if light and light[1] then
        local result = {}
        for index, member in ipairs(light) do result[index] = illuminate(member, multiplier, fallback_size, intensity, color) end
        return result
    end
    local result = table.deepcopy(light or {size=fallback_size,intensity=intensity,color=table.deepcopy(color),minimum_darkness=0.25})
    result.size = math.min(64, (result.size or fallback_size) * multiplier)
    result.intensity = ei_lib.clamp(result.intensity or intensity, 0, 1)
    return result
end

---@param node table|nil
---@return table|nil
local function authored_color(node)
    if type(node) ~= "table" then return nil end
    if node.tint then return node.tint end
    for _, child in pairs(node) do
        if type(child) == "table" then
            local color = authored_color(child)
            if color then return color end
        end
    end
end

-- blueprint-ref: .codex/esir/blueprints/combat-doctrines.md#thermal
-- Stickers have no native light property. Native cooldown effects provide actual
-- terrain illumination, without changing sticker lifetime or damage_interval.
local helpers = {}
for name, color in pairs(sticker_colors) do
    if data.raw.sticker[name] then
        local id = "ei-pyric-radiance-"..name
        helpers[#helpers+1] = {
            type="explosion", name=id, flags={"not-on-map"}, hidden=true,
            animations={filename="__core__/graphics/empty.png",width=1,height=1,frame_count=1,animation_speed=1/12},
            light={size=enabled and math.min(64,10*doctrine.fire) or 0,intensity=enabled and 0.3 or 0,
                color=table.deepcopy(color),minimum_darkness=0.25},
            light_intensity_factor_initial=1,light_intensity_factor_final=1,
            light_intensity_peak_start_progress=0,light_intensity_peak_end_progress=1,
            light_size_factor_initial=1,light_size_factor_final=1,light_size_peak_start_progress=0,light_size_peak_end_progress=1,
        }
        if enabled and doctrine.fire > 0 then
            local sticker = data.raw.sticker[name]
            sticker.update_effects = sticker.update_effects or {}
            sticker.update_effects[#sticker.update_effects+1] = {time_cooldown=12,
                effect={type="create-explosion",entity_name=id,only_when_visible=true,show_in_tooltip=false}}
        end
    end
end
for _, name in ipairs{"atomic-rocket", "ei-atomic-rocket-u235"} do
    if data.raw.projectile[name] then
        helpers[#helpers+1] = {
            type="explosion", name="ei-pyric-radiance-"..name.."-flash", flags={"not-on-map"}, hidden=true,
            animations={filename="__core__/graphics/empty.png",width=1,height=1,frame_count=1,animation_speed=1/30},
            light={size=enabled and math.min(64,48*doctrine.nuclear) or 0,intensity=enabled and math.min(1,0.8*doctrine.nuclear) or 0,
                color=name == "atomic-rocket" and {r=1,g=1,b=1} or {r=1,g=0.92,b=0.6}},
            light_intensity_factor_initial=1,light_intensity_factor_final=0,
            light_size_factor_initial=1,light_size_factor_final=1,
        }
    end
end
data:extend(helpers)
if not enabled then return end

if doctrine.fire > 0 then
    for name, color in pairs(fire_colors) do
        local fire = data.raw.fire[name]
        if fire then
            local power = math.min(math.abs(fire.damage_per_tick and fire.damage_per_tick.amount or 0) / 1.7, 1)
            fire.light = illuminate(fire.light, doctrine.fire, 19+18*power, 0.4+1.2*power, color)
        end
    end
    for name, color in pairs(stream_colors) do
        local stream = data.raw.stream[name]
        if stream then
            stream.stream_light = illuminate(stream.stream_light, doctrine.fire, 4, 0.3, color)
            stream.ground_light = illuminate(stream.ground_light, doctrine.fire, 6, 0.4, color)
        end
    end
    for name, turret in pairs(data.raw["fluid-turret"] or {}) do
        if name == fuels.base_turret or fuels.by_turret[name] then
            local fuel = fuels.by_turret[name]
            local color = fuel and {r=fuel.flame[1],g=fuel.flame[2],b=fuel.flame[3]} or warm
            turret.muzzle_light = illuminate(turret.muzzle_light, doctrine.muzzle, 5, 0.4, color)
        end
    end
end

---@param node table|nil
---@param scale number|nil
---@return number Rendered width in tiles, including nested animation layers.
local function rendered_width(node, scale)
    if type(node) ~= "table" then return 0 end
    local inherited = (scale or 1) * (node.scale or 1)
    local size = type(node.size) == "table" and node.size[1] or node.size
    local width = (node.width or size or 0) * inherited / 32
    for key, child in pairs(node) do
        if type(child) == "table" and (type(key) == "number" or key == "layers" or key == "stripes") then
            width = math.max(width, rendered_width(child, inherited))
        end
    end
    return width
end

local explosions = {"explosion", "big-explosion", "medium-explosion", "massive-explosion", "grenade-explosion",
    "ground-explosion", "big-artillery-explosion", "uranium-cannon-explosion", "uranium-cannon-shell-explosion"}
for _, name in ipairs(explosions) do
    local effect = data.raw.explosion[name]
    if effect and doctrine.explosion > 0 then
        effect.light = illuminate(effect.light, doctrine.explosion, 5.5+5*rendered_width(effect.animations), 0.6,
            authored_color(effect.animations) or warm)
    end
end
for _, name in ipairs{"explosion-gunshot", "explosion-gunshot-small", "artillery-cannon-muzzle-flash"} do
    local effect = data.raw.explosion[name]
    if effect and doctrine.muzzle > 0 then
        effect.light = illuminate(effect.light, doctrine.muzzle, 5.5+5*rendered_width(effect.animations), 0.6, warm)
    end
end
if doctrine.impact then
    local effect = data.raw.explosion["explosion-hit"]
    if effect then effect.light = illuminate(effect.light, doctrine.explosion, 5, 0.4, warm) end
end

-- A finite ordinary-effect registry leaves authored energy/contact/death effects
-- and exotic ammunition flashes/bursts with their existing owners and palettes.
local projectiles = {}
for _, name in ipairs{"rocket", "explosive-rocket", "atomic-rocket", "ei-atomic-rocket-u235", "grenade", "cluster-grenade", "cannon-projectile",
    "explosive-cannon-projectile", "uranium-cannon-projectile", "explosive-uranium-cannon-projectile",
    "shotgun-pellet", "piercing-shotgun-pellet", "ei-uranium-shotgun-pellet", "ei-dragons-breath-shotgun-pellet"} do
    projectiles[name] = true
end
for name in pairs(data.raw.projectile) do
    if ei_lib.startswith(name, "ei-ballistic-divergence-") then projectiles[name] = true end
end
if doctrine.projectile > 0 then
    for name in pairs(projectiles) do
        local projectile = data.raw.projectile[name]
        if projectile then
            local color = authored_color(projectile.animation) or warm
            projectile.light = illuminate(projectile.light, doctrine.projectile, 5, 0.4, color)
        end
    end
end
for _, silo in pairs(data.raw["rocket-silo"] or {}) do
    if silo.base_engine_light then
        silo.base_engine_light = illuminate(silo.base_engine_light, doctrine.explosion, 25, 1, warm)
    end
end
for _, rocket in pairs(data.raw["rocket-silo-rocket"] or {}) do
    if rocket.glow_light then rocket.glow_light = illuminate(rocket.glow_light, doctrine.explosion, 30, 1, warm) end
end

-- One extra native flash at the direct impact, outside the repeated blast waves.
-- The original camera effect, strength and duration remain untouched.
if doctrine.nuclear > 0 then
    for _, name in ipairs{"atomic-rocket", "ei-atomic-rocket-u235"} do
        local projectile = data.raw.projectile[name]
        local actions = projectile and projectile.action
        for _, action in ipairs(actions and (actions.type and {actions} or actions) or {}) do
            local deliveries = action.type == "direct" and action.action_delivery
            for _, delivery in ipairs(deliveries and (deliveries.type and {deliveries} or deliveries) or {}) do
                local effects = delivery.target_effects
                if effects then
                    for _, effect in ipairs(effects) do
                        if effect.type == "camera-effect" then
                            effects[#effects+1] = {type="create-explosion",entity_name="ei-pyric-radiance-"..name.."-flash",show_in_tooltip=false}
                            break
                        end
                    end
                end
            end
        end
    end
end

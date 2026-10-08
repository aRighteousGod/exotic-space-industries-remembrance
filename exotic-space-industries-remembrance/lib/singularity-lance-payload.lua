-- blueprint: .codex/esir/blueprints/singularity-lance.md#contract
-- Shared packet mechanics only. Callers own payment, contexts, deadlines and
-- presentation. Telemetry adapters are bound at load, never stored in storage.
local lib = require("lib/lib")
local c = require("lib/singularity-lance-config")
local module = {}

---@param count function
---@param profile_start function
---@param profile_end function
---@return table
function module.new(count, profile_start, profile_end)
-- Diplomacy is read at every packet, never cached across ticks.
---@param entity LuaEntity? Engine query results or already validated event/queued references.
---@param force LuaForce?
---@param selection_forces table<integer,boolean>?
local function hostile(entity, force, selection_forces)
    if not entity or not entity.valid or not force or not force.valid then return false end
    local health = entity.health
    if not health or health <= 0 or not entity.destructible then return false end
    local other = entity.force
    local index = other.index
    -- Selection runs without damage callbacks: diplomacy is stable within this
    -- single query. Actual damage always rechecks it without this scratch cache.
    if selection_forces and selection_forces[index] ~= nil then return selection_forces[index] end
    local allowed = index ~= force.index and other.name ~= "neutral" and force.name ~= "neutral"
        and not force.get_friend(other) and not other.get_friend(force)
        and not force.get_cease_fire(other) and not other.get_cease_fire(force)
    if selection_forces then selection_forces[index] = allowed end
    return allowed
end

local function damage(runtime, target, amount, force, source, primary)
    if amount <= 0 or not hostile(target, force) then return 0 end
    -- Internal packet references are LuaEntity-or-nil; generic event inputs are
    -- validated with ei_lib at entry, avoiding repeated protected calls per victim.
    if source and not source.valid then source = nil end
    if source and (source.surface ~= target.surface or source.force ~= force) then source = nil end
    local applied = target.damage(amount, force, c.damage_type, source)
    count(runtime, primary and "direct_damage_amount" or "secondary_damage_amount", applied)
    count(runtime, primary and "direct_damage_applied" or "secondary_packets")
    return applied
end

local function nearer(a, b)
    if a.distance ~= b.distance then return a.distance < b.distance end
    if a.id ~= b.id then return a.id < b.id end
    if a.x ~= b.x then return a.x < b.x end
    if a.y ~= b.y then return a.y < b.y end
    return a.name < b.name
end

local function candidate(entity, distance)
    local position = entity.position
    return {entity = entity, distance = distance, id = entity.unit_number or 0,
        x = position.x, y = position.y, name = entity.name}
end

---@param runtime LanceRuntime
---@param surface LuaSurface
---@param force LuaForce
---@param position MapPosition
---@param primary LuaEntity?
---@param source LuaEntity?
---@param amount number
---@param radius number
---@param cap integer
---@param packet LanceCollapse? Nil is ordinary splash; absent fields retain legacy behavior.
local function area_damage(runtime, surface, force, position, primary, source, amount, radius, cap, packet)
    count(runtime, "area_queries")
    local selected, selection_forces, reserved = {}, {}, nil
    for _, entity in pairs(surface.find_entities_filtered{position = position, radius = radius, is_military_target = true}) do
        if hostile(entity, force, selection_forces) then
            local p = entity.position
            local entry = candidate(entity, (p.x - position.x)^2 + (p.y - position.y)^2)
            if entity ~= primary then selected[#selected + 1] = entry
            elseif packet and packet.include_primary then reserved = entry end
        end
    end
    table.sort(selected, nearer)
    -- Membership is from this pulse's current-position query. The primary has
    -- its own slot, while each victim receives exactly one core-or-shell packet.
    local core_squared = packet and packet.core_radius and packet.core_radius^2
    if reserved then damage(runtime, reserved.entity,
        core_squared and reserved.distance <= core_squared and packet.core_damage or amount, force, source) end
    for index = 1, math.min(cap, #selected) do
        local entry = selected[index]
        damage(runtime, entry.entity, core_squared and entry.distance <= core_squared and packet.core_damage or amount, force, source)
    end
end

-- Clip an oriented collision box to the incision strip. Its first surviving
-- point determines victim order; projecting the whole box can put an off-ray
-- corner ahead of a nearer enemy. The broad-phase query is never the final test.
local function corridor_entry(entity, origin, ux, uy, length, half_width)
    local box = entity.bounding_box
    local left, right = box.left_top, box.right_bottom
    local bx, by = (left.x + right.x) / 2 - origin.x, (left.y + right.y) / 2 - origin.y
    local hx, hy = (right.x - left.x) / 2, (right.y - left.y) / 2
    local angle = (box.orientation or 0) * 2 * math.pi
    local ex, ey = math.cos(angle), math.sin(angle)
    local vx, vy = -uy, ux
    local along, across = bx * ux + by * uy, bx * vx + by * vy
    local along_extent = hx * math.abs(ex * ux + ey * uy) + hy * math.abs(-ey * ux + ex * uy)
    local across_extent = hx * math.abs(ex * vx + ey * vy) + hy * math.abs(-ey * vx + ex * vy)
    if along + along_extent < 0 or along - along_extent > length or math.abs(across) > half_width + across_extent then return end
    if angle == 0 and (ux == 0 or uy == 0) then return math.max(0, along - along_extent) end
    local ax, ay = hx * (ex * ux + ey * uy), hx * (ex * vx + ey * vy)
    local cx, cy = hy * (-ey * ux + ex * uy), hy * (-ey * vx + ex * vy)
    -- Keep the original corner arithmetic and edge order without allocating
    -- two four-element tables for every secondary-target geometry check.
    local x1,y1 = along-ax-cx,across-ay-cy
    local x2,y2 = along+ax-cx,across+ay-cy
    local x3,y3 = along+ax+cx,across+ay+cy
    local x4,y4 = along-ax+cx,across-ay+cy
    local first, last = math.huge, -math.huge
    for i = 1, 4 do
        local x,y,next_x,next_y
        if i == 1 then x,y,next_x,next_y = x1,y1,x2,y2
        elseif i == 2 then x,y,next_x,next_y = x2,y2,x3,y3
        elseif i == 3 then x,y,next_x,next_y = x3,y3,x4,y4
        else x,y,next_x,next_y = x4,y4,x1,y1 end
        if math.abs(y) <= half_width then first, last = math.min(first, x), math.max(last, x) end
        if y ~= next_y then
            for sign = -1, 1, 2 do
                local fraction = (sign * half_width - y) / (next_y - y)
                if fraction >= 0 and fraction <= 1 then
                    local intersection = x + fraction * (next_x - x)
                    first, last = math.min(first, intersection), math.max(last, intersection)
                end
            end
        end
    end
    if first <= length and last >= 0 then return math.max(0, first) end
end

---@param origin MapPosition
---@param aim MapPosition
---@param range number
---@return LanceRay[]
local function incision_rays(origin, aim, range, axial)
    local dx, dy = aim.x - origin.x, aim.y - origin.y
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 0.00001 then return {} end
    local ux, uy = dx / length, dy / length
    local reach = math.min(length + axial.reach, range)
    local rays = {{origin = origin, endpoint = {x = origin.x + ux * reach, y = origin.y + uy * reach},
        ux = ux, uy = uy, length = reach, half_width = axial.width / 2}}
    -- Native targeting may approve a bounding-box hit beyond the center range.
    -- Keep that direct hit, but do not grow branches from outside the circle.
    if length <= range then
        for sign = -1, 1, 2 do
            local bx, by = ux * axial.cos - sign * uy * axial.sin, uy * axial.cos + sign * ux * axial.sin
            local projection = dx * bx + dy * by
            local exit = -projection + math.sqrt(math.max(0, projection^2 + range^2 - length^2))
            local branch_reach = math.min(axial.branch.reach, exit)
            if branch_reach > 0.00001 then rays[#rays + 1] = {origin = aim,
                endpoint = {x = aim.x + bx * branch_reach, y = aim.y + by * branch_reach},
                ux = bx, uy = by, length = branch_reach, half_width = axial.branch.width / 2} end
        end
    end
    return rays
end

---@param runtime LanceRuntime
---@param rays LanceRay[]
---@param multiplier number
---@param paid LanceContact Snapshotted axial coefficients and victim caps.
---@param tick integer
local function penetrate(runtime, surface, source, force, primary, rays, multiplier, paid, tick)
    if not rays[1] then return end
    local profiler = profile_start(runtime)
    local central, branches, selection_forces = {}, {}, {}
    local min_x, min_y, max_x, max_y = math.huge, math.huge, -math.huge, -math.huge
    for _, ray in ipairs(rays) do
        local a, b, half = ray.origin, ray.endpoint, ray.half_width
        min_x, min_y = math.min(min_x, a.x - half, b.x - half), math.min(min_y, a.y - half, b.y - half)
        max_x, max_y = math.max(max_x, a.x + half, b.x + half), math.max(max_y, a.y + half, b.y + half)
    end
    count(runtime, "penetration_queries")
    for _, entity in pairs(surface.find_entities_filtered{area = {{min_x, min_y}, {max_x, max_y}}, is_military_target = true}) do
        if entity ~= primary and hostile(entity, force, selection_forces) then
            local ray = rays[1]
            local distance = corridor_entry(entity, ray.origin, ray.ux, ray.uy, ray.length, ray.half_width)
            if distance then central[#central + 1] = candidate(entity, distance)
            else
                -- Classify before capping: central eligibility never falls back
                -- to weaker branch damage, even when the central cap is full.
                local shortest
                for index = 2, #rays do
                    ray = rays[index]
                    distance = corridor_entry(entity, ray.origin, ray.ux, ray.uy, ray.length, ray.half_width)
                    if distance then shortest = math.min(shortest or distance, distance) end
                end
                if shortest then branches[#branches + 1] = candidate(entity, shortest) end
            end
        end
    end
    table.sort(central, nearer)
    table.sort(branches, nearer)
    profile_end(profiler, "incision-selection", tick)
    profiler = profile_start(runtime)
    for index = 1, math.min(paid.axial_cap, #central) do
        damage(runtime, central[index].entity, paid.axial.damage * multiplier, force, source)
        count(runtime, "central_packets")
    end
    for index = 1, math.min(paid.branch_cap, #branches) do
        damage(runtime, branches[index].entity, paid.axial.branch.damage * multiplier, force, source)
        count(runtime, "branch_packets")
    end
    profile_end(profiler, "incision-damage", tick)
end


---@param contact LanceContact
---@param target LuaEntity?
---@param force LuaForce
---@return LuaEntity?, number
local function resolve_primary(runtime, contact, target, force)
    local context = contact.context
    if context.target ~= contact.primary or not context.tick or contact.due - context.tick >= contact.wound_timeout
        or not hostile(target, force) or contact.level < 2 then
        context.target, context.tick, context.stacks = nil, nil, 0
    end
    local stacks = contact.level >= 2 and math.min(context.stacks + 1, contact.wound_cap) or 0
    -- Damage consumes the previously earned bonus; a positive result banks the
    -- next stack. Old paid contacts lack this snapshot and retain their +20% start.
    local bonus_stacks = contact.level >= 2
        and math.min(context.stacks + (contact.wound_first_hit_stacks or 1), contact.wound_cap) or 0
    local amount = contact.direct_damage * (1 + bonus_stacks * contact.wound_step)
        * contact.primary_multiplier
    local source = lib.get_valid_entity(contact.source)
    if source and source.force ~= force then source = nil end
    local applied = damage(runtime, target, amount, force, source, true)
    if applied > 0 and contact.level >= 2 then
        context.target, context.tick, context.stacks = contact.primary, contact.due, stacks
        contact.wound_updated = true
    end
    return source, applied
end

return {hostile = hostile, damage = damage, area_damage = area_damage,
    incision_rays = incision_rays, penetrate = penetrate, resolve_primary = resolve_primary}
end

-- A contact's owner decides when it is committed. Once built, positions and
-- coefficients belong to the packet, independently of the source's lifecycle.
---@param contact LanceContact
---@param values table
---@param delay integer
---@param echo_values table?
---@return LanceCollapse
function module.collapse_packet(contact, values, delay, echo_values)
    local packet = {force_index = contact.force_index, surface_index = contact.surface_index,
        position = contact.position, primary = contact.primary, source = contact.source,
        damage = values.damage * contact.multiplier, radius = values.radius, cap = values.cap,
        testament = contact.testament, include_primary = true,
        core_damage = values.core_damage * contact.multiplier, core_radius = values.core_radius,
        phase = "first", due = contact.due + delay}
    if echo_values then
        packet.echo = {force_index = contact.force_index, surface_index = contact.surface_index,
            position = contact.position, primary = contact.primary, source = contact.source,
            damage = echo_values.damage * contact.multiplier, radius = echo_values.radius,
            cap = echo_values.cap, testament = true, include_primary = true,
            phase = "echo", due = contact.due + echo_values.delay}
    end
    return packet
end
return module

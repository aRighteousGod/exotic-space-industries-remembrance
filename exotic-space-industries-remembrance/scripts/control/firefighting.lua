--==============================================================================
-- ESIR FILE MAP
-- owns: impact-only fire removal for integrated handheld and water turret
-- loaded_by: control.lua, control/water-turret
-- cadence: private impact effects only; no polling or persistent state
-- forwarded_events: on_script_trigger_effect, on_trigger_created_entity, cleanup_legacy
-- storage_roots: none
--==============================================================================
local ei_lib = require("lib/lib")
local config = require("lib/firefighting-config")
local flames = require("lib/flamethrower-fuels")
local model = {}
model.effects = {config.handheld_effect, config.protect_effect, config.all_effect}

---@param fire LuaEntity?
---@param weapon_fires boolean
---@return boolean
function model.eligible(fire, weapon_fires)
    return ei_lib.entity_check(fire) and fire.type=="fire"
        and (config.thermal_fires[fire.name]==true or (weapon_fires and flames.ground_fires[fire.name]==true))
end

---@param surface LuaSurface
---@param position MapPosition
---@param handheld boolean Original handheld deliberately removes all fire entities, including acid.
---@param weapon_fires boolean?
function model.suppress(surface, position, handheld, weapon_fires)
    local filter = handheld and {area={{position.x-1,position.y-1},{position.x+1,position.y+1}},type="fire"}
        or {position=position,radius=config.radius,type="fire"}
    for _,fire in pairs(surface.find_entities_filtered(filter)) do
        if (handheld and ei_lib.entity_check(fire)) or (not handheld and model.eligible(fire,weapon_fires==true)) then fire.destroy() end
    end
end

---@param event EventData.on_script_trigger_effect
function model.on_script_trigger_effect(event)
    local surface = game.get_surface(event.surface_index)
    local position = event.target_position
    if not (surface and position) then return end
    model.suppress(surface,position,event.effect_id==config.handheld_effect,event.effect_id==config.all_effect)
end

---@param event EventData.on_trigger_created_entity
function model.on_trigger_created_entity(event)
    local marker = ei_lib.get_valid_entity(event.entity)
    if not marker or marker.name~="extinguisher-remnants" then return end
    local surface,position = marker.surface,marker.position
    marker.destroy()
    model.suppress(surface,position,true)
end

function model.cleanup_legacy()
    -- Saved stale markers are visual residue, not new impacts.
    for _,surface in pairs(game.surfaces) do
        for _,marker in pairs(surface.find_entities_filtered{name="extinguisher-remnants"}) do marker.destroy() end
    end
end
return model

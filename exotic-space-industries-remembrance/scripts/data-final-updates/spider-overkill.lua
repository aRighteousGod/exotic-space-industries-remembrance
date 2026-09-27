--==============================================================================
-- ESIR FILE MAP
-- owns: conservative spider impact profiles and observational ammunition hooks
-- loaded_by: data-final-fixes.lua, after ammunition and spider compatibility
-- cadence: data-final-fixes once; no damage or delivery replacement
-- forwarded_events: none
-- storage_roots: none
-- rebuild_on: startup settings / final ammunition prototypes
--==============================================================================
local catalog=require("lib/spider-vehicles")
local spec=catalog.overkill
local profiles={}
local effects={}
local probes={bullet=true,flamethrower=true}
local categories={["cannon-shell"]=true,["artillery-shell"]=true,rocket=true,["dw-deer-ammo"]=true,bullet=true,flamethrower=true}

---@param value table?
---@return table[]
local function entries(value)
    if not value then return {} end
    return value.type and {value} or value
end

-- Only guaranteed immediate damage is credited. Scripts, spawned entities,
-- stickers, delayed waves, probabilistic effects and branching deliveries are
-- deliberately absent from the estimate, but remain in the native action.
local read_actions
local function read_effects(effects,parts,radius,multiplier)
    for _,effect in ipairs(entries(effects)) do
        if (effect.probability or 1)==1 and (effect.repeat_count_deviation or 0)==0 and not effect.damage_type_filters and
            effect.force~="same" and effect.force~="friend" then
            local count=multiplier*(effect.repeat_count or 1)
            if effect.type=="damage" and effect.damage and (effect.damage.amount or 0)>0 and
                not effect.lower_distance_threshold and not effect.upper_distance_threshold then
                parts[#parts+1]={amount=effect.damage.amount,count=count,type=effect.damage.type,radius=radius,
                    ignore_modifiers=effect.ignore_damage_modifiers or false}
            elseif effect.type=="nested-result" then read_actions(effect.action,parts,radius,count) end
        end
    end
end
read_actions=function(actions,parts,radius,multiplier)
    for _,action in ipairs(entries(actions)) do
        if (action.probability or 1)==1 and (action.type=="direct" or action.type=="area") and action.target_entities~=false and
            not action.trigger_target_mask and not action.entity_flags and action.force~="same" and action.force~="friend" then
            local reach=action.type=="area" and math.min(action.radius,radius or math.huge) or radius
            for _,delivery in ipairs(entries(action.action_delivery)) do
                if delivery.type=="instant" then read_effects(delivery.target_effects,parts,reach,(multiplier or 1)*(action.repeat_count or 1)) end
            end
        end
    end
end

---@param prototype table
---@param field string
---@param effect_id string
local function observe(prototype,field,effect_id)
    local actions=entries(prototype[field])
    actions[#actions+1]={type="direct",show_in_tooltip=false,
        action_delivery={type="instant",target_effects={{type="script",effect_id=effect_id,show_in_tooltip=false}}}}
    prototype[field]=actions
    effects[effect_id]=true
end

local hooked={}
if settings.startup["ei-spider-range-aware-cycling"].value then
    for name,ammo in pairs(data.raw.ammo) do
        if categories[ammo.ammo_category] then
            local kind=ammo.ammo_type
            if kind and not kind.action then
                local fallback
                for _,candidate in ipairs(kind) do
                    if candidate.source_type=="vehicle" then kind=candidate;break end
                    if candidate.source_type=="default" then fallback=candidate end
                end
                if not kind.action then kind=fallback end
            end
            local chosen,ambiguous
            for _,action in ipairs(entries(kind and kind.action)) do
                for _,delivery in ipairs(entries(action.action_delivery)) do
                    if delivery.type=="projectile" or delivery.type=="artillery" or delivery.type=="stream" then
                        if chosen or action.type~="direct" or (action.probability or 1)~=1 or (action.repeat_count or 1)~=1 then ambiguous=true end
                        chosen=delivery
                    end
                end
            end
            if kind and kind.action and probes[ammo.ammo_category] then
                -- These weapons reserve no damage. One observed failed native
                -- aiming attempt must still prevent repeated alternative probes.
                observe(kind,"action",spec.launch..name)
            elseif chosen and not ambiguous then
                local entity_type=chosen.type=="artillery" and "artillery-projectile" or chosen.type
                local payload_name=chosen.projectile or chosen.stream
                local payload=data.raw[entity_type][payload_name]
                local parts={}
                if payload then
                    -- A stream's nonempty initial_action replaces action for
                    -- its first (and here only) particle; never credit both.
                    local impact_field=entity_type=="stream" and next(entries(payload.initial_action)) and "initial_action" or "action"
                    read_actions(payload[impact_field],parts,nil,1)
                    local single=entity_type~="stream" or ((payload.particle_spawn_interval or 0)==0 and (payload.particle_spawn_timeout or 0)==0)
                    local speed=entity_type=="stream" and ((payload.particle_horizontal_speed or 0)-(payload.particle_horizontal_speed_deviation or 0)) or
                        ((chosen.starting_speed or 0)-(chosen.starting_speed_deviation or 0))
                    if #parts>0 and single and speed>0 and (payload.acceleration or 0)>=0 then
                        local id=entity_type..":"..payload_name
                        profiles[name]={category=ammo.ammo_category,parts=parts,payload=id,speed=speed,
                            acceleration=payload.acceleration or 0,max_speed=payload.max_speed or 0,
                            scatter=payload.target_position_deviation or 0,direction_deviation=chosen.direction_deviation or 0,
                            target_type=kind.target_type or "entity"}
                        -- A sibling instant delivery retains the engine's actual
                        -- target even for position/direction ammunition (2.0.77).
                        observe(kind,"action",spec.launch..name)
                        if not hooked[id] then
                            observe(payload,impact_field,spec.impact..id)
                            hooked[id]=true
                        end
                    end
                end
            end
        end
    end
end
data:extend({
    {type="mod-data",name=spec.profiles,data_type="esir.spider-impact-profiles",data=profiles},
    {type="mod-data",name=spec.profiles.."-effects",data_type="esir.spider-observation-effects",data=effects},
})

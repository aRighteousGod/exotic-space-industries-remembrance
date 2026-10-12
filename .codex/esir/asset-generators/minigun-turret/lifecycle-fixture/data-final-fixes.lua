-- Disposable helper owns instrumentation; it does not alter shipping prototypes.
local config = require("test-config")
local art = require("candidate-graphics-data")
local mechanical = require("candidate-mechanical-data")
local original = assert(data.raw["ammo-turret"]["ei-gatling-turret"])
local factory = require("__exotic-space-industries-remembrance__/prototypes/electricity-age/gatling-turret/graphics")
local candidate = table.deepcopy(original)
candidate.name, candidate.minable = "mg-lifecycle-candidate", nil
local graphics = factory.create(art, mods, {fixture=true, direction_count=256})
graphics.apply(candidate)
candidate.attack_parameters.projectile_creation_parameters = graphics.creation_parameters()
for _, key in ipairs({"projectile_center", "apply_projection_to_projectile_creation_position"}) do
    if mechanical[key] ~= nil then candidate.attack_parameters[key] = table.deepcopy(mechanical[key]) end
end
if mechanical.shell_particle then candidate.attack_parameters.shell_particle = table.deepcopy(mechanical.shell_particle) end
if mechanical.circuit_connector then candidate.circuit_connector = table.deepcopy(mechanical.circuit_connector) end
local legacy = table.deepcopy(original)
legacy.name, legacy.minable = "mg-lifecycle-legacy", nil

-- Enabled_states is native rendering state. A post-run pixel decoder proves
-- which phase the engine actually displayed when an intervention took effect.
for _, turret in ipairs({candidate, legacy}) do
    turret.graphics_set = turret.graphics_set or {}
    local visual = turret.graphics_set.base_visualisation or {}
    if visual.animation then visual = {visual} end
    turret.graphics_set.base_visualisation = visual
    for index, state in ipairs(config.states) do
        visual[#visual+1] = {enabled_states={state}, render_layer="object", secondary_draw_order=120,
            animation={filename="__zzz-esir-minigun-firing__/graphics/state-"..(index-1)..".png",
                width=64, height=12, frame_count=1, shift={0,3}, flags={"not-compressed"}}}
    end
end

local ammo = table.deepcopy(assert(data.raw.ammo["piercing-rounds-magazine"]))
ammo.name = "mg-lifecycle-ammo"
local before_ammo = table.deepcopy(ammo.ammo_type)
local kinds = ammo.ammo_type.action and {ammo.ammo_type} or ammo.ammo_type
local observers = 0
for _, kind in ipairs(kinds) do
    if not kind.source_type or kind.source_type == "default" or kind.source_type == "turret" then
        if kind.action.type then kind.action = {kind.action} end
        kind.action[#kind.action+1] = {type="direct",action_delivery={type="instant",
            source_effects={{type="script",effect_id="mg-lifecycle-shot"}}}}
        observers = observers + 1
    end
end
assert(observers == 1, "Expected one source-only observer for the selected native ammo")
local heater = table.deepcopy(assert(data.raw["heat-interface"]["heat-interface"]))
heater.name, heater.minable, heater.heating_radius = "mg-lifecycle-heater", nil, 6
local power = table.deepcopy(assert(data.raw["electric-energy-interface"]["electric-energy-interface"]))
power.name, power.minable = "mg-lifecycle-power", nil
power.energy_production, power.energy_usage = "100MW", "0W"
power.energy_source.buffer_capacity = "10MJ"
local empty = {filename="__core__/graphics/empty.png",width=1,height=1}
data:extend{candidate, legacy, ammo, heater, power, {type="simple-entity-with-owner",name="mg-lifecycle-target",
    icon="__base__/graphics/icons/wood.png",icon_size=64,max_health=1000000000,
    flags={"placeable-player","placeable-enemy"},is_military_target=true,
    collision_box={{-0.1,-0.1},{0.1,0.1}},selection_box={{-0.1,-0.1},{0.1,0.1}},picture=empty}}
local audit = {schema=1, lineage=config.lineage, original=original, candidate=candidate,
    original_ammo_type=before_ammo, instrumented_ammo_type=ammo.ammo_type,
    actual_profile=mods["minigun-turret-HD"] and "hd" or "sd",
    observer_count=observers, instrumentation="one private ammo source observer; damage delivery copied unchanged"}
data:extend{{type="mod-data",name="mg-lifecycle-prototype-audit",data=audit}}

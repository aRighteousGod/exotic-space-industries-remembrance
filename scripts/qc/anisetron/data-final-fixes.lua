local vehicle = assert(data.raw["spider-vehicle"]["ei-anisetron"])
local gun = assert(data.raw.gun["ei-anisetron-beam-gun"]).attack_parameters
local ammo = assert(data.raw.ammo["ei-anisetron-crystal-charge"])
local delivery = ammo.ammo_type.action.action_delivery
local beam = assert(data.raw.beam["ei-anisetron-beam"])
local trigger = assert(data.raw.beam["ei-anisetron-charge-trigger"])
local crown = assert(data.raw.beam["ei-anisetron-crown-beam"])
assert(not crown.action and not crown.action_triggered_automatically and crown.damage_interval==12)
assert(crown.width==beam.width*2)
assert(vehicle.graphics_set.animation.layers[1].direction_count==128)
assert(vehicle.graphics_set.shadow_animation.direction_count==128)
assert(data.raw.animation["ei-anisetron-movement-strand"])
assert(vehicle.energy_source.type=="void", "Cathedral movement power was rewritten")
assert(#vehicle.guns==1 and not vehicle.automatic_weapon_cycling)
assert(gun.type=="beam" and gun.ammo_category==ammo.ammo_category)
assert(gun.turn_range==1)
assert(delivery.type=="beam" and delivery.beam==trigger.name and delivery.duration==1)
assert(not beam.action_triggered_automatically and not beam.random_target_offset)
assert(not beam.action and beam.damage_interval==12)
assert(trigger.action.action_delivery.target_effects[1].effect_id=="ei-anisetron-charge")
assert(not trigger.action_triggered_automatically)
assert(beam.graphics_set.beam.body[1].layers[1].filename:find("singularity%-lance%-beam%-body"))
assert(gun.cooldown==1200 and gun.range==85 and ammo.magazine_size==1)
assert(gun.range_mode=="bounding-box-to-bounding-box")
assert(#ammo.custom_tooltip_fields==10)
assert(tonumber(ammo.custom_tooltip_fields[1].value[2])==20)
assert(tonumber(ammo.custom_tooltip_fields[2].value[2])==320)
assert(tonumber(ammo.custom_tooltip_fields[2].quality_values.rare[2])==512)
assert(tonumber(ammo.custom_tooltip_fields[3].value[2])==160)
assert(tonumber(ammo.custom_tooltip_fields[3].quality_values.rare[2])==256)
assert(tonumber(ammo.custom_tooltip_fields[4].value[2])==12)
assert(tonumber(ammo.custom_tooltip_fields[5].value[2])==2400)
assert(tonumber(ammo.custom_tooltip_fields[5].quality_values.rare[2])==3840)
assert(tonumber(ammo.custom_tooltip_fields[6].value[2])==360)
assert(tonumber(ammo.custom_tooltip_fields[7].value[2])==120)
assert(tonumber(ammo.custom_tooltip_fields[8].value[2])==85)
assert(tonumber(ammo.custom_tooltip_fields[9].value[2])==30)
local recipe=assert(data.raw.recipe["ei-anisetron"])
local charge=assert(data.raw.recipe["ei-anisetron-crystal-charge"])
local tech=assert(data.raw.technology["ei-anisetron"])
assert(recipe.energy_required==120 and charge.energy_required==10 and not recipe.enabled and not charge.enabled)
assert(recipe.surface_conditions[1].min==15.5 and recipe.surface_conditions[1].max==15.5)
assert(not charge.surface_conditions)
local unlocks={}
for _,effect in ipairs(tech.effects) do if effect.type=="unlock-recipe" then unlocks[effect.recipe]=true end end
assert(unlocks[recipe.name] and unlocks[charge.name])
local prerequisites={}
for _,name in ipairs(tech.prerequisites) do prerequisites[name]=true end
for _,name in ipairs{"ei-gaian-saucer","ei-crystal-accumulator","ei-computing-unit","ei-neodymium-magnet","ei-sus-plating","ei-high-energy-crystal","ei-electronic-parts","laser-weapons-damage-5","ei-singularity-lance"} do assert(prerequisites[name],name) end
for _,pack in ipairs(tech.unit.ingredients) do assert(pack[1]~="ei-quantum-age-tech" and pack[1]~="ei-exotic-age-tech") end
for _,technology in pairs(data.raw.technology) do
    for _,effect in ipairs(technology.effects or {}) do
        if effect.ammo_category==ammo.ammo_category then
            assert(effect.type=="ammo-damage" and (technology.name=="laser-weapons-damage-6" or technology.name=="laser-weapons-damage-7"))
            local lance_modifier
            for _,other in ipairs(technology.effects) do
                if other.type=="ammo-damage" and other.ammo_category=="ei-singularity-lance" then lance_modifier=other.modifier end
            end
            assert(effect.modifier==lance_modifier)
        end
    end
end
for _, anchor in ipairs(vehicle.spider_engine.legs) do
    local leg = assert(data.raw["spider-leg"][anchor.leg])
    assert(not leg.graphics_set and not next(leg.collision_mask.layers))
end
assert(vehicle.graphics_set.animation.layers[3].apply_runtime_tint)
log("ANISETRON_DATA_QC PASS shared-charge twin320/160,360/120degrees,128directions,action-free beams, private category, hidden anchors, mask, crafting and research")
for index=1,5 do data.raw["spider-vehicle"]["ei-anisetron-speed-"..index].energy_source={type="void"} end
-- Artist endpoint captures hide one channel's appearance only. Both action-free
-- entities and both real paid mechanical channels remain present and unchanged.
local qc_config=require("test-config")
if qc_config.visual and qc_config.isolate and qc_config.isolate~="all" then
    local hidden=qc_config.isolate=="crown" and beam or crown
    local empty=require("__core__/lualib/util").empty_sprite()
    hidden.graphics_set={beam={head=empty,tail=empty,body={empty}},
        ground={head=empty,tail=empty,body=empty}}
    hidden.light=nil;hidden.working_sound=nil
end

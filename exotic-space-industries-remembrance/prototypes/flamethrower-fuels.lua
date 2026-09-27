-- Fuel effects are native prototypes: runtime only changes the turret identity.
local catalog = require("lib/flamethrower-fuels")
local ei_lib = require("lib/lib")
local util = require("util")
local base_ammo = table.deepcopy(data.raw.ammo["flamethrower-ammo"])
local base_recipe = table.deepcopy(data.raw.recipe["flamethrower-ammo"])

-- Only animation leaves receive tint; shadows and unrelated tree fires stay native.
---@param animation table?
---@param color number[]
local function tint(animation,color)
    if type(animation)~="table" then return end
    if (animation.filename or animation.filenames or animation.stripes) and not animation.draw_as_shadow then
        animation.tint=color
        animation.tint_as_overlay=true
    end
    for _,value in pairs(animation) do if type(value)=="table" then tint(value,color) end end
end

---@param node table
---@param fuel ESIRFlameFuel
---@param prefix string
---@param multiplier number
local function effects(node,fuel,prefix,multiplier)
    if node.type=="damage" then node.damage.amount=node.damage.amount*multiplier end
    if node.type=="create-fire" and node.entity_name=="fire-flame" then node.entity_name=prefix.."-fire" end
    if node.type=="create-sticker" and node.sticker=="fire-sticker" then node.sticker=prefix.."-sticker" end
    if node.type=="create-trivial-smoke" and node.smoke_name=="fire-smoke-on-adding-fuel" then node.smoke_name="ei-flame-"..fuel.id.."-smoke" end
    for _,value in pairs(node) do if type(value)=="table" then effects(value,fuel,prefix,multiplier) end end
end

for index,fuel in ipairs(catalog.fuels) do
    local prefix="ei-flame-"..fuel.id
    local smoke=table.deepcopy(data.raw["trivial-smoke"]["soft-fire-smoke"])
    smoke.name=prefix.."-smoke"
    -- Match vanilla's premultiplied smoke tint and particle lifetime ceiling.
    -- Cleaner fractions dissipate faster; none emit more particles than vanilla.
    smoke.color=util.premul_color{fuel.smoke[1],fuel.smoke[2],fuel.smoke[3],fuel.smoke[4]*0.18}
    local density=fuel.id=="crude-oil" and 1 or math.min(1,fuel.smoke[4]/0.55)
    smoke.start_scale=smoke.start_scale*(0.7+0.3*density)
    smoke.end_scale=smoke.end_scale*(0.6+0.4*density)
    smoke.duration=math.floor(smoke.duration*(0.5+0.5*density)+0.5)
    if smoke.spread_delay then smoke.spread_delay=math.min(smoke.spread_delay,math.floor(smoke.duration/2)) end
    smoke.fade_away_duration=math.floor(smoke.duration*0.2+0.5)
    if fuel.id=="crude-oil" then smoke.color=table.deepcopy(data.raw["trivial-smoke"]["soft-fire-smoke"].color) end
    data:extend{smoke}
    -- Separate ammo/turret fire prototypes prevent applying a native turret bonus twice.
    for _,kind in ipairs{"ammo","turret"} do
        local effect_prefix=prefix.."-"..kind
        local multiplier=kind=="ammo" and fuel.damage or 1
        local fire=table.deepcopy(data.raw.fire["fire-flame"])
        fire.name=effect_prefix.."-fire"
        fire.localised_name={"entity-name.fire-flame"}
        fire.damage_per_tick.amount=fire.damage_per_tick.amount*multiplier
        for _,key in ipairs{"initial_lifetime","lifetime_increase_by","maximum_lifetime"} do
            fire[key]=math.floor(fire[key]*fuel.lifetime+0.5)
        end
        tint(fire.pictures,fuel.flame)
        if fire.light then fire.light.color=fuel.flame end
        for _,entry in pairs(fire.smoke or {}) do entry.name=smoke.name end
        if fire.on_fuel_added_action then effects(fire.on_fuel_added_action,fuel,effect_prefix,multiplier) end
        local sticker=table.deepcopy(data.raw.sticker["fire-sticker"])
        sticker.name=effect_prefix.."-sticker"
        sticker.damage_per_tick.amount=sticker.damage_per_tick.amount*multiplier
        tint(sticker.animation,fuel.flame)
        data:extend{fire,sticker}
        local stream_names=kind=="ammo" and {"handheld-flamethrower-fire-stream","tank-flamethrower-fire-stream"} or {"flamethrower-fire-stream"}
        for _,name in ipairs(stream_names) do
            local stream=table.deepcopy(data.raw.stream[name])
            stream.name=prefix.."-"..name
            tint(stream.spine_animation,fuel.flame)
            tint(stream.particle,fuel.flame)
            if stream.stream_light then stream.stream_light.color=fuel.flame end
            if stream.ground_light then stream.ground_light.color=fuel.flame end
            for _,entry in pairs(stream.smoke_sources or {}) do entry.name=smoke.name end
            if stream.action then effects(stream.action,fuel,effect_prefix,multiplier) end
            if stream.initial_action then effects(stream.initial_action,fuel,effect_prefix,multiplier) end
            data:extend{stream}
        end
    end
    local ammo=table.deepcopy(base_ammo)
    ammo.name=fuel.ammo
    ammo.localised_name={"item-name.ei-flamethrower-fuel",{"fluid-name."..fuel.fluid}}
    ammo.localised_description={"item-description.ei-flamethrower-fuel",tostring(math.floor(fuel.damage*100+0.5)),tostring(2*fuel.lifetime),tostring(30*fuel.lifetime)}
    ammo.order="e[flamethrower]-"..string.format("%02d",index)
    local fluid=data.raw.fluid[fuel.fluid]
    ammo.icons=ei_lib.make_icons(base_ammo.icon,base_ammo.icon_size or 64,fluid.icon,fluid.icon_size or 64,0.25,{-8,-8})
    ammo.icons[2].floating=true
    ammo.icon=nil
    for _,ammo_type in ipairs(ammo.ammo_type) do
        ammo_type.action.action_delivery.stream=prefix.."-"..ammo_type.action.action_delivery.stream
    end
    data:extend{ammo}
    if fuel.ammo~="flamethrower-ammo" then
        local recipe=table.deepcopy(base_recipe)
        recipe.name=fuel.ammo
        recipe.ingredients={{type="item",name="steel-plate",amount=5},{type="fluid",name=fuel.fluid,amount=100}}
        recipe.results={{type="item",name=fuel.ammo,amount=1}}
        recipe.main_product=fuel.ammo
        recipe.energy_required=6
        recipe.enabled=false
        recipe.localised_name=ammo.localised_name
        recipe.icons=table.deepcopy(ammo.icons)
        recipe.icon=nil
        recipe.allow_productivity=false
        recipe.crafting_machine_tint={primary=fuel.flame,secondary=fuel.smoke}
        data:extend{recipe}
        ei_lib.add_unlock_recipe(fuel.technology,fuel.ammo)
    end
end

--====================================================================================================
--CHECK FOR MOD
--====================================================================================================
--******ensure this happens before icon updates
--solar matrix
if not mods["SolarMatrix"] then
    return
end

ei_lib = require("lib/lib")



--item icon = __SolarMatrix__"/graphics/icons/solar_matrix_icon.png",

--Swap vanilla solar panel with Sacredanarchy's solar matrix
local smatrix = ei_lib.raw["solar-panel"]["solar-matrix"]
if smatrix then
    --vanilla
    vsp = ei_lib.raw["solar-panel"]["solar-panel"]
    if vsp then
        vsp.icon = table.deepcopy(smatrix.icon)
        vsp.collision_box = table.deepcopy(smatrix.collision_box)
        vsp.selection_box = table.deepcopy(smatrix.selection_box)
        vsp.damaged_trigger_effect = table.deepcopy(smatrix.damaged_trigger_effect)
        vsp.corpse = table.deepcopy(smatrix.corpse)
        vsp.build_grid_size = table.deepcopy(smatrix.build_grid_size)
        vsp.picture = table.deepcopy(smatrix.picture)
        vsp.overlay = nil
        vsp.impact_category = table.deepcopy(smatrix.impact_category)
    end
    --panel 2
    esp2 = ei_lib.raw["solar-panel"]["ei-solar-panel-2"]
    if esp2 then
        esp2.icon = table.deepcopy(smatrix.icon)
        esp2.collision_box = table.deepcopy(smatrix.collision_box)
        esp2.selection_box = table.deepcopy(smatrix.selection_box)
        esp2.damaged_trigger_effect = table.deepcopy(smatrix.damaged_trigger_effect)
        esp2.corpse = table.deepcopy(smatrix.corpse)
        esp2.build_grid_size = table.deepcopy(smatrix.build_grid_size)
        esp2.picture = table.deepcopy(smatrix.picture)
        esp2.overlay = nil
        esp2.impact_category = table.deepcopy(smatrix.impact_category)
        --color mask
        esp2.picture.layers[1].tint = {0.706,0.514,0.256}
        esp2.picture.layers[1].apply_runtime_tint = true
        ei_lib.patch_nested_value(
            esp2,
            "picture.layers[2].tint",
            {0.396,0.722,0.553}
        )
    end
    --panel 3
    esp3 = ei_lib.raw["solar-panel"]["ei-solar-panel-3"]
    if esp3 then
        esp3.icon = table.deepcopy(smatrix.icon)
        esp3.collision_box = table.deepcopy(smatrix.collision_box)
        esp3.selection_box = table.deepcopy(smatrix.selection_box)
        esp3.damaged_trigger_effect = table.deepcopy(smatrix.damaged_trigger_effect)
        esp3.corpse = table.deepcopy(smatrix.corpse)
        ei_lib.raw["solar-panel"]["ei-solar-panel-2"].build_grid_size = table.deepcopy(smatrix.build_grid_size)
        esp3.picture = table.deepcopy(smatrix.picture)
        esp3.overlay = nil
        esp3.impact_category = table.deepcopy(smatrix.impact_category)
        --color mask
        esp3.picture.layers[1].tint = {0.706,0.0,0.556}
        esp3.picture.layers[1].apply_runtime_tint = true
        ei_lib.patch_nested_value(
            esp3,
            "picture.layers[2].tint",
            {0.706,0.514,0.753}
        )
    end
else
    log("esir: solar_matrix.lua couldn't find solar_matrix entity, aborting")
    return
end

--corpse solar-matrix-remnants
smatrix_corpse = ei_lib.raw.corpse["solar-matrix-remnants"]

if smatrix_corpse then
    --copy the original corpse
    local ei_panel_2_corpse = table.deepcopy(smatrix_corpse)
    ei_panel_2_corpse.name = "ei-solar-panel-2-remnants"
    ei_panel_2_corpse.icon = table.deepcopy(ei_lib.raw.item["ei-solar-panel-2"].icon)
    ei_panel_2_corpse.tint = {0.706,0.514,0.256}
    --tint each animation variant
    --runtime tint makes them invisible?
    ei_panel_2_corpse.animation[1].layers[1].tint = {0.706,0.514,0.256}
    ei_panel_2_corpse.animation[2].layers[1].tint = {0.706,0.514,0.256}
    ei_panel_2_corpse.animation[3].layers[1].tint = {0.706,0.514,0.256}
    ei_panel_2_corpse.animation[4].layers[1].tint = {0.706,0.514,0.256}
    --same with tier 3 
    local ei_panel_3_corpse = table.deepcopy(smatrix_corpse)
    ei_panel_3_corpse.name = "ei-solar-panel-3-remnants"
    ei_panel_3_corpse.icon = table.deepcopy(ei_lib.raw.item["ei-solar-panel-3"].icon)
    ei_panel_3_corpse.tint = {0.706,0.0,0.556}
    --tint each animation variant
    ei_panel_3_corpse.animation[1].layers[1].tint = {0.706,0.0,0.556}
    ei_panel_3_corpse.animation[2].layers[1].tint = {0.706,0.0,0.556}
    ei_panel_3_corpse.animation[3].layers[1].tint = {0.706,0.0,0.556}
    ei_panel_3_corpse.animation[4].layers[1].tint = {0.706,0.0,0.556}
    data:extend({
        ei_panel_2_corpse,
        ei_panel_3_corpse,
    })
    if esp2 then
        esp2.corpse = "ei-solar-panel-2-remnants"
    end
    if esp3 then
        esp3.corpse = "ei-solar-panel-3-remnants"
    end
end

local solar_matrix_tech = ei_lib.raw.technology["solar-matrix"]
local solar_e_tech = ei_lib.raw.technology["solar-energy"]
--we use this as default model
if solar_matrix_tech and solar_e_tech then
    solar_matrix_tech.enabled = false
    solar_matrix_tech.hidden = true
    solar_e_tech.icon = table.deepcopy(solar_matrix_tech.icon)
    solar_e_tech.icon_size = table.deepcopy(solar_matrix_tech.icon_size)
end
local esp2_tech = ei_lib.raw.technology["ei-solar-panel-2"]
if esp2_tech then
    esp2_tech.icon = table.deepcopy(solar_matrix_tech.icon)
    esp2_tech.icons = {
        {icon=table.deepcopy(solar_matrix_tech.icon),
        tint={0.706,0.514,0.256},
        icon_size = 256}
    }
end
local esp3_tech = ei_lib.raw.technology["ei-solar-panel-3"]
if esp3_tech then
    esp3_tech.icon = table.deepcopy(solar_matrix_tech.icon)
    esp3_tech.icons = {
        {icon=table.deepcopy(solar_matrix_tech.icon),
        tint={0.706,0.0,0.556},
        icon_size = 256}
    }
end

local solar_matrix_item = ei_lib.raw.item["solar-matrix"]
if solar_matrix_item then
    local solar_panel_item = ei_lib.raw.item["solar-panel"]
    if solar_panel_item then
        solar_matrix_item.enabled = false
        solar_matrix_item.hidden = true
        solar_panel_item.icon = table.deepcopy(solar_matrix_item.icon)
    end
    local esp2_item = ei_lib.raw.item["ei-solar-panel-2"]
    if esp2_item then
        esp2_item.icon = table.deepcopy(solar_matrix_item.icon)
        esp2_item.icons = {
            {icon=table.deepcopy(solar_matrix_item.icon),
            tint={0.706,0.514,0.256},
            icon_size = table.deepcopy(solar_matrix_item.icon_size)}
        }
    end
    local esp3_item = ei_lib.raw.item["ei-solar-panel-3"]
    if esp3_item then
        esp3_item.icon = table.deepcopy(solar_matrix_item.icon)
        esp3_item.icons = {
        {icon=table.deepcopy(solar_matrix_item.icon),
        tint={0.706,0.0,0.556},
        icon_size = table.deepcopy(solar_matrix_item.icon_size)}
        }
    end
end

local solar_matrix_recipe = ei_lib.raw.recipe["solar-matrix"]

if solar_matrix_recipe then
    solar_matrix_recipe.enabled = false
    solar_matrix_recipe.hidden = true
end

local solar_rescale = ei_lib.config("solar-icon-scaling")
if not solar_rescale then
    return
end
local switch_table = {
    ["25%"] = 0.25,
    ["50%"] = 0.5,
    ["75% (Vanilla)"] = 0.75,
    ["100%"] = 1,
    ["125%"] = 1.25,
    ["150%"] = 1.5,
    ["175%"] = 1.75,
    ["200%"] = 2,
    ["225%"] = 2.25,
    ["250%"] = 2.5,
    ["275%"] = 2.75,
    ["300%"] = 3
}
local scale_multiplier = switch_table[solar_rescale]
if scale_multiplier == 1 then
    return
end


if vsp then
    local vsp_initial = table.deepcopy(vsp.collision_box)
    ei_lib.entity_icon_scaler(vsp,scale_multiplier)
    local vsp_scaled = table.deepcopy(vsp.collision_box)
    local vsp_area_change = ei_lib.get_entity_area_change(vsp_initial, vsp_scaled)
    --1.778 is area difference multiplier between vanilla 3x3 solar and matrix 4x4
    local vsp_default_production = 80*1.778
    vsp.production = vsp_default_production+(vsp_default_production*vsp_area_change.percent).."kW"
    if smatrix_corpse then
        ei_lib.entity_icon_scaler(smatrix_corpse,scale_multiplier)
    end
end

if esp2 then
    local esp2_initial = table.deepcopy(esp2.collision_box)
    ei_lib.entity_icon_scaler(esp2,scale_multiplier)
    local esp2_scaled = table.deepcopy(esp2.collision_box)
    local esp2_area_change = ei_lib.get_entity_area_change(esp2_initial, esp2_scaled)
    local esp2_default_production = 160*1.778
    esp2.production = esp2_default_production+(esp2_default_production*esp2_area_change.percent).."kW"
    local esp2_corpse = ei_lib.raw.corpse["ei-solar-panel-2-remnants"]
    if esp2_corpse then
        ei_lib.entity_icon_scaler(esp2_corpse,scale_multiplier)
    end
end
if esp3 then
    local esp3_initial = table.deepcopy(esp3.collision_box)
    ei_lib.entity_icon_scaler(esp3,scale_multiplier)
    local esp3_scaled = table.deepcopy(esp3.collision_box)
    local esp3_area_change = ei_lib.get_entity_area_change(esp3_initial, esp3_scaled)
    local esp3_default_production = 320*1.778
    esp3.production = esp3_default_production+(esp3_default_production*esp3_area_change.percent).."kW"
    local esp3_corpse = ei_lib.raw.corpse["ei-solar-panel-3-remnants"]
    if esp3_corpse then
        ei_lib.entity_icon_scaler(esp3_corpse,scale_multiplier)
    end
end
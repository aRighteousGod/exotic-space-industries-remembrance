local ei_lib = require("lib/lib")

--Add nutrients to science pack
local p_d_g = ei_lib.raw.technology["planet-discovery-gleba"]
if p_d_g then
    p_d_g.age = "computer-age"
end
local ag_sci_pack_r = ei_lib.raw.recipe["agricultural-science-pack"]
if ag_sci_pack_r then
    ag_sci_pack_r.ingredients = {
        { type = "item", name = "nutrients", amount = 120}, -- def 40
        { type = "item", name = "bioflux", amount = 3}, -- def 1
        { type = "item", name = "pentapod-egg", amount = 2}, -- def 1
    }
    ag_sci_pack_r.results = {
	{ type = "item", name = "agricultural-science-pack", amount_min = 1, amount_max = 3}, -- def 1
}
    ag_sci_pack_r.energy_required = 8 -- def 4
    ag_sci_pack_r.always_show_products = true
end

-- Biolab uses nutrients, @StephenB
local biolab = ei_lib.raw.lab.biolab
if biolab then
    local originalEnergySource = biolab.energy_source
    local biochamber = ei_lib.raw["assembling-machine"].biochamber
    if biochamber and biochamber.energy_source then
        -- Leaving power at 300kW. Biochambers use 500kW.
        biolab.energy_source = table.deepcopy(biochamber.energy_source)
        -- Biochambers have -1/m pollution emission (ie they reduce pollution). Biolabs had 8/m pollution emission, but this changes it to -1/m. Captive biter spawners are also -1/m. Looking at a simple Nauvis base importing most sciences, biolabs are actually the majority of the pollution, so I'm changing it back to 8/m.
        local originalEmissions = originalEnergySource and originalEnergySource.emissions_per_minute
        local originalPollution = type(originalEmissions) == "table" and originalEmissions.pollution or originalEmissions
        if originalPollution then
            biolab.energy_source.emissions_per_minute = biolab.energy_source.emissions_per_minute or {}
            biolab.energy_source.emissions_per_minute.pollution = originalPollution
        end
    else
        log("Could not find biochamber to copy energy source from, leaving biolab energy source unchanged")
    end
end
--add electric lab unlock to biolab
ei_lib.add_prerequisite("biolab","ei-electric-lab")

local jelly_proc_r = ei_lib.raw.recipe["jellynut-processing"]
if jelly_proc_r then
    jelly_proc_r.results = {
        { type = "item", name = "jellynut-seed", amount = 1, probability = 0.02 },
        { type = "item", name = "jelly", amount_min = 2, amount_max = 6 }, -- def 4
    }
    jelly_proc_r.always_show_products = true
end

local yum_proc_r = ei_lib.raw.recipe["yumako-processing"]
if yum_proc_r then
    yum_proc_r.results = {
        { type = "item", name = "yumako-seed", amount = 1, probability = 0.02 },
        { type = "item", name = "yumako-mash", amount_min = 1, amount_max = 3 }, -- def 2
    }
    yum_proc_r.always_show_products = true
end
local bioflux_r = ei_lib.raw.recipe["bioflux"]
if bioflux_r then
    bioflux_r.results = {
        { type = "item", name = "bioflux", amount_min = 1, amount_max = 7 }, -- def 4
    }
    bioflux_r.always_show_products = true
end

local nut_from_yum_r = ei_lib.raw.recipe["nutrients-from-yumako-mash"]
if nut_from_yum_r then
    nut_from_yum_r.results = {
        { type = "item", name = "nutrients", amount_min = 2, amount_max = 10, probability=0.94 }, -- def 6
        { type = "item", name = "spoilage", amount_min = 1, amount_max = 2, probability=0.04, ignored_by_stats = 2},
    }
    nut_from_yum_r.always_show_products = true
end

local nut_from_bioflux_r = ei_lib.raw.recipe["nutrients-from-bioflux"]
if nut_from_bioflux_r then
    nut_from_bioflux_r.results = {
        { type = "item", name = "nutrients", amount_min = 20, amount_max = 60, probability = 0.96 }, -- def 40
        { type = "item", name = "spoilage", amount_min = 2, amount_max = 8, probability=0.02, ignored_by_stats = 2},
    }
    nut_from_bioflux_r.always_show_products = true
end

local nut_from_biter_egg_r = ei_lib.raw.recipe["nutrients-from-biter-egg"]
if nut_from_biter_egg_r then
    nut_from_biter_egg_r.results = {
        { type = "item", name = "nutrients", amount_min = 15, amount_max = 30}, -- def 20
    }
    nut_from_biter_egg_r.always_show_products = true
end

local bio_l_r = ei_lib.raw.recipe["biolubricant"]
if bio_l_r then
    bio_l_r.ingredients = {
        { type = "item", name = "jelly", amount = 120}, -- def 4
        { type = "item", name = "bioflux", amount = 4}, -- def 1
    }
    bio_l_r.results = {
        { type = "fluid", name = "lubricant", amount_min = 10, amount_max = 40}, -- def 20
    }
    bio_l_r.energy_required = 66 -- def 33
    bio_l_r.always_show_products = true
end
local rf_from_jelly_r = ei_lib.raw.recipe["rocket-fuel-from-jelly"]
if rf_from_jelly_r then
    rf_from_jelly_r.ingredients = {
        { type = "item", name = "jelly", amount = 150}, -- def 30
        { type = "item", name = "bioflux", amount = 20}, -- def 2
        { type = "fluid", name = "ei-liquid-oxygen", amount = 90}, -- def 30 water
        { type = "fluid", name = "ammonia", amount = 60},
    }
    rf_from_jelly_r.results = {
        { type = "item", name = "rocket-fuel", amount_min = 1, amount_max = 5, probability=0.33}, -- def 1, still average 1 per craft
        { type = "fluid", name = "ei-dirty-water", amount_min = 3, amount_max = 12, probability= 0.33, ignored_by_stats = 12},
        { type = "fluid", name = "ei-acidic-water", amount_min = 3, amount_max = 12, probability= 0.33, ignored_by_stats = 12},
        { type = "item", name = "spoilage", amount_min = 1, amount_max = 6, probability=0.33, ignored_by_stats = 6}, -- def 2
    }
    rf_from_jelly_r.always_show_products = true
    rf_from_jelly_r.energy_required = 60 --def 10
end
local bio_p_r = ei_lib.raw.recipe["bioplastic"]
if bio_p_r then
    bio_p_r.ingredients = {
        { type = "item", name = "yumako-mash", amount = 16}, -- def 4
        { type = "item", name = "bioflux", amount = 4}, -- def 1
    }
    bio_p_r.results = {
        { type = "item", name = "plastic-bar", amount_min = 1, amount_max = 6}, -- def 3
    }
    bio_p_r.energy_required = 8 -- def 2
    bio_p_r.always_show_products = true
end
local bio_s_r = ei_lib.raw.recipe["biosulfur"]
if bio_s_r then
    bio_s_r.ingredients = {
        { type = "item", name = "spoilage", amount = 20}, -- def 5
        { type = "item", name = "bioflux", amount = 4}, -- def 1
    }
    bio_s_r.results = {
        { type = "item", name = "sulfur", amount_min = 1, amount_max = 4}, -- def 2
    }
    bio_s_r.energy_required = 8 -- def 2
    bio_s_r.always_show_products = true
end

local ca_fi_t = ei_lib.raw.technology["carbon-fiber"]
if ca_fi_t then
    ca_fi_t.localised_description = {"technology-description.ei-carbon-fiber"}
    ei_lib.add_prerequisite("carbon-fiber","ei-carbon-manipulation")
end

local ca_fi_r = ei_lib.raw.recipe["carbon-fiber"]
if ca_fi_r then
    ca_fi_r.localised_description = {"technology-description.ei-carbon-fiber"}
    ca_fi_r.ingredients = { --default 1 carbon, 10 yumako mash
	{ type = "fluid", name = "ei-molten-carbon-symbiote", amount = 20},
    { type = "fluid", name = "steam", amount = 200, minimum_temperature = 500 },
    { type = "item", name = "pentapod-egg", amount = 1},
    { type = "item", name = "yumako-mash", amount = 20}, -- def 10
}
    ca_fi_r.results = {
	{ type = "item", name = "carbon-fiber", amount_min = 1, amount_max = 3}, -- def 1
}
    ca_fi_r.energy_required = 15 -- def 5
    ca_fi_r.always_show_products = true
    --this may return but foundry can do casting and that doesn't make sense, reconsider an extra category to only add to caster later..although the recipe description would seem to lean biochamber
    --[[
    local cf_ac = ca_fi_r.additional_categories
    if cf_ac then
        table.insert(cf_ac,"ei-casting")
    else
        ei_lib.raw.recipe["carbon-fiber"].additional_categories = {"ei-casting"}
    end
    ]]
end
local pen_egg_r = ei_lib.raw.recipe["pentapod-egg"]
if pen_egg_r then
    pen_egg_r.ingredients = {
        { type = "item", name = "nutrients", amount = 75}, -- def 30
        { type = "item", name = "pentapod-egg", amount = 1, ignored_by_stats = 1}, -- def 1
        { type = "fluid", name = "water", amount = 150}, -- def 60
    }
    pen_egg_r.results = {
        { type = "item", name = "pentapod-egg", amount = 1, ignored_by_stats = 1, ignored_by_productivity = 1}, -- def 2
        { type = "item", name = "pentapod-egg", amount_min = 1, amount_max = 3, probability=0.75},
    }
    pen_egg_r.energy_required = 37 -- def 15
    pen_egg_r.always_show_products = true
    pen_egg_r.localised_name = {"item-name.pentapod-egg"}
    pen_egg_r.localised_description = {"item-description.pentapod-egg"}
end

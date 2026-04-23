local ei_lib = require("lib/lib")

local p_d_f = ei_lib.raw.technology["planet-discovery-fulgora"]
if p_d_f then
    p_d_f.age = "computer-age"
end
local li_co = ei_lib.raw.technology["lightning-collector"]
if li_co then
    li_co.age = "computer-age"
end
local electro = ei_lib.raw["assembling-machine"]["electromagnetic-plant"]
if electro then
    electro.energy_usage = "41.4MW"
    electro.energy_source.emissions_per_minute.pollution = 12 --def 4
    electro.crafting_speed = 1.5
    electro.module_slots = 3
    table.insert(electro.crafting_categories,"ei-waver-factory")
end
local t_t = ei_lib.raw["electric-turret"]["tesla-turret"]
if t_t then
    t_t.max_health = 1800
    t_t.resistances =
    {
        {type = "electric", decrease = 10, percent = 95 },
    }
end

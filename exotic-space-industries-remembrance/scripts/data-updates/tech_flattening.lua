
-- also set prerequisite of all techs to "ei-temp" tech

local ei_lib = require("lib/lib")
local ei_data = require("lib/data")

--====================================================================================================
--TECH FLATTENING
--====================================================================================================



-- loop over all technologies
for i,v in pairs(data.raw.technology) do
    
    --convert triggered technologies to science-packs
    --  if data.raw.technology[i]["research_trigger"] then
    --     data.raw.technology[i]["research_trigger"] = nil
    --     data.raw.technology[i].unit = {ingredients = {}, time=20, count=100}
    --  end

    




    -- treat prerequisites:
    -- only if this is no Exotic-Industries tech
    --[[
    if not (string.sub(data.raw.technology[i].name, 1, 3) == "ei-") then
        data.raw.technology[i].prerequisites = {"ei-temp"}
    end
    ]]

    -- every tech in ei_data.tech_structure[] gets its prerequisites set to "ei-temp"
    -- aswell as all techs from ei_data.tech_exclude_list
    for i,v in pairs(ei_data.tech_structure) do
        for x,y in ipairs(ei_data.tech_structure[i]) do
          if data.raw.technology[y] then
            data.raw.technology[y].prerequisites = {"ei-temp"}
          end
        end
    end

    for i,v in ipairs(ei_data.tech_exclude_list) do
      if data.raw.technology[y] then
        data.raw.technology[v].prerequisites = {"ei-temp"}
      end
    end
end
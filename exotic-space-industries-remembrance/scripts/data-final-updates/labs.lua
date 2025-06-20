--LABS
------------------------------------------------------------------------------------------------------
ei_lib.raw["lab"]["ei-big-lab"].inputs = table.deepcopy(ei_data.lab_inputs["biglab"])
ei_lib.raw["lab"]["biolab"].inputs = table.deepcopy(ei_data.lab_inputs["biolab"])
ei_lib.raw["lab"]["lab"].inputs = table.deepcopy(ei_data.lab_inputs["lab"])
ei_lib.raw["lab"]["lab"].researching_speed = 1.5
ei_lib.raw["lab"]["lab"].fast_replaceable_group = "lab"

for science_pack_name,science_pack_object in pairs(data.raw['tool']) do
  if science_pack_object.hidden or ei_lib.table_contains_value(ei_data.tech_exclude_list,science_pack_name) then 
    if not ei_lib.table_contains_value(data.raw.lab["ei-dummy-lab"]['inputs'],science_pack_name) then 
      table.insert(data.raw.lab["ei-dummy-lab"]['inputs'],science_pack_name)
    end
    elseif ei_lib.table_contains_value(data.raw.lab["ei-big-lab"]['inputs'],science_pack_name) then
      if not ei_lib.table_contains_value(data.raw.lab["ei-dummy-lab"]['inputs'],science_pack_name) then 
        table.insert(data.raw.lab["ei-dummy-lab"]['inputs'],science_pack_name)
    end
  else
    table.insert(data.raw.lab["ei-big-lab"]['inputs'],science_pack_name)
    table.insert(data.raw.lab["lab"]['inputs'],science_pack_name)
    table.insert(data.raw.lab["biolab"]['inputs'],science_pack_name)
    log("ei labs: adding "..science_pack_name.." to big lab, lab, biolab.")
  end
end


--data.raw.lab["ei-dark-age-lab"]['inputs'] = table.deepcopy(ei_data.lab_inputs["dark-age-lab"])
--data.raw.lab.lab['inputs'] = table.deepcopy(ei_data.lab_inputs["lab"])

-- error(serpent.block(data.raw.lab["ei-dark-age-lab"]['inputs']))
-- error(serpent.block(util.by_pixel))

for science_pack_name,science_pack_object in pairs(data.raw['tool']) do
  if science_pack_object.hidden then 
    if not ei_lib.table_contains_value(data.raw.lab["ei-dummy-lab"]['inputs'],science_pack_name) then 
      table.insert(data.raw.lab["ei-dummy-lab"]['inputs'],science_pack_name)
    end
    elseif string.sub(science_pack_name, 1, 3) == "ei-" then  
      if not ei_lib.table_contains_value(data.raw.lab["ei-dummy-lab"]['inputs'],science_pack_name) then 
        table.insert(data.raw.lab["ei-dummy-lab"]['inputs'],science_pack_name)
    end
   elseif ei_lib.table_contains_value(data.raw.lab.lab['inputs'],science_pack_name) then
    if not ei_lib.table_contains_value(data.raw.lab["ei-dummy-lab"]['inputs'],science_pack_name) then 
      table.insert(data.raw.lab["ei-dummy-lab"]['inputs'],science_pack_name)
    end
--  else 
--    table.insert(data.raw.lab.lab['inputs'],science_pack_name)
  end
end

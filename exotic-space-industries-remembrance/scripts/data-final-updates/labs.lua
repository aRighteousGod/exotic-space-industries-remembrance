for science_pack_name,science_pack_object in pairs(data.raw['tool']) do
  if science_pack_object.hidden then 
    if not ei_lib.table_contains_value(data.raw.lab["ei-dummy-lab"]['inputs'],science_pack_name) then 
      table.insert(data.raw.lab["ei-dummy-lab"]['inputs'],science_pack_name)
    end
  elseif ei_lib.table_contains_value(data.raw.lab["ei-big-lab"]['inputs'],science_pack_name) then
    if not ei_lib.table_contains_value(data.raw.lab["ei-dummy-lab"]['inputs'],science_pack_name) then 
      table.insert(data.raw.lab["ei-dummy-lab"]['inputs'],science_pack_name)
    end
  else 
    table.insert(data.raw.lab["ei-big-lab"]['inputs'],science_pack_name)
  end
end

data.raw.lab["ei-dark-age-lab"]['inputs'] = table.deepcopy(ei_data.lab_inputs["dark-age-lab"])
data.raw.lab.lab['inputs'] = table.deepcopy(ei_data.lab_inputs["lab"])

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
  else 
    table.insert(data.raw.lab.lab['inputs'],science_pack_name)
  end
end
-- if mods[""] then 

-- end



if mods["aai-industry"] then 
  ei_lib.disable("burner-assembling-machine")
  data.raw["assembling-machine"]["burner-assembling-machine"].next_upgrade = nil
end

require("compatibility_lignumis")
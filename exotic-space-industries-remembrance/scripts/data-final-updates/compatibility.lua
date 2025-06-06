ei_lib = require("lib/lib")

if mods["aai-industry"] then 
  ei_lib.disable("burner-assembling-machine")
  data.raw["assembling-machine"]["burner-assembling-machine"].next_upgrade = nil
end
--Normally elevated pipes require iron stick, converted elsewhere to copper mechanical parts
if mods["elevated-pipes"] then
   ei_lib.remove_unlock_recipe("elevated-pipe","iron-stick")
end
require("compatibility_lignumis")
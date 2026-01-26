ei_lib = require("lib/lib")

if mods["Igrys"] then 
  local cpp = ei_lib.raw.technology["igrys-copper-plate-productivity"]
  if cpp then
    table.insert(cpp.effects,
      {
          type = "change-recipe-productivity",
          recipe = "ei-cast-copper-ingot",
          change = 0.1
      })
  end
end

if mods["aai-industry"] then 
  ei_lib.disable("burner-assembling-machine")
  data.raw["assembling-machine"]["burner-assembling-machine"].next_upgrade = nil
end
--Normally elevated pipes require iron stick, converted elsewhere to copper mechanical parts
if mods["elevated-pipes"] then
   ei_lib.remove_unlock_recipe("elevated-pipe","iron-stick")
end
require("compatibility-lignumis")
--==============================================================================
-- ESIR FILE MAP
-- owns: final optional recipe productivity and compatibility routing
-- loaded_by: data-final-fixes.lua
-- cadence: data final fixes only
-- storage_roots: none
--==============================================================================
-- blueprint: .codex/esir/blueprints/recipe-economy.md#contract
ei_lib = require("lib/lib")

-- blueprint-ref: .codex/esir/blueprints/recipe-economy.md#muluna-rockets
if mods["planet-muluna"] then
  local routes = {"ei-rocket-parts", "ei-rocket-parts-advanced",
    "ei-rocket-parts-odd-plating", "ei-rocket-parts-odd-plating-advanced"}
  for _, technology in pairs(data.raw.technology) do
    local effects, existing = {}, {}
    for _, effect in ipairs(technology.effects or {}) do
      if effect.type == "change-recipe-productivity" then existing[effect.recipe] = true end
    end
    for _, effect in ipairs(technology.effects or {}) do
      if effect.type == "change-recipe-productivity" and effect.recipe == "rocket-part" then
        -- The silo recipe consumes already-made ESIR parts. Apply this research
        -- at their four manufacturing routes, preserving Muluna's level value.
        for _, recipe in ipairs(routes) do
          if data.raw.recipe[recipe] and not existing[recipe] then
            local replacement = table.deepcopy(effect)
            replacement.recipe = recipe
            effects[#effects + 1] = replacement
            existing[recipe] = true
          end
        end
      else
        effects[#effects + 1] = effect
      end
    end
    if technology.effects then technology.effects = effects end
  end
end

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

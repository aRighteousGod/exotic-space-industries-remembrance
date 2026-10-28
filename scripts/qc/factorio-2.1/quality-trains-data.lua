-- Private recipe admits all module effects without altering shipping recipes.
local recipe={type="recipe",name="esir-module-qc",enabled=true,energy_required=1,
    ingredients={{type="item",name="iron-plate",amount=1}},results={{type="item",name="iron-gear-wheel",amount=1}},
    allow_productivity=true,allow_quality=true,hide_from_player_crafting=true}
if mods.base:sub(1,3)=="2.1" then recipe.categories={"crafting"} else recipe.category="crafting" end
data:extend{recipe}

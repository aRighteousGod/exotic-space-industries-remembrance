local backgrounds =
{
["Gaian Guardian"] = ei_path.."graphics/background/background1.png",
["Industry1"] = ei_path.."graphics/background/background2.png",
["Industry2"] = ei_path.."graphics/background/background3.png",
["Angel1"] = ei_path.."graphics/background/background4.png",
["Angel2"] = ei_path.."graphics/background/background5.png",
["Throne of Fleshed Glass"] = ei_path.."graphics/background/background6.png",
["The Crystal That Screams"] = ei_path.."graphics/background/background7.png"
}
local pick = backgrounds[ei_lib.config("menu-background")]
-- Override background GUI style
if not pick then return end
data.raw["utility-constants"]["default"].main_menu_background_image_location = pick
data.raw["utility-constants"]["default"].main_menu_simulations = {}
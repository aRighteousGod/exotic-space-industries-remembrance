local backgrounds =
{
["The Crystal That Screams"] = ei_path.."graphics/background/background1.png",
["Vector Bifurcation: Portal Ignition"] = ei_path.."graphics/background/background2.png",
["Saluting the Solar Core"] = ei_path.."graphics/background/background3.png",
["Daemonic Invitation"] = ei_path.."graphics/background/background4.png",
["Yin and Yang: Cloudflesh"] = ei_path.."graphics/background/background5.png",
["Industrial Dominance: Crystalline Vigil"] = ei_path.."graphics/background/background6.png",
["Choking Smog: Ascension Protocol"] = ei_path.."graphics/background/background7.png"
}
local pick = backgrounds[ei_lib.config("menu-background")]
-- Override background GUI style
if not pick then return end
data.raw["utility-constants"]["default"].main_menu_background_image_location = pick
data.raw["utility-constants"]["default"].main_menu_simulations = {}
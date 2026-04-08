require "teslas_legacy.prototypes.entity.beam.tl-tesla-coil-beam"
require "teslas_legacy.prototypes.entity.explosion.tl-tesla-coil-explosion"
require "teslas_legacy.prototypes.entity.explosion.tl-tesla-coil-turret-explosion"
require "teslas_legacy.prototypes.entity.electric-turret.tl-advanced-tesla-coil-turret"
require "teslas_legacy.prototypes.entity.electric-turret.tl-basic-tesla-coil-turret"
require "teslas_legacy.prototypes.entity.combat-robot.tl-basic-tesla-coil-timer"
require "teslas_legacy.prototypes.entity.land-mine.tl-basic-tesla-coil-single-zap"
require "teslas_legacy.prototypes.entity.land-mine.tl-basic-tesla-coil-multi-zap"
require "teslas_legacy.prototypes.entity.land-mine.tl-tesla-coil-zap-explosion"
require "teslas_legacy.prototypes.entity.car.tl-tesla-tank-car"
require "teslas_legacy.prototypes.entity.sticker.tl-shock-sticker"
require "teslas_legacy.prototypes.entity.fire.tl-tesla-coil-zap-fire"

require "teslas_legacy.prototypes.category.tl-tesla-coil-ammo-category"
require "teslas_legacy.prototypes.category.tl-basic-tesla-coil-turret-category"
require "teslas_legacy.prototypes.category.tl-advanced-tesla-coil-turret-category"
require "teslas_legacy.prototypes.item.tl-advanced-tesla-coil-item"
require "teslas_legacy.prototypes.item.tl-basic-tesla-coil-item"
require "teslas_legacy.prototypes.item.tl-tesla-tank-item"
require "teslas_legacy.prototypes.item.tl-tesla-tank-gun-item"
require "teslas_legacy.prototypes.item.tl-tesla-coil-ammo-item"
require "teslas_legacy.prototypes.recipe.tl-advanced-tesla-coil-recipe"
require "teslas_legacy.prototypes.recipe.tl-basic-tesla-coil-recipe"
require "teslas_legacy.prototypes.recipe.tl-tesla-tank-recipe"
require "teslas_legacy.prototypes.recipe.tl-tesla-coil-ammo-recipe"
require "teslas_legacy.lib.technology"

require "teslas_legacy.prototypes.technology.tl-tesla-tank-technology"
require "teslas_legacy.prototypes.technology.tl-basic-tesla-coils-technology"
require "teslas_legacy.prototypes.technology.tl-advanced-tesla-coils-technology"
require "teslas_legacy.prototypes.technology.tl-tesla-coil-damage-1-technology"
require "teslas_legacy.prototypes.technology.tl-tesla-coil-damage-2-technology"
require "teslas_legacy.prototypes.technology.tl-tesla-coil-damage-3-technology"
require "teslas_legacy.prototypes.technology.tl-tesla-coil-damage-4-technology"
require "teslas_legacy.prototypes.technology.tl-tesla-coil-damage-5-technology"
require "teslas_legacy.prototypes.technology.tl-tesla-coil-damage-6-technology"
require "teslas_legacy.prototypes.technology.tl-tesla-coil-damage-7-technology"
require "teslas_legacy.prototypes.technology.tl-tesla-coil-shooting-speed-1-technology"
require "teslas_legacy.prototypes.technology.tl-tesla-coil-shooting-speed-2-technology"
require "teslas_legacy.prototypes.technology.tl-tesla-coil-shooting-speed-3-technology"
require "teslas_legacy.prototypes.technology.tl-tesla-coil-shooting-speed-4-technology"
require "teslas_legacy.prototypes.technology.tl-tesla-coil-shooting-speed-5-technology"
require "teslas_legacy.prototypes.technology.tl-tesla-coil-shooting-speed-6-technology"
require "teslas_legacy.prototypes.technology.tl-tesla-coil-shooting-speed-7-technology"
require "teslas_legacy.prototypes.technology.tl-tesla-ammo-upgrade-technology"
require "teslas_legacy.prototypes.technology.tl-scripted-technologies"


get_tesla_coil_zap_fire_data_extend()
tl_tesla_coil_zap_explosion_data_extend()
tl_basic_tesla_coil_single_zap_data_extend()

tl_basic_tesla_coil_multi_zap_data_extend()
tl_basic_tesla_coil_beam_data_extend()
tl_shock_sticker_data_extend()

all_scripted_technology_data_extend()

-- The vendored Tesla tree still contains a mix of static prototype files and
-- helper-generated technologies. Normalize every TL technology here, inside the
-- owned Tesla module, so they all carry EI-native ages and age-pack ingredients
-- before EI's global final-tech passes run.
apply_tesla_technology_layouts()






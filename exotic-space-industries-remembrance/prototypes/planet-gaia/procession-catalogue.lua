local util = require("__core__.lualib.util")
local procession_graphic_catalogue = require("__base__/prototypes/planet/procession-graphic-catalogue-types")

local sprite_flags = {"group=effect-texture", "linear-minification", "linear-magnification"}
local gaia_tint = {r = 0.42, g = 0.95, b = 0.72, a = 1}

local function make_catalogue_sprite(index, filename, width, height, tint)
    local sprite = {
        filename = filename,
        width = width,
        height = height,
        priority = "no-atlas",
        flags = sprite_flags,
    }

    if tint then
        sprite.tint = tint
    end

    return {
        index = index,
        type = "sprite",
        sprite = sprite,
    }
end

local function make_hatch_sprite(index, filename, shift_x, shift_y)
    return {
        index = index,
        sprite = util.sprite_load(filename, {
            priority = "medium",
            draw_as_glow = true,
            blend_mode = "additive",
            scale = 0.5,
            shift = util.by_pixel(shift_x, shift_y),
        })
    }
end

return {
    make_catalogue_sprite(
        procession_graphic_catalogue.planet_cloudscape,
        "__space-age__/graphics/procession/clouds/gleba-cloudscape.png",
        960,
        960
    ),
    make_catalogue_sprite(
        procession_graphic_catalogue.planet_cloudscape_mask,
        "__space-age__/graphics/procession/clouds/mask-cloudscape.png",
        960,
        960
    ),
    make_catalogue_sprite(
        procession_graphic_catalogue.planet_cloudscape_lvl0,
        "__space-age__/graphics/procession/clouds/gleba-cloudscape-layered-0.png",
        2000,
        1500
    ),
    make_catalogue_sprite(
        procession_graphic_catalogue.planet_cloudscape_lvl0_mask,
        "__space-age__/graphics/procession/clouds/mask-cloudscape-layered-0.png",
        2000,
        1500
    ),
    make_catalogue_sprite(
        procession_graphic_catalogue.planet_cloudscape_lvl1,
        "__space-age__/graphics/procession/clouds/gleba-cloudscape-layered-1.png",
        1600,
        1200
    ),
    make_catalogue_sprite(
        procession_graphic_catalogue.planet_cloudscape_lvl1_mask,
        "__space-age__/graphics/procession/clouds/mask-cloudscape-layered-1.png",
        1600,
        1200
    ),
    make_catalogue_sprite(
        procession_graphic_catalogue.planet_cloudscape_lvl2,
        "__space-age__/graphics/procession/clouds/gleba-cloudscape-layered-2.png",
        1400,
        1050
    ),
    make_catalogue_sprite(
        procession_graphic_catalogue.planet_cloudscape_lvl2_mask,
        "__space-age__/graphics/procession/clouds/mask-cloudscape-layered-2.png",
        1400,
        1050
    ),
    make_catalogue_sprite(
        procession_graphic_catalogue.planet_cloudscape_lvl3,
        "__space-age__/graphics/procession/clouds/gleba-cloudscape-layered-3.png",
        1200,
        900
    ),
    make_catalogue_sprite(
        procession_graphic_catalogue.planet_cloudscape_lvl3_mask,
        "__space-age__/graphics/procession/clouds/mask-cloudscape-layered-3.png",
        1200,
        900
    ),
    make_catalogue_sprite(
        procession_graphic_catalogue.planet_stars_background,
        "__space-age__/graphics/procession/space-rear-star.png",
        1024,
        1024
    ),
    make_catalogue_sprite(
        procession_graphic_catalogue.planet_tint,
        "__space-age__/graphics/procession/clouds/gleba-sky-tint.png",
        16,
        16,
        gaia_tint
    ),
    make_hatch_sprite(
        procession_graphic_catalogue.hatch_emission_bay,
        "__space-age__/graphics/entity/cargo-hubs/hatches/shared-cargo-bay-pod-emission",
        10.24,
        48
    ),
    make_hatch_sprite(
        procession_graphic_catalogue.hatch_emission_out_1,
        "__space-age__/graphics/entity/cargo-hubs/hatches/platform-lower-hatch-pod-emission-A",
        56,
        -16
    ),
    make_hatch_sprite(
        procession_graphic_catalogue.hatch_emission_out_2,
        "__space-age__/graphics/entity/cargo-hubs/hatches/platform-lower-hatch-pod-emission-B",
        16,
        -32
    ),
    make_hatch_sprite(
        procession_graphic_catalogue.hatch_emission_out_3,
        "__space-age__/graphics/entity/cargo-hubs/hatches/platform-lower-hatch-pod-emission-C",
        64,
        -48
    ),
    make_hatch_sprite(
        procession_graphic_catalogue.hatch_emission_in_1,
        "__space-age__/graphics/entity/cargo-hubs/hatches/platform-upper-hatch-pod-emission-A",
        -16,
        96
    ),
    make_hatch_sprite(
        procession_graphic_catalogue.hatch_emission_in_2,
        "__space-age__/graphics/entity/cargo-hubs/hatches/platform-upper-hatch-pod-emission-B",
        -64,
        96
    ),
    make_hatch_sprite(
        procession_graphic_catalogue.hatch_emission_in_3,
        "__space-age__/graphics/entity/cargo-hubs/hatches/platform-upper-hatch-pod-emission-C",
        -40,
        64
    ),
    make_hatch_sprite(
        procession_graphic_catalogue.planet_hatch_emission_in_1,
        "__base__/graphics/entity/cargo-hubs/hatches/planet-lower-hatch-pod-emission-A",
        -16,
        96
    ),
    make_hatch_sprite(
        procession_graphic_catalogue.planet_hatch_emission_in_2,
        "__base__/graphics/entity/cargo-hubs/hatches/planet-lower-hatch-pod-emission-B",
        -64,
        96
    ),
    make_hatch_sprite(
        procession_graphic_catalogue.planet_hatch_emission_in_3,
        "__base__/graphics/entity/cargo-hubs/hatches/planet-lower-hatch-pod-emission-C",
        -40,
        64
    ),
}

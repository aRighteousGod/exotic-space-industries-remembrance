local ei_lib = require("lib/lib")

ei_lib.raw.item["electromagnetic-science-pack"].pictures = {
layers = {
    {
        filename = ei_graphics_3_path.."graphics/items/fulgora-science-vial.png",
        size = 128,
    	scale = 0.25,
    },
    {
        draw_as_light = true,
        flags = {"light"},
        filename = ei_graphics_3_path.."graphics/items/fulgora-science-vial-glow.png",
        size = 128,
    	scale = 0.25,
    }
}
}

ei_lib.raw.item["promethium-science-pack"].pictures = {
layers = {
    {
        filename = ei_graphics_3_path.."graphics/items/promethium-science-vial.png",
        size = 128,
    	scale = 0.25,
    },
    {
        draw_as_light = true,
        flags = {"light"},
        filename = ei_graphics_3_path.."graphics/items/promethium-science-vial-glow.png",
        size = 128,
    	scale = 0.25,
    }
}
}

ei_lib.raw.item["cryogenic-science-pack"].pictures = {
layers = {
    {
        filename = ei_graphics_3_path.."graphics/items/aquilo-science-vial.png",
        size = 128,
    	scale = 0.25,
    },
    {
        draw_as_light = true,
        flags = {"light"},
        filename = ei_graphics_3_path.."graphics/items/aquilo-science-vial-glow.png",
        size = 128,
        scale = 0.25,
    }
}
}

ei_lib.raw.item["metallurgic-science-pack"].pictures = {
layers = {
    {
        filename = ei_graphics_3_path.."graphics/items/vulcanus-science-vial.png",
        size = 128,
    	scale = 0.25,
    },
    {
        draw_as_light = true,
        flags = {"light"},
        filename = ei_graphics_3_path.."graphics/items/vulcanus-science-vial-glow.png",
        size = 128,
    	scale = 0.25,
    }
}
}

ei_lib.raw.item["agricultural-science-pack"].pictures = {
layers = {
    {
        filename = ei_graphics_3_path.."graphics/items/gleba-science-vial.png",
        size = 128,
    	scale = 0.25,
    },
    {
        draw_as_light = true,
        flags = {"light"},
        filename = ei_graphics_3_path.."graphics/items/gleba-science-vial-glow.png",
        size = 128,
    	scale = 0.25,
    }
}
}
local unset = {} -- Marker to set attribute to nil
local items = {
    ["metallurgic-science-pack"] = {
        icon_size = 128,
        icon = ei_graphics_3_path.."graphics/items/vulcanus-science-vial.png",
        icons = unset,
        icon_mipmaps = 4,
    },
    ["electromagnetic-science-pack"] = {
        icon_size = 128,
        icon = ei_graphics_3_path.."graphics/items/fulgora-science-vial.png",
        icons = unset,
        icon_mipmaps = 4,
    },
    ["agricultural-science-pack"] = {
        icon_size = 128,
        icon = ei_graphics_3_path.."graphics/items/gleba-science-vial.png",
        icons = unset,
        icon_mipmaps = 4,
    },
    ["cryogenic-science-pack"] = {
        icon_size = 128,
        icon = ei_graphics_3_path.."graphics/items/aquilo-science-vial.png",
        icons = unset,
        icon_mipmaps = 4,
    },
    ["promethium-science-pack"] = {
        icon_size = 128,
        icon = ei_graphics_3_path.."graphics/items/promethium-science-vial.png",
        icons = unset,
        icon_mipmaps = 4,
    },
}
for name, definition in pairs(items) do
    for property, value in pairs(definition) do
        if value == unset then
            value = nil
        end
        if ei_lib.raw.technology[name] then
            ei_lib.raw.technology[name][property] = value
        end
        if ei_lib.get_item_prototype(name) then
            ei_lib.get_item_prototype(name)[property] = value
        end
    end
end

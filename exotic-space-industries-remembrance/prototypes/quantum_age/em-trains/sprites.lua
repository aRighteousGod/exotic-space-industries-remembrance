local emt_charger_glow = {
    type = "sprite",
    name = "emt_charger_glow",
    filename = ei_graphics_glow_path.."big_pngs/glow_3_25.png",
    priority = "high",
    width = 820,
    height = 826,
    scale = 1,
    frame_count = 3,
    animation_speed = 2,
}
local emt_train_glow = {
    type = "sprite",
    name = "emt_train_glow",
    filename = ei_graphics_glow_path.."small_pngs/frame_count_3/glow_3_25.png",
    priority = "high",
    width = 205,
    height = 207,
    scale = 1,
    frame_count = 3,
    animation_speed = 1,
}
local charger_beam = table.deepcopy(data.raw["beam"]["electric-beam"])
charger_beam.name = "ei_charger-beam"
charger_beam.action = nil
charger_beam.working_sound.min_volume=0.05
charger_beam.working_sound.max_volume=0.1
-- Define your imperial tint: rich royal purple
local purple_tint = {r = 0.6, g = 0.1, b = 0.8, a = 1}

-- Apply the tint to each part of the beam
if charger_beam.head then
  charger_beam.head.tint = purple_tint
end

if charger_beam.tail then
  charger_beam.tail.tint = purple_tint
end

if charger_beam.body then
  for _, segment in pairs(charger_beam.body) do
    charger_beam.segment.tint = purple_tint
  end
end

if charger_beam.light then
  charger_beam.light.tint = purple_tint
end

data:extend({
    emt_charger_glow,
    emt_train_glow,
    charger_beam,
    {
        name = "ei_emt-logo",
        type = "sprite",
        filename = ei_trains_tech_path.."em-locomotive.png",
        size = 256,
        scale = 0.25,
    },
    {
        name = "ei_emt-range-toggle",
        type = "sprite",
        filename = ei_trains_item_path.."charging.png",
        size = 64,
    },
    {
        name = "ei_emt-radius",
        type = "sprite",
        filename = ei_trains_entity_path.."radius.png",
        size = 256,
    },
    {
        name = "ei_emt-radius_big",
        type = "sprite",
        filename = ei_trains_entity_path.."radius_big.png",
        size = 256*4,
    },
})


local style = data.raw["gui-style"]["default"]

style.ei_subheader_frame = {
    type = "frame_style",
    parent = "subheader_frame",
    horizontally_stretchable = "on"
}

style.ei_inner_content_flow = {
    type = "vertical_flow_style",
    padding = 12
}
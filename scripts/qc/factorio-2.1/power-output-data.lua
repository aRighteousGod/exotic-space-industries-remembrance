-- The only private prototype is the measurement load. Generators are unchanged.
data:extend{{
    type = "electric-energy-interface", name = "esir-qc-power-load",
    icon = "__base__/graphics/icons/accumulator.png", icon_size = 64,
    flags = {"placeable-player", "player-creation"},
    collision_box = {{-0.4,-0.4},{0.4,0.4}}, selection_box = {{-0.5,-0.5},{0.5,0.5}},
    energy_source = {type="electric", buffer_capacity="1GJ", usage_priority="primary-input",
        input_flow_limit="100GW", output_flow_limit="0W"},
    energy_production = "0W", energy_usage = "0W",
    picture = {filename="__core__/graphics/empty.png", width=1, height=1},
}}

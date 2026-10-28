-- No ESIR imports, prototypes, control code or assets. Same authored power/fuel values.
data:extend{{
    type="burner-generator", name="qc-native-burner",
    icon="__base__/graphics/icons/steam-engine.png", icon_size=64,
    flags={"placeable-player","player-creation"},
    collision_box={{-1.4,-1.4},{1.4,1.4}}, selection_box={{-1.5,-1.5},{1.5,1.5}},
    energy_source={type="electric",usage_priority="secondary-output"},
    burner={type="burner",fuel_categories={"chemical"},effectivity=3,fuel_inventory_size=3},
    max_power_output="12MW",
}}

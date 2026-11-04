-- blueprint: .codex/esir/blueprints/combustion-turbine.md#contract
-- Shared by prototypes, oxygen extraction and runtime classification.
-- Keep supplied-oxygen pressure < this value paired with oxygen extraction
-- pressure >= this value. Change the shared boundary and boundary tests together.
return {
    atmospheric_oxygen_min_pressure = 33,
    oxygen_tag = "ei_combustion_turbine_oxygen_fed",
    mode_tag = "ei_combustion_turbine_mode",
    ash_tag = "ei_combustion_turbine_ash_generating",
    enabled_tag = "ei_combustion_turbine_enabled",
    ash_solid = "ei-combustion-turbine-ash",
    oxygen_ash_solid = "ei-combustion-turbine-oxygen-solid-ash",
    ash_generator = "ei-combustion-turbine-oxygen-generator-ash",
    ash_factor = 0.9,
    ash_slots = 3,
    solid = "ei-combustion-turbine",
    fluid = "ei-combustion-turbine-fluid",
    oxygen_solid = "ei-combustion-turbine-oxygen-solid",
    oxygen_fluid = "ei-combustion-turbine-oxygen-fluid",
    generator = "ei-combustion-turbine-oxygen-generator",
    working_fluid = "ei-combustion-turbine-working-fluid",
    recipe = "ei-combustion-turbine-oxygen-combustion",
    pressure_interval = 60,
}

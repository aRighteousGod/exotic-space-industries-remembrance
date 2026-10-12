-- Native preview proposal from the accepted fixed-base render, not a calibration.
require("__core__/lualib/circuit-connector-sprites")
return {
    status="unvalidated_new_foundation_connector_proposal",
    connector_anchor_calibrated=false,
    connector_proposal={variation=28,main_offset_pixels={30,14},shadow_offset_pixels={35,19},
        measured_mount_bolt_pixels={38.5,11.5},source_ground_anchor_master_pixels={270,270}},
    circuit_connector=circuit_connector_definitions.create_vector(universal_connector_template,{
        {variation=28,main_offset={30/32,14/32},shadow_offset={35/32,19/32},show_shadow=true},
    }),
}

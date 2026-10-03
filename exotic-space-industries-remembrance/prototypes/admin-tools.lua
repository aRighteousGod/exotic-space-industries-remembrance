-- blueprint: .codex/esir/blueprints/admin-tools.md#contract
local config = require("lib/admin-tools-config")
-- Keep the hidden selector defined across enable/disable so cursor cleanup can
-- identify it during configuration changes. It has no recipe or public item.
data:extend({{
    type="selection-tool", name=config.selector,
    icon="__base__/graphics/icons/radar.png", icon_size=64,
    stack_size=1, flags={"only-in-cursor", "spawnable"}, hidden=true,
    select={border_color={0.35,0.85,1,0.8}, mode={"any-entity","any-tile"}, cursor_box_type="entity"},
    alt_select={border_color={1,0.65,0.2,0.8}, mode={"any-entity","any-tile"}, cursor_box_type="entity"},
}})
local styles=data.raw["gui-style"].default
styles.ei_admin_nav={type="button_style",parent="button",width=190,horizontal_align="left",font_color={0.95,0.95,0.95}}
styles.ei_admin_caption={type="label_style",parent="label",font_color={0.94,0.95,0.97},single_line=false}
styles.ei_admin_muted={type="label_style",parent="label",font_color={0.77,0.81,0.85},single_line=false}
styles.ei_admin_heading={type="label_style",parent="bold_label",font_color={0.60,0.88,1}}
styles.ei_admin_field={type="textbox_style",parent="textbox",width=160}

--==============================================================================
-- ESIR FILE MAP
-- owns: revision 03 acidthrower sprites, bearing shifts and visual muzzle anchor
-- loaded_by: prototypes/steam-age/acid-turret/acid.lua
-- cadence: data stage only; native turret states control the accent glow
--==============================================================================
-- blueprint: .codex/esir/blueprints/acidthrower-pressure-jet.md#contract
local art = "__exotic-space-industries-remembrance-graphics-6__/graphics/entities/acidthrower-turret/"
local facings = {"north", "east", "south", "west"}
local projection = math.sqrt(0.5)
-- Blender coordinates: +Y is north. Height is already baked into the head
-- frames; only the fixed bearing's horizontal displacement belongs in shift.
local bearing_x, bearing_y = 0.0014700282, 0.6423900127
-- Fit to the dark outlet/side-rim centres in the shipping atlas, independently
-- of the old model anchor. The height change raises the origin 0.74 native px.
local muzzle_height = 0.87555 * projection
-- Art-only fit: move the complete assembly 5.76 native pixels rearward so
-- its existing sidewall meets the original vanilla covers. No atlas edit.
local rear_offset = 0.18
local base_shifts = {
    north = {0, rear_offset}, east = {-rear_offset, 0},
    south = {0, -rear_offset}, west = {rear_offset, 0},
}
local shifts = {
    north = {bearing_x, -bearing_y + rear_offset},
    east = {bearing_y - rear_offset, bearing_x},
    south = {-bearing_x, bearing_y - rear_offset},
    west = {-bearing_y + rear_offset, -bearing_x},
}

-- These builders describe this model's two different origins and sheet layouts.
-- The shared four-way helper does not retain draw_as_glow on its leaf sprites.
---@param suffix string
---@param index integer
---@return data.Animation
local function base_layer(suffix, index)
    local layer = {filename=art.."acidthrower-base"..suffix..".png",
        width=320, height=320, x=index*320, frame_count=1, scale=0.5, shift=base_shifts[facings[index+1]]}
    if suffix == "_shadow" then layer.draw_as_shadow = true end
    if suffix == "_mask" then layer.flags={"mask"}; layer.apply_runtime_tint=true end
    if suffix == "_glow" then layer.draw_as_glow=true end
    return layer
end

---@param glow boolean
---@param transition "forward"|"backward"|nil
---@return data.RotatedAnimation8Way
local function head_animation(glow, transition)
    local animation = {}
    for _,facing in ipairs(facings) do
        local layers = {}
        for _,suffix in ipairs(glow and {"", "_shadow", "_glow"} or {"", "_shadow"}) do
            local layer = {filename=art.."acidthrower-head"..suffix..".png",
                width=256, height=256, line_length=16, frame_count=1, direction_count=256,
                scale=0.5, shift=shifts[facing], apply_projection=true, counterclockwise=false}
            if suffix == "_shadow" then layer.draw_as_shadow=true end
            if suffix == "_glow" then layer.draw_as_glow=true end
            if transition then
                layer.frame_sequence={1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}
                layer.run_mode=transition
            end
            layers[#layers+1] = layer
        end
        animation[facing] = {layers=layers}
    end
    return animation
end

---@param turret data.FluidTurretPrototype
return function(turret)
    local base, glow = {}, {}
    for index,facing in ipairs(facings) do
        base[facing] = {layers={base_layer("",index-1), base_layer("_shadow",index-1), base_layer("_mask",index-1)}}
        glow[facing] = base_layer("_glow",index-1)
    end
    turret.base_picture = nil
    -- The fixed tanks are tall enough to occlude neighbours. Keep the whole
    -- assembly on the normal object layer so rear entities sort behind it;
    -- secondary order only arranges parts sharing this entity's position.
    turret.graphics_set = {base_visualisation={
        {render_layer="object", secondary_draw_order=1, animation=base},
        {render_layer="object", secondary_draw_order=3, animation=glow,
            enabled_states={"prepared", "starting-attack", "attacking", "ending-attack", "rotate-for-folding"}},
    }}
    -- Native covers stay aligned with the real fluid ports, disappear when a
    -- pipe connects, and supply their own shadows. Draw them above the chassis.
    turret.fluid_box.pipe_covers = pipecoverspictures()
    turret.fluid_box.render_layer = "object"
    turret.fluid_box.secondary_draw_order = 2
    turret.gun_animation_render_layer = "object"
    turret.gun_animation_secondary_draw_order = 4
    turret.folded_animation = head_animation(false)
    turret.preparing_animation = head_animation(false,"forward")
    turret.prepared_animation = head_animation(true)
    turret.attacking_animation = head_animation(true)
    turret.ending_attack_animation = head_animation(true)
    turret.folding_animation = head_animation(false,"backward")
    -- The old active image duplicated the entire diffuse gun additively. Only
    -- the isolated glass AOV glows now; diffuse art is identical in every state.
    turret.muzzle_animation = nil
    turret.muzzle_light = nil
    for _,state in ipairs{"folded","preparing","prepared","attacking","ending_attack","folding"} do
        turret[state.."_muzzle_animation_shift"] = nil
        turret[state.."_muzzle_animation"] = nil
    end
    turret.not_enough_fuel_indicator_picture = nil
    turret.not_enough_fuel_indicator_light = nil
    turret.enough_fuel_indicator_picture = nil
    turret.enough_fuel_indicator_light = nil
    local attack = turret.attack_parameters
    attack.gun_center_shift = {}
    for _,facing in ipairs(facings) do
        attack.gun_center_shift[facing] = {shifts[facing][1], shifts[facing][2]-muzzle_height}
    end
    -- The lip is slightly ahead of the old bore anchor. Keep the native source
    -- at the opening instead of burying the first visible bead in the sleeve.
    attack.gun_barrel_length = 0.835
    attack.ammo_type.action.action_delivery.source_offset = {0,0}
end

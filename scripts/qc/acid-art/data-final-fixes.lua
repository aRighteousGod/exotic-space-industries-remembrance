local original = data.raw["fluid-turret"]["ei-acidthrower-turret"]
assert(original.rotation_speed==0.015 and original.preparing_speed==0.08 and original.folding_speed==0.08)
assert(original.attack_parameters.range==38 and original.attack_parameters.min_range==9)
assert(math.abs(original.attack_parameters.turn_range-0.8/3)<1e-10)
assert(original.selection_box[1][1]==-1 and original.selection_box[2][2]==1.5)
assert(original.fluid_box.pipe_connections[1].position[1]==-0.5)
assert(original.fluid_box.pipe_connections[2].position[1]==0.5)
assert(original.fluid_buffer_size==100 and original.activation_buffer_ratio==0.25)
for _,state in ipairs{"folded","preparing","prepared","attacking","ending_attack","folding"} do
    for _,facing in ipairs{"north","east","south","west"} do
        local layers=original[state.."_animation"][facing].layers
        assert(layers[1].direction_count==256 and layers[1].apply_projection)
        assert(layers[1].filename==original.folded_animation[facing].layers[1].filename)
    end
end
assert(original.muzzle_animation==nil and original.muzzle_light==nil)
assert(#original.graphics_set.base_visualisation==2)
assert(original.fluid_box.pipe_covers.north.layers[1].filename=="__base__/graphics/entity/pipe-covers/pipe-cover-north.png")
assert(original.fluid_box.render_layer=="object" and original.fluid_box.secondary_draw_order==2)
assert(original.graphics_set.base_visualisation[1].render_layer=="object" and original.graphics_set.base_visualisation[1].secondary_draw_order==1)
assert(original.graphics_set.base_visualisation[2].render_layer=="object" and original.graphics_set.base_visualisation[2].secondary_draw_order==3)
assert(original.gun_animation_render_layer=="object" and original.gun_animation_secondary_draw_order==4)
-- Side-by-side regression fixture retains only the former draw-order fields.
local previous=table.deepcopy(original)
previous.name="esir-acid-art-old-draw-order"
previous.minable=nil;previous.placeable_by=nil;previous.next_upgrade=nil
for _,visual in ipairs(previous.graphics_set.base_visualisation) do visual.render_layer="lower-object-above-shadow" end
previous.fluid_box.render_layer="lower-object-above-shadow"
previous.gun_animation_secondary_draw_order=1
data:extend{previous}
local probe=table.deepcopy(original)
probe.name="esir-acid-art-probe"
probe.minable=nil;probe.placeable_by=nil;probe.next_upgrade=nil
-- State markers exist only in this isolated helper clone. Native 2.0.77 does
-- not expose the current turret animation state through LuaEntity.
for index,state in ipairs{"folded","preparing","prepared","starting-attack","attacking","ending-attack","rotate-for-folding","folding"} do
    probe.graphics_set.base_visualisation[#probe.graphics_set.base_visualisation+1]={
        render_layer="higher-object-above",enabled_states={state},
        animation={filename="__core__/graphics/white-square.png",width=1,height=1,
            scale=8,shift={-1.05+(index-1)*0.3,1.3},draw_as_glow=true}}
end
probe.attack_parameters.ammo_type.action.action_delivery.source_effects={{type="script",effect_id="acid-art-launch"}}
local target=table.deepcopy(data.raw["ammo-turret"]["gun-turret"])
target.name="esir-acid-art-target";target.max_health=100000000
target.minable=nil;target.next_upgrade=nil;target.placeable_by=nil
data:extend{probe,target}
log("ACID_ART_DATA all_pass=true directions=256 footprint=2x3 vanilla_pipe_covers=true")

-- Diagnostic clones only. Contract and lifecycle: README.md#contract.
local contract = require("contract")
local original = assert(data.raw["ammo-turret"]["ei-gatling-turret"])
local states = {"folded_animation", "preparing_animation", "prepared_animation", "attacking_animation", "folding_animation"}

local function leaf(name, rotated)
    local result = {filename="__zzz-esir-minigun-color__/graphics/"..name..".png",
        width=contract.width,height=contract.height,frame_count=1,line_length=1}
    if rotated then result.direction_count=1; result.apply_projection=true; result.counterclockwise=false end
    return result
end

for _, placement in ipairs{"base", "state", "base-state"} do
    for _, variant in ipairs{"ordinary", "glow", "reference", "identity-ordinary", "identity-glow", "identity-reference"} do
        local turret = table.deepcopy(original)
        turret.name="mg-delta-"..placement.."-"..variant
        turret.minable=nil;turret.base_picture=nil;turret.turret_base_has_direction=false
        turret.random_animation_offset=false;turret.graphics_set={base_visualisation={}}
        turret.gun_animation_render_layer="object";turret.gun_animation_secondary_draw_order=2
        local is_reference=variant:find("reference",1,true)~=nil
        local identity=variant:find("identity",1,true)~=nil
        local base_layers, state_layers = {}, {}
        local under_base=placement~="state"
        local under=leaf(is_reference and not identity and "reference" or "under",not under_base)
        if under_base then base_layers[#base_layers+1]=under else state_layers[#state_layers+1]=under end
        if not is_reference then
            local rotated=placement~="base"
            local layers=rotated and state_layers or base_layers
            if not identity then layers[#layers+1]=leaf("normal",rotated) end
            local multiplier=leaf(identity and "identity" or "multiplier",rotated)
            multiplier.blend_mode="multiplicative-with-alpha"
            multiplier.premul_alpha=false
            multiplier.draw_as_glow=variant:find("glow",1,true)~=nil
            layers[#layers+1]=multiplier
            if not identity then
                local additive=leaf("additive",rotated)
                additive.blend_mode="additive";additive.draw_as_glow=false
                layers[#layers+1]=additive
            end
        end
        for order, layer in ipairs(base_layers) do
            turret.graphics_set.base_visualisation[#turret.graphics_set.base_visualisation+1]={
                render_layer="object",secondary_draw_order=order-5,animation=layer}
        end
        -- An empty table is parsed as one visualisation record, which requires
        -- animation. The state-only diagnostic deliberately has no base record.
        if #base_layers==0 then turret.graphics_set.base_visualisation=nil end
        if #state_layers==0 then
            state_layers={ {filename="__core__/graphics/empty.png",width=1,height=1,frame_count=1,direction_count=1} }
        end
        for _,name in ipairs(states) do turret[name]={layers=table.deepcopy(state_layers)} end
        turret.starting_attack_animation=nil;turret.ending_attack_animation=nil
        data:extend{turret}
    end
end
data:extend{
    {type="simple-entity",name="mg-delta-background",flags={"not-on-map"},render_layer="ground-patch",
        collision_box={{0,0},{0,0}},picture={filename="__zzz-esir-minigun-color__/graphics/background.png",width=512,height=512}},
    {type="simple-entity",name="mg-delta-foreground",flags={"not-on-map"},render_layer="object",secondary_draw_order=100,
        collision_box={{0,0},{0,0}},picture={filename="__zzz-esir-minigun-color__/graphics/foreground.png",width=192,height=128}},
    {type="simple-entity",name="mg-delta-fx",flags={"not-on-map"},render_layer="object",secondary_draw_order=101,
        collision_box={{0,0},{0,0}},picture={filename="__zzz-esir-minigun-color__/graphics/fx.png",width=192,height=128,draw_as_glow=true}}
}

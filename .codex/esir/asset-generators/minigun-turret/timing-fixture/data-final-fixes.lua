local art = "__zzz-esir-minigun-timing__/graphics/"
local original = data.raw["ammo-turret"]["ei-gatling-turret"]
assert(original and original.attack_parameters.cooldown == 0.25)
local advanced=require("test-config").advanced
local glow=require("test-config").glow
local variants = glow and {{"legacy",20},{"glow1",20,1},{"glow8",20,1/8}} or advanced and {{"legacy",20},{"native16",20,1},{"leaf16",20,1/16},{"leaf001",20,0.001},
    {"start16",1/16,1,true},{"start20",20,1,true},{"random20",20,1,false,true}}
    or {{"legacy",20},{"speed20",20},{"speed16",1/16},{"speed32",1/32},{"speed8",1/8}}
local function visual(state, attack, transition)
    local color = {width=64,height=32,frame_count=attack and 16 or 1,direction_count=256,
        line_length=16,scale=1,shift={0,0},apply_projection=true,counterclockwise=false}
    if attack then
        color.stripes={}
        for index=0,15 do color.stripes[#color.stripes+1]={filename=art.."attack-"..index..".png",width_in_frames=16,height_in_frames=16} end
    else color.filename=art..state..".png" end
    local shadow={filename=art.."shadow.png",width=64,height=32,frame_count=1,direction_count=256,
        line_length=16,scale=1,shift={0,0},apply_projection=true,counterclockwise=false,draw_as_shadow=true}
    if attack then shadow.repeat_count=16 end
    if transition then
        color.frame_sequence={1,1,1,1,1,1,1,1};shadow.frame_sequence={1,1,1,1,1,1,1,1}
        color.run_mode=transition;shadow.run_mode=transition
    end
    return {layers={color,shadow}}
end
for _,entry in ipairs(variants) do
    local turret=table.deepcopy(original)
    turret.name="mg-timing-"..entry[1]
    turret.minable=nil
    turret.attacking_speed=entry[2]
    if glow and entry[1]~="legacy" then
        -- Preserve native state/frame/direction counts while making old art
        -- transparent, so a glow marker cannot be hidden under the body.
        local function blank(node)
            if node.layers then for _,layer in ipairs(node.layers) do blank(layer) end
            else
                node.filename=art.."blank.png";node.stripes=nil
                node.width=1;node.height=1;node.line_length=8;node.shift={0,0}
            end
        end
        for _,field in ipairs({"folded_animation","preparing_animation","prepared_animation","attacking_animation","folding_animation"}) do
            if turret[field] then blank(turret[field]) end
        end
        turret.energy_glow_animation=visual("attacking",true).layers[1]
        turret.energy_glow_animation.animation_speed=entry[3]
        turret.energy_glow_animation.blend_mode="normal"
        turret.energy_glow_animation.draw_as_glow=false
        turret.energy_glow_animation.draw_as_light=false
        turret.energy_glow_animation_flicker_strength=0
        turret.glow_light_intensity=0
    elseif entry[1]~="legacy" then
        turret.attacking_animation=visual("attacking",true)
        if advanced then
            turret.attacking_animation.layers[1].animation_speed=entry[3] or 1
            turret.attacking_animation.layers[2].animation_speed=entry[3] or 1
            turret.attack_from_start_frame=entry[4] or false
            turret.random_animation_offset=entry[5] or false
        else
            turret.folded_animation=visual("folded")
            turret.preparing_animation=visual("preparing",false,"forward")
            turret.prepared_animation=visual("prepared")
            turret.folding_animation=visual("folding",false,"backward")
        end
    end
    data:extend{turret}
end
data:extend{{type="simple-entity-with-owner",name="mg-timing-target",
    icon="__base__/graphics/icons/wood.png",icon_size=64,max_health=1000000000,
    flags={"placeable-player","placeable-enemy"},is_military_target=true,
    collision_box={{-1,-1},{1,1}},selection_box={{-1,-1},{1,1}},
    picture={filename="__core__/graphics/empty.png",width=1,height=1}}}
local function list(node) return node.type and {node} or node end
local ammo=data.raw.ammo["piercing-rounds-magazine"]
local kinds=ammo.ammo_type.action and {ammo.ammo_type} or ammo.ammo_type
local observed=0
for _,kind in ipairs(kinds) do
    if not kind.source_type or kind.source_type=="default" or kind.source_type=="turret" then
        -- One independent source-only action observes ammunition use once.
        -- Final ammunition also contains spider bookkeeping deliveries; counting
        -- every delivery would multiply launches and mutate single-effect tables.
        kind.action=list(kind.action)
        kind.action[#kind.action+1]={type="direct",action_delivery={type="instant",
            source_effects={{type="script",effect_id="mg-timing-launch"}}}}
        observed=observed+1
    end
end
assert(observed==1,"Fixture requires exactly one launch observer per selected ammo shot; observed="..observed.."; ammo="..serpent.line(ammo.ammo_type))
log("MINIGUN_TIMING_DATA_READY "..serpent.line({variants=variants,ammo=ammo.magazine_size,ballistic=require("test-config").ballistic}))

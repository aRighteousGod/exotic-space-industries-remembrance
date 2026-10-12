-- Disposable shadow union gate. Every visible tested leaf is draw_as_shadow.
-- Lifecycle and ownership: README.md#contract in this helper directory.
local contract = require("contract")
local original = assert(data.raw["ammo-turret"]["ei-gatling-turret"])
local states = {"folded_animation","preparing_animation","prepared_animation",
    "attacking_animation","folding_animation"}
local shadow_leaves = {}

local function audit(source, owner)
    if source.layers then
        for _, child in ipairs(source.layers) do audit(child, owner) end
    else
        shadow_leaves[#shadow_leaves+1] = {owner=owner,draw_as_shadow=source.draw_as_shadow,
            flags=table.deepcopy(source.flags or {}),filename=source.filename,filenames=source.filenames,
            x=source.x or 0,y=source.y or 0,width=source.width,height=source.height,
            direction_count=source.direction_count,frame_count=source.frame_count,
            frame_sequence=table.deepcopy(source.frame_sequence or {}),shift=source.shift,scale=source.scale,
            line_length=source.line_length,slice=source.slice,lines_per_file=source.lines_per_file,
            apply_projection=source.apply_projection,counterclockwise=source.counterclockwise}
    end
end

local function selected(source,pose)
    assert(source.draw_as_shadow == true,"Shadow fixture received a color leaf")
    local leaf = table.deepcopy(source)
    leaf.frame_sequence = {pose+1}
    leaf.repeat_count = 1
    leaf.run_mode = "forward"
    return leaf
end

local function turret(name,animation,base)
    local result = table.deepcopy(original)
    result.name = name
    result.minable = nil
    result.base_picture = nil
    result.turret_base_has_direction = false
    result.random_animation_offset = false
    result.graphics_set = {}
    result.gun_animation_render_layer = "object"
    result.gun_animation_secondary_draw_order = 2
    if base then
        base = table.deepcopy(base)
        base.direction_count = nil
        base.apply_projection = nil
        base.counterclockwise = nil
        assert(base.draw_as_shadow == true)
        result.graphics_set = {base_visualisation={{render_layer="object",
            secondary_draw_order=1,animation=base}}}
    end
    for _,state in ipairs(states) do result[state] = table.deepcopy(animation) end
    result.starting_attack_animation = nil
    result.ending_attack_animation = nil
    if base then audit(base,name.."/base") end
    for _,state in ipairs(states) do audit(result[state],name.."/"..state) end
    return result
end

for _,tier in ipairs(contract.tiers) do
    if tier.representation == "combined" then
        local complete = contract.profiles[tier.shadow].shadow
        local profile = contract.profiles[tier.reference]
        local reference = profile.reference
        for pose = 0,27 do
            data:extend{turret("mg-shadow-"..tier.id.."-separated-"..pose,selected(complete,pose))}
            if reference then
                data:extend{turret("mg-shadow-"..tier.id.."-reference-"..pose,selected(reference,pose))}
            end
        end
        for direction, poses in pairs(profile.reference_cells or {}) do
            for pose, leaf in pairs(poses) do
                data:extend{turret("mg-shadow-"..tier.id.."-reference-"..pose.."-d"..direction,selected(leaf,0))}
            end
        end
    else
    local base = contract.profiles[tier.base].base
    local upper = contract.profiles[tier.upper].upper
    local rotor = contract.profiles[tier.shadow].shadow
    local reference = contract.profiles[tier.reference].reference
    for pose = 0,27 do
        data:extend{
            turret("mg-shadow-"..tier.id.."-separated-"..pose,
                {layers={selected(upper,0),selected(rotor,pose)}},base),
            turret("mg-shadow-"..tier.id.."-reference-"..pose,selected(reference,pose)),
        }
    end
    end
end
for _,alpha in ipairs{0,128,255} do
    local leaf = {filename="__zzz-esir-minigun-shadow__/graphics/control-"..alpha..".png",
        width=32,height=32,frame_count=1,direction_count=1,draw_as_shadow=true}
    data:extend{turret("mg-shadow-control-"..alpha,leaf)}
end
data:extend{{type="mod-data",name="mg-shadow-texture-audit",data={leaves=shadow_leaves}}}
data:extend{{type="simple-entity",name="mg-shadow-background",flags={"not-on-map"},
    render_layer="ground-patch",collision_box={{0,0},{0,0}},
    picture={filename="__zzz-esir-minigun-shadow__/graphics/background.png",width=1024,height=1024}}}

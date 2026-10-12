-- Disposable frozen native composition fixture; no production prototypes change.
-- Lifecycle and ownership: README.md#contract in this helper directory.
local contract = require("contract")
local original = assert(data.raw["ammo-turret"]["ei-gatling-turret"])
local animations = {"folded_animation", "preparing_animation", "prepared_animation",
    "attacking_animation", "folding_animation"}
local color_leaf_flags = {}

local function audit_flags(source, owner)
    if source.layers then
        for _,child in ipairs(source.layers) do audit_flags(child,owner) end
    else
        color_leaf_flags[#color_leaf_flags+1]={owner=owner,flags=table.deepcopy(source.flags or {}),
            filename=source.filename,filenames=source.filenames}
    end
end

local function selected(source, pose)
    local leaf = table.deepcopy(source)
    leaf.frame_sequence = {pose + 1}
    leaf.repeat_count = 1
    leaf.run_mode = "forward"
    return leaf
end

local function append_selected(layers, source, pose)
    if source.layers then
        for _, child in ipairs(source.layers) do append_selected(layers, child, pose) end
    else
        layers[#layers+1] = selected(source, pose)
    end
end

for profile_name, profile in pairs(contract.profiles) do
    local function add_turret(pose, variant, reference_leaf, direction)
            local turret = table.deepcopy(original)
            turret.name = "mg-color-"..profile_name.."-"..variant.."-"..pose
            if direction ~= nil then turret.name = turret.name.."-d"..direction end
            turret.minable = nil
            turret.base_picture = nil
            turret.turret_base_has_direction = false
            turret.random_animation_offset = false
            turret.graphics_set = {}
            turret.gun_animation_render_layer = "object"
            turret.gun_animation_secondary_draw_order = 2
            local animation
            if variant == "separated" then
                local base = table.deepcopy(profile.base)
                base.direction_count = nil
                base.apply_projection = nil
                base.counterclockwise = nil
                turret.graphics_set = {base_visualisation={{render_layer="object",
                    secondary_draw_order=1,animation=base}}}
                local layers = {}
                append_selected(layers,profile.upper,0)
                append_selected(layers,profile.rotor,pose)
                animation = {layers=layers}
            else
                -- The one-cell reference retains the original atlas rectangle,
                -- dimensions and registration; entity orientation stays unchanged.
                animation = reference_leaf and selected(reference_leaf,0) or selected(profile.reference,pose)
            end
            for _, field in ipairs(animations) do turret[field] = table.deepcopy(animation) end
            turret.starting_attack_animation = nil
            turret.ending_attack_animation = nil
            if turret.graphics_set.base_visualisation then
                audit_flags(turret.graphics_set.base_visualisation[1].animation,turret.name.."/base")
            end
            for _,field in ipairs(animations) do audit_flags(turret[field],turret.name.."/"..field) end
            data:extend{turret}
    end
    for pose = 0, 27 do
        add_turret(pose,"separated")
        if profile.reference then add_turret(pose,"reference") end
    end
    for direction, poses in pairs(profile.reference_cells or {}) do
        for pose, leaf in pairs(poses) do add_turret(pose,"reference",leaf,direction) end
    end
end
data:extend{{type="mod-data",name="mg-color-texture-audit",data={leaves=color_leaf_flags}}}
data:extend{{type="simple-entity", name="mg-color-background", flags={"not-on-map"},
    render_layer="ground-patch", collision_box={{0,0},{0,0}},
    -- Hold the comparison backdrop constant across global DXT modes. The old
    -- compressed backdrop shifted blue110 to108 and obscured cross-run identity.
    picture={filename="__zzz-esir-minigun-color__/graphics/background.png",width=1024,height=1024,
        flags={"not-compressed"}}}}

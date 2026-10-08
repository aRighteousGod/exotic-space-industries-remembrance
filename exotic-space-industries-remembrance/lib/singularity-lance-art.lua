-- blueprint: .codex/esir/blueprints/singularity-lance.md#contract
-- Data-stage artwork constructors. Explicit owner style inputs prevent another
-- weapon's startup fidelity from changing these returned graphics.
local util = require("__core__/lualib/util")
local singularity_lance_config = require("lib/singularity-lance-config")
local module = {}
local function make_prismatic_beam_animation(path, include_glow, filename, glow_filename, width, height, frame_count, line_length, scale)
    scale = scale or 1

    local animation = {
        layers = {
            {
                filename = path..filename,
                width = width,
                height = height,
                frame_count = frame_count,
                line_length = line_length,
                animation_speed = 0.55,
                scale = scale,
                draw_as_glow = true,
            },
            {
                filename = path..glow_filename,
                width = width,
                height = height,
                frame_count = frame_count,
                line_length = line_length,
                animation_speed = 0.55,
                scale = scale,
                draw_as_glow = true,
                blend_mode = "additive-soft",
            },
        },
    }
    if not include_glow then animation.layers[2] = nil end
    return animation
end

function module.base_graphics(path, scale, options, include_glow)
    options = options or {}

    local body = make_prismatic_beam_animation(path, include_glow,
        "singularity-lance-beam-body.png",
        "singularity-lance-beam-body-glow.png",
        256,
        96,
        16,
        4,
        scale
    )
    local head = make_prismatic_beam_animation(path, include_glow,
        "singularity-lance-beam-head.png",
        "singularity-lance-beam-head-glow.png",
        192,
        160,
        16,
        4,
        scale
    )
    local tail = make_prismatic_beam_animation(path, include_glow,
        "singularity-lance-beam-tail.png",
        "singularity-lance-beam-tail-glow.png",
        192,
        160,
        16,
        4,
        scale
    )
    local impact = options.impact_ending and make_prismatic_beam_animation(path, include_glow,
        "singularity-lance-impact-prism.png",
        "singularity-lance-impact-prism-glow.png",
        256,
        256,
        24,
        6,
        scale
    ) or nil

    return {
        beam = {
            start = table.deepcopy(tail),
            ending = impact or table.deepcopy(head),
            head = head,
            tail = tail,
            body = {body},
            render_layer = "projectile",
        },
        ground = {
            head = util.empty_sprite(),
            tail = util.empty_sprite(),
            body = util.empty_sprite(),
        },
        desired_segment_length = 1,
        transparent_start_end_animations = true,
        random_end_animation_rotation = false,
        randomize_animation_per_segment = false,
    }
end

function module.beam(name, width, light, graphics_set, working_sound)
    local beam = table.deepcopy(data.raw.beam["laser-beam"])
    beam.name = name
    beam.width = width
    -- BeamPrototype has no LightDefinition field. Illuminate terrain through
    -- the native ground animation layer, independently of the bright beam art.
    beam.light = nil
    local ground = table.deepcopy(data.raw.beam["laser-beam"].graphics_set.ground)
    local size = light.size / singularity_lance_config.presentation.ground_light_reference_size
    local intensity = math.min(1, light.intensity)
    for _, part in ipairs({"head", "tail", "body"}) do
        local mask = ground[part]
        mask.scale = mask.scale * size
        mask.tint = {r = light.color.r * intensity, g = light.color.g * intensity,
            b = light.color.b * intensity, a = 1}
        if mask.shift then mask.shift = {mask.shift[1] * size, mask.shift[2] * size} end
    end
    graphics_set.ground = ground
    beam.hidden = true
    beam.hidden_in_factoriopedia = true
    beam.damage_interval = 60
    beam.random_target_offset = false
    beam.target_offset = {0, 0}
    beam.action = nil
    beam.working_sound = working_sound
    beam.graphics_set = graphics_set
    beam.head = nil
    beam.tail = nil
    beam.body = nil

    return beam
end

---@return data.Animation
function module.upgrade_animation(art_path, include_glow, key, width, height, frames, columns, scale, speed)
    local semantic = {filename = art_path .. key .. ".png", width = width, height = height,
        frame_count = frames, line_length = columns, scale = scale, animation_speed = speed,
        flags = {"no-crop"}, draw_as_glow = true}
    local glow = table.deepcopy(semantic)
    glow.filename, glow.blend_mode = art_path .. key .. "-glow.png", "additive-soft"
    return {layers = include_glow and {glow, semantic} or {semantic}}
end


---@return data.BeamPrototype
function module.material(base, art_path, art, shape, include_glow)
    local beam = table.deepcopy(base)
    local function animation(key, width, height)
        return module.upgrade_animation(art_path, include_glow, "beam-" .. shape .. "-" .. key,
            width, height, art.beam_frames, 4, art.beam_scale, art.beam_speed)
    end
    beam.graphics_set.beam = {start = animation("start", 192, 160),
        ending = beam.graphics_set.beam.ending, head = animation("head", 192, 160),
        tail = animation("tail", 192, 160), body = {animation("body", 256, 96)}, render_layer = "projectile"}
    beam.action, beam.working_sound = nil, nil
    return beam
end

function module.rescale(node, factor)
    if type(node) ~= "table" then return end
    if node.filename then
        node.scale = (node.scale or 1) * factor
        if node.shift then node.shift = {node.shift[1] * factor, node.shift[2] * factor} end
    end
    for _, child in pairs(node) do if type(child) == "table" then module.rescale(child, factor) end end
end
return module

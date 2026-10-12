--==============================================================================
-- ESIR FILE MAP
-- owns: minigun SD/HD profile selection, native state layers and muzzle metadata
-- loaded_by: prototypes/electricity-age/gatling-turret.lua
-- cadence: data stage only; native turret states own all animation progress
--==============================================================================
-- blueprint: .codex/esir/blueprints/minigun-turret-graphics.md#contract

---@class ESIRMinigunGraphicsProfile
---@field base data.Animation
---@field upper data.RotatedAnimation
---@field rotor data.RotatedAnimation
---@field shadow? data.RotatedAnimation Complete combined ground mask.
---@field shadows? {base: data.Animation, upper: data.RotatedAnimation, rotor: data.RotatedAnimation}
---@field shadow_representation "combined"|"alpha_over_residual"
---@field shadow_native_eligible? boolean Residuals require native evidence outside isolated fixtures.
---@field complete_families boolean All physical poses and all declared directions are present.
---@field rotor_representation? "single_leaf"|"vertical_strips_4"
---@field rotor_native_eligible? boolean Exact native evidence for additional rotor child rectangles.
---@field item_icon string
---@field item_icon_size integer
---@field technology_icon string
---@field technology_icon_size integer

---@class ESIRMinigunLaunchField
---@field present boolean False preserves the measured absence of a prototype field.
---@field value? data.Vector|number|boolean

---@class ESIRMinigunLaunchContract
---@field projectile_center ESIRMinigunLaunchField
---@field projectile_creation_distance ESIRMinigunLaunchField
---@field apply_projection_to_projectile_creation_position ESIRMinigunLaunchField

---@class ESIRMinigunGraphicsData
---@field schema string
---@field hd_major integer
---@field profiles {sd: ESIRMinigunGraphicsProfile, hd: ESIRMinigunGraphicsProfile}
---@field projectile_creation_parameters data.CircularProjectileCreationSpecification
---@field preparing_ticks integer
---@field folding_ticks integer
---@field native_launch_contract? ESIRMinigunLaunchContract Required outside explicit fixtures.
---@field provenance table Finalizer receipt and full atlas/native evidence lineage.
---@field muzzle_proposal table Geometry proposal becomes calibrated only after finalization.

---@class ESIRMinigunGraphicsIcons
---@field item {icon: string, icon_size: integer}
---@field technology {icon: string, icon_size: integer}

---@class ESIRMinigunGraphics
---@field icons fun(): ESIRMinigunGraphicsIcons
---@field creation_parameters fun(): data.CircularProjectileCreationSpecification
---@field apply fun(turret: data.AmmoTurretPrototype)

---@class ESIRMinigunGraphicsOptions
---@field fixture? boolean Explicitly permits a partial direction family for isolated QC.
---@field direction_count? integer Production requires 256; fixture directions must divide 256.

---@class ESIRMinigunGraphicsFactory
---@field create fun(metadata?: ESIRMinigunGraphicsData, enabled_mods?: table<string, string>, options?: ESIRMinigunGraphicsOptions): ESIRMinigunGraphics

---@type ESIRMinigunGraphicsFactory
local factory = {}

-- Defer generated asset loading until construction so isolated fixtures can use
-- helper-local metadata without promoting pilot sheets into shipping graphics.
---@param metadata? ESIRMinigunGraphicsData
---@param enabled_mods? table<string, string>
---@param options? ESIRMinigunGraphicsOptions
---@return ESIRMinigunGraphics
function factory.create(metadata, enabled_mods, options)
    options = options or {}
    local direction_count = options.direction_count or 256
    assert(type(direction_count) == "number" and direction_count >= 1 and direction_count <= 256
        and direction_count % 1 == 0 and 256 % direction_count == 0,
        "ESIR minigun graphics: invalid direction count")
    assert(direction_count == 256 or options.fixture == true,
        "ESIR minigun graphics: partial direction families are restricted to explicit fixtures")
    ---@type ESIRMinigunGraphicsData
    local art = metadata or require("prototypes/electricity-age/gatling-turret/graphics-data")
    assert(art.schema == "esir.minigun.graphics.v2", "ESIR minigun graphics: unsupported metadata schema")
    assert(art.hd_major == 1, "ESIR minigun graphics: unsupported HD metadata major version")
    local preparing_ticks = {[12] = true, [18] = true, [24] = true, [30] = true, [36] = true, [45] = true}
    assert(preparing_ticks[art.preparing_ticks] and art.folding_ticks == 18,
        "ESIR minigun graphics: unsupported preparing duration or folding duration other than 18 ticks")
    assert(type(art.projectile_creation_parameters) == "table" and #art.projectile_creation_parameters == 256,
        "ESIR minigun graphics: expected 256 projectile creation directions")
    for index = 1, 256 do
        local entry = art.projectile_creation_parameters[index]
        assert(type(entry) == "table" and entry[1] == (index - 1) / 256 and type(entry[2]) == "table",
            "ESIR minigun graphics: projectile creation ordering changed")
        for axis = 1, 2 do
            local coordinate = entry[2][axis]
            assert(type(coordinate) == "number" and coordinate > -math.huge and coordinate < math.huge,
                "ESIR minigun graphics: projectile creation coordinates must be finite")
        end
    end

    -- blueprint-ref: .codex/esir/blueprints/minigun-turret-graphics.md#muzzle-alignment
    -- Draft metadata remains usable only by explicit isolated fixtures. Shipping
    -- must consume the finalizer's calibrated full atlas and acceptance receipt.
    if options.fixture ~= true then
        local provenance = art.provenance or {}
        local receipt = provenance.finalization_evidence or {}
        local muzzle = art.muzzle_proposal or {}
        assert(provenance.status == "native_accepted_ready_for_staged_integration"
            and provenance.complete_direction_family == true and provenance.muzzle_native_calibrated == true
            and muzzle.native_calibrated == true and muzzle.height_compensation_verified == true
            and receipt.schema == "esir.minigun.finalization-receipt.v1" and receipt.ready_for_staged_integration == true,
            "ESIR minigun graphics: finalizer-produced native-calibrated metadata is required")
        assert(type(provenance.direction_indices) == "table" and #provenance.direction_indices == 256,
            "ESIR minigun graphics: expected complete 256-direction provenance")
        for index = 1, 256 do
            assert(provenance.direction_indices[index] == index - 1,
                "ESIR minigun graphics: provenance direction ordering changed")
        end
        assert(type(art.native_launch_contract) == "table",
            "ESIR minigun graphics: measured native launch contract missing")
    end
    local launch_fields = {"projectile_center", "projectile_creation_distance",
        "apply_projection_to_projectile_creation_position"}
    if art.native_launch_contract then
        for _, key in ipairs(launch_fields) do
            local field = art.native_launch_contract[key]
            assert(type(field) == "table" and type(field.present) == "boolean",
                "ESIR minigun graphics: invalid measured launch field "..key)
            local value = field.value
            if not field.present then
                assert(value == nil, "ESIR minigun graphics: absent launch field carries a value: "..key)
            elseif key == "projectile_center" then
                assert(type(value) == "table" and #value == 2, "ESIR minigun graphics: invalid projectile center")
                for axis = 1, 2 do
                    assert(type(value[axis]) == "number" and value[axis] > -math.huge and value[axis] < math.huge,
                        "ESIR minigun graphics: projectile center must be finite")
                end
            elseif key == "projectile_creation_distance" then
                assert(type(value) == "number" and value >= 0 and value < math.huge,
                    "ESIR minigun graphics: invalid projectile creation distance")
            else
                assert(type(value) == "boolean", "ESIR minigun graphics: invalid launch projection flag")
            end
        end
    end

    -- blueprint-ref: .codex/esir/blueprints/minigun-turret-graphics.md#profile-selection
    -- Profile selection happens once during prototype loading. An incompatible HD
    -- pack must fail explicitly instead of silently mixing two atlas contracts.
    local profile_name = "sd"
    local hd_version = (enabled_mods or mods or {})["minigun-turret-HD"]
    if hd_version then
        local hd_major = tonumber(hd_version:match("^(%d+)%.") or "")
        assert(hd_major == art.hd_major,
            "ESIR minigun graphics: graphics-hd "..hd_version.." is incompatible; expected major "..art.hd_major)
        profile_name = "hd"
    end

    ---@type ESIRMinigunGraphicsProfile
    local profile = assert(art.profiles[profile_name], "ESIR minigun graphics: missing "..profile_name.." profile")
    assert(profile.base.frame_count == 1 and profile.upper.frame_count == 1,
        "ESIR minigun graphics: base and upper atlases must contain one frame per direction")
    assert(profile.complete_families == true,
        "ESIR minigun graphics: profile must declare complete physical pose families")
    local direction_layers = {profile.upper}
    local rotor_leaves = {}
    -- Flatten internal atlas children only. Each child keeps its own registration
    -- and physical stride while receiving the same native temporal sequence.
    ---@param source data.RotatedAnimation
    local function collect_rotor_leaves(source)
        if source.layers then
            assert(not source.filename and not source.filenames and #source.layers > 0,
                "ESIR minigun graphics: malformed rotor child container")
            for _, child in ipairs(source.layers) do collect_rotor_leaves(child) end
        else
            assert(source.frame_count == 28,
                "ESIR minigun graphics: every rotor child requires 28 physical frames")
            rotor_leaves[#rotor_leaves + 1] = source
            direction_layers[#direction_layers + 1] = source
        end
    end
    collect_rotor_leaves(profile.rotor)
    if profile.rotor.layers then
        assert(profile.rotor_representation == "vertical_strips_4" and #rotor_leaves == 4,
            "ESIR minigun graphics: expected exactly four rotor strip leaves")
        assert(options.fixture == true or profile.rotor_native_eligible == true,
            "ESIR minigun graphics: rotor strip composition has not passed its native gate")
    else
        assert(#rotor_leaves == 1, "ESIR minigun graphics: invalid rotor family")
    end
    if profile.shadow_representation == "combined" then
        assert(profile.shadow and profile.shadow.frame_count == 28 and not profile.shadows,
            "ESIR minigun graphics: combined shadows require exactly one 28-frame ground mask")
        direction_layers[#direction_layers + 1] = profile.shadow
    elseif profile.shadow_representation == "alpha_over_residual" then
        assert(profile.shadows and not profile.shadow and profile.shadows.base.frame_count == 1
            and profile.shadows.upper.frame_count == 1 and profile.shadows.rotor.frame_count == 28,
            "ESIR minigun graphics: residual shadows require complete base, upper and rotor families")
        assert(options.fixture == true or profile.shadow_native_eligible == true,
            "ESIR minigun graphics: residual shadow composition has not passed its native gate")
        direction_layers[#direction_layers + 1] = profile.shadows.upper
        direction_layers[#direction_layers + 1] = profile.shadows.rotor
    else
        error("ESIR minigun graphics: unsupported or missing shadow representation")
    end
    for _, layer in ipairs(direction_layers) do
        assert(layer.direction_count == nil or layer.direction_count == direction_count,
            "ESIR minigun graphics: atlas direction count does not match the selected production/fixture contract")
    end

    -- Frame 1 is parked; frame 2 is the steady 90-degree exposure. Reusing these
    -- exact images at transition endpoints prevents a fresh render from flickering.
    -- Keep the physical frame_count/packing metadata: frame_sequence controls only
    -- the logical animation length, including when a state uses just one frame.
    local parked = {1}
    local running = {2}
    local preparing = {1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 2}
    local folding = {2, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 1}

    ---@param source data.RotatedAnimation
    ---@param sequence integer[]
    ---@param repetitions integer
    ---@return data.RotatedAnimation
    local function state_layer(source, sequence, repetitions)
        local layer = table.deepcopy(source)
        layer.direction_count = direction_count
        layer.apply_projection = true
        layer.counterclockwise = false
        -- Use the already loaded core copier here as well: isolated fixture
        -- mods need not expose ESIR's ei_lib binding in their chunk environment.
        layer.frame_sequence = table.deepcopy(sequence)
        layer.repeat_count = repetitions
        layer.run_mode = "forward"
        return layer
    end

    ---@param sequence integer[]
    ---@return data.RotatedAnimation8Way
    local function state_animation(sequence)
        local layers = {state_layer(profile.upper, parked, #sequence)}
        for _, rotor in ipairs(rotor_leaves) do
            layers[#layers + 1] = state_layer(rotor, sequence, 1)
        end
        if profile.shadow_representation == "combined" then
            -- This mask already contains every part's ground shadow. Drawing a
            -- second fixed-base shadow would darken their overlapping coverage.
            local shadow = state_layer(profile.shadow, sequence, 1)
            shadow.draw_as_shadow = true
            layers[#layers + 1] = shadow
        else
            -- These are solved alpha-over residuals, not isolated caster masks.
            -- Their density combination is frozen by the native-tested profile.
            local upper_shadow = state_layer(profile.shadows.upper, parked, #sequence)
            local rotor_shadow = state_layer(profile.shadows.rotor, sequence, 1)
            upper_shadow.draw_as_shadow = true
            rotor_shadow.draw_as_shadow = true
            layers[#layers + 1] = upper_shadow
            layers[#layers + 1] = rotor_shadow
        end
        return {layers = layers}
    end

    ---@type ESIRMinigunGraphics
    local graphics = {}

    function graphics.icons()
        return {
            item = {icon = profile.item_icon, icon_size = profile.item_icon_size},
            technology = {icon = profile.technology_icon, icon_size = profile.technology_icon_size},
        }
    end

    function graphics.creation_parameters()
        return table.deepcopy(art.projectile_creation_parameters)
    end

    function graphics.apply(turret)
        assert(turret.attack_parameters and turret.attack_parameters.type == "projectile",
            "ESIR minigun graphics: expected projectile attack parameters")
        local base = table.deepcopy(profile.base)
        -- A fixed base is an ordinary Animation, independent of gun direction.
        base.direction_count = nil
        base.apply_projection = nil
        base.counterclockwise = nil
        base.middle_orientation = nil
        base.orientation_range = nil
        base.still_frame = nil
        turret.base_picture = nil
        turret.turret_base_has_direction = false
        turret.graphics_set = turret.graphics_set or {}
        turret.graphics_set.base_visualisation = {{
            render_layer = "object", secondary_draw_order = 1, animation = base,
        }}
        if profile.shadow_representation == "alpha_over_residual" then
            local base_shadow = table.deepcopy(profile.shadows.base)
            base_shadow.direction_count = nil
            base_shadow.apply_projection = nil
            base_shadow.counterclockwise = nil
            base_shadow.middle_orientation = nil
            base_shadow.orientation_range = nil
            base_shadow.still_frame = nil
            base_shadow.draw_as_shadow = true
            turret.graphics_set.base_visualisation[#turret.graphics_set.base_visualisation + 1] = {
                render_layer = "object", secondary_draw_order = 1, animation = base_shadow,
            }
        end
        turret.gun_animation_render_layer = "object"
        turret.gun_animation_secondary_draw_order = 2

        turret.folded_animation = state_animation(parked)
        turret.preparing_animation = state_animation(preparing)
        turret.prepared_animation = state_animation(running)
        turret.attacking_animation = state_animation(running)
        turret.folding_animation = state_animation(folding)
        -- Spin-up belongs to preparation, not to the per-shot attack cycle. Keep
        -- attacking_speed, cooldown and the remaining attack parameters untouched.
        turret.starting_attack_animation = nil
        turret.ending_attack_animation = nil
        turret.preparing_speed = 1 / art.preparing_ticks
        turret.preparing_speed_secondary = 1 / art.preparing_ticks
        turret.folding_speed = 1 / art.folding_ticks
        turret.folding_speed_secondary = 1 / art.folding_ticks

        -- blueprint-ref: .codex/esir/blueprints/minigun-turret-graphics.md#muzzle-alignment
        -- Copy the exact measured table. Re-projecting it or guessing default
        -- center/distance values would invalidate the native firing evidence.
        turret.attack_parameters.projectile_creation_parameters = graphics.creation_parameters()
        if art.native_launch_contract then
            for _, key in ipairs(launch_fields) do
                local field = art.native_launch_contract[key]
                if field.present then
                    turret.attack_parameters[key] = table.deepcopy(field.value)
                else
                    turret.attack_parameters[key] = nil
                end
            end
        end
    end

    return graphics
end

return factory

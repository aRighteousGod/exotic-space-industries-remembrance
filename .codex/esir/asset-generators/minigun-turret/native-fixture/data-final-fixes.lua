-- Disposable native prototype fixture. No shipping prototypes are changed except
-- one source-only observer on fixture ammunition, in this isolated mod set only.
-- Lifecycle and ownership: README.md#contract in this directory.
local contract = require("contract")
local art = "__zzz-esir-minigun-native__/graphics/"
local original = assert(data.raw["ammo-turret"]["ei-gatling-turret"])
assert(original.attack_parameters.cooldown == 0.25 and original.attacking_speed == 20,
    "Baseline combat contract changed; review fixture before running")
local files = {}
for index = 0, 31 do files[#files+1] = art .. string.format("rotor-%02d.png", index) end

---@param sequence uint32[] Physical source indices, one-based.
---@return data.RotatedAnimation
local function rotor(sequence)
    return {filenames=files, width=64, height=32, frame_count=28,
        direction_count=256, slice=7, line_length=7, lines_per_file=32,
        frame_sequence=sequence, repeat_count=1, run_mode="forward",
        apply_projection=true, counterclockwise=false, scale=1, shift={0,-0.5}}
end

---@param sequence uint32[]
---@return data.RotatedAnimation
local function visual(sequence)
    return {layers={
        {filename=art.."upper.png", width=64, height=32, frame_count=1,
            direction_count=256, line_length=16, repeat_count=#sequence,
            apply_projection=true, counterclockwise=false, scale=1, shift={0,0.5}},
        rotor(sequence),
    }}
end

local function base_visualisations()
    local result = {{animation={filename=art.."base.png", width=64, height=16,
        frame_count=1, shift={0,1.25}}, render_layer="lower-object"}}
    for index, state in ipairs(contract.states) do
        result[#result+1] = {enabled_states={state}, render_layer="object",
            animation={filename=art.."state-"..(index-1)..".png", width=64, height=16,
                frame_count=1, shift={0,-1.25}}}
    end
    return result
end

---@param name string
---@return data.AmmoTurretPrototype
local function candidate(name)
    local turret = table.deepcopy(original)
    turret.name = name
    turret.minable = nil
    -- Casings can obscure diagnostic barcode patches. This purely visual
    -- suppression belongs only to fixture clones, never the real firing art.
    turret.attack_parameters.shell_particle = nil
    turret.turret_base_has_direction = false
    turret.random_animation_offset = false
    turret.preparing_speed = 1/12
    turret.preparing_speed_secondary = 1/12
    turret.folding_speed = 1/18
    turret.folding_speed_secondary = 1/18
    turret.starting_attack_animation = nil
    turret.ending_attack_animation = nil
    turret.folded_animation = visual(contract.sequences.parked)
    turret.preparing_animation = visual(contract.sequences.preparing)
    turret.prepared_animation = visual(contract.sequences.running)
    turret.attacking_animation = visual(contract.sequences.running)
    turret.folding_animation = visual(contract.sequences.folding)
    turret.graphics_set = {base_visualisation=base_visualisations()}
    return turret
end

local legacy = table.deepcopy(original)
legacy.name = "mg-native-legacy"
legacy.minable = nil
legacy.attack_parameters.shell_particle = nil
data:extend{legacy, candidate("mg-native-candidate")}
-- This clone makes normally instantaneous per-shot states observable. Its
-- deliberately slower per-shot states are excluded from firing parity checks.
local probe = candidate("mg-native-state-probe")
probe.starting_attack_animation = visual(contract.sequences.running)
probe.ending_attack_animation = visual(contract.sequences.running)
probe.starting_attack_speed = 1/4
probe.starting_attack_speed_secondary = 1/4
probe.ending_attack_speed = 1/4
probe.ending_attack_speed_secondary = 1/4
data:extend{probe}
for pose = 1, 28 do
    local turret = candidate("mg-native-layout-"..pose)
    for _, field in ipairs({"folded_animation","preparing_animation","prepared_animation",
        "attacking_animation","folding_animation"}) do turret[field] = visual({pose}) end
    data:extend{turret}
end

local function shadow(alpha)
    return {filename=art.."alpha-"..alpha..".png",width=32,height=32,
        frame_count=1,direction_count=1,draw_as_shadow=true}
end
for _, entry in ipairs(contract.shadows) do
    local turret = candidate("mg-native-shadow-"..entry[1])
    local a, b = shadow(entry[3]), shadow(entry[4])
    local animation = {layers=entry[5] and {b,a} or {a,b}}
    for _, field in ipairs({"folded_animation","preparing_animation","prepared_animation",
        "attacking_animation","folding_animation"}) do turret[field] = animation end
    local fixed = shadow(entry[2])
    fixed.direction_count = nil -- Animation4Way consumes a plain Animation here.
    turret.graphics_set = {base_visualisation={animation=fixed,render_layer="lower-object"}}
    data:extend{turret}
end
data:extend{
    {type="simple-entity-with-owner",name="mg-native-target",
        icon="__base__/graphics/icons/wood.png",icon_size=64,max_health=1000000000,
        flags={"placeable-player","placeable-enemy"},is_military_target=true,
        collision_box={{-1,-1},{1,1}},selection_box={{-1,-1},{1,1}},
        picture={filename="__core__/graphics/empty.png",width=1,height=1}},
    {type="simple-entity",name="mg-native-background",flags={"not-on-map"},
        render_layer="ground-patch",collision_box={{0,0},{0,0}},
        picture={filename=art.."background.png",width=96,height=96}},
}

-- One additional source-only action observes a shot once, without multiplying
-- the final ammo's separate damage/spider deliveries. This is fixture-only.
local ammo = assert(data.raw.ammo["piercing-rounds-magazine"])
local kinds = ammo.ammo_type.action and {ammo.ammo_type} or ammo.ammo_type
local observers = 0
for _, kind in ipairs(kinds) do
    if not kind.source_type or kind.source_type == "default" or kind.source_type == "turret" then
        if kind.action.type then kind.action = {kind.action} end
        kind.action[#kind.action+1] = {type="direct",action_delivery={type="instant",
            source_effects={{type="script",effect_id="mg-native-launch"}}}}
        observers = observers + 1
    end
end
assert(observers == 1, "Fixture requires one observer on the selected ammo type")
log("MINIGUN_NATIVE_DATA_READY physical=28 directions=256 preparing=12 folding=18 attacking_speed=20")

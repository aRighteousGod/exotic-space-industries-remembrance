-- Disposable QC mod. Only private turret, ammo, projectile and flash clones are
-- modified. The native full-visual branch retains the authored visual fields.
-- Lifecycle and evidence contract: README.md#contract in this directory.
local config = require("test-config")
local empty = {filename="__core__/graphics/empty.png",width=1,height=1}
local audit = {schema=1,ballistic=config.ballistic,profile=config.profile,
    ammo={},flashes={},projectiles={},limitations={},flash_templates={}}
if config.compact_heading_templates then
    for _,role in ipairs{"a","b","c"} do
        data:extend{{type="simple-entity",name="mgf-compact-background-"..role,
            flags={"not-on-map"},render_layer="ground-patch",collision_box={{0,0},{0,0}},
            picture={filename="__zzz-esir-minigun-firing__/graphics/compact-background-"..role..".png",
                width=128,height=128,flags={"not-compressed"}}}}
    end
end

---@param node table|nil
---@return table[]
local function entries(node)
    if not node then return {} end
    return node.type and {node} or node
end

---@param prior table|nil
---@param effect_id string
---@return table[]
local function append_created(prior,effect_id)
    local result = entries(prior)
    result[#result+1] = {type="direct",action_delivery={type="instant",
        target_effects={{type="script",effect_id=effect_id}}}}
    return result
end

local original = assert(data.raw["ammo-turret"]["ei-gatling-turret"])
audit.original_attack = table.deepcopy(original.attack_parameters)
local turret = table.deepcopy(original)
turret.name, turret.minable = "mg-firing-candidate", nil
local mechanical = require("candidate-mechanical-data")
audit.original_circuit_connector = table.deepcopy(original.circuit_connector)
audit.original_shell_particle = table.deepcopy(original.attack_parameters.shell_particle)
if mechanical.circuit_connector then turret.circuit_connector=table.deepcopy(mechanical.circuit_connector) end
if mechanical.shell_particle then turret.attack_parameters.shell_particle=table.deepcopy(mechanical.shell_particle) end
audit.mechanical_status = mechanical.status or "unreviewed_legacy"
audit.connector_anchor_calibrated = mechanical.connector_anchor_calibrated == true
audit.connector_proposal = table.deepcopy(mechanical.connector_proposal)
audit.effective_circuit_connector = table.deepcopy(turret.circuit_connector)
-- The production factory accepts explicit fixture metadata; it does not load a
-- shipping graphics-data module or promote this candidate into the main pack.
local graphics = require("__exotic-space-industries-remembrance__/prototypes/electricity-age/gatling-turret/graphics")
assert(graphics.create,"Candidate graphics factory is not available")
local candidate = graphics.create(require("candidate-graphics-data"),mods,
    {fixture=true,direction_count=config.direction_count})
candidate.apply(turret)
turret.attack_parameters.projectile_creation_parameters = candidate.creation_parameters()
for _,key in ipairs({"projectile_center","apply_projection_to_projectile_creation_position"}) do
    if mechanical[key] ~= nil then turret.attack_parameters[key]=table.deepcopy(mechanical[key]) end
end
audit.effective_attack = table.deepcopy(turret.attack_parameters)
audit.effective_shell_particle = table.deepcopy(turret.attack_parameters.shell_particle)
audit.collision_box, audit.selection_box = turret.collision_box, turret.selection_box
audit.profile_enabled = mods["minigun-turret-HD"] or false
assert(#turret.attack_parameters.projectile_creation_parameters == 256,
    "Firing fixture requires the actual 256-entry candidate launch map")

-- The marker shares the actual color layer's projection convention. Its decoded
-- pixels, not requested heading or launch coordinates, identify rendered views.
local direction_contract
local function inspect_rotated(node)
    if node.layers then for _,leaf in ipairs(node.layers) do inspect_rotated(leaf) end
    elseif node.direction_count and node.direction_count > 1 and not node.draw_as_shadow then
        local actual = {directions=node.direction_count,
            projection=node.apply_projection ~= false,counterclockwise=node.counterclockwise == true}
        assert(actual.directions == config.direction_count, "Candidate direction count differs from staged atlas")
        if direction_contract then
            assert(actual.projection == direction_contract.projection and
                actual.counterclockwise == direction_contract.counterclockwise,
                "Candidate color layers disagree on direction convention")
        else direction_contract = actual end
    end
end
for _,name in ipairs({"folded_animation","preparing_animation","prepared_animation","attacking_animation","folding_animation"}) do
    local animation = assert(turret[name],"Missing candidate animation "..name)
    inspect_rotated(animation)
    assert(direction_contract,"Candidate has no identifiable rotated color layer")
    if not animation.layers then animation = {layers={animation}};turret[name]=animation end
    animation.layers[#animation.layers+1] = {
        filename="__zzz-esir-minigun-firing__/graphics/direction-code.png",
        width=72,height=12,frame_count=1,direction_count=config.direction_count,line_length=16,
        repeat_count=animation.layers[1].repeat_count or 1,
        apply_projection=direction_contract.projection,
        counterclockwise=direction_contract.counterclockwise,shift={0,3},scale=1}
end
audit.direction_contract = direction_contract
data:extend{turret,
    {type="simple-entity-with-owner",name="mg-firing-target",max_health=1000000000,
        icon="__base__/graphics/icons/wood.png",icon_size=64,
        flags={"placeable-player","placeable-enemy"},is_military_target=true,
        collision_box={{-0.1,-0.1},{0.1,0.1}},selection_box={{-0.1,-0.1},{0.1,0.1}},
        picture=table.deepcopy(empty)}}

---@param name string Native source explosion name.
---@param tag string Private ammo/variant identity.
---@param hidden boolean
---@return string
local function flash_clone(name,tag,hidden,ammo_name)
    local id = tag.."-flash-"..name
    if data.raw.explosion[id] then return id end
    local source = assert(data.raw.explosion[name],"Unclassified source visual: "..name)
    if not audit.flash_templates[ammo_name] then
        local templates={}
        local animations=source.animations.filename and {source.animations} or source.animations
        for variation,animation in ipairs(animations) do
            local template=table.deepcopy(source)
            template.name="mgf-template-"..ammo_name.."-"..variation
            template.animations={table.deepcopy(animation)}
            -- Known attachment point: zero height and rotation. Only template
            -- clones lose secondary emissions; all firing variants stay native.
            template.height,template.rotate,template.correct_rotation=0,false,false
            template.created_effect,template.sound=nil,nil
            template.smoke,template.smoke_count,template.explosion_effect,template.beam=nil,0,nil,nil
            templates[#templates+1]={name=template.name,variation=variation,
                original=name,height=0,rotation=0,source_height=source.height or 1,
                source_rotate=source.rotate or false,source_correct_rotation=source.correct_rotation or false}
            data:extend{template}
            if config.heading_templates then
                local heading=table.deepcopy(template)
                heading.name="mgf-heading-template-"..ammo_name.."-"..variation
                heading.rotate,heading.correct_rotation=source.rotate,source.correct_rotation
                templates[#templates].heading_name=heading.name
                data:extend{heading}
                local elevated=table.deepcopy(heading)
                elevated.name="mgf-height-template-"..ammo_name.."-"..variation
                elevated.height=source.height
                templates[#templates].native_height_name=elevated.name
                data:extend{elevated}
            end
        end
        audit.flash_templates[ammo_name]=templates
    elseif audit.flash_templates[ammo_name][1].original~=name then
        error("Multiple source flash families need separate template attribution: "..ammo_name)
    end
    local clone = table.deepcopy(source)
    clone.name = id
    clone.created_effect = append_created(clone.created_effect,"mgf-flash|"..id)
    if hidden then
        clone.animations, clone.light = {table.deepcopy(empty)}, nil
        clone.smoke, clone.smoke_count, clone.explosion_effect, clone.beam = nil,0,nil,nil
        if source.created_effect then
            audit.limitations[#audit.limitations+1]="Source flash has additional created_effect requiring contrast review: "..name
        end
    end
    audit.flashes[id] = {original=name,hidden=hidden,height=source.height or 1,
        animations=table.deepcopy(source.animations),light=table.deepcopy(source.light),
        rotate=source.rotate or false,correct_rotation=source.correct_rotation or false,
        delay=source.delay or 0,delay_deviation=source.delay_deviation or 0,
        scale=source.scale or 1,scale_deviation=source.scale_deviation or 0,
        scale_initial=source.scale_initial or 1,scale_initial_deviation=source.scale_initial_deviation or 0,
        scale_animation_speed=source.scale_animation_speed or false,
        offsets_are_preserved=true}
    data:extend{clone}
    return id
end

---@param name string Native projectile name.
---@param tag string
---@param hidden boolean
---@return string
local function projectile_clone(name,tag,hidden)
    local id = tag.."-projectile-"..name
    if data.raw.projectile[id] then return id end
    local source = assert(data.raw.projectile[name])
    local clone = table.deepcopy(source)
    clone.name = id
    clone.created_effect = append_created(clone.created_effect,"mgf-projectile|"..id)
    if hidden then
        clone.animation, clone.shadow = table.deepcopy(empty), nil
        clone.light, clone.smoke = nil,nil
        if source.created_effect then
            audit.limitations[#audit.limitations+1]="Projectile has additional created_effect requiring contrast review: "..name
        end
    end
    audit.projectiles[id] = {original=name,hidden=hidden,height=source.height or 1,
        animation=table.deepcopy(source.animation),acceleration=source.acceleration,
        max_speed=source.max_speed}
    data:extend{clone}
    return id
end

for _,ammo_name in ipairs(config.ammo_names) do
    local source = assert(data.raw.ammo[ammo_name],"Missing required ammunition "..ammo_name)
    audit.ammo[ammo_name] = {magazine_size=source.magazine_size,
        ammo_type=table.deepcopy(source.ammo_type),variants={}}
    for _,variant in ipairs({"native","flash","projectile","blank"}) do
        local clone = table.deepcopy(source)
        local tag = "mgf-"..ammo_name.."-"..variant
        clone.name, clone.hidden = tag,true
        local summary = {name=tag,source_flashes=0,projectile_deliveries=0,observer_branches=0}
        local kinds = clone.ammo_type.action and {clone.ammo_type} or clone.ammo_type
        for branch,kind in ipairs(kinds) do
            -- Instrument every native source branch once. Factorio selects the
            -- applicable branch; adding an extra observer delivery preserves the
            -- existing native trigger graph and payload multiplicities.
            for _,action in ipairs(entries(kind.action)) do
                for _,delivery in ipairs(entries(action.action_delivery)) do
                    for _,effect in ipairs(entries(delivery.source_effects)) do
                        if effect.type == "create-explosion" or effect.type == "create-entity" then
                            assert(data.raw.explosion[effect.entity_name],
                                "Unclassified source visual needs explicit fixture support: "..effect.entity_name)
                            effect.entity_name = flash_clone(effect.entity_name,tag,
                                variant == "projectile" or variant == "blank",ammo_name)
                            summary.source_flashes = summary.source_flashes + 1
                        elseif effect.type ~= "script" then
                            error("Unclassified source effect: "..effect.type)
                        end
                    end
                    if delivery.type == "projectile" then
                        delivery.projectile = projectile_clone(delivery.projectile,tag,
                            variant == "flash" or variant == "blank")
                        summary.projectile_deliveries = summary.projectile_deliveries + 1
                    elseif delivery.type ~= "instant" then error("Unsupported delivery "..delivery.type) end
                end
            end
            kind.action = entries(kind.action)
            kind.action[#kind.action+1] = {type="direct",action_delivery={type="instant",
                source_effects={{type="script",effect_id="mgf-shot|"..tag.."|"..branch}}}}
            summary.observer_branches = summary.observer_branches + 1
        end
        audit.ammo[ammo_name].variants[variant] = summary
        data:extend{clone}
    end
end
data:extend{{type="mod-data",name="mg-firing-prototype-audit",data=audit}}

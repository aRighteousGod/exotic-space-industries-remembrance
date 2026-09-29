local config = require("test-config")
if not config.baseline then
    local fire=data.raw.fire["ei-singularity-lance-hit-fire"]
    local sticker=data.raw.sticker["ei-singularity-lance-fire-sticker"]
    assert(fire.damage_per_tick.amount==0 and not fire.on_damage_tick_effect,"lance fire is not cosmetic")
    assert(sticker.damage_per_tick.amount==0 and sticker.target_movement_modifier==1
        and sticker.vehicle_speed_modifier==1 and sticker.vehicle_friction_modifier==1,"lance sticker is not cosmetic")
    for _, suffix in ipairs({"-beam","-beam-axial","-beam-testament","-beam-axial-branch","-beam-testament-branch","-impact-beam"}) do
        local name="ei-singularity-lance"..suffix
        local beam=data.raw.beam[name]
        assert(not beam.action and not beam.light,name.." must remain cosmetic and use supported lighting")
        local opening=beam.graphics_set.beam.start.layers
        local shape=suffix:find("axial",1,true) and "axial" or suffix:find("testament",1,true) and "testament"
        local opening_name=shape and "beam-"..shape.."-start" or "singularity-lance-beam-tail"
        assert(#opening==(config.fidelity=="lean" and 1 or 2),name.." wrong source-transition fidelity")
        for _,layer in ipairs(opening) do
            assert(layer.filename:find(opening_name,1,true)
                and layer.width==192 and layer.height==160 and layer.frame_count==16
                and layer.line_length==4 and layer.animation_speed==0.55 and layer.draw_as_glow,
                name.." wrong source transition for beam material")
        end
        local base_opening=data.raw.beam["ei-singularity-lance-beam"..(shape and "-"..shape or "")].graphics_set.beam.start.layers
        if suffix~="-impact-beam" then
            local scale=suffix:find("-branch",1,true) and 0.65 or 1
            for i,layer in ipairs(opening) do
                assert(layer.filename==base_opening[i].filename and layer.blend_mode==base_opening[i].blend_mode
                    and math.abs(layer.scale-base_opening[i].scale*scale)<0.00001,
                    name.." changed opening material or branch scale")
            end
        end
        if shape then
            assert(opening[#opening].filename:find(opening_name..".png",1,true),name.." missing semantic source layer")
            if #opening==2 then
                assert(opening[1].filename:find(opening_name.."-glow.png",1,true)
                    and opening[1].blend_mode=="additive-soft",name.." missing source glow")
            end
            for _,part in ipairs({"head","tail","body"}) do
                local animation=beam.graphics_set.beam[part]
                if part=="body" then animation=animation[1] end
                assert(animation.layers[#animation.layers].filename:find("beam-"..shape.."-"..part..".png",1,true),
                    name.." changed established beam segment "..part)
            end
        end
        assert(beam.graphics_set.desired_segment_length==1 and beam.graphics_set.transparent_start_end_animations
            and not beam.graphics_set.random_end_animation_rotation
            and not beam.graphics_set.randomize_animation_per_segment,name.." changed source segmentation")
        local ending=beam.graphics_set.beam.ending.layers
        assert(#ending==(config.fidelity=="lean" and 1 or 2),name.." wrong impact fidelity")
        assert(ending[1].filename:find("singularity-lance-impact-prism.png",1,true)
            and ending[1].frame_count==24,name.." lost original animated impact bloom")
        for _, part in ipairs({"head","tail","body"}) do
            local mask=beam.graphics_set.ground[part]
            assert(mask.draw_as_light and not mask.draw_as_glow and mask.scale>0
                and mask.tint.r>0 and mask.tint.g>0 and mask.tint.b>0,name.." missing terrain light "..part)
            if suffix~="-impact-beam" then
                local strength=math.min(1,({lean=.60,standard=.85,cinematic=1,maximal=1.20,unbounded=1.45})[config.fidelity])*.25
                assert(math.abs(mask.tint.r-.72*strength)<.000001 and math.abs(mask.tint.g-.35*strength)<.000001
                    and math.abs(mask.tint.b-strength)<.000001,name.." lost subdued violet terrain light")
            end
        end
        log("LANCE_VISUAL_CONTRACT PASS "..name.." matching source material, original bloom and native terrain lighting")
    end
    for _, light in ipairs({"contact-light","afterglow-light"}) do
        local p=data.raw.explosion["ei-singularity-lance-"..light]
        assert(p and not p.created_effect and not p.created_smoke and p.light_intensity_factor_final==0,"light must fade without damage")
        assert(p.animations[1].repeat_count==(light=="contact-light" and 5 or
            ({lean=14,standard=30,cinematic=45,maximal=90,unbounded=180})[config.fidelity]),"native light duration")
        local rgb=light=="contact-light" and {.52,.95,1} or {.48,.88,1}
        assert(p.light.color.r==rgb[1] and p.light.color.g==rgb[2] and p.light.color.b==rgb[3],"cyan contact palette")
    end
    for _, key in ipairs({"collapse-concentrated-warning","collapse-concentrated-impact",
        "testament-concentrated-warning","testament-concentrated-impact","echo-warning","echo-impact"}) do
        local animation=data.raw.animation["ei-singularity-lance-"..key]
        assert(animation and #animation.layers==(config.fidelity=="lean" and 1 or 2),"hybrid core cue missing "..key)
        assert(animation.layers[1].frame_count==(key:find("warning",1,true) and 30 or 12),"hybrid cue timing "..key)
    end
    local keys={"axial-rupture","wound-memory","terminal-collapse","black-hole-testament"}
    local counts={7,8,9,10}
    local age_gates={false,"ei-quantum-age","ei-exotic-age","ei-black-hole"}
    local early={"ei-dark-age-tech","ei-steam-age-tech","ei-electricity-age-tech","ei-computer-age-tech",
        "ei-alien-computer-age-tech","ei-advanced-computer-age-tech"}
    for i,key in ipairs(keys) do
        local name="ei-singularity-lance-"..key
        local tech=data.raw.technology[name]
        local packs={}
        for _,p in ipairs(tech.unit.ingredients) do packs[#packs+1]=p.name or p[1] end
        table.sort(packs)
        assert(#packs==counts[i],name.." wrong pack count")
        local expected=table.deepcopy(early)
        if i<=2 then expected[#expected+1]="space-science-pack" end
        if i>=2 then expected[#expected+1]="ei-quantum-age-tech" end
        if i>=3 then expected[#expected+1]="ei-fusion-quantum-age-tech"; expected[#expected+1]="ei-exotic-age-tech" end
        if i==4 then expected[#expected+1]="ei-black-hole-exotic-age-tech" end
        table.sort(expected)
        assert(table.concat(packs,",")==table.concat(expected,","),name.." wrong finalized science set")
        local prerequisites={}
        for _,p in ipairs(tech.prerequisites) do prerequisites[p]=true end
        assert(prerequisites[i==1 and "ei-singularity-lance" or "ei-singularity-lance-"..keys[i-1]],name.." missing preceding capability")
        if age_gates[i] then assert(prerequisites[age_gates[i]],name.." missing age prerequisite") end
        if i>=3 then for _,p in ipairs(packs) do assert(p~="space-science-pack",name.." incorrectly inherits Space") end end
        if config.no_scaling then assert(tech.unit.count==100*counts[i],name.." bypassed existing no-scaling normalization") end
        log("LANCE_TECH name="..name.." count="..tostring(tech.unit.count).." time="..tech.unit.time
            .." packs="..table.concat(packs,",").." prerequisites="..table.concat(tech.prerequisites,","))
    end
end
local target = table.deepcopy(data.raw["ammo-turret"]["gun-turret"])
target.name, target.max_health, target.healing_per_tick = "lance-qc-target", 10000000, 0
if config.mode == "benchmark" then target.max_health = 1000000000 end -- Keep query populations matched through artificial stress.
target.collision_box = {{-0.25,-0.25},{0.25,0.25}}
target.selection_box = target.collision_box
target.collision_mask = {layers = {}}
target.resistances = {}
target.minable = nil
target.attack_parameters.range = 1
data:extend({target})
local precise = table.deepcopy(target)
precise.name = "lance-qc-precise"
precise.flags = precise.flags or {}
table.insert(precise.flags, "placeable-off-grid")
data:extend({precise})
local resistant = table.deepcopy(target)
resistant.name, resistant.resistances = "lance-qc-resistant", {{type="laser",decrease=100,percent=0}}
local immune = table.deepcopy(target)
immune.name, immune.resistances = "lance-qc-immune", {{type="laser",percent=100}}
local large = table.deepcopy(data.raw.car.car)
large.name, large.max_health, large.resistances = "lance-qc-large", 10000000, {}
large.collision_box, large.collision_mask = {{-0.5,-4},{0.5,4}}, {layers={}}
large.selection_box = table.deepcopy(large.collision_box)
large.is_military_target = true
data:extend({resistant,immune,large})
local power = table.deepcopy(data.raw["electric-energy-interface"]["electric-energy-interface"])
power.name, power.energy_production, power.energy_usage = "lance-qc-power", "100GW", "0W"
power.energy_source.buffer_capacity, power.energy_source.output_flow_limit = "100GJ", "100GW"
local pole = table.deepcopy(data.raw["electric-pole"].substation)
pole.name, pole.supply_area_distance = "lance-qc-pole", 64
data:extend({power,pole})
for _, pair in ipairs({{"unit","behemoth-biter"},{"turret","behemoth-worm-turret"},{"unit-spawner","biter-spawner"}}) do
    local visual = table.deepcopy(data.raw[pair[1]][pair[2]])
    visual.name, visual.max_health = "lance-qc-"..pair[2], 10000000
    visual.resistances = {}
    data:extend({visual})
end
if config.mode == "benchmark" and config.scene ~= "normal-power" and config.scene ~= "wide-native" then
    -- Explicit artificial firing stress, separate from shipped-power results.
    local turret = data.raw["electric-turret"]["ei-singularity-lance"]
    turret.attack_parameters.ammo_type.energy_consumption = "1J"
    turret.energy_source.buffer_capacity, turret.energy_source.input_flow_limit = "1GJ", "1GW"
    turret.energy_source.drain = "0W"
end

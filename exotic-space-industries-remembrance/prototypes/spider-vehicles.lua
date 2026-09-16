--==============================================================================
-- ESIR FILE MAP
-- owns: spider vehicle items, research, weapons, and generated configurations
-- loaded_by: data.lua (declarations), data-final-fixes.lua (resolved variants)
-- cadence: data stage; final pass after compatibility and presentation
-- forwarded_events: none
-- storage_roots: none
-- rebuild_on: data stage reload
--==============================================================================
local catalog = require("lib/spider-vehicles")
local ei_lib = require("lib/lib")
local ei_data = require("lib/data")
local model = {}
local simulation = "advanced-computer-age"
local technology_specs = {}

local function add_technology(name, age, prerequisites, effects, icon)
    technology_specs[name] = {age=age,prerequisites=prerequisites}
    data:extend({{
        type="technology",name=name,icon=icon or "__base__/graphics/technology/spidertron.png",icon_size=256,
        prerequisites=prerequisites,effects=effects or {{type="nothing",effect_description={"technology-description."..name}}},
        unit={count=100,time=20,ingredients=table.deepcopy(ei_data.science[age])},age=age,
        localised_name={"technology-name."..name},localised_description={"technology-description."..name},
        upgrade=name:find("chassis",1,true) ~= nil,order="e-z[spider-vehicles]-"..name,
    }})
end

function model.declare()
    -- The base factory applies the vanilla sprite scale consistently to body and legs.
    create_spidertron{name="ei-scout-spidertron",scale=0.55,leg_scale=1,leg_thickness=1,leg_movement_speed=1}
    local scout=data.raw["spider-vehicle"]["ei-scout-spidertron"]
    local legs=scout.spider_engine.legs
    scout.spider_engine.legs={legs[1],legs[4],legs[7]}
    for index,leg in ipairs(scout.spider_engine.legs) do
        local angle=(index-1)*math.pi*2/3-math.pi/2
        leg.mount_position={math.cos(angle)*0.35,math.sin(angle)*0.35}
        leg.ground_position={math.cos(angle)*1.85,math.sin(angle)*1.85}
        leg.walking_group=index
    end
    scout.guns={}
    for _,resistance in ipairs(scout.resistances) do
        resistance.percent=(resistance.percent or 0)/2
        resistance.decrease=(resistance.decrease or 0)/2
    end
    scout.localised_name={"entity-name.ei-scout-spidertron"}
    local scout_item=table.deepcopy(data.raw["item-with-entity-data"].spidertron)
    scout_item.name="ei-scout-spidertron"
    scout_item.place_result="ei-scout-spidertron"
    scout_item.localised_name=scout.localised_name
    scout_item.order="b[personal-transport]-c[scout-spidertron]"
    data:extend({scout_item,{
        type="recipe",name="ei-scout-spidertron",enabled=false,energy_required=10,
        ingredients={{type="item",name="ei-advanced-motor",amount=20},{type="item",name="ei-steel-mechanical-parts",amount=40},{type="item",name="ei-electronic-parts",amount=20},{type="item",name="ei-energy-crystal",amount=20},{type="item",name="radar",amount=1}},
        results={{type="item",name="ei-scout-spidertron",amount=1}},
    },{
        type="recipe",name="ei-assault-spidertron",enabled=false,energy_required=30,
        ingredients={{type="item",name="tank",amount=1},{type="item",name="ei-steel-mechanical-parts",amount=100},{type="item",name="ei-advanced-motor",amount=100},{type="item",name="ei-high-energy-crystal",amount=40},{type="item",name="processing-unit",amount=40},{type="item",name="ei-simulation-data",amount=100}},
        results={{type="item",name="assault_spidertron",amount=1}},
    },{
        type="item",name=catalog.smoke.charge,icon="__base__/graphics/icons/poison-capsule.png",icon_size=64,stack_size=100,
        subgroup="capsule",order="b[assault-smoke]",
    },{
        type="recipe",name=catalog.smoke.charge,enabled=false,energy_required=5,
        ingredients={{type="item",name="steel-plate",amount=2},{type="item",name="plastic-bar",amount=1},{type="item",name="coal",amount=5}},
        results={{type="item",name=catalog.smoke.charge,amount=1}},
    }})
    local smoke=table.deepcopy(data.raw["smoke-with-trigger"]["poison-cloud"])
    smoke.name="ei-assault-smoke-cloud"
    smoke.action=nil
    smoke.created_effect=nil
    smoke.action_cooldown=nil
    smoke.duration=catalog.smoke.duration
    smoke.particle_count=40
    smoke.particle_spread={6.5,3.9}
    smoke.particle_scale_factor={1.45,1.03}
    smoke.particle_duration_variation=0
    smoke.spread_duration=18
    smoke.spread_duration_variation=6
    smoke.fade_in_duration=12
    smoke.fade_away_duration=60
    smoke.color={r=0.48,g=0.52,b=0.50,a=0.8}
    -- Outer clouds make the suppression area visible without adding damage.
    local bank=table.deepcopy(smoke)
    bank.name="ei-assault-smoke-bank"
    bank.particle_count=12
    bank.particle_spread={3.2,1.9}
    bank.particle_scale_factor={1.2,0.85}
    bank.color={r=0.42,g=0.46,b=0.44,a=0.68}
    smoke.created_effect={{type="cluster",cluster_count=6,distance=4.5,distance_deviation=0.5,
        action_delivery={type="instant",target_effects={{type="create-smoke",entity_name=bank.name,show_in_tooltip=false,initial_height=0}}}}}
    data:extend({smoke,bank,{
        type="sticker",name="ei-assault-smoke-slow",duration_in_ticks=catalog.smoke.interval,
        target_movement_modifier=0.65,single_particle=true,
        animation={filename=ei_lib.empty_sprite(),width=64,height=64},
    }})
    add_technology("ei-spider-vehicles","computer-age",{"ei-computer-age","ei-advanced-motor","ei-electronic-parts","radar"},{{type="unlock-recipe",recipe="ei-scout-spidertron"}})
    add_technology("ei-assault-spidertron",simulation,{"ei-spider-vehicles","ei-advanced-computer-age-tech","tank","flamethrower","ei-high-energy-crystal","processing-unit"},{{type="unlock-recipe",recipe="ei-assault-spidertron"}})
    for level=1,12 do
        local age=level<=2 and "computer-age" or (level<=6 and simulation or "quantum-age")
        local prerequisites={"ei-spider-vehicles"}
        if level>1 then prerequisites[#prerequisites+1]="ei-spider-chassis-"..(level-1) end
        if level==3 then prerequisites[#prerequisites+1]="ei-advanced-computer-age-tech" end
        if level==7 then prerequisites[#prerequisites+1]="ei-quantum-age" end
        add_technology("ei-spider-chassis-"..level,age,prerequisites)
        local technology=data.raw.technology["ei-spider-chassis-"..level]
        local axis=catalog.chassis[(level-1)%6+1]
        local tier=level<=6 and 1 or 2
        technology.localised_name={"spider-vehicles.chassis-upgrade",{"spider-vehicles.chassis-"..axis},tostring(tier)}
        local values={hull={1250,3500},cargo={60,100},fuel={3,4},efficiency={1.15},armor={5},grid={"6x4","10x6","12x6"}}
        if tier==2 then values={hull={1500,4000},cargo={80,120},fuel={4,6},efficiency={1.3},armor={10},grid={"6x6","10x8","12x8"}} end
        for index,value in ipairs(values[axis]) do values[axis][index]=tostring(value) end
        technology.localised_description={"spider-vehicles.chassis-"..axis.."-description",table.unpack(values[axis])}
        technology.effects[1].effect_description=technology.localised_description
    end
    for _,branch in ipairs(catalog.branch_order) do
        for level=1,#catalog.upgrade_names[branch] do
            local age=level<=catalog.simulation_steps[branch] and simulation or "quantum-age"
            local root=(branch=="rocket" or branch=="doeworks") and "spidertron" or "ei-assault-spidertron"
            local prerequisites={root}
            if level>1 then prerequisites[#prerequisites+1]=catalog.weapon_technology(branch,level-1) end
            if age=="quantum-age" then prerequisites[#prerequisites+1]="ei-quantum-age" end
            if branch=="mg" and level<=2 then prerequisites[#prerequisites+1]=level==1 and "ei-minigun" or "ei-heavy-minigun" end
            if branch=="artillery" and level==1 then prerequisites[#prerequisites+1]="artillery" end
            if branch=="doeworks" and level==1 then prerequisites[#prerequisites+1]="dw-deer-tech" end
            add_technology(catalog.weapon_technology(branch,level),age,prerequisites)
            local technology=data.raw.technology[catalog.weapon_technology(branch,level)]
            local stats=catalog.weapons[branch][level+1]
            technology.localised_name={"spider-vehicles.weapon-upgrade",{"spider-vehicles.weapon-"..branch},{"spider-vehicles.upgrade-"..catalog.upgrade_names[branch][level]}}
            technology.localised_description={"spider-vehicles.weapon-description",{"spider-vehicles.weapon-"..branch},tostring(stats[1]),tostring(stats[2]),tostring(stats[3])}
            technology.effects[1].effect_description=technology.localised_description
        end
    end
    add_technology(catalog.smoke.technology,"quantum-age",{"ei-assault-spidertron","ei-spider-chassis-4","ei-quantum-age"},{{type="unlock-recipe",recipe=catalog.smoke.charge},{type="nothing",effect_description={"technology-description.ei-assault-smokescreen"}}})
end

local function weapon_prototypes()
    local sources={cannon="assault_spidertron_cannon",mg="assault_spidertron-mg",flamer="assault_spidertron-flamer",artillery="assault_spidertron-mortar",rocket="spidertron-rocket-launcher-1",doeworks="spidertron-rocket-launcher-1"}
    for _,branch in ipairs(catalog.branch_order) do
        for index,stats in ipairs(catalog.weapons[branch]) do
            if stats then
                local gun=table.deepcopy(data.raw.gun[sources[branch]])
                gun.name="ei-spider-gun-"..branch.."-"..(index-1)
                gun.hidden=true
                gun.hidden_in_factoriopedia=true
                gun.localised_name={"spider-vehicles.weapon-"..branch}
                gun.attack_parameters.cooldown=stats[1]
                gun.attack_parameters.range=stats[2]
                gun.attack_parameters.min_range=stats[3]
                gun.attack_parameters.damage_modifier=1
                if branch=="mg" and index>=2 then
                    local minigun=data.raw.gun[index==2 and "ei-minigun" or "ei-heavy-minigun"]
                    gun.attack_parameters.sound=table.deepcopy(minigun.attack_parameters.sound)
                    gun.icons=table.deepcopy(minigun.icons)
                    gun.icon=minigun.icon
                    gun.icon_size=minigun.icon_size
                elseif branch=="doeworks" then
                    gun.attack_parameters=table.deepcopy(data.raw["ammo-turret"]["dw-deer-turret"].attack_parameters)
                    gun.attack_parameters.cooldown=stats[1]
                    gun.attack_parameters.range=stats[2]
                    gun.attack_parameters.min_range=stats[3]
                    gun.attack_parameters.damage_modifier=1
                    -- A stationary turret's narrow arc stalls a selected spider
                    -- mount at otherwise valid overlapping ranges.
                    gun.attack_parameters.turn_range=1
                elseif branch=="cannon" and index==6 then
                    gun.attack_parameters.projectile_creation_distance=0
                    gun.attack_parameters.projectile_center={0,0}
                end
                data:extend({gun})
                if branch=="rocket" then
                    local smart=table.deepcopy(gun)
                    smart.name=gun.name.."-smart"
                    smart.attack_parameters.cooldown=stats[1]*0.5
                    data:extend({smart})
                end
            end
        end
    end
end

local function configure_chassis(body, family, level)
    local profile=catalog.profiles[family]
    local tier=catalog.grid_tier(level)
    local function axis(first,second) return level>=second and 3 or (level>=first and 2 or 1) end
    body.max_health=profile.health[axis(1,7)]
    body.inventory_size=profile.cargo[axis(2,8)]
    body.trash_inventory_size=20
    body.equipment_grid="ei-spider-grid-"..family.."-"..tier
    body.energy_source={type="burner",effectivity=({1,1.15,1.3})[axis(4,10)],fuel_categories=catalog.fuel_categories,
        fuel_inventory_size=profile.fuel[axis(3,9)],burnt_inventory_size=profile.fuel[axis(3,9)],
        smoke={{name="smoke",frequency=10,position={0,0},starting_vertical_speed=0.08,starting_frame_deviation=60}},
    }
    body.movement_energy_consumption=profile.power
    body.resistances=table.deepcopy(body.resistances)
    local armor=level>=11 and 10 or (level>=5 and 5 or 0)
    for _,resistance in ipairs(body.resistances or {}) do
        if resistance.type=="physical" or resistance.type=="explosion" then resistance.percent=math.min(90,(resistance.percent or 0)+armor) end
    end
    body.minable={mining_time=1,result=catalog.stored_item(family,tier)}
    body.allow_remote_driving=true
    body.next_upgrade=nil
    body.localised_name={"entity-name."..profile.item}
    body.localised_description={"entity-description."..profile.item}
end

function model.finalize()
    weapon_prototypes()
    -- Restore only this catalog's prerequisites after optional technology flattening.
    for name,spec in pairs(technology_specs) do
        ei_lib.set_prerequisites(name,table.deepcopy(spec.prerequisites))
        if name:find("ei-spider-rocket-",1,true)==1 or name:find("ei-spider-doeworks-",1,true)==1 then
            local packs=data.raw.technology[name].unit.ingredients
            for _,pack in ipairs({"space-science-pack","agricultural-science-pack"}) do
                local present=false
                for _,ingredient in ipairs(packs) do if ingredient[1]==pack then present=true end end
                if not present then packs[#packs+1]={pack,1} end
            end
        end
    end
    for _,technology in pairs(data.raw.technology) do
        for i=#(technology.effects or {}),1,-1 do
            local effect=technology.effects[i]
            if effect.type=="unlock-recipe" and effect.recipe=="assault_spidertron" then table.remove(technology.effects,i) end
        end
    end
    data.raw.technology.assault_spidertron_tech.hidden=true
    data.raw.technology.assault_spidertron_tech.enabled=false
    data.raw.technology.assault_spidertron_tech.effects={}
    data.raw.recipe.assault_spidertron.hidden=true
    data.raw.recipe.assault_spidertron.enabled=false
    data.raw.recipe.assault_spidertron.hide_from_player_crafting=true

    for _,family in ipairs(catalog.families) do
        local profile=catalog.profiles[family]
        local base=table.deepcopy(data.raw["spider-vehicle"][profile.source])
        base.automatic_weapon_cycling=true
        if family=="assault" then base.chain_shooting_cooldown_modifier=1 end
        for tier,dimensions in ipairs(profile.grids) do
            data:extend({{type="equipment-grid",name="ei-spider-grid-"..family.."-"..tier,width=dimensions[1],height=dimensions[2],equipment_categories={"armor"}}})
            if tier>1 then
                local item=table.deepcopy(data.raw["item-with-entity-data"][profile.item])
                item.name=catalog.stored_item(family,tier)
                item.place_result=catalog.variant_name(family,{chassis=(tier-1)*6})
                item.localised_name={"item-name.ei-stored-spidertron",{"entity-name."..profile.item},tostring(dimensions[1]),tostring(dimensions[2])}
                item.hidden=true
                item.hidden_in_factoriopedia=true
                item.factoriopedia_alternative=profile.item
                data:extend({item})
            end
        end
        for chassis=0,12 do
            local body=table.deepcopy(base)
            configure_chassis(body,family,chassis)
            local states={}
            if family=="scout" then states[1]={chassis=chassis}
            elseif family=="rocket" then
                for rocket=0,4 do for doeworks=0,4 do states[#states+1]={chassis=chassis,rocket=rocket,doeworks=doeworks} end end
            else
                for cannon=0,5 do for mg=0,4 do for flamer=0,4 do for artillery=0,5 do
                    states[#states+1]={chassis=chassis,cannon=cannon,mg=mg,flamer=flamer,artillery=artillery}
                end end end end
            end
            for _,state in ipairs(states) do
                -- No later ESIR pass mutates variants: share the resolved body/leg graphics.
                local entity={}
                for key,value in pairs(body) do entity[key]=value end
                entity.name=catalog.variant_name(family,state)
                entity.hidden=true
                entity.hidden_in_factoriopedia=true
                entity.factoriopedia_alternative=profile.source
                entity.guns={}
                if family=="assault" then
                    for _,branch in ipairs({"cannon","mg","flamer","artillery"}) do
                        if branch~="artillery" or state.artillery>0 then entity.guns[#entity.guns+1]="ei-spider-gun-"..branch.."-"..state[branch] end
                    end
                elseif family=="rocket" then
                    for slot=1,4 do entity.guns[slot]="ei-spider-gun-rocket-"..state.rocket end
                    if state.doeworks>0 then entity.guns[5]="ei-spider-gun-doeworks-"..state.doeworks end
                end
                local modes=family=="scout" and {"native"} or (family=="rocket" and {"native","hold","smart"} or {"native","hold"})
                for _,mode in ipairs(modes) do
                local variant={}
                for key,value in pairs(entity) do variant[key]=value end
                variant.name=catalog.variant_name(family,state,mode)
                variant.automatic_weapon_cycling=mode=="native"
                if mode=="smart" then
                    variant.guns={}
                    for slot,gun in ipairs(entity.guns) do variant.guns[slot]=slot<=4 and gun.."-smart" or gun end
                end
                data:extend({variant})
                -- Enhancements creates boarding proxies before this final pass.
                -- Reuse its resolved family graphics/leg, with this variant's
                -- capacities, rather than generating another leg per variant.
                local proxy_source=data.raw["spider-vehicle"][catalog.proxy_prefix..profile.source]
                if proxy_source then
                    local proxy={}
                    for key,value in pairs(proxy_source) do proxy[key]=value end
                    for _,key in ipairs({"max_health","resistances","inventory_size","trash_inventory_size","equipment_grid","energy_source","movement_energy_consumption","guns","minable","automatic_weapon_cycling","chain_shooting_cooldown_modifier"}) do proxy[key]=variant[key] end
                    proxy.name=catalog.proxy_prefix..variant.name
                    proxy.hidden=true
                    proxy.hidden_in_factoriopedia=true
                    proxy.factoriopedia_alternative=profile.source
                    data:extend({proxy})
                end
                end
            end
        end
        local public=data.raw["spider-vehicle"][profile.source]
        if family=="scout" then configure_chassis(public,family,0) end
        if family=="scout" then public.guns={} end
        -- Preserve legacy body capacities until runtime can inspect their contents.
        -- Shrinking a legacy grid here would lose equipment before migration runs.
        if family=="assault" then
            public.hidden=true
            public.hidden_in_factoriopedia=true
            public.guns={"assault_spidertron-mortar","assault_spidertron_rocket_launcher","assault_spidertron_cannon","assault_spidertron-mg","assault_spidertron-flamer"}
            -- Legacy mined items can contain a full 10x6 grid. Let native placement
            -- restore that grid before the runtime safely resolves the ESIR chassis.
            data.raw["item-with-entity-data"][profile.item].place_result=profile.source
        elseif family=="rocket" then
            data.raw["item-with-entity-data"][profile.item].place_result=profile.source
        else
            data.raw["item-with-entity-data"][profile.item].place_result=catalog.variant_name(family,{})
        end
    end
    -- Mined expanded-grid rocket spiders remain valid saucer construction inputs.
    for tier=2,3 do
        local recipe=table.deepcopy(data.raw.recipe["ei-gaian-saucer"])
        recipe.name="ei-gaian-saucer-stored-spidertron-"..tier
        recipe.hidden=false
        recipe.hidden_in_factoriopedia=true
        recipe.auto_recycle=false
        recipe.localised_name={"spider-vehicles.stored-saucer-recipe",{"entity-name.ei-gaian-saucer"},data.raw["item-with-entity-data"][catalog.stored_item("rocket",tier)].localised_name}
        data:extend({recipe})
        ei_lib.recipe_swap(recipe.name,"spidertron",catalog.stored_item("rocket",tier))
        ei_lib.add_unlock_recipe("ei-gaian-saucer",recipe.name)
    end
end

return model

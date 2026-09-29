--==============================================================================
-- ESIR FILE MAP
-- owns: two radar chassis, hidden helpers, finite research and circuit signals
-- loaded_by: data.lua after age prototypes
-- cadence: data stage; scripted scanning has no native omnidirectional coverage
--==============================================================================
local config = require("lib/sweeping-radar-config")
local art = require("prototypes/sweeping-radar-art")
local icon="__base__/graphics/icons/radar.png"
local recipes={
    {{"radar",1},{"advanced-circuit",8},{"ei-electronic-parts",4},
        {"ei-steel-mechanical-parts",10},{"ei-insulated-wire",10}},
    {{config.names[1],1},{"processing-unit",20},{"ei-advanced-motor",8},
        {"ei-steel-beam",8},{"ei-simulation-data",40},{"ei-high-energy-crystal",8}},
}
local function technology(name, prerequisites, age, effects, time, chassis)
    return {type="technology",name=name,icons={{icon=ei_path.."graphics/items/"..config.art[chassis].asset..".png",
        icon_size=128,icon_mipmaps=3}},prerequisites=prerequisites,
        effects=effects,unit={count=100,time=time,ingredients=ei_data.science[age]},age=age}
end
for tier,name in ipairs(config.names) do
    local hardware=config.hardware[name]
    local radar=table.deepcopy(data.raw.radar.radar)
    radar.name=name
    radar.icons={{icon=ei_path.."graphics/items/"..config.art[name].asset..".png",icon_size=128,icon_mipmaps=3}}
    radar.icon=nil
    radar.minable={mining_time=0.5,result=name}
    radar.max_health=hardware.health
    radar.fast_replaceable_group="ei-sweeping-radar"
    radar.next_upgrade=tier==1 and config.names[2] or nil
    radar.energy_source={type="void"}
    radar.energy_usage="1W"
    radar.energy_per_sector="1GJ"
    radar.energy_per_nearby_scan="1GJ"
    radar.max_distance_of_sector_revealed=0
    radar.max_distance_of_nearby_sector_revealed=0
    radar.connects_to_other_radars=false
    radar.rotation_speed=0
    radar.heating_energy="300kW"
    radar.factoriopedia_simulation=nil
    radar.radius_minimap_visualisation_color={0,0,0,0}
    radar.localised_description={"sweeping-radar.description",tostring(hardware.range),tostring(hardware.rate)}
    radar.pictures={filename="__core__/graphics/empty.png",width=1,height=1,direction_count=1}
    radar.placeable_position_visualization=nil
    radar.placeable_by={item=name,count=1}
    radar.water_reflection=nil
    radar.drawing_box_vertical_extension=2
    radar.additional_pastable_entities=config.names
    local ingredients={}
    for _,ingredient in ipairs(recipes[tier]) do
        ingredients[#ingredients+1]={type="item",name=ingredient[1],amount=ingredient[2]}
    end
    -- The placement-only chassis supplies the native cursor preview. The build
    -- handler fast-replaces it with the canonical scripted radar immediately.
    local placement=table.deepcopy(radar)
    placement.name=name.."-placement"
    placement.hidden=true;placement.hidden_in_factoriopedia=true
    placement.localised_name={"entity-name."..name}
    placement.pictures=table.deepcopy(art[name]);placement.pictures.direction_count=1
    data:extend({radar,placement,
        {type="item",name=name,icons=table.deepcopy(radar.icons),subgroup="defensive-structure",
            order="d[radar]-"..tier,stack_size=50,place_result=placement.name},
        {type="recipe",name=name,enabled=false,energy_required=tier*10,allow_productivity=false,
            ingredients=ingredients,results={{type="item",name=name,amount=1}}},
        technology(name,tier==1 and {"radar","circuit-network","ei-electronic-parts"}
            or {config.names[1],"ei-advanced-computer-age-tech","ei-high-energy-crystal"},
            tier==1 and "electricity-age" or "advanced-computer-age",
            {{type="unlock-recipe",recipe=name}},20,name),
        {type="electric-energy-interface",name=name.."-power",localised_name={"entity-name."..name},
            flags={"not-on-map","placeable-off-grid","not-blueprintable","not-deconstructable","not-flammable"},
            hidden=true,hidden_in_factoriopedia=true,selectable_in_game=false,
            collision_mask={layers={}},collision_box={{-1.2,-1.2},{1.2,1.2}},
            energy_source={type="electric",usage_priority="secondary-input",
                buffer_capacity=tostring(hardware.buffer).."J",input_flow_limit=tostring(hardware.input).."W",
                output_flow_limit="0W",drain="0W",render_no_power_icon=false,render_no_network_icon=false},
            energy_usage=tostring(hardware.idle).."W",energy_production="0W",picture={filename=ei_lib.empty_sprite(),width=64,height=64},
            gui_mode="none",allow_copy_paste=false},
    })
end
local output=table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
output.name=config.output
output.flags={"not-on-map","placeable-off-grid","not-blueprintable","not-deconstructable","not-flammable"}
output.hidden=true
output.hidden_in_factoriopedia=true
output.selectable_in_game=false
output.minable=nil
output.collision_mask={layers={}}
output.collision_box={{0,0},{0,0}}
output.selection_box={{0,0},{0,0}}
local blank={filename=ei_lib.empty_sprite(),width=64,height=64}
output.sprites={north=blank,east=blank,south=blank,west=blank}
output.activity_led_sprites=output.sprites
output.item_slot_count=#config.outputs
output.draw_circuit_wires=false
output.draw_copper_wires=false
output.circuit_wire_max_distance=3
data:extend({output,{type="custom-input",name=config.input,key_sequence="",
    linked_game_control="open-gui",consuming="none"}})
for index,key in ipairs(config.outputs) do
    data:extend({{type="virtual-signal",name="ei-radar-"..key,
        icons={{icon=icon,icon_size=64,tint={0.5+index/25,0.8,1}}},
        subgroup="virtual-signal-special",order="r[radar]-"..string.format("%02d",index)}})
end
for _,branch in ipairs(config.branches) do
    for level=1,3 do
        local name="ei-radar-"..branch.."-"..level
        local prerequisites={level==1 and config.names[1] or "ei-radar-"..branch.."-"..(level-1)}
        prerequisites[#prerequisites+1]=level==1 and "ei-computer-age" or level==2 and config.names[2] or "ei-quantum-age"
        local tech=technology(name,prerequisites,({"computer-age","advanced-computer-age","quantum-age"})[level],
            {{type="nothing",effect_description={"sweeping-radar.research-"..branch,
                tostring(branch=="range" and config.range_bonus[level+1] or branch=="capacity"
                    and (config.rate_bonus[level+1]-1)*100 or (1-config.energy_bonus[level+1])*100)}}},
            level==3 and 30 or 20,config.names[level==1 and 1 or 2])
        tech.localised_name={"sweeping-radar.research-name-"..branch,tostring(level)}
        data:extend({tech})
    end
end

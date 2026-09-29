-- Native mining/placement acceptance; no combat or fleet benchmark in this mode.
local catalog=require("__exotic-space-industries-remembrance__/lib/spider-vehicles")
local config=require("test-config")
local api="exotic-industries-spider-vehicles"
local qc="esir-spider-qc-controls"
local function check(name,pass,detail) storage.checks[#storage.checks+1]={name=name,pass=pass==true,detail=detail} end
local function current(id) return remote.call(qc,"vehicle",id) end
local function equip(grid,dims)
    grid.put{name="solar-panel-equipment",position={dims[1]-1,dims[2]-1},quality="rare"}
    local shield=grid.put{name="energy-shield-equipment",position={0,0}}
    shield.energy=shield.max_energy;shield.shield=10
    local generator=grid.put{name="esir-spider-qc-generator",position={2,0}}
    generator.burner.inventory.insert{name="coal",count=3}
    generator.burner.burnt_result_inventory.insert{name="iron-plate",count=2}
    generator.burner.currently_burning="coal";generator.burner.remaining_burning_fuel=1000000
    grid.inhibit_movement_bonus=true
end
local function grid_check(entity,dims,prefix)
    local corner=entity.grid.get{x=dims[1]-1,y=dims[2]-1}
    check(prefix.."-outer-equipment",corner and corner.name=="solar-panel-equipment" and corner.quality.name=="rare")
    local shield=entity.grid.get{0,0}
    check(prefix.."-shield",shield and shield.name=="energy-shield-equipment" and shield.energy>0 and shield.shield>=10)
    local generator=entity.grid.get{2,0}
    local burner=generator and generator.burner
    check(prefix.."-burner",burner and burner.inventory.get_item_count("coal")==3 and burner.burnt_result_inventory.get_item_count("iron-plate")==2 and
        burner.currently_burning and burner.currently_burning.name.name=="coal" and burner.remaining_burning_fuel>990000,
        burner and {coal=burner.inventory.get_item_count("coal"),spent=burner.burnt_result_inventory.get_item_count("iron-plate"),burning=burner.currently_burning and burner.currently_burning.name.name,remaining=burner.remaining_burning_fuel})
    check(prefix.."-grid-setting",entity.grid.inhibit_movement_bonus==(prefix~="robot"))
end
local function setup()
    storage.start=game.tick;storage.checks={};storage.forces={};storage.cases={}
    local player=game.get_player(1)
    assert(player,"Use a player save for canonical item QC")
    local surface=game.create_surface("esir-canonical-qc",{autoplace_settings={entity={treat_missing_as_default=false,settings={}}}})
    surface.request_to_generate_chunks({0,0},3);surface.request_to_generate_chunks({0,300},2);surface.force_generate_chunk_requests()
    local tiles={}
    for x=-32,32 do for y=-32,32 do tiles[#tiles+1]={name="grass-1",position={x,y}};tiles[#tiles+1]={name="grass-1",position={x,y+300}} end end
    surface.set_tiles(tiles)
    for tier=1,3 do
        local force=game.create_force("esir-canonical-"..tier)
        for level=1,(tier-1)*6 do force.technologies["ei-spider-chassis-"..level].researched=true end
        remote.call(api,"refresh_force",force);storage.forces[tier]=force
    end
    player.driving=false;player.teleport({0,0},surface)
    for _,family in ipairs(catalog.families) do for tier=1,3 do storage.cases[#storage.cases+1]={family=family,tier=tier} end end
    for _,family in ipairs(catalog.families) do storage.cases[#storage.cases+1]={family=family,tier=2,legacy=true} end
    for tier=2,3 do storage.cases[#storage.cases+1]={family="scout",tier=tier,downgrade=true} end
    storage.surface=surface
end
script.on_event(defines.events.on_robot_mined_entity,function(event)
    if storage.robot and event.entity==storage.robot.source then
        storage.robot.mined=true
        local found=false
        for i=1,#event.buffer do found=found or event.buffer[i].valid_for_read and event.buffer[i].name=="spidertron" end
        check("robot-canonical-item",found)
    end
end)
script.on_event(defines.events.on_robot_built_entity,function(event)
    if storage.robot and catalog.family(event.entity.name)=="rocket" then
        storage.robot.id=remote.call(api,"get_vehicle_id",event.entity)
        storage.robot.built={name=event.entity.name,equipment=#event.entity.grid.equipment,items={}}
        for i=1,(event.consumed_items and #event.consumed_items or 1) do
            local stack=event.consumed_items and event.consumed_items[i] or event.stack
            storage.robot.built.items[i]={name=stack.valid_for_read and stack.name,grid=stack.grid and stack.grid.prototype.name,equipment=stack.grid and #stack.grid.equipment}
        end
    end
end)
script.on_event(defines.events.on_tick,function(event)
    if not storage.start then setup() end
    local tick=event.tick-storage.start
    local player=game.get_player(1)
    local case=storage.cases[math.floor(tick/15)]
    if case then
        local prefix=case.family.."-"..case.tier..(case.legacy and "-legacy" or case.downgrade and "-downgrade" or "")
        local base=catalog.profiles[case.family].grids[case.tier]
        local quality=prototypes.quality.rare
        local dims={base[1]+quality.equipment_grid_width_bonus,base[2]+quality.equipment_grid_height_bonus}
        local phase=tick%15
        if phase==0 then
            local force=storage.forces[case.tier]
            player.force=force;player.teleport({3,0},storage.surface)
            player.clear_cursor();player.get_main_inventory().clear()
            local name=catalog.configured_name(case.family,catalog.researched_state(force),{cycling=false,special=false},config.smart)
            local entity=storage.surface.create_entity{name=name,position={4,0},force=force,quality="rare",raise_built=true}
            equip(entity.grid,dims);entity.entity_label=prefix
            entity.get_logistic_sections().add_section("canonical fixture")
            if case.family~="scout" then remote.call(api,"set_weapon_controls",entity,{cycling=false,special=false,selected_slot=2,overkill=true}) end
            check(prefix.."-mine",player.mine_entity(entity,true))
            local item
            for i=1,#player.get_main_inventory() do
                local stack=player.get_main_inventory()[i]
                if stack.valid_for_read and stack.name==catalog.profiles[case.family].item then item=stack;break end
            end
            check(prefix.."-canonical-item",item and item.quality.name=="rare" and item.grid and #item.grid.equipment==3)
            if case.legacy then
                item.set_stack{name=catalog.stored_item(case.family,case.tier),count=1,quality="rare"}
                equip(item.create_grid(),dims)
            end
            player.cursor_stack.transfer_stack(item)
            if case.downgrade then player.force=storage.forces[1] end
            player.build_from_cursor{position={8,0}}
            check(prefix.."-build",not player.cursor_stack.valid_for_read)
            local placed=storage.surface.find_entities_filtered{type="spider-vehicle",position={8,0},radius=1}[1]
            case.id=remote.call(api,"get_vehicle_id",placed)
        elseif phase==5 then
            local entity=current(case.id)
            grid_check(entity,dims,prefix)
            check(prefix.."-resolved-body",entity.name~=catalog.placement_name(case.family) and entity.grid.width==dims[1] and entity.grid.height==dims[2] and entity.active and entity.minable and entity.operable and entity.destructible,
                {name=entity.name,width=entity.grid.width,height=entity.grid.height,active=entity.active,minable=entity.minable,operable=entity.operable,destructible=entity.destructible})
            if not case.legacy then
                check(prefix.."-metadata",entity.entity_label==prefix and entity.quality.name=="rare" and entity.get_logistic_sections().sections_count>0)
                if case.family~="scout" then
                    local controls=remote.call(api,"get_weapon_controls",entity)
                    check(prefix.."-preferences",not controls.cycling and not controls.special and controls.selected_slot==2 and controls.overkill)
                end
            end
            if case.downgrade then
                check(prefix.."-pending",remote.call(api,"get_status").pending[case.id]=="grid-capacity")
                entity.grid.clear();remote.call(api,"refresh_vehicle",entity)
            end
        elseif phase==10 then
            local entity=current(case.id)
            if case.downgrade then check(prefix.."-refit-after-removal",entity.grid.width==4+quality.equipment_grid_width_bonus and entity.grid.height==4+quality.equipment_grid_height_bonus) end
            if case.legacy then
                player.force=entity.force;player.teleport({7,0},storage.surface);player.get_main_inventory().clear()
                check(prefix.."-remine-canonical",player.mine_entity(entity,true) and player.get_main_inventory().get_item_count{name=catalog.profiles[case.family].item,quality="rare"}==1)
            else entity.destroy{raise_destroy=true} end
        end
    end
    if tick==240 then
        local force=storage.forces[2];force.worker_robots_speed_modifier=10
        local port=storage.surface.create_entity{name="roboport",position={0,300},force=force}
        port.energy=100000000;port.get_inventory(defines.inventory.roboport_robot).insert{name="construction-robot",count=2}
        local chest=storage.surface.create_entity{name="storage-chest",position={5,300},force=force}
        local name=catalog.configured_name("rocket",catalog.researched_state(force),{cycling=false,special=false},config.smart)
        local entity=storage.surface.create_entity{name=name,position={10,300},force=force,raise_built=true}
        equip(entity.grid,catalog.profiles.rocket.grids[2])
        entity.grid.inhibit_movement_bonus=false
        remote.call(api,"set_weapon_controls",entity,{cycling=false,special=false,selected_slot=2,overkill=true})
        storage.robot={source=entity,port=port,chest=chest};entity.order_deconstruction(force)
    elseif tick==400 then
        check("robot-mined",storage.robot.mined==true)
        -- Native blueprint reconciliation removes equipment absent from a ghost.
        -- Request the mined layout so this checks transfer rather than removal.
        local dims=catalog.profiles.rocket.grids[2]
        local inventory=game.create_inventory(1)
        inventory[1].set_stack{name="blueprint",count=1}
        -- Exercise matching native grid swaps and mismatched scripted handoffs.
        inventory[1].set_blueprint_entities{{entity_number=1,name=catalog.variant_name("rocket",{chassis=config.smart and 12 or 6}),position={x=0,y=0},grid={
            {equipment={name="solar-panel-equipment",quality="rare"},position={x=dims[1]-1,y=dims[2]-1}},
            {equipment={name="energy-shield-equipment"},position={x=0,y=0}},
            {equipment={name="esir-spider-qc-generator"},position={x=2,y=0}},
        }}}
        storage.robot.ghost=inventory[1].build_blueprint{surface=storage.surface,force=storage.forces[2],position={15,300},skip_fog_of_war=false}[1]
        inventory.destroy()
    elseif tick==620 then
        local ghost=storage.robot.ghost
        local ingredients={}
        if ghost and ghost.valid then
            for _,entry in pairs(ghost.ghost_prototype.items_to_place_this or {}) do ingredients[#ingredients+1]={name=entry.name,count=entry.count} end
        end
        check("robot-built",storage.robot.id~=nil,{ghost=ghost and ghost.valid,ingredients=ingredients,contents=storage.robot.chest.get_inventory(defines.inventory.chest).get_contents()})
        if storage.robot.id then
            local entity=current(storage.robot.id)
            grid_check(entity,catalog.profiles.rocket.grids[2],"robot")
            local controls=remote.call(api,"get_weapon_controls",entity)
            check("robot-preferences",not controls.cycling and not controls.special and controls.selected_slot==2 and controls.overkill)
        end
        local status=remote.call(api,"get_status")
        check("native-no-selector-work",config.smart or status.selector_samples==0 and status.selector_searches==0)
        check("no-unexpected-refit-failures",status.failures==0,status.failures)
        local all=true
        for _,entry in ipairs(storage.checks) do all=all and entry.pass end
        helpers.write_file("spider-vehicles-qc.json",helpers.table_to_json({all_pass=all,checks=storage.checks,status=status,robot=storage.robot.built}),false)
    end
    if storage.robot then storage.robot.port.energy=100000000 end
end)

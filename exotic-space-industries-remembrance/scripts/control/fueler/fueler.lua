local model = {}

--====================================================================================================
--FUELER
--====================================================================================================

model.target_types = {
    "locomotive",
    "car",
    "spidertron", -- needed for EI changes
    "character", -- refering to player equipment
}

--UTIL
------------------------------------------------------------------------------------------------------

function model.get_transfer_inv(transfer)
    -- transfer is either a player index, a robot, or nil
    -- needed to prevent unregistration when the transferer cant mine due to full inv

    if not transfer then
        return nil
    end

    if type(transfer) == "number" then
        -- player index
        local player = game.get_player(transfer)
        return player.get_main_inventory()
    end

    if transfer.valid then
        -- robot
        local robot = transfer
        return robot.get_inventory(defines.inventory.robot_cargo)
    end

    return nil

end


function model.transfer_valid(source, transfer)

    local target_inv = model.get_transfer_inv(transfer)
    
    if not target_inv then
        -- case for when destroyed by gun f.e. -> need to unregister
        return true
    end

    -- check if contents of source and the source itself can be inserted into the target
    local source_inv = source.get_inventory(defines.inventory.chest)
    local source_contents = source_inv.get_contents()

    local return_value = true

    if not source_inv then return end
    if not source_contents then return end

    -- for item, count in pairs(source_contents) do
        
    --     local insertable_count = target_inv.get_insertable_count(item)

    --     if insertable_count < count then
    --         return_value = false
    --     end
    -- end

    -- check if the source itself can be inserted into the target
    if not target_inv.can_insert({name = source.name, count = 1}) then
        return_value = false
    end

    if return_value == true then
        if type(transfer) ~= "number" then
            -- robot
            -- if the source inv is not empty, the robot will not mine the source
            if not source_inv.is_empty() then
                return_value = false
            end
        end
    end

    return return_value

end


function model.entity_check(entity)
    if entity == nil then
        return false
    end

    if not entity.valid then
        return false
    end

    return true
end


function model.check_global()

    if not storage.ei then
        storage.ei = {}
    end

    if not storage.ei.fueler then
      storage.ei.fueler = {}
    end

end


function model.check_queue()

    if not storage.ei then
      storage.ei = {}
    end

    if not storage.ei.fueler_queue then
      storage.ei.fueler_queue = {}
    end

end


function model.check_cooldown()

    if not storage.ei then
      storage.ei = {}
    end

    if not storage.ei.cooldown then
      storage.ei.cooldown = {}
    end

end


function model.is_on_cooldown(entity)

    if not storage.ei.cooldown[entity.unit_number] then
        return false
    end

    if storage.ei.cooldown[entity.unit_number] > game.tick then
        -- the tick value is for when the cooldown will end
        return true
    end

    return false

end


function model.add_cooldown(entity)

    model.check_cooldown()
    storage.ei.cooldown[entity.unit_number] = game.tick + 60

end


function model.clone_fuel(itemstack, source_inv, target_inv, clearup_stack)

    if not itemstack.valid_for_read then
        return
    end

    if not target_inv.can_insert(itemstack.name) then
        return
    end

    local count = target_inv.insert({name=itemstack.name, count=itemstack.count})
    table.insert(clearup_stack, {itemstack.name, count})

end

function model.clone_ammo(itemstack, source_inv, target_inv, clearup_stack)

    if not itemstack.valid_for_read then
        return
    end

    if not target_inv.can_insert(itemstack.name) then
        return
    end

    local count = target_inv.insert({name=itemstack.name, count=itemstack.count})
    table.insert(clearup_stack, {itemstack.name, count})

end


function model.cleanup_clones(inv, clearup_stack)

    local action = false

    -- remove the itemstacks that were inserted into the target inventory
    for _, itemstack in ipairs(clearup_stack) do
        inv.remove({name=itemstack[1], count=itemstack[2]})
        action = true
    end

    return action

end


function model.transfer_fuel(fueler_inventory, target_inventory)

    local itemstacks_inserted = {}

        for i=1, #fueler_inventory do

            local itemstack = fueler_inventory[i]
            model.clone_fuel(itemstack, fueler_inventory, target_inventory, itemstacks_inserted)
    
        end
    
    local action = model.cleanup_clones(fueler_inventory, itemstacks_inserted)

    return action

end

function model.transfer_ammo(fueler_inventory, target_inventory)

    local itemstacks_inserted = {}

        for i=1, #fueler_inventory do

            local itemstack = fueler_inventory[i]
            model.clone_ammo(itemstack, fueler_inventory, target_inventory, itemstacks_inserted)
    
        end
    
    local action = model.cleanup_clones(fueler_inventory, itemstacks_inserted)

    return action

end


function model.cast_beam(fueler, target)

    -- create a beam between the fueler and the target
    local beam = fueler.surface.create_entity({
        name = "ei_fuel-beam",
        position = fueler.position,
        source_offset = {0, -1},
        source = fueler,
        target = target,
        duration = 30,
        force = fueler.force,
    })

end


function model.refuel_target(fueler, target, target_type)

    -- game.print("refueling target")
    -- game.print("fueler: " .. fueler.name)
    -- game.print("target: " .. target.name)

    local fueler_inventory = fueler.get_inventory(defines.inventory.chest)

    -- ammo insert
    target_inventory = target.get_inventory(defines.inventory.turret_ammo)
    if target_inventory == nil then target_inventory = target.get_inventory(defines.inventory.artillery_turret_ammo) end
    if target_inventory == nil then target_inventory = target.get_inventory(defines.inventory.artillery_wagon_ammo) end

    if target_inventory then 
      local action = model.transfer_ammo(fueler_inventory, target_inventory)
      if action then
          model.cast_beam(fueler, target)
      end
    end


    local target_inventory = nil

    if target_type == "car" or target_type == "spider-vehicle" or target_type == "locomotive" then

        target_inventory = target.get_fuel_inventory()

    end

    if target_inventory == nil then
        return
    end

    -- fueler -> target
    if not fueler_inventory.is_empty() then
        local action = model.transfer_fuel(fueler_inventory, target_inventory)
        if action then
            model.cast_beam(fueler, target)
        end
    end

    -- target -> fueler
    local result_inventory = target.get_burnt_result_inventory()

    if not result_inventory then
        return
    end

    if fueler_inventory.is_full() then
        return
    end

    if not result_inventory.is_empty() then
        local action = model.transfer_fuel(result_inventory, fueler_inventory)
        if action then
            model.cast_beam(fueler, target)
        end
    end
end


function model.refuel_equipments(fueler, target)

    local fueler_inventory = fueler.get_inventory(defines.inventory.chest)

    if not target.grid then
        return
    end

    local equipments = target.grid.equipment

    if #equipments == 0 then
        return
    end

    -- for every equip in the target try to insert fuel from the fueler
    for _, equipment in ipairs(equipments) do

        if not equipment.valid then
            goto continue
        end

        if not equipment.burner then
            goto continue
        end

        -- fueler -> target
        local burner_inventory = equipment.burner.inventory
        if not fueler_inventory.is_empty() then
            local action = model.transfer_fuel(fueler_inventory, burner_inventory)
            if action then
                model.cast_beam(fueler, target)
            end
        end

        -- target -> fueler
        local result_inventory = equipment.burner.burnt_result_inventory
        if not result_inventory then
            goto continue
        end

        if fueler_inventory.is_full() then
            goto continue
        end

        if not result_inventory.is_empty() then
            local action = model.transfer_fuel(result_inventory, fueler_inventory)
            if action then
                model.cast_beam(fueler, target)
            end
        end

        ::continue::

    end

end


function model.get_break_point()

    model.check_queue()

    -- id,_ = next() returns the first element of a table
    -- id,_ = next(_, id) returns the next element of a table

    -- if there already is a break point, then try to move it forward one step
    -- if that is not possible then try to return the first element
    -- if that is not possible then return nil

    -- if there id no current break point, then try to return the first element
    -- if that is not possible then return nil

    local break_point = storage.ei.fueler_break_point

    if break_point then

        -- if no element in fueler_queue then return nil and reset the break point
        if not next(storage.ei.fueler_queue) then
            storage.ei.fueler_break_point = nil
            return nil
        end

        -- try to move the break point forward one step
        if next(storage.ei.fueler_queue, break_point) then
            storage.ei.fueler_break_point,_ = next(storage.ei.fueler_queue, break_point)
            return storage.ei.fueler_break_point
        end

        -- cant move the break point forward, so try to return the first element
        if next(storage.ei.fueler_queue) then
            storage.ei.fueler_break_point,_ = next(storage.ei.fueler_queue)
            return storage.ei.fueler_break_point
        end

        -- cant return the first element, so return nil
        return nil

    end

    -- there is no break point, so try to return the first element
    if next(storage.ei.fueler_queue) then
        storage.ei.fueler_break_point,_ = next(storage.ei.fueler_queue)
        return storage.ei.fueler_break_point
    end

    -- cant return the first element, so return nil
    return nil

end


--UPDATES
------------------------------------------------------------------------------------------------------

function model.update_cooldowns()

    model.check_cooldown()

    local ids_to_remove = {}

    -- remove all cooldowns that are over current tick
    for unit, cooldown in pairs(storage.ei.cooldown) do

        if cooldown < game.tick then
            -- store unit for removal
            table.insert(ids_to_remove, unit)
        end

    end

    -- remove all stored units
    for i, unit in ipairs(ids_to_remove) do
        storage.ei.cooldown[unit] = nil
    end

end


function model.update_fueler(break_point)
    -- game.print("update_fueler")

    model.check_global()
    model.check_cooldown()

    local unit = storage.ei.fueler_queue[break_point]
    local fueler = storage.ei.fueler[unit].entity

    -- get what entity_type this fueler currently fuels
    -- and then try to insert as many items from the fueler inv as possible
    -- into all targets of that type

    local target_type = model.get_target_type(unit)
    local equipment = model.get_equipment(unit)

    if target_type == "spidertron" then
        target_type = "spider-vehicle"
    end

    -- get all entities of the target type in range
    local targets = fueler.surface.find_entities_filtered{
        position = fueler.position,
        radius = settings.startup["ei_fueler_range"].value,
        type = {target_type,"ammo-turret","artillery-turret","artillery-wagon"}
    }

    -- exclude targets that are on cooldown for refueling
    -- for the others try refueling them
    for i, target in ipairs(targets) do

        if not model.entity_check(target) then
            goto continue
        end

        if not model.is_on_cooldown(target) then
            if equipment == false then
                model.refuel_target(fueler, target, target_type)
            else
                model.refuel_equipments(fueler, target)
            end
            model.add_cooldown(target)
        end

        ::continue::

    end

end


--GETTERS AND SETTERS
------------------------------------------------------------------------------------------------------

function model.get_target_type(unit)

    -- get the current entity type that this fueler is fueling
    -- if none id given then return the default type (locomotive)

    local target_type = storage.ei.fueler[unit].target_type

    if not target_type then
        target_type = model.target_types[1]
    end

    return target_type

end


function model.set_target_type(unit, target_type)

    -- set the current entity type that this fueler is fueling
    -- if none id given then set the default type (locomotive)

    if not target_type then
        target_type = model.target_types[1]
    end

    storage.ei.fueler[unit].target_type = target_type

    -- game.print("Set target type to: " .. target_type)

end


function model.get_equipment(unit)

    local equipment = storage.ei.fueler[unit].equipment

    if not equipment then
        equipment = false
    end

    return equipment

end


function model.set_equipment(unit, equipment)

    if not equipment then
        equipment = false
    end

    storage.ei.fueler[unit].equipment = equipment

end

--REGISTER
------------------------------------------------------------------------------------------------------

function model.register_fueler(entity)

    local unit = entity.unit_number

    model.check_global()
    model.check_queue()

    storage.ei.fueler[unit] = {}
    storage.ei.fueler[unit].entity = entity

    -- get lenght of queue
    local queue_lenght = #storage.ei.fueler_queue
    table.insert(storage.ei.fueler_queue, unit)

    -- store the position in the queue
    storage.ei.fueler[unit].queue_pos = queue_lenght + 1

end


function model.unregister_fueler(entity, transfer)

    if not model.transfer_valid(entity, transfer) then
        return
    end

    local unit = entity.unit_number

    model.check_global()
    model.check_queue()
    
    -- remove the unit from the queue
    local sus_pos = storage.ei.fueler[unit].queue_pos

    if storage.ei.fueler_queue[sus_pos] == unit then
        table.remove(storage.ei.fueler_queue, sus_pos)
    else
        -- if the unit is not at that pos, then check for others
        for i, v in pairs(storage.ei.fueler_queue) do
            if v == unit then
                table.remove(storage.ei.fueler_queue, i)
            end
        end
    end

    -- delete the entry from storage 
    storage.ei.fueler[unit] = nil

end

--HANDLERS
------------------------------------------------------------------------------------------------------

function model.on_built_entity(entity)

    if not model.entity_check(entity) then
        return
    end

    if entity.name ~= "ei_fueler" then
        return
    end

    model.register_fueler(entity)

end


function model.on_destroyed_entity(entity, transfer)

    if not model.entity_check(entity) then
        return
    end

    if entity.name ~= "ei_fueler" then
        return
    end

    model.unregister_fueler(entity, transfer)

end


function model.updater()

    local next_break_point = model.get_break_point()

    if not next_break_point then
        return false
    end

    -- update this fueler
    model.update_fueler(next_break_point)
    model.update_cooldowns()
    return true
end


--GUI
------------------------------------------------------------------------------------------------------

function model.open_gui(player)

    if player.gui.relative["ei_fueler-console"] then
        model.close_gui(player)
    end

    local root = player.gui.relative.add{
        type = "frame",
        name = "ei_fueler-console",
        anchor = {
            gui = defines.relative_gui_type.container_gui,
            name = "ei_fueler",
            position = defines.relative_gui_position.right,
        },
        direction = "vertical",
    }

    do -- Titlebar
        local titlebar = root.add{type = "flow", direction = "horizontal"}
        titlebar.add{
            type = "label",
            caption = {"exotic-industries-fueler.fueler-gui-title"},
            style = "frame_title",
        }

        titlebar.add{
            type = "empty-widget",
            style = "ei_titlebar_draggable_spacer",
            ignored_by_interaction = true
        }

        titlebar.add{
            type = "sprite-button",
            sprite = "virtual-signal/informatron",
            style = "frame_action_button",
            tags = {
                parent_gui = "ei_fueler-console",
                action = "goto-informatron",
                page = "exotic-industries-fueler-informatron"
            }
        }
    end

    local main_container = root.add{
        type = "frame",
        name = "main-container",
        direction = "vertical",
        style = "inside_shallow_frame",
    }

    do -- control subheader
        main_container.add{
            type = "frame",
            style = "ei_subheader_frame",
        }.add{
            type = "label",
            caption = {"exotic-industries-fueler.fueler-gui-control-title"},
            style = "subheader_caption_label",
        }
    
        local control_flow = main_container.add{
            type = "flow",
            name = "control-flow",
            direction = "vertical",
            style = "ei_inner_content_flow",
        }

        control_flow.add{
            type = "label",
            caption = {"exotic-industries-fueler.fueler-gui-control-description"},
            tooltip = {"exotic-industries-fueler.fueler-gui-control-description-tooltip"},
        }

        local button_frame = control_flow.add{
            type = "frame",
            name = "target-frame",
            style = "slot_button_deep_frame"
        }
        for _, target_name in ipairs(model.target_types) do
            button_frame.add{
                type = "sprite-button",
                sprite = "entity/" .. target_name,
                tooltip = {"entity-name." .. target_name},
                tags = {
                    action = "set-target-type",
                    parent_gui = "ei_fueler-console",
                    target_type = target_name
                },
                style = "ei_slot_button_radio"
            }
        end
        control_flow.add{type = "empty-widget", style = "ei_vertical_pusher"}

        control_flow.add{
            type = "label",
            caption = {"exotic-industries-fueler.fueler-gui-equipment-description"},
            tooltip = {"exotic-industries-fueler.fueler-gui-equipment-description-tooltip"},
        }

        local equipment_frame = control_flow.add{
            type = "frame",
            name = "equipment-frame",
            style = "slot_button_deep_frame"
        }
        equipment_frame.add{
            type = "sprite-button",
            sprite = "ei_vehicle",
            tooltip = {"exotic-industries-fueler.vehicle"},
            tags = {
                action = "set-equipment-type",
                parent_gui = "ei_fueler-console",
                equipment_type = false
            },
            style = "ei_slot_button_radio"
        }
        equipment_frame.add{
            type = "sprite-button",
            sprite = "ei_equipment",
            tooltip = {"exotic-industries-fueler.equipment"},
            tags = {
                action = "set-equipment-type",
                parent_gui = "ei_fueler-console",
                equipment_type = true
            },
            style = "ei_slot_button_radio"
        }

        control_flow.add{type = "empty-widget", style = "ei_vertical_pusher"}
        

    end

    model.update_gui(player)

end


function model.update_gui(player)

    -- sync gui with current setting of tower

    local root = player.gui.relative["ei_fueler-console"]
    if not root then
        return
    end

    local control = root["main-container"]["control-flow"]
    local target_frame = control["target-frame"]

    -- get sync
    local fueler_unit = player.opened.unit_number
    local target = model.get_target_type(fueler_unit)
    local equipment = model.get_equipment(fueler_unit)

    -- update gui
    -- target_frame.tags = {selected = target}
    for _, elem in pairs(target_frame.children) do
        if elem.tags.target_type == target then
            elem.enabled = false
        else
            elem.enabled = true
        end
    end

    local equipment_frame = control["equipment-frame"]
    -- equipment_frame.tags = {selected = equipment}
    for _, elem in pairs(equipment_frame.children) do
        if elem.tags.equipment_type == equipment then
            elem.enabled = false
        else
            elem.enabled = true
        end
    end

end


function model.close_gui(player)
    if player.gui.relative["ei_fueler-console"] then
        player.gui.relative["ei_fueler-console"].destroy()
    end
end


function model.on_gui_click(event)
    if event.element.tags.action == "set-target-type" then
        local player = game.players[event.player_index]
        local root = player.gui.relative["ei_fueler-console"]
        if not root then
            return
        end

        local fueler_unit = player.opened.unit_number
        local target = event.element.tags.target_type

        model.set_target_type(fueler_unit, target)

        -- if new target type is player then set equipment to true
        if target == "character" then
            model.set_equipment(fueler_unit, true)
        end

        model.update_gui(player)
    end

    if event.element.tags.action == "set-equipment-type" then
        local player = game.players[event.player_index]
        local root = player.gui.relative["ei_fueler-console"]
        if not root then
            return
        end

        local fueler_unit = player.opened.unit_number
        local equipment_type = event.element.tags.equipment_type

        -- dont let player set equipment to false if target is player
        if equipment_type == false and model.get_target_type(fueler_unit) == "character" then
            return
        end

        model.set_equipment(fueler_unit, equipment_type)

        model.update_gui(player)
    end

    if event.element.tags.action == "goto-informatron" then 
        remote.call("informatron", "informatron_open_to_page", {
            player_index = event.player_index,
            interface = "exotic-industries-fueler-informatron",
            page_name = event.element.tags.page
        })
    end
end


return model

-- TODO
-- more UPS optimization
-- add character handling
-- add tech
-- add gui
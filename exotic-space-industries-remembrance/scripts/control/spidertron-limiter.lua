local model = {}

local function get_item_prototypes()
    if prototypes and prototypes.item then
        return prototypes.item
    end

    if game and game.item_prototypes then
        return game.item_prototypes
    end
end

local function get_requested_item_name(slot)
    if not slot or not slot.value then
        return nil
    end

    if type(slot.value) == "string" then
        return slot.value
    end

    if slot.value.type ~= nil and slot.value.type ~= "item" then
        return nil
    end

    return slot.value.name
end

local function is_allowed_spiderling_fuel(entity, item_name)
    if not entity or not entity.valid or not item_name then
        return false
    end

    local burner = entity.burner
    if not burner or not burner.fuel_categories then
        return false
    end

    local item_prototypes = get_item_prototypes()
    local item = item_prototypes and item_prototypes[item_name]
    local fuel_category = item and item.fuel_category

    return fuel_category ~= nil and burner.fuel_categories[fuel_category] == true
end

local function print_rejection_message(event)
    local player = event.player_index and game and game.get_player(event.player_index)
    if player then
        player.print("Only fuel items can be requested for this spidertron.")
        return
    end

    if game then
        game.print("Only fuel items can be requested for this spidertron.")
    end
end

--====================================================================================================
--SPIDERTRON LIMITER
--====================================================================================================
function model.remove_nonfuel_requests(event)
    if not event or not event.entity or not event.section or not event.slot_index then
        return
    end

    if not event.section.valid or not event.section.is_manual then
        return
    end

    local slot = event.section.get_slot(event.slot_index)
    local requested_item = get_requested_item_name(slot)

    if not requested_item then
        event.section.clear_slot(event.slot_index)
        print_rejection_message(event)
        return
    end

    if not is_allowed_spiderling_fuel(event.entity, requested_item) then
        event.section.clear_slot(event.slot_index)
        print_rejection_message(event)
    end
end

function model.on_entity_logistic_slot_changed(event)

    -- spider vehicle as spiderling should only allow request of fuel
    if not event then return end
    if not event.entity or not event.entity.valid then return end
    local entity = event.entity
    if not entity.type then return end
--    local inbound_slots = entity.logistic_sections["inbound"]
--    if not inbound_slots then return end

    if entity.type ~= "spider-vehicle" then
        return
    end

    if entity.name == "sp-spiderling" then
        model.remove_nonfuel_requests(event)
    end

end


return model

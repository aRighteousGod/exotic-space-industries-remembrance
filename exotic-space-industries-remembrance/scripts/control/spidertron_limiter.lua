local model = {}

--====================================================================================================
--SPIDERTRON LIMITER
--====================================================================================================
function model.remove_nonfuel_requests(event)
    if event.entity and event.section and event.slot_index then
        local name = event.section.get_slot(event.slot_index)
        if name and name.value and name.value.name then
            if not ei_lib.endswith(name.value.name,"fuel") then
               event.section.clear_slot(event.slot_index)
               game.print("Only fuel items can be requested for this spidertron.")
            end
        end
    end
end
--[[]
    if slot == nil then
        return
    end

    if slot.name == nil then
        return
    end

    local item = prototypes.item[slot.name]

    if item.fuel_category then
        if item.fuel_category == "ei-fusion-fuel" or item.fuel_category == "ei-nuclear-fuel" or item.fuel_category == "chemical" then
            return 
        end
    end

    entity.clear_vehicle_logistic_slot(slot_id)

    -- send message
    game.print("Only fuel items can be requested for this spidertron.")

end
]]

function model.on_entity_logistic_slot_changed(event)

    -- spider vehicle as spiderling should only allow request of fuel
    if not event then return end
    if not event.entity then return end
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
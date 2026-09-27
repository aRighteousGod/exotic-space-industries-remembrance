for _,id in ipairs{"a","b"} do
    local fire=table.deepcopy(data.raw.fire["fire-flame"])
    fire.name="proof-fire-"..id
    local sticker=table.deepcopy(data.raw.sticker["fire-sticker"])
    sticker.name="proof-sticker-"..id
    data:extend{fire,sticker}
    for _,kind in ipairs{"fire","sticker"} do
        local effect=kind=="fire" and {type="create-fire",entity_name=fire.name} or {type="create-sticker",sticker=sticker.name}
        effect.trigger_created_entity=true
        data:extend{{type="projectile",name="proof-"..kind.."-shot-"..id,flags={"not-on-map"},acceleration=0,
            action={type="direct",action_delivery={type="instant",target_effects={effect}}}}}
    end
end

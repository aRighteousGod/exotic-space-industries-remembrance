local config=require("test-config")
if not config.overlap then return end
local catalog=require("__exotic-space-industries-remembrance__/lib/flamethrower-fuels")
local visited={}
local counts={sticker=0,fire=0}
local function audit(node)
    if visited[node] then return end
    visited[node]=true
    local kind=node.type=="create-sticker" and catalog.fire_stickers[node.sticker] and "sticker"
        or node.type=="create-fire" and catalog.ground_fires[node.entity_name] and "fire"
    if kind then
        assert((node.trigger_created_entity==true)==config.enabled,"Unexpected notification state: "..(node.sticker or node.entity_name))
        counts[kind]=counts[kind]+1
    end
    for _,value in pairs(node) do if type(value)=="table" then audit(value) end end
end
audit(data.raw)
assert(counts.sticker>20 and counts.fire>20)
log("FLAME_OVERLAP_PROTOTYPES "..serpent.line(counts))
for _,kind in ipairs{"fire","sticker"} do
    for name in pairs(kind=="fire" and catalog.ground_fires or catalog.fire_stickers) do
        assert(data.raw[kind][name],name)
        local effect=kind=="fire" and {type="create-fire",entity_name=name} or {type="create-sticker",sticker=name}
        -- Deliberately notify even in disabled mode to prove the dispatcher
        -- ignores foreign/old notification sources as well as native impacts.
        effect.trigger_created_entity=true
        data:extend{{type="projectile",name="overlap-qc-"..name,flags={"not-on-map"},acceleration=0,
            action={type="direct",action_delivery={type="instant",target_effects={effect}}}}}
    end
end
data:extend{{type="projectile",name="overlap-qc-legacy-extinguisher",flags={"not-on-map"},acceleration=0,
    action={type="direct",action_delivery={type="instant",target_effects={
        type="create-entity",entity_name="extinguisher-remnants",trigger_created_entity=true}}}}}
local unrelated=table.deepcopy(data.raw.sticker["fire-sticker"])
unrelated.name="overlap-qc-unrelated-sticker"
unrelated.damage_per_tick=nil
unrelated.spread_fire_entity=nil
local unrelated_fire=table.deepcopy(data.raw.fire["fire-flame"])
unrelated_fire.name="overlap-qc-unrelated-fire"
data:extend{unrelated,unrelated_fire}
-- Assert tank delivery remains ground-fire-free after the final pass.
for _,fuel in ipairs(catalog.fuels) do
    local stream=data.raw.stream["ei-flame-"..fuel.id.."-tank-flamethrower-fire-stream"]
    assert(not serpent.line(stream.action):find('create%-fire'))
end

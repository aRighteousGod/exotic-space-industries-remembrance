local snap=data.combat_doctrines_qc
data.combat_doctrines_qc=nil
local test=require("test-config")
local bp=require("__exotic-space-industries-remembrance__/lib/ballistic-divergence-config")
local rp=require("__exotic-space-industries-remembrance__/lib/pyric-radiance-config")
local b,r=bp.resolve(),rp.resolve()
assert(b.visual_fidelity==test["ballistic-divergence"] and r.visual_fidelity==test["pyric-radiance"],
    "QC startup doctrine must resolve to the requested name")
local be,re=bp.enabled(),rp.enabled()
if test.mode=="overlap" then
    log("COMBAT_DOCTRINES_DATA_QC coexistence prototypes loaded; "..test.phase)
    return
end
local count=0
local function check(pass,message) count=count+1;assert(pass,"Combat doctrines QC: "..message) end
local function eq(a,c)
    if type(a)~=type(c) then return false end
    if type(a)~="table" then return a==c end
    for k,v in pairs(a) do if not eq(v,c[k]) then return false end end
    for k in pairs(c) do if a[k]==nil then return false end end
    return true
end
local function list(node) return node and (node.type and {node} or node) or {} end
local names={}
local payloads=0
if test.mode=="compatibility" then
    local prefix="ei-combat-doctrines-qc-"
    local original=snap.before.ammo[prefix.."wide-shotgun"].ammo_type.action.action_delivery
    local current=data.raw.ammo[prefix.."wide-shotgun"].ammo_type.action.action_delivery
    local id="ei-ballistic-divergence-"..prefix.."wide-shotgun-1-1-1"
    check(data.raw.projectile[id]~=nil,"wide external shotgun stable helper")
    if be and .6*b.shotgun_variation<2 then check(current.projectile==id,"supported external shotgun conversion")
    else check(eq(current,original),"unsafe external shotgun remains intact") end
    local old=snap.before.ammo[prefix.."branches"]
    local new=data.raw.ammo[prefix.."branches"]
    check(new.magazine_size==old.magazine_size,"partial support preserves whole-item capacity")
    check(eq(new.ammo_type[2],old.ammo_type[2]),"unsupported source branch remains intact")
    check(new.ammo_type[1].source_type=="player" and new.ammo_type[1].range_modifier==1.3,"supported source branch metadata")
    local converted=false
    for _,a in ipairs(list(new.ammo_type[1].action)) do
        for _,d in ipairs(list(a.action_delivery)) do if d.type=="projectile" then converted=true end end
    end
    check(be and converted or not be and eq(new.ammo_type[1],old.ammo_type[1]),"independent source branch conversion")
    local oldactions=list(snap.before.ammo[prefix.."dual"].ammo_type.action)
    local newactions=list(data.raw.ammo[prefix.."dual"].ammo_type.action)
    local action_index
    for i,a in ipairs(oldactions) do if a.probability==.7 then action_index=i;break end end
    old=oldactions[action_index];new=newactions[action_index]
    check(new.repeat_count==2 and new.probability==.7,"dual delivery launch gates")
    for i=1,2 do
        local helper=data.raw.projectile["ei-ballistic-divergence-"..prefix.."dual-1-"..action_index.."-"..i]
        check(helper~=nil,"one stable helper per direct delivery")
        check(eq(helper.action.action_delivery.target_effects,old.action_delivery[i].target_effects),"dual delivery complete impact payload")
        check(helper.action.repeat_count==nil,"launch repetition not squared at impact")
        check(eq(new.action_delivery[i].source_effects,old.action_delivery[i].source_effects),"dual delivery launch effects")
    end
end
for name,original in pairs(snap.before.ammo) do
    if (original.ammo_category=="bullet" or original.ammo_category=="shotgun-shell") and not name:find("ei-combat-doctrines-qc-",1,true) then
        names[#names+1]=name
        local current=data.raw.ammo[name]
        check(current.magazine_size==(be and original.ammo_category=="bullet"
            and math.ceil((original.magazine_size or 1)*b.magazine) or original.magazine_size),name.." capacity")
        local oldtypes=original.ammo_type.action and {original.ammo_type} or original.ammo_type
        local newtypes=current.ammo_type.action and {current.ammo_type} or current.ammo_type
        for bi,oldtype in ipairs(oldtypes) do
            local newtype=newtypes[bi]
            check(newtype.range_modifier==oldtype.range_modifier,name.." acquisition modifier")
            check(newtype.source_type==oldtype.source_type,name.." source branch")
            local actions=list(newtype.action)
            for ai,action in ipairs(list(oldtype.action)) do
                check(actions[ai].repeat_count==action.repeat_count and actions[ai].probability==action.probability,name.." multiplicity")
                for di,delivery in ipairs(list(action.action_delivery)) do
                    local d=list(actions[ai].action_delivery)[di]
                    check(eq(d.source_effects,delivery.source_effects),name.." launch effects")
                    if delivery.type=="projectile" or (delivery.type=="instant" and delivery.target_effects) then
                        local id="ei-ballistic-divergence-"..name.."-"..bi.."-"..ai.."-"..di
                        local projectile=data.raw.projectile[id]
                        check(projectile~=nil,id.." stable helper")
                        if be then
                            check(d.type=="projectile" and d.projectile==id,name.." native trajectory")
                            check(projectile.force_condition=="not-same",name.." force policy")
                            if delivery.type=="instant" then
                                check(eq(projectile.action.action_delivery.target_effects,delivery.target_effects),name.." complete impact payload")
                                check(d.target_effects==nil and d.starting_speed==1,name.." impact split/speed")
                                check(eq(projectile.collision_box,{{-.05,-.25},{.05,.25}}),name.." collision geometry")
                                local physical=0
                                for _,effect in ipairs(list(delivery.target_effects)) do
                                    if effect.type=="damage" and effect.damage.type=="physical" then physical=physical+effect.damage.amount end
                                end
                                local penetrates=name=="piercing-rounds-magazine" or name=="uranium-rounds-magazine"
                                check(projectile.piercing_damage==(penetrates and 25*physical or 0),name.." penetration")
                            else
                                -- Fuel/performance finalizers own later aliases in
                                -- both the original pellet and its private copy.
                                check(eq(projectile.action,data.raw.projectile[delivery.projectile].action),name.." existing projectile payload")
                                check(d.direction_deviation==delivery.direction_deviation and d.starting_speed==delivery.starting_speed
                                    and d.starting_speed_deviation==delivery.starting_speed_deviation,name.." native cone/speed")
                                check(eq(d.target_effects,delivery.target_effects),name.." delivery payload")
                            end
                            local dev=original.ammo_category=="bullet" and .4*b.scatter or (delivery.range_deviation or 0)*b.shotgun_variation
                            check(d.range_deviation==dev and dev<2,name.." range variation")
                            local expected_min=original.ammo_category=="bullet" and 30 or (delivery.max_range or 1000)
                            check(d.max_range>=expected_min*b.flight/(1-dev/2),name.." original travel coverage")
                            check(d.max_range*(1-dev/2)>=90*1.5*b.flight,name.." finalized quality range")
                        else
                            check(eq(d,delivery),name.." disabled delivery")
                        end
                        payloads=payloads+1
                    else check(eq(d,delivery),name.." source-only delivery") end
                end
            end
        end
    end
end
for name,old in pairs(snap.before.gun) do
    local current=data.raw.gun[name].attack_parameters
    check(current.range==old.attack_parameters.range and current.damage_modifier==old.attack_parameters.damage_modifier,name.." gun mechanics")
end
local defender=data.raw["combat-robot"].defender.attack_parameters
local olddef=snap.before["combat-robot"].defender.attack_parameters
check(defender.range==olddef.range and defender.damage_modifier==olddef.damage_modifier,"Defender mechanics")
if be then
    local d=list(list(defender.ammo_type.action)[1].action_delivery)[1]
    local old=list(list(olddef.ammo_type.action)[1].action_delivery)[1]
    check(eq(data.raw.projectile[d.projectile].action.action_delivery.target_effects,old.target_effects),"Defender own impact")
end
for _,kind in ipairs{"tree","simple-entity"} do
    for name,old in pairs(snap.before[kind]) do
        local current=data.raw[kind][name]
        local eligible=kind=="tree" or old.count_as_rock_for_filtered_deconstruction or string.find(name,"rock",1,true)
        if be and b.terrain and eligible then
            local physical
            for _,res in ipairs(current.resistances or {}) do if res.type=="physical" then physical=res end end
            check(physical and physical.decrease>=(kind=="tree" and 2 or 4)
                and physical.percent>=(kind=="tree" and 65 or 75),name.." terrain floor")
            for _,res in ipairs(old.resistances or {}) do
                if res.type=="physical" then check(physical.decrease>=(res.decrease or 0) and physical.percent>=(res.percent or 0),name.." stronger terrain resistance") end
            end
        else check(eq(current.resistances,old.resistances),name.." terrain isolation") end
    end
end
local lightfields={light=true,stream_light=true,ground_light=true,muzzle_light=true,base_engine_light=true,glow_light=true}
local function lights_valid(light)
    for _,v in ipairs(light and (light[1] and light or {light}) or {}) do
        check((v.intensity or 0)>=0 and (v.intensity or 0)<=1,"ordinary intensity")
        check((v.size or 0)<=64,"ordinary radius")
    end
end
for kind,rows in pairs(snap.visual) do
    for name,old in pairs(rows) do
        local current=data.raw[kind][name]
        if not re then check(eq(current,old),kind.."/"..name.." disabled radiance")
        elseif not eq(old,current) then
            local clean=table.deepcopy(current)
            for field in pairs(lightfields) do
                if not eq(old[field],current[field]) then lights_valid(current[field]);clean[field]=old[field] end
            end
            if kind=="sticker" then
                check(#current.update_effects==#(old.update_effects or {})+1,name.." native sticker effect")
                clean.update_effects=old.update_effects
            elseif kind=="projectile" and not eq(clean.action,old.action)
                and (name=="atomic-rocket" or name=="ei-atomic-rocket-u235") then
                local added=0
                for _,action in ipairs(list(clean.action)) do
                    for _,delivery in ipairs(list(action.action_delivery)) do
                        local effects=delivery.target_effects
                        if effects and effects[#effects].entity_name=="ei-pyric-radiance-"..name.."-flash" then
                            added=added+1;table.remove(effects)
                        end
                    end
                end
                check(r.nuclear>0 and added==1,name.." extra nuclear flash")
            end
            check(eq(clean,old),kind.."/"..name.." presentation isolation")
        end
    end
end
table.sort(names)
log("COMBAT_DOCTRINES_DATA_QC "..count.." checks; "..#names.." ammunition; "..payloads.." payloads; "..test.phase)
if test.mode~="firing" and test.mode~=nil then return end

-- Disposable observations added only AFTER production assertions. Headless
-- source flashes explicitly bypass visibility for entity-count verification.
local function observe(actions,id)
    local rows=list(actions)
    rows[#rows+1]={type="direct",action_delivery={type="instant",target_effects={{type="script",effect_id=id}}}}
    return rows
end
local function flashes(node)
    if type(node)~="table" then return end
    if node.type=="create-explosion" then
        node.only_when_visible=false
        local explosion=data.raw.explosion[node.entity_name]
        if explosion and not explosion.combat_qc_flash then
            explosion.created_effect=observe(explosion.created_effect,"ei-combat-qc-flash")
            explosion.combat_qc_flash=true
        end
    end
    for _,child in pairs(node) do if type(child)=="table" then flashes(child) end end
end
for _,name in ipairs(names) do
    local ammo=data.raw.ammo[name]
    for _,kind in ipairs(ammo.ammo_type.action and {ammo.ammo_type} or ammo.ammo_type) do
        for _,action in ipairs(list(kind.action)) do
            for _,d in ipairs(list(action.action_delivery)) do flashes(d.source_effects) end
        end
        kind.action=observe(kind.action,"ei-combat-qc-launch:"..name)
    end
end
local robot=data.raw["combat-robot"].defender.attack_parameters
robot.ammo_type.action=observe(robot.ammo_type.action,"ei-combat-qc-launch:defender")
for name,p in pairs(data.raw.projectile) do
    if name:sub(1,#"ei-ballistic-divergence-")=="ei-ballistic-divergence-" then
        p.created_effect=observe(p.created_effect,"ei-combat-qc-created")
        p.action=observe(p.action,"ei-combat-qc-impact")
    end
end

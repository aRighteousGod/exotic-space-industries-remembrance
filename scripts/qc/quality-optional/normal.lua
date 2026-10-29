-- Runs inside the private ESIR control context, using real native owners.
local model={}
local lib=require("__exotic-space-industries-remembrance__/lib/lib")
local fueler=require("__exotic-space-industries-remembrance__/scripts/control/fueler/fueler")
local em=require("__exotic-space-industries-remembrance__/scripts/control/em-trains/charger")
local matter=require("__exotic-space-industries-remembrance__/scripts/control/matter-stabilizer")
local crystal=require("__exotic-space-industries-remembrance__/scripts/control/crystal-accumulator")
local radar=require("__exotic-space-industries-remembrance__/scripts/control/sweeping-radar")
local radar_config=require("__exotic-space-industries-remembrance__/lib/sweeping-radar-config")
local emerald=require("__exotic-space-industries-remembrance__/scripts/control/emerald-apocalypse-hover-tank")
local shards=require("__exotic-space-industries-remembrance__/scripts/control/emerald-apocalypse-orbital-shards")
local function check(value,label)
    local q=storage.quality_normal_qc
    q.checks=q.checks+1
    assert(value,"QUALITY NORMAL OPERATION: "..label)
    q.labels[#q.labels+1]=label
end
local function same(a,b,label)check(math.abs(a-b)<0.01,label..": "..a.." expected "..b)end
local function burst()
    local q=storage.quality_normal_qc
    local root=storage.ei.runtime_scheduler.modules.anisetron
    local owner=root and root.active[q.anisetron.unit_number]
    return owner and owner.burst
end
local function contract(b)
    local result={}
    for _,key in ipairs({"quality","contract_version","duration","contact_ticks","damage","crown_damage","facade_damage",
        "research_multiplier","crown_range","facade_range","start_tick","end_tick"}) do result[key]=b[key] end
    return result
end
function model.setup(tick)
    local q={checks=0,labels={},started=tick,contacts={crown=0,facade=0,shards=0}}
    storage.quality_normal_qc=q
    local force=game.create_force("quality-normal-qc")
    local surface=game.create_surface("quality-normal-qc",{width=512,height=512})
    surface.request_to_generate_chunks({0,0},5);surface.force_generate_chunk_requests()
    for _,entity in pairs(surface.find_entities()) do entity.destroy() end
    q.surface=surface
    local player=game.get_player(1)
    if player then
        if player.controller_type==defines.controllers.cutscene then player.exit_cutscene() end
        local character=player.character or player.surface.create_entity{name="character",position=player.position,force=player.force}
        player.set_controller{type=defines.controllers.character,character=character}
        player.teleport({0,100},surface)
    end
    local function create(name,x,y)
        return assert(surface.create_entity{name=name,position={x,y},force=force,quality="normal",raise_built=true})
    end
    q.fueler=create("ei-fueler",-60,60)
    q.turret=create("gun-turret",-55,60)
    q.fueler.get_inventory(defines.inventory.chest).insert{name="firearm-magazine",count=10}
    check(fueler.get_normalized_quality_factor(q.fueler)==0,"Fueler normal factor")
    for y=-110,-70,2 do surface.create_entity{name="straight-rail",position={-80,y},direction=defines.direction.north,force=force} end
    q.locomotive=create("ei_em-locomotive",-80,-90)
    q.charger=create("ei_charger",-72,-90)
    q.charger.energy=500000000
    q.locomotive.burner.remaining_burning_fuel=0
    em.update_train(q.locomotive,tick)
    check(lib.get_prototype_name(q.locomotive.burner.currently_burning.name)==em.get_selected_em_fuel_prototype().name,"EM native selected fuel")
    same(q.charger.energy,400000000,"EM normal transfer payment")
    em.update_train(q.locomotive,tick)
    same(q.charger.energy,400000000,"EM full native fuel is not charged twice")
    check(storage.ei_emt.trains[q.locomotive.unit_number].grace_until_tick==0,"EM normal grace baseline")
    q.machine=create("ei-exotic-assembler",60,-90);q.machine.destructible=false
    local stabilizer=create("ei-matter-stabilizer",66,-90)
    check(matter.get_stabilizer_weight(stabilizer)==1,"normal stabilizer weight")
    same(matter.get_machine_base_chance(q.machine),0.12,"normal containment baseline")
    force.technologies["ei-high-tech-parts"].researched=true
    local recipe=assert(force.recipes["ei-high-tech-parts"])
    check(recipe.enabled,"native research unlocks fixture recipe")
    check(q.machine.set_recipe(recipe),"native matter recipe")
    for _,name in ipairs({"ei-eu-magnet","ei-eu-circuit","ei-plasma-cube","ei-exotic-matter-up"}) do
        check(q.machine.insert{name=name,count=1}==1,"matter ingredient "..name)
    end
    q.machine.energy=q.machine.electric_buffer_size
    local wrong=surface.create_entity{name="ei-crystal-accumulator-gaia",position={110,50},force=force,quality="normal"}
    wrong.energy=12345678
    local health=wrong.max_health*0.7;wrong.health=health
    crystal.on_built_entity{entity=wrong,tick=tick}
    local right=surface.find_entities_filtered{name="ei-crystal-accumulator",position={110,50},radius=2}[1]
    check(not wrong.valid and right and right.quality.name=="normal","crystal native normal shell replacement")
    same(right.energy,12345678,"crystal energy custody");same(right.health,health,"crystal health custody")
    q.crystal=right
    q.radar=create("ei-sweeping-radar",80,70)
    local r=assert(radar.get_record(q.radar))
    local settings=radar_config.defaults();settings.run=0;settings.mode=5
    for _,geometry in pairs(settings.modes) do geometry.radius=1;geometry.near=0 end
    radar.set_settings(r,settings,tick);r.power.energy=r.power.electric_buffer_size
    q.radar_settings=settings
    if prototypes.quality.rare then
        q.radar_high=assert(surface.create_entity{name="ei-sweeping-radar",position={-110,-30},
            force=force,quality="rare",raise_built=true})
        local high=assert(radar.get_record(q.radar_high))
        local high_settings=radar_config.defaults();high_settings.mode=5
        for _,geometry in pairs(high_settings.modes) do geometry.radius=1;geometry.near=0 end
        high_settings.run=1;radar.set_settings(high,high_settings,tick)
        high.power.energy=high.power.electric_buffer_size
        q.high_settings=high_settings
    end
    q.anisetron=create("ei-anisetron",0,20)
    q.anisetron.orientation=0
    q.anisetron.vehicle_automatic_targeting_parameters={auto_target_with_gunner=true,auto_target_without_gunner=true}
    q.anisetron.get_inventory(defines.inventory.spider_ammo)[1].set_stack{
        name="ei-anisetron-crystal-charge",count=1,ammo=1,quality="normal"}
    q.target=surface.create_entity{name="esir-qc-quality-target",position={0,0},force="enemy"}
    q.shards=create(emerald.tank_name,-150,20)
    q.shard_target=surface.create_entity{name="esir-qc-quality-target",position={-130,20},force="enemy"}
    local profile=shards.get_effective_damage(storage.ei.emerald_apocalypse_hover_tank,force,q.shards,tick)
    check(profile.quality_factor==0 and profile.quality_multiplier==1 and profile.shard_damage==240
        and profile.active_shard_count==3 and profile.cooldown_ticks==70,"orbital shards normal profile")
    return {checks=q.checks}
end
function model.step(tick)
    local q=assert(storage.quality_normal_qc)
    local age=tick-q.started
    if q.machine.valid then q.machine.energy=q.machine.electric_buffer_size end
    local r=radar.get_record(q.radar)
    if age==30 then
        if q.radar_high then
            q.high_settings.run=0
            radar.set_settings(radar.get_record(q.radar_high),q.high_settings,tick)
        end
        check(r.maximum==16 and r.rate==2 and r.cost==8000000,"radar normal derived baseline")
        check(r.quality_range==0 and r.quality_rate==1 and r.quality_energy==1,"radar native normal multipliers")
        q.radar_idle=r.power.energy;q.radar_paid=radar.get_state().counters.paid_joules
    elseif age==90 then
        same(q.radar_idle-r.power.energy,1000000,"radar paid native standby")
        same(radar.get_state().counters.paid_joules,q.radar_paid,"paused radar no observations charged")
        q.radar_start=r.power.energy;q.radar_paid_start=radar.get_state().counters.paid_joules
        q.radar_settings.run=1;radar.set_settings(r,q.radar_settings,tick)
    elseif age==150 then
        same(q.radar_start-r.power.energy,9000000,"radar standby plus one observation")
        same(radar.get_state().counters.paid_joules-q.radar_paid_start,8000000,"radar one paid observation")
        local b=assert(burst(),"native ANISETRON must have consumed its charge")
        check(b.contract_version==3 and b.quality=="normal" and b.duration==1200 and b.contact_ticks==12,"ANISETRON paid duration")
        check(b.crown_damage==320 and b.facade_damage==160 and b.research_multiplier==1,"ANISETRON paid damage")
        check(b.crown_range==85 and b.facade_range==30,"ANISETRON paid ranges")
        check(q.anisetron.get_inventory(defines.inventory.spider_ammo).is_empty(),"ANISETRON native payment")
        q.paid_contract=contract(b)
        q.cannon=q.surface.create_entity{name=emerald.tank_name,position={130,170},force=q.shards.force,quality="normal",raise_built=true}
        q.cannon_target=q.surface.create_entity{name="esir-qc-quality-target",position={130,100},force="enemy"}
        local ammo=q.cannon.get_inventory(defines.inventory.car_ammo)
        ammo[1].set_stack{name=emerald.charge_item,count=1,quality="normal"};ammo[1].ammo=1
        q.cannon_driver=q.surface.create_entity{name="character",position={130,176},force=q.cannon.force}
        q.cannon.set_driver(q.cannon_driver);q.cannon.driver_is_gunner=true;q.cannon.selected_gun_index=1
        q.cannon_driver.selected=q.cannon_target
        q.cannon_driver.shooting_state={state=defines.shooting.shooting_selected,position=q.cannon_target.position}
    elseif age==160 and q.cannon then
        local driver=q.cannon.get_driver()
        if driver then driver.shooting_state={state=defines.shooting.not_shooting,position=q.cannon_target.position} end
        q.cannon.set_driver(nil)
        local record=storage.ei.emerald_apocalypse_hover_tank.tanks_by_unit[q.cannon.unit_number]
        check(record.charge_profile and record.charge_due_tick>tick,"native paid Emerald wind-up")
        q.cannon_contract=table.deepcopy(record.charge_profile);q.cannon_due=record.charge_due_tick
    end
    if q.cannon and age>150 and age<160 then
        q.cannon_driver.selected=q.cannon_target
        q.cannon_driver.shooting_state={state=defines.shooting.shooting_selected,position=q.cannon_target.position}
    end
end
function model.immediate()
    local q=assert(storage.quality_normal_qc)
    local b=assert(burst(),"paid ANISETRON burst retained")
    check(serpent.line(contract(b),{sortkeys=true})==serpent.line(q.paid_contract,{sortkeys=true}),"paid burst exact execution contract retained")
    local r=radar.get_record(q.radar)
    check(r.maximum==16 and r.rate==2 and r.cost==8000000,"radar derived stats rebuilt to normal")
    check(lib.get_normalized_quality_factor(q.locomotive)==0 and fueler.get_normalized_quality_factor(q.fueler)==0,"normal factors after configuration")
    q.radar_paid_after=radar.get_state().counters.paid_joules
    if q.radar_contract then
        check(r.quality_refresh_pending and r.job and r.job.paid,"paid radar retained through configuration")
        check(r.epoch==q.radar_contract.epoch and r.batch.cursor==q.radar_contract.cursor,"paid radar batch/epoch retained")
        same(r.cost,q.radar_contract.cost,"paid radar numeric cost retained")
        same(radar.get_state().counters.paid_joules,q.radar_contract.paid,"paid radar not charged again")
    end
    if q.high_contract and q.radar_high.valid then
        local high=radar.get_record(q.radar_high)
        check(high.job and high.job.paid and high.quality_refresh_pending,"higher-tier paid radar retained")
        check(high.maximum==q.high_contract.maximum and high.cost==q.high_contract.cost
            and high.rate==q.high_contract.rate,"higher-tier paid numeric context retained")
        q.high_survived=true
    end
    if q.cannon then
        local record=storage.ei.emerald_apocalypse_hover_tank.tanks_by_unit[q.cannon.unit_number]
        check(record.charge_due_tick==q.cannon_due and serpent.line(record.charge_profile,{sortkeys=true})
            ==serpent.line(q.cannon_contract,{sortkeys=true}),"paid Emerald wind-up and numeric contract retained")
    end
    local profile=shards.get_effective_damage(storage.ei.emerald_apocalypse_hover_tank,q.shards.force,q.shards,game.tick)
    check(profile.quality_factor==0 and profile.shard_damage==240,"orbital damage refreshed to normal")
    return {checks=q.checks,paid_contract=q.paid_contract}
end
function model.finish()
    local q=assert(storage.quality_normal_qc)
    local ammo=q.turret.get_inventory(defines.inventory.turret_ammo).get_item_count("firearm-magazine")
    check(ammo>0,"Fueler ordinary ammunition transfer")
    check(ammo+q.fueler.get_inventory(defines.inventory.chest).get_item_count("firearm-magazine")==10,"Fueler exact ammunition conservation")
    check(q.machine.products_finished>=1,"matter assembler native craft completed "..serpent.line{
        status=q.machine.status,progress=q.machine.crafting_progress,recipe=q.machine.get_recipe(),
        enabled=q.machine.force.recipes["ei-high-tech-parts"].enabled,input=q.machine.get_inventory(defines.inventory.crafter_input).get_contents(),
        energy=q.machine.energy,disabled=q.machine.disabled_by_script})
    local out=q.machine.get_output_inventory()
    check(out.get_item_count("ei-high-tech-parts")==5 and out.get_item_count("ei-exotic-matter-down")==1,"matter normal native outputs")
    check(q.contacts.crown==100 and q.contacts.facade==100,"ANISETRON exact paid contact counts")
    same(1000000-q.target.health,48000,"ANISETRON exact paid damage")
    check(not burst(),"paid ANISETRON burst completed")
    check(q.anisetron.get_inventory(defines.inventory.spider_ammo).is_empty(),"paid burst not duplicated")
    if q.radar_contract then
        local r=radar.get_record(q.radar)
        check(not r.quality_refresh_pending,"paid radar hands back to normal capabilities")
        check(r.observations==q.radar_contract.observations+1,"one accepted radar observation completed")
        same(radar.get_state().counters.paid_joules,q.radar_contract.paid,"radar completion has no second debit")
    end
    if q.high_survived then
        local high=radar.get_record(q.radar_high)
        check(high.maximum==16 and high.rate==2 and high.cost==8000000,"next radar capability is native normal baseline")
        check(high.observations==q.high_contract.observations+1,"higher-tier paid observation completed once")
    end
    check(q.contacts.shards>0 and q.contacts.shards%3==0,"autonomous orbital shard volleys execute")
    same(1000000-q.shard_target.health,q.contacts.shards*240,"orbital native damage ledger")
    if q.cannon then
        check(q.cannon.get_inventory(defines.inventory.car_ammo).is_empty(),"Emerald charge paid once")
        local record=storage.ei.emerald_apocalypse_hover_tank.tanks_by_unit[q.cannon.unit_number]
        check(record.charge_profile==nil and not storage.ei.emerald_apocalypse_hover_tank.pending_by_unit[q.cannon.unit_number],
            "retained Emerald paid charge completes")
    end
    return {passed=true,checks=q.checks,labels=q.labels,paid_contract=q.paid_contract,contacts=q.contacts}
end
function model.seed_paid_radar(tick)
    local q=assert(storage.quality_normal_qc)
    -- Older disposable donor-start checkpoints granted the recipe directly.
    -- Research its actual unlock before saving so native configuration repair
    -- retains it exactly as it does in a progressed factory.
    q.machine.force.technologies["ei-high-tech-parts"].researched=true
    check(q.machine.force.recipes["ei-high-tech-parts"].enabled,"saved factory recipe has native research")
    local root=radar.get_state()
    local r=radar.get_record(q.radar)
    r.power.energy=r.power.electric_buffer_size
    r.next_poll=tick;radar.qc_service_control(root,r,tick)
    r.next_scan=tick;r.cursor=1;r.pass_complete=false
    radar.qc_begin_job(root,r,tick,true)
    check(r.job and r.job.paid and r.batch,"native paid radar batch captured before aggregation")
    q.radar_contract={epoch=r.epoch,cursor=r.batch.cursor,cost=r.cost,observations=r.observations}
    if q.radar_high then
        local high=radar.get_record(q.radar_high)
        high.power.energy=high.power.electric_buffer_size
        q.high_settings.run=1;radar.set_settings(high,q.high_settings,tick)
        radar.qc_service_control(root,high,tick)
        high.next_scan=tick;high.cursor=1;high.pass_complete=false
        radar.qc_begin_job(root,high,tick,true)
        check(high.job and high.job.paid and high.batch,"native higher-tier radar payment before removal")
        q.high_contract={maximum=high.maximum,rate=high.rate,cost=high.cost,observations=high.observations}
        -- Leave only standby reserve, preventing a subsequent unpaid observation.
        high.power.energy=1000000
    end
    r.power.energy=1000000
    q.radar_contract.paid=root.counters.paid_joules
end
function model.damage(event)
    local q=storage.quality_normal_qc
    if not q then return end
    if event.cause==q.anisetron and event.entity==q.target then
        local channel=event.original_damage_amount==320 and "crown" or event.original_damage_amount==160 and "facade"
        check(channel~=nil,"ANISETRON numeric contact")
        local previous=q["last_"..channel]
        if previous then check(event.tick-previous==12,"ANISETRON paid cadence") end
        q["last_"..channel]=event.tick
        q.contacts[channel]=q.contacts[channel]+1
    elseif event.cause==q.shards and event.entity==q.shard_target then
        same(event.original_damage_amount,240,"orbital normal damage")
        q.contacts.shards=q.contacts.shards+1
    end
end
return model

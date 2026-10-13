-- Identical native missed-fire scene for staged old/current source comparisons.
local test=require('test-config')
script.on_init(function()
    local s=game.create_surface('combat-range-performance',{autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
    -- Cover the pre-change strongest doctrine too; boundaries must not end misses.
    s.request_to_generate_chunks({900,80},32);s.force_generate_chunk_requests()
    storage.surface=s;storage.turrets={};storage.receivers={};storage.start=game.tick;storage.samples={};storage.initial=0
    for x=0,9 do for y=0,9 do
        local target=s.create_entity{name='ei-combat-doctrines-qc-miss-target',position={x*100+8,y*16},force='enemy'}
        local turret=s.create_entity{name='gun-turret',position={x*100,y*16},force='player'}
        turret.orientation=.25;turret.get_inventory(defines.inventory.turret_ammo).insert{name='firearm-magazine',count=1000};turret.shooting_target=target
        storage.turrets[#storage.turrets+1]=turret;storage.receivers[#storage.receivers+1]={entity=target,health=target.health}
        local stack=turret.get_inventory(defines.inventory.turret_ammo)[1];storage.initial=storage.initial+stack.count*stack.prototype.magazine_size
    end end
end)
script.on_event(defines.events.on_tick,function(e)
    local elapsed=e.tick-storage.start
    if elapsed~=1000 and elapsed~=2000 and elapsed~=3500 then return end
    local population=#storage.surface.find_entities_filtered{type='projectile'}
    storage.samples[#storage.samples+1]={tick=elapsed,projectiles=population}
    if elapsed==3500 then
        local damage,remaining=0,0
        for _,r in ipairs(storage.receivers) do damage=damage+r.health-r.entity.health end
        for _,t in ipairs(storage.turrets) do local s=t.get_inventory(defines.inventory.turret_ammo)[1]
            if s.valid_for_read then remaining=remaining+(s.count-1)*s.prototype.magazine_size+s.ammo end end
        local report={phase=test.phase,legacy=test['legacy-travel'],samples=storage.samples,turrets=100,
            shots_fired=storage.initial-remaining,damage=damage,all_pass=damage==0 and population>0}
        helpers.write_file('combat-doctrines-range-performance.json',helpers.table_to_json(report),false)
        assert(report.all_pass,'Simulation fixture must sustain actual missed fire')
    end
end)

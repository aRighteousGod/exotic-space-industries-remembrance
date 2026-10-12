-- Upgrade from the captured pre-index runtime, preserving authoritative state.
local config=require("test-config")
local function call(name,...) return remote.call("ei-water-qc",name,...) end
local first
script.on_event(defines.events.on_tick,function(event)
    local tick=event.tick
    if not first then first=tick end
    if not storage.transition then
        local surface=game.create_surface("water-schema-upgrade",{width=640,height=128})
        surface.request_to_generate_chunks({0,0},9);surface.force_generate_chunk_requests()
        storage.transition={started=tick,turrets={},probes={}}
        for i=1,8 do
            local e=surface.create_entity{name="ei-water-turret",position={-260+i*56,0.5},force="player",raise_built=true}
            call("preferences",e,3,i%2==0);e.insert_fluid{name="water",amount=100}
            storage.transition.turrets[#storage.transition.turrets+1]=e
        end
    end
    local s=storage.transition
    local results=s.results or {};s.results=results
    local function check(name,pass) results[name]={pass=pass==true} end
    if not config.save and tick==first then
        check("schema-upgraded",call("state").schema==2)
        for i,probe in ipairs(s.probes) do
            local r=call("record",probe.entity)
            check("preserved-helper-"..i,r.power==probe.power and r.power.energy>0)
            check("preserved-policy-"..i,r.mode==probe.mode and r.weapon_fires==probe.weapon_fires)
            check("preserved-deadline-"..i,r.next_pulse==probe.next_pulse)
            check("fresh-clock-"..i,not r.aim_checkpoint or r.aim_checkpoint>=first-1)
        end
    end
    for _,e in ipairs(s.turrets) do call("sample",e).power.energy=50000 end
    if tick-s.started==180 and config.save then
        for _,e in ipairs(s.turrets) do
            local r=call("record",e)
            s.probes[#s.probes+1]={entity=e,power=r.power,mode=r.mode,weapon_fires=r.weapon_fires,next_pulse=r.next_pulse}
            e.surface.create_entity{name="ei-oil-fire-flame",position={e.position.x+12,e.position.y},force="neutral"}
        end
        helpers.write_file("water-qc.json",helpers.table_to_json{all_pass=true,cases={prepared={pass=#s.probes==8}}},false)
        game.server_save("water-transition")
    end
    if not config.save and tick-first==400 then
        local root=call("state")
        check("upgrade-resumes-suppression",root.counters.pulses>=8)
        check("registry-preserved",root.count==8)
        local pass=true
        for _,r in pairs(results) do if not r.pass then pass=false end end
        helpers.write_file("water-qc.json",helpers.table_to_json{all_pass=pass,cases=results},false)
    end
end)

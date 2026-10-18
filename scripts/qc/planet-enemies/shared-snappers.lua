-- Staging-only shared-nest compatibility fixture; force ab-enable-nest=false in
-- the isolated settings stage, never by changing the installed dependency ZIP.
do
    local config=require("lib/planet-enemies-config")
    local policy=require("scripts/control/planet-enemies")
    local maps=require("scripts/control/map-settings")
    local previous=script.get_event_handler(defines.events.on_tick)
    local start,checks,old,shared,blocked
    checks={}
    local function check(name,pass) checks[#checks+1]={name=name,pass=not not pass};assert(pass,name) end
    local function control(s,name,n)
        local m=s.map_gen_settings;m.autoplace_controls[name]={frequency=n,size=n,richness=1};s.map_gen_settings=m
    end
    script.on_event(defines.events.on_tick,function(event)
        previous(event)
        if not start then
            start=event.tick
            check("shared option remains selectable",not settings.startup["ab-enable-nest"].value)
            local snapshot=prototypes.mod_data["ei-planet-enemies-qc"].data
            helpers.write_file("planet-enemies-final-data.json",helpers.table_to_json(snapshot),false)
            local found=false
            for _,row in pairs(snapshot.spawn_results["biter-spawner"]) do
                if config.family(row[1],"unit")=="armoured" then found=true end
            end
            check("vanilla nests retain snapper spawn results",found)
            local s=game.surfaces.nauvis;s.no_enemies_mode=false
            s.request_to_generate_chunks({2000,2000},1);s.force_generate_chunk_requests()
            control(s,"enemy-base",1);control(s,config.controls.nauvis.armoured,0)
            check("independent slider inactive in shared mode",not policy.is_disabled(s,"armoured"))
            check("editor explains shared mode",maps.snapshot{surface_index=s.index}.armoured_shared)
            local name
            for n,p in pairs(prototypes.entity) do if config.family(n,p.type)=="armoured" and p.type=="unit" then name=n;break end end
            shared=s.create_entity{name=name,position={2000,2000},force="enemy"}
            check("shared birth allowed with Armoured row Off",shared and not shared.disabled_by_script)
            control(s,"enemy-base",0);control(s,config.controls.nauvis.armoured,1)
            blocked=s.create_entity{name=name,position={2010,2000},force="enemy"}
            check("ordinary Off controls shared births",blocked and blocked.disabled_by_script)
            old=shared
        elseif event.tick==start+3 then
            check("existing shared snapper retained",old.valid)
            check("blocked shared birth removed",not blocked.valid)
            helpers.write_file("shared-snappers.json",helpers.table_to_json{all_pass=true,checks=checks},false)
        end
    end)
end

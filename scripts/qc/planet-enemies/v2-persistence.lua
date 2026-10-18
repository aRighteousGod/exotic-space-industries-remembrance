-- Staging-only native save/reload, sparse overrides, raft queue and Gaia revision QC.
do
    local maps=require("scripts/control/map-settings")
    local policy=require("scripts/control/planet-enemies")
    local admin=require("scripts/control/admin-tools")
    local gaia=require("scripts/control/gaia")
    local previous=script.get_event_handler(defines.events.on_tick)
    local previous_load=assert(__control_ups_load)
    local loaded=false
    script.on_load(function() previous_load();loaded=storage.enemy_v2_persistence~=nil end)
    local function check(name,value)
        local s=storage.enemy_v2_persistence
        s.checks[#s.checks+1]={name=name,pass=not not value}
        assert(value,name)
    end
    local function apply(target,changes,tick)
        local s=assert(maps.snapshot(target));local ok,message=maps.apply(s.target,s.values,changes,tick)
        assert(ok,serpent.line(message));return maps.snapshot(target)
    end
    script.on_event(defines.events.on_tick,function(event)
        local s=storage.enemy_v2_persistence
        if loaded then
            loaded=false;s.reloaded=true
            check("restore queue survives native checkpoint",s.rafts[#s.rafts].valid and s.rafts[#s.rafts].disabled_by_script and policy.has_tick_work(event.tick))
            local pending=maps.snapshot{planet="aquilo"}
            check("pending override persists without surface",pending.pending and not game.planets.aquilo.surface and pending.values.seed==42
                and pending.values.peaceful_mode==false and pending.values["control/ei-aquilo-cold-enemies/enabled"]==false)
            local session=storage.ei.admin_tools.sessions[1]
            local draft=session.map_settings_drafts[s.draft_id]
            check("unsubmitted administrator draft persists",draft and draft.changes.starting_area==5)
            local surface=game.planets.aquilo.create_surface()
            check("pending values govern first native creation",surface.map_gen_settings.seed==42 and not surface.peaceful_mode and policy.is_disabled(surface,"cold"))
        end
        local before=0
        if s then for _,raft in ipairs(s.rafts) do if raft.valid and not raft.disabled_by_script then before=before+1 end end end
        previous(event)
        if not s then
            s={start=event.tick,checks={},rafts={}};storage.enemy_v2_persistence=s
            local global=maps.snapshot{scope="global"};local changes={}
            for _,field in ipairs(global.fields) do
                local value=global.values[field.id]
                if type(value)=="boolean" then changes[field.id]=not value
                elseif field.integer then changes[field.id]=value+1
                else changes[field.id]=value==0 and 0.01 or value*1.01 end
            end
            local changed=apply({scope="global"},changes,event.tick)
            for id,value in pairs(changes) do
                check("native global write "..id,changed.values[id]==value or
                    (type(value)=="number" and math.abs(changed.values[id]-value)<0.00001))
            end
            apply({scope="global"},global.values,event.tick)
            check("fixture starts before Aquilo creation",not game.planets.aquilo.surface)
            apply({planet="aquilo"},{seed=42,peaceful_mode=false,["control/ei-aquilo-cold-enemies/enabled"]=false},event.tick)
            local p=game.players[1];p.admin=true;admin.open(p,"map-settings",event.tick)
            local session=storage.ei.admin_tools.sessions[1];local ui=session.map_settings
            s.draft_id=ui.id
            ui.rows.starting_area.value.text="5"
            script.get_event_handler(defines.events.on_gui_text_changed){player_index=1,element=ui.rows.starting_area.value,tick=event.tick}
            local gleba=game.planets.gleba.create_surface()
            apply({planet="gleba"},{["control/gleba_enemy_base/enabled"]=false},event.tick)
            for i=1,2600 do s.rafts[i]=assert(gleba.create_entity{name="gleba-spawner",position={2000,2000},force="enemy"}) end
            apply({planet="gleba"},{["control/gleba_enemy_base/enabled"]=true},event.tick)
            check("owned rafts await bounded reactivation",s.rafts[2600].disabled_by_script)
            game.server_save("planet-enemies-pending")
            return
        end
        local enabled=0;for _,raft in ipairs(s.rafts) do if raft.valid and not raft.disabled_by_script then enabled=enabled+1 end end
        if enabled~=before then check("restoration budget tick "..event.tick,enabled-before<=64) end
        local age=event.tick-s.start
        if age==60 then
            check("all owned rafts restored",enabled==2600)
            local surface=game.planets.gaia.create_surface();s.gaia_index=surface.index
            apply({planet="gaia"},{seed=13579,starting_area=2,peaceful_mode=true,["control/ei-gaia-electric-enemies/enabled"]=false},event.tick)
            local m=surface.map_gen_settings;m.property_expression_names.elevation="0";surface.map_gen_settings=m
            gaia.reforge_gaia_surface(event);s.reforging=true
        elseif s.reforging then
            local staging=game.surfaces["gaia-reforge-staging"]
            if staging and not s.revised then
                check("Gaia preparation merges overrides before staging",staging.map_gen_settings.seed==13579
                    and staging.map_gen_settings.starting_area==2 and policy.is_disabled(staging,"electric"))
                apply({planet="gaia"},{seed=24680,starting_area=3},event.tick);s.revised=true
            end
            if not storage.ei.reforge_gaia then
                local surface=game.planets.gaia.surface
                check("Gaia ready rechecks latest override revision",s.revised and surface and surface.index~=s.gaia_index
                    and surface.map_gen_settings.seed==24680 and surface.map_gen_settings.starting_area==3
                    and surface.peaceful_mode and policy.is_disabled(surface,"electric"))
                s.reforging=false;s.complete=true
                helpers.write_file("enemy-v2-persistence.json",helpers.table_to_json{all_pass=true,checks=s.checks,reloaded=s.reloaded or false,complete=true},false)
            end
        end
    end)
end

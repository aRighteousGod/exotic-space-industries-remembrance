-- Staging-only integration fixture. Production code is exercised through its owners.
do
    local maps=require("scripts/control/map-settings")
    local policy=require("scripts/control/planet-enemies")
    local config=require("lib/planet-enemies-config")
    local admin=require("scripts/control/admin-tools")
    local schema=require("lib/map-settings-config")
    local previous=script.get_event_handler(defines.events.on_tick)
    local started=false
    local checks,blocked,kept,rafts={},{},{},{}
    local surfaces,batch,infections={},{},{}
    local gui_pending,gui_replaced
    local all_pass=true
    local function check(name,pass,detail)
        checks[#checks+1]={name=name,pass=not not pass,detail=detail}
        if not pass then all_pass=false;log("V2 FAIL "..name.." "..serpent.line(detail)) end
    end
    local function test(name,fn)
        local ok,result=pcall(fn)
        check(name,ok and result~=false,not ok and tostring(result) or nil)
    end
    local function apply(target,changes,tick)
        local snap,error=maps.snapshot(target);assert(snap,serpent.line(error))
        local ok,message=maps.apply(snap.target,snap.values,changes,tick)
        assert(ok,serpent.line(message));return maps.snapshot(snap.target)
    end
    local function set_control(surface,name,frequency,size)
        local mgs=surface.map_gen_settings
        mgs.autoplace_controls[name]={frequency=frequency,size=size,richness=1}
        surface.map_gen_settings=mgs
    end
    local function write()
        helpers.write_file("planet-enemies-v2.json",helpers.table_to_json{all_pass=all_pass,checks=checks,
            version=script.active_mods.base,mods=script.active_mods,connected=#game.connected_players,complete=game.tick>=started+10},false)
        log("PLANET_ENEMIES_V2_COMPLETE "..tostring(all_pass))
    end
    script.on_event(defines.events.on_tick,function(event)
        previous(event)
        if not started then
            started=event.tick
            helpers.write_file("planet-enemies-final-data.json",helpers.table_to_json(prototypes.mod_data["ei-planet-enemies-qc"].data),false)
            test("global snapshot and schema",function()
                local snapshot=maps.snapshot{scope="global"}
                for _,field in ipairs(schema.global) do
                    assert(snapshot.values[field.id]~=nil,field.id)
                end
                return #snapshot.fields==22
            end)
            test("pending reference booleans",function()
                local snap=maps.snapshot{planet="aquilo"}
                return type(snap.values.no_enemies_mode)=="boolean" and type(snap.values.peaceful_mode)=="boolean"
            end)
            test("pending values do not create planet",function()
                local planet=game.planets.aquilo
                if planet.surface then game.delete_surface(planet.surface) end
                local snap=apply({planet="aquilo"},{["control/ei-aquilo-cold-enemies/enabled"]=false,seed=123456,peaceful_mode=true},event.tick)
                return snap.pending and not planet.surface
            end)
            test("pending readback preserves explicit zero and false",function()
                local snap=maps.snapshot{planet="aquilo"}
                local ok,_,readback=maps.apply(snap.target,snap.values,{seed=0,peaceful_mode=false},event.tick)
                assert(ok and readback.seed==0 and readback.peaceful_mode==false)
                apply({planet="aquilo"},{seed=123456,peaceful_mode=true},event.tick)
            end)
            test("pending Off restores remembered positive tuple",function()
                local id="control/ei-aquilo-cold-enemies/"
                apply({planet="aquilo"},{[id.."enabled"]=true,[id.."frequency"]=3,[id.."size"]=2},event.tick)
                local off=apply({planet="aquilo"},{[id.."frequency"]=0,[id.."size"]=4},event.tick)
                assert(off.values[id.."frequency"]==3 and off.values[id.."size"]==4,"pending Off display must match remembered values")
                local snap=apply({planet="aquilo"},{[id.."enabled"]=true},event.tick)
                local ok=snap.values[id.."frequency"]==3 and snap.values[id.."size"]==4
                apply({planet="aquilo"},{[id.."enabled"]=false},event.tick)
                return ok and not game.planets.aquilo.surface
            end)
            for name,controls in pairs(config.controls) do
                local surface=game.planets[name].surface or game.planets[name].create_surface()
                surfaces[name]=surface
                if name=="aquilo" then check("pending first creation",surface.map_gen_settings.seed==123456 and policy.is_disabled(surface,"cold") and surface.peaceful_mode) end
                surface.no_enemies_mode=false
                surface.request_to_generate_chunks({2000,2000},1);surface.force_generate_chunk_requests()
                local tiles={}
                for x=1970,2040 do for y=1970,2040 do tiles[#tiles+1]={name="landfill",position={x,y}} end end
                surface.set_tiles(tiles)
                for family,control in pairs(controls) do
                    check("checkbox-"..control,prototypes.autoplace_control[control].can_be_disabled)
                    set_control(surface,control,0,0)
                    check("policy-"..name.."-"..family,policy.is_disabled(surface,family))
                end
            end
            local nauvis=surfaces.nauvis
            local target={surface_index=nauvis.index,surface_name=nauvis.name}
            test("single field preserves unrelated map settings",function()
                local before=nauvis.map_gen_settings
                apply(target,{starting_area=2},event.tick)
                local after=nauvis.map_gen_settings;before.starting_area=2
                return serpent.line(before)==serpent.line(after)
            end)
            test("zero remembers positive control values",function()
                local name=config.controls.nauvis.arachnid
                set_control(nauvis,name,3,2)
                apply(target,{["control/"..name.."/frequency"]=0,["control/"..name.."/size"]=4},event.tick)
                local restored=apply(target,{["control/"..name.."/enabled"]=true},event.tick)
                return restored.values["control/"..name.."/frequency"]==3 and restored.values["control/"..name.."/size"]==4
            end)
            test("Off On retains zero resource richness",function()
                local id="control/iron-ore/"
                apply(target,{[id.."richness"]=0},event.tick)
                apply(target,{[id.."enabled"]=false},event.tick)
                apply(target,{[id.."enabled"]=true},event.tick)
                return nauvis.map_gen_settings.autoplace_controls["iron-ore"].richness==0
            end)
            test("migration preserves custom probability aliases",function()
                local m=nauvis.map_gen_settings
                m.property_expression_names.enemy_base_probability="0.0125"
                m.property_expression_names.eb_enemy_base_probability=nil
                m.property_expression_names.cb_enemy_base_probability="cb_enemy_base_probability"
                nauvis.map_gen_settings=m;policy.on_configuration_changed({})
                local aliases=nauvis.map_gen_settings.property_expression_names
                return aliases.enemy_base_probability=="0.0125"
                    and aliases.eb_enemy_base_probability=="ei_nauvis_explosive_enemy_base_probability"
                    and aliases.cb_enemy_base_probability=="ei_nauvis_cold_enemy_base_probability"
            end)
            test("stale same field rejected",function()
                local snap=maps.snapshot(target)
                apply(target,{starting_area=3},event.tick)
                return not maps.apply(target,snap.values,{starting_area=4},event.tick)
            end)
            test("unrelated concurrent field preserved",function()
                local snap=maps.snapshot(target)
                local mgs=nauvis.map_gen_settings;mgs.seed=98765;nauvis.map_gen_settings=mgs
                local ok=maps.apply(target,snap.values,{starting_area=4},event.tick)
                return ok and nauvis.map_gen_settings.seed==98765
            end)
            test("invalid patch is atomic",function()
                local snap=maps.snapshot(target);local before=nauvis.map_gen_settings
                return not maps.apply(target,snap.values,{starting_area=2,seed=-1},event.tick) and serpent.line(before)==serpent.line(nauvis.map_gen_settings)
            end)
            test("natural evolution does not conflict",function()
                local snap=maps.snapshot(target)
                game.forces.enemy.set_evolution_factor(0.4,nauvis)
                return maps.apply(target,snap.values,{evolution=0.2},event.tick)
            end)
            test("global values and validation",function()
                apply({scope="global"},{["pollution.enabled"]=false,["difficulty.spoil_time_modifier"]=2},event.tick)
                local snap=maps.snapshot{scope="global"}
                local failed=not maps.apply({scope="global"},snap.values,{["enemy_expansion.settler_group_min_size"]=100,["enemy_expansion.settler_group_max_size"]=5},event.tick)
                return failed and not game.map_settings.pollution.enabled and game.difficulty_settings.spoil_time_modifier==2
            end)
            for planet,controls in pairs(config.controls) do
                local surface=surfaces[planet]
                for family,control in pairs(controls) do
                    set_control(surface,control,0,0)
                    local count=0
                    for name,proto in pairs(prototypes.entity) do
                        if config.family(name,proto.type)==family then
                            count=count+1
                            local position={1980+(count%8)*7,1980+math.floor(count/8)*7}
                            local entity=surface.create_entity{name=name,position=position,force="enemy"}
                            if config.is_raft(name) then
                                check("retained-"..name,entity and entity.disabled_by_script and entity.destructible)
                                rafts[#rafts+1]=entity
                            else
                                check("blocked-"..planet.."-"..name,entity and entity.valid and entity.disabled_by_script and not entity.destructible)
                                if entity then blocked[#blocked+1]=entity end
                            end
                        end
                    end
                end
            end
            test("admin summon exemption cleanup",function()
                local name="arachnid-biter-drone-unit"
                local creature=policy.create_admin_enemy(nauvis,name,game.forces.enemy,function()
                    return nauvis.create_entity{name=name,position={2030,2030},force="enemy"}
                end)
                kept[#kept+1]=creature
                local ordinary=nauvis.create_entity{name=name,position={2035,2035},force="enemy"};blocked[#blocked+1]=ordinary
                return creature and not creature.disabled_by_script and ordinary and ordinary.disabled_by_script
            end)
            test("admin exemption clears on error",function()
                local name="arachnid-biter-drone-unit"
                local ok=pcall(policy.create_admin_enemy,nauvis,name,game.forces.enemy,function() error("expected fixture error") end)
                local body=nauvis.create_entity{name=name,position={2040,2035},force="enemy"};blocked[#blocked+1]=body
                return not ok and body and body.disabled_by_script
            end)
            test("demolisher admin exemption",function()
                local surface=surfaces.vulcanus;surface.no_enemies_mode=true
                local unit=policy.create_admin_enemy(surface,"small-demolisher",game.forces.enemy,function()
                    return surface.create_segmented_unit{name="small-demolisher",position={2300,2300},force="enemy"}
                end)
                kept[#kept+1]=unit
                return unit and unit.valid
            end)
            test("raft reactivation queued",function()
                apply({surface_index=surfaces.gleba.index},{["control/gleba_enemy_base/enabled"]=true},event.tick)
                return #rafts==2 and rafts[1].disabled_by_script
            end)
            local player=game.players[1]
            if player then
                player.admin=true
                test("native Map Settings GUI",function()
                    admin.open(player,"map-settings",event.tick)
                    local session=storage.ei.admin_tools.sessions[player.index]
                    return session.map_settings and session.map_settings.body.valid and session.nav["map-settings"].valid
                end)
                test("demotion denies apply",function()
                    local snap=maps.snapshot(target);player.admin=false
                    local ok=admin.execute(player,"map_settings_apply",{target=target,baseline=snap.values,changes={seed=777}},event.tick)
                    player.admin=true;return not ok
                end)
            else check("saved player exists",false) end
            write()
        elseif event.tick==started+5 then
            for i,entity in ipairs(blocked) do check("removed-"..i,not entity.valid) end
            for i,entity in ipairs(kept) do check("summon-remains-"..i,entity.valid) end
            for i,raft in ipairs(rafts) do check("raft-reactivated-"..i,raft.valid and not raft.disabled_by_script) end
            test("legacy Nauvis split values including zero",function()
                local s=surfaces.nauvis;local old=s.map_gen_settings;local m=table.deepcopy(old)
                m.autoplace_controls["enemy-base"]={frequency=0,size=2,richness=3}
                for _,family in ipairs(config.nauvis_splits) do m.autoplace_controls[config.controls.nauvis[family]]=nil end
                m.autoplace_controls[config.controls.nauvis.toxic]={frequency=4,size=5,richness=1}
                s.map_gen_settings=m;policy.on_configuration_changed({})
                local actual=s.map_gen_settings.autoplace_controls
                local ok=actual[config.controls.nauvis.arachnid].frequency==0 and actual[config.controls.nauvis.armoured].size==2
                    and actual[config.controls.nauvis.toxic].frequency==4
                s.map_gen_settings=old;return ok
            end)
            test("Toxic native infection callbacks finish before removal",function()
                local s=surfaces.nauvis;set_control(s,config.controls.nauvis.toxic,1,1)
                local killer=assert(s.create_entity{name="small-toxic-biter",position={1980,2000},force="enemy"})
                killer.disabled_by_script=true;kept[#kept+1]=killer
                set_control(s,config.controls.nauvis.toxic,0,0)
                for i,row in ipairs({{"gun-turret","tb_infected_gun_turret"},{"laser-turret","tb_infected_laser_turret"},
                    {"artillery-turret","tb_infected_artillery_turret"},{"radar","tb_infected_radar"}}) do
                    local p={x=1980+i*12,y=2040};local victim=assert(s.create_entity{name=row[1],position=p,force="player"})
                    assert(victim.die(game.forces.enemy,killer))
                    local body=assert(s.find_entities_filtered{name=row[2],position=p,radius=1}[1])
                    check("infected-reference-"..row[1],body.valid and body.disabled_by_script and not body.destructible)
                    if row[1]=="gun-turret" then check("infected-gun-ammunition",body.get_inventory(defines.inventory.turret_ammo).get_item_count()>0) end
                    if row[1]=="artillery-turret" then check("infected-artillery-ammunition",body.get_inventory(defines.inventory.artillery_turret_ammo).get_item_count("artillery-shell")==40) end
                    infections[#infections+1]=body
                end
            end)
            test("Arachnid native terrain replacement follows ordinary policy",function()
                local s=surfaces.nauvis;local m=s.map_gen_settings;m.property_expression_names.moisture="1";s.map_gen_settings=m
                set_control(s,config.controls.nauvis.arachnid,1,1);set_control(s,"enemy-base",0,0)
                local p={2020,1970};local nest=assert(s.create_entity{name="arachnid-spawner-unitspawner",position=p,force="enemy"})
                script.raise_event(defines.events.on_biter_base_built,{entity=nest,tick=event.tick})
                local replacements=s.find_entities_filtered{name={"biter-spawner","spitter-spawner"},position=p,radius=1}
                if replacements[1] then infections[#infections+1]=replacements[1] end
                return not nest.valid and #replacements==1 and replacements[1].disabled_by_script
            end)
            test("raft ownership only adopts new disabled rafts",function()
                local s=surfaces.gleba;set_control(s,"gleba_enemy_base",1,1)
                local other=assert(s.create_entity{name="gleba-spawner",position={2050,2000},force="enemy"});other.disabled_by_script=true
                kept[#kept+1]=other;batch.external=other
                set_control(s,"gleba_enemy_base",0,0)
                for i=1,130 do batch[i]=assert(s.create_entity{name="gleba-spawner",position={2050,2050},force="enemy"}) end
                apply({surface_index=s.index},{["control/gleba_enemy_base/enabled"]=true},event.tick)
                return batch[1].disabled_by_script and other.disabled_by_script
            end)
            test("native editor events and retained drafts",function()
                local p=game.players[1];p.admin=true;admin.open(p,"map-settings",event.tick)
                local session=storage.ei.admin_tools.sessions[p.index]
                local function dispatch(name,element)
                    script.get_event_handler(defines.events[name]){name=defines.events[name],player_index=p.index,element=element,tick=event.tick,button=defines.mouse_button_type.left}
                end
                local function planet(name)
                    for i,value in ipairs(session.choices.planet) do if value==name then session.fields.planet.selected_index=i end end
                    dispatch("on_gui_selection_state_changed",session.fields.planet)
                end
                local function button(action)
                    local function find(node)
                        if node.tags.action=="map-settings-"..action then return node end
                        for _,child in pairs(node.children) do local found=find(child);if found then return found end end
                    end
                    return assert(find(session.root),action)
                end
                planet("nauvis")
                local s=surfaces.nauvis;local before=s.map_gen_settings.starting_area
                local next_value=before==2 and 3 or 2;local ui=session.map_settings;local body=ui.body
                ui.rows.starting_area.slider.slider_value=next_value;dispatch("on_gui_value_changed",ui.rows.starting_area.slider)
                check("GUI slider draft only",s.map_gen_settings.starting_area==before and tonumber(ui.rows.starting_area.value.text)==next_value)
                check("GUI root retained",body==session.map_settings.body and body.valid)
                planet("fulgora");planet("nauvis")
                check("GUI navigation keeps draft",tonumber(session.map_settings.rows.starting_area.value.text)==next_value)
                dispatch("on_gui_click",session.map_settings.apply)
                check("GUI Apply writes native",s.map_gen_settings.starting_area==next_value and not session.map_settings.apply.enabled)
                ui=session.map_settings;ui.rows.starting_area.value.text="0.1";dispatch("on_gui_text_changed",ui.rows.starting_area.value)
                dispatch("on_gui_click",ui.apply)
                check("GUI rejects invalid draft",s.map_gen_settings.starting_area==next_value and session.map_settings.apply.enabled)
                dispatch("on_gui_click",button("discard"))
                ui=session.map_settings;ui.rows.starting_area.value.text="5";dispatch("on_gui_text_changed",ui.rows.starting_area.value)
                apply({surface_index=s.index},{starting_area=3},event.tick);dispatch("on_gui_click",ui.apply)
                check("GUI preserves conflicting draft",s.map_gen_settings.starting_area==3 and session.map_settings.apply.enabled)
                dispatch("on_gui_click",button("reload"))
                check("GUI reload reads native",tonumber(session.map_settings.rows.starting_area.value.text)==3)
                -- A pending draft must retain values while its target is created.
                game.delete_surface(surfaces.aquilo)
                gui_pending=function()
                planet("aquilo")
                ui=session.map_settings;ui.advanced.state=true;dispatch("on_gui_checked_state_changed",ui.advanced)
                ui=session.map_settings;ui.rows.seed.edit.state=true;dispatch("on_gui_checked_state_changed",ui.rows.seed.edit)
                ui.rows.seed.value.text="123";dispatch("on_gui_text_changed",ui.rows.seed.value)
                ui.rows.seed.edit.state=false;dispatch("on_gui_checked_state_changed",ui.rows.seed.edit)
                ui.rows.seed.edit.state=true;dispatch("on_gui_checked_state_changed",ui.rows.seed.edit)
                check("GUI override widget matches draft",tonumber(ui.rows.seed.value.text)==session.map_settings_drafts[ui.id].changes.seed)
                check("GUI pending browsing creates nothing",not game.planets.aquilo.surface)
                local replacement=game.planets.aquilo.create_surface();surfaces.aquilo=replacement
                admin.open(p,"map-settings",event.tick)
                check("GUI pending becomes live",session.map_settings.rows.evolution and not session.map_settings.rows.seed.edit)
                ui=session.map_settings;ui.rows.evolution.value.text="20";dispatch("on_gui_text_changed",ui.rows.evolution.value);dispatch("on_gui_click",ui.apply)
                check("GUI new live evolution applies",game.forces.enemy.get_evolution_factor(replacement)==0.2)
                local id=ui.id;local target=session.map_settings_drafts[id].target
                game.delete_surface(replacement)
                gui_replaced=function()
                game.planets.aquilo.create_surface();admin.open(p,"map-settings",event.tick)
                check("GUI replaced target cannot apply stale draft",not session.map_settings.apply.enabled and session.map_settings_drafts[id].target.surface_index==target.surface_index)
                dispatch("on_gui_click",button("reload"));planet("nauvis")
                end
                end
            end)
            write()
        elseif event.tick==started+6 then
            if gui_pending then test("pending GUI lifecycle",gui_pending) end
            for i,e in ipairs(infections) do check("dependency-body-removed-"..i,not e.valid) end
            local enabled=0;for _,e in ipairs(batch) do if not e.disabled_by_script then enabled=enabled+1 end end
            check("raft restore budget64",enabled==64,enabled)
            set_control(surfaces.gleba,"gleba_enemy_base",0,0)
        elseif event.tick==started+7 then
            if gui_replaced then test("replaced GUI lifecycle",gui_replaced) end
            local enabled=0;for _,e in ipairs(batch) do if not e.disabled_by_script then enabled=enabled+1 end end
            check("raft queued restore respects Off",enabled==64,enabled)
            apply({surface_index=surfaces.gleba.index},{["control/gleba_enemy_base/enabled"]=true},event.tick)
        elseif event.tick==started+10 then
            local enabled=0;for _,e in ipairs(batch) do if not e.disabled_by_script then enabled=enabled+1 end end
            check("raft reactivation resumes",enabled==130 and batch.external.disabled_by_script,enabled)
            write()
        end
    end)
end

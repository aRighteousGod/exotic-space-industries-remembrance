-- Disposable native capture scenarios. Gameplay remains under ESIR's production dispatcher.
-- Timing is derived from supplied ticks; storage.portal belongs to this helper mod.
local cfg=require("capture-config")
local catalog=require("__exotic-space-industries-remembrance__/lib/spider-vehicles")
local api="exotic-industries-spider-vehicles"
local order={"sweeping-radar","water-turret","auric-inoculation-vat","gates","spidertron-controls"}
local duration={['sweeping-radar']=960,['water-turret']=960,['auric-inoculation-vat']=10800,gates=960,['spidertron-controls']=1200}
local gui_names={['sweeping-radar']='ei_sweeping_radar_gui',['water-turret']='ei-water-turret-console',
    ['auric-inoculation-vat']='ei-auric-inoculation-vat-console',gates='ei-gate-console',['spidertron-controls']='ei-spider-weapon-console'}
local function call(name,...) return remote.call("esir_portal_capture",name,...) end

---@param s LuaSurface
---@param name string
---@param x number
---@param y number
---@param force LuaForce|string|nil
---@return LuaEntity
local function entity(s,name,x,y,force)
    return assert(s.create_entity{name=name,position={x,y},force=force or "player",raise_built=true},"Cannot create "..name)
end

---@param player LuaPlayer
---@param id string
---@return LuaSurface
local function prepare_surface(player,id)
    player.force.set_cease_fire("enemy",false);player.force.set_friend("enemy",false)
    game.forces.enemy.set_cease_fire(player.force,false);game.forces.enemy.set_friend(player.force,false)
    local names={['sweeping-radar']='Radar workshop',['water-turret']='Firefighting workshop',
        ['auric-inoculation-vat']='Gleba basin',gates='Gate workshop',['spidertron-controls']='Vehicle proving ground'}
    local s=game.create_surface(names[id],{width=256,height=192,seed=82,autoplace_controls={},
        autoplace_settings={entity={treat_missing_as_default=false},decorative={treat_missing_as_default=false}}})
    s.request_to_generate_chunks({0,0},4);s.force_generate_chunk_requests()
    for _,e in pairs(s.find_entities()) do if e.valid then e.destroy() end end
    s.destroy_decoratives{area={{-64,-48},{110,48}}}
    local tiles={}
    for x=-64,110 do for y=-48,48 do
        tiles[#tiles+1]={name=(x+y)%2==0 and "lab-dark-1" or "lab-dark-2",position={x,y}}
    end end
    s.set_tiles(tiles);s.daytime=0.05;s.freeze_daytime=true
    player.teleport({0,8},s);player.opened=nil
    for _,root in pairs(player.gui.screen.children) do root.destroy() end
    for _,root in pairs(player.gui.relative.children) do root.destroy() end
    -- Off-screen fixture generation supplies actual poles and native consumers.
    local source=entity(s,"electric-energy-interface",-23,0)
    source.power_production=1000000000000;source.electric_buffer_size=1000000000000;source.energy=1000000000000
    entity(s,"substation",-18,0);entity(s,"substation",-5,-4)
    entity(s,"steel-chest",-7,4).insert{name="iron-plate",count=1000}
    entity(s,"inserter",-7,5).direction=defines.direction.north
    entity(s,"steel-chest",8,4)
    entity(s,"inserter",8,5).direction=defines.direction.south
    entity(s,"substation",0,4)
    for x=-8,8 do entity(s,"transport-belt",x,6).direction=defines.direction.east end
    return s
end

---@param s LuaSurface
---@param x number
---@param y number
---@param fluid string
---@param sink boolean
local function fluid_line(s,x,y,fluid,sink)
    local sign=x<0 and -1 or 1
    for step=0,17 do entity(s,"pipe",x+step*sign,y) end
    local source=entity(s,"infinity-pipe",x+18*sign,y)
    source.set_infinity_pipe_filter{name=fluid,percentage=sink and 0 or 1,mode=sink and "at-most" or "at-least"}
end

local function start_scene(state,player,id,tick)
    local s=prepare_surface(player,id)
    state.scene={id=id,started=tick,surface=s,position={0,0},zoom=1.2,proof={},frame=0}
    local c=state.scene
    if id=="sweeping-radar" then
        c.main=entity(s,"ei-phased-array-radar",0,0);call("radar_configure",c.main,tick)
        entity(s,"constant-combinator",5,-1)
    elseif id=="water-turret" then
        c.main=entity(s,"ei-water-turret",0.5,0.5);fluid_line(s,2.5,0.5,"water",false)
        call("water_preferences",player,c.main,2,tick);c.position={0,-3};c.zoom=1.25
    elseif id=="auric-inoculation-vat" then
        s.set_property("pressure",2000)
        local tiles={}
        for n=0,103 do tiles[#tiles+1]={name="wetland-light-green-slime",position={6+n%10,-8+math.floor(n/10)}} end
        s.set_tiles(tiles);c.main=entity(s,"ei-auric-inoculation-vat",0,0)
        c.main.get_fuel_inventory().insert{name="nutrients",count=200}
        for _,name in ipairs({"spoilage","jelly","yumako-mash","bioflux"}) do c.main.insert{name=name,count=200} end
        fluid_line(s,3,-1,"ei-dirty-water",false);fluid_line(s,3,1,"ei-bio-oil",false)
        fluid_line(s,-3,1,"ei-dirty-water",true);fluid_line(s,-3,-1,"ei-acidic-water",true)
        c.position={5,0};c.zoom=1.2;c.phases={};if not cfg.probe then game.speed=4 end
    elseif id=="gates" then
        c.main=entity(s,"ei-gate-container",-5,0);c.receiver=entity(s,"ei-gate-receiver",7,0)
        c.zoom=1.25;c.position={1,0}
    elseif id=="spidertron-controls" then
        local force=game.create_force("portal-spiders");c.force=force;player.force=force
        c.main=entity(s,catalog.configured_name("assault",catalog.researched_state(force),{cycling=true,special=true},true),0,0,force)
        local ammo=c.main.get_inventory(defines.inventory.spider_ammo)
        ammo[1].set_stack{name="cannon-shell",count=100};ammo[2].set_stack{name="firearm-magazine",count=100};ammo[3].set_stack{name="flamethrower-ammo",count=100}
        c.main.get_inventory(defines.inventory.fuel).insert{name="coal",count=20}
        c.main.vehicle_automatic_targeting_parameters={auto_target_with_gunner=true,auto_target_without_gunner=true}
        c.vehicle_id=remote.call(api,"get_vehicle_id",c.main)
        c.before={health=c.main.max_health,grid={c.main.grid.width,c.main.grid.height}}
        c.slots={};c.zoom=1;c.position={5,0}
    else error("Unknown portal scene: "..id) end
end

local function shot(state,player,tick,caption,gui,speed,ms)
    local c=state.scene;c.frame=c.frame+1
    if gui then
        local root=player.gui.screen[gui_names[c.id]] or player.gui.relative[gui_names[c.id]]
        assert(root and root.valid,"Missing native GUI for "..c.id)
        c.gui_observed=true
    end
    local path=c.id.."/"..string.format("%04d",c.frame)..".jpg"
    if not cfg.probe then game.take_screenshot{player=player,surface=c.surface,path="portal/"..path,position=c.position,
        resolution={cfg.width,cfg.height},zoom=c.zoom*cfg.width/1280,show_gui=gui or false,show_entity_info=false,force_render=true} end
    local frame_ms=ms or (math.floor(c.frame*1000/12)-math.floor((c.frame-1)*1000/12))
    state.frames[#state.frames+1]={feature=c.id,path=path,tick=tick,duration_ms=frame_ms,caption=caption,speed=speed or 1,gui=gui or false,reading_hold=ms~=nil}
end

local function advance(state,player,event)
    local c=state.scene;local t=event.tick-c.started
    local caption,gui,speed,interval="",false,1,5
    if c.id=="sweeping-radar" then
        caption=t<600 and "Scan the area around your factory" or "Choose what the radar scans and reports"
        if t==600 then call("radar_open",player,c.main,event.tick) end
        gui=t>=600
        if t==950 then c.proof=call("radar_state",c.main);c.proof.pass=c.proof.observations>0 end
    elseif c.id=="water-turret" then
        if t==90 then c.fire=entity(c.surface,"ei-oil-fire-flame",0,-9,"neutral");c.fire_started=true end
        if t==330 then
            c.enemy=entity(c.surface,"big-biter",-3,-13,"enemy")
            c.enemy.commandable.set_command{type=defines.command.attack,target=c.main,distraction=defines.distraction.none};c.enemy_health=c.enemy.health
        end
        if c.enemy and c.enemy.valid then
            for _,sticker in pairs(c.enemy.stickers or {}) do
                if sticker.valid and sticker.name=="ei-water-slow" then c.slowed=true end
            end
        end
        caption=t<330 and "Water supply + power: put out nearby fires" or "Slow approaching enemies; choose which job comes first"
        if t==650 then player.opened=c.main;call("water_open",player,c.main,event.tick) end
        gui=t>=650
        if t==950 then
            c.proof=call("water_state",c.main);c.proof.fire_extinguished=c.fire_started and not c.fire.valid
            c.proof.enemy_slowed=c.slowed==true
            c.proof.enemy_start_health=c.enemy_health;c.proof.enemy_end_health=c.enemy.valid and c.enemy.health or 0
            c.proof.water=c.main.get_fluid_count("water");c.proof.active=c.main.active
            c.proof.pass=c.proof.fire_extinguished and c.proof.enemy_slowed
        end
    elseif c.id=="auric-inoculation-vat" then
        local observed=call("vat_state",c.main);c.phases[observed.phase]=true
        caption="Gleba wetland basin | "..observed.phase:gsub("%-"," ");interval=60;speed=12
        if t%600==0 then
            c.main.get_fuel_inventory().insert{name="nutrients",count=100}
            for _,name in ipairs({"spoilage","jelly","yumako-mash","bioflux"}) do c.main.insert{name=name,count=100} end
        end
        if t==10680 then call("vat_open",player,c.main,event.tick) end
        if t==10740 then
            c.proof=observed;c.proof.phases=c.phases;c.proof.world_nodes=c.surface.count_entities_filtered{name="ei-auric-cyst-node"}
            c.proof.pass=observed.valid and c.phases.bloom==true and (observed.cycles or 0)>0
        end
        gui=t>=10740
    elseif c.id=="gates" then
        if t==150 then call("gate_configure",player,c.main,c.receiver,event.tick) end
        if t==210 then c.loaded=c.main.insert{name="iron-plate",count=100} end
        if t==480 then call("gate_open",player,c.main,event.tick) end
        gui=t>=480;caption=t<480 and "Send items from the gate to its chosen receiver" or "Check the destination, stored energy and stress"
        if t>=240 and t<480 then
            caption=c.receiver.get_inventory(defines.inventory.chest).get_item_count("iron-plate").." iron plates delivered to the receiver"
        end
        if t==950 then
            c.proof=call("gate_state",c.main);c.proof.received=c.receiver.get_inventory(defines.inventory.chest).get_item_count("iron-plate")
            c.proof.remaining=c.main.get_inventory(defines.inventory.chest).get_item_count("iron-plate")
            c.proof.loaded=c.loaded
            c.proof.pass=c.proof.received>0 and c.proof.received+c.proof.remaining==100
        end
    elseif c.id=="spidertron-controls" then
        if t==120 then
            c.force.technologies[catalog.weapon_technology("mg",1)].researched=true
            for level=1,6 do c.force.technologies["ei-spider-chassis-"..level].researched=true end
            remote.call(api,"refresh_force",c.force)
        end
        if t<720 then local current=call("spider_entity",c.vehicle_id);if current and current.valid then c.main=current end end
        if t==240 then call("spider_open",player,c.main,event.tick) end
        if t==360 then
            player.opened=nil
            for i=1,8 do
                local enemy=entity(c.surface,"behemoth-biter",8+i%3,-3+i,"enemy")
                enemy.commandable.set_command{type=defines.command.attack,target=c.main,distraction=defines.distraction.none}
            end
        end
        if t>=360 and t<720 and c.main.valid then c.slots[tostring(c.main.selected_gun_index)]=true end
        if t==650 then remote.call(api,"set_weapon_controls",c.main,{cycling=false,selected_slot=2}) end
        if t==720 then
            c.after={health=c.main.max_health,grid={c.main.grid.width,c.main.grid.height}}
            c.main.destroy{raise_destroy=true}
            for _,enemy in pairs(c.surface.find_entities_filtered{force="enemy"}) do enemy.destroy() end
            c.main=entity(c.surface,catalog.configured_name("rocket",catalog.researched_state(c.force),{cycling=true,special=true},true),0,0,c.force)
            c.main.get_inventory(defines.inventory.spider_ammo)[1].set_stack{name="rocket",count=100}
            c.main.get_inventory(defines.inventory.fuel).insert{name="coal",count=20}
            remote.call(api,"set_weapon_controls",c.main,{cycling=true,overkill=true})
            c.main.vehicle_automatic_targeting_parameters={auto_target_with_gunner=true,auto_target_without_gunner=true}
            c.target=entity(c.surface,"big-biter",30,0,"enemy");c.target.active=false;c.position={12,0};c.zoom=0.95
        end
        if t>720 then
            local controls=remote.call(api,"get_weapon_controls",c.main);c.held=c.held or controls.holding_fire
            if t==900 then call("spider_open",player,c.main,event.tick) end
            gui=t>=900
        else gui=t>=240 and t<360 end
        caption=t<360 and "Research chassis and weapon upgrades: assault Spidertron" or
            (t<720 and (t<650 and "Cycle through loaded weapons that can reach a target" or "Or hold a selected weapon") or "Rocket Spidertron: optional Overkill prevention")
        if t==1190 then
            local n=0;for _ in pairs(c.slots) do n=n+1 end
            c.proof={before=c.before,after=c.after,selected_slots=c.slots,holding_fire_observed=c.held or false,controls=remote.call(api,"get_weapon_controls",c.main)}
            c.proof.pass=n>=2 and c.held==true and c.after.grid[1]>c.before.grid[1]
        end
    end
    if t>=60 and t<duration[c.id] and t%interval==0 then
        if c.id=="auric-inoculation-vat" and t==10740 then
            shot(state,player,event.tick,"Check the basin, cycle and harvest in the vat console",true,1,3000)
        else shot(state,player,event.tick,caption,gui,speed) end
    end
    if t>=duration[c.id] then
        state.evidence[c.id]=c.proof;state.evidence[c.id].production_entity=true
        state.evidence[c.id].gui_observed=c.gui_observed==true
        state.evidence[c.id].pass=c.proof.pass and c.gui_observed==true
        state.evidence[c.id].setup="Supplied items and off-screen fixture power/fluids; unmodified production behavior."
        player.opened=nil;player.force=game.forces.player;if not cfg.probe then game.speed=1 end
        state.next_scene=state.next_scene+1;state.scene=nil
    end
end

script.on_init(function() storage.portal={pending=true} end)
script.on_configuration_changed(function() storage.portal={pending=true} end)
script.on_event(defines.events.on_tick,function(event)
    local state=storage.portal
    if not state then state={pending=true};storage.portal=state end
    if state.done then return end
    local player=game.connected_players[1] or (cfg.probe and game.players[1])
    if not player then return end
    if state.pending then
        state.pending=nil;state.started=event.tick;state.frames={};state.evidence={};state.next_scene=1
        player.set_controller{type=defines.controllers.god};game.tick_paused=false
        state.resolution=player.display_resolution;state.scale=player.display_scale
    end
    local id=cfg.scene=="pilots" and order[state.next_scene] or (state.next_scene==1 and cfg.scene or nil)
    if id then
        if not state.scene then start_scene(state,player,id,event.tick) end
        advance(state,player,event);return
    end
    local startup={};for name,value in pairs(settings.startup) do if name:match("^ei%-") then startup[name]=value.value end end
    helpers.write_file("portal/report.json",helpers.table_to_json({complete=true,probe=cfg.probe or false,connected=player.connected,
        resolution=state.resolution,scale=state.scale,started_tick=state.started,ended_tick=event.tick,
        frames=state.frames,evidence=state.evidence,mods=script.active_mods,startup_settings=startup}),false)
    state.done=true;log("PORTAL_CAPTURE_COMPLETE")
end)

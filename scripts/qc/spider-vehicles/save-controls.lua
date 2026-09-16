-- Real saved-entity migration matrix. Kept separate from player interaction
-- tests because a private server has disconnected players, unlike benchmarks.
local catalog=require("__exotic-space-industries-remembrance__/lib/spider-vehicles")
local api="exotic-industries-spider-vehicles"
local loaded,started,finished=false,nil,false
local function fingerprint(entity)
    local result={inventories={},equipment={},fuel=entity.burner.remaining_burning_fuel,sections=entity.get_logistic_sections().sections[1].filters}
    for _,id in ipairs({defines.inventory.spider_trunk,defines.inventory.spider_trash,defines.inventory.spider_ammo,defines.inventory.fuel,defines.inventory.burnt_result}) do
        result.inventories[id]={}
        local inventory=entity.get_inventory(id)
        for slot=1,#inventory do
            local stack=inventory[slot]
            if stack.valid_for_read then result.inventories[id][slot]={name=stack.name,count=stack.count,quality=stack.quality.name,ammo=stack.type=="ammo" and stack.ammo or nil} end
        end
    end
    for _,eq in ipairs(entity.grid.equipment) do result.equipment[#result.equipment+1]={name=eq.name,position=eq.position,quality=eq.quality.name,energy=eq.energy} end
    return serpent.line(result,{sortkeys=true,comment=false})
end
local function replaced(event)
    for _,record in ipairs(storage.saved_matrix or {}) do if record.id==event.vehicle_id then record.entity=event.entity end end
end
script.on_load(function()
    loaded=true
    script.on_event(remote.call(api,"get_replacement_event"),replaced)
end)
script.on_init(function()
    script.on_event(remote.call(api,"get_replacement_event"),replaced)
    storage.saved_matrix={}
    local force=game.create_force("esir-spider-save")
    for _,branch in ipairs(catalog.branch_order) do
        for level=1,#catalog.upgrade_names[branch] do force.technologies[catalog.weapon_technology(branch,level)].researched=true end
    end
    remote.call(api,"refresh_force",force)
    local surface=game.create_surface("esir-spider-save",{width=128,height=128,autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false,settings={}}}})
    surface.request_to_generate_chunks({0,0},2);surface.force_generate_chunk_requests()
    local tiles={}
    for x=-10,40 do for y=-10,50 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
    surface.set_tiles(tiles)
    for _,family in ipairs({"assault","rocket"}) do
        for _,cycling in ipairs({false,true}) do
            for _,special in ipairs({false,true}) do
                local prefs={cycling=cycling,special=special}
                local entity=surface.create_entity{name=catalog.configured_name(family,catalog.researched_state(force),{cycling=cycling,special=true},settings.startup["ei-spider-range-aware-cycling"].value),position={0,#storage.saved_matrix*6},force=force,raise_built=true}
                entity.vehicle_automatic_targeting_parameters={auto_target_with_gunner=false,auto_target_without_gunner=false}
                if not cycling then prefs.selected_slot=2 end
                remote.call(api,"set_weapon_controls",entity,prefs)
                entity.get_inventory(defines.inventory.spider_trunk).insert{name="iron-plate",count=43,quality="rare"}
                entity.get_inventory(defines.inventory.spider_trash).insert{name="copper-plate",count=7}
                entity.burner.inventory.insert{name="coal",count=17}
                entity.burner.burnt_result_inventory.insert{name="depleted-uranium-fuel-cell",count=3}
                entity.burner.currently_burning={name="coal",quality="normal"};entity.burner.remaining_burning_fuel=789543
                entity.grid.put{name="battery-equipment",position={0,0},quality="rare"}.energy=654321
                local section=entity.get_logistic_sections().add_section("save-controls")
                section.set_slot(1,{value={name="iron-plate",quality="rare",comparator="="},min=43,max=50});section.active=false
                local ammo=entity.get_inventory(defines.inventory.spider_ammo)
                local names=family=="assault" and {"cannon-shell","firearm-magazine","flamethrower-ammo","artillery-shell"} or {"rocket","rocket","rocket","rocket","dw-deer-ammo-basic"}
                for slot=1,#ammo do ammo[slot].set_stack{name=names[slot],count=2,quality="rare"} end
                if family=="assault" then ammo[2].ammo=3;ammo[3].ammo=7 end
                local special_ammo=ammo[#ammo]
                storage.saved_matrix[#storage.saved_matrix+1]={entity=entity,id=remote.call(api,"get_vehicle_id",entity),family=family,preferences=prefs,
                    special_ammo={name=special_ammo.name,count=special_ammo.count,ammo=special_ammo.ammo}}
            end
        end
    end
end)
script.on_event(defines.events.on_tick,function(event)
    if finished then return end
    started=started or event.tick
    if loaded and event.tick-started==30 then
        for _,record in ipairs(storage.saved_matrix) do
            if not record.preferences.special then remote.call(api,"set_weapon_controls",record.entity,{special=true}) end
        end
    elseif loaded and event.tick-started==60 then
        for _,record in ipairs(storage.saved_matrix) do
            if not record.preferences.special then
                local ammo=record.entity.get_inventory(defines.inventory.spider_ammo)
                local slot=record.family=="assault" and 4 or 5
                local expected=record.special_ammo
                record.restored_ammo=#ammo==slot and ammo[slot].valid_for_read and ammo[slot].quality.name=="rare" and ammo[slot].name==expected.name and ammo[slot].count==expected.count and ammo[slot].ammo==expected.ammo
                remote.call(api,"set_weapon_controls",record.entity,{special=false})
            end
        end
    end
    if event.tick-started~=150 then return end
    local checks={}
    local function check(name,value) checks[#checks+1]={name=name,pass=value==true} end
    for index,record in ipairs(storage.saved_matrix) do
        local current=remote.call(api,"get_weapon_controls",record.entity)
        local prefs=record.preferences
        check("save-identity-"..index,current.vehicle_id==record.id)
        check("save-preferences-"..index,current.cycling==prefs.cycling and current.special==prefs.special)
        check("save-mode-"..index,not current.pending and current.effective_mode==(prefs.cycling and (settings.startup["ei-spider-range-aware-cycling"].value and "smart" or "native") or "hold"))
        check("save-hold-slot-"..index,prefs.cycling or current.selected_slot==2)
        if loaded then check("save-full-state-"..index,fingerprint(record.entity)==record.fingerprint) end
        if loaded and not prefs.special then check("save-stowed-ammo-"..index,record.restored_ammo==true) end
        record.fingerprint=fingerprint(record.entity)
    end
    local status=remote.call(api,"get_status")
    check("save-no-errors",status.failures==0)
    local all=true
    for _,check in ipairs(checks) do all=all and check.pass end
    helpers.write_file("spider-vehicles-qc.json",helpers.table_to_json({all_pass=all,checks=checks,status=status,phase=loaded and "save-reload" or "save-initial",smart=settings.startup["ei-spider-range-aware-cycling"].value}),false)
    finished=true
    game.server_save("spider-controls-"..(settings.startup["ei-spider-range-aware-cycling"].value and "smart" or "native"))
end)

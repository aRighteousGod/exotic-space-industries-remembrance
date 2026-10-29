-- Appended ONLY to the private ESIR copy, preserving the production dispatcher.
do
    local common=require("scripts/control/admin/common")
    local gui=require("scripts/control/admin/gui")
    local world=require("scripts/control/admin/world")
    local spiders=require("scripts/control/spider-vehicles")
    local catalog=require("lib/spider-vehicles")
    local scanner=require("scripts/control/orbital-combinator")
    local logistics=require("scripts/control/orbital-logistics")
    local lib=require("lib/lib")
    local normal=require("__esir-qc-quality-optional__/normal")
    local function check(value,label)
        local q=storage.quality_optional_qc
        q.checks=q.checks+1
        assert(value,"QUALITY REMOVAL: "..label)
        q.labels[#q.labels+1]=label
    end
    local function valid_filters(filters)
        for _,filter in pairs(filters or {}) do
            check(lib.is_valid_signal_id(filter.value),"current filter identifiers")
        end
    end
    local function ammo_count(entity)
        local count=0
        for _,id in ipairs({defines.inventory.spider_ammo,defines.inventory.spider_trunk}) do
            local inv=entity.get_inventory(id)
            if inv then count=count+inv.get_item_count("artillery-shell") end
        end
        return count
    end
    local function seed(surface,player,tick)
        local q={checks=0,labels={},player=player.index,platforms={},spiders={}}
        storage.quality_optional_qc=q
        player.admin=true
        if player.controller_type==defines.controllers.cutscene then player.exit_cutscene() end
        local character=player.character or player.surface.create_entity{name="character",position=player.position,force=player.force}
        player.set_controller{type=defines.controllers.character,character=character}
        check(player.character~=nil,"native player character")
        player.teleport({0,0},surface)
        ei_admin_tools.open(player,"creation",tick)
        local session=common.state().sessions[player.index]
        session.drafts.item={name="iron-plate",quality="uncommon"}
        session.drafts.place_item={name="quality-module",quality="normal"}
        gui.close(player.index,true)
        ei_admin_tools.open(player,"creation",tick)
        local elem=session.fields.item.elem_value
        q.picker_shape={name=type(elem.name),quality=type(elem.quality)}
        local ground={}
        for x=20,65 do for y=20,65 do ground[#ground+1]={name="grass-1",position={x,y}} end end
        surface.set_tiles(ground)
        local ok,message,id=world.execute(player,"place_entities",{
            surface_index=surface.index,force_index=player.force.index,position={x=32,y=32},
            item={name="wooden-chest",quality="uncommon"},quantity=100,direction=0},tick)
        check(ok,message or "admin job admitted")
        world.updater(tick)
        local job=common.state().world.jobs[id]
        check(job and job.completed>0 and job.completed<job.quantity,"partially completed admin job "..serpent.line(job))
        q.job=id;q.completed=job.completed;q.failed=job.failed

        local force=player.force
        force.technologies["ei-spider-artillery-mount"].researched=true
        spiders.refresh_force(force,"quality-removal-qc",tick)
        local name=catalog.configured_name("assault",catalog.researched_state(force),
            {cycling=false,special=false},settings.startup["ei-spider-range-aware-cycling"].value)
        for i=1,3 do
            local entity=assert(surface.create_entity{name=name,position={-60,i*12},force=force,raise_built=true})
            local stable=assert(spiders.get_vehicle_id(entity))
            spiders.set_weapon_controls(entity,{cycling=false,special=false,selected_slot=1},tick)
            for _=1,3 do spiders.updater{tick=tick} end
            local record=storage.ei.spider_vehicles.vehicles[stable]
            entity=record.entity
            record.stowed_ammo=i==3 and {name="artillery-shell",quality="normal",
                filter={name="artillery-shell",quality="normal",comparator="="}}
                or {name="artillery-shell",quality="uncommon",
                    filter={name="artillery-shell",quality="uncommon",comparator="="}}
            entity.get_inventory(defines.inventory.spider_trunk).insert{name="artillery-shell",count=2,quality="normal"}
            q.spiders[i]=stable
            if i==2 then
                player.teleport(entity.position,surface)
                check(player.mine_entity(entity,true),"native spider mining "..serpent.line{
                    minable=entity.valid and entity.minable_flag,controller=player.controller_type,
                    connected=player.connected,placement=record.placement~=nil,pending=record.pending_reason})
                for index=1,#player.get_main_inventory() do
                    local stack=player.get_main_inventory()[index]
                    if stack.valid_for_read and stack.item_number and storage.ei.spider_vehicles.items[stack.item_number] then
                        q.mined=stack.item_number
                        break
                    end
                end
                check(q.mined~=nil,"mined spider metadata")
            end
        end
        for i=1,9 do
            local platform=assert(force.create_space_platform{name="Quality removal "..i,planet="nauvis",
                starter_pack="space-platform-starter-pack"})
            if not platform.hub then assert(platform.apply_starter_pack()) end
            local point=assert(platform.hub.get_requester_point())
            local section=point.add_section()
            section.set_slot(1,{value={type="item",name="iron-plate",quality="normal",comparator="="},min=20})
            q.platforms[#q.platforms+1]=platform.index
        end
        scanner.repair_runtime_state("quality-removal-seed",tick)
        local stale={{value={type="item",name="iron-plate",quality="uncommon"},min=7},
            {value={type="item",name="quality-module",quality="normal"},min=3}}
        for _,index in ipairs(q.platforms) do
            local entry=assert(storage.ei.orbital_combinator_platform_cache[index])
            for _,field in ipairs({"request_filters","on_the_way_filters","need_inventory_filters","need_filters","filters"}) do
                entry[field]=table.deepcopy(stale)
            end
            for _,field in ipairs({"request_filter_map","targeted_deliver_map","need_inventory_map"}) do
                entry[field]={["item|iron-plate|uncommon"]=table.deepcopy(stale[1]),
                    ["item|quality-module|normal"]=table.deepcopy(stale[2])}
            end
            for _,field in ipairs({"request_filter_signature","requester_filter_signature","on_the_way_filter_signature",
                "targeted_deliver_signature","need_inventory_signature","need_filter_signature","filter_signature"}) do
                entry[field]="quality-removal-stale"
            end
        end
        local tiles={}
        for x=-1,4 do for y=-21,-16 do tiles[#tiles+1]={name="ei-induction-matrix-tile",position={x,y}} end end
        surface.set_tiles(tiles)
        local core=assert(surface.create_entity{name="ei-induction-matrix-core-0",position={0,-20},force=force,raise_built=true})
        local proxy=assert(storage.ei.induction_matrix.core[core.unit_number]).wire_proxy
        surface.create_entity{name="ei-induction-matrix-basic-coil",position={2.5,-19.5},force=force,raise_built=true}
        ei_induction_matrix.update_dirty{tick=tick}
        core=ei_induction_matrix.get_core_entity(ei_induction_matrix.get_matrix_id(proxy))
        q.core=core;core.energy=12375000
        local config=ei_induction_matrix.copy_circuit_settings()
        config.charge={enabled=true,signal={type="item",name="iron-plate",quality="uncommon"}}
        config.capacity={enabled=true,signal={type="quality",name="uncommon",quality="normal"}}
        config.max_io={enabled=true,signal={type="item",name="quality-module",quality="normal"}}
        config.percent={enabled=true,signal={type="virtual",name="signal-A",quality="normal"}}
        ei_induction_matrix.set_circuit_settings(core.unit_number,config)
        normal.seed_paid_radar(tick)
        return {checks=q.checks,picker_shape=q.picker_shape}
    end
    local function immediate(tick)
        local q=assert(storage.quality_optional_qc)
        local root=common.state()
        local session=root.sessions[q.player]
        check(session.drafts.item.name=="iron-plate" and session.drafts.item.quality=="normal","draft quality falls back to normal")
        check(session.drafts.place_item==false,"removed draft item cleared")
        check(root.world.jobs[q.job]==nil,"obsolete admin job cancelled")
        check(root.world.last_result.completed==q.completed and root.world.last_result.failed==q.failed,"completed admin work preserved")
        check(root.world.last_result.status=="cancelled: requested quality is no longer available","native job cancellation report")
        check(session.fields.place_item.elem_value==nil,"open picker synchronized")
        local choice=session.fields.item.elem_value
        check(lib.get_prototype_name(choice.name)=="iron-plate" and lib.get_prototype_name(choice.quality)=="normal","open surviving picker synchronized")
        gui.close(q.player,true);ei_admin_tools.open(game.get_player(q.player),"creation",tick)
        check(root.sessions[q.player].fields.place_item.elem_value==nil,"cleared picker stays clear on rebuild")
        local spider_root=storage.ei.spider_vehicles
        check(spider_root.vehicles[q.spiders[1]].stowed_ammo==nil,"live spider stale ammo cleared")
        check(spider_root.items[q.mined].stowed_ammo==nil,"mined spider stale ammo cleared")
        check(spider_root.vehicles[q.spiders[3]].stowed_ammo.quality=="normal","independent valid ammo metadata retained")
        q.ammo_before=ammo_count(spider_root.vehicles[q.spiders[1]].entity)
        q.spider_failures=spider_root.failures
        spiders.set_weapon_controls(spider_root.vehicles[q.spiders[1]].entity,{special=true},tick)
        for _,index in ipairs(q.platforms) do
            -- Inspect BEFORE any demand getter could refresh the cache.
            local entry=assert(storage.ei.orbital_combinator_platform_cache[index])
            for _,field in ipairs({"request_filters","on_the_way_filters","need_inventory_filters","need_filters",
                "request_filter_map","targeted_deliver_map","need_inventory_map"}) do valid_filters(entry[field]) end
            for _,field in ipairs({"request_filter_signature","on_the_way_filter_signature","need_filter_signature"}) do
                check(entry[field]~="quality-removal-stale","full cache repair "..index.."/"..field)
            end
        end
        for _,mode in ipairs({"requests","on_the_way","need"}) do
            local snapshot=scanner.qc_build_surface_snapshot(game.forces.player,game.surfaces.nauvis,mode,tick)
            check(#snapshot.platforms==9,"all platforms in "..mode)
            for _,platform in ipairs(snapshot.platforms) do valid_filters(platform.filters) end
        end
        local filters={
            {value={type="item",name="iron-plate",quality="uncommon"},min=7},
            {value={type="item",name="iron-plate",quality="normal"},min=5},
            {value={type="quality",name="uncommon",quality="normal"},min=2},
            {value={type="item",name="quality-module",quality="normal"},min=3},
            {value={type="not-a-signal-type",name="iron-plate"},min=11},
        }
        local page={label="quality-removal-qc",filters=filters,filter_count=#filters,start_index=1,stop_index=#filters}
        for _,owner in ipairs({scanner,logistics}) do
            local entity=game.surfaces.nauvis.create_entity{name="constant-combinator",position={100,100},force="player"}
            local section=entity.get_or_create_control_behavior().add_section()
            for i=1,5 do section.set_slot(i,{value={type="item",name="iron-plate",quality="normal",comparator="="},min=99}) end
            owner.qc_reconcile_section(section,page)
            check(section.get_slot(2).min==5,"valid demand published")
            for _,i in ipairs({1,3,4,5}) do check(not section.get_slot(i).value,"invalid demand slot cleared") end
            entity.destroy()
        end
        local manifest,total=logistics.qc_manifest_from_payload{filters=filters}
        check(#manifest==1 and total==5,"invalid demand excluded from manifest totals")
        local matrix=assert(storage.ei.induction_matrix.core[q.core.unit_number])
        for _,field in ipairs({"charge","capacity","max_io"}) do
            check(matrix.circuit_settings[field].signal==nil,"induction removed "..field)
        end
        check(matrix.circuit_settings.percent.signal.name=="signal-A","induction normal signal retained")
        ei_induction_matrix.update_wire_proxy_signals(q.core.unit_number,true)
        for _,section in pairs(matrix.wire_proxy.get_control_behavior().sections) do valid_filters(section.filters) end
        ei_induction_matrix.open_gui(game.get_player(q.player),q.core.unit_number)
        q.immediate=true
        return {checks=q.checks,labels=q.labels,picker_shape=q.picker_shape}
    end
    remote.add_interface("esir-quality-removal-qc",{
        clear_beacon_policy=function()storage.ei.beacon_module_policy=nil end,
        normal_setup=normal.setup,normal_step=normal.step,normal_immediate=normal.immediate,normal_finish=normal.finish,
        normal_damage=normal.damage,
        seed=function(surface,player,tick)return seed(game.get_surface(surface),game.get_player(player),tick)end,
        immediate=immediate,
        settled=function()
            local q=assert(storage.quality_optional_qc)
            local record=storage.ei.spider_vehicles.vehicles[q.spiders[1]]
            check(not spiders.get_weapon_controls(record.entity).pending,"live spider refit settled")
            check(ammo_count(record.entity)==q.ammo_before,"spider metadata did not create ammunition")
            check(storage.ei.spider_vehicles.failures==q.spider_failures,"spider refit has no failures")
            return {passed=true,checks=q.checks,labels=q.labels,picker_shape=q.picker_shape}
        end,
    })
end

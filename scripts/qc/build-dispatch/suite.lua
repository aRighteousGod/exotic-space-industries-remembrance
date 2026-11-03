-- Appended inside the private main control chunk; no shipping test interface.
local previous_tick = assert(script.get_event_handler(defines.events.on_tick))
local finished = false
script.on_event(defines.events.on_tick, function(tick_event)
    previous_tick(tick_event)
    if finished then return end
    finished = true
    local report = {phase=qc_phase, engine=script.active_mods.base, checks={}, cases={}}
    local function check(name, passed, detail)
        report.checks[#report.checks+1] = {name=name, passed=not not passed, detail=detail and tostring(detail)}
    end
    local function valid(entity) return entity and entity.valid end
    local owners = {
        {ei_terrain_evolution,"on_entity_built","event","terrain"},
        {ei_admin_tools,"on_built_entity","event","admin"},
        {ei_sweeping_radar,"on_built_entity","event","radar"},
        {ei_flamethrower_fuels,"on_built_entity","event","flame"},
        {ei_water_turret,"on_built_entity","event","water"},
        {ei_anisetron,"on_built_entity","event","anisetron"},
        {ei_spider_vehicles,"on_built_entity","event","spider"},
        {ei_combustion_turbine,"on_built_entity","event","turbine"},
        {ei_induction_matrix,"on_built_entity","event","matrix"},
        {ei_gaia,"on_built_entity","event","gaia"},
        {ei_crystal_accumulator,"on_built_entity","event","crystal"},
        {ei_steam_train,"on_built_entity","event","steam"},
        {ei_teslas_legacy,"on_built_entity","event","tesla"},
        {ei_fusion_reactor,"on_built_entity","entity","fusion",true},
        {ei_beacon_overload,"on_built_entity","entity","beacon",true},
        {ei_neutron_collector,"on_built_entity","entity","neutron",true},
        {ei_matter_stabilizer,"on_built_entity","entity","matter",true},
        {ei_black_hole,"on_built_entity","event","black-hole",true},
        {ei_gate,"on_built_entity","event","gate",true},
        {ei_alien_system,"on_built_entity","entity","alien",true},
        {ei_auric_inoculation_vat,"on_built_entity","event","auric",true},
        {ei_loaders_lib,"on_built_entity","entity","loaders",true},
        {ei_fueler,"on_built_entity","entity","fueler",true},
        {em_trains,"on_built_entity","entity","em",true},
        {orbital_combinator,"add","entity","orbital",true},
        {orbital_logistics,"on_built_entity","event","logistics",true},
        {ei_railgun_cooling,"on_built_entity","event","railgun",true},
        {ei_camp_fire,"on_built_entity","event","camp",true},
        {ei_singularity_lance,"on_built_entity","event","lance",true},
        {ei_sawblade_turret,"on_built_entity","event","sawblade",true},
        {ei_gaian_saucer_wake,"on_built_entity","event","saucer",true},
        {ei_emerald_apocalypse_hover_tank,"on_built_entity","event","emerald",true},
    }
    local function measure(label, event, handler)
        local result = {label=label, trace={}, counts={}, checks=0, invalid_general=0, identity=true, aliases=true,ticks=true}
        local originals = {}
        local guard = ei_lib.entity_check
        ei_lib.entity_check = function(entity) result.checks=result.checks+1;return guard(entity) end
        for index, row in ipairs(owners) do
            originals[index] = row[1][row[2]]
            row[1][row[2]] = function(...)
                local argument = select(1,...)
                local entity = row[3]=="event" and (argument.entity or argument.destination) or argument
                result.trace[#result.trace+1] = row[4]
                result.counts[row[4]] = (result.counts[row[4]] or 0)+1
                if row[5] and not valid(entity) then result.invalid_general=result.invalid_general+1 end
                if row[4]=="em" or row[4]=="orbital" then result.ticks=result.ticks and select(2,...)==event.tick end
                if row[4]=="fusion" then result.identity=result.identity and select(2,...)==event end
                if row[3]=="event" then
                    if argument.is_clone then
                        result.aliases=result.aliases and argument.entity==argument.destination and argument.entity==argument.created_entity
                    else result.identity=result.identity and argument==event end
                end
                return originals[index](...)
            end
        end
        local ok, err = pcall(handler or assert(script.get_event_handler(event.name)), event)
        for index,row in ipairs(owners) do row[1][row[2]]=originals[index] end
        ei_lib.entity_check=guard
        result.ok=ok;result.error=not ok and tostring(err) or nil
        result.receivers=#result.trace
        report.cases[#report.cases+1]=result
        return result
    end
    local function run()
        if qc_phase=="reload" then
            local saved=assert(storage.ei.build_dispatch_qc,"Missing persisted fixture")
            for name,entity in pairs(saved.entities) do check("reload-"..name,valid(entity)) end
            local turbine=saved.entities.turbine
            check("reload-turbine-registry",storage.ei.combustion_turbine.turbines_by_unit[turbine.unit_number]~=nil)
            check("reload-pipe-registry",storage.ei.fluid_entity[saved.entities.pipe.unit_number]==saved.entities.pipe)
            local direct_turbine, turbine_result=pcall(ei_combustion_turbine.on_built_entity,turbine)
            local direct_crystal, crystal_result=pcall(ei_crystal_accumulator.on_built_entity,saved.entities.crystal)
            report.native_entity_type=type(saved.entities.crystal)
            check("entity-only-turbine",direct_turbine and turbine_result==turbine,turbine_result)
            check("entity-only-crystal",direct_crystal and crystal_result==saved.entities.crystal,crystal_result)
            return
        end
        local surface=game.create_surface("build-dispatch-"..qc_phase,{width=512,height=256,autoplace_settings={entity={treat_missing_as_default=false,settings={}}}})
        surface.request_to_generate_chunks({0,0},5);surface.force_generate_chunk_requests()
        local tiles={}
        for x=-128,127 do for y=-64,63 do tiles[#tiles+1]={name="landfill",position={x,y}} end end
        surface.set_tiles(tiles)
        local force=game.create_force("build-dispatch-"..qc_phase)
        local sequence=0
        local function spawn(name, options)
            sequence=sequence+1
            local params={name=name,position={-115+(sequence%24)*10,-50+math.floor(sequence/24)*15},force=force,quality="normal",create_build_effect_smoke=false}
            for k,v in pairs(options or {}) do params[k]=v end
            local entity=assert(surface.create_entity(params),"Could not create "..name)
            return entity
        end
        local function build(entity, extra)
            local event={name=defines.events.script_raised_built,entity=entity,tick=tick_event.tick}
            for k,v in pairs(extra or {}) do event[k]=v end
            return event
        end
        local function accepted(label,event,expected)
            local result=measure(label,event)
            check(label.."-route",result.ok,result.error)
            check(label.."-valid-general",result.invalid_general==0)
            check(label.."-identity",result.identity)
            check(label.."-ticks",result.ticks)
            check(label.."-result",valid(event.entity) and event.entity.name==expected)
            for name,count in pairs(result.counts) do check(label.."-once-"..name,count==1,count) end
            return event.entity,result
        end
        local ordinary=measure("ordinary",build(spawn("iron-chest")))
        check("ordinary-route",ordinary.ok,ordinary.error)
        local pipe=spawn("pipe")
        local pipes=measure("pipe",build(pipe))
        check("pipe-route",pipes.ok,pipes.error)
        check("pipe-registry",storage.ei.fluid_entity[pipe.unit_number]==pipe)
        if qc_phase=="baseline" then
            -- Stable relevant paths provide cost comparisons independent of the crash.
            for _,case in ipairs({{"turbine-unchanged","ei-combustion-turbine"},
                {"crystal-unchanged","ei-crystal-accumulator"},{"tesla-unchanged","tl-basic-tesla-coil"}}) do
                local measured=measure(case[1],build(spawn(case[2])))
                check(case[1].."-route",measured.ok,measured.error)
            end
        end
        local original=spawn("ei-combustion-turbine",{quality="rare"})
        local tagged=build(original,{tags={ei_combustion_turbine_mode="fluid"}})
        local turbine=measure("tagged-turbine",tagged)
        if qc_phase=="baseline" then
            check("baseline-hazard-reproduced",not turbine.ok and turbine.invalid_general>0,turbine.error)
            check("baseline-original-consumed",not original.valid)
            return
        end
        check("tagged-turbine-route",turbine.ok,turbine.error)
        check("tagged-turbine-no-invalid",turbine.invalid_general==0)
        check("tagged-turbine-final",valid(tagged.entity) and tagged.entity.name=="ei-combustion-turbine-fluid")
        check("tagged-turbine-quality",valid(tagged.entity) and tagged.entity.quality.name=="rare")
        check("tagged-turbine-registry",valid(tagged.entity) and storage.ei.combustion_turbine.turbines_by_unit[tagged.entity.unit_number]~=nil)
        for _,event in ipairs({{}, {entity=spawn("iron-chest")}}) do
            if event.entity then event.entity.destroy() end
            local result=measure("empty-or-invalid",event,on_built_entity)
            check("empty-or-invalid-route",result.ok,result.error)
            check("empty-or-invalid-no-receivers",result.receivers==0)
        end
        check("nil-event",pcall(on_built_entity,nil))
        local events={"on_built_entity","on_robot_built_entity","on_space_platform_built_entity","script_raised_built","script_raised_revive"}
        for _,name in ipairs(events) do
            local tags,items={qc="preserved"},{}
            local event=build(spawn("iron-chest"),{name=defines.events[name],tick=0,tags=tags,consumed_items=items,player_index=1,robot=false,platform=false})
            accepted(name,event,"iron-chest")
            check(name.."-metadata",event.tags==tags and event.consumed_items==items and event.tick==0 and event.player_index==1 and event.robot==false and event.platform==false)
        end
        -- Native script raising, in addition to direct actual-handler event-shape probes.
        local native=spawn("pipe")
        script.raise_script_built{entity=native}
        check("native-script-built",storage.ei.fluid_entity[native.unit_number]==native)
        local failed=spawn("ei-combustion-turbine")
        storage.ei.build_dispatch_fail_turbine=true
        local failure_event=build(failed,{tags={ei_combustion_turbine_mode="fluid"}})
        accepted("turbine-create-failure",failure_event,"ei-combustion-turbine")
        storage.ei.build_dispatch_fail_turbine=nil
        check("turbine-create-failure-original",failure_event.entity==failed)
        local rejected=spawn("ei-gaia-pump")
        local rejected_event=build(rejected)
        local rejection=measure("gaia-rejected",rejected_event)
        check("gaia-rejected-safe",rejection.ok and rejected_event.entity==nil and not rejected.valid,rejection.error)
        check("gaia-rejected-stops",not rejection.counts.crystal and not rejection.counts.fusion)
        check("gaia-refund",surface.count_entities_filtered{name="item-on-ground"}>0)
        local crystal=accepted("crystal-downgrade",build(spawn("ei-crystal-accumulator-gaia")),"ei-crystal-accumulator")
        local tesla=accepted("tesla-downgrade",build(spawn("tl-basic-tesla-coil__exotic")),"tl-basic-tesla-coil")
        accepted("crystal-unchanged",build(spawn("ei-crystal-accumulator")),"ei-crystal-accumulator")
        accepted("turbine-unchanged",build(spawn("ei-combustion-turbine")),"ei-combustion-turbine")
        accepted("tesla-unchanged",build(spawn("tl-basic-tesla-coil")),"tl-basic-tesla-coil")
        local matrix=accepted("matrix-dormant",build(spawn("ei-induction-matrix-core-0")),"ei-induction-matrix-core-0")
        local matrix_tiles={}
        for x=80,87 do for y=10,13 do matrix_tiles[#matrix_tiles+1]={name="ei-induction-matrix-tile",position={x,y}} end end
        surface.set_tiles(matrix_tiles)
        local first_core=accepted("matrix-first",build(spawn("ei-induction-matrix-core-0",{position={81,11}})),"ei-induction-matrix-core-0")
        local second_core=accepted("matrix-duplicate",build(spawn("ei-induction-matrix-core-0",{position={85,11}})),"ei-induction-matrix-core-0")
        check("matrix-duplicate-survivor",second_core and second_core.valid and not first_core.valid)
        local flood=ei_induction_matrix.check_connected_tiles
        local incoming=spawn("ei-induction-matrix-core-0",{position={81,11}})
        ei_induction_matrix.check_connected_tiles=function(...)
            local result=flood(...)
            if incoming.valid then incoming.destroy() end
            return result
        end
        local lost_event=build(incoming)
        local lost=measure("matrix-incoming-removed",lost_event)
        ei_induction_matrix.check_connected_tiles=flood
        check("matrix-incoming-removed",lost.ok and lost_event.entity==nil and not lost.counts.gaia,lost.error)
        local radar_name
        for name in pairs(prototypes.entity) do if name:match("^ei%-.-radar%-placement$") then radar_name=name;break end end
        check("radar-prototype",radar_name~=nil)
        if radar_name then accepted("radar-replacement",build(spawn(radar_name)),radar_name:gsub("%-placement$","")) end
        local flame=spawn("entity-ghost",{inner_name="ei-flamethrower-turret-heavy-oil",tags={qc="ghost"}})
        local flame_event=build(flame)
        accepted("flamethrower-ghost",flame_event,"entity-ghost")
        check("flamethrower-ghost-final",not flame.valid and flame_event.entity.ghost_name=="flamethrower-turret" and flame_event.entity.tags.qc=="ghost")
        local scrubber=spawn("atan-air-scrubber",{quality="rare"})
        local scrub_event=build(scrubber)
        local scrubbed,scrub_trace=accepted("scrubber-normalization",scrub_event,"rare-atan-air-scrubber")
        check("scrubber-single-dispatch",not scrubber.valid and scrub_trace.counts.terrain==1 and scrub_trace.counts.turbine==1)
        accepted("scrubber-normal",build(spawn("atan-air-scrubber")),"atan-air-scrubber")
        -- Inject loss at the normalization return boundary; the preceding probe
        -- separately exercises native synchronous script-built reentrancy.
        local normalize=ei_air_scrubber.normalize
        ei_air_scrubber.normalize=function(entity)
            local result=normalize(entity)
            if valid(result) then result.destroy() end
            return result
        end
        local lost_scrubber=build(spawn("atan-air-scrubber",{quality="rare"}))
        local scrubber_loss=measure("scrubber-return-invalidated",lost_scrubber)
        ei_air_scrubber.normalize=normalize
        check("scrubber-return-invalidated",scrubber_loss.ok and lost_scrubber.entity==nil and scrubber_loss.receivers==0,scrubber_loss.error)
        -- Native rail and locomotive placement, not a replacement-body stand-in.
        surface.create_entity{name="straight-rail",position={100,40},direction=defines.direction.north,force=force}
        surface.create_entity{name="straight-rail",position={100,42},direction=defines.direction.north,force=force}
        surface.create_entity{name="straight-rail",position={100,44},direction=defines.direction.north,force=force}
        local steam=accepted("steam-placement",build(spawn("ei-steam-basic-locomotive-placement-entity",{position={100,42}})),"ei-steam-basic-locomotive")
        check("steam-force",steam and steam.force==force)
        accepted("steam-unchanged",build(steam),"ei-steam-basic-locomotive")
        for y=40,44,2 do surface.create_entity{name="straight-rail",position={110,y},direction=defines.direction.north,force=force} end
        for _,case in ipairs({
            {name="ei-crystal-accumulator-gaia",flag="crystal"},
            {name="tl-basic-tesla-coil__exotic",flag="tesla"},
            {name="ei-steam-basic-locomotive-placement-entity",flag="steam",position={110,42}},
        }) do
            local original=spawn(case.name,case.position and {position=case.position} or nil)
            storage.ei["build_dispatch_fail_"..case.flag]=true
            local event=build(original)
            local result=measure(case.flag.."-creation-failure",event)
            storage.ei["build_dispatch_fail_"..case.flag]=nil
            check(case.flag.."-creation-failure-safe",result.ok and not original.valid and event.entity==nil and not result.counts.fusion,result.error)
        end
        if prototypes.entity["rp-steam-pump"] then
            for _,quality in ipairs({"normal","rare","legendary"}) do
                local pump=accepted("steam-pump-"..quality,build(spawn("rp-steam-pump",{quality=quality})),"rp-steam-pump")
                local fluid=pump.get_fluid(2)
                local expected=math.min(100,math.max(3,3*0.33*pump.quality.level))
                check("steam-pump-prime-"..quality,fluid and fluid.name=="steam" and fluid.temperature==165 and math.abs(fluid.amount-expected)<1e-6)
            end
        else check("steam-pump-prototype",false,"Required dependency prototype absent") end
        local voice=spawn("ei-anisetron-crown-voice")
        local helper=measure("voice-consumed",build(voice))
        check("voice-consumed",helper.ok and not voice.valid and not helper.counts.turbine,helper.error)
        local transaction=ei_spider_vehicles.is_internal_transaction
        ei_spider_vehicles.is_internal_transaction=function() return true end
        local internal=measure("internal-transaction",build(spawn("iron-chest")))
        local internal_voice=spawn("ei-anisetron-facade-voice")
        local cleanup=measure("internal-helper-cleanup",build(internal_voice))
        ei_spider_vehicles.is_internal_transaction=transaction
        check("internal-observers",internal.counts.terrain==1 and internal.counts.admin==1)
        check("internal-stops",not internal.counts.turbine and not internal.counts.spider)
        check("internal-helper-cleanup",cleanup.ok and not internal_voice.valid and not cleanup.counts.turbine)
        -- A clone replacement must update the original destination and every adapter alias.
        local source=spawn("ei-crystal-accumulator")
        local destination=spawn("ei-crystal-accumulator-gaia")
        local clone_event={name=defines.events.on_entity_cloned,source=source,destination=destination,tick=tick_event.tick}
        local clone=measure("clone-crystal",clone_event)
        check("clone-crystal-route",clone.ok,clone.error)
        check("clone-crystal-aliases",clone.aliases and valid(clone_event.destination) and clone_event.destination.name=="ei-crystal-accumulator")
        check("clone-crystal-source",clone_event.source==source and source.valid)
        check("clone-no-gaia",not clone.counts.gaia)
        local power=spawn("ei-water-turret-power")
        local power_clone={name=defines.events.on_entity_cloned,source=power,destination=spawn("ei-water-turret-power"),tick=tick_event.tick}
        local power_result=measure("clone-power-cleanup",power_clone)
        check("clone-power-cleanup",power_result.ok and not power_clone.destination.valid and not power_result.counts.turbine)
        local proxy=spawn("ei-induction-matrix-core-circuit-interface")
        local proxy_clone={name=defines.events.on_entity_cloned,source=proxy,destination=spawn("ei-induction-matrix-core-circuit-interface"),tick=tick_event.tick}
        local proxy_result=measure("clone-proxy-intercept",proxy_clone)
        check("clone-proxy-intercept",proxy_result.ok and proxy_result.receivers==0 and proxy_clone.destination.get_control_behavior().enabled==false)
        local pasted={}
        local paste_owners={ei_fusion_reactor,ei_combustion_turbine,ei_neutron_collector,orbital_combinator,orbital_logistics}
        local paste_originals={}
        for index,owner in ipairs(paste_owners) do
            paste_originals[index]=owner.on_entity_settings_pasted
            owner.on_entity_settings_pasted=function(event)
                pasted[#pasted+1]=index
                check("clone-paste-metadata-"..index,event==clone_event and event.source==source and valid(event.destination))
                return paste_originals[index](event)
            end
        end
        local repeated=measure("clone-settings-tail",clone_event)
        for index,owner in ipairs(paste_owners) do owner.on_entity_settings_pasted=paste_originals[index] end
        check("clone-settings-tail-order",repeated.ok and table.concat(pasted,",")=="1,2,3,4,5",repeated.error)
        -- Every destructive receiver must terminate on its explicit consumed result.
        for _,owner in ipairs({ei_combustion_turbine,ei_induction_matrix,ei_gaia,ei_crystal_accumulator,ei_steam_train,ei_teslas_legacy}) do
            local previous=owner.on_built_entity
            owner.on_built_entity=function(event) event.entity.destroy();return nil end
            local consumed_event=build(spawn("iron-chest"))
            local consumed=measure("injected-consumption",consumed_event)
            owner.on_built_entity=previous
            check("consumed-stops",consumed.ok and consumed_event.entity==nil and not consumed.counts.fusion,consumed.error)
        end
        storage.ei.build_dispatch_qc={entities={turbine=tagged.entity,pipe=pipe,crystal=crystal,tesla=tesla,matrix=matrix,steam=steam,scrubber=scrubbed}}
        if game.is_multiplayer() then game.server_save("build-dispatch-reload")
        else game.auto_save("build-dispatch-reload") end
    end
    local ok,err=pcall(run)
    check("suite-completed",ok,not ok and err or nil)
    report.passed=true
    for _,entry in ipairs(report.checks) do report.passed=report.passed and entry.passed end
    helpers.write_file("build-dispatch-"..qc_phase..".json",helpers.table_to_json(report),false)
    log("BUILD_DISPATCH "..qc_phase.." passed="..tostring(report.passed))
end)

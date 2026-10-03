-- Ignored staging bridge: one real saved connected player; native GUI identities.
do
    local geometry=require("lib/sweeping-radar-geometry")
    local checks, player, started, q = {}, nil, false, nil
    local previous=script.get_event_handler(defines.events.on_tick)
    local function check(name,ok,detail) checks[#checks+1]={name=name,ok=not not ok,detail=detail} end
    local function test(name,fn)
        local ok,result=pcall(fn)
        check(name,ok and result~=false,ok and nil or tostring(result))
    end
    local function write()
        local pass=true;for _,c in ipairs(checks) do if not c.ok then pass=false end end
        helpers.write_file("admin-gui-native.json",helpers.table_to_json{all_pass=pass,checks=checks,
            players=#game.connected_players,tick=game.tick,version=script.active_mods.base},false)
        log("ADMIN_GUI_NATIVE_COMPLETE "..tostring(pass))
    end
    local function make(name,x,y)
        if not prototypes.entity[name] then return nil end
        return q.surface.create_entity{name=name,position={x=x,y=y},force=player.force,raise_built=true}
    end
    local function root(name) return player.gui.relative[name] or player.gui.screen[name] or player.gui.left[name] end
    local function open(entity)
        player.opened=nil
        player.teleport({entity.position.x,entity.position.y-6},entity.surface)
        player.opened=entity
    end
    local function setup()
        player.admin=true;player.opened=nil
        local surface=game.create_surface("admin-gui-native-fixture",{width=256,height=256})
        surface.request_to_generate_chunks({0,0},4);surface.force_generate_chunk_requests()
        for _,entity in pairs(surface.find_entities()) do entity.destroy() end
        local tiles={};for x=-90,90 do for y=-90,90 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
        surface.set_tiles(tiles)
        q={surface=surface,start=game.tick,entities={}}
        player.teleport({0,-10},surface)
        q.entities.water=make("ei-water-turret",0,0)
        q.entities.radar=make("ei-sweeping-radar",15,0)
        q.entities.scanner=make("ei-orbital-combinator",30,0)
        q.entities.fueler=make("ei-fueler",45,0)
        q.entities.matter=make("ei-exotic-assembler",60,0)
        q.entities.neutron=make("ei-neutron-collector",0,30)
        q.entities.auric=make("ei-auric-inoculation-vat",15,30)
        q.entities.black=make("ei-black-hole",30,30)
        q.entities.matrix=make("ei-induction-matrix-core-0",45,30)
        q.entities.gate=make("ei-gate",60,30)
        q.entities.combustion=make("ei-combustion-turbine",0,60)
        q.entities.fusion=make("ei-fusion-reactor",15,60)
        q.entities.railgun=make("railgun-turret",30,60)
        q.entities.logistics=make("ei-orbital-coordinator",45,60)
        q.entities.spider=make("assault_spidertron",60,60)
        q.entities.crystal=make("ei-crystal-accumulator",-30,0)
        for name in pairs(prototypes.entity) do
            if not q.entities.spider and name:find("^ei%-assault%-spidertron") then q.entities.spider=make(name,60,60) end
            if not q.entities.emerald and name:find("^ei%-emerald%-apocalypse") and prototypes.entity[name].type=="car" then q.entities.emerald=make(name,-15,0) end
        end
    end
    local function run_tests()
        check("actual connected saved player",player.valid and player.connected and #game.connected_players>=1)
        test("water same entity root retained and control changed",function()
            local entity=assert(q.entities.water);open(entity)
            local first=assert(root("ei-water-turret-console"));local content=assert(first.body.content)
            local mode=content.mode.selected_index%3+1;content.mode.selected_index=mode
            ei_water_turret.on_gui_changed{player_index=player.index,element=content.mode,tick=game.tick}
            return first.valid and first==root("ei-water-turret-console") and content.mode.selected_index==mode
        end)
        test("EM closed dirty refresh avoids registry summary",function()
            local tech=player.force.technologies["ei_em-trains"];if tech then tech.researched=true end
            em_trains_gui.close_mod_gui(player)
            local original=em_trains_gui.get_data;local calls=0
            em_trains_gui.get_data=function(...) calls=calls+1;return original(...) end
            em_trains_gui.mark_dirty();em_trains_gui.updater()
            em_trains_gui.get_data=original
            return calls==0
        end)
        test("EM open dirty refresh one summary and stable panel",function()
            em_trains_gui.open_mod_gui(player)
            local first=assert(root("ei_mod-gui"));local original=em_trains_gui.get_data;local calls=0
            em_trains_gui.get_data=function(...) calls=calls+1;return original(...) end
            em_trains_gui.mark_dirty();em_trains_gui.updater();em_trains_gui.updater()
            em_trains_gui.get_data=original
            return calls==1 and first.valid and first==root("ei_mod-gui")
        end)
        test("spider control refresh retains same native entity root",function()
            local entity=assert(q.entities.spider);open(entity)
            local first=assert(root("ei-spider-weapon-console"));local controls=assert(ei_spider_vehicles.get_weapon_controls(entity))
            ei_spider_vehicles.set_weapon_controls(entity,{overkill=not controls.overkill},game.tick)
            return first.valid and first==root("ei-spider-weapon-console")
        end)
        test("admin all pages build without losing drafts/root",function()
            assert(ei_admin_tools,"admin feature missing")
            ei_admin_tools.open(player,"creation",game.tick)
            local first=assert(root("ei-admin-console"));local session=storage.ei.admin_tools.sessions[player.index]
            assert(session.drafts.item_quantity=="1","untouched quantity default missing")
            assert(session.fields.item.elem_value.name=="iron-plate","selector default missing")
            session.fields.item_quantity.text="17";session.drafts.item_quantity="17"
            for _,page in ipairs({"planets","chunks","players","moderation","fluids","enemies","effects","research","diagnostics","repairs","cameras","creation"}) do ei_admin_tools.open(player,page,game.tick) end
            return first.valid and first==root("ei-admin-console") and session.fields.item_quantity.text=="17"
                and session.diagnostics and session.diagnostics.overview.valid
                and session.diagnostics.values.role.type=="label"
        end)
        -- Open every available ordinary entity panel through native dispatch. This
        -- checks API/lifecycle availability; it is not visual or two-player proof.
        for _,spec in ipairs({{"fueler","ei-fueler-console"},{"matter","ei-exotic-assembler-console"},
            {"neutron","ei-neutron-collector-console"},{"auric","ei-auric-inoculation-vat-console"},
            {"black","ei-black-hole-console"},{"gate","ei-gate-console"},{"combustion","ei-combustion-turbine-console"},
            {"fusion","ei-fusion-reactor-console"},{"railgun","ei-railgun-cooling-console"},
            {"scanner","ei-orbital-combinator-console"},{"logistics","ei-orbital-logistics-console"},
            {"emerald","ei-emerald-apocalypse-hover-tank-console"}}) do
            test("native panel "..spec[1],function() open(assert(q.entities[spec[1]],"prototype unavailable"));return root(spec[2])~=nil end)
        end
        player.opened=nil;em_trains_gui.close_mod_gui(player)
        test("matrix native proxy opens persistent screen",function()
            local core=assert(q.entities.matrix)
            local data=assert(storage.ei.induction_matrix.core[core.unit_number])
            open(assert(data.wire_proxy));return root("ei-induction-matrix-console")~=nil
        end)
        test("crystal native shell opens detached readout",function()
            open(assert(q.entities.crystal));return root("ei-crystal-accumulator-console-screen")~=nil
        end)
        test("alien confirmation opens and closes through owner",function()
            ei_alien_system.make_confirm_gui(player,{cost=1},10)
            local frame=assert(root("ei-alien-confirm-console"));ei_alien_system.exit_confirm(player,{})
            return not frame.valid and not root("ei-alien-confirm-console")
        end)
        test("shared camera native entity binding and scoped close",function()
            local frame=assert(ei_lib.camera_open(player,{owner="fixture",id="water",entity=q.entities.water},game.tick))
            local windows=storage.ei_camera_windows.windows
            local entry=assert(windows[player.index..":fixture:water"])
            assert(entry.camera.entity==q.entities.water,"native camera failed to bind")
            ei_lib.camera_close_owner("fixture",player.index)
            return not frame.valid and windows[player.index..":fixture:water"]==nil
        end)
        test("radar native screen requested",function() open(assert(q.entities.radar));return true end)
    end
    script.on_event(defines.events.on_tick,function(event)
        previous(event)
        player=game.connected_players[1]
        if not player then return end
        if not started then
            started=true
            test("native setup",setup)
            if not q then write();return end
            run_tests()
        elseif q and event.tick==q.start+2 then
            test("radar screen survives due refresh and coverage handles",function()
                local frame=assert(root("ei_sweeping_radar_gui"));local record=assert(ei_sweeping_radar.get_record(q.entities.radar))
                local viewer=storage.ei.sweeping_radar.gui.viewers[player.index]
                record.geometry=geometry.new({mode=1,radius=2,near=0,start=0,stop=0,bearing=0},record.entity.position)
                record.pass_observations=1;record.heading=90
                ei_sweeping_radar_gui._qc_overlay(player,viewer,record)
                local coverage=viewer.renders[1];local beam=viewer.beam_renders[1]
                ei_sweeping_radar_gui._qc_overlay(player,viewer,record)
                assert(coverage.valid and viewer.renders[1]==coverage and viewer.beam_renders[1]==beam,"unchanged overlays replaced")
                record.heading=180;ei_sweeping_radar_gui._qc_overlay(player,viewer,record)
                return frame.valid and coverage.valid and viewer.renders[1]==coverage and not beam.valid
            end)
            player.opened=nil
            test("radar closed has no tick work",function() return not ei_sweeping_radar_gui.has_tick_work() end)
            test("closed black-hole GUI does no snapshot queries",function()
                ei_black_hole.close_gui(player)
                local original=ei_black_hole.get_data;local calls=0
                ei_black_hole.get_data=function(...) calls=calls+1;return original(...) end
                ei_black_hole.update_player_guis();ei_black_hole.update_player_guis()
                ei_black_hole.get_data=original
                return calls==0
            end)
            test("closed matrix GUI does no power snapshot queries",function()
                ei_induction_matrix.close_gui(player)
                local original,calls={},0
                for _,name in ipairs({"get_matrix_capacity","get_matrix_current_stored_power","get_matrix_max_IO"}) do
                    original[name]=ei_induction_matrix[name]
                    ei_induction_matrix[name]=function(...) calls=calls+1;return original[name](...) end
                end
                ei_induction_matrix.update_player_guis();ei_induction_matrix.update_player_guis()
                for name,method in pairs(original) do ei_induction_matrix[name]=method end
                return calls==0
            end)
            write()
        end
    end)
end

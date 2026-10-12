-- Frozen native color fixture: bounded cases, one dispatcher, no firing or FX.
-- Lifecycle and ownership: README.md#contract in this helper directory.
local contract = require("contract")

script.on_init(function()
    if remote.interfaces.freeplay then
        remote.call("freeplay","set_skip_intro",true)
        remote.call("freeplay","set_disable_crashsite",true)
    end
    storage.started = game.tick -- on_init boundary has no event tick.
    storage.surface = game.create_surface("mg-native-color", {autoplace_controls={},
        autoplace_settings={entity={treat_missing_as_default=false},
            decorative={treat_missing_as_default=false}}})
    storage.surface.request_to_generate_chunks({0,0},2)
    storage.surface.force_generate_chunk_requests()
    storage.surface.freeze_daytime = true
    storage.surface.daytime = 0
    storage.surface.create_entity{name="mg-color-background",position={0,0}}
    storage.captures = {}
end)

script.on_event(defines.events.on_tick,function(event)
    if storage.done then return end
    local elapsed = event.tick-storage.started
    local player = game.get_player(1)
    if player and not storage.viewer then
        player.set_controller{type=defines.controllers.spectator}
        player.teleport({0,0},storage.surface)
        storage.viewer = true
    end
    local step = elapsed-contract.first_capture_tick
    if step >= 0 and step < #contract.cases*2 then
        local case = contract.cases[math.floor(step/2)+1]
        local variant = step%2 == 0 and "separated" or "reference"
        if storage.entity and storage.entity.valid then storage.entity.destroy() end
        local density = contract.profiles[case.profile].density
        local fractional = case.fractional_native_pixel_offset/32
        local camera = {x=0,y=0}
        local position
        if not case.background_only then
            local prototype_name = "mg-color-"..case.profile.."-"..variant.."-"..case.pose
            if variant == "reference" and contract.reference_selection == "cells" then
                prototype_name = prototype_name.."-d"..case.direction
            end
            storage.entity = storage.surface.create_entity{
                name=prototype_name,
                position={0,0},force="player"}
            assert(storage.entity, "Color fixture turret creation failed")
            storage.entity.active = false
            local angle = case.direction/256*2*math.pi
            storage.entity.orientation = (math.atan2(math.sqrt(2)*math.sin(angle),math.cos(angle))/(2*math.pi))%1
            -- Turret creation snaps to its placement grid. Move the camera
            -- relative to the measured position, never the requested position.
            position = storage.entity.position
            camera = {x=position.x-fractional,y=position.y-fractional}
        end
        local path = "minigun-native-color/"..case.id.."/"..variant..".png"
        game.take_screenshot{surface=storage.surface,position=camera,resolution=case.resolution,
            zoom=case.zoom,daytime=0,anti_alias=false,show_gui=false,show_entity_info=false,
            hide_clouds=true,hide_fog=true,force_render=true,path=path}
        storage.captures[#storage.captures+1] = {case_id=case.id,variant=variant,path=path,
            elapsed=elapsed,position=position,camera_position=camera,density=32,source_density=density,
            offset_native_pixels=case.fractional_native_pixel_offset,
            offset_source_pixels=case.fractional_native_pixel_offset*density/32,
            offset_screen_pixels=case.fractional_native_pixel_offset*case.zoom,
            prototype_name=storage.entity and storage.entity.valid and storage.entity.name or nil,
            orientation=storage.entity and storage.entity.valid and storage.entity.orientation or nil}
    end
    if elapsed == contract.finish_tick then
        local report = {schema=1,matrix=contract.matrix,capture_geometry="entity-relative-camera-v3",offset_units="engine-native-pixel-32-per-tile",started=storage.started,finished=event.tick,
            cases=contract.cases,captures=storage.captures,rgb_max_allowance=contract.rgb_max_allowance,
            rgb_rms_allowance=contract.rgb_rms_allowance,errors={}}
        report.color_leaf_flags=prototypes.mod_data["mg-color-texture-audit"].data.leaves
        helpers.write_file("minigun-native-color-report.json",helpers.table_to_json(report),false)
        game.set_wait_for_screenshots_to_finish()
        storage.done = true
    end
end)

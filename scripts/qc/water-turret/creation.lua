-- Engine gate for self-registering fires; runs only in the isolated QC mod.
local config=require("__exotic-space-industries-remembrance__/lib/firefighting-config")
local flames=require("__exotic-space-industries-remembrance__/lib/flamethrower-fuels")
local function check(name,pass,detail)
    storage.creation.results[name]={pass=pass==true,detail=detail}
end
local function marked(entity)
    return entity and entity.valid and storage.creation.ids[script.register_on_object_destroyed(entity)]~=nil
end
script.on_event(defines.events.on_script_trigger_effect,function(event)
    local state=storage.creation
    if not state then return end
    if event.effect_id=="water-qc-prior-created" then state.prior=state.prior+1;return end
    if event.effect_id~="ei-water-fire-created" then return end
    local entity=event.target_entity
    if not (entity and entity.valid and entity.type=="fire") then
        state.bad_identity=state.bad_identity+1;return
    end
    local id=script.register_on_object_destroyed(entity)
    state.ids[id]=entity;state.births=state.births+1
    local x=entity.position.x
    if x>35 and x<65 and entity.name=="fire-flame-on-tree" then state.tree_births=state.tree_births+1 end
    if x>75 and x<90 and entity.name=="fire-flame-on-tree" then state.sticker_births=state.sticker_births+1 end
    if x>15 and x<25 then state.refuel_births=state.refuel_births+1 end
end)
script.on_event(defines.events.on_entity_cloned,function(event)
    if event.destination.type=="fire" then storage.creation.cloned=event.destination end
end)
script.on_init(function()
    storage.creation={results={},ids={},births=0,bad_identity=0,prior=0,tree_births=0,sticker_births=0,refuel_births=0}
end)
script.on_event(defines.events.on_tick,function(event)
    local s=storage.creation
    if not s.started then
        s.started=event.tick
        local surface=game.create_surface("water-creation",{width=384,height=128,autoplace_settings={entity={treat_missing_as_default=false}}})
        surface.request_to_generate_chunks({0,0},5);surface.force_generate_chunk_requests();s.surface=surface
        local tiles={}
        for x=-150,150 do for y=-32,32 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
        surface.set_tiles(tiles)
        local count=0
        for name,prototype in pairs(prototypes.entity) do
            if prototype.type=="fire" and (config.thermal_fires[name] or flames.ground_fires[name]) then
                count=count+1
                local flame=surface.create_entity{name=name,position={-140+(count%30)*4,-25+math.floor(count/30)*8},force="neutral",create_build_effect_smoke=false}
                check("direct-"..name,marked(flame))
                if flame then flame.destroy() end
            end
        end
        check("supported-prototypes-present",count>=9,count)
        check("prior-effect-preserved",s.prior>0,s.prior)
        local fire=surface.create_entity{name="ei-oil-fire-flame",position={0,0}}
        local clone=fire.clone{position={5,0},surface=surface,force="neutral"}
        check("clone-lifecycle-event",clone==nil or s.cloned==clone,clone==nil and "fire clone unsupported by engine" or "clone event received")
        check("duplicate-registration-stable",script.register_on_object_destroyed(fire)==script.register_on_object_destroyed(fire))
        for x=40,60,2 do for y=-6,6,2 do surface.create_entity{name="tree-01",position={x,y}} end end
        local tree=surface.find_entities_filtered{name="tree-01",position={50,0},radius=2}[1]
        surface.create_entity{name="fire-flame-on-tree",position=tree.position,target=tree}
        s.sticker_target=surface.create_entity{name="behemoth-biter",position={82,0},force="enemy"}
        s.sticker_target.active=false;s.sticker_target.destructible=false
        for x=81,83 do for y=-1,1 do surface.create_entity{name="tree-01",position={x,y}} end end
        surface.create_entity{name="fire-sticker",position=s.sticker_target.position,target=s.sticker_target}
        surface.create_entity{name="flamethrower-fire-stream",position={100,0},source_position={100,0},target_position={110,0},force="player"}
    end
    local t=event.tick-s.started
    if t<=100 and t%5==0 then
        s.surface.create_entity{name="water-qc-refuel",position={20,0},target={20,0},speed=1,force="player"}
    end
    if t==150 then check("refuel-one-birth",s.refuel_births==1,s.refuel_births) end
    if t==120 then
        local fires=s.surface.find_entities_filtered{position={110,0},radius=3,type="fire"}
        check("native-stream-created",#fires>0,#fires)
        for _,fire in pairs(fires) do check("native-stream-identity",marked(fire)) end
    end
    if t==2100 then
        check("tree-spread-created",s.tree_births>1,s.tree_births)
        check("sticker-spread-created",s.sticker_births>0,s.sticker_births)
        check("birth-entity-identity",s.bad_identity==0,s.bad_identity)
        local pass=true
        for _,result in pairs(s.results) do if not result.pass then pass=false end end
        helpers.write_file("water-qc.json",helpers.table_to_json{all_pass=pass,cases=s.results},false)
    end
end)

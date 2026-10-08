-- Native mining, planetary protection and opt-in hazard acceptance.
local model = {minimum_ticks = 10300}
local function call(name, ...) return remote.call("ei-terrain-qc", name, ...) end
local function root() storage.terrain_extra = storage.terrain_extra or {}; return storage.terrain_extra end
local function counter(surface, name)
    return call("snapshot", surface.index).counters[name] or 0
end
local function check_result(check, name, pass, detail)
    check("extra-" .. name, pass == true, detail)
end
local function override(surface, name, value, check)
    local ok, message = call("override", surface.index, name, value)
    check_result(check, "override-" .. surface.name .. "-" .. name, ok, message)
end
local function prepare(surface, p, tile, radius)
    surface.request_to_generate_chunks(p, 1)
    surface.force_generate_chunk_requests()
    for _, entity in ipairs(surface.find_entities_filtered{
        area = {{p.x-24,p.y-24},{p.x+24,p.y+24}},
    }) do
        if entity.valid and entity.type ~= "character" then entity.destroy() end
    end
    local tiles = {}
    for x = p.x-radius, p.x+radius do for y = p.y-radius, p.y+radius do
        tiles[#tiles+1] = {name=tile,position={x,y}}
    end end
    surface.set_tiles(tiles,false,false,false,true)
end
local function configure(surface, check)
    for _, pair in ipairs{
        {"active",true},{"intensity","custom"},{"custom_rate_multiplier",4},
        {"degradation",false},{"recovery",false},{"tree_stress",false},
        {"tree_regrowth",false},{"aging",false},{"rot",false},{"blood",false},
        {"cliffs",false},{"flood",false},{"drought",false},{"paving",false},
        {"wildfire","off"},{"seasonal_daylight",false},{"seasonal_ecology",false},
        {"mining_scars",true},{"mining_recovery",false},{"mining_probability",1},
        {"mining_radius",0},{"mining_patch_radius",1},{"hazard_radius",1},
        {"protection_buffer",0},
    } do override(surface,pair[1],pair[2],check) end
end
local function resource_name(drill, infinite, mismatch)
    local candidates = {}
    for name, prototype in pairs(prototypes.entity) do
        if prototype.type == "resource" and prototype.infinite_resource == infinite then
            local compatible = drill and drill.prototype.resource_categories[prototype.resource_category] == true
            local mineable = prototype.mineable_properties
            if (not drill or compatible ~= mismatch) and not mineable.required_fluid then
                candidates[#candidates+1] = name
            end
        end
    end
    table.sort(candidates)
    -- Prefer a familiar finite resource so ordinary ore footprints are exercised.
    for _, wanted in ipairs{"iron-ore","coal","stone"} do
        for _, name in ipairs(candidates) do if name==wanted then return name end end
    end
    return candidates[1]
end
local mining_cases = {
    {id="burner",name="ei-burner-quarry",expected=true},
    {id="steam",name="ei-steam-quarry",expected=true},
    {id="electric",name="ei-electric-quarry",expected=true},
    {id="big-normal",name="big-mining-drill",expected=true},
    {id="big-legendary-edge",name="big-mining-drill",quality="legendary",expected=true,edge=true},
    {id="ordinary-burner",name="burner-mining-drill",expected=false},
    {id="ordinary-electric",name="electric-mining-drill",expected=false},
    {id="outside-live-area",name="ei-burner-quarry",expected=false,outside=true},
    {id="infinite",name="ei-burner-quarry",expected=false,infinite=true},
    {id="category-mismatch",name="ei-burner-quarry",expected=false,mismatch=true},
    {id="overlap-is-coverage",name="ei-burner-quarry",expected=true,overlap=true},
    {id="burst",name="ei-burner-quarry",expected=true,mass=true},
}
local function mining_case(index, check)
    local spec = mining_cases[index]
    local surface = game.surfaces.nauvis
    local p = {x=1024+index*96,y=1024}
    prepare(surface,p,"grass-1",24)
    local drill = surface.create_entity{
        name=spec.name,quality=spec.quality or "normal",position=p,force="player",
    }
    check_result(check,"mining-created-"..spec.id,drill~=nil)
    if not drill then return end
    drill.disabled_by_script=true -- Adapter policy deliberately tests coverage, not current activity.
    local box=drill.mining_area
    local target={x=math.floor(box.right_bottom.x)-0.5,y=p.y+0.5}
    if spec.outside then target.x=math.ceil(box.right_bottom.x)+2.5 end
    if not spec.edge and not spec.outside then target={x=p.x+0.5,y=p.y+0.5} end
    local name=resource_name(drill,spec.infinite==true,spec.mismatch==true)
    if spec.infinite then name=resource_name(nil,true,false) end
    check_result(check,"mining-resource-available-"..spec.id,name~=nil)
    if not name then drill.destroy();return end
    local overlap
    if spec.overlap then
        overlap=surface.create_entity{name="burner-mining-drill",position={p.x+5,p.y},force="player"}
        check_result(check,"overlap-disallowed-created",overlap~=nil)
        if overlap then overlap.disabled_by_script=true end
    end
    local resources={}
    if spec.mass then
        for x=-12,12,8 do for y=-12,12,8 do
            local resource=surface.create_entity{name=name,position={p.x+x+0.5,p.y+y+0.5},amount=10}
            if resource then resources[#resources+1]=resource end
        end end
    else
        local prototype=prototypes.entity[name]
        resources[1]=surface.create_entity{
            name=name,position=target,amount=math.max(10,prototype.minimum_resource_amount or 0),
        }
    end
    check_result(check,"mining-resource-created-"..spec.id,#resources>0)
    local before=call("pending")
    local queries=counter(surface,"mining_queries")
    local saturated=counter(surface,"mining_saturated")
    for _, resource in ipairs(resources) do call("depleted",resource) end
    local admitted=call("pending")-before
    check_result(check,"mining-attribution-"..spec.id,spec.expected and admitted==1 or not spec.expected and admitted==0,{
        admitted=admitted,queries=counter(surface,"mining_queries")-queries,resource=name,
        quality=drill.quality.name,mining_area=box,target=target,
    })
    if spec.infinite then check_result(check,"infinite-before-query",counter(surface,"mining_queries")==queries) end
    if spec.mass then
        check_result(check,"mass-mining-query-cap",counter(surface,"mining_queries")-queries<=1)
        check_result(check,"mass-mining-saturation-visible",counter(surface,"mining_saturated")>saturated)
    end
    for _, resource in ipairs(resources) do if resource.valid then resource.destroy() end end
    if overlap and overlap.valid then overlap.destroy() end
    drill.destroy()
end
local function start_native(tick,check)
    local r=root();local surface=game.surfaces.nauvis;local p={x=3072,y=1024}
    prepare(surface,p,"grass-1",24)
    -- Native drills discover resources when they are placed. Script the ore
    -- first so this fixture follows ordinary player construction over a patch.
    local name=resource_name({prototype=prototypes.entity["ei-burner-quarry"]},false,false)
    local pos={x=p.x+10.5,y=p.y+0.5}
    local resource=name and surface.create_entity{name=name,position=pos,amount=1}
    local drill=surface.create_entity{name="ei-burner-quarry",position=p,force="player"}
    check_result(check,"native-drill-created",drill~=nil)
    if not drill then return end
    local chest=surface.create_entity{name="iron-chest",position=drill.drop_position,force="player"}
    local inserted=drill.burner and drill.burner.inventory.insert{name="coal",count=30} or 0
    check_result(check,"native-mining-arrangement",resource~=nil and chest~=nil and inserted>0,{fuel=inserted,resource=name})
    r.native={drill=drill,resource=resource,position=pos,start=tick,events=0,surface=surface}
end
function model.on_resource_depleted(event)
    local r=root();local native=r.native
    if native and event.entity==native.resource then
        native.events=native.events+1;native.depleted_tick=event.tick
    end
end
local planet_tiles={
    {name="nauvis",source="grass-1",target="grass-3"},
    {name="gaia",source="ei-gaia-grass-2",target="ei-gaia-grass-1"},
    {name="vulcanus",source="volcanic-smooth-stone",target="volcanic-smooth-stone-warm"},
    {name="gleba",source="midland-cracked-lichen",target="midland-cracked-lichen-dark"},
    {name="fulgora",source="fulgoran-rock",target="fulgoran-sand"},
    {name="aquilo",source="snow-crests",target="snow-flat"},
}
local function planet_case(index,check)
    local r=root();local spec=planet_tiles[index];local planet=game.planets[spec.name]
    check_result(check,"planet-exists-"..spec.name,planet~=nil)
    if not planet then return end
    local surface=planet.surface or planet.create_surface()
    configure(surface,check)
    -- Keep Gaia's positive transition case separate from the starting site's
    -- conservative authored-terrain protection. Marker preservation is tested
    -- independently below.
    local p=spec.name=="gaia" and call("gaia_positive_point",surface.index) or {x=64,y=64}
    prepare(surface,p,spec.source,6)
    r.planets[spec.name]={surface=surface,position=p,source=spec.source,target=spec.target}
    check_result(check,"planet-admitted-"..spec.name,call("enqueue",surface.index,p,"thermal"))
    if spec.name=="fulgora" then
        r.fulgora_day=surface.daytime_parameters;r.fulgora_ticks=surface.ticks_per_day
        check_result(check,"fulgora-calendar-excluded",call("calendar",surface.index).status=="excluded")
        check_result(check,"fulgora-phase-rejected",not call("phase",surface.index,.25))
    end
end
local function protections(check)
    local r=root();local s=game.surfaces.nauvis;r.protections={};r.protection_queue={}
    local cases={
        {id="negative-coordinate",p={x=-64,y=-64},tile="grass-1",expected="grass-3"},
        {id="hidden-terrain",p={x=512,y=512},tile="grass-1",expected="grass-1",hidden=true},
        {id="foundation",p={x=544,y=512},tile="foundation",expected="foundation"},
        {id="rail",p={x=576,y=512},tile="grass-1",expected="grass-1",rail=true},
    }
    for _,spec in ipairs(cases) do
        prepare(s,spec.p,spec.tile,5)
        if spec.hidden then s.set_hidden_tile(spec.p,"dirt-1") end
        if spec.rail then
            local rail=s.create_entity{name="straight-rail",position={spec.p.x,spec.p.y},direction=defines.direction.north,force="player"}
            check_result(check,"rail-created",rail~=nil)
        end
        r.protection_queue[#r.protection_queue+1]={surface=s,p=spec.p,id=spec.id}
        r.protections[#r.protections+1]=spec
    end
    local distant={x=500000,y=500000}
    r.ungenerated=distant
    check_result(check,"ungenerated-before",not s.is_chunk_generated({math.floor(distant.x/32),math.floor(distant.y/32)}))
    r.protection_queue[#r.protection_queue+1]={surface=s,p=distant,id="ungenerated"}
    local unsupported=game.create_surface("terrain-extra-unassociated",{width=32,height=32})
    check_result(check,"unassociated-surface-rejected",not call("enqueue",unsupported.index,{x=0,y=0},"thermal"))
    game.delete_surface(unsupported)
    local gaia=r.planets.gaia and r.planets.gaia.surface
    if gaia then
        local p={x=512,y=512};prepare(gaia,p,"ei-gaia-grass-1",5)
        local flag=gaia.create_entity{name="ei-artifact-flag",position=p,force="neutral"}
        check_result(check,"artifact-marker-created",flag~=nil)
        r.gaia_protected={surface=gaia,p=p}
        r.protection_queue[#r.protection_queue+1]={surface=gaia,p=p,id="gaia-marker"}
    end
end
local function start_hazards(check)
    local r=root();local s=game.surfaces.nauvis
    for _,pair in ipairs{{"aging",true},{"rot",true},{"cliffs",true},{"cliff_probability",0},{"wildfire","contained"},{"wildfire_probability",0}} do override(s,pair[1],pair[2],check) end
    r.hazards={};r.hazard_queue={}
    for i,spec in ipairs{
        {id="aging",name="tree-01",cause="aging"},
        {id="rot",name="dry-tree",cause="rot"},
        {id="cliff",name="cliff",cause="cliff"},
        {id="protected-tree",name="tree-01",cause="aging",chest=true},
    } do
        local p={x=1024+i*48,y=1280};prepare(s,p,"grass-1",16)
        local entity=s.create_entity{name=spec.name,position={p.x+0.5,p.y+0.5},force="neutral",cliff_orientation=spec.name=="cliff" and "west-to-east" or nil}
        check_result(check,"hazard-created-"..spec.id,entity~=nil)
        if spec.chest then check_result(check,"hazard-chest-created",s.create_entity{name="iron-chest",position={p.x+3.5,p.y+0.5},force="player"}~=nil) end
        if entity then r.hazard_queue[#r.hazard_queue+1]={surface=s,p=p,cause=spec.cause,id=spec.id,extra=spec.cause=="cliff" and {entity=entity} or {tree=entity}} end
        r.hazards[#r.hazards+1]={id=spec.id,entity=entity,p=p,chest=spec.chest}
    end
    local p={x=1344,y=1280};prepare(s,p,"grass-1",16)
    r.fire={p=p,before=counter(s,"ignitions")}
    r.hazard_queue[#r.hazard_queue+1]={surface=s,p=p,cause="ignite",id="ignite"}
end
function model.on_tick(event,check)
    local r=root()
    if not r.start then
        r.start=event.tick;r.planets={}
        configure(game.surfaces.nauvis,check)
    end
    local t=event.tick-r.start
    for i in ipairs(mining_cases) do if t==60+i*8 then mining_case(i,check) end end
    if t==400 then start_native(event.tick,check) end
    if t==2100 then
        local n=r.native
        check_result(check,"native-depletion-observed",n and n.events==1,n and n.events)
        check_result(check,"native-resource-consumed",n and n.resource and not n.resource.valid)
    end
    for i in ipairs(planet_tiles) do if t==2200+i*16 then planet_case(i,check) end end
    if t==2400 then protections(check) end
    -- Chunk generation can legitimately consume that tick's admission quota.
    -- Submit asserted fixture intents on subsequent ticks, one per tick.
    local protection=r.protection_queue and r.protection_queue[t-2400]
    if protection then check_result(check,"protected-admitted-"..protection.id,call("enqueue",protection.surface.index,protection.p,"thermal")) end
    if t==6000 then
        local n=r.native
        if n then
            check_result(check,"native-depletion-scar",n.surface.get_tile(n.position).name=="grass-3",n.surface.get_tile(n.position).name)
            check_result(check,"native-mining-permanent",call("history",n.surface.index,math.floor(n.position.x),math.floor(n.position.y))==nil)
        end
        for name,entry in pairs(r.planets) do
            check_result(check,"actual-planet-transition-"..name,entry.surface.get_tile(entry.position).name==entry.target,entry.surface.get_tile(entry.position).name)
        end
        for _,spec in ipairs(r.protections) do
            check_result(check,"protection-"..spec.id,game.surfaces.nauvis.get_tile(spec.p).name==spec.expected,game.surfaces.nauvis.get_tile(spec.p).name)
        end
        check_result(check,"ungenerated-still-absent",not game.surfaces.nauvis.is_chunk_generated({math.floor(r.ungenerated.x/32),math.floor(r.ungenerated.y/32)}))
        if r.gaia_protected then local g=r.gaia_protected;check_result(check,"gaia-marker-protected",g.surface.get_tile(g.p).name=="ei-gaia-grass-1") end
        local f=r.planets.fulgora
        if f then
            local current=f.surface.daytime_parameters
            for _,key in ipairs{"dusk","evening","morning","dawn"} do check_result(check,"fulgora-boundary-"..key,current[key]==r.fulgora_day[key]) end
            -- Fulgora's existing independent module MAY change ticks_per_day;
            -- deliberately do not assert the clock is frozen across this run.
        end
    end
    if t==6500 then start_hazards(check) end
    local hazard=r.hazard_queue and r.hazard_queue[t-6500]
    if hazard then check_result(check,"hazard-admitted-"..hazard.id,call("enqueue",hazard.surface.index,hazard.p,hazard.cause,hazard.extra)) end
    if t==9000 then
        for _,spec in ipairs(r.hazards) do
            check_result(check,"hazard-result-"..spec.id,spec.entity and (spec.chest and spec.entity.valid or not spec.chest and not spec.entity.valid))
            check_result(check,"entity-cause-no-soil-scar-"..spec.id,game.surfaces.nauvis.get_tile(spec.p).name=="grass-1")
        end
        check_result(check,"contained-ignition",counter(game.surfaces.nauvis,"ignitions")==r.fire.before+1)
        local p={x=1408,y=1280};prepare(game.surfaces.nauvis,p,"grass-1",8)
        r.disabled_point=p
        call("enqueue",game.surfaces.nauvis.index,p,"thermal")
        override(game.surfaces.nauvis,"active",false,check)
    end
    if t==10100 then
        check_result(check,"disabled-queued-tile-untouched",game.surfaces.nauvis.get_tile(r.disabled_point).name=="grass-1")
        r.complete=true
    end
end
function model.complete() return root().complete==true end
return model

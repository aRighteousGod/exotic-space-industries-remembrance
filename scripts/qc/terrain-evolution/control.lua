local options=require("options")
local function call(name,...) return remote.call("ei-terrain-qc",name,...) end
local function check(name,pass,detail)
    local old=storage.results[name]
    storage.results[name]={pass=pass==true and (not old or old.pass),detail=detail}
end
local function finish()
    local all,count=true,0
    for _,r in pairs(storage.results) do count=count+1;all=all and r.pass end
    helpers.write_file("terrain-qc.json",helpers.table_to_json{all_pass=all,count=count,cases=storage.results},false)
end
local function patch(surface,x,y,name)
    local tiles={}
    for dx=-3,3 do for dy=-3,3 do tiles[#tiles+1]={name=name,position={x+dx,y+dy}} end end
    surface.set_tiles(tiles,false,false,false,true)
end
script.on_init(function() storage.results={};storage.start=game.tick end)
script.on_configuration_changed(function() storage.results={};storage.start=game.tick end)
script.on_event(defines.events.on_tick,function(event)
    local t=event.tick-storage.start
    local surface=game.surfaces.nauvis
    if t==1 then
        local cfg=call("defaults")
        check("default-lean",cfg.performance=="lean" and cfg.interval==16 and cfg.search_interval==32 and cfg.writes==4 and cfg.histories==4 and cfg.searches==1)
        check("default-restrained",cfg.intensity=="restrained")
        check("default-seasonal-daylight",cfg.seasonal_daylight==true)
        check("hazards-off",cfg.wildfire=="off" and not cfg.aging and not cfg.flood and not cfg.paving)
        local _,errors=call("resolve",{pollution_low=200,pollution_high=100})
        check("threshold-validation",#errors>0)
        _,errors=call("resolve",{interval=0,tree_stress="yes"})
        check("range-type-validation",#errors==2)
        local transitions=call("compile")
        check("gleba-corrected",transitions["highland-dark-rock"]=="midland-cracked-lichen-dark")
        check("gaia-native-chain",transitions["ei-gaia-grass-2"]=="ei-gaia-grass-1")
        local base={dusk=.25,evening=.45,morning=.55,dawn=.75}
        for _,tilt in ipairs({0,23.5,60}) do for _,lat in ipairs({-75,0,45,75}) do for _,phase in ipairs({0,.25,.5,.75,.99}) do
            local result=call("calculate",base,phase,tilt,lat)
            check("season-boundaries",result and result.dusk<result.evening and result.evening<result.morning and result.morning<result.dawn and result.morning-result.evening>=.019999 and result.dusk+1-result.dawn>=.019999)
            check("twilight-preserved",result and math.abs((result.evening-result.dusk)-.2)<1e-8 and math.abs((result.dawn-result.morning)-.2)<1e-8)
        end end end
        if options.disabled then
            check("startup-disabled-idle",not call("enablement"))
            check("startup-disabled-admission",not call("enqueue",surface.index,{x=0,y=0},"thermal"))
            return
        end
        storage.day_baseline=surface.daytime_parameters;storage.day_ticks=surface.ticks_per_day
        surface.freeze_daytime=false;surface.always_day=false
        for _,pair in ipairs({{"degradation",false},{"tree_stress",false},{"tree_regrowth",false},{"recovery",false},{"hazard_radius",1},{"protection_buffer",0},{"mining_radius",0},{"mining_patch_radius",1},{"mining_probability",1},{"clean_seconds",1},{"recovery_seconds",1}}) do
            check("override-"..pair[1],call("override",surface.index,pair[1],pair[2]))
        end
        local ok=call("override",surface.index,"performance","detailed")
        check("surface-global-budget-rejected",not ok)
        surface.request_to_generate_chunks({256,256},2);surface.force_generate_chunk_requests()
        for _,entity in pairs(surface.find_entities_filtered{area={{230,230},{320,300}}}) do if entity.valid and entity.type~="character" then entity.destroy() end end
        patch(surface,256,256,"grass-1");patch(surface,272,256,"grass-1")
        patch(surface,288,256,"grass-1");patch(surface,304,256,"water")
        surface.set_tiles({{name="stone-path",position={288,256}}},false,false,false,true)
        surface.create_entity{name="iron-chest",position={272.5,256.5},force="player"}
    end
    if t==100 and not options.disabled then
        for _,x in ipairs({256,272,288,304}) do check("admitted-"..x,call("enqueue",surface.index,{x=x,y=256},"thermal")) end
    end
    if not options.disabled then
        local status=call("snapshot",surface.index)
        local last=status.last_service
        if last then check("service-caps",last.candidates<=32 and last.writes<=4 and last.searches<=1 and last.histories<=4,last) end
        if t==900 then
            check("actual-natural-scar",surface.get_tile(256,256).name=="grass-3",surface.get_tile(256,256).name)
            check("scar-history",call("history",surface.index,256,256)~=nil)
            check("infrastructure-protected",surface.get_tile(272,256).name=="grass-1")
            check("paving-protected",surface.get_tile(288,256).name=="stone-path")
            check("water-protected",surface.get_tile(304,256).name=="water")
            check("rotation-unchanged",surface.ticks_per_day==storage.day_ticks)
            check("daylight-owned",call("calendar",surface.index).owns_daylight==true)
            local accepted=0
            for i=1,100 do if call("enqueue",surface.index,{x=1000+i*16,y=1000},"wake") then accepted=accepted+1 end end
            check("admission-cap",accepted<=16,accepted)
            surface.clear_pollution()
            call("override",surface.index,"recovery",true)
            surface.set_tiles({{name="concrete",position={256,257}}},false,false,false,true)
            check("external-write-invalidates",call("history",surface.index,256,257)==nil)
        end
        if t==2300 then
            check("exact-recovery",surface.get_tile(256,256).name=="grass-1",surface.get_tile(256,256).name)
            check("external-write-preserved",surface.get_tile(256,257).name=="concrete")
            local baseline=surface.daytime_parameters
            call("phase",surface.index,.25)
            for _,s in pairs(game.surfaces) do call("override",s.index,"active",false) end
            check("runtime-disable-idle",not call("enablement"))
            check("runtime-disable-admission",not call("enqueue",surface.index,{x=256,y=256},"thermal"))
        end
    end
    if t==options.ticks-1 then finish() end
end)

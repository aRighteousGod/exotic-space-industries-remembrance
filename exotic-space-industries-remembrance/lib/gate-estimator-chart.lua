-- blueprint: .codex/esir/blueprints/gate.md#contract
-- Private, static chart canvas. No entities, planetary anchors or periodic rendering.
local model = {}
model.surface_name="ei-gate-estimator-chart"
model.metrics={"energy","stress","cooldown","throughput","queue","power"}
local colors={{0.2,0.85,1},{1,0.65,0.2}}

function model.hide_surface()
    local surface=game.get_surface(model.surface_name)
    if surface then for _,force in pairs(game.forces) do force.set_surface_hidden(surface,true) end end
end

function model.surface()
    local surface=game.get_surface(model.surface_name)
    if not surface then
        surface=game.create_surface(model.surface_name,{width=64,height=64,
            autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false},
                tile={treat_missing_as_default=false},decorative={treat_missing_as_default=false}}})
        surface.freeze_daytime=true;surface.daytime=0;surface.show_clouds=false
    end
    model.hide_surface()
    return surface
end

function model.clear(viewer)
    for _,object in ipairs(viewer.renders or {}) do if object.valid then object.destroy() end end
    viewer.renders={}
end

local function series(bin,metric)
    if metric==1 then return {bin.last[1]},{bin.min[1]},{bin.max[1]} end
    if metric==2 then return {bin.last[2],bin.last[3]},{bin.min[2],bin.min[3]},{bin.max[2],bin.max[3]} end
    if metric==3 then return {bin.last[4],bin.last[5]},{bin.min[4],bin.min[5]},{bin.max[4],bin.max[5]} end
    if metric==4 then return {bin.rate,bin.offered} end
    if metric==5 then return {bin.last[6],bin.last[7]},{bin.min[6],bin.min[7]},{bin.max[6],bin.max[7]} end
    return {bin.transfer_w,bin.upkeep_w}
end

-- At most 240 bins per curve; range whiskers preserve spikes that a trend line hides.
function model.draw(player,viewer)
    model.clear(viewer)
    local result=viewer.results
    if not result or not viewer.gui then return end
    local surface=model.surface()
    local function line(a,b,color,dashed)
        viewer.renders[#viewer.renders+1]=rendering.draw_line{surface=surface,players={player.index},
            from=a,to=b,color=color,width=2,dash_length=dashed and 0.18 or 0,gap_length=dashed and 0.12 or 0}
    end
    for panel=1,2 do
        local metric=viewer.metrics[panel]
        local y=(panel-1)*20
        local maximum=1
        for _,job in ipairs(result) do for _,bin in ipairs(job.bins) do
            local values,_,high=series(bin,metric)
            for _,v in ipairs(high or values) do maximum=math.max(maximum,v) end
        end end
        if metric==1 then maximum=math.max(maximum,result[1].scenario.capacity/1e9) end
        if metric==2 then maximum=100 end
        maximum=maximum*1.05
        viewer.gui.axes[panel].caption={"gate-estimator.axis",string.format("%.3g",maximum),
            {"gate-estimator.unit-"..metric},result[1].scenario.horizon}
        viewer.renders[#viewer.renders+1]=rendering.draw_rectangle{surface=surface,players={player.index},
            left_top={-12,y-4},right_bottom={12,y+4},filled=true,color={0.035,0.04,0.05}}
        for i=0,4 do line({-10,y+3-i*1.5},{10,y+3-i*1.5},{0.25,0.28,0.32}) end
        line({-10,y-3},{-10,y+3},{0.7,0.7,0.7})
        local threshold=metric==1 and 100 or metric==2 and 75
        if threshold then local yy=y+3-threshold/maximum*6;line({-10,yy},{10,yy},{0.9,0.3,0.3},true) end
        for run,job in ipairs(result) do
            local previous={}
            for _,bin in ipairs(job.bins) do
                local values,low,high=series(bin,metric)
                local x=-10+20*bin.to/job.scenario.horizon
                for i,value in ipairs(values) do
                    local point={x,y+3-value/maximum*6}
                    if previous[i] then line(previous[i],point,colors[i],run==2) end
                    if low and high and high[i]>low[i] then
                        line({x,y+3-low[i]/maximum*6},{x,y+3-high[i]/maximum*6},colors[i],run==2)
                    end
                    previous[i]=point
                end
            end
        end
        local sample=math.min(#result[1].bins,math.max(1,viewer.sample or 1))
        local bin=result[1].bins[sample]
        if bin then
            local x=-10+20*bin.to/result[1].scenario.horizon
            line({x,y-3},{x,y+3},{1,1,1},true)
            local values,low,high=series(bin,metric)
            local texts={}
            for i,value in ipairs(values) do
                texts[#texts+1]=string.format("%.3g [%.3g–%.3g]",value,(low or values)[i],(high or values)[i])
            end
            viewer.gui.samples[panel].caption={"gate-estimator.sample",string.format("%.1f",bin.from),
                string.format("%.1f",bin.to),table.concat(texts," / ")}
        end
    end
end

return model

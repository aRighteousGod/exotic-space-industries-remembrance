local options=require("options")
local profiles={{id="four",count=4,response=.02,overlap=0},{id="saucer",saucer=true,count=4}}
for _,response in ipairs(options.responsiveness) do
    for _,overlap in ipairs(options.overlaps or {0,.5,.75}) do
        for _,scalar in ipairs(options.force_scalars or {false}) do
            for _,selection in ipairs(options.selection_scales or {1}) do
                for _,friction in ipairs(options.frictions or {false}) do
                    local suffix=scalar and "-f"..math.floor(scalar*100000+.5) or ""
                    if selection~=1 then suffix=suffix.."-s"..math.floor(selection*100000+.5) end
                    if friction then suffix=suffix.."-v"..math.floor(friction*1000+.5) end
                    profiles[#profiles+1]={id="ten-r"..math.floor(response*100000+.5).."-o"..math.floor(overlap*100)..suffix,
                        count=10,response=response,overlap=overlap,force_scalar=scalar or nil,selection_scale=selection,friction=friction or nil}
                end
            end
        end
    end
end
return profiles

local config=require("test-config")
-- Factorio only applies forced_value to hidden boolean settings. This is a
-- fixture-only override; the shipped startup control remains visible.
data.raw["bool-setting"]["ei-spider-range-aware-cycling"].hidden=true
data.raw["bool-setting"]["ei-spider-range-aware-cycling"].forced_value=config.smart~=false
data.raw["bool-setting"]["ei-spider-range-aware-cycling"].default_value=config.smart~=false
local count=0
for _,kind in ipairs({"bool-setting","string-setting"}) do
    for name,setting in pairs(data.raw[kind]) do
        if name:find("assault-spidertron-",1,true)==1 then
            if name=="assault-spidertron-enable-arachnophobia-mode" then
                assert(not setting.hidden and setting.forced_value==nil and #setting.allowed_values==2,"Arachnophobia must remain a player choice")
                if config.arachnophobia then setting.default_value="active";setting.allowed_values={"active"} end
            else
                assert(setting.hidden and setting.forced_value~=nil,"Unlocked assault setting: "..name)
                count=count+1
            end
        end
    end
end
assert(count==16,"Unexpected assault setting inventory")
log("SPIDER_SETTINGS_QC PASS locks="..count.." arachnophobia="..tostring(config.arachnophobia))

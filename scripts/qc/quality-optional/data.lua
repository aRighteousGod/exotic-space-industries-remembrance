local case=require("case")
-- Emulate an upstream mod's data-stage adjustment before ESIR's update pass.
if case.upstream_sentinel and data.raw.module["quality-module"] then
    data.raw.module["quality-module"].effect.quality=0.01234
    data.raw.module["quality-module"].effect.pollution=0.123
end

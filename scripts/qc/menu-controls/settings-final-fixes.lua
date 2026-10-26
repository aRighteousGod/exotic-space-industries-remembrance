local options=require("options")
for _,name in ipairs{"ei-admin-tools-enabled","ei-terrain-evolution-enabled"} do
    data.raw["bool-setting"][name].default_value=not options.disabled
end

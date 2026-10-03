local function clone(kind,source,name)
    local p=table.deepcopy(data.raw[kind][source]);p.name=name;data:extend{p}
end
for _,family in ipairs{'oil','gas','exotic','lava','thermal','chemical','cryo','data'} do
    clone('fire','fire-flame','ei-'..family..'-fire-flame')
    clone('fire','fire-flame','ei-'..family..'-platform-fire-flame')
    clone('trivial-smoke','smoke-fast','ei-'..family..'-rupture-smoke')
end
local probe=table.deepcopy(data.raw.container['wooden-chest'])
probe.name='admin-world-dense-target'
probe.flags={'placeable-off-grid'}
probe.collision_box={{-.001,-.001},{.001,.001}}
probe.collision_mask={layers={}}
probe.minable=nil
data:extend{probe}

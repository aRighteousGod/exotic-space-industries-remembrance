-- Private one-second lab technologies exercise native item/tool consumption.
assert(data.raw.tool['ei-dark-age-tech'],'ESIR science must remain a tool')
assert(data.raw.item['space-science-pack'],'2.1 native science must be an item')
for index,ingredients in ipairs{{{'ei-dark-age-tech',1}},{{'space-science-pack',1}},
    {{'ei-dark-age-tech',1},{'space-science-pack',1}}} do
    data:extend{{type='technology',name='esir-qc-science-'..index,
        icon='__base__/graphics/technology/automation.png',icon_size=256,
        unit={count=3,time=1,ingredients=ingredients},effects={}}}
end

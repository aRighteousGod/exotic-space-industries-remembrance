local drills={}
for _,name in ipairs{"ei-advanced-electric-mining-drill","ei-superior-electric-mining-drill"} do
    local prototype=assert(data.raw["mining-drill"][name])
    assert(#prototype.circuit_connector==4,"Expected authored four-direction connectors: "..name)
    for index,connector in ipairs(prototype.circuit_connector) do
        assert(connector.sprites.render_layer=="object","Connector render layer")
        assert(connector.sprites.secondary_draw_order==(index==1 and 14 or 48),"Connector draw order")
    end
    drills[#drills+1]={name=name,output=prototype.vector_to_place_result}
end
local uranium=assert(data.raw.resource["uranium-ore"])
assert(uranium.minable.required_fluid,"Wet native resource must require fluid")
data:extend{{type="mod-data",name="esir-upgrade-drill-qc",data_type="esir.upgrade-drill-qc",data={
    drills=drills,wet_resource="uranium-ore",wet_fluid=uranium.minable.required_fluid}}}

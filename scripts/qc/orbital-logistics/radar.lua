-- Player-built native radar examples. No ESIR radio reader or relay participates.
local radar = {}
local function create(surface, name, position, force)
  return assert(surface.create_entity{name=name,position=position,force=force,raise_built=true},name)
end
local function connect(a,b,colour)
  local id=colour=="green" and defines.wire_connector_id.circuit_green or defines.wire_connector_id.circuit_red
  assert(a.get_wire_connector(id,true).connect_to(b.get_wire_connector(id,true),false),"wire connection")
end
local function constant(surface,force,position,signal,count)
  local entity=create(surface,"constant-combinator",position,force)
  local control=entity.get_or_create_control_behavior()
  local section=control.get_section(1) or control.add_section()
  section.filters={{value=signal,min=count}}
  return entity
end
local function receiver(surface,force,position,channel)
  local entity=create(surface,"radar",position,force)
  local control=entity.get_or_create_control_behavior()
  control.mode=defines.control_behavior.radar.mode.universe
  control.universe_channel={type="virtual",name=channel}
  return entity
end
local function signal(entity,name,colour)
  local id=colour=="green" and defines.wire_connector_id.circuit_green or defines.wire_connector_id.circuit_red
  local network=entity.get_circuit_network(id)
  return network and network.get_signal{type=name:find("signal-",1,true) and "virtual" or "item",name=name,quality="normal"} or 0
end
function radar.build(s,tick)
  local force=s.entities.silo.force
  local r={started=tick,step=0,tx={},receivers={},hubs={s.platforms[2].hub,s.platforms[3].hub},platforms={s.platforms[2],s.platforms[3]}}
  for index,hub in ipairs(r.hubs) do
    for _, section in ipairs(hub.get_requester_point().sections) do if section.is_manual then section.active=false end end
    hub.get_inventory(defines.inventory.hub_main).clear()
    hub.get_inventory(defines.inventory.hub_main).insert{name="iron-plate",count=index==1 and 11 or 17}
    local control=hub.get_or_create_control_behavior()
    control.read_contents=true
    control.set_requests=true
    control.input_networks={red=false,green=true}
    control.output_networks={red=true,green=false}
    local tx=receiver(hub.surface,force,{6,2},index==1 and "signal-A" or "signal-B")
    r.tx[index]=tx
    connect(hub,tx,"red")
    local presence=constant(hub.surface,force,{6,6},{type="virtual",name="signal-L",quality="normal"},1)
    connect(presence,tx,"red")
    local request=constant(hub.surface,force,{-6,2},{type="item",name="iron-plate",quality="normal"},55)
    connect(request,hub,"green")
  end
  r.receivers[1]=receiver(s.entities.silo.surface,force,{500,540},"signal-A")
  r.receivers[2]=receiver(s.entities.silo.surface,force,{508,540},"signal-B")
  -- Native network handles require physical circuit endpoints at the receivers.
  for index,rx in ipairs(r.receivers) do
    connect(rx,constant(rx.surface,force,{500+(index-1)*8,544},{type="virtual",name="signal-Z"},0),"red")
    connect(rx,constant(rx.surface,force,{500+(index-1)*8,548},{type="virtual",name="signal-Z"},0),"green")
  end
  local foreign=game.forces["orbital-radar-other"] or game.create_force("orbital-radar-other")
  create(s.entities.silo.surface,"esir-orbital-qc-pole",{550,540},foreign)
  create(s.entities.silo.surface,"esir-orbital-qc-source",{550,540},foreign)
  r.foreign=receiver(s.entities.silo.surface,foreign,{550,540},"signal-A")
  connect(r.foreign,constant(r.foreign.surface,foreign,{554,544},{type="virtual",name="signal-Z"},0),"red")
  s.radar=r
end
function radar.step(s,tick,check)
  local r=s.radar
  if not r then radar.build(s,tick);return false end
  if tick-r.started<60 then return false end
  local rx=r.receivers[1]
  if r.step==0 then
    check("radar-dedicated-platform-channel",signal(rx,"iron-plate")==11 and signal(r.receivers[2],"iron-plate")==17,
      signal(rx,"iron-plate")..":"..signal(r.receivers[2],"iron-plate"))
    check("radar-presence-signal",signal(rx,"signal-L")==1)
    check("radar-force-isolation",signal(r.foreign,"iron-plate")==0 and signal(r.foreign,"signal-L")==0)
    check("radar-red-green-isolation",signal(rx,"iron-plate","green")==0)
    local count=0
    for _, filter in ipairs(r.hubs[1].get_requester_point().filters) do if filter.name=="iron-plate" then count=count+filter.count end end
    check("hub-output-not-fed-back-into-set-requests",count==55,count)
    r.tx[2].get_control_behavior().universe_channel={type="virtual",name="signal-A"}
  elseif r.step==1 then
    check("radar-shared-aggregate-inventory",signal(rx,"iron-plate")==28,signal(rx,"iron-plate"))
    check("radar-shared-transmitter-count",signal(rx,"signal-L")==2)
    r.hubs[1].get_inventory(defines.inventory.hub_main).clear()
  elseif r.step==2 then
    check("radar-empty-stock-keeps-presence",signal(rx,"iron-plate")==17 and signal(rx,"signal-L")==2)
    for _, source in pairs(r.hubs[1].surface.find_entities_filtered{name="esir-orbital-qc-source"}) do source.destroy() end
    r.tx[1].energy=0
  elseif r.step==3 then
    check("radar-power-loss-removes-link",signal(rx,"iron-plate")==17 and signal(rx,"signal-L")==1,
      signal(rx,"iron-plate")..":"..signal(rx,"signal-L"))
    create(r.hubs[1].surface,"esir-orbital-qc-source",{2,2},r.hubs[1].force)
  elseif r.step==4 then
    check("radar-reconnection-restores-link",signal(rx,"signal-L")==2)
    r.platforms[1].space_location="gleba"
  elseif r.step==5 then
    check("radar-channel-survives-location-change",signal(rx,"signal-L")==2 and signal(rx,"iron-plate")==17)
    r.tx[2].get_control_behavior().universe_channel={type="virtual",name="signal-B"}
  else
    check("radar-empty-dedicated-channel-presence",signal(rx,"iron-plate")==0 and signal(rx,"signal-L")==1)
    return true
  end
  r.step=r.step+1;r.started=tick
  return false
end
return radar

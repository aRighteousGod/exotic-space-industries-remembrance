-- Run the real fluid owner with mutable native boundaries; no shipping QC exports.
package.path = 'exotic-space-industries-remembrance/?.lua;' .. package.path
local checks, failures = 0, 0
local function check(ok, label)
    checks = checks + 1
    if not ok then failures = failures + 1; print('FAIL ' .. label) end
end
local incidents, vents, floating = {}, {}, 0
package.loaded['lib/data'] = {computing_types={'ei-computing-power'}}
package.loaded['lib/lib'] = {
    get_entity_unit_number=function(e) return e and e.valid and e.unit_number end,
    crystal_echo_floating=function() floating=floating+1 end,
}
package.loaded['lib/alerts'] = {record_incident=function(channel, id, context, tick)
    incidents[#incidents+1]={id=id,context=context,tick=tick}
end}
package.loaded['lib/fluid-safety-config'] = {is_ignored_entity=function()return false end}
package.loaded['scripts/control/fluid-rupture-effects'] = {
    queue_vent=function(e,spec) vents[#vents+1]={entity=e,spec=spec};return true end,
    queue_effect=function()return true end,
}
local source_path = arg[1] or 'exotic-space-industries-remembrance/scripts/control/fluid-safety.lua'
local file=assert(io.open(source_path));local source=file:read('*a');file:close()
source=assert(source:gsub('return model%s*$',
    'model.qc={audit=audit_segment,unsegmented=audit_unsegmented_entry,apply=apply_breach_context,context=resolve_breach_context};return model'))
local model=assert(load(source,'@'..source_path))()
local function setup(contents)
    incidents,vents,floating={},{},0
    storage={ei={}};game={tick=1000};settings={global={}}
    local networks={[1]=contents,[2]={['ei-liquid-nitrogen']=50}}
    local function pipe(unit,segment)
        local e={valid=true,unit_number=unit,name='pipe',type='pipe',segment=segment,
            force={name='player'},position={x=unit,y=0},gps_tag='[gps='..unit..',0]',
            surface={valid=true,create_entity=function()floating=floating+1;return{valid=true}end}}
        e.fluidbox={[1]={},get_fluid_segment_id=function()return e.segment end,
            get_fluid_segment_contents=function()return networks[e.segment] end,
            get_capacity=function()return 100 end,get_connections=function()return{}end,
            flush=function(_,name)
                local amount=networks[e.segment][name] or 0
                networks[e.segment][name]=nil
                return {[name]=amount}
            end}
        e.get_fluid_contents=function()return networks[e.segment] end
        e.clear_fluid_inside=function()networks[e.segment]={}end
        e.insert_fluid=function(fluid)
            local c=networks[e.segment];c[fluid.name]=(c[fluid.name] or 0)+fluid.amount
            return fluid.amount
        end
        e.destroy=function()e.valid=false;return true end
        return e
    end
    local moved,ordinary=pipe(1,1),pipe(2,1)
    model.on_fluid_entity_registered(moved);model.on_fluid_entity_registered(ordinary)
    local runtime=model.ensure_fluid_runtime()
    runtime.segments[1].representative_unit=moved.unit_number
    return runtime,moved,ordinary,networks
end
for _,fluid in ipairs{'empty','water','crude-oil','ei-nitrogen-gas','ei-oxygen-gas'} do
    local contents=fluid=='empty' and {} or {[fluid]=75}
    local runtime,moved,ordinary,networks=setup(contents)
    moved.segment=2 -- Engine topology changes before bounded cache repair reaches it.
    model.qc.audit(runtime,1,1000)
    check(#incidents==0,fluid..': stale representative cannot report another network fluid')
    check(#vents==0 and floating==0,fluid..': no phantom vent or feedback')
    check(ordinary.valid and (fluid=='empty' or networks[1][fluid]==75),fluid..': ordinary network unchanged')
    check(networks[2]['ei-liquid-nitrogen']==50,fluid..': detached cryo network unchanged')
    model.touch_entity(moved)
    check(runtime.entries_by_unit[moved.unit_number].last_segment_id==2
        and runtime.segments[2].members[moved.unit_number],fluid..': subsequent touch repairs moved membership')
    model.qc.audit(runtime,2,1400)
    check(networks[2]['ei-nitrogen-gas']==50 and #incidents==1,fluid..': repaired network still processes genuine boiloff')
end
for _,fluid in ipairs{'empty','water','ei-nitrogen-gas','ei-oxygen-gas'} do
    local runtime,_,ordinary,networks=setup(fluid=='empty' and {} or {[fluid]=75})
    local context=model.qc.context(1,runtime.segments[1],runtime.entries_by_unit[ordinary.unit_number],
        'cryo_nitrogen','ei-liquid-nitrogen',{amount=50,breach_kind='phase-shift',drain_mode='segment',
        replacement_fluid='ei-nitrogen-gas',segment_preserve_excess=false})
    local applied=model.qc.apply(runtime,1,runtime.segments[1],context,1000)
    check(not applied and #incidents==0 and #vents==0 and floating==0,fluid..': stale phase shift requires liquid removal')
    check(fluid=='empty' or networks[1][fluid]==75,fluid..': rejected phase shift preserves contents')
end
for _,fluid in ipairs{'ei-liquid-nitrogen','ei-liquid-oxygen'} do
    local gas=fluid=='ei-liquid-nitrogen' and 'ei-nitrogen-gas' or 'ei-oxygen-gas'
    local runtime,_,ordinary,networks=setup({[fluid]=50})
    model.qc.audit(runtime,1,1000)
    check(ordinary.valid and networks[1][fluid]==nil and networks[1][gas]==50,fluid..': genuine boiloff converts liquid')
    check(#incidents==1 and incidents[1].id=='fluid-phase-shift' and incidents[1].tick==1000,fluid..': genuine boiloff reported')
    model.qc.audit(runtime,1,1400)
    check(#incidents==1 and #vents==1,fluid..': converted gas does not report again')
    local fresh,_,unsegmented,contents=setup({[fluid]=50})
    model.qc.unsegmented(fresh,fresh.entries_by_unit[unsegmented.unit_number],1000)
    check(contents[1][gas]==50 and not contents[1][fluid],fluid..': unsegmented conversion retained')
    check(#incidents==1 and #vents==1,fluid..': unsegmented real boiloff reported')
end
do
    local runtime,data,ordinary,networks=setup({['ei-liquid-nitrogen']=150})
    data.name='ei-data-pipe';runtime.entries_by_unit[data.unit_number].class='data'
    model.qc.audit(runtime,1,1000)
    check(ordinary.valid and not data.valid,'genuine conversion still destroys the incompatible data carrier')
    check(networks[1]['ei-nitrogen-gas']==50,'destructive path drains converted gas and preserves excess')
    check(#incidents==2 and incidents[1].id=='fluid-phase-shift' and incidents[2].id=='fluid-cryo',
        'boiloff and destructive cryo breach remain distinct incidents')
end
print(('FLUID_SAFETY %d checks, %d failures'):format(checks,failures))
assert(failures==0,'fluid safety regression failed')

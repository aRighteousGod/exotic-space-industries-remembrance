"""Reuse established assertions exclusively inside managed private source copies."""
import copy
import importlib.util
import json
import re
from pathlib import Path


def read(path): return Path(path).read_text(encoding='utf-8-sig')


def write(path, text):
    path=Path(path)
    if path.exists():
        assert not path.is_symlink() and not path.is_junction(), path
        assert path.stat().st_nlink==1, f'Refuse shared-file mutation: {path}'
    path.write_text(text,encoding='utf-8')


def replace(text, old, new, count=1):
    assert text.count(old)==count, f'Fixture/source shape changed: {old[:100]!r}'
    return text.replace(old,new,count)


def append_main(main,body):
    path=main/'control.lua';write(path,read(path)+'\ndo\n'+body+'\nend\n')


def capture_init(body):
    """Expose an old fixture's init callback to the shared lifecycle owner."""
    return 'local native_init\nlocal function native_register_init(callback) native_init=callback end\n'+replace(body,'script.on_init(', 'native_register_init(')


def build_dispatch(repo,main,helper,profile):
    path=main/'scripts/control/combustion-turbine.lua'
    signature='local function create_turbine_shell(surface, name, position, force, direction, quality)\n'
    write(path,replace(read(path),signature,signature+'    if storage.ei.build_dispatch_fail_turbine then return nil end\n'))
    for filename,signature,flag in (
        ('crystal-accumulator','    local new_entity = surface.create_entity{','crystal'),
        ('steam-train','\t\tlocal locomotive = surface.create_entity({','steam'),
        ('teslas-legacy','    local replacement = surface.create_entity({','tesla')):
        path=main/f'scripts/control/{filename}.lua';text=read(path);assert signature in text
        write(path,text.replace(signature,signature.replace('= surface.create_entity',f'= not storage.ei.build_dispatch_fail_{flag} and surface.create_entity'),1))
    body=read(repo/'scripts/qc/build-dispatch/suite.lua')
    body=replace(body,'        if game.is_multiplayer() then game.server_save("build-dispatch-reload")\n        else game.auto_save("build-dispatch-reload") end','        -- Common driver owns checkpoint production.')
    marker='    log("BUILD_DISPATCH "..qc_phase.." passed="..tostring(report.passed))'
    body=replace(body,marker,marker+'\n    native_result={complete=true,checks=report.checks}')
    append_main(main,'''local qc_phase=require("__esir-qc-native-tests__.support").phase()
local native_result
remote.add_interface("esir-native-tests",{poll=function() return native_result or {complete=false} end})
'''+body)
    return {'requires_checkpoint':True,'evidence':'Native entities/handlers and explicit injected boundary probes'}


def research_bootstrap(repo,main,helper,profile):
    source=repo/'scripts/qc/factorio-2.1/research-bootstrap'
    lab=profile['no_triggers'] and not profile['flatten']
    for name in ('capture.lua','settings-updates.lua','data.lua','data-updates.lua','data-final-fixes.lua'):
        write(helper/name,read(source/name))
    write(helper/'test-config.lua','return {no_triggers='+str(profile['no_triggers']).lower()+',flatten='+str(profile['flatten']).lower()+',runtime="'+('lab' if lab else 'none')+'"}\n')
    body=read(source/'control.lua')
    body=replace(body,'if config.runtime == "reload" and loaded then','if native_support.phase() == "reload" and loaded then')
    body=replace(body,'    if game.is_multiplayer() then game.server_save("research-bootstrap-fixed") end','    -- Common driver owns checkpoint production.')
    initial='    helpers.write_file("research-bootstrap.json", helpers.table_to_json(prototypes.mod_data["esir-qc-research-bootstrap"].data), false)'
    body=replace(body,initial,initial+'''
    if native_config.runtime ~= "lab" then
        native_checks[#native_checks+1]={name="data-snapshot-captured",passed=true}
        native_result={complete=true,checks=native_checks}
    end''')
    tail='            actual=actual, expected=storage.bootstrap.accepted, engine=script.active_mods.base}, false)\n        return'
    body=replace(body,tail,tail.replace('        return','''        native_checks[#native_checks+1]={name="reload-snapshot-captured",passed=true}
        native_result={complete=true,checks=native_checks}
        return'''))
    marker='    log("RESEARCH BOOTSTRAP NATIVE PASSED")'
    body=replace(body,marker,marker+'\n    native_result={complete=true,checks=native_checks}')
    prefix='''local native_support=require("support")
local native_config=require("test-config")
local native_checks,native_result={},nil
local original_assert=assert
local function assert(value,message,...)
 native_checks[#native_checks+1]={name="assert-"..tostring(#native_checks+1),passed=not not value,detail=message and tostring(message)}
 return original_assert(value,message,...)
end
'''
    write(helper/'native-suite.lua',capture_init(prefix+body)+'\nreturn {init=native_init,poll=function() return native_result or {complete=false} end}\n')
    return {'requires_checkpoint':lab,'postcheck':'research-bootstrap','profile':{k:profile[k] for k in ('no_triggers','flatten')},'native_lab':lab}


MIRRORING_TICK='''script.on_load(function() native_loaded=true end)
script.on_event(defines.events.on_tick,function(event)
 if native_result then return end
 if native_support.phase()=="reload" then
  check(native_loaded,"Actual save loader invoked on_load")
  check(storage.native_completed==true,"Candidate completed before checkpoint")
  for _,record in ipairs(storage.persisted) do
   check(record.entity.valid and same(record.state,snapshot(record.entity)),record.entity.name..": saved state")
   storage.report.counts.reload=storage.report.counts.reload+1
  end
  for _,record in ipairs(storage.connected) do
   check(record.entity.valid and record.pipe.valid and same(record.state.fluids,snapshot(record.entity).fluids) and same(record.pipe_state,record.pipe.get_fluid(1)),"Connected fluid state survives reload")
  end
  write_receipt("reload");native_result={complete=true,checks=native_checks};return
 end
 local elapsed=event.tick-storage.native_started
 if storage.transport then transport.tick(elapsed) end
 if storage.heat then heat.tick(elapsed) end
 if storage.furnaces then furnaces.tick(elapsed,snapshot,same) end
 if elapsed==600 then
  for _,record in ipairs(storage.connected) do
   check(same(record.state.fluids,snapshot(record.entity).fluids) and same(record.pipe_state,record.pipe.get_fluid(1)),record.entity.name..": incompatible fluids remain separate")
  end
  storage.report.counts.connected_persistence=#storage.connected
 end
 if elapsed<1800 then return end
 for name,count in pairs{transport=32,heat=16,furnaces=24} do
  local report=storage.native_reports[name]
  check(report~=nil,name..": report produced");check(report and report.passed,name..": native assertions")
  check(report and #report.cases==count,name..": complete inventory")
 end
 check(#storage.report.failures==0,"Persisted initialization assertions passed")
 storage.native_completed=true;write_receipt("reload");native_result={complete=true,checks=native_checks}
end)
'''


def mirroring(repo,main,helper,profile):
    source=repo/'scripts/qc/mirroring';quality=profile['quality']=='enabled';tag='candidate-quality-'+profile['quality']
    for name in ('cases.lua','data-final-fixes.lua'):write(helper/name,read(source/name))
    write(helper/'test-config.lua','return {mode="candidate",tag='+json.dumps(tag)+',visual=false}\n')
    for name in ('transport','heat','furnaces'):
        body=read(source/(name+'.lua'))
        marker='    helpers.write_file("mirroring/" .. config.tag .. "-'+name+'.json", helpers.table_to_json(report), false)'
        write(helper/(name+'.lua'),replace(body,marker,'    storage.native_reports["'+name+'"] = report\n'+marker))
    body=read(source/'control.lua');signature='local function check(condition, message)\n'
    body=replace(body,signature,signature+'    native_checks[#native_checks+1]={name="assert-"..tostring(#native_checks+1),passed=not not condition,detail=message}\n')
    body=replace(body,'script.on_init(function()\n','script.on_init(function()\n    storage.native_started=game.tick\n    storage.native_reports={}\n')
    marker='script.on_event(defines.events.on_tick, function(event)\n';assert body.count(marker)==1
    body=body[:body.index(marker)]+MIRRORING_TICK
    write(helper/'native-suite.lua',capture_init('local native_support=require("support")\nlocal native_checks,native_result,native_loaded={},nil,false\n'+body)+'\nreturn {init=native_init,poll=function() return native_result or {complete=false} end}\n')
    return {'requires_checkpoint':True,'postcheck':'mirroring','tag':tag,'quality':quality}


def stage(repo,main,helper,suite_id,profile):
    assert main.resolve()!=(repo/'exotic-space-industries-remembrance').resolve()
    assert not main.is_junction() and not helper.is_junction()
    handlers={'build-dispatch':build_dispatch,'research-bootstrap':research_bootstrap,'mirroring':mirroring}
    if suite_id not in handlers:
        from runtime_adapters import stage_runtime
        return stage_runtime(repo,main,helper,suite_id,profile)
    return handlers[suite_id](repo,main,helper,profile)


def postcheck(repo,output,metadata,phase):
    if metadata.get('postcheck') == 'gaia-resources':
        import gaia_resources
        return gaia_resources.postcheck(output, metadata, phase)
    checks=[]
    def check(name,value):
        assert value,name
        checks.append({'name':name,'passed':True})
    def result(name):return json.loads((output/name).read_text(encoding='utf-8-sig'))
    if metadata.get('postcheck')=='research-bootstrap':
        if phase=='candidate':
            path=repo/'scripts/qc/factorio-2.1/research-bootstrap/check.py'
            spec=importlib.util.spec_from_file_location('esir_bootstrap_check',path);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
            data,report=module.check(output/'research-bootstrap.json')
            check('existing-bootstrap-semantic-checker',report['passed'])
            check('actual-startup-settings',data['settings']==metadata['profile'])
            if not metadata['native_lab']:return checks
            native=result('research-bootstrap-native.json')
            check('native-lab-completion',native['passed'] and native['completion']['by_script'] is False);state=native['accepted']
        else:
            report=result('research-bootstrap-reload.json');check('reload-exact-state',report['actual']==report['expected']);state=report['actual']
        check('research-progress',state['progress']==0.375)
        check('research-queue',state['queue']==['ei-acid-neutralisation-t2'])
        check('science-consumption',len(state['inventory'])==4 and set(state['inventory'].values())=={30})
        check('metallurgic-unlock',state['metallurgic_recipe_enabled'] is True)
    elif metadata.get('postcheck')=='mirroring':
        tag=metadata['tag'];report=result(f'mirroring/{tag}-reload.json')
        check('native-mirroring',report['passed'] is True);check('quality-selection',report['quality']==metadata['quality'])
        if phase=='reload':
            check('persisted-machine-count',report['counts']['reload']==18);return checks
        final=result(f'mirroring/{tag}-final.json')
        check('final-quality-profile',final['quality']==metadata['quality'])
        for name in re.findall(r'"([^"]+)"',read(repo/'scripts/qc/mirroring/cases.lua')):
            check('final-opt-in-'+name,final['entities'][name].get('use_mirroring') is True)
        pump=final['entities']['ei-steam-oil-pumpjack']
        check('final-pumpjack-mirrored-graphics',pump['graphics_set_flipped']==pump['graphics_set'])
        check('final-pumpjack-native-inheritance',pump['use_mirroring'] is True and pump['migrate_horizontal_mirroring'] is True)
        for suffix,count in (('transport',32),('heat',16),('furnaces',24)):
            report=result(f'mirroring/{tag}-{suffix}.json');check(suffix+'-passed',report['passed'] is True);check(suffix+'-inventory',len(report['cases'])==count)
            if suffix=='transport':check('native-crane-upgrades',sum(r['upgraded'] for r in report['cases'])==8)
            if suffix=='furnaces':
                for i,row in enumerate(report['cases']):
                    check(f'furnace-{i}-native-recipe',bool(row['success'] and row['recipe']))
                    expected=copy.deepcopy(row['before']['ports'])
                    for ports in expected:
                        for port in ports:
                            for key in (('x','tx') if row['horizontal'] else ('y','ty')):port[key]=-port[key]
                    check(f'furnace-{i}-indexed-reflection',expected==row['after']['ports'])
                    check(f'furnace-{i}-restored-ports',row['before']['ports']==row['restored']['ports'])
    return checks

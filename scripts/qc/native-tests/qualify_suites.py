"""Explicit private regression injection; never part of normal qc-full.

Every child must FAIL for its named defect. A staging/input/timeout failure is
not qualification. Shipping sources and historical receipts are untouched.
"""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

import adapters
import catalogue
import runner


def inject(main,helper,suite,gaia_defect='missing-resource'):
    if suite == 'gaia-resources':
        path = main / 'control.lua'
        if gaia_defect == 'legacy-generation':
            adapters.write(path, adapters.replace(adapters.read(path),
                'local map_settings = mapgen.get_map_gen_settings()',
                'local map_settings = mapgen.get_map_gen_settings({seed=seed})'))
            return 'select-legacy-gaia-generation'
        marker = '        surface = game.create_surface("esir-qc-gaia-runtime", map_settings)'
        replacement = '        map_settings.autoplace_controls["ei-gaia-relic-debris"] = {frequency=0,size=0,richness=0}\n' + marker
        adapters.write(path, adapters.replace(adapters.read(path), marker, replacement))
        return 'disable-required-gaia-relic-resource'
    changes={
        'build-dispatch':('control.lua','em_trains.on_built_entity(entity, current_tick)','em_trains.on_built_entity(entity)', 'drop-build-tick'),
        'scheduler-event-tick':('lib/runtime-scheduler.lua','        return current_tick','        return 999999', 'ignore-supplied-clock'),
        'research-events':('control.lua','    ei_anisetron.on_scripted_research_burst(force, current_tick)','    -- qualification: receiver deliberately omitted', 'omit-scripted-receiver'),
        'research-bootstrap':('scripts/data-updates/vanilla-updates/planets/vulcanus.lua','table.deepcopy(ei_data.science["computer-age"])','ei_data.science["computer-age"]', 'mutate-shared-science-template'),
        'induction-circuit':('scripts/control/induction-matrix.lua','result[output.key] = {enabled = false,','result[output.key] = {enabled = true,', 'enable-default-circuit-output'),
        'alert-preferences':('lib/alerts.lua','    if not setting or setting.value ~= true then return false end','    -- qualification: personal Off deliberately ignored', 'ignore-personal-off'),
    }
    if suite=='mirroring':
        path=main/'data-final-fixes.lua'
        adapters.write(path,adapters.read(path)+'\ndata.raw["assembling-machine"]["ei-advanced-chem-plant"].use_mirroring=false\n')
        return 'disable-approved-mirroring'
    relative,old,new,name=changes[suite]
    path=main/relative;adapters.write(path,adapters.replace(adapters.read(path),old,new))
    return name


def compact_evidence(result):
    """Read the closed receipt, never loose remnants or unverified ZIP members."""
    evidence=Path(result['evidence'])
    index=catalogue.read_json(evidence/'evidence-index.json')
    if (index['run_id']!=result['run_id'] or index['workflow']!='qc-test' or index['status']!='failed'):
        raise ValueError('Qualification evidence identity mismatch')
    archive_path=evidence/'evidence.zip'
    if hashlib.sha256(archive_path.read_bytes()).hexdigest()!=index['archive_sha256']:
        raise ValueError('Qualification archive hash mismatch')
    with zipfile.ZipFile(archive_path) as archive:
        def entry(name,optional=False):
            rows=[r for r in index['entries'] if r['name']==name]
            members=[r for r in archive.infolist() if r.filename==name]
            if optional and not rows and not members:return None
            if len(rows)!=1 or len(members)!=1:raise ValueError('Missing or duplicate evidence: '+name)
            data=archive.read(members[0]);row=rows[0]
            if len(data)!=row['bytes'] or hashlib.sha256(data).hexdigest()!=row['sha256']:
                raise ValueError('Qualification entry hash mismatch: '+name)
            return data.decode('utf-8-sig')
        encoded=entry('reports/candidate.json',optional=True)
        report=json.loads(encoded) if encoded is not None else {}
        if not isinstance(report,dict) or not isinstance(report.get('checks',[]),list) or any(not isinstance(c,dict) for c in report.get('checks',[])):
            raise ValueError('Malformed qualification report')
        return report,entry('reports/candidate.log')


def detected(result):
    if result['overall_status']!='failed' or any(result.get(k) for k in ('housekeeping_error','stage','evidence_error','final_receipt_error')): return False
    if result.get('housekeeping',{}).get('status')!='failed' or result['housekeeping'].get('cleanup_status')!='compacted': return False
    if 'injected_defect' not in result: return False
    phases=[p for p in result.get('phases',[]) if p['phase']=='candidate']
    if len(phases)!=1 or phases[0]['passed']: return False
    phase=phases[0];process=phase['process'];suite=result['suite']
    if process['timed_out']: return False
    log_failure=suite in ('scheduler-event-tick','research-events','induction-circuit')
    allowed={'engine-exit','failed-report','failed-assertion'}
    if log_failure: allowed.update(('missing-or-malformed-report','fatal-engine-log'))
    if set(phase['errors'])-allowed: return False
    if not log_failure and process['fatal']: return False
    if suite=='research-bootstrap':
        if process['exit_code'] not in (0, 1): return False
    elif process['exit_code']==0:return False
    try:report,log=compact_evidence(result)
    except (OSError,ValueError,KeyError,TypeError,zipfile.BadZipFile):return False
    # Exact selected profile/runtime checks must still pass if a report exists.
    if any(c.get('passed') is not True and c.get('name','').startswith('effective-mod-') for c in report.get('checks',[])): return False
    failed=[c for c in report.get('checks',[]) if c.get('passed') is False]
    # RunTest describes every uncaught Lua assertion as non-recoverable. The
    # named event assertion below identifies these intentional failures; loading
    # and unrelated engine failures still cannot qualify them.
    if log_failure and ('Error while running event' not in log or any(marker in log.lower() for marker in ('error atlasbuilder','failed to load mods','error modmanager','error servermultiplayer','error util.cpp'))): return False
    if suite=='build-dispatch': return bool(failed) and all(c['name'].endswith('-ticks') for c in failed)
    if suite=='gaia-resources':
        expected = {'disable-required-gaia-relic-resource': 'resource-present-ei-gaia-relic-debris',
                    'select-legacy-gaia-generation': 'runtime-current-generation-revision'}.get(result['injected_defect'])
        return len(failed)==1 and failed[0]['name']==expected
    if suite=='scheduler-event-tick': return 'controlled-clock-counter-tick-0' in log
    if suite=='research-events': return 'scripted-order' in log and 'anisetron-scripted' not in log.split('scripted-order:')[-1].split('\n')[0]
    if suite == 'research-bootstrap':
        if process['exit_code'] == 0:
            return not phase['errors'] and result.get('error') == 'updates' and report.get('passed') is True
        expected_errors = {'engine-exit', 'failed-report', 'failed-assertion'}
        return (set(phase['errors']) == expected_errors and len(failed) == 1
                and failed[0].get('name') == 'fixture-exception'
                and failed[0].get('detail', '').endswith(': Wrong native technology ingredients'))
    if suite=='induction-circuit': return 'INDUCTION_CIRCUIT_QC all four outputs default off' in log
    if suite=='alert-preferences': return any(c['name']=='fixture-exception' and 'personal-off-gate-low-power' in c.get('detail','') for c in failed)
    return any('ei-advanced-chem-plant: eligibility'==c.get('detail') for c in failed)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--suite',action='append',choices=(*catalogue.CORE, 'gaia-resources'))
    parser.add_argument('--gaia-defect', choices=('missing-resource','legacy-generation'), default='missing-resource')
    args=parser.parse_args();rows=[]
    if args.gaia_defect != 'missing-resource' and args.suite != ['gaia-resources']:
        parser.error('The Gaia generation control requires exactly --suite gaia-resources')
    for suite in args.suite or catalogue.CORE:
        profile={'research-bootstrap':'triggers-1-flatten-0','mirroring':'quality-enabled'}.get(suite,'default')
        row=catalogue.plan(runner.REPO,suites=[suite],cases=['candidate'],profiles=[profile])['rows'][0]
        rows.append(row)
    execution=runner.execute_selection(rows,qualification=lambda main,helper,suite: inject(main,helper,suite,args.gaia_defect))
    results=[{'suite':r['suite'],'defect_detected':detected(r),'child':r} for r in execution['results']]
    passed=not execution['source_errors'] and len(results)==len(rows) and all(r['defect_detected'] for r in results)
    output={'task':'suite-qualification','overall_status':'ok' if passed else 'failed','results':results,
        'source_fingerprint':execution['source_fingerprint'],'source_errors':execution['source_errors']}
    print(json.dumps(output));return int(output['overall_status']=='failed')


if __name__=='__main__':raise SystemExit(main())

"""Explicit-scope quick iteration and targeted acceptance; never invokes full QC."""
from __future__ import annotations

import argparse
import ast
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

import catalogue
import runner
import source_inputs

REPO = runner.REPO
HERE = Path(__file__).resolve().parent


def normalize_paths(repo, paths):
    """Exact files only. Deleted/renamed tracked paths remain valid inputs."""
    repo = Path(repo).resolve()
    tracked = set(subprocess.check_output(['git', 'ls-files', '-z'], cwd=repo).decode('utf-8').split('\0'))
    tracked.update(subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', '-z', 'HEAD'], cwd=repo).decode('utf-8').split('\0'))
    result = set()
    for value in paths:
        if not value or any(c in value for c in '*?['):
            raise ValueError('-ChangedPath requires nonempty exact files, not patterns')
        path = Path(value.replace('\\', '/'))
        path = (repo / path).resolve()
        try:
            relative = path.relative_to(repo).as_posix()
        except ValueError:
            raise ValueError('Changed path escapes repository: ' + value) from None
        if path.is_dir() or (not path.is_file() and relative not in tracked):
            raise ValueError('Unknown changed file (deleted tracked files are supported): ' + value)
        result.add(relative)
    if not result:
        raise ValueError('Empty -ChangedPath scope')
    return sorted(result)


def is_gameplay(path):
    return bool(re.match(r'(?:exotic-space-industries-remembrance[^/]*|[^/]+-continued)/', path))


def is_data(path):
    return is_gameplay(path) and (path.endswith('/info.json') or
        (path.endswith('.lua') and ('/prototypes/' in path or '/scripts/data-' in path or
         Path(path).name in ('settings.lua', 'settings-updates.lua', 'settings-final-fixes.lua',
                             'data.lua', 'data-updates.lua', 'data-final-fixes.lua') or
         path.endswith(('/lib/data.lua', '/lib/lib.lua', '/lib/recipe-routing.lua', '/lib/recycling-policy.lua',
                        '/lib/tech-weighting.lua')))))


def row_keys(rows):
    return {(r['suite'], r['profile']['id'], case) for r in rows for case in r['cases']}


def expected_launches(rows):
    # Counts game sessions, separately from executable version/capability probes.
    return sum(len(r['cases']) + int(any(c != 'candidate' for c in r['cases'])) +
               int(any(c in ('reload', 'configuration') for c in r['cases'])) for r in rows)


def make_plan(repo, level, suites=(), cases=(), profiles=(), paths=None, changed_since=None, tier='core'):
    if sum((bool(suites), paths is not None, changed_since is not None)) != 1:
        raise ValueError('Supply exactly one scope: -ChangedPath <files>, -ChangedSince <ref>, or -Suite <ids>; use -PlanOnly to preview it')
    if level == 'quick' and (tier != 'core' or any(c != 'candidate' for c in cases)):
        raise ValueError('qc-quick allows candidate cases only; use qc-targeted for reload, configuration or extended cases')
    document = catalogue.load(repo)
    errors = catalogue.audit_inventory(repo, document) + catalogue.audit_links(repo, document)
    if errors:
        raise ValueError('Catalogue validation failed: ' + '; '.join(errors))
    scope_paths = normalize_paths(repo, paths) if paths is not None else None
    selection = catalogue.plan(repo, suites, cases, profiles, tier, changed_since,
                               discovery=True, paths=scope_paths, deduplicate_smoke=level != 'quick')
    if suites and not selection['rows']:
        raise ValueError('Empty test execution selection')
    by_id = {s['id']: s for s in document['suites']}
    # Required acceptance before applying an explicit subset or quick preset.
    owners = sorted({r['suite'] for r in selection['rows']})
    required = catalogue.plan(repo, owners, tier=tier, discovery=True)['rows'] if owners else []
    if any('host-timeout' in r['cases'] for r in selection['rows']):
        required = [r for r in required if r['suite'] != 'runner-conformance'] + [r for r in selection['rows'] if r['suite'] == 'runner-conformance']
    rows = selection['rows']
    if level == 'quick':
        rows = [{**r, 'cases': [c for c in r['cases'] if c in by_id[r['suite']]['quick']['cases']]}
                for r in rows if profiles or r['profile']['id'] in by_id[r['suite']]['quick']['profiles']]
        rows = [r for r in rows if r['cases']]
        if owners and not rows:
            raise ValueError('Empty quick preset selection')
        rows = catalogue.deduplicate_routed_smoke(rows)
        if 'engine-smoke' not in {r['suite'] for r in rows}:
            required = [r for r in required if r['suite'] != 'engine-smoke']
    changed = selection['changed_paths']
    # Explicit suites check their owned sources and fixtures, not unrelated dirt.
    static_paths = set(changed)
    if suites:
        for name in suites:
            for pattern in by_id[name].get('paths', []):
                static_paths.update(p.relative_to(repo).as_posix() for p in Path(repo).glob(pattern) if p.is_file())
    static_paths = sorted(static_paths)
    checks = [{'id': 'scoped-static', 'paths': static_paths}]
    infrastructure = any(catalogue.matches(p, document['infrastructure_paths']) and
                         not p.endswith('.md') and not Path(p).name.startswith('test_') for p in changed)
    catalogue_changed = catalogue.CATALOGUE in changed
    host_changed = any(p.startswith('scripts/qc/native-tests/test_') for p in changed)
    if infrastructure or catalogue_changed or host_changed:
        checks.append({'id': 'native-host-tests', 'command': [sys.executable, '-B', '-m', 'unittest', 'discover', '-s', str(HERE), '-p', 'test_*.py']})
    if infrastructure:
        for name in ('test_encoding.ps1', 'test_helpers.ps1', 'test_acceptance.ps1'):
            checks.append({'id': name, 'command': ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(HERE / name)]})
    profile_change = any(catalogue.matches(p, ['*/info.json', '.codex/esir/factorio-development.json', '.codex/esir/save-catalog.json']) for p in changed)
    data = any(is_data(p) for p in static_paths) or profile_change
    assets = any(is_gameplay(p) and (Path(p).suffix.lower() in ('.png','.ogg','.wav') or
                 '/entity-presentation' in p or p.endswith('/death-explosions.lua')) for p in static_paths)
    package = any(catalogue.matches(p, ['scripts/pack*', 'scripts/*package*', '.github/workflows/*release*']) for p in changed)
    acceptance_checks = []
    if data: acceptance_checks.append({'id': 'final-data', 'mode': 'fast'})
    if assets: acceptance_checks.append({'id': 'assets', 'mode': 'assets'})
    if package: acceptance_checks.append({'id': 'package', 'mode': 'package'})
    companion_rows = []
    if 'gaia-resources' in owners:
        acceptance_checks.append({'id': 'gaia-acceptance', 'mode': 'preview', 'preview_scope': 'gaia-acceptance'})
    omitted = [{'suite': s, 'profile': p, 'case': c} for s,p,c in sorted(row_keys(required)-row_keys(rows))]
    if level == 'targeted':
        checks.extend(acceptance_checks)
        # The fixed companion already executes the native Gaia row exactly once.
        if 'gaia-resources' in owners:
            companion_rows = [r for r in rows if r['suite'] == 'gaia-resources']
            rows = [r for r in rows if r['suite'] != 'gaia-resources']
    else:
        omitted.extend({'check': c['id']} for c in acceptance_checks)
    if rows: checks.append({'id': 'native-tests', 'rows': rows})
    recommendations = ['Full QC remains an explicit request or an authorized release gate.']
    if profile_change: recommendations.append('Engine/dependency profile changed: consider an explicit full qualification after targeted checks.')
    return {**selection, 'task': 'qc-'+level, 'validation_level': level, 'rows': rows,
            'requested_scope': {'suites': list(suites), 'cases': list(cases), 'profiles': list(profiles),
                                'changed_paths': scope_paths, 'changed_since': changed_since},
            'checks': checks, 'companion_rows': companion_rows, 'omitted_requirements': omitted,
            'acceptance_scope': 'iteration' if level=='quick' else ('subset' if omitted else 'selected-suites'),
            'expected_native_game_launches': expected_launches(rows + companion_rows),
            'additional_engine_work': [c['id'] for c in checks if 'mode' in c],
            'launch_note': 'Game sessions exclude version/help probes; broad data/assets/preview checks report their own processes.',
            'full_qc_recommendations': recommendations}


def bridge(action, data):
    environment = {k:v for k,v in os.environ.items() if k.lower() != 'psmodulepath'}
    root = REPO / 'temp'; root.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='esir-scoped-request-', dir=root) as directory:
        request = Path(directory) / 'request.json'
        runner.write_json(request, data)
        process = subprocess.run(['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
            str(HERE/'workflows.ps1'), '-Action', action, '-Request', str(request)], cwd=REPO,
            env=environment, capture_output=True, text=True, encoding='utf-8', errors='replace')
        lines = [line for line in process.stdout.splitlines() if line.startswith('{')]
        if process.returncode or not lines:
            raise RuntimeError(process.stderr[-5000:] + process.stdout[-2000:])
        return json.loads(lines[-1])


def locale_entries(text):
    entries, duplicates, section = {}, [], ''
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith(('#',';')): continue
        if line.startswith('[') and line.endswith(']'): section = line[1:-1]; continue
        if '=' in line:
            key, value = line.split('=',1); key = section + '.' + key.strip()
            if key in entries: duplicates.append(key)
            entries[key] = value
    return entries, duplicates


def scoped_static(paths):
    errors, checked, skills = [], [], set()
    ps = bridge('static', {'paths': paths})
    errors.extend(ps['errors'])
    for relative in paths:
        path = REPO / relative
        if not path.is_file(): continue
        suffix = path.suffix.lower()
        if suffix not in ('.py','.lua','.json','.md','.cfg','.ps1','.psm1'): continue
        text = path.read_text(encoding='utf-8-sig')
        try:
            if suffix == '.py': ast.parse(text, filename=relative)
            elif suffix == '.json': json.loads(text)
            elif suffix == '.lua':
                compiler = REPO / '.tools/lua-5.4.8/luac54.exe'
                check = subprocess.run([str(compiler), '-p', str(path)], capture_output=True, text=True, encoding='utf-8', errors='replace')
                if check.returncode: errors.append(relative + ': ' + check.stderr.strip())
            elif suffix == '.cfg' and '/locale/' in relative:
                entries, duplicates = locale_entries(text)
                errors.extend(relative + ': duplicate ' + k for k in duplicates)
                locale = path.parent.name
                english = path.parent.parent / 'en' / path.name.replace('lang_'+locale, 'lang_en')
                if locale != 'en' and english.is_file():
                    base, _ = locale_entries(english.read_text(encoding='utf-8-sig'))
                    for key,value in entries.items():
                        if key in base and sorted(re.findall(r'__\d+__', value)) != sorted(re.findall(r'__\d+__', base[key])):
                            errors.append(relative + ': placeholder mismatch ' + key)
            elif suffix == '.md':
                for target in re.findall(r'(?<!!)\[[^\]]*\]\(([^)]+)\)', text):
                    target = target.strip('<>').split('#')[0]
                    if not target or re.match(r'^[\w-]+:',target) or target.startswith('/') or ' ' in target: continue
                    if not (path.parent / target).exists(): errors.append(relative + ': broken local link ' + target)
                for parent in (path.parent, *path.parents):
                    if (parent/'SKILL.md').is_file(): skills.add(parent); break
            checked.append(relative)
        except (SyntaxError, ValueError, OSError) as error:
            errors.append(relative + ': ' + str(error))
    for skill in sorted(skills):
        validator = Path.home()/'.codex/skills/.system/skill-creator/scripts/quick_validate.py'
        process = subprocess.run([sys.executable,'-X','utf8','-B',str(validator),str(skill)],capture_output=True,text=True,encoding='utf-8',errors='replace')
        if process.returncode: errors.append(str(skill)+': '+process.stdout+process.stderr)
    return {'id':'scoped-static','overall_status':'failed' if errors else 'ok', 'checked_files':checked,
            'deleted_files':[p for p in paths if not (REPO/p).exists()], 'skills':[str(p) for p in sorted(skills)],
            'encoding':ps['encoding'], 'errors':errors}


def execute(selection, engine=None, strict=False):
    started = time.monotonic()
    owner = bridge('register', {'task': selection['task'], 'scope': selection['requested_scope']})
    evidence = REPO / owner['payload_path']
    result = {'task':selection['task'], 'run_id':owner['id'], 'overall_status':'failed',
              'selection':selection, 'validation_level':selection['validation_level'],
              'executed_checks':[], 'omitted_requirements':selection['omitted_requirements'],
              'coverage_gaps':selection['coverage_gaps'], 'receipt':str(evidence/'result.json')}
    baseline = None
    try:
        if selection['rows'] or selection['additional_engine_work']:
            base_only = bool(selection['rows']) and not selection['additional_engine_work'] and all(r['suite']=='runner-conformance' for r in selection['rows'])
            baseline = source_inputs.snapshot(REPO,base_only=base_only)
            result['source_fingerprint'] = baseline
        runner.write_json(evidence/'plan.json',selection)
        for check in selection['checks']:
            if baseline and source_inputs.snapshot(REPO,base_only=baseline.get('base_only',False))['sha256'] != baseline['sha256']:
                raise RuntimeError('Source inputs changed during scoped QC')
            if runner.harness_inputs() != runner.START_HARNESS:
                raise RuntimeError('Runner/fixture inputs changed during scoped QC')
            tick = time.monotonic()
            print('Scoped QC: '+check['id'], file=sys.stderr, flush=True)
            if check['id'] == 'scoped-static': child = scoped_static(check['paths'])
            elif check['id'] == 'native-tests':
                child = runner.execute_selection(check['rows'],engine,baseline['sha256'])
                child['overall_status'] = 'failed' if (child['source_errors'] or len(child['results'])!=len(check['rows']) or
                    any(r['overall_status']!='ok' for r in child['results'])) else 'ok'
            elif 'mode' in check:
                child = bridge('broad', {**check,'engine':engine,'strict':strict})
            else:
                environment = {k:v for k,v in os.environ.items() if k.lower()!='psmodulepath'}
                process = subprocess.run(check['command'], cwd=REPO, env=environment, capture_output=True,
                    text=True, encoding='utf-8', errors='replace', timeout=600)
                log = evidence/(check['id']+'.log'); log.write_text(process.stdout+process.stderr,encoding='utf-8')
                child = {'overall_status':'ok' if process.returncode==0 else 'failed','exit_code':process.returncode,'log':str(log)}
            child.update(id=check['id'], elapsed_seconds=round(time.monotonic()-tick,3))
            result['executed_checks'].append(child)
            if child['overall_status']=='failed': break
        if baseline and source_inputs.snapshot(REPO,base_only=baseline.get('base_only',False))['sha256']!=baseline['sha256']:
            raise RuntimeError('Source inputs changed before scoped completion')
        if runner.harness_inputs()!=runner.START_HARNESS:
            raise RuntimeError('Runner/fixture inputs changed before scoped completion')
        failed = len(result['executed_checks'])!=len(selection['checks']) or any(c['overall_status']=='failed' for c in result['executed_checks'])
        warning = bool(selection['coverage_gaps']) or any(c['overall_status']=='warning' for c in result['executed_checks'])
        result['overall_status'] = 'failed' if failed or (strict and warning) else ('warning' if warning else 'ok')
    except Exception as error:
        result['error'] = str(error)
    finally:
        result['elapsed_seconds'] = round(time.monotonic()-started,3)
        runner.write_json(evidence/'result.json', result)
        try:
            result['housekeeping'] = bridge('finish', {'run_id':owner['id'],'result':result})
            if result['overall_status']!='failed' and result['housekeeping']['status']!='success':
                result['overall_status']='failed'
                result['housekeeping_error']=result['housekeeping'].get('error') or 'Managed completion failed'
        except Exception as error:
            result['overall_status']='failed'; result['housekeeping_error']=str(error)
        # Keep the registered payload immutable after its completion snapshot.
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('task',choices=['qc-quick','qc-targeted'])
    parser.add_argument('--repo',type=Path,default=REPO)
    for name in ('suite','case','profile'): parser.add_argument('--'+name,action='append',default=[])
    parser.add_argument('--changed-path',action='append',default=None)
    parser.add_argument('--changed-since'); parser.add_argument('--engine')
    parser.add_argument('--tier',choices=['core','extended'],default='core')
    parser.add_argument('--plan-only',action='store_true'); parser.add_argument('--strict',action='store_true')
    args=parser.parse_args()
    try:
        if args.repo.resolve()!=REPO: raise ValueError('Scoped QC is repository-owned')
        selection=make_plan(REPO,args.task[3:],args.suite,args.case,args.profile,args.changed_path,args.changed_since,args.tier)
        result=selection if args.plan_only else execute(selection,args.engine,args.strict)
        if args.plan_only:
            result['plan_only']=True
            if args.strict and result['overall_status']=='warning': result['overall_status']='failed'
        print(json.dumps(result,ensure_ascii=False))
        return int(result['overall_status']=='failed')
    except Exception as error:
        print(json.dumps({'task':args.task,'overall_status':'failed','error':str(error)})); return 1


if __name__=='__main__': sys.exit(main())

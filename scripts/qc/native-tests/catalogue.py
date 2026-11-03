"""Read-only native-suite discovery, selection and evidence validation.

Execution lives in runner.py; listing/planning never initialize a managed run.
"""
from __future__ import annotations

import fnmatch
import json
import re
import subprocess
from pathlib import Path

CORE = ("build-dispatch", "scheduler-event-tick", "research-events", "research-bootstrap",
        "induction-circuit", "alert-preferences", "mirroring")
CATALOGUE = ".codex/esir/test-suites.json"


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def load(repo):
    document = read_json(Path(repo) / CATALOGUE)
    if document.get("schema_version") != 1:
        raise ValueError("Unsupported suite catalogue schema")
    if document.get('engine_version')!='2.1.24': raise ValueError('Native catalogue requires exact engine 2.1.24')
    suites = document["suites"]
    ids = [s["id"] for s in suites]
    if len(ids) != len(set(ids)) or set(CORE) != {s["id"] for s in suites if s.get("core")}:
        raise ValueError("Duplicate suite or incomplete core catalogue")
    for suite in suites:
        if suite["eligibility"] not in ("active", "needs-port", "historical"):
            raise ValueError("Invalid suite eligibility: " + suite["id"])
        if suite.get('core') and suite['eligibility']!='active': raise ValueError('Required core suite is not active: '+suite['id'])
        if suite["eligibility"] == "active":
            if not suite.get("profiles") or not suite.get("cases"):
                raise ValueError("Active suite has no profiles/cases: " + suite["id"])
            for name in ("profiles", "cases"):
                values = [r["id"] for r in suite[name]]
                if len(values) != len(set(values)):
                    raise ValueError("Duplicate " + name + ": " + suite["id"])
            if suite.get('engine_version')!='2.1.24': raise ValueError('Active suite engine mismatch')
            for budget in ('deadline_ticks','timeout_seconds'):
                if type(suite.get(budget)) is not int or suite[budget]<=0: raise ValueError('Invalid finite budget: '+suite['id'])
            if (suite['deadline_ticks']!=3600 or suite['timeout_seconds']!=600) and not suite.get('budget_reason'):
                raise ValueError('Budget override requires a fixture reason: '+suite['id'])
            if suite.get('checkpoint_executor') not in ('server','graphical'): raise ValueError('Unknown checkpoint executor')
            if any(p.get('quality') not in ('enabled','disabled') for p in suite['profiles']): raise ValueError('Unknown Quality profile')
            if suite['id']=='research-bootstrap' and {(p.get('no_triggers'),p.get('flatten')) for p in suite['profiles']}!={(False,False),(False,True),(True,False),(True,True)}:
                raise ValueError('Incomplete research startup matrix')
            if suite['id']=='mirroring' and {p['quality'] for p in suite['profiles']}!={'enabled','disabled'}: raise ValueError('Incomplete mirroring Quality matrix')
            if suite.get('core'):
                for profile in suite['profiles']:
                    required={'candidate','reload'}
                    if suite['id']=='induction-circuit': required.add('configuration')
                    if suite['id']=='research-bootstrap' and not (profile['no_triggers'] and not profile['flatten']): required={'candidate'}
                    available={c['id'] for c in suite['cases'] if c.get('tier','core')=='core' and
                               (not c.get('profiles') or profile['id'] in c['profiles'])}
                    if not required<=available: raise ValueError('Incomplete required core phases: '+suite['id']+'/'+profile['id'])
    return document


def changed_paths(repo, ref="HEAD"):
    # -z preserves whitespace; both rename sides are selection inputs.
    paths=set()
    # Include index/worktree separately: an unstaged reversal can hide a staged
    # edit from the combined ref-to-worktree diff.
    for tail in ([ref], ['--cached'], []):
        command = ["git", "diff", "--name-status", "-z", "--find-renames", *tail, "--"]
        tokens = subprocess.check_output(command, cwd=repo).decode("utf-8").split("\0")
        index=0
        while index < len(tokens) and tokens[index]:
            status = tokens[index]; index += 1
            count = 2 if status.startswith(("R", "C")) else 1
            paths.update(tokens[index:index + count]); index += count
    untracked = subprocess.check_output(
        ["git", "ls-files", "--others", "--exclude-standard", "-z"], cwd=repo).decode("utf-8")
    paths.update(p for p in untracked.split("\0") if p)
    return sorted(paths)


def matches(path, patterns):
    return any(fnmatch.fnmatchcase(path.replace("\\", "/"), pattern) for pattern in patterns)


def plan(repo, suites=(), cases=(), profiles=(), tier="core", changed_since=None,
         discovery=False, paths=None):
    document = load(repo)
    catalogue = {s["id"]: s for s in document["suites"]}
    suites, cases, profiles = list(suites), list(cases), list(profiles)
    if cases and len(suites) != 1:
        raise ValueError("-Case requires one explicit -Suite")
    if suites and changed_since is not None:
        raise ValueError("Choose explicit suites or change routing, not both")
    unknown = set(suites) - catalogue.keys()
    if unknown:
        raise ValueError("Unknown suites: " + ", ".join(sorted(unknown)))
    selected, gaps, supplemental = {}, [], []
    infrastructure_changed=False
    route = not suites and (discovery or changed_since is not None or paths is not None)
    changed = changed_paths(repo, changed_since or "HEAD") if route and paths is None else (paths or [])
    if route:
        for path in changed:
            owners = [s for s in catalogue.values() if matches(path, s.get("paths", []))]
            if matches(path, document["infrastructure_paths"] + ['.codex/esir/factorio-development.json', '.codex/esir/save-catalog.json', '.codex/esir/*dependency*.json']):
                owners = list({s['id']:s for s in [*owners,*(catalogue[n] for n in (*CORE, "runner-conformance"))]}.values())
                infrastructure_changed=True
            elif matches(path, document["shared_runtime_paths"]):
                owners = list({s['id']:s for s in [*owners,*(catalogue[n] for n in CORE)]}.values())
            elif matches(path, ['*/info.json', '.codex/skills/esir-dev/assets/*']):
                core_owners = [catalogue[name] for name in CORE]
                owners = list({owner['id']: owner for owner in owners + core_owners}.values())
                supplemental.append('dependency/profile compatibility')
            for owner in owners:
                if owner["eligibility"] == "active":
                    selected.setdefault(owner["id"], []).append(path)
                else:
                    components=[c for c in owner.get('components',[]) if any(
                        path==owner['reference_base']+'/'+ref or ('/' in ref and path.startswith(owner['reference_base']+'/'+ref.split('/')[0]+'/'))
                        for ref in c['references'])]
                    if components:
                        for component in components:
                            alias=component.get('active_suite')
                            if component['eligibility']=='active' and alias:
                                selected.setdefault(alias,[]).append(path)
                            else:
                                gaps.append({'path':path,'suite':owner['id'],'component':component['id'],'reason':component['eligibility']})
                            supplemental.extend(k for k in component['evidence_kind'] if k in ('rendered','multiplayer','benchmark'))
                    else: gaps.append({"path": path, "suite": owner["id"], "reason": owner["eligibility"]})
                supplemental.extend(owner.get("supplementary_evidence", []))
            if (not owners and re.match(r"(?:exotic-space-industries-remembrance[^/]*|[^/]+-continued)/", path)
                    and path.endswith((".lua", ".json"))):
                gaps.append({"path": path, "reason": "unmapped-gameplay"})
                for name in CORE:
                    selected.setdefault(name, []).append("unmapped fallback: " + path)
    else:
        wanted = suites or [s["id"] for s in catalogue.values()
                            if s["eligibility"] == "active" and (s.get("core") or tier == "extended")]
        for name in wanted:
            if catalogue[name]["eligibility"] != "active":
                raise ValueError(f"Suite {name} is {catalogue[name]['eligibility']}; port/validate before native execution")
            selected[name] = ["explicit selection" if suites else tier]
    rows = []
    for name in sorted(selected):
        suite = catalogue[name]
        known_cases = {c["id"] for c in suite["cases"]}
        known_profiles = {p["id"] for p in suite["profiles"]}
        if set(cases) - known_cases or set(profiles) - known_profiles:
            raise ValueError("Unknown case/profile for suite " + name)
        for profile in suite["profiles"]:
            if profiles and profile["id"] not in profiles:
                continue
            chosen = [c["id"] for c in suite["cases"] if (not cases or c["id"] in cases)
                      and (c.get("tier", "core") == "core" or tier == "extended" or cases or (infrastructure_changed and name=='runner-conformance'))
                      and (not c.get("profiles") or profile["id"] in c["profiles"])]
            if chosen:
                rows.append({"suite": name, "profile": profile, "cases": chosen,
                             "reasons": sorted(set(selected[name])), "deadline_ticks": suite.get("deadline_ticks", 3600),
                             "timeout_seconds": suite.get("timeout_seconds", 600), "checkpoint_executor":suite['checkpoint_executor']})
        supplemental.extend(suite.get("supplementary_evidence", []))
    if not rows and not discovery:
        raise ValueError("Empty test execution selection")
    return {"task": "test-plan", "overall_status": "warning" if gaps else "ok", "rows": rows,
            "changed_paths": changed, "coverage_gaps": gaps,
            "supplementary_evidence": sorted(set(supplemental)), "engine_version": document["engine_version"]}


def validate_report(report, expected, process_exit, fresh=True, fatal=False):
    errors = []
    if process_exit != 0: errors.append("engine-exit")
    if fatal: errors.append("fatal-engine-log")
    if not isinstance(report, dict): return errors + ["missing-or-malformed-report"]
    if not fresh: errors.append("stale-report")
    for key in ("run_id", "suite", "profile", "phase", "input_hash", "engine_version"):
        if report.get(key) != expected.get(key): errors.append("identity:" + key)
    if report.get("complete") is not True: errors.append("incomplete-report")
    if report.get("passed") is not True: errors.append("failed-report")
    checks = report.get("checks", [])
    if not isinstance(checks, list) or not checks:
        errors.append("empty-assertions")
    elif any(not isinstance(c, dict) or c.get("passed") is not True for c in checks):
        errors.append("failed-assertion")
    actual=report.get('cases')
    if not isinstance(actual,list) or actual != expected['cases']: errors.append("case-completeness")
    return errors


def audit_links(repo, document):
    suites={s['id']:s for s in document['suites']};errors=[]
    for suite in suites.values():
        reference=suite.get('existing_workflow',{}).get('reference')
        if reference and not (Path(repo)/reference).is_file(): errors.append(suite['id']+': missing workflow reference '+reference)
        helper=suite.get('launch',{}).get('helper')
        if helper and not (Path(repo)/helper/'info.json').is_file(): errors.append(suite['id']+': missing helper '+helper)
        component_ids=set()
        for component in suite.get('components',[]):
            if component['id'] in component_ids: errors.append(suite['id']+': duplicate component '+component['id'])
            component_ids.add(component['id'])
            if component['eligibility'] not in ('active','needs-port','historical'): errors.append('Invalid component eligibility')
            for ref in component['references']:
                if not (Path(repo)/suite['reference_base']/ref).exists(): errors.append(suite['id']+'/'+component['id']+': missing '+ref)
            for key in ('active_suite','catalogue_suite'):
                if component.get(key) and component[key] not in suites: errors.append('Unknown component suite alias: '+component[key])
    for path in (Path(repo)/'.codex/esir/blueprints').glob('*.md'):
        text=path.read_text(encoding='utf-8-sig')
        for name in re.findall(r'^test-suite:\s*([\w-]+)\s*$',text,re.M):
            if name not in suites: errors.append(str(path)+': unknown suite '+name)
        for name,case in re.findall(r'^test-case:\s*([\w-]+)/([\w-]+)\s*$',text,re.M):
            if name not in suites or case not in {c['id'] for c in suites[name]['cases']}:
                errors.append(str(path)+': unknown case '+name+'/'+case)
    return errors


def audit_inventory(repo, document):
    """Ensure new fixture families/runners cannot disappear from discovery."""
    declared = {p for s in document["suites"] for p in s.get("inventory", [])}
    actual = {p.relative_to(repo).as_posix() for p in (Path(repo) / "scripts/qc").iterdir() if p.is_dir() and p.name != "__pycache__"}
    actual |= {p.relative_to(repo).as_posix() for p in (Path(repo) / "scripts").glob("invoke-*-qc.ps1")}
    actual |= {p.parent.relative_to(repo).as_posix() for p in (Path(repo)/'.codex/skills/esir-dev/assets').glob('*/info.json')}
    missing=actual-declared
    for suite in document['suites']:
        if not suite.get('components'): continue
        root=Path(repo)/suite['reference_base']
        represented={ref.split('/')[0] for c in suite['components'] for ref in c['references']}
        missing.update(p.relative_to(repo).as_posix() for p in root.iterdir() if p.name!='__pycache__' and p.name not in represented)
    return sorted(missing)



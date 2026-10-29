"""Factorio 2.1.23 full-core optional-Quality matrix, with isolated frozen source.

Register an absent short run directory through esir-housekeeping.ps1 first.
The runner preserves the core seed and explicitly disables Quality after staging.
No user saves, installed mods or shipping files are modified.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import itertools
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

REPO = Path(__file__).absolute().parents[3]
FIXTURE = Path(__file__).absolute().parent
NAME = "exotic-space-industries-remembrance"
FLAGS = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2), encoding="utf-8")


def source_hashes(root):
    return {str(p.relative_to(root)).replace("\\", "/"): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(root.rglob("*")) if p.is_file()}


def stage(root, frozen, engine):
    root.mkdir(exist_ok=True, parents=True)
    command = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
               str(REPO / "scripts/qc/factorio-2.1/invoke-core.ps1"), "-Task", "stage",
               "-RunRoot", str(root), "-Engine", str(engine), "-Quality", "disabled"]
    result = subprocess.run(command, cwd=REPO, capture_output=True, text=True, creationflags=FLAGS)
    (root / "staging.log").write_text(result.stdout + result.stderr, encoding="utf-8")
    assert result.returncode == 0, result.stderr
    destination = root / "mods" / NAME
    # Unlink only the verified live-source junction. Never recursively remove it.
    assert destination.resolve() == (REPO / NAME).resolve(), destination
    assert os.path.isjunction(destination), destination
    os.rmdir(destination)
    quote = lambda path: "'" + str(path).replace("'", "''") + "'"
    subprocess.run(["powershell", "-NoProfile", "-Command",
                    f"New-Item -ItemType Junction -Path {quote(destination)} -Target {quote(frozen)} | Out-Null"],
                   check=True, creationflags=FLAGS)
    fixture = root / "mods/esir-qc-quality-optional"
    fixture.mkdir()
    for path in FIXTURE.glob("*.lua"):
        shutil.copy2(path, fixture / path.name)
    shutil.copy2(FIXTURE / "info.json", fixture / "info.json")
    selection = json.loads((root / "mods/mod-list.json").read_text(encoding="utf-8-sig"))
    selection["mods"].append({"name": "esir-qc-quality-optional", "enabled": True})
    write_json(root / "mods/mod-list.json", selection)
    return fixture


def configure(root, case):
    fixture = root / "mods/esir-qc-quality-optional"
    contents = "return {\n" + "".join(
        f"    {key} = {str(value).lower() if isinstance(value, bool) else json.dumps(value)},\n"
        for key, value in case.items()) + "}\n"
    (fixture / "case.lua").write_text(contents, encoding="utf-8")
    selection = json.loads((root / "mods/mod-list.json").read_text(encoding="utf-8"))
    for mod in selection["mods"]:
        if mod["name"] == "quality":
            mod["enabled"] = case["quality"]
    required = {row["name"] for row in selection["mods"] if row["enabled"]}
    assert {"space-age", "recycler", NAME} <= required
    write_json(root / "mods/mod-list.json", selection)


def execute(root, engine, case, args, phase):
    log = root / (case["id"] + "." + phase + ".log")
    command = [str(engine), "--config", str(root / "config.ini"), "--mod-directory",
               str(root / "mods"), "--disable-audio", *args]
    start = time.time()
    with log.open("w", encoding="utf-8") as stream:
        result = subprocess.run(command, cwd=REPO, stdout=stream, stderr=subprocess.STDOUT,
                                timeout=300, creationflags=FLAGS)
    content = log.read_text(encoding="utf-8", errors="replace")
    marker = re.search(r"QUALITY_OPTIONAL_DATA_PASSED (\d+)", content)
    passed = result.returncode == 0 and bool(marker) and "Error while running" not in content
    return {"case": case, "phase": phase, "passed": passed, "exit_code": result.returncode,
            "data_checks": int(marker[1]) if marker else 0, "elapsed_seconds": round(time.time()-start, 2),
            "progression_sha256": hashlib.sha256("\n".join(re.findall(r"QUALITY_OPTIONAL_PROGRESSION (.+)", content)).encode()).hexdigest(),
            "log": str(log), **({} if passed else {"error_tail": content[-5000:]})}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", required=True)
    parser.add_argument("--workers", type=int, choices=(1, 2), default=2)
    parser.add_argument("--limit", type=int)
    parser.add_argument("--filter", default=".")
    parser.add_argument("--upstream-sentinel",action="store_true")
    parser.add_argument("--resume",action="store_true",help="Keep successful rows from this unchanged frozen source after correcting a fixture")
    parser.add_argument("--refresh-source", action="store_true", help="Explicitly refresh this task-owned frozen snapshot")
    parser.add_argument("--phase", choices=("matrix", "runtime"), default="matrix")
    args = parser.parse_args()
    root = Path(os.path.abspath(args.run))
    assert root.is_relative_to(REPO / ".factorio-qc"), "Use registered repo-owned staging"
    root.mkdir(exist_ok=True, parents=True)
    development = json.loads((REPO / ".codex/esir/factorio-development.json").read_text(encoding="utf-8-sig"))
    engine = (REPO / development["engine_path"]).absolute()
    frozen = root / "main"
    if not frozen.exists() or args.refresh_source:
        if (root / "production-source.json").exists():
            shutil.copy2(root / "production-source.json", root / ("production-source-" + str(time.time_ns()) + ".json"))
        shutil.copytree(REPO / NAME, frozen, dirs_exist_ok=True)
        write_json(root / "production-source.json", source_hashes(REPO / NAME))
    assert source_hashes(REPO / NAME) == json.loads((root / "production-source.json").read_text()), \
        "Shipping source changed; start a new registered run or deliberately refresh the frozen snapshot"
    values = ("neither", "nitrogen", "alien", "both")
    cases = [{"id": f"q{int(q)}-{effects}-q{quality}-p{productivity}", "quality": q,
              "effects": effects, "quality_permission": quality, "productivity_permission": productivity,
              "overload": True, "phase": args.phase}
             for q, effects, quality, productivity in itertools.product((False, True), ("esir", "vanilla"), values, values)]
    if args.phase == "runtime":
        cases = [case for case in cases if
                 (case["quality_permission"] in ("neither", "both") and case["productivity_permission"] in ("neither", "both"))
                 or (case["quality"] and case["effects"]=="esir"
                     and (case["quality_permission"],case["productivity_permission"]) in (("nitrogen","alien"),("alien","nitrogen")))]
        for index, case in enumerate(cases):
            case["overload"] = index % 2 == 0
    cases = [case for case in cases if re.search(args.filter, case["id"])]
    if args.upstream_sentinel:
        for case in cases:
            case["upstream_sentinel"]=True
            case["id"]+="-upstream"
    if args.limit:
        cases = cases[:args.limit]
    summary_path=root / (args.phase + ("-upstream" if args.upstream_sentinel else "") + ".json")
    accepted={}
    if args.resume and summary_path.exists():
        previous=json.loads(summary_path.read_text())
        assert previous.get("source_unchanged"),"Cannot resume evidence from changed shipping source"
        accepted={row["case"]["id"]:row for row in previous["cases"] if row["passed"]}
    stages = []
    for index in range(args.workers):
        worker = root / chr(ord("a") + index)
        if not (worker / "mods/esir-qc-quality-optional").exists():
            stage(worker, frozen, engine)
        else:
            for path in FIXTURE.glob("*.lua"):
                shutil.copy2(path, worker / "mods/esir-qc-quality-optional" / path.name)
            shutil.copy2(FIXTURE / "info.json", worker / "mods/esir-qc-quality-optional/info.json")
        stages.append(worker)
    def worker_run(index):
        worker = stages[index]
        results = []
        for case in cases[index::args.workers]:
            prior=accepted.get(case["id"])
            if prior and prior["case"]==case:
                results.append(prior)
                print(json.dumps({"case":case["id"],"passed":True,"resumed":True}),flush=True)
                continue
            configure(worker, case)
            save = worker / "fresh.zip"
            result = execute(worker, engine, case, ["--create", str(save)], "create")
            if result["passed"]:
                report = json.loads((worker / "script-output/quality-optional-init.json").read_text())
                result["passed"] = report.get("passed") and report.get("case") == case["id"]
                result["init"] = report
            if result["passed"] and args.phase == "runtime":
                runtime = execute(worker, engine, case, ["--benchmark", str(save), "--benchmark-ticks", "300",
                                                       "--benchmark-runs", "1"], "runtime")
                result["runtime"] = runtime
                result["passed"] = runtime["passed"]
                if runtime["passed"]:
                    report = json.loads((worker / "script-output/quality-optional-native.json").read_text())
                    result["passed"] = report.get("passed") and report["case"]["id"] == case["id"]
                    result["native"] = report
            write_json(worker / (case["id"] + ".receipt.json"), result)
            results.append(result)
            print(json.dumps({"case": case["id"], "passed": result["passed"], "checks": result["data_checks"]}), flush=True)
            if not result["passed"]:
                break
        return results
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        results = list(itertools.chain.from_iterable(pool.map(worker_run, range(args.workers))))
    summary = {"passed": len(results) == len(cases) and all(row["passed"] for row in results),
               "engine": str(engine), "expected_cases": len(cases), "cases": results,
               "source_unchanged": source_hashes(REPO / NAME) == json.loads((root / "production-source.json").read_text())}
    progression = {row["progression_sha256"] for row in results if row["case"]["quality"]}
    summary["progression_unchanged"] = len(progression) <= 1
    summary["passed"] = summary["passed"] and summary["progression_unchanged"]
    write_json(summary_path, summary)
    if not summary["passed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()

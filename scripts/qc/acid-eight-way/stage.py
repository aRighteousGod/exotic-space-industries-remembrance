"""Stage exact-version, isolated acidthrower QC against live repository packs."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

REPO = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
MAIN = "exotic-space-industries-remembrance"
COPY_EXCLUDES={'.git','.qc','dist','tests','__pycache__'}


def source_identity(directory):
    return {p.relative_to(directory).as_posix():hashlib.file_digest(p.open('rb'),'sha256').hexdigest()
            for p in directory.rglob('*') if p.is_file() and not COPY_EXCLUDES.intersection(p.relative_to(directory).parts)}


def stage(root, engine, seed, phase, profile):
    assert "Version: 2.1.23 " in subprocess.check_output([str(engine), "--version"], text=True)
    assert json.loads((engine.parents[2] / "data/base/info.json").read_text())["version"] == "2.1.23"
    root.mkdir(parents=True, exist_ok=True)
    mods = root / "mods"
    mods.mkdir(exist_ok=True)
    lock = seed / "dependency-lock-2.1.json"
    development = json.loads((REPO / ".codex/esir/factorio-development.json").read_text())
    assert hashlib.sha256(lock.read_bytes()).hexdigest() == development["dependency_lock_sha256"]
    names = {"base", "space-age", "quality", "recycler", "elevated-rails"}
    input_hashes={}
    for row in json.loads(lock.read_text()):
        source = seed / row["file"]
        target = mods / source.name
        if not target.exists():
            assert hashlib.file_digest(source.open("rb"), "sha256").hexdigest() == row["sha256"]
            if source.drive.lower() == target.drive.lower():
                os.link(source, target)
            else:
                shutil.copy2(source, target)
        actual=hashlib.file_digest(target.open('rb'),'sha256').hexdigest()
        assert actual==row['sha256'], 'Staged dependency changed: '+str(target)
        input_hashes[target.name]=actual
        names.add(row["name"])
    sources = [p for p in REPO.iterdir() if p.is_dir() and
               (p.name.startswith(MAIN) or p.name in ("doeworks-deer-continued", "enhanced-walls-continued"))
               and (p / "info.json").is_file()]
    sources.append((REPO / development["nsbc_source"]).resolve())
    for source in sources:
        info = json.loads((source / "info.json").read_text(encoding="utf-8-sig"))
        target = mods / info["name"]
        if not target.exists() and info["name"] == "zzz-nonstandard-beacons-continued":
            shutil.copytree(source,target,ignore=shutil.ignore_patterns(*COPY_EXCLUDES))
        elif not target.exists():
            env = dict(os.environ, ESIR_ACID_LINK=str(target), ESIR_ACID_SOURCE=str(source))
            subprocess.run(["powershell", "-NoProfile", "-Command",
                            "New-Item -ItemType Junction -Path $env:ESIR_ACID_LINK -Target $env:ESIR_ACID_SOURCE | Out-Null"],
                           env=env, check=True)
        names.add(info["name"])
        if info['name']=='zzz-nonstandard-beacons-continued':
            expected=source_identity(source)
            assert source_identity(target)==expected, 'Private NSBC source changed; use a fresh RunRoot: '+str(target)
            input_hashes[info['name']]=expected
    helper = mods / "zzz-esir-acid-eight-way-qc"
    helper.mkdir(exist_ok=True)
    for name in ("control.lua", "data-final-fixes.lua", "acceptance.lua", "player.lua", "upgrade.lua"):
        shutil.copy2(HERE / name, helper / name)
    (helper / "info.json").write_text(json.dumps(dict(name=helper.name, version="1.0.0", factorio_version="2.1",
        title="ESIR eight-direction acidthrower acceptance", author="ESIR QC", dependencies=[MAIN])), encoding="utf-8")
    (helper / "test-config.lua").write_text("return " + "{phase='" + phase + "',profile='" + profile + "'}\n")
    (helper / "settings-updates.lua").write_text(
        "data.raw['string-setting']['ei-thrower-performance-profile'].default_value='" + profile + "'\n")
    names.add(helper.name)
    (mods / "mod-list.json").write_text(json.dumps({"mods": [{"name": n, "enabled": True} for n in sorted(names)]}))
    (root / "config.ini").write_text("[path]\nread-data=" + (engine.parents[2] / "data").as_posix() +
        "\nwrite-data=" + root.as_posix() + "\n[other]\ncheck-updates=false\n[graphics]\ncache-sprite-atlas=false\n")
    (root / "stage.json").write_text(json.dumps(dict(engine=str(engine), engine_version="2.1.23", phase=phase,
        profile=profile, seed=str(seed), packages=sorted(names)), indent=2))
    (root / 'stage-inputs.json').write_text(json.dumps(input_hashes,indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", type=Path, required=True)
    parser.add_argument("--engine", type=Path, required=True)
    parser.add_argument("--seed", type=Path, required=True)
    parser.add_argument("--phase", choices=("baseline", "probe", "ports", "layouts", "accept", "visual", "player", "legacy-seed", "legacy-load"), required=True)
    parser.add_argument("--create-only", action="store_true")
    parser.add_argument("--profile", choices=("original", "2x", "4x", "8x", "16x"), default="original")
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    assert not args.execute or args.phase in ("baseline", "probe", "accept"), "This phase requires the native graphical runner"
    root, engine = args.run.resolve(), args.engine.resolve()
    stage(root, engine, args.seed.resolve(), args.phase, args.profile)
    if args.execute or args.create_only:
        started=time.time()
        common = [str(engine), "--config", str(root / "config.ini"), "--mod-directory", str(root / "mods"), "--disable-audio"]
        commands=[("create", ["--create", str(root / "fixture.zip")])]
        if args.execute:commands.append(("benchmark", ["--benchmark", str(root / "fixture.zip"), "--benchmark-ticks", "600", "--benchmark-runs", "1"]))
        for label, command in commands:
            with (root / (label + ".log")).open("w", encoding="utf-8") as output:
                subprocess.run(common + command, stdout=output, stderr=subprocess.STDOUT, check=True)
        if args.execute:
            marker={"baseline":"final-data.json","probe":"ports.json","accept":"acid-eight-native.json"}[args.phase]
            result=root / "script-output" / marker
            assert result.is_file() and result.stat().st_mtime>=started, "Missing fresh native result: " + marker
            if args.phase!="baseline":assert json.loads(result.read_text())["passed"], "Native assertions failed: " + str(result)
    print(json.dumps(dict(run=str(root), phase=args.phase, profile=args.profile)))


if __name__ == "__main__":
    main()

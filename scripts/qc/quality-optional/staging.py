"""Exercise the real optional-combination CLI with explicit enabled/disabled profiles."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

REPO=Path(__file__).absolute().parents[3]


def write(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value),encoding="utf-8")


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run",type=Path,required=True)
    args=parser.parse_args()
    root=args.run.absolute()
    assert root.is_relative_to(REPO/".factorio-qc") and not root.exists()
    root.mkdir(parents=True)
    archive=root/"esir-qc-staging-optional_1.0.0.zip"
    info={"name":"esir-qc-staging-optional","version":"1.0.0","factorio_version":"2.1","dependencies":["base"]}
    with zipfile.ZipFile(archive,"w") as z:z.writestr("esir-qc-staging-optional_1.0.0/info.json",json.dumps(info))
    package={"name":info["name"],"version":"1.0.0","absolute_file":str(archive),"info":info,
        "sha256":hashlib.sha256(archive.read_bytes()).hexdigest()}
    packages=root/"packages"
    write(packages/"package-lock.json",[package]);write(packages/"resolution.json",{"required_edges":[]})
    results=[]
    for enabled in (True,False):
        core=root/("core-on" if enabled else "core-off")
        original=[{"name":"base","enabled":True,"version":"2.1.23"},
            {"name":"space-age","enabled":True},{"name":"recycler","enabled":True},
            {"name":"quality","enabled":enabled},{"name":"unselected-companion","enabled":False}]
        write(core/"mods/mod-list.json",{"mods":original});write(core/"release-selection.json",{"packages":[]})
        # Staging copies this opaque file; only Factorio interprets its contents.
        (core/"mods/mod-settings.dat").write_bytes(b"profile-copy-sentinel")
        output=root/("on" if enabled else "off")
        command=["python","-B",str(REPO/"scripts/qc/factorio-2.1/stage_optional_combination.py"),
            "--run",str(output),"--core",str(core),"--packages",str(packages),"--roots",info["name"]]
        subprocess.run(command,check=True,capture_output=True,text=True)
        selection={row["name"]:row for row in json.loads((output/"mods/mod-list.json").read_text())["mods"]}
        assert all(selection[row["name"]]==row for row in original)
        assert (output/"mods/mod-settings.dat").read_bytes()==b"profile-copy-sentinel"
        assert (output/"mods"/archive.name).read_bytes()==archive.read_bytes()
        results.append({"quality":enabled,"passed":True,"preserved_core_rows":len(original)})
    package["info"]["dependencies"].append("quality >= 2.1.23")
    write(packages/"package-lock.json",[package])
    command[command.index("--run")+1]=str(root/"rejected")
    rejected=subprocess.run(command,capture_output=True,text=True)
    assert rejected.returncode and "requires Quality in a Quality-disabled profile" in rejected.stderr
    report={"passed":True,"profiles":results,"hard_quality_dependency_rejected":True,
        "scope":"Real staging CLI, archive identity, startup-settings byte copy and core selection; no optional gameplay claim"}
    write(root/"receipt.json",report)
    print(json.dumps(report))


if __name__=="__main__":main()

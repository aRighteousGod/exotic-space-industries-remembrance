"""Resolve and optionally acquire pinned optional candidates and required children.

Resolution does not enable incompatible optional families together. Every edge,
conflict and version mismatch remains in the receipt for combination selection.
Downloads use the same authenticated, redacted helper as the verified core seed.
"""
import argparse
import concurrent.futures
import datetime
import json
from pathlib import Path
import urllib.parse
import urllib.request
from acquire_dependencies import acquire
from build_audit_ledgers import BUILTINS, parse_dependency


def version(value):
    return tuple(map(int, value.split(".")))


def accepts(actual, operator, required):
    if not operator: return True
    a,b=version(actual),version(required)
    return {">=":a>=b,"<=":a<=b,">":a>b,"<":a<b,"=":a==b}[operator]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--audit",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--download",action="store_true")
    parser.add_argument("--reuse",type=Path,help="Read and verify completed packages/metadata already preserved in an earlier task output")
    args=parser.parse_args()
    args.output.mkdir(parents=True,exist_ok=True)
    cache=args.output / "metadata"
    cache.mkdir(exist_ok=True)
    matrix=json.loads((args.audit / "optional-dependencies.json").read_text(encoding="utf-8"))
    core=json.loads((args.audit.parent / "dependencies/dependency-lock-2.1.json").read_text(encoding="utf-8"))
    available={row["name"]:row["version"] for row in core}
    available.update({name:"2.1.23" for name in BUILTINS})
    for source in Path.cwd().iterdir():
        if source.is_dir() and (source.name.startswith("exotic-space-industries-remembrance") or source.name in ("doeworks-deer-continued","enhanced-walls-continued")) and (source / "info.json").is_file():
            info=json.loads((source / "info.json").read_text(encoding="utf-8-sig"))
            if info.get("factorio_version")=="2.1": available[info["name"]]=info["version"]
    available["zzz-nonstandard-beacons-continued"]="1.0.0"
    selected={row["selected"]:row["version"] for row in matrix["entries"] if row["version"] and row["status"]!="port-backlog"}
    queue=list(selected)
    metadata={}
    edges=[]
    conflicts=[]
    missing=[]
    releases={}
    while queue:
        name=queue.pop(0)
        if name in metadata: continue
        candidates=[cache / (name+".json"),args.audit / "portal-metadata" / (name+".json"),args.audit.parent / "dependencies" / (name+".portal.json")]
        if args.reuse: candidates.insert(1,args.reuse / "metadata" / (name+".json"))
        path=next((p for p in candidates if p.is_file()),None)
        if path:
            document=json.loads(path.read_text(encoding="utf-8"))
        else:
            request=urllib.request.Request("https://mods.factorio.com/api/mods/"+urllib.parse.quote(name)+"/full",headers={"User-Agent":"Mozilla/5.0"})
            with urllib.request.urlopen(request,timeout=60) as response: document=json.load(response)
        metadata[name]=document
        (cache / (name+".json")).write_text(json.dumps(document,indent=2),encoding="utf-8")
        release=next(r for r in document["releases"] if r["version"]==selected[name])
        releases[name]=release
        for raw in release["info_json"].get("dependencies",[]):
            dependency=parse_dependency(raw)
            child=dependency["name"]
            if dependency["prefix"]=="!":
                conflicts.append({"from":name,**dependency})
                continue
            if dependency["prefix"] in ("?","(?)"): continue
            actual=selected.get(child,available.get(child))
            if actual is None:
                path=cache / (child+".json")
                if not path.is_file() and args.reuse and (args.reuse / "metadata" / (child+".json")).is_file():
                    path=args.reuse / "metadata" / (child+".json")
                if path.is_file(): child_document=json.loads(path.read_text(encoding="utf-8"))
                else:
                    request=urllib.request.Request("https://mods.factorio.com/api/mods/"+urllib.parse.quote(child)+"/full",headers={"User-Agent":"Mozilla/5.0"})
                    with urllib.request.urlopen(request,timeout=60) as response: child_document=json.load(response)
                    path.write_text(json.dumps(child_document,indent=2),encoding="utf-8")
                candidates=[r for r in child_document["releases"] if r["info_json"].get("factorio_version")=="2.1" and accepts(r["version"],dependency["operator"],dependency["version"])]
                if candidates:
                    actual=max(candidates,key=lambda r:version(r["version"]))["version"]
                    selected[child]=actual
                    queue.append(child)
            edge={"from":name,**dependency,"selected_version":actual,
                "satisfied":bool(actual and accepts(actual,dependency["operator"],dependency["version"]))}
            edges.append(edge)
            if not edge["satisfied"]: missing.append(edge)
    receipt={"refreshed_utc":datetime.datetime.now(datetime.timezone.utc).isoformat(),"original_count":50,
        "selected":selected,"required_edges":edges,"declared_conflicts":conflicts,"unsatisfied":missing,
        "limits":"Dependency metadata resolution only; no combination, migration, provenance or engine acceptance"}
    (args.output / "resolution.json").write_text(json.dumps(receipt,indent=2),encoding="utf-8")
    print(json.dumps({"selected":len(selected),"required_edges":len(edges),"conflicts":len(conflicts),"unsatisfied":missing}),flush=True)
    if args.download:
        def fetch(pair):
            name,pin=pair
            filename=releases[name]["file_name"]
            output=args.reuse if args.reuse and (args.reuse / filename).is_file() else args.output
            result=acquire(name,pin,output,metadata[name])
            if result["status"]=="verified-package": result["absolute_file"]=str((output / filename).absolute())
            return result
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            results=list(pool.map(fetch,selected.items()))
        (args.output / "package-lock.json").write_text(json.dumps(results,indent=2),encoding="utf-8")
        assert all(r["status"]=="verified-package" for r in results),"Some optional downloads did not verify"


if __name__=="__main__": main()

"""Attach verified package provenance and compare community forks with preserved ZIPs.

License label discrepancies are review holds, not automatic legal conclusions.
Engine and migration acceptance stay unset until their own receipts exist.
"""
import argparse
import hashlib
import json
from pathlib import Path
import urllib.parse
import urllib.request
import zipfile


def contents(path):
    with zipfile.ZipFile(path) as archive:
        rows={}
        for name in archive.namelist():
            if name.endswith("/"): continue
            relative=name.split("/",1)[1]
            rows[relative]=hashlib.sha256(archive.read(name)).hexdigest()
        return rows


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--audit",type=Path,required=True)
    parser.add_argument("--packages",type=Path,required=True)
    args=parser.parse_args()
    lock=json.loads((args.packages / "package-lock.json").read_text(encoding="utf-8"))
    assert all(r["status"]=="verified-package" for r in lock)
    packages={r["name"]:r for r in lock}
    matrix=json.loads((args.audit / "optional-dependencies.json").read_text(encoding="utf-8"))
    provenance=args.audit / "fork-provenance"
    provenance.mkdir(exist_ok=True)
    reviews=[]
    for row in matrix["entries"]:
        package=packages.get(row["selected"])
        if not package: continue
        row.update(sha256=package["sha256"],package_file=package["absolute_file"],package_verified=True,
            declared_dependencies=package["info"].get("dependencies",[]),package_author=package["info"].get("author"))
        row["evidence"].append(str(args.packages / "package-lock.json"))
        if row["original"]==row["selected"]: continue
        path=provenance / (row["original"]+".portal.json")
        if path.is_file(): original=json.loads(path.read_text(encoding="utf-8"))
        else:
            request=urllib.request.Request("https://mods.factorio.com/api/mods/"+urllib.parse.quote(row["original"])+"/full",headers={"User-Agent":"Mozilla/5.0"})
            with urllib.request.urlopen(request,timeout=60) as response: original=json.load(response)
            path.write_text(json.dumps(original,indent=2),encoding="utf-8")
        review={"original":row["original"],"selected":row["selected"],"version":row["version"],
            "original_portal_license":original.get("license"),"fork_portal_license":package["portal_license"],
            "original_portal":"https://mods.factorio.com/mod/"+row["original"],"fork_portal":row["portal_url"],
            "original_owner":original.get("owner"),"fork_owner":package["owner"],"package_author":package["info"].get("author"),
            "source_url":package["source_url"],"automatic_license_acceptance":False}
        previous=list((args.audit.parent / "baseline/mods").glob(row["original"]+"_*.zip"))
        after=contents(Path(package["absolute_file"]))
        review["license_or_credit_files"]={name:sha for name,sha in after.items() if any(word in name.lower() for word in ("license","licence","credit","attribution"))}
        if len(previous)==1:
            before=contents(previous[0])
            changed=sorted(name for name in before.keys() & after.keys() if before[name]!=after[name])
            review.update(baseline=str(previous[0]),unchanged_files=sum(before[n]==after[n] for n in before.keys() & after.keys()),
                changed_files=changed,added_files=sorted(after.keys()-before.keys()),removed_files=sorted(before.keys()-after.keys()))
        old_label=(original.get("license") or {}).get("name")
        new_label=(package.get("portal_license") or {}).get("name")
        review["license_label_discrepancy"]=old_label!=new_label
        if review["license_label_discrepancy"]:
            row["status"]="provenance-hold"
            row["provenance_note"]=f"Original Portal license {old_label}; fork Portal license {new_label}. Package/attribution review remains required."
        else:
            row["provenance_note"]="Portal license labels agree; package attribution and changed files recorded, acceptance still reviewed separately."
        row["evidence"].append(str(provenance / "comparison.json"))
        reviews.append(review)
    (provenance / "comparison.json").write_text(json.dumps(reviews,indent=2),encoding="utf-8")
    (args.audit / "optional-dependencies-packaged.json").write_text(json.dumps(matrix,indent=2),encoding="utf-8")
    print(json.dumps({"verified_packages":len(lock),"optional_entries":len(matrix["entries"]),"community_forks":len(reviews),
        "license_label_holds":[r["selected"] for r in reviews if r["license_label_discrepancy"]]}))


if __name__=="__main__": main()

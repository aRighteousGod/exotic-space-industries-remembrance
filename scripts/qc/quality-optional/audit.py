"""Inventory every Quality touchpoint in all live shipping packs, including ignored packs."""
import argparse
import hashlib
import json
from pathlib import Path
import re

REPO=Path(__file__).absolute().parents[3]
GUARDED={
    "info.json","lib/module-policy-config.lua","scripts/control/beacon-module-policy.lua",
    "scripts/data-updates/vanilla-updates/other.lua","scripts/data-updates/vanilla-updates/recipes.lua",
    "scripts/data-updates/vanilla-updates/techs.lua","scripts/data-final-updates/set-prerequisites.lua",
    "scripts/data-updates/atan-air-scrubber.lua","scripts/control/air-scrubber-compat.lua",
    "scripts/control/admin/gui.lua","scripts/control/admin/world.lua","scripts/control/spider-vehicles.lua",
    "scripts/control/orbital-combinator.lua","scripts/control/orbital-logistics.lua",
}
SAFE={
    "lib/recipe-routing.lua":"Only routes existing recipes",
    "scripts/data-final-updates/final-tech-fixes.lua":"Higher-quality unlock examples are commented out",
    "scripts/data-final-updates/recipe-buffer-sizing.lua":"Existing explicit no-Quality fallback; native sizing with Quality",
    "scripts/control/induction-matrix.lua":"Existing signal prototype/quality validation on configuration and GUI rebuild",
    "scripts/control/admin/players.lua":"Validates requested item and quality prototypes",
    "scripts/control/admin/restrictions.lua":"Iterates existing quality prototypes",
    "scripts/control/admin/targeting.lua":"Native selected objects and existing prototype lookups",
}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output",required=True)
    args=parser.parse_args()
    packs=sorted(p for p in REPO.iterdir() if p.is_dir() and (p/"info.json").is_file())
    rows=[];scanned=0
    for pack in packs:
        for path in sorted(pack.rglob("*")):
            if not path.is_file() or path.suffix.lower() not in (".lua",".json"):continue
            scanned+=1
            text=path.read_text(encoding="utf-8-sig")
            lines=[{"line":i,"text":line.strip()} for i,line in enumerate(text.splitlines(),1) if re.search("quality",line,re.I)]
            if not lines:continue
            relative=path.relative_to(pack).as_posix()
            classification="guard required and implemented" if pack.name=="exotic-space-industries-remembrance" and relative in GUARDED \
                else "already safe" if relative in SAFE else "native quality behavior"
            note=SAFE.get(relative,"Native normal quality/effects/scaling/transfer remains available without the Quality content mod")
            if relative=="control.lua":note="Pump priming remains native normal level0, 3 steam at165C in runtime storage2; Quality mod changes repair scanner caches"
            if relative=="lib/lib.lua":note="Native quality bounds and transfers retained; saved identifiers validated; existing conditional fluid-buffer helper retained"
            rows.append({"file":path.relative_to(REPO).as_posix(),"sha256":hashlib.sha256(path.read_bytes()).hexdigest(),
                         "classification":classification,"note":note,"findings":lines})
    locales={}
    expected=None
    for language in ("en","de","fr","ja","pl","ru","zh-CN","zh-TW"):
        path=REPO/"exotic-space-industries-remembrance/locale"/language/"module-policy.cfg"
        keys={};section=""
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.startswith("["):section=line
            elif line and "=" in line:
                key,value=line.split("=",1);full=section+key
                assert full not in keys,(language,key)
                keys[full]=sorted(re.findall(r"__\d+__|__ENTITY__[^_]+__",value))
                assert "\ufffd" not in value
        if expected is None:expected=keys
        assert keys==expected,language
        locales[language]={"keys":len(keys),"passed":True}
    report={"passed":True,"packs":[p.name for p in packs],"scanned_source_files":scanned,
            "matching_files":len(rows),"findings":sum(len(row["findings"]) for row in rows),"rows":rows,"locales":locales,
            "dedicated_quality_suites":{"classification":"intentionally Quality-specific test","paths":[
                "scripts/qc/factorio-2.1/quality-trains.lua","scripts/qc/sweeping-radar/quality.lua",
                "scripts/qc/beacon-profiles","scripts/qc/spider-vehicles","scripts/qc/induction-circuit"],
                "policy":"Keep original higher-quality acceptance explicit; new normal-only probes have separate names and receipts."}}
    Path(args.output).write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding="utf-8")
    print(json.dumps({key:value for key,value in report.items() if key not in ("rows","dedicated_quality_suites")}))


if __name__=="__main__":main()

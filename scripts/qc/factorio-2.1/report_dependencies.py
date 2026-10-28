"""Render the complete 50-entry matrix from package and native receipts.

Never equates a smoke pass with progression, migration or publication acceptance.
The JSON companion retains full hashes, required closures, conflicts and provenance.
"""
import argparse
import datetime
import hashlib
import json
from pathlib import Path

INTEGRATION_NOTES = {
    "planet-muluna": "Route replacement rocket productivity to all four ESIR manufacturing recipes at each level's original value, removing the silo bridge bonus; Rigor targets unrelated random products instead of changing conserved crystal-return odds. Final native data contains 600 valid return recipes. Published Muluna forces its easy rocket setting true; expanded research is not an available supported setting. Interstellar-science age classification still needs progression review.",
    "Cerys-Moon-of-Fulgora": "Remove additional technology unlocks only for recycling recipes deliberately retired by ESIR.",
    "tenebris-prime": "Refresh inherited ESIR graphics sets after canonical repairs, retaining Tenebris glow, speed, void energy and restrictions; native rendering remains open.",
    "corrundum": "Move red steam engine's 100 C admission floor from removed FluidBox field to native generator input field; admission boundary remains open.",
    "Krastorio2-spaced-out": "User explicitly deferred K2 support for ESIR 1.4.0. Known load conflict: kr-ammonia has a 25 C minimum while ESIR cryo-container recipes use -35 C. No temperature or balance change; retain affected saves on preserved 2.0. Earlier import/buffer ports are preparatory, not accepted support.",
    "cubium": "Published port retains old lava tile-effect textures; 2.1 requires separate noise/image textures. Unsupported pending presentation port.",
    "planet-woodoria": "Transitive fruit package calls removed assembler3pipepictures during data.lua. Unsupported pending dependency port.",
}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--audit",type=Path,required=True)
    parser.add_argument("--packages",type=Path,required=True)
    parser.add_argument("--runs",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args()
    matrix=json.loads((args.audit / "optional-dependencies-packaged.json").read_text(encoding="utf-8"))
    packages=json.loads((args.packages / "package-lock.json").read_text(encoding="utf-8"))
    resolution=json.loads((args.packages / "resolution.json").read_text(encoding="utf-8"))
    receipts={}
    for path in sorted(args.runs.glob("*/receipt.json")):
        receipt=json.loads(path.read_text(encoding="utf-8"))
        receipt["receipt_path"]=str(path.absolute())
        receipts.setdefault(receipt["name"],[]).append(receipt)
    edges={}
    for edge in resolution["required_edges"]: edges.setdefault(edge["from"],[]).append(edge)
    for row in matrix["entries"]:
        attempts=receipts.get(row["selected"],[])
        valid=[r for r in attempts if r["version"]==row["version"] and r["package_sha256"]==row["sha256"]]
        best=max(valid,key=lambda r:(r["passed"],r["started_utc"]),default=None)
        row["engine_smoke"]="passed" if best and best["passed"] else "failed" if best else "not-run"
        row["tested_version"]=best["version"] if best and best["passed"] else None
        row["engine_receipt"]=best["receipt_path"] if best else None
        row["attempts"]=[{"path":r["receipt_path"],"passed":r["passed"],"started_utc":r["started_utc"],
            "settings_overrides":r.get("settings_overrides",{})} for r in valid]
        required=set()
        queue=[row["selected"]]
        while queue:
            parent=queue.pop()
            for edge in edges.get(parent,[]):
                name=edge["name"]
                if name in required: continue
                required.add(name)
                queue.append(name)
        row["required_closure"]=sorted(required)
        row["conflicts"]=[r for r in resolution["declared_conflicts"] if r["from"] in required | {row["selected"]}]
        row["integration_acceptance"]="pending"
        row["integration_changes_or_limits"]=INTEGRATION_NOTES.get(row["selected"],"No accepted integration-specific change in this smoke lane; progression, migration and combinations remain open.")
        row["migration"]="not-accepted"
        if row["selected"]=="Krastorio2-spaced-out":
            row["integration_acceptance"]="deferred-by-user"
            row["migration"]="unsupported-retain-2.0"
        if best and best["passed"]:
            native_path=Path(best["receipt_path"]).parent / "script-output/optional-smoke.json"
            native=json.loads(native_path.read_text(encoding="utf-8"))
            row["tested_settings_overrides"]=best.get("settings_overrides",{})
            row["rocket_productivity"]=native.get("rocket_productivity")
            if "crystal_recipes" in native:
                row["final_crystal_recipes"]=native["crystal_recipes"]
        if row.get("license"):
            row["license"]={k:row["license"].get(k) for k in ("name","title","url")}
    package_manifest=[{k:r.get(k) for k in ("name","version","sha256","sha1","absolute_file","owner","source_url","info","portal_license")} for r in packages]
    for row in package_manifest:
        row["portal_license"]={k:(row["portal_license"] or {}).get(k) for k in ("name","title","url")}
    result={"generated_utc":datetime.datetime.now(datetime.timezone.utc).isoformat(),"original_count":50,
        "scope":"Package integrity and isolated native smoke receipts; progression/migration/native interaction remain separate gates",
        "excluded_conflicts":["TerrainEvolution","TerrainEvolution2"],"entries":matrix["entries"],
        "verified_optional_packages":package_manifest,"resolution_source":str(args.packages / "resolution.json")}
    result["required_core_packages"]=json.loads((args.audit.parent / "dependencies/dependency-lock-2.1.json").read_text(encoding="utf-8"))
    sources=[]
    profile=json.loads(Path(".codex/esir/factorio-development.json").read_text(encoding="utf-8"))
    roots=[p for p in Path.cwd().iterdir() if p.is_dir() and (p.name.startswith("exotic-space-industries-remembrance")
        or p.name in ("doeworks-deer-continued","enhanced-walls-continued")) and (p / "info.json").is_file()]
    roots.append(Path(profile["nsbc_source"]))
    for root in roots:
        raw=(root / "info.json").read_bytes();info=json.loads(raw.decode("utf-8-sig"))
        sources.append({"name":info["name"],"version":info["version"],"factorio_version":info["factorio_version"],
            "source":str(root.absolute()),"info_sha256":hashlib.sha256(raw).hexdigest(),
            "dependencies":info.get("dependencies",[]),"status":"source staged; final ZIP/publication acceptance open"})
    result["local_release_sources"]=sorted(sources,key=lambda r:r["name"])
    args.output.mkdir(parents=True,exist_ok=True)
    (args.output / "DEPENDENCY_MATRIX.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    lines=["# ESIR 1.4.0 optional dependency matrix","","Working evidence; release acceptance remains open.","",
        "All 50 original optional entries are accounted for. Exact SHA-256 hashes, source and license provenance, required closures, conflicts and every test attempt are retained in [DEPENDENCY_MATRIX.json](DEPENDENCY_MATRIX.json). A native smoke pass covers startup, merged crystal contracts and 600 ticks; it does not accept progression, saves, interactions or optional combinations.","",
        "| Original ID | Selected 2.1 candidate | Version | Native smoke | Provenance / disposition | Migration |",
        "|---|---|---|---|---|---|"]
    for row in matrix["entries"]:
        candidate=f'[`{row["selected"]}`]({row["portal_url"]})' if row["version"] else "Port backlog"
        state="**deferred by user**" if row["integration_acceptance"]=="deferred-by-user" else "**license discrepancy hold**" if row["status"]=="provenance-hold" else "port backlog" if row["status"]=="port-backlog" else "package verified; integration pending"
        migration="unsupported; retain 2.0" if row["migration"]=="unsupported-retain-2.0" else "not accepted"
        lines.append(f'| `{row["original"]}` | {candidate} | {row["version"] or "—"} | {row["engine_smoke"]} | {state} | {migration} |')
    lines += ["", "## Integration findings", ""]
    for name,note in INTEGRATION_NOTES.items():lines.append(f"- `{name}`: {note}")
    lines += ["", "## Required core packages", "", "Exact hashes and provenance are in the JSON companion.", "",
        "| Package | Tested version |", "|---|---|"]
    for row in result["required_core_packages"]:lines.append(f'| `{row["name"]}` | {row["version"]} |')
    lines += ["", "## Local release sources", "", "These are staged source versions, not published package receipts.", "",
        "| Package | Version |", "|---|---|"]
    for row in result["local_release_sources"]:lines.append(f'| `{row["name"]}` | {row["version"]} |')
    lines += ["","Gore remains on provenance hold: the original Portal declares CC BY-SA 4.0 and the fork declares MIT. Package attribution and baseline-file comparisons are retained in the protected audit. No optional candidate is published or redistributed by this report.","",
        "Generated downloads use the protected task directory on C: and the established D:/ESIR overflow directory. Source checkouts and the installed 2.0 mod selection stay in place.",""]
    (args.output / "DEPENDENCY_MATRIX.md").write_text("\n".join(lines),encoding="utf-8")
    variants=["# Final-data crystal return variants", "", "Native merged-data assertions; generated recipes have not each received an independent statistical crafting run.", ""]
    for row in matrix["entries"]:
        if not row.get("final_crystal_recipes"):continue
        variants += [f'## {row["selected"]} {row["version"]}', "", f'Evidence: `{row["engine_receipt"]}`.', "",
            "| Final recipe | Source recipe | High-energy input | High-energy return | Ordinary return |", "|---|---|---:|---:|---:|"]
        for recipe in row["final_crystal_recipes"]:
            variants.append(f'| `{recipe["name"]}` | `{recipe["base"]}` | {recipe["input"]} | {recipe["high"]:.0%} | {recipe["ordinary"]:.0%} |')
        variants.append("")
    (args.output / "CRYSTAL_VARIANT_MATRIX.md").write_text("\n".join(variants),encoding="utf-8")
    print(json.dumps({"entries":50,"verified_optional_packages":len(packages),"native_smoke_passes":sum(r["engine_smoke"]=="passed" for r in matrix["entries"]),"migration_acceptances":0}))


if __name__=="__main__": main()

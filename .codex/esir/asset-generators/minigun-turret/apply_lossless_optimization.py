"""Freeze a fresh compiled sibling after independently verifying lossless PNG outputs.

No existing source, render, shipping file, or native result is rewritten. Every
unchanged file, including native-reference atlases, is a SHA256-verified hardlink.
Replacement PNGs and metadata are new files, never writes through source links.
"""
import argparse
import copy
import hashlib
import io
import json
import math
import os
from pathlib import Path
import re
import struct
import zlib

SCHEMA="esir.minigun.applied-lossless-optimization.v1"
COLOR_CHUNKS={"sRGB","gAMA","cHRM"}


def require(condition,message):
    if not condition:
        raise ValueError(message)


def sha(value):
    return hashlib.sha256(value).hexdigest()


def file_sha(path):
    result=hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda:stream.read(1024*1024),b""):
            result.update(block)
    return result.hexdigest()


def color_chunks(payload):
    require(payload[:8]==b"\x89PNG\r\n\x1a\n","Expected a PNG")
    result={};offset=8;ended=False
    while offset<len(payload):
        require(offset+12<=len(payload),"Truncated PNG chunk")
        size=struct.unpack(">I",payload[offset:offset+4])[0]
        kind=payload[offset+4:offset+8];end=offset+12+size
        require(end<=len(payload),"Truncated PNG payload")
        value=payload[offset+8:offset+8+size]
        require(zlib.crc32(kind+value)&0xffffffff==struct.unpack(">I",payload[end-4:end])[0],"PNG CRC mismatch")
        name=kind.decode("ascii")
        if name in COLOR_CHUNKS:
            require(name not in result,"Duplicate PNG color profile chunk")
            result[name]=value.hex()
        offset=end
        if kind==b"IEND":
            ended=True
            break
    require(ended and offset==len(payload) and set(result)==COLOR_CHUNKS,"Missing/invalid PNG color profile")
    return result


def inspect_png(payload):
    from PIL import Image
    chunks=color_chunks(payload)
    with Image.open(io.BytesIO(payload)) as image:
        require(image.format=="PNG" and 0<min(image.size) and max(image.size)<=4096,"Invalid shipping PNG dimensions")
        mode=image.mode;size=list(image.size)
        rgba=image.convert("RGBA").tobytes()
    return {"mode":mode,"size":size,"decoded_rgba_sha256":sha(rgba),
            "decoded_rgba_bytes":len(rgba),"png_color_profile_chunks":chunks}


def repo_root():
    for root in Path(__file__).resolve().parents:
        if (root/"AGENTS.md").is_file() and (root/"scripts/invoke-esir-dev.ps1").is_file():
            return root
    raise ValueError("Run this repo-local tool from its canonical or ignored staging directory")


def leaf_paths(leaf):
    if "layers" in leaf:
        return [path for child in leaf["layers"] for path in leaf_paths(child)]
    require(bool(leaf.get("filename")) != bool(leaf.get("filenames")),"Expected one atlas filename representation")
    return [leaf["filename"]] if "filename" in leaf else leaf["filenames"]


def image_inventory(metadata):
    images={}
    for profile in ("sd","hd"):
        value=metadata["profiles"][profile]
        for family in ("base","upper","rotor","shadow"):
            record=value["families"][family]
            require(value["leaves"][family]==record["leaf"],"Leaf/family geometry differs")
            paths=leaf_paths(record["leaf"])
            records={row["name"]:row for row in record["files"]}
            require(len(records)==len(record["files"])==len(paths),"Duplicate or unowned family images")
            for path in paths:
                relative=Path(profile)/path
                require(Path(path).parts[0]=="images" and ".." not in relative.parts and not Path(path).is_absolute(),"Unconfined family filename")
                row=records.get(Path(path).name)
                require(row is not None and relative.as_posix() not in images,"Missing/duplicate shipping PNG")
                images[relative.as_posix()]={"profile":profile,"family":family,"record":row}
        for kind,row in value["icons"].items():
            path=Path(row["path"])
            require(path.parts[0]=="images" and ".." not in path.parts and not path.is_absolute(),"Unconfined icon filename")
            relative=(Path(profile)/path).as_posix()
            require(relative not in images,"Duplicate shipping icon")
            images[relative]={"profile":profile,"family":kind+"_icon","record":row}
    return images


def report_rows(reports,source,inventory,allow_aliases=False,allow_unmatched=False):
    selected,provenance,skipped={},[],[]
    for report_path in sorted({Path(path).resolve() for path in reports},key=str):
        payload=report_path.read_bytes();report=json.loads(payload)
        require(report.get("schema")=="esir.minigun.png-optimization.v1" and report.get("zopfli_version")=="0.4.0"
                and re.fullmatch(r"[0-9a-f]{64}",report.get("generator_sha256","")) is not None,"Unknown optimization report provenance")
        provenance.append({"path":str(report_path),"sha256":sha(payload),"optimizer_sha256":report["generator_sha256"],
            "zopfli_version":report["zopfli_version"],"filters_only":report["filters_only"],"iterations":report["iterations"]})
        for index,row in enumerate(report["files"]):
            original=Path(row["source"]).resolve()
            if original.is_relative_to(source):
                relative=original.relative_to(source).as_posix()
            else:
                relative=Path(*original.parts[-3:]).as_posix()
                if relative not in inventory and allow_unmatched:
                    skipped.append({"report":str(report_path),"row":index,"source":str(original),"reason":"not a PNG owned by this compiled metadata"})
                    continue
                require(allow_aliases,"Report source is not this compiled tree; identical aliases require explicit permission")
            if relative not in inventory:
                require(allow_unmatched,"Report includes an unowned/nonshipping PNG: "+relative)
                skipped.append({"report":str(report_path),"row":index,"source":str(original),"reason":"not a PNG owned by this compiled metadata"})
                continue
            target=source/relative
            record=inventory[relative]["record"]
            require(row.get("decoded_rgba_equal") is True and row.get("color_chunks_equal") is True,
                    "Optimizer did not declare exact decoded pixels/profile")
            require(row.get("source_sha256")==record["sha256"] and row.get("before_bytes")==record["bytes"]
                    and original.is_file() and original.stat().st_size==record["bytes"] and file_sha(original)==record["sha256"],
                    "Optimization input does not match the frozen compiler/source bytes: "+relative)
            optimized=Path(row["output"]).resolve()
            require(optimized!=target and optimized.is_file() and optimized.stat().st_size==row["after_bytes"]
                    and file_sha(optimized)==row["sha256"] and row["after_bytes"]<=row["before_bytes"],
                    "Optimized PNG is missing, changed, larger, or overwrites its input")
            choice={**row,"source":str(original),"output":str(optimized),"relative":relative,
                "report":str(report_path),"report_row":index,"source_alias":original!=target}
            previous=selected.get(relative)
            if previous is None or (choice["after_bytes"],choice["sha256"],choice["output"]) < (previous["after_bytes"],previous["sha256"],previous["output"]):
                selected[relative]=choice
    require(set(selected)==set(inventory),"Optimization reports do not cover every shipping PNG; missing="+repr(sorted(set(inventory)-set(selected))))
    return selected,provenance,skipped


def apply(compiled,output,reports,allow_aliases=False,allow_unmatched=False):
    source=Path(compiled).resolve();destination=Path(output).resolve();allowed=repo_root()/"output"
    require(source.is_relative_to(allowed) and destination.is_relative_to(allowed) and source.is_dir(),"Compiled/output roots must be ignored repo output directories")
    require(source!=destination and source.parent==destination.parent and not destination.exists(),"Output must be a fresh absent sibling of compiled input")
    source_meta=(source/"metadata.json").read_bytes();metadata=json.loads(source_meta)
    require(metadata.get("schema")=="esir.minigun.separated.compiled.v2" and not metadata.get("lossless_optimization"),
            "Expected a raw compiler result without applied optimization")
    directions=metadata.get("direction_indices")
    require(directions in (list(range(0,256,32)),list(range(256))) and metadata.get("physical_pose_count")==28,
            "Expected real pilot8 or complete256 physical families")
    require(metadata.get("complete_direction_family")==(len(directions)==256),"Incorrect complete family flag")
    signature=json.loads((source/"compile-input.json").read_bytes())
    require(signature.get("configuration_hash")==metadata["configuration_hash"] and signature.get("directions")==directions,
            "Compiler signature and metadata differ")
    inventory=image_inventory(metadata)
    references={}
    for name in ("sd","hd"):
        reference=metadata["profiles"][name]["native_reference"]
        reference_root=Path(reference["root"])
        require(not reference_root.is_absolute() and ".." not in reference_root.parts
                and reference_root.parts[0]=="native-reference","Unconfined native reference directory")
        records={row["name"]:row for row in reference["files"]}
        paths=leaf_paths(reference["leaf"])
        require(len(paths)==len(records),"Native-reference file ledger is incomplete")
        for relative in paths:
            path=(source/reference_root/relative).resolve()
            require(path.is_relative_to(source) and path.is_file(),"Missing native reference atlas")
            record=records[Path(relative).name]
            require(path.stat().st_size==record["bytes"] and file_sha(path)==record["sha256"],"Native reference changed before linking")
            references[path.relative_to(source).as_posix()]=record["sha256"]
    choices,report_provenance,skipped=report_rows(reports,source,inventory,allow_aliases,allow_unmatched)
    inspected,changes={},[]
    for relative,value in sorted(inventory.items()):
        original=source/relative;record=value["record"];choice=choices[relative]
        before=original.read_bytes();after=Path(choice["output"]).read_bytes()
        require(sha(before)==record["sha256"] and len(before)==record["bytes"],"Compiled PNG changed: "+relative)
        before_info=inspect_png(before);after_info=inspect_png(after)
        expected_size=[record["size"],record["size"]] if isinstance(record["size"],int) else record["size"]
        require(before_info["size"]==expected_size and before_info["png_color_profile_chunks"]==metadata["png_color_profile_chunks"],
                "Original PNG disagrees with frozen dimensions/profile")
        require(before_info["decoded_rgba_sha256"]==after_info["decoded_rgba_sha256"]
                and before_info["size"]==after_info["size"]
                and before_info["png_color_profile_chunks"]==after_info["png_color_profile_chunks"],
                "Optimizer changed decoded RGBA (including hidden RGB), dimensions, or sRGB/gAMA/cHRM: "+relative)
        require(record.get("decoded_rgba_exact") is True,"Compiler image has no exact-pixel declaration")
        inspected[relative]=after_info
        changes.append({"relative":relative,"profile":value["profile"],"family":value["family"],
            "source_sha256":sha(before),"sha256":sha(after),"before_bytes":len(before),"after_bytes":len(after),
            "decoded_rgba_sha256":after_info["decoded_rgba_sha256"],"decoded_rgba_equal":True,"color_chunks_equal":True,
            "source_mode":before_info["mode"],"mode":after_info["mode"],"size":after_info["size"],
            "optimization_report":choice["report"],"optimization_report_row":choice["report_row"],
            "optimization_source_alias":choice["source_alias"]})
        record.update(bytes=len(after),sha256=sha(after),mode=after_info["mode"],
                      decoded_rgba_sha256=after_info["decoded_rgba_sha256"],decoded_rgba_exact=True)
    for name in ("sd","hd"):
        profile=metadata["profiles"][name]
        for family in profile["families"].values():
            family["bytes"]=sum(row["bytes"] for row in family["files"])
        icons=sum(row["bytes"] for row in profile["icons"].values())
        profile["png_bytes"]=icons+sum(row["bytes"] for row in profile["families"].values())
        profile["projected_256_png_bytes"]=math.ceil(icons+profile["families"]["base"]["bytes"]+
            sum(profile["families"][family]["bytes"]*256/len(directions) for family in ("upper","rotor","shadow")))
    prior_budget=metadata.get("budget")
    metadata["budget"]={"schema":"esir.minigun.compiled-png-budget.v1","archive_cap_bytes":256000000,
        "sd_projected_png_bytes":metadata["profiles"]["sd"]["projected_256_png_bytes"],
        "hd_projected_png_bytes":metadata["profiles"]["hd"]["projected_256_png_bytes"],
        "allowance_fraction":.15,"projection_is_estimate":len(directions)!=256,
        "png_proxy_only":True,"includes_archive_metadata_or_zip_overhead":False,"release_gate":False,
        "scope":"Updated PNG totals only; use current G6/HD budget and actual archive builders for per-pack acceptance"}
    metadata["lossless_optimization"]={"schema":SCHEMA,"input_root":str(source),"input_metadata_sha256":sha(source_meta),
        "compiler_signature_sha256":file_sha(source/"compile-input.json"),"compiler_sha256":signature["script_sha256"],
        "applier_sha256":file_sha(Path(__file__)),"reports":report_provenance,"shipping_pngs":changes,
        "complete_shipping_coverage":True,"unmatched_report_rows":skipped,"prior_budget":prior_budget,
        "native_evidence_inherited":False,"layout_trials_are_pre_optimization_measurements":True}
    for key in ("native_load_tested","native_filtered_seams_tested","production_promoted"):
        metadata[key]=False
    # Validate everything before creating a new directory. Files replaced below
    # are never first linked to the input: writing through a link would mutate it.
    source_files=[]
    for path in sorted(source.rglob("*")):
        require(not path.is_symlink() and not (hasattr(path,"is_junction") and path.is_junction()),"Input tree contains a reparse point")
        if path.is_file():
            relative=path.relative_to(source).as_posix()
            require(relative not in ("lossless-optimization.json","optimization-input-metadata.json","APPLY-INCOMPLETE.json"),"Reserved optimization output already exists")
            expected=file_sha(path)
            if relative in choices:
                require(expected==choices[relative]["source_sha256"],"Compiled image changed after validation")
            if relative in references:
                require(expected==references[relative],"Native reference changed after validation")
            source_files.append((path,relative,expected))
    destination.mkdir()
    marker=destination/"APPLY-INCOMPLETE.json"
    marker.write_text(json.dumps({"schema":SCHEMA,"source":str(source),"status":"incomplete"})+"\n",encoding="utf-8")
    clone=[]
    for path,relative,expected in source_files:
        target=destination/relative;target.parent.mkdir(parents=True,exist_ok=True)
        if relative=="metadata.json":
            continue
        if relative in choices:
            payload=Path(choices[relative]["output"]).read_bytes()
            require(sha(payload)==choices[relative]["sha256"],"Optimized file changed during apply")
            with target.open("xb") as stream:
                stream.write(payload)
            mode="new-optimized-file"
        else:
            os.link(path,target)
            mode="sha256-verified-hardlink"
            require(os.path.samefile(path,target) and file_sha(target)==expected,"Hardlink verification failed")
        require(file_sha(path)==expected,"Source changed while cloning; incomplete clone retained")
        clone.append({"path":relative,"source_sha256":expected,"sha256":file_sha(target),"method":mode,
                      "native_reference":relative.startswith("native-reference/")})
    require((source/"metadata.json").read_bytes()==source_meta,"Source metadata changed during apply")
    payload=(json.dumps(metadata,indent=2)+"\n").encode()
    (destination/"metadata.json").write_bytes(payload)
    (destination/"optimization-input-metadata.json").write_bytes(source_meta)
    report={"schema":SCHEMA,"source":str(source),"output":str(destination),"input_metadata_sha256":sha(source_meta),
        "metadata_sha256":sha(payload),"applier_sha256":file_sha(Path(__file__)),"reports":report_provenance,
        "shipping_pngs":changes,"clone_files":clone,"complete_shipping_coverage":True,"production_approved":False,
        "native_evidence_inherited":False,"unmatched_report_rows":skipped,
        "profile_png_bytes":{name:metadata["profiles"][name]["png_bytes"] for name in ("sd","hd")},
        "profile_projected_256_png_bytes":{name:metadata["profiles"][name]["projected_256_png_bytes"] for name in ("sd","hd")}}
    (destination/"lossless-optimization.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    marker.unlink()
    return report


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiled",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--reports",type=Path,nargs="+",required=True)
    parser.add_argument("--allow-identical-source-aliases",action="store_true",help="Diagnostic reuse only: require identical actual source bytes and relative profile/image path")
    parser.add_argument("--allow-unmatched-report-rows",action="store_true",help="Retain an explicit ledger of ignored report images not owned by this compiled tree")
    args=parser.parse_args()
    result=apply(args.compiled,args.output,args.reports,args.allow_identical_source_aliases,args.allow_unmatched_report_rows)
    print(json.dumps({key:result[key] for key in ("output","metadata_sha256","profile_png_bytes","profile_projected_256_png_bytes","production_approved")}))

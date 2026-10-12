"""Native shadow-union comparisons, with independently calibrated alpha units."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil

import numpy as np
from PIL import Image
from capture_geometry import METHOD, UNITS, inspect as inspect_geometry, finish as finish_geometry
from evidence_contract import verify_inputs, verify_native_policy, verify_capture, expected_cases


def fs_path(path):
    """Use the Win32 extended namespace only at filesystem access boundaries."""
    path=Path(path)
    if os.name!="nt":return path
    absolute=os.path.abspath(path)
    if absolute.startswith("\\\\?\\"):return Path(absolute)
    if absolute.startswith("\\\\"):return Path("\\\\?\\UNC\\"+absolute[2:])
    return Path("\\\\?\\"+absolute)


def analyze(run, output):
    report=json.loads((run/"script-output/minigun-native-shadow-report.json").read_text(encoding="utf-8-sig"))
    inputs=json.loads((run/"mods/zzz-esir-minigun-shadow/shadow-input-manifest.json").read_text(encoding="utf-8-sig"))
    log=(run/"graphics.log").read_text(encoding="utf-8-sig",errors="replace")
    match=re.search(r"\[DXT: ([^\]]+)\]",log)
    compression=match.group(1) if match else None
    failures=list(report["errors"])
    strict = bool(inputs.get("source_proof_sha256"))
    if inputs.get("source_direction_count",8) == 256 and not strict:
        failures.append("Final256 lacks independently verified complete source shadows")
    source_verified = False
    policy = {"native_shadow_policy_verified":False,"observed_atlas_flags":[],"matched_shadow_atlas_flags":[],"shadow_leaf_count":0}
    if strict:
        try:
            verify_inputs(run/"mods/zzz-esir-minigun-shadow",inputs)
            source_verified = True
            policy = verify_native_policy(inputs,report,log)
        except (ValueError,KeyError,OSError,TypeError) as error:
            failures.append("Shadow provenance/native policy: " + str(error))
        if report.get("cases") != inputs["controls"]+inputs["cases"]:
            failures.append("Native cases differ from the exact staged matrix and controls")
        if (report.get("rgb_max_allowance"),report.get("rgb_rms_allowance"),report.get("equivalent_alpha_max_allowance")) != (2,.25,6):
            failures.append("Native shadow error allowances changed")
    if report.get("capture_geometry") != METHOD or inputs.get("capture_geometry") != METHOD:
        failures.append("Capture geometry predates the actual-position camera contract")
    if report.get("offset_units") != UNITS or inputs.get("offset_units") != UNITS:
        failures.append("Capture geometry does not declare engine-native pixel units")
    if report["matrix"] != inputs["matrix"] or report["matrix"] not in ("smoke","full"):
        failures.append("Native report matrix does not match the staged shadow matrix")
    if compression != inputs["texture_compression"]:
        failures.append("Engine texture compression does not match the staged shadow fixture")
    output.mkdir(parents=True,exist_ok=True)
    captures={}
    for capture in report["captures"]:
        key=(capture["case_id"],capture["variant"])
        if key in captures:
            failures.append("Duplicate screenshot: "+str(key))
        captures[key]=capture

    def read(case_id,variant):
        capture=captures[(case_id,variant)]
        path=run/"script-output"/capture["path"]
        with Image.open(path) as image:
            return np.asarray(image.convert("RGB"),dtype=np.int16),hashlib.sha256(path.read_bytes()).hexdigest()

    calibrated=True
    calibration={}
    calibration_regions={}
    for case_id in ("control-background","control-full","control-mid"):
        if (case_id,"reference") not in captures:
            failures.append("Missing native shadow calibration: "+case_id)
            calibrated=False
            continue
        array,_=read(case_id,"reference")
        y,x=np.array(array.shape[:2])//2
        region=array[y-8:y+8,x-8:x+8]
        calibration[case_id]=np.median(region,axis=(0,1))
        spread=int(np.max(region.max(axis=(0,1))-region.min(axis=(0,1))))
        calibration_regions[case_id]={"xyxy":[int(x-8),int(y-8),int(x+8),int(y+8)],"maximum_rgb_spread":spread}
        if region.shape != (16,16,3) or spread != 0:
            failures.append("Shadow calibration ROI is not a uniform interior: "+case_id)
            calibrated=False
    denominator=np.ones(3)*255
    mid_error=None
    if calibrated:
        denominator=calibration["control-background"]-calibration["control-full"]
        mid_expected=calibration["control-background"]-denominator*(128/255)
        mid_error=float(np.abs(calibration["control-mid"]-mid_expected).max())
        calibrated=bool(np.all(denominator>=10) and mid_error<=2)
    if not calibrated:
        failures.append("Shadow opacity is absent or native alpha calibration is not linear within two RGB codes")
    safe_denominator=np.maximum(denominator,1)
    results=[]
    geometry_groups={}
    for case in report["cases"]:
        case_id=case["id"]
        if any((case_id,variant) not in captures for variant in ("separated","reference")):
            failures.append("Missing shadow pair: "+case_id)
            continue
        a,ah=read(case_id,"separated")
        b,bh=read(case_id,"reference")
        pair=[captures[(case_id,variant)] for variant in ("separated","reference")]
        if strict:
            try:
                verify_capture(case,pair,inputs["reference_selection"])
            except (ValueError,TypeError) as error:
                failures.append(str(error))
        if a.shape!=b.shape or list(reversed(a.shape[:2]))!=case["resolution"]:
            failures.append("Mismatched shadow screenshot bounds: "+case_id)
            continue
        failures.extend(inspect_geometry(case,pair,b,geometry_groups,report["matrix"]))
        if pair[0].get("orientation")!=pair[1].get("orientation") or pair[0].get("position")!=pair[1].get("position"):
            failures.append("Native shadow pair registration differs: "+case_id)
        signed=a-b
        difference=np.abs(signed)
        pixel=difference.max(axis=2)
        maximum=int(difference.max())
        rms=float(np.sqrt(np.mean(difference.astype(np.float64)**2)))
        equivalent=float((difference.astype(np.float64)*255/safe_denominator).max())
        edges=np.concatenate((pixel[:2].reshape(-1),pixel[-2:].reshape(-1),pixel[:,:2].reshape(-1),pixel[:,-2:].reshape(-1)))
        reference_border=np.concatenate((b[:2].reshape(-1,3),b[-2:].reshape(-1,3),b[:,:2].reshape(-1,3),b[:,-2:].reshape(-1,3)))
        background=np.median(reference_border,axis=0)
        reference_border_deviation=int(np.max(np.abs(reference_border-background)))
        foreground=int(np.count_nonzero(np.max(background-b,axis=2)>4))
        control="control_alpha" in case
        passed=(maximum<=report["rgb_max_allowance"] and rms<=report["rgb_rms_allowance"]
                and equivalent<=report["equivalent_alpha_max_allowance"] and int(edges.max())==0 and reference_border_deviation<=1)
        if control:
            passed=maximum==0
        elif foreground<max(16,8*case["zoom"]**2):
            passed=False
        heatmap=None
        if maximum:
            path=output/"differences"/(case_id+".png")
            path.parent.mkdir(exist_ok=True)
            heat=np.zeros((*pixel.shape,3),dtype=np.uint8)
            heat[:,:,0]=np.clip((-signed).max(axis=2)*8,0,255)
            heat[:,:,2]=np.clip(signed.max(axis=2)*8,0,255)
            Image.fromarray(heat).save(path,optimize=True)
            heatmap=path.relative_to(output).as_posix()
        if control and not passed:
            failures.append("Identical native shadow control pair differs: "+case_id)
        results.append({**case,"passed":passed,"max_rgb_error":maximum,"rms_rgb_error":rms,
                        "max_equivalent_alpha_error":equivalent,"maximum_extra_darkening_rgb":max(0,int((-signed).max())),
                        "maximum_missing_darkening_rgb":max(0,int(signed.max())),"reference_shadow_pixels":foreground,
                        "registration_border_error":int(edges.max()),"heatmap":heatmap,
                        "reference_border_deviation":reference_border_deviation,
                        "pixels_above_error":{str(level):int(np.count_nonzero(pixel>level)) for level in (0,1,2,8,32,64)},
                        "screenshots_sha256":{"separated":ah,"reference":bh}})
    expected=inputs["comparison_cases"]+len(inputs["controls"])
    if len(results)!=expected or len(captures)!=expected*2:
        failures.append("Incomplete native shadow matrix")
    geometry,geometry_failures=finish_geometry(geometry_groups,report["matrix"])
    failures.extend(geometry_failures)
    geometry["passed"]=geometry["passed"] and not any("geometry" in failure or "registration" in failure for failure in failures)
    tier_results={}
    for tier in inputs["tiers"]:
        rows=[row for row in results if row["tier"]==tier["id"]]
        wanted=sum(case["tier"]==tier["id"] for case in inputs["cases"])
        required_count=sum(key[0] == tier["id"] for key in expected_cases(inputs))
        passed=len(rows)==wanted==required_count and all(row["passed"] for row in rows)
        tier_results[tier["id"]]={"passed":passed,"native_eligible":False,"mandatory":tier["mandatory"],
            "representation":tier.get("representation", "separated"),
            "reference_profile":tier["reference"],"families":{"base":tier["base"],"upper":tier["upper"],"rotor":tier["shadow"]},
            "comparison_cases":len(rows),"failed_cases":[row["id"] for row in rows if not row["passed"]],
            "max_rgb_error":max((row["max_rgb_error"] for row in rows),default=None),
            "max_equivalent_alpha_error":max((row["max_equivalent_alpha_error"] for row in rows),default=None),
            "maximum_case_rms_rgb_error":max((row["rms_rgb_error"] for row in rows),default=None)}
        if not passed and (tier["mandatory"] or len(inputs["tiers"])==1):
            failures.append("Required native shadow tier failed: "+tier["id"])
    source_pass=all(row["passed"] for row in inputs["source_alpha"].values())
    if not source_pass:
        failures.append("Source alpha reconstruction exceeded one code value")
    for tier in tier_results.values():
        tier["native_eligible"]=bool(not failures and tier["passed"] and report["matrix"]=="full"
                                     and compression=="none" and calibrated and source_pass)
        # Preserve the existing uncompressed mathematical verdict. HQ is a
        # separate qualification of the unchanged native alpha-mask policy.
        tier["final_policy_qualified"]=bool(not failures and tier["passed"] and report["matrix"]=="full"
            and inputs.get("source_direction_count")==256 and compression=="high-quality"
            and calibrated and source_pass and source_verified and policy["native_shadow_policy_verified"])
    summary={"schema":"esir.minigun.native-shadow-evidence.v1","matrix":report["matrix"],"run":str(run),
             "candidate_metadata_sha256":inputs["candidate_metadata_sha256"],
             "reference_metadata_sha256":inputs["reference_metadata_sha256"],
             "source_direction_count":inputs.get("source_direction_count",8),
             "tested_direction_indices":inputs.get("tested_direction_indices",sorted({row["direction"] for row in inputs["cases"]})),
             "selected_profiles":inputs.get("selected_profiles",["sd","hd"]),
             "reference_selection":inputs.get("reference_selection","full"),
             "source_proof_sha256":inputs.get("source_proof_sha256"),
             "source_cells_verified":source_verified,"staged_files_verified":source_verified,
             "reference_selection_verified":source_verified,
             "reference_cells_sha256":inputs.get("reference_cells_sha256"),
             "input_manifest_sha256":hashlib.sha256((run/"mods/zzz-esir-minigun-shadow/shadow-input-manifest.json").read_bytes()).hexdigest(),
             "shadow_texture_policy":inputs.get("shadow_texture_policy","native-shadow-default"),
             "comparison_pairs":len(results),"expected_comparison_pairs":expected,
             **policy,
             "automated_checks_passed":not failures,"failures":failures,"tiers":tier_results,
             "capture_geometry":geometry,
             "offset_units":UNITS,
             "optional_tiers_rejected":[name for name,row in tier_results.items() if not row["mandatory"] and not row["passed"]],
             "texture_compression_observed":compression,"texture_compression_requested":inputs["texture_compression"],
             "source_alpha":inputs["source_alpha"],"source_alpha_max_allowance":1,
             "native_rgb_max_allowance":report["rgb_max_allowance"],"native_rgb_rms_allowance":report["rgb_rms_allowance"],
             "native_equivalent_alpha_max_allowance":report["equivalent_alpha_max_allowance"],
             "alpha_calibration":{"passed":calibrated,"reference_rgb":{name:value.tolist() for name,value in calibration.items()},"regions":calibration_regions,
                 "darkening_at_alpha255_rgb":denominator.tolist(),"midpoint_error_rgb":mid_error,
                 "method":"Calibrated equivalent alpha units from native background and alpha255 controls; not direct framebuffer alpha"},
             "cases":results,"production_approved":False,
             "review_required":["Inspect worst native shadows/heatmaps for overlap darkening, missing coverage or filtering seams",
                 "Mixed tiers use complete density families; a failed naive mixture requires a newly derived residual and fresh hash-bound evidence",
                 "Run high-quality texture compression separately after the uncompressed mathematical gate"],
             "analyzer_sha256":hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
    (output/"summary.json").write_text(json.dumps(summary,indent=2)+"\n",encoding="utf-8")
    for name,value in (("native-report.json",report),("shadow-input-manifest.json",inputs)):
        (output/name).write_text(json.dumps(value,indent=2)+"\n",encoding="utf-8")
    shutil.copyfile(__file__,output/"analyzer-source.py")
    shutil.copyfile(Path(__file__).with_name("capture_geometry.py"),output/"capture_geometry.py")
    for name in ("source_proof.py","evidence_contract.py"):
        shutil.copyfile(Path(__file__).with_name(name),output/name)
    if strict:
        for name in ("source-shadow-proof.json","candidate-metadata.json","reference-metadata.json"):
            shutil.copyfile(run/"mods/zzz-esir-minigun-shadow"/name,output/name)
    shutil.copytree(fs_path(run/"script-output/minigun-native-shadow"),fs_path(output/"screenshots"),dirs_exist_ok=True)
    return summary


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args()
    result=analyze(args.run,args.output)
    print(json.dumps({key:result[key] for key in ("automated_checks_passed","failures","optional_tiers_rejected","production_approved")}))
    raise SystemExit(0 if result["automated_checks_passed"] else 2)

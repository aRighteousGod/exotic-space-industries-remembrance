"""Offline lifecycle checks and immutable retention; image review stays explicit."""
import argparse
import copy
import hashlib
import json
import math
import os
from pathlib import Path, PurePosixPath
import shutil

import numpy as np
from PIL import Image

from evidence_contract import (fs_path, sha, canonical_sha, verify_candidate_asset_manifest,
                               retain_candidate_assets)

PHASES = {"preparing": {1}, "running": {2, 3, 4, 5}, "folding": {7}}
KINDS = ["save_load", "ammo_shortage", "energy_shortage", "script_disable", "circuit_disable", "freeze_thaw"]
EXPECTED = {kind + "/" + phase for kind in KINDS for phase in PHASES}


def read(path):
    return json.loads(fs_path(path).read_text(encoding="utf-8-sig"))


def reference(path):
    return {"path": str(Path(path).resolve()), "sha256": sha(path)}


def retain(source, target):
    source, target = fs_path(source), fs_path(target)
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        if sha(source) != sha(target):
            raise ValueError("Refusing to overwrite retained bytes: " + str(target))
        return
    try:
        os.link(source, target)
    except OSError:
        shutil.copyfile(source, target)
    if sha(source) != sha(target):
        raise ValueError("Retention changed evidence bytes")


def capture_path(root, name):
    pure = PurePosixPath(name)
    if pure.is_absolute() or ".." in pure.parts or "\\" in name or not name.startswith("minigun-lifecycle/"):
        raise ValueError("Unsafe native capture path")
    return fs_path(root).joinpath(*pure.parts)


def decode(path):
    pixels = np.asarray(Image.open(fs_path(path)).convert("RGB"))
    if pixels.shape != (384, 256, 3):
        raise ValueError("Unexpected native screenshot geometry")
    patch = pixels[260:330, 80:176].astype(np.int16)
    magenta = (patch[:, :, 0] > 220) & (patch[:, :, 1] < 50) & (patch[:, :, 2] > 220)
    candidates = []
    for y in range(patch.shape[0]-11):
        for x in range(patch.shape[1]-63):
            if not magenta[y:y+12, x:x+6].all():
                continue
            cyan = patch[y:y+12,x+58:x+64]
            if not ((cyan[:,:,0]<50)&(cyan[:,:,1]>220)&(cyan[:,:,2]>220)).all():
                continue
            state=0
            for bit in range(3):
                region=patch[y+3:y+9,x+14+bit*14:x+20+bit*14]
                if (region > 220).all(): state |= 1<<bit
                elif not (region < 50).all(): raise ValueError("Ambiguous native state barcode bit")
            candidates.append((x+80,y+260,state))
    if len(candidates) != 1:
        raise ValueError("Native state barcode is missing/ambiguous: " + repr(candidates))
    return {"origin":list(candidates[0][:2]),"state":candidates[0][2]}


def combat_audit(audit):
    original, candidate = audit["original"], audit["candidate"]
    graphics = {"name","minable","graphics_set","base_picture","turret_base_has_direction",
        "gun_animation_render_layer","gun_animation_secondary_draw_order","folded_animation",
        "preparing_animation","prepared_animation","attacking_animation","folding_animation",
        "starting_attack_animation","ending_attack_animation","preparing_speed","preparing_speed_secondary",
        "folding_speed","folding_speed_secondary","attack_parameters","circuit_connector"}
    errors=[]
    if {k:v for k,v in original.items() if k not in graphics} != {k:v for k,v in candidate.items() if k not in graphics}:
        errors.append("Candidate changed non-graphics turret behavior")
    launch={"projectile_creation_parameters","projectile_center","projectile_creation_distance",
            "apply_projection_to_projectile_creation_position","shell_particle"}
    if {k:v for k,v in original["attack_parameters"].items() if k not in launch} != {
            k:v for k,v in candidate["attack_parameters"].items() if k not in launch}:
        errors.append("Range, damage, ammunition or attack mechanics changed")
    observed=copy.deepcopy(audit["instrumented_ammo_type"])
    kinds=[observed] if "action" in observed else observed
    for kind in kinds:
        action=kind.get("action")
        if not action: continue
        if isinstance(action,dict): action=[action]
        filtered=[a for a in action if not (isinstance(a.get("action_delivery"),dict) and
                  a["action_delivery"].get("source_effects") == [{"type":"script","effect_id":"mg-lifecycle-shot"}])]
        kind["action"]=filtered
    baseline=copy.deepcopy(audit["original_ammo_type"])
    for kind in ([baseline] if "action" in baseline else baseline):
        if isinstance(kind.get("action"),dict): kind["action"]=[kind["action"]]
    if observed != baseline or audit.get("observer_count") != 1:
        errors.append("Private observer changed an authored ammunition effect/damage delivery")
    return errors


def row_checks(row, baseline, resumes, decoded):
    failures=list(row.get("failures",[]))
    events={event["kind"]:event for event in row["events"]}
    effect=events.get("effective_interruption")
    recovery=events.get("effective_recovery")
    command=events.get("intervention_command")
    if not (effect and recovery and command):
        return failures+["Native interruption/recovery event is missing"]
    phase_tick=effect["tick"]-1
    # Freeze/circuit use their observed actual flag transition, not the earlier
    # request tick. This can reject a poorly calibrated thermal/circuit delay.
    proof=decoded.get((row["id"],"baseline",phase_tick))
    if not proof or proof["state"] not in PHASES[row["phase"]]:
        failures.append("Actual interruption did not occur in the requested visible native phase")
    if row["inserted"]-row["removed"]-row["remaining"] != row["shots"]:
        failures.append("Source observer and ammunition consumption disagree")
    snapshots={value["tick"]:value for value in row["observations"]}
    blocked=[value for tick,value in snapshots.items() if effect["tick"]+2<=tick<events["recovery_command"]["tick"]]
    if row["kind"] != "save_load":
        if len(blocked)<60: failures.append("Native interruption was not held for a measured 60-tick interval")
        if any(effect["tick"]+2<=tick<events["recovery_command"]["tick"] for tick in row["shot_ticks"]):
            failures.append("Native turret fired while the resource/disable/freeze condition was held")
        field={"ammo_shortage":"ammo","energy_shortage":"energy","script_disable":"disabled_by_script",
               "circuit_disable":"disabled_by_control_behavior","freeze_thaw":"frozen"}[row["kind"]]
        if field in ("ammo","energy"):
            if any(value[field] != 0 for value in blocked): failures.append("Withheld native resource was restored prematurely")
        elif any(value[field] is not True for value in blocked): failures.append("Native disabled/frozen flag was not actually held")
        if row["kind"]=="freeze_thaw" and any(value["is_freezable"] is not True for value in blocked):
            failures.append("Freezing case was not a freezable native entity")
    if not any(recovery["tick"]<=tick<=recovery["tick"]+80 for tick in row["shot_ticks"]):
        failures.append("Native shots did not resume after restoration/reacquisition")
    if row["kind"]=="save_load":
        report=resumes.get(row["phase"])
        candidates=[case for case in report.get("cases",[]) if case["id"]==row["id"]] if report else []
        if len(candidates)!=1: return failures+["Exact mid-state checkpoint was not resumed"]
        resumed=candidates[0]
        if resumed.get("resumed") is not True: failures.append("Replay did not execute the on_load/next-tick resume boundary")
        if resumed.get("failures"): failures.append("Resumed case reported a native failure")
        resume_event=next((value for value in resumed["events"] if value["kind"]=="resumed_on_tick"),None)
        if not resume_event or resume_event["tick"]!=row["checkpoint"]["tick"]+1:
            failures.append("Replay did not start on the tick after the exact checkpoint")
        keys=("unit_number","ammo","shots","orientation","active","disabled_by_script","disabled_by_control_behavior","frozen")
        checked=0
        for actual in resumed["observations"]:
            if actual.get("epoch") != "resume-"+row["phase"]: continue
            expected=snapshots.get(actual["tick"])
            if not expected or any(actual.get(key)!=expected.get(key) for key in keys):
                failures.append("Mid-state replay diverged from its uninterrupted native timeline");break
            if not math.isclose(actual["energy"],expected["energy"],rel_tol=1e-12,abs_tol=1e-6):
                failures.append("Mid-state replay changed native electrical energy");break
            checked+=1
        if checked<60: failures.append("Fewer than 60 resumed native snapshots were compared")
        if resumed["shot_ticks"]!=row["shot_ticks"]:
            failures.append("Save/load changed the exact native shot tick sequence")
    return failures


def analyze(run, output, helper):
    output=Path(output).resolve()
    if output.exists(): raise ValueError("Use a new retained analysis directory; existing evidence is immutable")
    plan=read(helper/"fixture-plan.json")
    manifest=read(helper/"candidate-assets-manifest.json")
    verify_candidate_asset_manifest(manifest,helper/"candidate-graphics-data.lua",helper/"candidate")
    raw=run/"script-output"
    baseline=read(raw/"minigun-lifecycle-baseline.json")
    resumes={phase:read(raw/("minigun-lifecycle-resume-"+phase+".json")) for phase in PHASES}
    errors=[]
    for name,digest in plan["config"]["fixture_sources_sha256"].items():
        if Path(name).name!=name or sha(helper/name)!=digest:
            errors.append("Fixture source changed after immutable staging: "+name)
    stage=read(run/"lifecycle-stage.json")
    repo=Path(stage["record"]["repo_root"])
    for name,digest in stage["source_hashes"].items():
        if sha(repo/name).lower()!=digest.lower():errors.append("Production source changed during native lifecycle execution: "+name)
    for report in [baseline,*resumes.values()]:
        if report.get("engine_version")!="2.0.77" or report.get("config")!=plan["config"] or report.get("lineage")!=plan["config"]["lineage"]:
            errors.append("Native runtime does not match exact staged engine/config/lineage")
        errors.extend(str(item) for item in report.get("errors",[]))
        if report.get("prototype_audit")!=baseline.get("prototype_audit"):
            errors.append("Effective native prototypes changed across save/load replay")
    audit=baseline["prototype_audit"]
    errors.extend(combat_audit(audit))
    if audit.get("actual_profile")!=plan["config"]["profile"]:errors.append("Wrong native SD/HD profile was loaded")
    rows=[row for row in baseline["cases"] if row["kind"]!="parity"]
    if len(rows)!=18 or {row["id"] for row in rows}!=EXPECTED:errors.append("Incomplete/duplicate native lifecycle matrix")
    parity=[row for row in baseline["cases"] if row["kind"]=="parity"]
    if len(parity)!=2:errors.append("Missing legacy/candidate sustained firing comparison")
    for row in parity:
        count=sum(row["spawned"]+120<=tick<row["spawned"]+780 for tick in row["shot_ticks"])
        if count!=660 or row["inserted"]-row["removed"]-row["remaining"]!=row["shots"]:
            errors.append(row["id"]+": native 660-tick parity/ammunition gate failed")
    output.mkdir(parents=True)
    decoded={};capture_refs={};all_reports=[baseline,*resumes.values()]
    for report in all_reports:
        for row in report["cases"]:
            for capture in row["captures"]:
                name=capture["path"]
                if name not in capture_refs:
                    source=capture_path(raw,name);target=capture_path(output,name)
                    retain(source,target);capture_refs[name]=reference(target)
                try:
                    decoded[row["id"],capture["epoch"],capture["tick"]]=decode(capture_path(output,name))
                except ValueError as error:
                    errors.append(row["id"]+": "+str(error))
    normalized=[]
    for row in rows:
        failures=row_checks(row,baseline,resumes,decoded)
        captures=[capture_refs[value["path"]] for value in row["captures"]]
        observations={"baseline":row,"decoded_phase_captures":[{"epoch":epoch,"tick":tick,**value}
            for (case,epoch,tick),value in decoded.items() if case==row["id"]]}
        record={"id":row["id"],"automated_checks_passed":not failures,"failures":failures,
                "observations":observations,"captures":captures}
        if row["kind"]=="save_load":
            save=run/"saves"/("_autosave-"+row["checkpoint"]["name"]+".zip")
            target=output/"checkpoint-saves"/save.name;retain(save,target)
            record["checkpoint_saves"]=[reference(target)]
            replay=resumes[row["phase"]]["cases"][0]
            observations["resumed"]=replay
            for value in replay["captures"]:
                if capture_refs[value["path"]] not in captures:captures.append(capture_refs[value["path"]])
        normalized.append(record);errors.extend(row["id"]+": "+failure for failure in failures)
    for name in ("fixture-plan.json","candidate-graphics-data.lua","candidate-mechanical-data.lua",
                 "muzzle-anchors.json","candidate-assets-manifest.json"):
        retain(helper/name,output/name)
    retain_candidate_assets(manifest,helper/"candidate",output/"candidate-assets","hardlink")
    native_refs={}
    for epoch in ("baseline",*("resume-"+phase for phase in PHASES)):
        name="minigun-lifecycle-"+epoch+".json"
        retain(raw/name,output/"native-original"/name);native_refs[epoch]=reference(output/"native-original"/name)
    normalized_report={"schema":"esir.minigun.lifecycle-normalized.v1","engine_version":"2.0.77",
        "lineage":plan["config"]["lineage"],"cases":normalized,"failures":errors,
        "source_native_reports":native_refs,"prototype_audit":audit,
        "candidate_assets_manifest_sha256":sha(helper/"candidate-assets-manifest.json"),
        "automated_checks_passed":not errors,"production_approved":False}
    report_path=output/"lifecycle-observations.json"
    report_path.write_text(json.dumps(normalized_report,indent=2)+"\n",encoding="utf-8")
    review={"schema":"esir.minigun.lifecycle-acceptance.v1","lineage":plan["config"]["lineage"],
        "passed":False,"failures":errors,"pending_review":["Actual phase, interruption/recovery, save replay and native art clips"],
        "reviewer":"","raw_reports":{"native":reference(report_path)},"cases":[
            {"id":row["id"],"raw_report":"native","passed":False,"notes":"",
             "captures":[]} for row in normalized]}
    (output/"review-template.json").write_text(json.dumps(review,indent=2)+"\n",encoding="utf-8")
    summary={"schema":1,"automated_checks_passed":not errors,"failures":errors,
        "visual_review_pending":True,"lifecycle_gate_passed":False,"production_approved":False,
        "case_count":len(rows),"capture_count":len(capture_refs),"native_report":reference(report_path)}
    (output/"summary.json").write_text(json.dumps(summary,indent=2)+"\n",encoding="utf-8")
    return summary


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--helper",type=Path,required=True)
    args=parser.parse_args()
    result=analyze(args.run.resolve(),args.output,args.helper.resolve())
    print(json.dumps(result,indent=2))
    raise SystemExit(3 if result["automated_checks_passed"] else 2)

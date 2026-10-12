"""Validate compact native control coverage; no image review is manufactured."""
import math

SCHEMA = "esir.minigun.compact-flash-measurements.v1"
RAYS = {"center_projected_twice", "source_projected_twice", "visual_projected_twice"}


def finite_point(value):
    return (isinstance(value,list) and len(value)==2 and
            all(type(x) in (int,float) and math.isfinite(x) for x in value))


def compact_control_problem(measured, report):
    if measured.get("schema") != SCHEMA or measured.get("approved") is not False:
        return "Compact heading diagnostics have an unexpected schema or approval claim"
    cases={case["id"]:case for case in report["cases"] if case["spec"]["kind"]=="static"}
    expected={(case,variant,offset,ray) for case in cases for variant in ("native","flash")
              for offset in (0,1) for ray in RAYS}
    controls=measured.get("held_out_controls",[])
    rejected=measured.get("rejected_control_models",[])
    if rejected and measured.get("control_selection_method") != "use_only_independently_registered_models":
        return "Rejected compact models lack an explicit selection method"
    all_controls=controls+rejected
    actual=[(row.get("case"),row.get("variant"),row.get("shot_offset"),row.get("ray_mode")) for row in all_controls]
    if len(actual)!=len(expected) or set(actual)!=expected:
        return "Compact heldout controls lack the complete cases, variants, frames or rays"
    eligible=set()
    for row in all_controls:
        group=report["heading_flash_templates"].get(row["case"]+"-"+row["variant"],{})
        source=group.get("source_effect",{})
        authored=report["prototype_audit"]["flashes"].get(source.get("name"),{})
        height=authored.get("height")
        point=row.get("origin_pixels")
        residual=row.get("relative_sse")
        if (type(height) not in (int,float) or not math.isfinite(height) or not 0<height<=1
                or row.get("native_height")!=height or not finite_point(point)
                or row.get("known_origin")!=[128,128]
                or row.get("expected_visual_origin")!=[128,128-height*64]
                or row.get("observed_height_translation")!=[point[0]-128,point[1]-128]
                or math.dist(point,[128,128-height*64])>.5
                or type(residual) not in (int,float) or not math.isfinite(residual) or residual<0):
            return "Compact independent height/registration control failed or changed"
        identity=(row["case"],row["variant"],row["shot_offset"],row["ray_mode"])
        if row in rejected:
            if residual<.001 or row.get("control_registration_passed") is not False:
                return "Rejected compact model was not an actual failed control"
        elif residual>=.001 or row.get("control_registration_passed") is not True:
            return "Compact independent height/registration control failed or changed"
        else:
            eligible.add(identity)
    groups={(case,variant,offset) for case,variant,offset,ray in expected}
    if {(case,variant,offset) for case,variant,offset,ray in eligible} != groups:
        return "A compact measurement has no independently registered model"
    for row in measured.get("results",[]):
        case=cases.get(row.get("case"),{})
        native_row=next((item for item in case.get("rows",[]) if item["variant"]==row.get("variant")),{})
        cap=next((item for item in native_row.get("captures",[]) if item["shot_offset"]==row.get("shot_offset")),{})
        key=(row.get("case"),row.get("variant"),row.get("shot_offset"))
        if (not cap or row.get("capture")!=cap["path"] or row.get("zoom")!=cap["zoom"]
                or not finite_point(row.get("origin_pixels")) or row.get("approved") is not False):
            return "Compact actual flash fit lacks its exact native image identity"
        if (*key,row.get("ray_mode")) not in eligible or any(
                (*key,alternative.get("ray_mode")) not in eligible for alternative in row.get("alternatives",[])):
            return "An actual flash fit uses an unregistered compact model"
    return None

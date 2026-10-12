"""Decode retained native screenshots; never infer visual success from a load."""
import argparse
import hashlib
import json
import shutil
import statistics
from pathlib import Path

from PIL import Image

from build_fixture import SEQUENCES, STATES


def bits(image, center, zoom, y, count, block=True):
    value = 0
    confidence = 1.0
    for bit in range(count):
        x = round(center[0] + (-32 + 6 + 7 * bit) * zoom)
        py = round(center[1] + y * zoom)
        # build_fixture.barcode writes fully opaque 5x6 source-pixel patches.
        # Sample only that known patch, never the surrounding sprite/background.
        pixels = list(image.crop((x-2*zoom, py-2*zoom, x+3*zoom, py+4*zoom)).getdata()) if block else [image.getpixel((x, py))]
        black = sum(max(rgb[:3]) <= 70 for rgb in pixels)
        white = sum(min(rgb[:3]) >= 170 for rgb in pixels)
        confidence = min(confidence, max(black, white) / len(pixels))
        # FX with intermediate RGB are rejected. Any opposite-polarity pixels
        # or lack of a strict majority make this bit unreadable, never guessed.
        if (black and white) or max(black, white) <= len(pixels) / 2:
            return None, confidence
        if white > black:
            value |= 1 << bit
    return value, confidence


def decode(image, center, zoom):
    fields = {"direction": (-26, 8), "physical_pose": (-13, 5),
              "upper_direction": (6, 8), "state": (-42, 3)}
    sampled = {key: bits(image, center, zoom, *spec) for key, spec in fields.items()}
    point = {key: bits(image, center, zoom, *spec, block=False)[0] for key, spec in fields.items()}
    return {**{key: value[0] for key, value in sampled.items()},
            "barcode_confidence": {key: value[1] for key, value in sampled.items()},
            "original_single_pixel": point}


def collapsed(values):
    return [value for index, value in enumerate(values) if index == 0 or value != values[index - 1]]


def segments(decoded, state):
    found, current = [], []
    for item in decoded:
        if item["state"] == state:
            if current and item["elapsed"] != current[-1]["elapsed"] + 1:
                found.append(current)
                current = []
            current.append(item)
        elif current:
            found.append(current)
            current = []
    if current:
        found.append(current)
    return found


def transition_details(decoded, state, expected):
    result = []
    by_elapsed = {item["elapsed"]: item for item in decoded}
    for sequence in segments(decoded, state):
        poses = collapsed([x["physical_pose"] for x in sequence])
        indices = [expected.index(x) if x in expected else -1 for x in poses]
        before = by_elapsed.get(sequence[0]["elapsed"] - 1)
        after = by_elapsed.get(sequence[-1]["elapsed"] + 1)
        start = before if before and before["physical_pose"] == expected[0] else None
        end = next((item for item in sequence if item["physical_pose"] == expected[-1]), None)
        result.append({"first_elapsed": sequence[0]["elapsed"], "last_elapsed": sequence[-1]["elapsed"],
                       "observed_ticks": len(sequence), "poses": poses,
                       "source_sequence_length": len(expected),
                       "state_exit_elapsed": after["elapsed"] if after else None,
                       "measured_state_span_ticks": after["elapsed"]-sequence[0]["elapsed"] if after else None,
                       "start_endpoint_elapsed": start["elapsed"] if start else None,
                       "end_endpoint_elapsed": end["elapsed"] if end else None,
                       "endpoint_to_endpoint_ticks": end["elapsed"]-start["elapsed"] if start and end else None,
                       "preceding_state": before["state"] if before else None,
                       "following_state": after["state"] if after else None,
                       "ordered": all(x >= 0 for x in indices) and indices == sorted(indices),
                       "all_interior_poses_seen": set(expected[1:-1]).issubset(poses)})
    return result


def analyze(run, output):
    report = json.loads((run / "script-output/minigun-native-report.json").read_text(encoding="utf-8-sig"))
    output.mkdir(parents=True, exist_ok=True)
    failures = list(report["errors"])
    layout_errors, base_hashes = [], set()
    base_hashes_by_position = {pose: set() for pose in range(1, 29)}
    for capture in report["layout"]:
        with Image.open(run / "script-output" / capture["path"]) as source:
            image = source.convert("RGB")
        for pose in range(1, 29):
            center = ((pose - 1) % 14 * 128 + 64, (pose - 1) // 14 * 128 + 64)
            observed = decode(image, center, 1)
            digest = hashlib.sha256(image.crop((center[0]-32,center[1]+32,
                center[0]+32,center[1]+48)).tobytes()).hexdigest()
            base_hashes.add(digest)
            base_hashes_by_position[pose].add(digest)
            if (observed["direction"], observed["physical_pose"], observed["upper_direction"]) != (
                    capture["direction"], pose, capture["direction"]):
                layout_errors.append({"requested_direction": capture["direction"], "pose": pose, **observed})
    if len(report["layout"]) != 256 or layout_errors:
        failures.append("Native layout did not reproduce all 7168 direction/pose cells")
    if any(len(values) != 1 for values in base_hashes_by_position.values()):
        failures.append("Fixed base appearance changed across headings at the same world position")

    timing, observed_states = [], set()
    rows = {row["id"]: row for row in report["cases"]}
    for row in rows.values():
        decoded = []
        for capture in row["captures"]:
            with Image.open(run / "script-output" / capture["path"]) as source:
                sample = decode(source.convert("RGB"), (80, 112), 2)
            decoded.append({**capture, **sample})
            if sample["state"] is not None:
                observed_states.add(sample["state"])
        (output / (row["id"] + "-decoded.json")).write_text(json.dumps(decoded, indent=2) + "\n")
        steady = sum(value for tick, value in row["curve"].items() if 90 <= int(tick) < 750)
        if row["shots"] != row["consumed"]:
            failures.append(row["id"] + ": source observer disagrees with ammunition consumption")
        if row["scenario"] == "baseline" and steady != 660:
            failures.append(row["id"] + ": steady 660-tick firing window changed")
        first_delay = row.get("first_shot", report["started"] + 100000) - report["started"] - 60
        preparing = transition_details(decoded, 1, SEQUENCES["preparing"])
        folding = transition_details(decoded, 7, SEQUENCES["folding"])
        unreadable = [x["elapsed"] for x in decoded if any(x[key] is None for key in
            ("direction", "physical_pose", "upper_direction", "state"))]
        mismatches = [x["elapsed"] for x in decoded if x["upper_direction"] != x["direction"]]
        original_failures = [{"elapsed": x["elapsed"], "path": x["path"],
                              "single_pixel": x["original_single_pixel"],
                              "block_confidence": x["barcode_confidence"]} for x in decoded
            if any(x["original_single_pixel"][key] != x[key] for key in x["original_single_pixel"])]
        if unreadable or mismatches:
            failures.append(row["id"] + ": upper/rotor directions disagree or barcode cannot be decoded")
        if row["variant"] == "candidate" and row["scenario"] == "baseline":
            if not 0 <= first_delay <= 45:
                failures.append(row["id"] + ": first-shot delay exceeds accepted activation cap")
            if not any(x["ordered"] and x["all_interior_poses_seen"] for x in preparing):
                failures.append(row["id"] + ": complete ordered spin-up was not observed")
            if not any(x["ordered"] and x["all_interior_poses_seen"] for x in folding):
                failures.append(row["id"] + ": complete ordered spin-down was not observed")
        event_context = []
        for event_index, event in enumerate(row["events"]):
            near = [x for x in decoded if event["elapsed"] - 2 <= x["elapsed"] <= event["elapsed"] + 2]
            details = {**event, "nearby_frames": near}
            if event["kind"] == "acquire":
                next_event = row["events"][event_index+1]["elapsed"] if event_index+1 < len(row["events"]) else 1000000
                first = min((int(tick) for tick, value in row["curve"].items()
                    if value and event["elapsed"] <= int(tick) < next_event), default=None)
                details["next_shot_elapsed_before_next_event"] = first
                details["activation_delay_ticks"] = first-event["elapsed"] if first is not None else None
                if details["activation_delay_ticks"] is not None and row["variant"] == "candidate" and details["activation_delay_ticks"] > 45:
                    failures.append(row["id"] + ": acquisition delay exceeds accepted 45-tick ceiling")
            event_context.append(details)
        timing.append({"id": row["id"], "variant": row["variant"], "scenario": row["scenario"],
                       "shots": row["shots"], "consumed": row["consumed"], "steady_660_tick_shots": steady,
                       "first_shot_delay_ticks": first_delay, "preparing": preparing, "folding": folding,
                       "events": event_context, "captures": len(decoded),
                       "unreadable_capture_ticks": unreadable, "direction_mismatch_ticks": mismatches,
                       "single_pixel_extraction_failures": original_failures,
                       "minimum_barcode_confidence": min((min(x["barcode_confidence"].values()) for x in decoded), default=None)})

    samples = {}
    for capture in report["shadows"]:
        with Image.open(run / "script-output" / capture["path"]) as image:
            pixels = list(image.convert("RGB").crop((56, 56, 72, 72)).getdata())
        samples[capture["name"]] = [statistics.median(p[c] for p in pixels) for c in range(3)]
    predictions = {
        "minimum": {"b64-u192": "control64", "b128-u128": "control128", "triple": "control64", "u64-r192": "control64"},
        "maximum": {"b64-u192": "control192", "b128-u128": "control128", "triple": "control192", "u64-r192": "control192"},
        "alpha_over": {"b64-u192": "control208", "b128-u128": "control192", "triple": "control232", "u64-r192": "control208"},
        "clamped_add": {"b64-u192": "control255", "b128-u128": "control255", "triple": "control255", "u64-r192": "control255"},
    }
    difference = lambda a, b: max(abs(x-y) for x, y in zip(samples[a], samples[b]))
    scores = {law: max(difference(a, b) for a, b in controls.items()) for law, controls in predictions.items()}
    ranked = sorted(scores, key=scores.get)
    measurable = difference("empty", "control255") >= 10
    determined = measurable and scores[ranked[0]] <= 4 and scores[ranked[1]] - scores[ranked[0]] >= 2
    order_error = max(difference("triple", "triple-reversed"), difference("u64-r192", "u64-r192-reversed"))
    path_error = max(difference("b64", "u64"), difference("b128", "u128"), difference("b192", "u192"))
    if not determined or order_error > 4 or path_error > 4:
        failures.append("Shadow accumulation is ambiguous or differs by leaf order/ownership surface")
    summary = {"schema": 2, "ballistic": report["ballistic"], "run": str(run),
               "instrumentation": report.get("instrumentation", {"shell_particles_disabled": False}),
               "analyzer_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
               "extraction": {"method": "strict-majority-with-no-opposite-polarity-in-opaque-source-patch",
                              "source_patch_pixels": [5, 6], "single_pixel_results_retained": True},
               "automated_checks_passed": not failures, "failures": failures,
               "layout": {"captures": len(report["layout"]), "cells_checked": len(report["layout"])*28,
                          "errors": layout_errors, "fixed_base_unique_hashes": len(base_hashes),
                          "fixed_base_unique_hashes_by_position": {str(pose): len(values) for pose, values in base_hashes_by_position.items()},
                          "fixed_base_invariance_scope": "256 headings at each of 28 fixed world positions; different positions may differ in environmental lighting"}, "timing": timing,
               "states_observed": [STATES[x] for x in sorted(observed_states)],
               "states_not_observed": [state for i, state in enumerate(STATES) if i not in observed_states],
               "shadow": {"selected_law": ranked[0] if determined else None, "candidate_residuals_rgb": scores,
                          "samples_rgb": samples, "order_error_rgb": order_error, "path_error_rgb": path_error,
                          "real_geometry_union_validated": False},
               "review_required": ["Inspect interrupted spin-up/down and rotation-for-folding frames",
                                   "Use measured fold start to calibrate requested quarter/half/three-quarter interruptions",
                                   "Confirm nominal 12/18 tick durations from native state markers",
                                   "Test actual geometry shadow union; scalar calibration is not sufficient"],
               "production_approved": False}
    (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    (output / "native-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    shutil.copyfile(__file__, output / "analyzer-source.py")
    shutil.copytree(run / "script-output/minigun-native", output / "screenshots", dirs_exist_ok=True)
    return summary


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = analyze(args.run, args.output)
    print(json.dumps({"automated_checks_passed": result["automated_checks_passed"], "failures": result["failures"],
                      "shadow_law": result["shadow"]["selected_law"], "production_approved": False}, indent=2))
    raise SystemExit(0 if result["automated_checks_passed"] else 2)

"""Prove requested subpixel phases survived placement and camera bookkeeping."""
import hashlib
import math
import numpy as np

METHOD = "entity-relative-camera-v3"
UNITS = "engine-native-pixel-32-per-tile"


def inspect(case, pair, reference_pixels, groups, matrix="full"):
    if case.get("background_only") or "control_alpha" in case:
        return []
    failures = []
    source_density = case.get("reference_density", 32 if case.get("profile") == "sd" else 64)
    density = 32
    fraction = case["fractional_native_pixel_offset"]
    for capture in pair:
        position, camera = capture.get("position"), capture.get("camera_position")
        if not position or not camera or capture.get("density") != density or capture.get("source_density") != source_density:
            failures.append("Missing actual entity/camera geometry: " + case["id"])
            continue
        observed = [(position[axis]-camera[axis])*density for axis in ("x", "y")]
        if any(abs(value-fraction)>1e-7 for value in observed):
            failures.append("Requested fraction differs from actual entity/camera geometry: " + case["id"])
        expected = {"offset_native_pixels":fraction,"offset_source_pixels":fraction*source_density/32,
                    "offset_screen_pixels":fraction*case["zoom"]}
        if any(key not in capture or abs(capture[key]-value)>1e-7 for key,value in expected.items()):
            failures.append("Native/source/screen offset labels disagree with capture geometry: " + case["id"])
    if any(pair[0].get(key) != pair[1].get(key) for key in ("position", "camera_position", "orientation")):
        failures.append("Pair entity/camera registration differs: " + case["id"])
    key = (case.get("tier", case.get("profile")), case["direction"], case["pose"], case["zoom"])
    rows = groups.setdefault(key, [])
    measured = {"fraction":fraction,"source_fraction":fraction*source_density/32,
        "screen_fraction":fraction*case["zoom"],"source_density":source_density,"case_id":case["id"],
        "pixels_sha256":hashlib.sha256(reference_pixels.tobytes()).hexdigest()}
    if fraction == 0:
        measured["_pixels"] = reference_pixels.copy()
        measured["exact_screen_translations"] = [[0, 0]]
    elif rows and "_pixels" in rows[0]:
        baseline = rows[0]["_pixels"]
        height, width = baseline.shape[:2]
        limit = math.ceil(fraction * case["zoom"]) + 1
        measured["exact_screen_translations"] = [[dx, dy]
            for dx in range(limit + 1) for dy in range(limit + 1)
            if np.array_equal(reference_pixels[dy:, dx:], baseline[:height-dy, :width-dx])]
    else:
        measured["exact_screen_translations"] = []
        failures.append("Fractional group has no phase-zero reference: " + case["id"])
    rows.append(measured)
    if fraction == (.5 if matrix == "smoke" else .75):
        rows[0].pop("_pixels", None)
    return failures


def finish(groups, matrix):
    wanted = [0, .5] if matrix == "smoke" else [0, .25, .5, .75]
    failures, repeated, unvalidated = [], [], []
    for key, rows in groups.items():
        if sorted(row["fraction"] for row in rows) != wanted:
            failures.append("Incomplete fractional geometry group: " + repr(key))
        if len({row["pixels_sha256"] for row in rows}) != len(rows):
            record = {"group":list(key),"cases":rows}
            repeated.append(record)
            # The engine rounds screenshot camera translations to screen pixels.
            # Accept an alias only when actual pixels prove a common whole-screen
            # translation, every camera request was checked, and phases did move.
            valid = (len({row["pixels_sha256"] for row in rows}) >= 2 and
                     all(row.get("exact_screen_translations") for row in rows) and
                     all([0, 0] not in row["exact_screen_translations"]
                         for row in rows if row["fraction"] != 0))
            if not valid:
                unvalidated.append(record)
    if unvalidated:
        failures.append("Reference fractional aliases lack exact native screen-translation evidence")
    return {"method":METHOD,"offset_units":UNITS,"native_pixels_per_tile":32,
            "passed":not failures,"groups_checked":len(groups),
            "expected_source_pixel_offsets":{"sd":wanted,"hd":[value*2 for value in wanted]},
            "screen_pixel_offset_formula":"native_pixel_offset * zoom",
            "required_fractions":wanted,"duplicate_pixel_groups":repeated,
            "unvalidated_duplicate_pixel_groups":unvalidated,
            "pixel_phase_quantization_proven":bool(repeated and not unvalidated),
            "quantization_method":"exact-native-screen-translations",
            "pixel_uniqueness_policy":"Distinct images, or exact translated native pixels proving screen-grid aliases; all requested camera offsets remain mandatory"}, failures

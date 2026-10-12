"""Prove requested subpixel phases survived placement and camera bookkeeping."""
import hashlib
import math
import numpy as np

METHOD = "entity-relative-camera-v3"
UNITS = "engine-native-pixel-32-per-tile"
QUANTIZATION = "native-shadow-screen-translations-one-code-support-band"


def translation_evidence(baseline, pixels, limit):
    """Measure native shadow registration; one-code cause remains an inference.

    The >4-code support matches the existing shadow-presence measurement.
    Only 4<->5 darkening crossings qualify at that threshold under the existing
    one-code bound. Borders stay exact; comparison/source-alpha limits stay.
    """
    baseline = baseline.astype(np.int16, copy=False)
    pixels = pixels.astype(np.int16, copy=False)
    height, width = baseline.shape[:2]
    background = baseline[0, 0]
    def border(array):
        return np.concatenate((array[:2].reshape(-1,3),array[-2:].reshape(-1,3),
                               array[:,:2].reshape(-1,3),array[:,-2:].reshape(-1,3)))
    borders_exact = bool(np.all(border(baseline)==background) and np.all(border(pixels)==background))
    candidates = []
    for dx in range(limit+1):
        for dy in range(limit+1):
            left, right = baseline[:height-dy,:width-dx], pixels[dy:,dx:]
            delta = right-left
            maximum = int(np.abs(delta).max())
            if maximum > 1:
                continue
            dark_left=np.max(background-left,axis=2)
            dark_right=np.max(background-right,axis=2)
            crossing=(dark_left>4)!=(dark_right>4)
            crossing_values=np.stack((dark_left[crossing],dark_right[crossing]),axis=1)
            support_exact=not bool(np.any(crossing))
            support_qualified=bool(support_exact or np.all(
                ((crossing_values[:,0]==4)&(crossing_values[:,1]==5)) |
                ((crossing_values[:,0]==5)&(crossing_values[:,1]==4))))
            border_exact = borders_exact and bool(np.array_equal(border(left),border(right)))
            if support_qualified and border_exact:
                candidates.append({"shift":[dx,dy],"maximum_rgb_error":maximum,
                    "rms_rgb_error":float(np.sqrt(np.mean(delta.astype(np.float64)**2))),
                    "differing_pixels":int(np.count_nonzero(np.any(delta!=0,axis=2))),
                    "border_exact":True,"shadow_support_exact":support_exact,
                    "shadow_support_qualified":support_qualified,"support_threshold_rgb":4,
                    "support_uncertainty_band_rgb":[4,5],"support_crossing_pixels":int(np.count_nonzero(crossing)),
                    "support_crossing_values":np.unique(crossing_values,axis=0).tolist()})
    return candidates


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
        measured["screen_translation_evidence"] = translation_evidence(reference_pixels,reference_pixels,0)
    elif rows and "_pixels" in rows[0]:
        baseline = rows[0]["_pixels"]
        height, width = baseline.shape[:2]
        limit = math.ceil(fraction * case["zoom"]) + 1
        measured["exact_screen_translations"] = [[dx, dy]
            for dx in range(limit + 1) for dy in range(limit + 1)
            if np.array_equal(reference_pixels[dy:, dx:], baseline[:height-dy, :width-dx])]
        measured["screen_translation_evidence"] = translation_evidence(baseline,reference_pixels,limit)
    else:
        measured["exact_screen_translations"] = []
        measured["screen_translation_evidence"] = []
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
            # Require a unique whole-screen shift on every requested row. Native
            # shadow compositing can differ by one code after translation; the
            # measured cause is not established, so preserve exact and bounded
            # evidence separately. Borders stay exact; visible support is exact
            # or changes only at darkening4<->5 within the one-code bound.
            valid = (len({row["pixels_sha256"] for row in rows}) >= 2 and
                     all(len(row.get("screen_translation_evidence",[])) == 1 for row in rows) and
                     all(row["screen_translation_evidence"][0]["shift"] != [0,0]
                         for row in rows if row["fraction"] != 0))
            if not valid:
                unvalidated.append(record)
    if unvalidated:
        failures.append("Reference fractional aliases lack unique bounded native shadow screen-translation evidence")
    return {"method":METHOD,"offset_units":UNITS,"native_pixels_per_tile":32,
            "passed":not failures,"groups_checked":len(groups),
            "expected_source_pixel_offsets":{"sd":wanted,"hd":[value*2 for value in wanted]},
            "screen_pixel_offset_formula":"native_pixel_offset * zoom",
            "required_fractions":wanted,"duplicate_pixel_groups":repeated,
            "unvalidated_duplicate_pixel_groups":unvalidated,
            "pixel_phase_quantization_proven":bool(repeated and not unvalidated),
            "quantization_method":QUANTIZATION,"translation_rgb_max_allowance":1,
            "translation_support_threshold_rgb":4,
            "translation_support_uncertainty_band_rgb":[4,5],
            "pixel_uniqueness_policy":"Distinct images, or unique nonzero native screen translations within one RGB code with exact borders and exact support or darkening4<->5 crossings only; all requested camera offsets remain mandatory"}, failures

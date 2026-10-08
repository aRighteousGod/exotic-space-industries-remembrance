"""Fit simple diagnostic attachment-lift curves to measured motion registration.

The target is inferred native residual lift, not a Lua API property. This is a
one-route empirical fit; repeated preview headings and physics interpolation
remain limitations. Only moving frames receive visual strands in production.
"""
import argparse
import json
from pathlib import Path

import numpy as np


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    source = json.loads(args.input.read_text())
    rows = [row for row in source["results"] if row.get("status") == "diagnostic"]
    speed = np.array([row["speed"] for row in rows])
    lift = np.array([row["inferred_residual_lift_tiles"] for row in rows])
    moving = np.array([row["moving"] for row in rows], dtype=bool)
    design = np.column_stack((np.ones(len(speed)), speed))
    linear = np.linalg.lstsq(design[moving], lift[moving], rcond=None)[0]
    models = {}
    def record(name, predicted, parameters):
        error = (predicted - lift) * 32
        models[name] = {"parameters": parameters,
                        "max_moving_vertical_error_px": float(abs(error[moving]).max()),
                        "rms_moving_vertical_error_px": float(np.sqrt((error[moving] ** 2).mean())),
                        "max_all_vertical_error_px": float(abs(error).max()),
                        "per_frame_vertical_errors_px": np.round(error, 6).tolist()}
    record("fixed", np.full(len(speed), .625), {"lift": .625})
    record("moving-linear-least-squares", design @ linear,
           {"offset": float(linear[0]), "gain": float(linear[1])})
    record("initial-speed-curve", -.25 + .875 * np.clip(speed / .175, 0, 1),
           {"offset": -.25, "span": .875, "normalization_speed": .175})
    record("rounded-moving-minimax", -.34 + .875 * np.clip(speed / .083, 0, 1),
           {"offset": -.34, "span": .875, "normalization_speed": .083})
    best = None
    for normalization in np.linspace(.08, .18, 501):
        normalized = np.clip(speed[moving] / normalization, 0, 1)
        for span in np.linspace(.4, 1.3, 901):
            remainder = lift[moving] - span * normalized
            low = (remainder.max() + remainder.min()) * .5
            error = (remainder.max() - remainder.min()) * .5
            if best is None or error < best[0]:
                best = error, normalization, low, span
    _, normalization, low, span = best
    record("moving-minimax-grid", low + span * np.clip(speed / normalization, 0, 1),
           {"offset": float(low), "span": float(span), "normalization_speed": float(normalization)})
    report = {"kind": "reference17-keel-lift-one-route-fit", "certified": False,
              "source_report": str(args.input), "measured_frames": len(rows),
              "moving_frames": int(moving.sum()), "models": models,
              "scope": "Inferred vertical residual only. No exact native bob access, no universal pixel guarantee, and no heading-quantization correction is hidden in the fit."}
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({name: {key: value for key, value in model.items()
                            if key != "per_frame_vertical_errors_px"}
                      for name, model in models.items()}))


if __name__ == "__main__":
    main()

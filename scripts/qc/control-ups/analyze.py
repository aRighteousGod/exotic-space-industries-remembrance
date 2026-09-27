"""Summarize matched UPS evidence without treating helper exit 0 as acceptance."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import statistics


def profiles(path: Path) -> dict:
    text = path.read_text(encoding="utf-8-sig")
    complete = re.findall(r"CONTROL_UPS ALL_COMPLETE checks=(\d+)", text)
    if not complete:
        raise ValueError(f"Missing differential completion marker: {path}")
    result = {}
    pattern = r"CONTROL_UPS PROFILE (\S+) (baseline|candidate) repetition=(\d+) calls=(\d+) elapsed=Duration: ([\d.]+)ms"
    for name, side, repetition, calls, duration in re.findall(pattern, text):
        if int(repetition) == 1:
            continue  # First pair warms each probe; subsequent pairs alternate order.
        result.setdefault(name, {}).setdefault(side, []).append(float(duration) / int(calls))
    for name, item in result.items():
        for side in ("baseline", "candidate"):
            if len(item.get(side, [])) != 5:
                raise ValueError(f"Incomplete profile {name}/{side}")
            item[side + "_median_ms_per_call"] = statistics.median(item[side])
        item["reduction_percent"] = 100 * (1 - item["candidate_median_ms_per_call"] / item["baseline_median_ms_per_call"])
    return {"checks": int(complete[-1]), "probes": result}


def benchmark(path: Path) -> dict:
    text = path.read_text(encoding="utf-8-sig")
    rows = re.findall(r"Performed (\d+) updates in ([\d.]+) ms\s+avg: ([\d.]+) ms, min: ([\d.]+) ms, max: ([\d.]+) ms", text)
    if len(rows) != 6:
        raise ValueError(f"Expected one warm-up and five measured runs: {path}; found {len(rows)}")
    samples = [float(total) / int(ticks) for ticks, total, *_ in rows[1:]]
    return {"ticks": int(rows[0][0]), "warmup_runs": 1, "measured_runs": 5,
            "ms_per_tick": samples, "median_ms_per_tick": statistics.median(samples),
            "min_ms_per_tick": min(samples), "max_ms_per_tick": max(samples)}


def water(path: Path) -> dict:
    report = json.loads(path.read_text(encoding="utf-8-sig"))
    assert report["all_pass"] is True, f"Water acceptance failed: {path}"
    assert report["cases"] and all(case["pass"] is True for case in report["cases"].values())
    return {"cases": len(report["cases"]), "all_pass": True}


def alternating(paths: list[Path]) -> dict:
    result = {}
    for side, path in zip(("baseline", "candidate"), paths):
        samples, checksums = [], []
        for pair in range(6):
            text = (path / f"pair-{pair}-stdout.txt").read_text(encoding="utf-8-sig")
            rows = re.findall(r"Performed (\d+) updates in ([\d.]+) ms", text)
            assert len(rows) == 1 and int(rows[0][0]) == 3600, (path, pair)
            checksum = re.findall(r"^\s*checksum: (\d+)\s*$", text, re.M)
            assert len(checksum) == 1, (path, pair)
            checksums.extend(checksum)
            if pair:
                samples.append(float(rows[0][1]) / int(rows[0][0]))
        assert len(set(checksums)) == 1, (side, checksums)
        result[side] = {"ticks": 3600, "warmup_runs": 1, "measured_runs": 5,
                        "ms_per_tick": samples, "median_ms_per_tick": statistics.median(samples),
                        "min_ms_per_tick": min(samples), "max_ms_per_tick": max(samples),
                        "checksum": checksums[0]}
    result["median_reduction_percent"] = 100 * (1 - result["candidate"]["median_ms_per_tick"] / result["baseline"]["median_ms_per_tick"])
    result["paired_reduction_percent"] = [100 * (1-c/b) for b,c in zip(result["baseline"]["ms_per_tick"],result["candidate"]["ms_per_tick"])]
    # Serialization/cache metadata may change the engine checksum. Record it;
    # observable behavior parity is checked by the dedicated lifecycle fixtures.
    return result


def gui_profile(path: Path) -> dict:
    text = path.read_text(encoding="utf-8-sig")
    assert "CONTROL_UPS_GUI ALL_COMPLETE" in text, path
    pattern = r"CONTROL_UPS_GUI_PROFILE (\S+) (black|matrix) (\d+) (\d+) (\d+) Duration: ([\d.]+)ms"
    result = {}
    for phase, module, repetition, calls, positives, duration in re.findall(pattern, text):
        expected = int(calls) if phase == module + "-orphan" else 0
        assert int(positives) == expected, (path, phase, module, positives)
        if int(repetition) == 1:
            continue
        result.setdefault(phase, {}).setdefault(module, []).append(float(duration) * 1000 / int(calls))
    assert set(result) == {"no-root", "black-orphan", "matrix-orphan", "unrelated-root"}, path
    for phase, modules in result.items():
        for module in ("black", "matrix"):
            assert len(modules[module]) == 5, (path, phase, module)
            modules[module + "_median_us_per_call"] = statistics.median(modules[module])
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--probe", type=Path)
    parser.add_argument("--benchmark", type=Path, action="append", default=[])
    parser.add_argument("--water", type=Path, action="append", default=[])
    parser.add_argument("--output", type=Path)
    parser.add_argument("--alternating", type=Path, nargs=2, metavar=("BASELINE", "CANDIDATE"))
    parser.add_argument("--gui-profile", type=Path, action="append", default=[])
    args = parser.parse_args()
    result = {}
    if args.alternating:
        result["alternating"] = alternating(args.alternating)
    for path in args.gui_profile:
        result[str(path)] = gui_profile(path)
    if args.probe:
        result["differential"] = profiles(args.probe)
    for path in args.benchmark:
        result[str(path)] = benchmark(path)
    for path in args.water:
        result[str(path)] = water(path)
    text = json.dumps(result, indent=2)
    if args.output:
        args.output.write_text(text + "\n", encoding="utf-8")
    print(text)


if __name__ == "__main__":
    main()

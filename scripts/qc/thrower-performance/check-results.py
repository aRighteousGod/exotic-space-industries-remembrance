"""Compare native combat reports and validate the seven startup locale contracts."""
import argparse
import configparser
import json
from pathlib import Path


def check_locales():
    root = Path(__file__).resolve().parents[3] / "exotic-space-industries-remembrance" / "locale"
    reference = None
    for language in ("en", "fr", "ja", "pl", "ru", "zh-CN", "zh-TW"):
        text = (root / language / "thrower-performance.cfg").read_text(encoding="utf-8")
        assert "\ufffd" not in text, language
        cfg = configparser.ConfigParser(interpolation=None, strict=True)
        cfg.read_string(text)
        keys = {(section, key) for section in cfg.sections() for key in cfg[section]}
        reference = reference or keys
        assert keys == reference, f"Locale keys differ: {language}"
        for index in range(1, 8):
            assert f"__{index}__" in cfg["thrower-performance"]["profile-row"]
        for profile in ("original", "2x", "4x", "8x", "16x"):
            assert cfg["string-mod-setting-description"][f"ei-thrower-performance-profile-{profile}"]
    print("Five profiles and seven locale contracts verified.")


def compare(baseline, candidate):
    original = json.loads(baseline.read_text(encoding="utf-8-sig"))
    changed = json.loads(candidate.read_text(encoding="utf-8-sig"))
    assert original["profile"] == "original"
    assert original["adaptation"] == changed["adaptation"]
    assert original["all_fired"] and changed["all_fired"]
    old = {row["key"]: row for row in original["cases"]}
    new = {row["key"]: row for row in changed["cases"]}
    assert old.keys() == new.keys()
    failures, rows = [], []
    for key, row in new.items():
        component = key.rsplit("/", 1)[1]
        ratio = row["dps"] / old[key]["dps"]
        fluid_ratio = row["fluid_per_second"] / old[key]["fluid_per_second"]
        tolerance = 0.05 if component in ("ground", "combined") else 0.01
        result = {"key": key, "dps_ratio": ratio, "fluid_ratio": fluid_ratio,
                  "event_ratio": row["events"] / old[key]["events"],
                  "first_hit_delta": row["first_hit"] - old[key]["first_hit"]}
        rows.append(result)
        if abs(ratio - 1) > tolerance or abs(fluid_ratio - 1) > 0.01:
            failures.append(result)
    report = {"profile": changed["profile"], "adaptation": changed["adaptation"],
              "all_pass": not failures, "failures": failures, "cases": rows}
    output = candidate.with_name(candidate.stem + "-comparison.json")
    output.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"{changed['profile']}: {len(rows)-len(failures)}/{len(rows)} parity cases passed; {output}")
    for row in failures[:12]:
        print(row)
    return not failures


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("baseline", type=Path, nargs="?")
    parser.add_argument("candidates", type=Path, nargs="*")
    args = parser.parse_args()
    check_locales()
    passed = True
    if args.baseline:
        for candidate in args.candidates:
            passed = compare(args.baseline, candidate) and passed
    raise SystemExit(0 if passed else 1)

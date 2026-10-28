"""Report cross-engine legacy preservation and within-profile control isolation.

Native generation completing is not acceptance: exact differences remain visible
until raw-value, prototype-order and populated-surface evidence resolves them.
"""
import argparse
import hashlib
import json
from pathlib import Path


def key(case):
    return case["planet"], case["seed"], case["case"], case.get("family")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--old", type=Path, required=True)
    parser.add_argument("--new", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    old, new = [json.loads(p.read_text(encoding="utf-8")) for p in (args.old, args.new)]
    baseline = {key(c): c for c in old["cases"]}
    cohorts = {revision: {key(c): c for c in new["cases"] if c["revision"] == revision}
        for revision in ("legacy20", "native21")}
    assert len(baseline) == len(cohorts["legacy20"]) == len(cohorts["native21"]) == 258
    differences, zero_equivalents, failures, checks = [], [], [], 0

    def check(condition, label):
        nonlocal checks
        checks += 1
        if not condition:
            failures.append(label)

    for case_key, case in cohorts["legacy20"].items():
        before = baseline[case_key]
        for prop in set(before["noise"]) | set(case["noise"]):
            a, b = before["noise"].get(prop), case["noise"].get(prop)
            if a == b:
                continue
            row = {"case": case_key, "property": prop, "before": a, "after": b}
            if a and b and a["positive"] == b["positive"] == 0 and (a.get("omitted") or b.get("omitted")):
                zero_equivalents.append(row)
            else:
                differences.append(row)
        if before["entities"] != case["entities"]:
            differences.append({"case": case_key, "property": "generated_entities",
                "removed": sorted(set(before["entities"]) - set(case["entities"])),
                "added": sorted(set(case["entities"]) - set(before["entities"]))})

    for revision, cohort in cohorts.items():
        for case_key, case in cohort.items():
            label = revision + "/" + "/".join(str(v) for v in case_key)
            check(case["roundtrip"], label + "/exchange")
            check(all(v.get("omitted") or v["count"] == 9409 for v in case["noise"].values()), label + "/samples")
            if case["case"] == "default":
                continue
            default = cohort[case["planet"], case["seed"], "default", None]
            for prop, value in case["noise"].items():
                family = case["families"].get(prop)
                if case.get("mixed"):
                    reference = cohort[case["planet"], case["seed"], "frequency-high", family] if family in case["mixed"] else default
                    check(value == reference["noise"][prop], label + "/mixed-isolation/" + prop)
                elif family != case.get("family"):
                    check(value == default["noise"][prop], label + "/other-family/" + prop)
                elif case["case"] in ("off", "frequency-zero", "size-zero") and prop.startswith("entity:"):
                    if case["planet"] == "gleba":
                        # Authored contract retains the normal raft/egg supply;
                        # runtime suppresses births instead of removing rafts.
                        check(value == default["noise"][prop], label + "/retained-egg-rafts/" + prop)
                        if case["case"] == "off":
                            check(case["entities"] == default["entities"], label + "/retained-generated-rafts")
                        continue
                    check(value["positive"] == 0, label + "/no-probability/" + prop)
                    if case["case"] == "off":
                        check(not any(e.startswith(prop.split(":")[1] + ":") for e in case["entities"]), label + "/no-entities/" + prop)
    report = {"engine_execution_cases": len(old["cases"]) + len(new["cases"]),
        "control_checks": checks, "control_failures": failures, "controls_passed": not failures,
        "legacy_exact_differences": differences, "disabled_omitted_vs_zero": zero_equivalents,
        "legacy_acceptance": not differences, "release_acceptance": False,
        "inputs": [{"path": str(p.absolute()), "sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p in (args.old, args.new)],
        "limits": ["Territory boundaries and small floating-point differences require focused raw-value evidence",
            "Existing surfaces, custom aliases and Gaia reforge remain separate migration gates"]}
    args.output.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps({k: report[k] for k in ("engine_execution_cases", "control_checks", "controls_passed", "legacy_acceptance")}))
    print(json.dumps({"control_failures": failures[:10], "legacy_difference_count": len(differences)}))


if __name__ == "__main__":
    main()

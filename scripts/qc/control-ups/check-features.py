"""Validate the existing helper reports, then compare matched runtime snapshots."""
import argparse
from collections import Counter
import json
from pathlib import Path


def rows(path, marker):
    if path.is_dir():
        # Helpers log the same JSON even when their player-targeted file output
        # is unavailable in a headless profile. Include fixture creation.
        result = []
        for name in ("create.log", "benchmark.log"):
            log = path / name
            if log.exists():
                for line in log.read_text(encoding="utf-8-sig").splitlines():
                    if marker in line:
                        result.append(json.loads(line.split(marker, 1)[1]))
        return result
    return [json.loads(line) for line in path.read_text(encoding="utf-8-sig").splitlines() if line.strip()]


def orbital(path, report_baseline_failures=False):
    records = rows(path, "ORBITAL_LOGISTICS_QC ")
    build = next(row for row in records if row["kind"] == "build")
    configured = next(row for row in records if row["kind"] == "configured")
    for key in ("rebuild_ok", "warm_service_ok", "initial_snapshot_ok", "config_ok", "post_service_ok", "post_snapshot_ok"):
        assert configured[key] is True, (path, key, configured)
    for key in ("initial_validation", "post_validation"):
        assert configured[key]["ok"] is True and not configured[key].get("errors"), (path, key, configured[key])
    assert len(set(configured["platform_ids"].values())) == 3
    alpha = configured["platform_ids"]["QC Alpha"]
    expected_ticks = {1, 30, 60, 120, 180, 240, 270, 300, 330, 420, 450, 480}
    expected_actions = {
        45: "duplicate-manual-target", 90: "restore-policy-selector", 120: "destroy-active-coordinator",
        150: "invalid-manual-selector", 195: "restore-manual-selector", 225: "retarget-manual-selector",
        255: "destroy-silo-b", 285: "rebuild-silo-b", 300: "rebind-uplink-b", 330: "prepare-fairness-rotation",
        345: "clear-fairness-lane", 360: "rebind-fairness-lane-first", 375: "clear-fairness-lane-again",
        390: "rebind-fairness-lane-second", 405: "create-transponder-conflict", 435: "restore-transponder-ids",
    }
    seen_ticks, seen_actions, gui_skips, failed_actions = set(), {}, 0, []

    def check_config(value):
        if isinstance(value, dict):
            for field in ("selectors", "uplinks", "transponders"):
                for item in value.get(field, []):
                    assert item["ok"] is True, (path, field, item)

    check_config(configured.get("config_result"))
    for row in records:
        if row["kind"] not in ("checkpoint", "action"):
            continue
        relative = row["tick"] - build["tick"]
        if row["kind"] == "action":
            assert row["config_ok"], (path, row)
            if not row["expectation"]["ok"]:
                failed_actions.append({"action": row["action"], "tick": relative, "expectation": row["expectation"]})
                assert report_baseline_failures, (path, failed_actions[-1])
            check_config(row.get("config_result"))
            seen_actions[relative] = row["action"]
            sample = row["post"]
        else:
            seen_ticks.add(relative)
            sample = row
        assert sample["service_ok"] and sample["snapshot_ok"] and sample["remote"]["present"], (path, sample)
        assert isinstance(sample["snapshot"], dict)
        if relative in (360, 390) and not report_baseline_failures:
            # Fairness must rotate fixed jobs; a policy can retarget between
            # the helper's repeated service calls and invalidate this scenario.
            jobs = {job["selector_unit_number"]: job
                    for cohort in sample["snapshot"]["cohorts"] for job in cohort["jobs"]}
            for label, platform, leased in (
                ("selector_b", "QC Beta", relative == 390),
                ("selector_c", "QC Gamma", relative == 360),
            ):
                job = jobs[build["entity_units"][label]]
                assert job["mode"] == "manual", (path, relative, job)
                assert job["target_platform_id"] == configured["platform_ids"][platform], (path, relative, job)
                assert job["leased"] is leased, (path, relative, job)
        expected_errors = []
        if relative >= 120:
            expected_errors.append("coordinator-count:1/2")
        if 405 <= relative < 435:
            expected_errors.append(f"duplicate-platform-id:{alpha}")
        validation = sample["baseline_validation"]
        assert Counter(validation.get("errors", [])) == Counter(expected_errors), (path, relative, validation)
        assert validation["ok"] == (not expected_errors)
        gui = sample["gui_validation"]
        assert gui["ok"] and not gui.get("errors"), (path, relative, gui)
        assert gui["summary"]["runtime_present"]
        if gui.get("skipped"):
            assert gui["summary"]["skip_reason"] == "missing-player" and not gui["summary"]["player_present"]
            gui_skips += 1
        else:
            assert gui["summary"]["probe_count"] == 4
    assert seen_ticks == expected_ticks, (path, seen_ticks)
    assert seen_actions == expected_actions, (path, seen_actions)
    return records, {"checkpoints": len(seen_ticks), "actions": len(seen_actions), "gui_skips": gui_skips,
                     "acceptance_pass": not failed_actions, "failed_actions": failed_actions}


def emerald(path):
    records = rows(path, "EMERALD_DOCTRINE_QC ")
    built = next(row for row in records if row["event"] == "built")
    assert built["tank_unit_number"] > 0 and built["reset"]["ok"] and built["configure"]["ok"]
    assert built["configure"]["result"]["tracked_tanks"] == 1
    samples = [row for row in records if row["event"] == "checkpoint"]
    assert [row["relative_tick"] for row in samples] == [1, 30, 120, 360, 720, 1200]
    for row in samples:
        assert row["tick"] == built["tick"] + row["relative_tick"]
        assert row["service"]["ok"] and row["snapshot_ok"] and row["remote_members"] > 0
        assert row["snapshot"]["tick"] == row["tick"] and row["snapshot"]["qc_enabled"]
    assert samples[0]["snapshot"]["tracked_tanks"] == 1
    return [row["snapshot"] for row in samples], {"checkpoints": len(samples)}


def tesla(path):
    header, snapshots = {}, []
    current = header
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        if line == "[snapshot]":
            current = {}
            snapshots.append(current)
        elif "=" in line:
            key, value = line.split("=", 1)
            current[key] = value
    for key in ("initialized", "runtime_synced"):
        assert header[key] == "true", (path, key)
    assert header["queue_interval_ticks"] == "60"
    assert header["tesla_basic_count"] == header["tesla_advanced_count"] == "192"
    for key in ("bulk_researched_count", "rail_count", "charger_count", "train_count"):
        assert int(header[key]) > 0
    researches = [value.strip() for value in header["queued_researches"].split(",")]
    assert len(set(researches)) == 4
    assert [(row["research"], row["label"]) for row in snapshots] == [
        (research, label) for research in researches
        for label in ("pre-complete", "post-immediate", "post-plus-1", "post-plus-2")
    ] + [(researches[-1], "queue-finished")]
    times = []
    for research in researches:
        found = {row["label"]: row for row in snapshots if row.get("research") == research}
        tick = int(found["pre-complete"]["tick"])
        times.append(tick)
        for label, delta in (("pre-complete", 0), ("post-immediate", 0), ("post-plus-1", 1), ("post-plus-2", 2)):
            assert int(found[label]["tick"]) == tick + delta
            assert int(found[label]["tesla.force_cache_count"]) > 0
    assert all(b-a == 60 for a,b in zip(times, times[1:]))
    final = snapshots[-1]
    assert final["label"] == "queue-finished" and final["research"] == researches[-1]
    for key in ("variant_sync_job_count", "variant_sync_pending_job_count", "variant_sync_restart_requested_count", "variant_sync_bucket_items"):
        assert final["tesla."+key] == "0", (path, final)
    return snapshots, {"researches": len(researches), "snapshots": len(snapshots)}


def water(path):
    report = json.loads(path.read_text(encoding="utf-8-sig"))
    assert report["all_pass"] and len(report["cases"]) == 59, path
    assert all(case["pass"] for case in report["cases"].values()), path
    return report, {"cases": len(report["cases"])}


parser = argparse.ArgumentParser()
parser.add_argument("kind", choices=("orbital", "emerald", "tesla", "water"))
parser.add_argument("baseline", type=Path)
parser.add_argument("candidate", type=Path)
parser.add_argument("--report-baseline-failures", action="store_true",
                    help="Orbital only: retain existing failed assertions in an exact report comparison; acceptance remains false.")
args = parser.parse_args()
if args.report_baseline_failures and args.kind != "orbital":
    parser.error("--report-baseline-failures is only supported for orbital reports")
check = {"orbital": orbital, "emerald": emerald, "tesla": tesla, "water": water}[args.kind]
if args.report_baseline_failures:
    check = lambda path: orbital(path, report_baseline_failures=True)
old, old_summary = check(args.baseline)
new, new_summary = check(args.candidate)
assert old == new, "Baseline/candidate runtime snapshots differ; inspect reports before accepting."
assert old_summary == new_summary, "Baseline/candidate acceptance results differ."
print(json.dumps({"kind": args.kind, "baseline": old_summary, "candidate": new_summary, "snapshots_equal": True}, indent=2))

"""Stage exact candidate lifecycle inputs and cheap state markers; no engine."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import sys

from PIL import Image, ImageDraw

STATES = ["folded", "preparing", "prepared", "starting-attack", "attacking",
          "ending-attack", "rotate-for-folding", "folding"]
PHASES = ["preparing", "running", "folding"]
KINDS = ["save_load", "ammo_shortage", "energy_shortage", "script_disable", "circuit_disable", "freeze_thaw"]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def load(path, name):
    sys.path.insert(0, str(path.parent))
    try:
        spec = importlib.util.spec_from_file_location(name, path)
        result = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(result)
        return result
    finally:
        sys.path.pop(0)


def build(args):
    generator = args.repo.resolve() / ".codex/esir/asset-generators/minigun-turret"
    emitter = load(generator / "emit_graphics_data.py", "lifecycle_emitter")
    contract = load(args.evidence_contract.resolve(), "lifecycle_firing_contract")
    art = read(args.candidate_data.parent / "graphics-data.json")
    if (art.get("schema") != "esir.minigun.graphics.v2" or
        art.get("provenance", {}).get("direction_indices") != list(range(256))):
        raise ValueError("Lifecycle acceptance requires actual full256 candidate metadata")
    if args.output.exists() and (args.output / "fixture-plan.json").exists():
        raise ValueError("Refusing to replace an existing staged lifecycle request")
    args.output.mkdir(parents=True, exist_ok=True)
    for source, name in ((args.candidate_data, "candidate-graphics-data.lua"),
                         (args.mechanical_data, "candidate-mechanical-data.lua"), (args.anchors, "muzzle-anchors.json")):
        shutil.copy2(source, args.output / name)
    shutil.copytree(args.candidate_assets, args.output / "candidate", dirs_exist_ok=False)
    manifest = contract.build_candidate_asset_manifest(args.output / "candidate-graphics-data.lua", args.output / "candidate")
    # The firing matrix input is the authority, not a new atlas assembled here.
    if manifest != read(args.assets_manifest):
        raise ValueError("Lifecycle candidate PNGs differ from the full firing manifest")
    shutil.copy2(args.assets_manifest, args.output / "candidate-assets-manifest.json")
    lineage = {"source_sha256": emitter.SOURCE_SHA256,
        "compiled_metadata_sha256": art["provenance"]["compiled_metadata_sha256"],
        "candidate_data_sha256": sha(args.candidate_data), "mechanical_data_sha256": sha(args.mechanical_data),
        "anchors_sha256": sha(args.anchors), "atlas_inventory_sha256": contract.canonical_sha(manifest["files"])}
    graphics = args.output / "graphics"; graphics.mkdir(exist_ok=True)
    for index in range(8):
        image = Image.new("RGBA", (64, 12), (32, 48, 32, 255))
        draw = ImageDraw.Draw(image)
        draw.rectangle((0, 0, 5, 11), fill=(255, 0, 255, 255))
        draw.rectangle((58, 0, 63, 11), fill=(0, 255, 255, 255))
        for bit in range(3):
            left = 12 + bit * 14
            draw.rectangle((left, 2, left + 9, 9), fill="white" if index & (1 << bit) else "black")
        image.save(graphics / f"state-{index}.png", optimize=True)
    cases = [{"id": kind + "/" + phase, "kind": kind, "phase": phase} for kind in KINDS for phase in PHASES]
    config = {"schema": 1, "profile": args.profile, "ballistic": args.mode == "on", "lineage": lineage,
        "fixture_sources_sha256": {name:sha(args.output/name) for name in
            ("info.json","settings-updates.lua","data-final-fixes.lua","control.lua",
             "build_fixture.py","analyze_fixture.py","evidence_contract.py")},
        "assets_manifest_sha256": sha(args.assets_manifest), "preparing_ticks": art["preparing_ticks"],
        "folding_ticks": art["folding_ticks"], "fold_delay_ticks": args.fold_delay_ticks,
        "freeze_lead_ticks": args.freeze_lead_ticks, "cases": cases, "states": STATES,
        "checkpoint_prefix": "mg-lifecycle-" + args.run_id[:8], "maximum_case_ticks": 1800,
        "fixture_contract": "native phase must be decoded at actual interruption; scheduled ticks alone never pass"}
    (args.output / "test-config.lua").write_text("return " + emitter.lua(config) + "\n", encoding="utf-8")
    plan = {"schema": "esir.minigun.lifecycle-plan.v1", "config": config,
            "baseline_ticks": 18 * 1800 + 1000, "resume_ticks": 2000,
            "status": "staged_only_native_execution_and_visual_review_pending"}
    (args.output / "fixture-plan.json").write_text(json.dumps(plan, indent=2) + "\n", encoding="utf-8")
    return plan


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("repo", "output", "candidate-data", "candidate-assets", "mechanical-data", "anchors",
                 "assets-manifest", "evidence-contract"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--profile", choices=("sd", "hd"), default="sd")
    parser.add_argument("--mode", choices=("on", "off"), default="on")
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--fold-delay-ticks", type=int, default=0)
    parser.add_argument("--freeze-lead-ticks", type=int, default=0)
    args = parser.parse_args()
    if not 0 <= args.fold_delay_ticks <= 120 or not 0 <= args.freeze_lead_ticks <= 900:
        parser.error("Timing calibration is out of the supported bounds")
    print(json.dumps(build(args)))

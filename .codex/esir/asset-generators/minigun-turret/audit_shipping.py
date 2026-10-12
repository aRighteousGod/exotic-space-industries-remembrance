"""Read-only final minigun destination/ZIP audit; never installs or starts an engine."""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import zipfile

GEN = ".codex/esir/asset-generators/minigun-turret"
PACKS = {"exotic-space-industries-remembrance-graphics-6": "sd",
         "minigun-turret-HD": "hd"}
HD = "minigun-turret-HD"
MAIN = "exotic-space-industries-remembrance/prototypes/electricity-age/gatling-turret/graphics-data.lua"
CAP = 256_000_000


def shared_path_boundary():
    # Reuse the installed evidence helper's drive/UNC handling without changing
    # logical paths in receipts, relative-name checks, or containment comparisons.
    for root in Path(__file__).absolute().parents:
        source = root / GEN / "firing-fixture/evidence_contract.py"
        if source.is_file():
            spec = importlib.util.spec_from_file_location("minigun_shipping_path_boundary", source)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            return module.fs_path, source
    raise ValueError("Installed minigun evidence fs_path helper is missing")


fs_path, PATH_HELPER = shared_path_boundary()


def logical_path(path):
    value = os.fspath(path)
    if os.name == "nt":
        if value.startswith("\\\\?\\UNC\\"):
            value = "\\\\" + value[8:]
        elif value.startswith("\\\\?\\"):
            value = value[4:]
    return Path(value).absolute()


def require(value, message):
    if not value:
        raise ValueError(message)


def sha(path):
    result = hashlib.sha256()
    with fs_path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def read(path):
    return json.loads(fs_path(path).read_text(encoding="utf-8-sig"))


def safe_file(repo, path):
    """Accept ordinary files and hardlinks; reject path traversal and reparses."""
    raw = Path(path)
    require(".." not in raw.parts, "Parent traversal refused: " + str(path))
    repo = logical_path(repo)
    path = logical_path(raw if raw.is_absolute() else repo / raw)
    require(path.is_relative_to(repo) and fs_path(path).is_file(), "Missing or external file: " + str(path))
    for part in [path, *path.parents]:
        if part == repo:
            break
        actual = fs_path(part)
        require(not actual.is_symlink() and not (getattr(actual.stat(), "st_file_attributes", 0) & 1024),
                "Reparse source/destination refused: " + str(part))
    return path


def file_record(path):
    return {"sha256": sha(path), "bytes": fs_path(path).stat().st_size}


def same_file_bytes(path, record, label):
    require(type(record.get("bytes")) is int and record["bytes"] >= 0,
            "Missing byte count: " + label)
    require(file_record(path) == {key: record[key] for key in ("sha256", "bytes")},
            "Absent/stale/changed bytes: " + label)


def destination(row, support=False):
    pack = row.get("pack")
    require(pack in PACKS and row.get("profile") == PACKS[pack], "Wrong asset pack/density")
    value = row.get("path", "")
    path = PurePosixPath(value)
    require(value and not path.is_absolute() and ".." not in path.parts and "\\" not in value
            and path.as_posix() == value, "Unsafe/noncanonical artifact destination")
    if support:
        require((pack, value, row.get("role")) == (HD, "lib/graphics-data.lua", "graphics_library_metadata"),
                "Unexpected generated support artifact")
    else:
        require(path.suffix == ".png" and (value.startswith("graphics/entities/gatling-turret/")
                or value in ("graphics/items/gatling-turret.png", "graphics/techs/gatling-turret.png")),
                "PNG destination is outside the minigun family")
    return pack, value


def inspect_finalizer(repo, finalized):
    receipt_path = safe_file(repo, finalized / "finalization-receipt.json")
    receipt = read(receipt_path)
    require(receipt.get("schema") == "esir.minigun.finalization-receipt.v1"
            and receipt.get("ready_for_staged_integration") is True
            and receipt.get("production_promoted") is False, "Expected a real staged finalizer receipt")
    expected = {"graphics-data.lua", "graphics-data.json", "hd-example-graphics-data.lua", "artifact-map.json"}
    require(set(receipt.get("outputs", {})) == expected, "Finalizer output inventory differs")
    for name, record in receipt["outputs"].items():
        same_file_bytes(safe_file(repo, finalized / name), record, "finalizer output " + name)
    require(receipt["validators"]["finalizer"] == sha(safe_file(repo, repo / GEN / "finalize_graphics_data.py")),
            "Canonical finalizer differs from this receipt; review source drift")
    mapping = read(finalized / "artifact-map.json")
    contract = read(finalized / "graphics-data.json")
    require(mapping.get("schema") == "esir.minigun.artifact-map.v1"
            and mapping.get("complete_direction_family") is True
            and not mapping.get("budget_measurement_only") and mapping.get("production_promoted") is False,
            "Budget/pilot/promoted map is not the finalizer map")
    require(mapping.get("graphics_data_filename") == "graphics-data.lua"
            and mapping.get("graphics_data_sha256") == receipt["outputs"]["graphics-data.lua"]["sha256"]
            and mapping.get("frozen_profile_contract") == contract, "Finalized main metadata/map differs")
    lineage = {key: value for key, value in receipt.items() if key != "outputs"}
    require(mapping.get("finalization") == lineage
            and contract.get("provenance", {}).get("finalization_evidence") == lineage
            and contract["provenance"].get("muzzle_native_calibrated") is True
            and contract["provenance"].get("direction_indices") == list(range(256))
            and set(contract.get("profiles", {})) == {"sd", "hd"}
            and mapping.get("compiled_metadata_sha256") == receipt["lineage"]["compiled_metadata_sha256"],
            "Finalized metadata is not bound to the complete accepted lineage")
    return receipt, mapping


def pack_inventory(repo, pack):
    root = repo / pack
    info = read(safe_file(repo, root / "info.json"))
    require(info.get("name") == pack and info.get("version") == "1.0.0"
            and info.get("license") == "GPL-3.0-or-later"
            and info.get("dependencies") == (["base >= 2.0.77", "? space-age >= 2.0.77"] if pack == HD else ["base >= 2.0.0"]), "Pack metadata contract differs: " + pack)
    required = ["info.json", "LICENSE.md", "attribution.txt", "changelog.txt"]
    if pack == HD:
        required += ["README.md", "data.lua", "data-final-fixes.lua", "prototypes/minigun-turret.lua", "examples/data.lua", "lib/graphics.lua", "lib/graphics-data.lua"]
    for relative in required:
        require(fs_path(safe_file(repo, root / relative)).stat().st_size > 0, "Empty required pack support file")
    for loader in ("data.lua", "data-updates.lua", "data-final-fixes.lua", "control.lua",
                   "settings.lua", "settings-updates.lua", "settings-final-fixes.lua"):
        if pack == HD and loader in ("data.lua", "data-final-fixes.lua"):
            continue
        require(not fs_path(root / loader).exists(), "Unexpected pack loader: " + pack + "/" + loader)
    files = {}
    folded = set()
    physical_root = fs_path(root)
    for physical in sorted(physical_root.rglob("*")):
        path = root / physical.relative_to(physical_root)
        require(not physical.is_symlink() and not (getattr(physical.stat(), "st_file_attributes", 0) & 1024),
                "Linked pack entry refused: " + str(path))
        if physical.is_file():
            path = safe_file(repo, path)
            name = path.relative_to(root).as_posix()
            require(name.casefold() not in folded, "Case-colliding pack paths")
            folded.add(name.casefold())
            files[name] = file_record(path)
    return files


def verify_installed(repo, finalized, receipt, mapping):
    same_file_bytes(safe_file(repo, repo / MAIN), receipt["outputs"]["graphics-data.lua"], "installed main metadata")
    require(len(mapping.get("support_artifacts", [])) == 1, "Exactly one generated HD example is required")
    expected = {pack: {} for pack in PACKS}
    source_records = {}
    for support, rows in ((False, mapping["artifacts"]), (True, mapping["support_artifacts"])):
        for row in rows:
            pack, relative = destination(row, support)
            require(relative.casefold() not in {name.casefold() for name in expected[pack]}, "Duplicate destination")
            source = Path(row["source"])
            source = safe_file(repo, source if source.is_absolute() else finalized / source)
            if support:
                require(source == logical_path(finalized / "hd-example-graphics-data.lua")
                        and row["sha256"] == receipt["outputs"]["hd-example-graphics-data.lua"]["sha256"],
                        "Generated HD example source differs from the finalizer")
            same_file_bytes(source, row, "frozen source " + relative)
            target = safe_file(repo, repo / pack / relative)
            same_file_bytes(target, row, "installed destination " + pack + "/" + relative)
            expected[pack][relative] = {key: row[key] for key in ("sha256", "bytes")}
            source_records[str(source)] = file_record(source)
    inventories = {pack: pack_inventory(repo, pack) for pack in PACKS}
    for pack, files in inventories.items():
        require(any(name.startswith("graphics/") for name in expected[pack]), "Missing complete pack PNG inventory")
        actual_family = {name for name in files if name.startswith("graphics/entities/gatling-turret/")
                         or name in ("graphics/items/gatling-turret.png", "graphics/techs/gatling-turret.png")}
        wanted_family = {name for name in expected[pack] if name.startswith("graphics/")}
        require(actual_family == wanted_family, "Missing/unmapped minigun files in installed pack: " + pack)
    return expected, inventories, source_records


def verify_archive(repo, archives, record, inventory, overlays):
    pack = record["pack"]
    require(pack in PACKS and record.get("version") == "1.0.0", "Archive pack/version differs")
    archive = safe_file(repo, Path(record["path"]))
    require(archive.parent == archives and archive.name == pack + "_1.0.0.zip", "Archive path/name differs")
    before = file_record(archive)
    require(before == {"sha256": record["sha256"], "bytes": record["zip_bytes"]}
            and before["bytes"] < CAP and record.get("strict_cap_passed") is True
            and record.get("zip_integrity_passed") is True, "Archive changed, failed, or exceeds strict cap")
    wanted = [{"path": path, **data, "minigun_overlay": path in overlays} for path, data in sorted(inventory.items())]
    require(record.get("files") == wanted and record.get("file_count") == len(wanted),
            "Archive measurement omits or changes an installed pack/support file")
    prefix = pack + "_1.0.0/"
    with zipfile.ZipFile(fs_path(archive)) as opened:
        names = opened.namelist()
        require(len(names) == len(set(names)) == len(inventory)
                and set(names) == {prefix + name for name in inventory}, "ZIP does not contain exactly the complete installed pack")
        for path, expected in inventory.items():
            info = opened.getinfo(prefix + path)
            require(not info.is_dir() and not info.flag_bits & 1 and info.file_size == expected["bytes"],
                    "Invalid/encrypted ZIP entry: " + path)
            digest = hashlib.sha256()
            with opened.open(info) as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                    digest.update(chunk)
            require(digest.hexdigest() == expected["sha256"], "ZIP bytes differ from installed destination: " + path)
    require(file_record(archive) == before, "Archive changed during audit")
    return {"pack": pack, "sha256": before["sha256"], "zip_bytes": before["bytes"],
            "installed_file_count": len(inventory), "exact_installed_inventory_verified": True}


def audit(repo, finalized, archives=None):
    repo = logical_path(repo); finalized = logical_path(finalized)
    receipt, mapping = inspect_finalizer(repo, finalized)
    original = {name: file_record(finalized / name) for name in (*receipt["outputs"], "finalization-receipt.json")}
    expected, inventories, sources = verify_installed(repo, finalized, receipt, mapping)
    results = []
    if archives:
        archives = logical_path(archives)
        measurement_path = safe_file(repo, archives / "archive-measurement.json")
        measurement_before = file_record(measurement_path)
        measurement = read(measurement_path)
        require(measurement.get("schema") == "esir.minigun.archive-measurement.v1"
                and measurement.get("artifact_map_sha256") == sha(finalized / "artifact-map.json")
                and measurement.get("generator_sha256") == sha(safe_file(repo, repo / GEN / "measure_packages.py"))
                and measurement.get("strict_caps_passed") is True, "Archive measurement is not bound to the finalizer map/current writer")
        records = measurement.get("archives", [])
        require(len(records) == 2 and {row["pack"] for row in records} == set(PACKS), "Both complete final archives are required")
        results = [verify_archive(repo, archives, row, inventories[row["pack"]], expected[row["pack"]]) for row in records]
        require(file_record(measurement_path) == measurement_before, "Archive measurement changed during audit")
    require(all(file_record(finalized / name) == value for name, value in original.items())
            and all(file_record(Path(path)) == value for path, value in sources.items())
            and {pack: pack_inventory(repo, pack) for pack in PACKS} == inventories,
            "Finalized inputs or installed pack changed during audit")
    same_file_bytes(safe_file(repo, repo / MAIN), receipt["outputs"]["graphics-data.lua"], "installed main metadata after audit")
    return {"schema": "esir.minigun.installed-shipping-audit.v1", "audit_sha256": sha(Path(__file__)),
            "filesystem_path_helper_sha256": sha(PATH_HELPER),
            "finalization_receipt_sha256": original["finalization-receipt.json"]["sha256"],
            "artifact_map_sha256": original["artifact-map.json"]["sha256"],
            "installed_main_metadata_verified": True, "installed_destinations_verified": True,
            "verified_overlay_files": {pack: len(files) for pack, files in expected.items()},
            "installed_pack_files": inventories, "archives": results,
            "complete_final_archives_verified": bool(archives), "archive_verification_pending": not bool(archives),
            "writes": False, "engines_started": False, "final_release_approval": False}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--finalized", type=Path, required=True)
    parser.add_argument("--archives", type=Path, help="Directory with finalizer-backed archive-measurement.json and both ZIPs")
    args = parser.parse_args()
    print(json.dumps(audit(args.repo, args.finalized, args.archives), indent=2, allow_nan=False))

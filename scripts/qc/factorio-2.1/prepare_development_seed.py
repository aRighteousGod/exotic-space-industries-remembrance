"""Promote a verified dependency-only seed and an accepted native core smoke save.

Does not alter the preserved input archives, installed mods, or source folders.
Startup settings use the core's tested defaults; no historical settings are copied.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def copy_verified(source, target):
    if target.exists():
        if digest(source) != digest(target):
            raise RuntimeError("Existing target differs; preserve and review before replacing: " + str(target))
    else:
        shutil.copy2(source, target)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dependencies", type=Path, required=True)
    parser.add_argument("--smoke", type=Path, required=True)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[3]
    profile = json.loads((repo / ".codex/esir/factorio-development.json").read_text(encoding="utf-8"))
    lock_path = args.dependencies / "dependency-lock-2.1.json"
    assert digest(lock_path) == profile["dependency_lock_sha256"], "Unexpected dependency lock"
    lock = json.loads(lock_path.read_text(encoding="utf-8"))
    seed = repo / profile["dependency_seed"]
    seed.mkdir(parents=True, exist_ok=True)
    enabled = {"base", "space-age", "quality", "recycler", "elevated-rails", "zzz-nonstandard-beacons-continued"}
    for row in lock:
        source = args.dependencies / row["file"]
        assert row["info"]["factorio_version"] == "2.1" and digest(source) == row["sha256"], row["name"]
        copy_verified(source, seed / row["file"])
        enabled.add(row["name"])
    for source in repo.iterdir():
        if source.name.startswith("exotic-space-industries-remembrance") or source.name in ("doeworks-deer-continued", "enhanced-walls-continued"):
            info_path = source / "info.json"
            if info_path.is_file():
                info = json.loads(info_path.read_text(encoding="utf-8-sig"))
                assert info["factorio_version"] == "2.1", source
                enabled.add(info["name"])
    assert len(enabled) == 40, sorted(enabled)
    copy_verified(lock_path, seed / lock_path.name)
    mod_list = {"mods": [{"name": name, "enabled": True} for name in sorted(enabled)] +
        [{"name": name, "enabled": False} for name in ("minigun-turret-HD", "minigun-turret-HD-graphics")]}
    (seed / "mod-list.json").write_text(json.dumps(mod_list, indent=2), encoding="utf-8")
    smoke = repo / profile["smoke_save"]
    copy_verified(args.smoke, smoke)
    receipt = {"enabled_mods": len(enabled), "dependency_archives": len(lock), "seed": str(seed),
        "smoke_save": str(smoke), "smoke_sha256": digest(smoke), "startup_settings": "tested core defaults",
        "dependency_lock_sha256": digest(lock_path)}
    # The receipt belongs outside the dependency seed's deliberately narrow contents.
    (seed.parent / "2.1-core.receipt.json").write_text(json.dumps(receipt, indent=2), encoding="utf-8")
    print(json.dumps(receipt))


if __name__ == "__main__":
    main()

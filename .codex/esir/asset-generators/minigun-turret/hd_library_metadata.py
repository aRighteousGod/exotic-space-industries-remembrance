"""Project accepted graphics metadata into the public, self-contained HD API."""
from __future__ import annotations
import copy

HD = "minigun-turret-HD-graphics"
LEGACY_HD = "minigun-turret-HD"
OLD_HD = "e-s-i-r-minigun-turret-graphics-hd"


def library_metadata(art, asset_pack=HD):
    """Emit the current asset root; pass LEGACY_HD to reproduce 2.0 receipts."""
    def rename(value):
        if isinstance(value, dict):
            return {key: rename(child) for key, child in value.items()}
        if isinstance(value, list):
            return [rename(child) for child in value]
        if isinstance(value, str):
            for source in (OLD_HD, LEGACY_HD):
                value = value.replace("__" + source + "__/", "__" + asset_pack + "__/")
            return value
        return value

    provenance = art["provenance"]
    return {
        "schema": "minigun-turret.graphics.v1", "hd_major": art["hd_major"],
        "preparing_ticks": art["preparing_ticks"], "folding_ticks": art["folding_ticks"],
        "profiles": {"hd": rename(copy.deepcopy(art["profiles"]["hd"]))},
        "projectile_creation_parameters": copy.deepcopy(art["projectile_creation_parameters"]),
        "native_launch_contract": copy.deepcopy(art.get("native_launch_contract", {})),
        "provenance": {
            "complete_direction_family": provenance["complete_direction_family"],
            "muzzle_native_calibrated": provenance["muzzle_native_calibrated"],
            "direction_indices": copy.deepcopy(provenance["direction_indices"]),
        },
    }

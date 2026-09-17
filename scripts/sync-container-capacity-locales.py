"""Generate/check Factorio's static option tooltips from the shared Lua profile table.

The main setting tooltip is parameterized in Lua. Factorio's option descriptions
are locale-only, so these generated rows are checked during container QC.
"""
import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "exotic-space-industries-remembrance"
TIERS = ("wooden", "iron", "steel", "small", "medium", "warehouse")


def profiles():
    source = (PACK / "lib/container-capacity-config.lua").read_text(encoding="utf-8")
    rows = {}
    for name, fields in re.findall(r"^    (\w+) = \{(wooden = [^}]+)\},$", source, re.M):
        values = dict(re.findall(r"(\w+) = (\d+)", fields))
        rows[name] = [int(values[tier]) for tier in TIERS]
    assert len(rows) == 8, "Expected exactly eight capacity profiles"
    assert all(v > 0 and v % 8 == 0 for row in rows.values() for v in row)
    assert all(row == sorted(row) and row[3] < row[4] < row[5] for row in rows.values())
    ordered = list(rows.values())
    assert all(all(a <= b for a, b in zip(first, second)) for first, second in zip(ordered, ordered[1:]))
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="Refresh generated option descriptions")
    args = parser.parse_args()
    rows = profiles()
    for language in ("en", "fr", "ja", "pl", "ru", "zh-CN", "zh-TW"):
        path = PACK / "locale" / language / "container-capacity.cfg"
        text = path.read_text(encoding="utf-8")
        assert "ei-container-capacity-profile=" in text and "\\n__1__" in text
        assert all(f"ei-container-capacity-profile-{name}=" in text for name in rows)
        template = re.search(r"^option-template=(.+)$", text, re.M).group(1)
        base = text.split("[string-mod-setting-description]")[0].rstrip()
        lines = []
        for name, values in rows.items():
            rendered = template
            for index, value in enumerate(values, 1):
                rendered = rendered.replace(f"__{index}__", str(value))
            assert not re.search(r"__\d+__", rendered)
            lines.append(f"ei-container-capacity-profile-{name}={rendered}")
        expected = base + "\n\n[string-mod-setting-description]\n" + "\n".join(lines) + "\n"
        if args.write:
            path.write_text(expected, encoding="utf-8", newline="\n")
        else:
            assert text == expected, f"Stale option tooltips: {path}; run this script with --write"
    print("Container capacity locale tooltips: 8 profiles x 7 languages verified.")


if __name__ == "__main__":
    main()

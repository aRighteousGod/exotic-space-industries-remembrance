"""Audit shipping radar locale parity and the event-tick convention."""
from pathlib import Path
import re

repo = Path(__file__).resolve().parents[3]
pack = repo / "exotic-space-industries-remembrance"
languages = ("en", "fr", "ja", "pl", "ru", "zh-CN", "zh-TW")
catalog = {}
for language in languages:
    path = pack / "locale" / language / "sweeping-radar.cfg"
    raw = path.read_bytes()
    assert not raw.startswith(b"\xef\xbb\xbf"), f"BOM: {path}"
    text = raw.decode("utf-8")
    assert "\ufffd" not in text
    section = ""
    entries = {}
    for line in text.splitlines():
        if line.startswith("["):
            section = line
        elif "=" in line and not line.startswith((";", "#")):
            key, value = line.split("=", 1)
            identity = section + key
            assert identity not in entries, f"Duplicate {language}: {identity}"
            assert value, f"Empty {language}: {identity}"
            entries[identity] = sorted(re.findall(r"__\d+__", value))
    catalog[language] = entries
    assert entries == catalog["en"], f"Locale keys/placeholders differ: {language}"
for path in list((pack / "lib").glob("sweeping-radar*.lua")) + list((pack / "scripts/control").glob("sweeping-radar*.lua")):
    assert "game.tick" not in path.read_text(encoding="utf-8"), path
print(f"Radar audit passed: {len(languages)} locales, {len(catalog['en'])} keys each; no game.tick in radar modules.")

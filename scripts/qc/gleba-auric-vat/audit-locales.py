"""Validate the changed Auric locale contract without rewriting translations."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[3]
base = root / "exotic-space-industries-remembrance/locale"
languages = ("de", "en", "fr", "ja", "pl", "ru", "zh-CN", "zh-TW")
files = ("auric-inoculation-vat.cfg", "auric-inoculation-vat-informatron.cfg")
checks = 0
for language in languages:
    for name in files:
        section = ""
        entries = {}
        for line in (base / language / name).read_text(encoding="utf-8-sig").splitlines():
            if line.startswith("[") and line.endswith("]"):
                section = line[1:-1]
            elif "=" in line and not line.startswith((";", "#")):
                key, value = line.split("=", 1)
                identity = (section, key)
                assert identity not in entries, (language, name, identity, "duplicate")
                entries[identity] = value
                assert "\ufffd" not in value, (language, key, "replacement character")
        checks += 1
        if name == files[0]:
            key = "ei-productivity-auric-cyst-washing"
            assert entries[("technology-name", key)]
            description = entries[("technology-description", key)]
            assert "10" in description and "300" in description
            checks += 3
        else:
            band = entries[("exotic-industries-informatron", "auric-inoculation-vat-text-2")]
            assert all(str(n) in band for n in (6, 8, 12, 16, 20, 24, 28))
            wash = entries[("exotic-industries-informatron", "auric-inoculation-vat-text-4")]
            assert "[technology=ei-productivity-auric-cyst-washing]" in wash and "300" in wash
            checks += 2
result = {"checks": checks, "languages": list(languages), "files": len(languages)*len(files), "status": "passed"}
print(json.dumps(result, ensure_ascii=False))

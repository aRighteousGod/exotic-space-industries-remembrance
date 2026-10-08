"""Check terrain settings coverage without using or replacing a final-data dump."""
from pathlib import Path
from collections import Counter
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
LOCALES = ROOT / "exotic-space-industries-remembrance/locale"
LANGUAGES = ("en", "fr", "ja", "pl", "ru", "zh-CN", "zh-TW")


def entries(path, strict=True):
    raw = path.read_bytes()
    assert not raw.startswith(b"\xef\xbb\xbf"), f"UTF-8 BOM: {path}"
    text = raw.decode("utf-8")
    assert "\ufffd" not in text, f"Replacement character: {path}"
    section, result = "", {}
    for number, line in enumerate(text.splitlines(), 1):
        line = line.strip()
        if not line or line.startswith((";", "#")):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            continue
        key, separator, value = line.partition("=")
        assert section and separator and (value or not strict), f"Malformed entry: {path}:{number}"
        full_key = f"{section}.{key}"
        assert not strict or full_key not in result, f"Duplicate key: {path}:{number}: {full_key}"
        result[full_key] = value
    return result


def tokens(value):
    return Counter(re.findall(r"__\d+__|\[/?color(?:=[^\]]+)?\]|\\n", value))


def audit():
    english = entries(LOCALES / "en/terrain-evolution.cfg")
    anchors = {}
    for path in (LOCALES / "en").glob("*.cfg"):
        anchors.update(entries(path, strict=False))
    report = {}
    for language in LANGUAGES:
        path = LOCALES / language / "terrain-evolution.cfg"
        values = entries(path)
        assert not english.keys() - values.keys(), f"Missing terrain keys: {language}"
        assert not values.keys() - anchors.keys(), f"Missing English anchors: {language}"
        for key, value in english.items():
            translated = values[key]
            assert tokens(translated) == tokens(value), (language, key)
            if key.startswith("string-mod-setting-description.ei-terrain-performance-") and not key.endswith("-custom"):
                # Japanese naturally says 'per one service'; that 1 is not a cap.
                translated = translated.replace("\u51e6\u74061\u56de\u3042\u305f\u308a", "per service")
                assert sorted(re.findall(r"\d+", translated)) == sorted(re.findall(r"\d+", value)), (language, key)
        for sibling in path.parent.glob("*.cfg"):
            if sibling != path:
                assert not values.keys() & entries(sibling, strict=False).keys(), sibling
        report[language] = {"keys": len(values), "pass": True}
    source = """local c=dofile('exotic-space-industries-remembrance/lib/terrain-evolution-config.lua')
for _,r in ipairs(c.schema) do
    print('mod-setting-name.'..r.setting_name)
    print('mod-setting-description.'..r.setting_name)
    for _,v in ipairs(r.values or {}) do
        print('string-mod-setting.'..r.setting_name..'-'..v)
        print('string-mod-setting-description.'..r.setting_name..'-'..v)
    end
end"""
    required = subprocess.check_output(
        [str(ROOT / ".tools/lua-5.4.8/lua54.exe"), "-e", source],
        cwd=ROOT, text=True,
    ).splitlines()
    assert not set(required) - english.keys(), sorted(set(required) - english.keys())
    print(json.dumps({"pass": True, "schema_locale_keys": len(required), "locales": report}, indent=2))


if __name__ == "__main__":
    audit()

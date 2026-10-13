"""Reject fallback-only doctrine locales and damaged translation parameters."""
from collections import Counter
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[3]
LOCALES = ROOT / "exotic-space-industries-remembrance" / "locale"
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
    baseline = entries(LOCALES / "en" / "combat-doctrines.cfg")
    assert len(baseline) == 63, "Unexpected English doctrine key set"
    for page in ("pyric_radiance", "ballistic_divergence"):
        for prefix in ("menu_", "title_"):
            assert f"exotic-industries-informatron.{prefix}{page}" in baseline
    for language in LANGUAGES:
        path = LOCALES / language / "combat-doctrines.cfg"
        translated = entries(path)
        assert translated.keys() == baseline.keys(), f"Key coverage mismatch: {language}"
        for key, source in baseline.items():
            target = translated[key]
            assert tokens(target) == tokens(source), f"Parameter/markup mismatch: {language}: {key}"
            if key.startswith("string-mod-setting.") or key.startswith("exotic-industries-informatron.menu_") or key.startswith("exotic-industries-informatron.title_"):
                assert target == source, f"Proper name changed: {language}: {key}"
            # Ordinary counts may be written as words or digits in each language.
            # The specified scatter, penetration and resistance constants must stay exact.
            constants = {
                "mod-setting-description.ei-ballistic-divergence": ("25",),
                "mod-setting-description.ei-ballistic-divergence-preset": ("16", "0.16", "0.40", "2", "65", "4", "75"),
                "exotic-industries-informatron.ballistic-divergence-text": ("25",),
            }.get(key, ())
            numbers = [number.replace(",", ".") for number in re.findall(r"\d+(?:[.,]\d+)?", target)]
            assert all(number in numbers for number in constants), f"Mechanical constants changed: {language}: {key}"
        # Prevent duplicate definitions in another shipping locale sidecar.
        travel_field = translated["ballistic-divergence.row"].split("__3__", 1)[0]
        units = {"en": "tiles", "fr": "cases", "ja": "タイル", "pl": "pola", "ru": "клетки", "zh-CN": "格", "zh-TW": "格"}
        assert units[language] in travel_field and not re.search(r"__2__\s*(?:x|倍)", travel_field), f"Extra-travel unit changed: {language}"
        for other in path.parent.glob("*.cfg"):
            if other != path:
                duplicates = translated.keys() & entries(other, strict=False).keys()
                assert not duplicates, f"Doctrine key collision: {other}: {sorted(duplicates)}"
        print(f"{language}: {len(translated)} keys; UTF-8, placeholders, markup, names and constants match")


if __name__ == "__main__":
    audit()

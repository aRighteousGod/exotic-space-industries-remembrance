"""Focused induction circuit locale coverage; optional pre-edit token comparison."""
import argparse
import collections
import json
import pathlib
import re

LOCALES = ("en", "de", "fr", "ja", "pl", "ru", "zh-CN", "zh-TW")
KEYS = tuple("induction-matrix-circuit-" + key for key in (
    "stored", "capacity", "max-io", "percent", "output-tooltip",
    "shared-tooltip", "timing-tooltip", "percent-tooltip"))
DEFAULT_OFF = {
    "en": "All outputs are disabled by default",
    "de": "Standardmäßig sind alle Ausgaben deaktiviert",
    "fr": "Toutes les sorties sont désactivées par défaut",
    "ja": "初期設定ではすべての出力が無効",
    "pl": "Wszystkie wyjścia są domyślnie wyłączone",
    "ru": "По умолчанию все выходы отключены",
    "zh-CN": "所有输出默认禁用",
    "zh-TW": "所有輸出預設停用",
}


def read(path):
    entries = collections.defaultdict(list)
    section = ""
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        assert "\ufffd" not in line, f"Replacement character in {path}"
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
        elif "=" in line and not line.startswith((";", "#")):
            key, value = line.split("=", 1)
            entries[section, key].append(value)
    return entries


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", type=pathlib.Path)
    args = parser.parse_args()
    repo = pathlib.Path(__file__).resolve().parents[3]
    relative = pathlib.Path("exotic-space-industries-remembrance/locale")
    english = read(repo / relative / "en/lang_en.cfg")
    results = []
    for locale in LOCALES:
        suffix = pathlib.Path(locale) / f"lang_{locale}.cfg"
        entries = read(repo / relative / suffix)
        for key in KEYS:
            values = entries["exotic-industries", key]
            assert len(values) == 1 and values[0], (locale, key, "missing/duplicate/empty")
            if locale != "en":
                assert values != english["exotic-industries", key], (locale, key, "English fallback")
            assert re.findall(r"__\d+__", values[0]) == re.findall(
                r"__\d+__", english["exotic-industries", key][0]), (locale, key, "placeholders")
        desc = entries["item-description", "ei-induction-matrix-core-circuit-interface"]
        assert len(desc) == 1 and all(token in desc[0] for token in ("C/T/M", "A", "%")), (locale, "defaults")
        assert entries["exotic-industries", "induction-matrix-circuit-timing-tooltip"][0] in desc[0], (locale, "description timing")
        help_rows = [(k, v) for k, v in entries.items() if k[1] == "induction-matrix-2-text"]
        assert len(help_rows) == 1 and len(help_rows[0][1]) == 1, (locale, "help")
        assert DEFAULT_OFF[locale] in desc[0] and DEFAULT_OFF[locale] in help_rows[0][1][0], (locale, "all outputs default off")
        if args.baseline:
            before = read(args.baseline / relative / suffix)
            key, current = help_rows[0]
            original = before[key][0]
            assert re.findall(r"\[[^\]]+\]|__\d+__|\\n", current[0]) == re.findall(
                r"\[[^\]]+\]|__\d+__|\\n", original), (locale, "help formatting changed")
        results.append({"locale": locale, "custom_keys": len(KEYS), "description": True, "help": True, "default_off": True})
    print(json.dumps({"all_pass": True, "locales": results}, ensure_ascii=True, indent=2))


if __name__ == "__main__":
    main()

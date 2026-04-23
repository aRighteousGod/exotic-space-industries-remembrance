#!/usr/bin/env python3
"""
Build a normalized baseline summary for the local recipe-icons-improvement-for-esir
companion mod and optionally diff it against a prior baseline snapshot.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import zipfile
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable


DEFAULT_SOURCE = Path(
    os.path.expandvars(
        r"%APPDATA%\Factorio\mods\recipe-icons-improvement-for-esir_1.1.14.zip"
    )
)
KNOWN_HELPERS = {
    "try_set_order",
    "try_set_subgroup",
    "try_set_full_order",
    "try_set_group",
    "try_hide_factoriopeida",
    "try_redirect_factoriopeida",
    "try_hide_player_crafting",
    "try_hide_signal",
    "try_hide_all",
    "try_purge_item",
    "try_show_factoriopeida",
    "try_show_player_crafting",
    "try_show_dual",
    "try_set_icons",
    "try_set_icons_if",
}
RULE_FILE_PATTERN = re.compile(
    r"^prototypes/esir-(?:2[1-5]|3[0-4]|4[0-3])[a-z]?-.+\.lua$"
)
SUMMARY_TAGS = {"ready-to-map", "needs-rule-design", "out-of-scope-v1"}


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def compact_spaces(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def remove_lua_comments(text: str) -> str:
    text = re.sub(r"--\[\[.*?\]\]", "", text, flags=re.S)
    return re.sub(r"--.*?$", "", text, flags=re.M)


def find_matching(text: str, start: int, open_char: str, close_char: str) -> int:
    if text[start] != open_char:
        raise ValueError(f"Expected {open_char!r} at index {start}")
    depth = 0
    string_quote = None
    escape = False
    idx = start
    while idx < len(text):
        ch = text[idx]
        if string_quote:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == string_quote:
                string_quote = None
        else:
            if ch in ('"', "'"):
                string_quote = ch
            elif ch == open_char:
                depth += 1
            elif ch == close_char:
                depth -= 1
                if depth == 0:
                    return idx
        idx += 1
    raise ValueError(f"Unbalanced {open_char}{close_char} segment")


def split_top_level_args(text: str) -> list[str]:
    args: list[str] = []
    start = 0
    pairs = {"(": ")", "{": "}", "[": "]"}
    stack: list[str] = []
    string_quote = None
    escape = False
    for idx, ch in enumerate(text):
        if string_quote:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == string_quote:
                string_quote = None
            continue
        if ch in ('"', "'"):
            string_quote = ch
            continue
        if ch in pairs:
            stack.append(pairs[ch])
            continue
        if stack and ch == stack[-1]:
            stack.pop()
            continue
        if ch == "," and not stack:
            args.append(text[start:idx].strip())
            start = idx + 1
    tail = text[start:].strip()
    if tail:
        args.append(tail)
    return args


def iter_tables(text: str) -> Iterable[str]:
    clean = remove_lua_comments(text)
    idx = 0
    while True:
        start = clean.find("{", idx)
        if start == -1:
            break
        try:
            end = find_matching(clean, start, "{", "}")
        except ValueError:
            break
        yield clean[start : end + 1]
        idx = end + 1


def extract_string(value: str | None) -> str | None:
    if not value:
        return None
    match = re.search(r'"([^"]+)"', value)
    return match.group(1) if match else None


def extract_lua_list(value: str | None) -> list[str]:
    if not value:
        return []
    return re.findall(r'"([^"]+)"', value)


def parse_lua_scalar(value: str | None) -> Any:
    if value is None:
        return None
    raw = compact_spaces(value).rstrip(",")
    if raw.startswith('"') and raw.endswith('"'):
        return raw[1:-1]
    if raw == "true":
        return True
    if raw == "false":
        return False
    try:
        return int(raw)
    except ValueError:
        try:
            return float(raw)
        except ValueError:
            return raw


def parse_data_raw_target(expr: str) -> dict[str, Any]:
    expr = compact_spaces(expr)
    if expr.startswith("data.raw"):
        segments: list[str] = []
        for match in re.finditer(r'\.([A-Za-z0-9_-]+)|\["([^"]+)"\]', expr[8:]):
            segments.append(match.group(1) or match.group(2))
        if segments:
            prototype_type = segments[0]
            prototype_name = segments[-1]
            return {
                "prototype_type": prototype_type,
                "prototype_name": prototype_name,
                "target_expression": expr,
            }
    quoted = re.findall(r'"([^"]+)"', expr)
    return {
        "prototype_type": None,
        "prototype_name": quoted[-1] if quoted else None,
        "target_expression": expr,
    }


def summarize_helper(name: str, helper_group: str) -> str:
    summaries = {
        "try_get_single_icon": "Clones a single icon layer from a prototype and applies scale, shift, tint, and fallback behavior.",
        "try_get_single_icon_if": "Returns an icon layer only when a condition passes.",
        "pass_icon_if": "Passes through an icon only when a condition passes.",
        "make_icon_outline": "Builds a larger tinted outline version of an icon for readability.",
        "make_corner_outline": "Builds an outline for a corner badge and re-shifts it by corner.",
        "try_set_icons": "Writes replacement icons and resets recipe signal hiding before later cleanup passes.",
        "try_set_icons_if": "Conditionally writes replacement icons.",
        "copy_item_icon_to_picture": "Copies item icon layers into belt-picture style definitions before icon replacement.",
        "try_set_order": "Sets order only when the target exists.",
        "try_set_subgroup": "Sets subgroup only when the target subgroup exists.",
        "try_set_full_order": "Sets subgroup and order together.",
        "try_set_group": "Sets subgroup group for subgroup prototypes.",
        "try_hide_factoriopeida": "Hides a prototype from Factoriopedia and may also hide recipe signals.",
        "try_redirect_factoriopeida": "Redirects Factoriopedia to an alternative and may also hide recipe signals.",
        "try_hide_player_crafting": "Hides a recipe from player crafting.",
        "try_hide_signal": "Hides a recipe from the signal GUI.",
        "try_hide_all": "Marks a prototype hidden.",
        "try_show_factoriopeida": "Re-shows Factoriopedia visibility for non-hidden targets.",
        "try_show_player_crafting": "Re-shows player crafting visibility for non-hidden targets.",
        "try_show_dual": "Re-shows both Factoriopedia and player crafting visibility.",
        "try_purge_item": "Moves a non-recipe item or fluid into a purged subgroup while preserving a full-order snapshot.",
        "try_get_full_order": "Computes a stable full order string from group, subgroup, and target order.",
        "try_set_main_product": "Sets recipe main product when the result list actually contains the requested product.",
    }
    return summaries.get(name, f"{helper_group.title()} helper detected in companion mod.")


class ModReader:
    def __init__(self, source: Path) -> None:
        self.source = source
        self._zip: zipfile.ZipFile | None = None
        self._members: dict[str, str] = {}
        self._root_prefix = ""
        if source.is_file() and source.suffix.lower() == ".zip":
            self._zip = zipfile.ZipFile(source)
            names = [name for name in self._zip.namelist() if not name.endswith("/")]
            roots = {name.split("/", 1)[0] for name in names if "/" in name}
            if len(roots) == 1:
                candidate = next(iter(roots))
                if any(name.startswith(candidate + "/prototypes/") for name in names):
                    self._root_prefix = candidate + "/"
            for name in names:
                rel = name[len(self._root_prefix) :] if name.startswith(self._root_prefix) else name
                self._members[rel.replace("\\", "/")] = name
        elif source.is_dir():
            for file in source.rglob("*"):
                if file.is_file():
                    rel = file.relative_to(source).as_posix()
                    self._members[rel] = rel
        else:
            raise FileNotFoundError(source)

    def list_files(self) -> list[str]:
        return sorted(self._members.keys())

    def read_text(self, rel_path: str) -> str:
        rel_path = rel_path.replace("\\", "/")
        if rel_path not in self._members:
            raise FileNotFoundError(rel_path)
        if self._zip:
            return self._zip.read(self._members[rel_path]).decode("utf-8", errors="replace")
        return (self.source / self._members[rel_path]).read_text(encoding="utf-8", errors="replace")

    def maybe_read_text(self, rel_path: str) -> str | None:
        try:
            return self.read_text(rel_path)
        except FileNotFoundError:
            return None

    def close(self) -> None:
        if self._zip:
            self._zip.close()


def parse_info(reader: ModReader) -> dict[str, Any]:
    info_text = reader.read_text("info.json")
    info = json.loads(info_text)
    return {
        "name": info.get("name"),
        "title": info.get("title"),
        "version": info.get("version"),
        "factorio_version": info.get("factorio_version"),
        "dependencies": info.get("dependencies", []),
    }


def parse_changelog(reader: ModReader, version: str | None) -> dict[str, Any]:
    text = (reader.maybe_read_text("changelog.txt") or "").replace("\r\n", "\n")
    versions: list[dict[str, Any]] = []
    for match in re.finditer(
        r"-{20,}\nVersion:\s*([^\n]+)\nDate:\s*([^\n]+)\n(.*?)(?=\n-{20,}\nVersion:|\Z)",
        text,
        flags=re.S,
    ):
        ver = match.group(1).strip()
        date = match.group(2).strip()
        notes_block = match.group(3)
        features = [
            compact_spaces(line.lstrip("- "))
            for line in re.findall(r"^\s*-\s+(.+)$", notes_block, flags=re.M)
        ]
        versions.append({"version": ver, "date": date, "notes": features})
    latest = next((entry for entry in versions if entry["version"] == version), versions[0] if versions else {})
    return {
        "latest_version": latest.get("version", version),
        "latest_date": latest.get("date"),
        "latest_notes": latest.get("notes", []),
        "versions": versions[:12],
    }


def parse_settings(reader: ModReader) -> list[dict[str, Any]]:
    text = reader.read_text("settings.lua")
    clean = remove_lua_comments(text)
    settings_root = clean.find("data:extend(")
    if settings_root == -1:
        return []
    outer_start = clean.find("{", settings_root)
    if outer_start == -1:
        return []
    try:
        outer_end = find_matching(clean, outer_start, "{", "}")
    except ValueError:
        return []
    settings_block = clean[outer_start + 1 : outer_end]
    settings: list[dict[str, Any]] = []
    for block in iter_tables(settings_block):
        if 'setting_type = "startup"' not in block:
            continue
        name = extract_string(re.search(r'name\s*=\s*"([^"]+)"', block).group(0) if re.search(r'name\s*=\s*"([^"]+)"', block) else None)
        if not name:
            continue
        type_match = re.search(r'(?m)^\s*type\s*=\s*"([^"]+)"', block)
        default_match = re.search(r"(?m)^\s*default_value\s*=\s*([^\n,]+)", block)
        allowed_match = re.search(r"allowed_values\s*=\s*\{(.*?)\}", block, flags=re.S)
        settings.append(
            {
                "name": name,
                "kind": type_match.group(1) if type_match else None,
                "default_value": parse_lua_scalar(default_match.group(1)) if default_match else None,
                "allowed_values": extract_lua_list(allowed_match.group(0) if allowed_match else None),
                "order": extract_string(re.search(r'order\s*=\s*"([^"]+)"', block).group(0) if re.search(r'order\s*=\s*"([^"]+)"', block) else None),
            }
        )
    return settings


def build_effective_default_gates(
    settings: list[dict[str, Any]], config_model: dict[str, Any]
) -> dict[str, str]:
    by_name = {setting["name"]: setting.get("default_value") for setting in settings}
    required = {
        "icon-visibility-esir-hide-signals",
        "icon-visibility-esir-replace-facilities-icons",
        "icon-visibility-esir-replace-items-icons",
        "icon-visibility-esir-replace-weapons-icons",
    }
    if not required.issubset(by_name):
        return {"signal_cleanup": "unknown"}
    hide_signals = bool(by_name["icon-visibility-esir-hide-signals"])
    facilities = by_name["icon-visibility-esir-replace-facilities-icons"] != "none"
    items = by_name["icon-visibility-esir-replace-items-icons"] != "none"
    weapons = by_name["icon-visibility-esir-replace-weapons-icons"] != "none"
    if hide_signals and facilities and items and weapons:
        return {"signal_cleanup": "enabled"}
    return {"signal_cleanup": "disabled"}


def parse_regex_constants(reader: ModReader) -> dict[str, str]:
    text = reader.maybe_read_text("prototypes/0-constants.lua") or ""
    constants: dict[str, str] = {}
    for match in re.finditer(r'const\.([A-Za-z0-9_]+)\s*=\s*"([^"]+)"', text):
        name, value = match.groups()
        if "matching" in name.lower():
            constants[name] = value
    return constants


def parse_config_model(reader: ModReader) -> dict[str, Any]:
    text = reader.read_text("prototypes/0-config.lua")
    sections: dict[str, list[dict[str, str]]] = defaultdict(list)
    current_section = "General"
    for raw_line in text.splitlines():
        stripped = raw_line.strip()
        if not stripped:
            continue
        if stripped.startswith("--"):
            title = stripped.lstrip("-").strip()
            if title and not title.lower().startswith("variables"):
                current_section = title
            continue
        assign = re.match(r"config\.([A-Za-z0-9_]+)\s*=\s*(.+)", stripped)
        if assign:
            sections[current_section].append(
                {
                    "key": assign.group(1),
                    "expression": compact_spaces(assign.group(2)),
                }
            )
    flattened = {
        entry["key"]: {"section": section, "expression": entry["expression"]}
        for section, entries in sections.items()
        for entry in entries
    }
    return {"sections": sections, "flattened": flattened}


def parse_helper_file(text: str, helper_group: str) -> list[dict[str, Any]]:
    names = re.findall(r"local function\s+([A-Za-z0-9_]+)\s*\(", text)
    return [
        {
            "name": name,
            "group": helper_group,
            "summary": summarize_helper(name, helper_group),
        }
        for name in names
    ]


def parse_loader_order(reader: ModReader) -> list[dict[str, Any]]:
    text = reader.read_text("data-final-fixes.lua")
    current_stage = "Top level"
    entries: list[dict[str, Any]] = []
    for raw_line in text.splitlines():
        stripped = raw_line.strip()
        if stripped.startswith("--") and stripped.count("-") < 10:
            label = stripped.lstrip("-").strip()
            if label and not label.lower().startswith("footnote"):
                current_stage = label
            continue
        match = re.search(r'require\("([^"]+)"\)', stripped)
        if match:
            entries.append(
                {
                    "stage": current_stage,
                    "module": match.group(1),
                }
            )
    return entries


def find_named_calls(text: str, names: set[str]) -> list[dict[str, Any]]:
    clean = remove_lua_comments(text)
    results: list[dict[str, Any]] = []
    idx = 0
    while idx < len(clean):
        matched_name = None
        for name in names:
            if clean.startswith(name, idx):
                before = clean[idx - 1] if idx > 0 else ""
                after = clean[idx + len(name)] if idx + len(name) < len(clean) else ""
                if (not before or not (before.isalnum() or before == "_")) and after == "(":
                    matched_name = name
                    break
        if not matched_name:
            idx += 1
            continue
        end = find_matching(clean, idx + len(matched_name), "(", ")")
        args_text = clean[idx + len(matched_name) + 1 : end]
        results.append(
            {
                "helper": matched_name,
                "args_text": args_text,
                "args": split_top_level_args(args_text),
            }
        )
        idx = end + 1
    return results


def parse_rule_entries(path: str, text: str, regex_constants: dict[str, str]) -> dict[str, Any]:
    helper_calls = find_named_calls(text, KNOWN_HELPERS)
    helpers_used = sorted({call["helper"] for call in helper_calls})
    clean = remove_lua_comments(text)
    prototype_mentions = sorted(
        {
            name
            for name in re.findall(r'data\.raw(?:\.[A-Za-z0-9_-]+|\["[^"]+"\])+\["([^"]+)"\]', text)
            if not name.startswith("icon-visibility-")
        }
    )
    rule_entries: list[dict[str, Any]] = []
    for call in helper_calls:
        args = call["args"]
        if not args:
            continue
        target_arg_index = 0
        if call["helper"] == "try_set_icons_if":
            target_arg_index = 1
        if len(args) <= target_arg_index:
            continue
        target = parse_data_raw_target(args[target_arg_index])
        if not target.get("prototype_name"):
            continue
        entry: dict[str, Any] = {
            "helper": call["helper"],
            "prototype_type": target.get("prototype_type"),
            "prototype_name": target.get("prototype_name"),
            "target_expression": target.get("target_expression"),
        }
        if call["helper"] == "try_set_icons" and len(args) >= 2:
            entry["icons_expression"] = args[1]
        elif call["helper"] == "try_set_icons_if" and len(args) >= 3:
            entry["condition_expression"] = compact_spaces(args[0])
            entry["icons_expression"] = args[2]
        if call["helper"] == "try_set_full_order" and len(args) >= 3:
            entry["subgroup"] = extract_string(args[1]) or compact_spaces(args[1])
            entry["order"] = extract_string(args[2]) or compact_spaces(args[2])
        elif call["helper"] == "try_set_subgroup" and len(args) >= 2:
            entry["subgroup"] = extract_string(args[1]) or compact_spaces(args[1])
        elif call["helper"] == "try_set_order" and len(args) >= 2:
            entry["order"] = extract_string(args[1]) or compact_spaces(args[1])
        elif call["helper"] == "try_redirect_factoriopeida" and len(args) >= 2:
            alt = parse_data_raw_target(args[1])
            entry["alternative_type"] = alt.get("prototype_type")
            entry["alternative_name"] = alt.get("prototype_name")
        rule_entries.append(entry)
    name_patterns: list[dict[str, Any]] = []
    for match in re.finditer(
        r'string\.match\(\s*([A-Za-z0-9_\.]+)\.name\s*,\s*(const\.[A-Za-z0-9_]+|"[^"]+")\s*\)',
        clean,
    ):
        subject, raw_pattern = match.groups()
        if raw_pattern.startswith("const."):
            resolved = regex_constants.get(raw_pattern.split(".", 1)[1], raw_pattern)
        else:
            resolved = raw_pattern.strip('"')
        name_patterns.append(
            {
                "subject": subject,
                "pattern_source": raw_pattern,
                "resolved_pattern": resolved,
            }
        )
    category_match = re.search(r"esir-\d+[a-z]?-(.+)\.lua$", path)
    return {
        "path": path,
        "category": category_match.group(1) if category_match else path,
        "helpers_used": helpers_used,
        "prototype_mentions": prototype_mentions,
        "name_patterns": name_patterns,
        "rule_entries": rule_entries,
        "rule_count": len(rule_entries),
    }


def parse_rule_map(reader: ModReader) -> dict[str, Any]:
    files = [path for path in reader.list_files() if RULE_FILE_PATTERN.match(path)]
    regex_constants = parse_regex_constants(reader)
    rule_files = [parse_rule_entries(path, reader.read_text(path), regex_constants) for path in files]
    family_counts = Counter()
    for path in files:
        match = re.search(r"esir-(\d{2})", path)
        family_counts[match.group(1) if match else path] += 1
    return {
        "files": rule_files,
        "family_counts": dict(sorted(family_counts.items())),
    }


def discover_asset_families(reader: ModReader) -> list[dict[str, Any]]:
    keywords = {
        "overlay": re.compile(r"overlay|ovl", re.I),
        "background": re.compile(r"background|bg_", re.I),
        "isotope": re.compile(r"isotope|uranium|plutonium|thorium|u235|u233|pu239|th232", re.I),
        "fuel": re.compile(r"fuel|coolant|vent", re.I),
        "filter-logistics": re.compile(r"filter|logistic|chest|container|storebox|storehouse", re.I),
        "recycle": re.compile(r"recycle|centrifug", re.I),
        "gate": re.compile(r"gate", re.I),
    }
    files = reader.list_files()
    families: list[dict[str, Any]] = []
    for family, pattern in keywords.items():
        hits = [path for path in files if pattern.search(path)]
        if hits:
            families.append({"family": family, "count": len(hits), "examples": hits[:12]})
    return families


def build_feature_candidates(
    settings: list[dict[str, Any]],
    changelog: dict[str, Any],
    rule_map: dict[str, Any],
) -> list[dict[str, Any]]:
    by_name = {setting["name"]: setting for setting in settings}
    rule_paths = {entry["path"] for entry in rule_map["files"]}
    candidates = [
        {
            "id": "signal-cleanup-gating",
            "tag": "needs-rule-design",
            "summary": "Signal hiding only activates when the hide-signals setting is enabled and all three icon-replacement families are active.",
            "evidence": ["prototypes/0-config.lua", "prototypes/esir-42a-hiding-signals.lua"],
        },
        {
            "id": "legacy-setting-spelling-and-values",
            "tag": "needs-rule-design",
            "summary": "The companion mod intentionally keeps backward-compatible setting quirks such as add-backgroud, legacy item-icons full handling, and isotope overlay-all wiring.",
            "evidence": ["settings.lua", "prototypes/0-config.lua"],
        },
        {
            "id": "dummy-isotope-board-recipes",
            "tag": "ready-to-map",
            "summary": "Dummy isotope and element recipe boards add a separate review surface after sorting and before hiding.",
            "evidence": sorted(path for path in rule_paths if "/esir-25" in path),
        },
        {
            "id": "intensive-facility-centralization",
            "tag": "ready-to-map",
            "summary": "Facility sorting has a deeper centralization branch that should stay distinct from the default facility sort preset.",
            "evidence": sorted(path for path in rule_paths if "31e" in path or "31b" in path),
        },
        {
            "id": "composite-gate-family",
            "tag": "needs-rule-design",
            "summary": "Gate support spans multiple prototype types including item, container, electric-energy-interface, and ammo-category surfaces.",
            "evidence": ["prototypes/esir-41a-hiding-minimum.lua"],
        },
        {
            "id": "signal-cleanup-exceptions",
            "tag": "ready-to-map",
            "summary": "Signal cleanup is partly heuristic and partly hardcoded for specific recipe families and exceptions.",
            "evidence": ["prototypes/esir-42a-hiding-signals.lua"],
        },
        {
            "id": "purged-non-recipe-buckets",
            "tag": "ready-to-map",
            "summary": "Purging is an explicit non-default cleanup mode that moves non-recipe items and fluids into dedicated purged subgroups.",
            "evidence": sorted(path for path in rule_paths if "43a" in path),
        },
        {
            "id": "rejected-merging-mode",
            "tag": "out-of-scope-v1",
            "summary": "The historical merging system is still present in comments but rejected by the current loader order.",
            "evidence": ["data-final-fixes.lua", "settings.lua"],
        },
    ]
    background_setting = by_name.get("icon-visibility-esir-add-backgroud")
    if background_setting:
        candidates.append(
            {
                "id": "background-plates",
                "tag": "needs-rule-design",
                "summary": "Background plates are a supported icon branch but should stay optional in the ESIR-first house style.",
                "evidence": [background_setting["name"]],
            }
        )
    latest_notes = changelog.get("latest_notes", [])
    if latest_notes:
        candidates.append(
            {
                "id": "latest-supported-content",
                "tag": "ready-to-map",
                "summary": f"Latest companion changelog notes: {latest_notes[0]}",
                "evidence": ["changelog.txt"],
            }
        )
    return [candidate for candidate in candidates if candidate["tag"] in SUMMARY_TAGS]


def build_baseline(source: Path) -> dict[str, Any]:
    reader = ModReader(source)
    try:
        info = parse_info(reader)
        changelog = parse_changelog(reader, info.get("version"))
        settings = parse_settings(reader)
        regex_constants = parse_regex_constants(reader)
        config_model = parse_config_model(reader)
        effective_default_gates = build_effective_default_gates(settings, config_model)
        icon_helpers = parse_helper_file(reader.read_text("prototypes/0-func-for-icon.lua"), "icon")
        behavior_helpers = parse_helper_file(
            reader.read_text("prototypes/0-func-for-sorting.lua"), "behavior"
        )
        loader_order = parse_loader_order(reader)
        rule_map = parse_rule_map(reader)
        asset_families = discover_asset_families(reader)
        features = build_feature_candidates(settings, changelog, rule_map)
    finally:
        reader.close()
    return {
        "skill_baseline_version": 1,
        "source_path": str(source),
        "mod_info": info,
        "changelog": changelog,
        "startup_settings": settings,
        "regex_constants": regex_constants,
        "config_model": config_model,
        "effective_default_gates": effective_default_gates,
        "icon_helper_semantics": icon_helpers,
        "behavior_helper_semantics": behavior_helpers,
        "loader_order": loader_order,
        "rule_file_map": rule_map,
        "asset_families": asset_families,
        "potential_features": features,
    }


def diff_lists(old_items: Iterable[Any], new_items: Iterable[Any]) -> dict[str, list[Any]]:
    old_set = {json.dumps(item, sort_keys=True) if not isinstance(item, str) else item for item in old_items}
    new_set = {json.dumps(item, sort_keys=True) if not isinstance(item, str) else item for item in new_items}
    added = sorted(new_set - old_set)
    removed = sorted(old_set - new_set)
    return {"added": added, "removed": removed}


def diff_baselines(old: dict[str, Any], new: dict[str, Any]) -> dict[str, Any]:
    old_settings = {item["name"]: item for item in old.get("startup_settings", [])}
    new_settings = {item["name"]: item for item in new.get("startup_settings", [])}
    old_rules = {item["path"] for item in old.get("rule_file_map", {}).get("files", [])}
    new_rules = {item["path"] for item in new.get("rule_file_map", {}).get("files", [])}
    old_assets = {item["family"] for item in old.get("asset_families", [])}
    new_assets = {item["family"] for item in new.get("asset_families", [])}
    old_features = {item["id"]: item for item in old.get("potential_features", [])}
    new_features = {item["id"]: item for item in new.get("potential_features", [])}
    changed_setting_defaults = []
    for name in sorted(old_settings.keys() & new_settings.keys()):
        if old_settings[name].get("default_value") != new_settings[name].get("default_value"):
            changed_setting_defaults.append(
                {
                    "name": name,
                    "old": old_settings[name].get("default_value"),
                    "new": new_settings[name].get("default_value"),
                }
            )
    added_feature_ids = sorted(new_features.keys() - old_features.keys())
    diff = {
        "version_change": {
            "old_version": old.get("mod_info", {}).get("version"),
            "new_version": new.get("mod_info", {}).get("version"),
            "old_date": old.get("changelog", {}).get("latest_date"),
            "new_date": new.get("changelog", {}).get("latest_date"),
        },
        "startup_settings": {
            "added": sorted(new_settings.keys() - old_settings.keys()),
            "removed": sorted(old_settings.keys() - new_settings.keys()),
            "changed_default_values": changed_setting_defaults,
        },
        "rule_files": {
            "added": sorted(new_rules - old_rules),
            "removed": sorted(old_rules - new_rules),
        },
        "asset_families": {
            "added": sorted(new_assets - old_assets),
            "removed": sorted(old_assets - new_assets),
        },
        "potential_features": {
            "added": added_feature_ids,
            "removed": sorted(old_features.keys() - new_features.keys()),
        },
    }
    findings: list[dict[str, Any]] = []
    for setting_name in diff["startup_settings"]["added"]:
        findings.append(
            {
                "tag": "ready-to-map",
                "category": "startup-setting",
                "summary": f"New startup setting detected: {setting_name}",
            }
        )
    for path in diff["rule_files"]["added"]:
        findings.append(
            {
                "tag": "ready-to-map",
                "category": "rule-file",
                "summary": f"New companion rule file detected: {path}",
            }
        )
    for family in diff["asset_families"]["added"]:
        findings.append(
            {
                "tag": "needs-rule-design",
                "category": "asset-family",
                "summary": f"New overlay/background asset family detected: {family}",
            }
        )
    for feature_id in added_feature_ids:
        findings.append(new_features[feature_id])
    diff["findings"] = findings
    return diff


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source",
        type=Path,
        default=DEFAULT_SOURCE,
        help="Path to the companion mod zip or unpacked folder.",
    )
    parser.add_argument("--output", type=Path, help="Write the baseline JSON to this path.")
    parser.add_argument(
        "--compare",
        type=Path,
        help="Existing baseline JSON to diff against the freshly generated baseline.",
    )
    parser.add_argument(
        "--diff-output",
        type=Path,
        help="Write the baseline diff JSON to this path when --compare is supplied.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.source.exists():
        print(f"[ERROR] Companion source not found: {args.source}", file=sys.stderr)
        return 1
    baseline = build_baseline(args.source)
    if args.output:
        write_json(args.output, baseline)
    else:
        print(json.dumps(baseline, indent=2, ensure_ascii=False))
    if args.compare:
        previous = json.loads(args.compare.read_text(encoding="utf-8"))
        diff = diff_baselines(previous, baseline)
        if args.diff_output:
            write_json(args.diff_output, diff)
        else:
            print(json.dumps(diff, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""
Audit ESIR recipe prototypes by combining runtime dump truth with static repo mapping
and companion rule evidence.
"""

from __future__ import annotations

import argparse
import copy
import json
import os
import re
import sys
from dataclasses import dataclass
from collections import defaultdict
from pathlib import Path
from typing import Any

from companion_mod_probe import ModReader, find_matching, remove_lua_comments, split_top_level_args


DEFAULT_DUMP = Path(".factorio-qc/dump-run-data-2/script-output/data-raw-dump.json")
DEFAULT_DEPENDENCY_CATALOG = Path(".codex/esir/dependency-catalog.json")
ESIR_ROOT = Path("exotic-space-industries-remembrance")
LOCALE_ROOT = ESIR_ROOT / "locale" / "en"
RECIPE_MUTATION_PATTERN = re.compile(
    r'data\.raw(?:\.recipe|\["recipe"\])\["([^"]+)"\]'
)
ICON_MOD_PATTERN = re.compile(r"__([^/]+?)__/")
IGNORED_SCOPE_OWNER_MODS = {"recipe-icons-improvement-for-esir", "core"}
FOUNDATION_SCOPE_OWNER_MODS = {
    "base",
    "core",
    "quality",
    "space-age",
    "exotic-space-industries-remembrance",
}


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def compact_spaces(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def parse_locale(root: Path) -> dict[str, str]:
    locale: dict[str, str] = {}
    if not root.exists():
        return locale
    for path in sorted(root.glob("*.cfg")):
        section = None
        for raw_line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            line = raw_line.strip()
            if not line or line.startswith(";") or line.startswith("#"):
                continue
            if line.startswith("[") and line.endswith("]"):
                section = line[1:-1]
                continue
            if "=" not in line or not section:
                continue
            key, value = line.split("=", 1)
            locale[f"{section}.{key.strip()}"] = value.strip()
    return locale


def resolve_localized_name(
    value: Any, locale: dict[str, str], prototype_name: str, prototype_type: str
) -> tuple[str, str]:
    def resolve_node(node: Any) -> str:
        if node is None:
            return ""
        if isinstance(node, str):
            return locale.get(node, node)
        if isinstance(node, (int, float)):
            return str(node)
        if isinstance(node, list) and node:
            key = node[0]
            args = [resolve_node(item) for item in node[1:]]
            template = locale.get(key, key if isinstance(key, str) else "")
            if isinstance(template, str) and args:
                for index, arg in enumerate(args, start=1):
                    template = template.replace(f"__{index}__", arg)
                return template
            if args:
                return " ".join(part for part in [template] + args if part)
            return template
        return ""

    resolved = resolve_node(value).strip()
    if resolved and resolved != prototype_name:
        return resolved, "localised_name"
    for locale_key in (
        f"{prototype_type}-name.{prototype_name}",
        f"item-name.{prototype_name}",
        f"fluid-name.{prototype_name}",
        f"entity-name.{prototype_name}",
    ):
        if locale_key in locale:
            return locale[locale_key], locale_key
    return prototype_name, "prototype_name"


def derive_icon_layers(prototype: dict[str, Any]) -> list[dict[str, Any]]:
    if isinstance(prototype.get("icons"), list) and prototype["icons"]:
        layers = []
        for layer in prototype["icons"]:
            if not isinstance(layer, dict):
                continue
            layers.append(
                {
                    "icon": layer.get("icon"),
                    "icon_size": layer.get("icon_size") or layer.get("icon-size"),
                    "icon_mipmaps": layer.get("icon_mipmaps") or layer.get("icon-mipmaps"),
                    "scale": layer.get("scale"),
                    "shift": layer.get("shift"),
                    "tint": layer.get("tint"),
                    "draw_background": layer.get("draw_background"),
                }
            )
        if layers:
            return layers
    if prototype.get("icon"):
        return [
            {
                "icon": prototype.get("icon"),
                "icon_size": prototype.get("icon_size"),
                "icon_mipmaps": prototype.get("icon_mipmaps"),
                "scale": None,
                "shift": None,
                "tint": None,
                "draw_background": None,
            }
        ]
    return []


def scan_brace_stack_for_positions(text: str, positions: list[int]) -> dict[int, int | None]:
    if not positions:
        return {}
    wanted = sorted(positions)
    resolved: dict[int, int | None] = {}
    brace_stack: list[int] = []
    string_quote: str | None = None
    escape = False
    wanted_index = 0
    for idx, ch in enumerate(text):
        while wanted_index < len(wanted) and wanted[wanted_index] == idx:
            resolved[wanted[wanted_index]] = brace_stack[-1] if brace_stack else None
            wanted_index += 1
        if string_quote:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == string_quote:
                string_quote = None
            continue
        if ch in {'"', "'"}:
            string_quote = ch
            continue
        if ch == "{":
            brace_stack.append(idx)
        elif ch == "}" and brace_stack:
            brace_stack.pop()
    while wanted_index < len(wanted):
        resolved[wanted[wanted_index]] = brace_stack[-1] if brace_stack else None
        wanted_index += 1
    return resolved


def extract_top_level_string_fields(block_text: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    inner = block_text[1:-1] if block_text.startswith("{") and block_text.endswith("}") else block_text
    for chunk in split_top_level_args(inner):
        match = re.match(r'\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"([^"]+)"', chunk)
        if match:
            fields[match.group(1)] = match.group(2)
    return fields


def iter_recipe_declarations(text: str) -> list[dict[str, Any]]:
    cleaned = remove_lua_comments(text)
    type_matches = list(re.finditer(r'type\s*=\s*"recipe"', cleaned))
    if not type_matches:
        return []
    enclosing = scan_brace_stack_for_positions(cleaned, [match.start() for match in type_matches])
    declarations: list[dict[str, Any]] = []
    seen_blocks: set[tuple[int, int]] = set()
    for match in type_matches:
        block_start = enclosing.get(match.start())
        if block_start is None:
            continue
        try:
            block_end = find_matching(cleaned, block_start, "{", "}")
        except ValueError:
            continue
        block_key = (block_start, block_end)
        if block_key in seen_blocks:
            continue
        seen_blocks.add(block_key)
        block_text = cleaned[block_start : block_end + 1]
        fields = extract_top_level_string_fields(block_text)
        if fields.get("type") != "recipe" or not fields.get("name"):
            continue
        line = cleaned.count("\n", 0, block_start) + 1
        icon_strategy = "single-icon"
        if "ei_lib.make_icons" in block_text:
            icon_strategy = "ei_lib.make_icons"
        elif re.search(r"\bicons\s*=\s*{", block_text):
            icon_strategy = "layered-icons"
        score = 100
        if "ei_lib.make_icons" in block_text:
            score += 3
        elif re.search(r"\bicons\s*=\s*{", block_text):
            score += 2
        if re.search(r"\bsubgroup\s*=", block_text) or re.search(r"\border\s*=", block_text):
            score += 1
        declarations.append(
            {
                "name": fields["name"],
                "line": line,
                "score": score,
                "declared_icon_strategy": icon_strategy,
            }
        )
    return declarations


def build_repo_index(repo_root: Path) -> tuple[dict[str, dict[str, Any]], dict[str, list[str]]]:
    declarations: dict[str, dict[str, Any]] = {}
    mutations: dict[str, list[str]] = defaultdict(list)
    for path in sorted((repo_root / ESIR_ROOT).rglob("*.lua")):
        rel = path.relative_to(repo_root).as_posix()
        text = path.read_text(encoding="utf-8", errors="replace")
        for declaration in iter_recipe_declarations(text):
            name = declaration["name"]
            best = declarations.get(name)
            candidate = {
                "source_file": rel,
                "line": declaration["line"],
                "score": declaration["score"],
                "declared_icon_strategy": declaration["declared_icon_strategy"],
            }
            if not best or candidate["score"] > best["score"]:
                declarations[name] = candidate
        for match in RECIPE_MUTATION_PATTERN.finditer(text):
            mutations[match.group(1)].append(rel)
    return declarations, {name: sorted(set(paths)) for name, paths in mutations.items()}


def lua_pattern_to_regex(pattern: str) -> str:
    return pattern.replace("%", "\\")


def build_companion_rule_index(
    probe: dict[str, Any]
) -> tuple[dict[str, list[dict[str, Any]]], list[dict[str, Any]]]:
    index: dict[str, list[dict[str, Any]]] = defaultdict(list)
    pattern_rules: list[dict[str, Any]] = []
    for file_entry in probe.get("rule_file_map", {}).get("files", []):
        for rule in file_entry.get("rule_entries", []):
            prototype_type = rule.get("prototype_type")
            if prototype_type not in {None, "recipe"}:
                continue
            name = rule.get("prototype_name")
            if not name:
                continue
            merged = dict(rule)
            merged["rule_path"] = file_entry.get("path")
            merged["rule_category"] = file_entry.get("category")
            index[name].append(merged)
        for pattern in file_entry.get("name_patterns", []):
            pattern_rules.append(
                {
                    "rule_path": file_entry.get("path"),
                    "rule_category": file_entry.get("category"),
                    "pattern_source": pattern.get("pattern_source"),
                    "resolved_pattern": pattern.get("resolved_pattern"),
                    "compiled_pattern": lua_pattern_to_regex(pattern.get("resolved_pattern") or ""),
                }
            )
    return index, pattern_rules


def synthetic_pattern_hits(
    recipe_name: str, pattern_rules: list[dict[str, Any]]
) -> list[dict[str, Any]]:
    hits: list[dict[str, Any]] = []
    for pattern_rule in pattern_rules:
        compiled = pattern_rule.get("compiled_pattern")
        if not compiled:
            continue
        try:
            if not re.match(compiled, recipe_name):
                continue
        except re.error:
            continue
        hit = {
            "helper": "pattern-match",
            "prototype_name": recipe_name,
            "prototype_type": "recipe",
            "rule_path": pattern_rule.get("rule_path"),
            "rule_category": pattern_rule.get("rule_category"),
            "pattern_source": pattern_rule.get("pattern_source"),
        }
        if pattern_rule.get("pattern_source") == "const.fusion_recipe_matching":
            hit["helper"] = "show_fusion_bucket"
        hits.append(hit)
    return hits


def determine_style_family(rule_hits: list[dict[str, Any]], source_file: str | None, recipe_name: str) -> str:
    for hit in rule_hits:
        category = hit.get("rule_category") or ""
        if category.startswith("icons-"):
            return category.replace("icons-", "", 1)
    haystack = " ".join(part for part in [source_file or "", recipe_name] if part).lower()
    if "nuclear" in haystack or any(token in haystack for token in ("uranium", "plutonium", "thorium", "fusion")):
        return "recipe-nuclear"
    if any(token in haystack for token in ("rocket", "ammo", "combat", "railgun")):
        return "recipe-combat"
    if any(token in haystack for token in ("oil", "gas", "coolant", "bio-oil", "petro", "chemical")):
        return "recipe-petro"
    if any(token in haystack for token in ("alien", "gate")):
        return "recipe-alien"
    if any(token in haystack for token in ("vulcanus", "fumarole", "aquilo", "gleba", "maraxsis")):
        return "recipe-exoplanets"
    if any(token in haystack for token in ("molten", "slag", "casting", "metal")):
        return "recipe-metallurgy"
    return "manual-review"


def determine_preset_tags(
    current: dict[str, Any], proposed: dict[str, Any], rule_hits: list[dict[str, Any]], style_family: str
) -> list[str]:
    tags = set()
    current_subgroup = current.get("subgroup") or ""
    proposed_subgroup = proposed.get("subgroup") or ""
    signal_changed = proposed.get("hide_from_signal_gui") != current.get("hide_from_signal_gui")
    has_signal_rule = any(hit.get("helper") in {"try_hide_signal", "show_fusion_bucket"} for hit in rule_hits)
    has_icon_rule = any(hit.get("helper") in {"try_set_icons", "try_set_icons_if"} for hit in rule_hits)
    has_sort_rule = any(hit.get("helper") in {"try_set_order", "try_set_subgroup", "try_set_full_order"} for hit in rule_hits)
    has_hide_rule = any(
        hit.get("helper")
        in {
            "try_hide_factoriopeida",
            "try_redirect_factoriopeida",
            "try_hide_player_crafting",
            "try_hide_signal",
            "try_show_factoriopeida",
            "try_show_player_crafting",
            "try_show_dual",
            "show_fusion_bucket",
        }
        for hit in rule_hits
    )
    if has_icon_rule or proposed.get("icon_strategy") == "companion-layered-icons":
        tags.add("icons-lite")
    if any((hit.get("rule_path") or "").startswith("prototypes/esir-25") for hit in rule_hits):
        tags.add("icons-full")
    if any((hit.get("rule_path") or "").startswith("prototypes/esir-31e") for hit in rule_hits):
        tags.add("sort-expanded")
    elif has_sort_rule:
        tags.add("sort-core")
    if any((hit.get("rule_path") or "").startswith("prototypes/esir-41e") for hit in rule_hits):
        tags.add("hide-extra")
    elif has_hide_rule and (
        proposed.get("hidden_in_factoriopedia") != current.get("hidden_in_factoriopedia")
        or proposed.get("hide_from_player_crafting") != current.get("hide_from_player_crafting")
        or proposed.get("factoriopedia_alternative") != current.get("factoriopedia_alternative")
    ):
        tags.add("hide-std")
    if proposed.get("hide_from_signal_gui") and (signal_changed or has_signal_rule):
        tags.add("signals-clean")
    if current_subgroup.startswith("ivi-purged-") or proposed_subgroup.startswith("ivi-purged-"):
        tags.add("purge-nonbasic")
    return sorted(tags)


def classify_evidence_state(rule_hits: list[dict[str, Any]]) -> str:
    for hit in rule_hits:
        helper = hit.get("helper")
        if helper and helper not in {"pattern-match", "show_fusion_bucket"}:
            return "direct-helper"
    if any(
        hit.get("rule_path") and not hit.get("pattern_source") and hit.get("helper") is None
        for hit in rule_hits
    ):
        return "direct-rule-file"
    if rule_hits:
        return "pattern-rule"
    return "heuristic-only"


def dedupe_rule_hits(rule_hits: list[dict[str, Any]]) -> list[dict[str, Any]]:
    seen: set[tuple[Any, ...]] = set()
    deduped: list[dict[str, Any]] = []
    for hit in rule_hits:
        key = (
            hit.get("rule_path"),
            hit.get("helper"),
            hit.get("subgroup"),
            hit.get("order"),
            hit.get("alternative_name"),
            hit.get("condition_expression"),
            hit.get("icons_expression"),
            hit.get("pattern_source"),
            hit.get("prototype_name"),
            hit.get("prototype_type"),
        )
        if key in seen:
            continue
        seen.add(key)
        deduped.append(hit)
    return deduped


def classify_source_surface(
    source: dict[str, Any] | None, mutations: list[str]
) -> tuple[str, str | None, str | None, list[str]]:
    unique_mutations = sorted(set(mutations))
    declaration_source_file = source.get("source_file") if source else None
    primary_patch_file = declaration_source_file or (unique_mutations[0] if unique_mutations else None)
    if source:
        distinct_mutations = [path for path in unique_mutations if path != declaration_source_file]
        if distinct_mutations:
            return "source-and-mutation", declaration_source_file, primary_patch_file, unique_mutations
        return "source-file", declaration_source_file, primary_patch_file, unique_mutations
    if unique_mutations:
        return "mutation-only", declaration_source_file, primary_patch_file, unique_mutations
    return "none", None, None, []


def normalize_shift(shift: Any) -> list[float]:
    if isinstance(shift, list) and len(shift) >= 2:
        return [float(shift[0]), float(shift[1])]
    return [0.0, 0.0]


def normalize_layers(layers: list[dict[str, Any]]) -> list[dict[str, Any]]:
    normalized = []
    for layer in layers:
        normalized.append(
            {
                "icon": layer.get("icon"),
                "icon_size": layer.get("icon_size"),
                "icon_mipmaps": layer.get("icon_mipmaps"),
                "scale": layer.get("scale"),
                "shift": normalize_shift(layer.get("shift")),
                "tint": layer.get("tint"),
                "draw_background": layer.get("draw_background"),
            }
        )
    return normalized


def layer_signature(layers: list[dict[str, Any]]) -> str:
    return json.dumps(normalize_layers(layers), sort_keys=True, ensure_ascii=False, separators=(",", ":"))


def infer_product_name(recipe: dict[str, Any]) -> str | None:
    if isinstance(recipe.get("main_product"), str):
        return recipe["main_product"]
    results = recipe.get("results")
    if isinstance(results, list) and len(results) == 1 and isinstance(results[0], dict):
        return results[0].get("name")
    if isinstance(recipe.get("result"), str):
        return recipe["result"]
    return None


def infer_product_names(recipe: dict[str, Any]) -> list[str]:
    names: list[str] = []
    if isinstance(recipe.get("main_product"), str):
        names.append(recipe["main_product"])
    if isinstance(recipe.get("result"), str):
        names.append(recipe["result"])
    for result in recipe.get("results") or []:
        if isinstance(result, dict) and isinstance(result.get("name"), str):
            names.append(result["name"])
    seen: set[str] = set()
    ordered: list[str] = []
    for name in names:
        if name in seen:
            continue
        seen.add(name)
        ordered.append(name)
    return ordered


def icon_owner_mod(icon_path: Any) -> str | None:
    if not isinstance(icon_path, str):
        return None
    match = ICON_MOD_PATTERN.match(icon_path)
    if not match:
        return None
    mod_name = match.group(1)
    if mod_name in IGNORED_SCOPE_OWNER_MODS:
        return None
    return mod_name


def is_foundation_scope_owner_mod(mod_name: str) -> bool:
    return (
        mod_name in FOUNDATION_SCOPE_OWNER_MODS
        or mod_name.startswith("exotic-space-industries-remembrance-graphics-")
        or mod_name.startswith("exotic-space-industries-remembrance-soundtrack-")
    )


def owner_mods_from_layers(layers: list[dict[str, Any]]) -> list[str]:
    mods: list[str] = []
    for layer in layers:
        mod_name = icon_owner_mod(layer.get("icon"))
        if mod_name and mod_name not in mods:
            mods.append(mod_name)
    return mods


def infer_recipe_owner_mods(recipe: dict[str, Any], products: dict[str, dict[str, Any]]) -> list[str]:
    mods: list[str] = []
    for product_name in infer_product_names(recipe):
        product = products.get(product_name)
        if not product:
            continue
        for mod_name in owner_mods_from_layers(derive_icon_layers(product)):
            if mod_name not in mods:
                mods.append(mod_name)
    if not mods:
        fallback_layers, _ = fallback_recipe_icon_layers(recipe, products)
        for mod_name in owner_mods_from_layers(fallback_layers):
            if mod_name not in mods:
                mods.append(mod_name)
    if not mods:
        for mod_name in owner_mods_from_layers(derive_icon_layers(recipe)):
            if mod_name not in mods:
                mods.append(mod_name)
    return mods


def load_dependency_scope(path: Path | None) -> dict[str, Any]:
    if not path or not path.exists():
        return {
            "catalog_path": str(path) if path else None,
            "allowed_mods": set(),
            "target_recipe_names": set(),
            "target_recipe_names_by_name": set(),
        }
    payload = json.loads(path.read_text(encoding="utf-8"))
    allowed_mods: set[str] = {"exotic-space-industries-remembrance"}
    target_recipe_names: set[str] = set()
    target_recipe_names_by_name: set[str] = set()
    for dependency in payload.get("declared_dependencies", []):
        mod_name = dependency.get("mod_name")
        if not mod_name or dependency.get("dependency_kind") == "incompatible":
            continue
        allowed_mods.add(mod_name)
    for touchpoint in payload.get("touchpoints", []):
        for mod_name in touchpoint.get("mod_names") or []:
            if mod_name:
                allowed_mods.add(mod_name)
        for prototype_ref in touchpoint.get("target_prototypes") or []:
            if not isinstance(prototype_ref, str) or ":" not in prototype_ref:
                continue
            prototype_type, prototype_name = prototype_ref.split(":", 1)
            if prototype_name:
                target_recipe_names_by_name.add(prototype_name)
            if prototype_type == "recipe" and prototype_name:
                target_recipe_names.add(prototype_name)
    return {
        "catalog_path": str(path),
        "allowed_mods": allowed_mods,
        "target_recipe_names": target_recipe_names,
        "target_recipe_names_by_name": target_recipe_names_by_name,
    }


def determine_scope(
    recipe_name: str,
    source: dict[str, Any] | None,
    mutations: list[str],
    owner_mods: list[str],
    dependency_scope: dict[str, Any],
    scope_mode: str,
) -> tuple[bool, list[str], list[str]]:
    scope_reasons: list[str] = []
    dependency_owner_mods = [
        mod_name
        for mod_name in owner_mods
        if mod_name in dependency_scope.get("allowed_mods", set()) and not is_foundation_scope_owner_mod(mod_name)
    ]
    if source:
        scope_reasons.append("esir-source")
    if mutations:
        scope_reasons.append("esir-mutation")
    if recipe_name.startswith("ei-"):
        scope_reasons.append("esir-prefix")
    has_esir_reason = bool(scope_reasons)
    if scope_mode != "esir-only":
        if recipe_name in dependency_scope.get("target_recipe_names", set()):
            scope_reasons.append("dependency-target")
        elif recipe_name in dependency_scope.get("target_recipe_names_by_name", set()):
            scope_reasons.append("dependency-target-by-name")
        if dependency_owner_mods:
            scope_reasons.append("dependency-owner")
    if scope_mode == "all-candidates" and not scope_reasons:
        scope_reasons.append("scope-all-candidates")
    if scope_mode == "esir-only":
        include = has_esir_reason
    elif scope_mode == "all-candidates":
        include = True
    else:
        include = bool(scope_reasons)
    return include, scope_reasons, dependency_owner_mods


def icons_match(recipe_layers: list[dict[str, Any]], product_layers: list[dict[str, Any]]) -> bool:
    if not recipe_layers and not product_layers:
        return True
    return layer_signature(recipe_layers) == layer_signature(product_layers)


def build_overlay_plan(
    rule_hits: list[dict[str, Any]],
    style_family: str,
    synthesized: SynthesizedIconPlan | None = None,
) -> dict[str, Any] | None:
    icon_hits = [
        hit
        for hit in rule_hits
        if hit.get("helper") in {"try_set_icons", "try_set_icons_if"}
    ]
    if not icon_hits:
        return None
    helpers = sorted({hit.get("helper") for hit in icon_hits if hit.get("helper")})
    rule_paths = sorted({hit.get("rule_path") for hit in icon_hits if hit.get("rule_path")})
    plan = {
        "kind": "companion-icon-rule",
        "style_family": style_family,
        "helpers": helpers,
        "rule_paths": rule_paths,
        "conditional": any(hit.get("helper") == "try_set_icons_if" for hit in icon_hits),
        "summary": "companion icon helper hit without synthesized target layers",
    }
    if synthesized:
        plan["mode"] = synthesized.mode
        if synthesized.selected_rule_path:
            plan["summary"] = "companion icon helper hit with synthesized target layers"
            plan["selected_rule_path"] = synthesized.selected_rule_path
            plan["selected_helper"] = synthesized.selected_helper
        elif synthesized.mode == "skipped-condition-false":
            plan["summary"] = "default companion icon condition is false; no icon replacement is proposed"
    return plan


def classify_icon_proposal(
    current_layers: list[dict[str, Any]],
    proposed_layers: list[dict[str, Any]],
    overlay_plan: dict[str, Any] | None,
) -> tuple[str, str]:
    if layer_signature(current_layers) != layer_signature(proposed_layers):
        return "concrete", "proposed icon layers differ from current layers"
    if overlay_plan and overlay_plan.get("selected_rule_path"):
        return "unchanged", "synthesized companion icon layers match current layers"
    if overlay_plan and overlay_plan.get("mode") == "skipped-condition-false":
        return "unchanged", "default companion icon condition is false; no proposed icon-layer delta"
    if overlay_plan:
        return "strategy-only", overlay_plan.get("summary") or "icon helper hit without concrete layers"
    return "unchanged", "no proposed icon-layer delta"


def infer_signal_cleanup(
    recipe_name: str,
    recipe: dict[str, Any],
    product_map: dict[str, dict[str, Any]],
) -> tuple[bool, str | None]:
    product_name = infer_product_name(recipe)
    if not product_name or recipe_name != product_name:
        return False, None
    product = product_map.get(product_name)
    if not product:
        return False, None
    recipe_layers = derive_icon_layers(recipe)
    product_layers = derive_icon_layers(product)
    if not recipe_layers or icons_match(recipe_layers, product_layers):
        return True, "same-name basic recipe signal heuristic"
    return False, None


def signal_cleanup_gate_state(probe: dict[str, Any]) -> str:
    gates = probe.get("effective_default_gates") or {}
    state = gates.get("signal_cleanup")
    if state in {"enabled", "disabled", "unknown"}:
        return state
    return "unknown"


def fallback_recipe_icon_layers(
    recipe: dict[str, Any], product_map: dict[str, dict[str, Any]]
) -> tuple[list[dict[str, Any]], str | None]:
    product_name = infer_product_name(recipe)
    if not product_name:
        return [], None
    product = product_map.get(product_name)
    if not product:
        return [], None
    layers = derive_icon_layers(product)
    if not layers:
        return [], None
    return layers, f"used main product icon fallback from {product_name}"


class ExpressionUnresolved(ValueError):
    pass


@dataclass
class SynthesizedIconPlan:
    layers: list[dict[str, Any]] | None
    notes: list[str]
    selected_rule_path: str | None
    selected_helper: str | None
    mode: str


def strip_outer_parens(text: str) -> str:
    text = compact_spaces(text)
    while text.startswith("(") and text.endswith(")"):
        try:
            end = find_matching(text, 0, "(", ")")
        except ValueError:
            break
        if end != len(text) - 1:
            break
        text = compact_spaces(text[1:-1])
    return text


def split_top_level_keyword(text: str, keyword: str) -> list[str]:
    token = f" {keyword} "
    parts: list[str] = []
    start = 0
    depth_paren = 0
    depth_brace = 0
    depth_bracket = 0
    string_quote = None
    escape = False
    idx = 0
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
            elif ch == "(":
                depth_paren += 1
            elif ch == ")":
                depth_paren -= 1
            elif ch == "{":
                depth_brace += 1
            elif ch == "}":
                depth_brace -= 1
            elif ch == "[":
                depth_bracket += 1
            elif ch == "]":
                depth_bracket -= 1
            elif (
                depth_paren == 0
                and depth_brace == 0
                and depth_bracket == 0
                and text.startswith(token, idx)
            ):
                parts.append(text[start:idx].strip())
                idx += len(token)
                start = idx
                continue
        idx += 1
    if not parts:
        return [text.strip()]
    parts.append(text[start:].strip())
    return parts


def split_top_level_operator(text: str, operator: str) -> tuple[str, str] | None:
    depth_paren = 0
    depth_brace = 0
    depth_bracket = 0
    string_quote = None
    escape = False
    last_match = -1
    idx = 0
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
            elif ch == "(":
                depth_paren += 1
            elif ch == ")":
                depth_paren -= 1
            elif ch == "{":
                depth_brace += 1
            elif ch == "}":
                depth_brace -= 1
            elif ch == "[":
                depth_bracket += 1
            elif ch == "]":
                depth_bracket -= 1
            elif (
                depth_paren == 0
                and depth_brace == 0
                and depth_bracket == 0
                and text.startswith(operator, idx)
            ):
                if operator in {"+", "-"}:
                    prev = text[idx - 1] if idx > 0 else ""
                    if idx == 0 or prev in "([{=,+-*/":
                        idx += len(operator)
                        continue
                last_match = idx
        idx += 1
    if last_match == -1:
        return None
    return text[:last_match].strip(), text[last_match + len(operator) :].strip()


def capture_expression_until_line_break(text: str, start: int) -> tuple[str, int]:
    depth_paren = 0
    depth_brace = 0
    depth_bracket = 0
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
            elif ch == "(":
                depth_paren += 1
            elif ch == ")":
                depth_paren -= 1
            elif ch == "{":
                depth_brace += 1
            elif ch == "}":
                depth_brace -= 1
            elif ch == "[":
                depth_bracket += 1
            elif ch == "]":
                depth_bracket -= 1
            elif ch == "\n" and depth_paren == 0 and depth_brace == 0 and depth_bracket == 0:
                break
        idx += 1
    return compact_spaces(text[start:idx]), idx


def find_top_level_equals(text: str) -> int:
    depth_paren = 0
    depth_brace = 0
    depth_bracket = 0
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
        elif ch == "(":
            depth_paren += 1
        elif ch == ")":
            depth_paren -= 1
        elif ch == "{":
            depth_brace += 1
        elif ch == "}":
            depth_brace -= 1
        elif ch == "[":
            depth_bracket += 1
        elif ch == "]":
            depth_bracket -= 1
        elif ch == "=" and depth_paren == 0 and depth_brace == 0 and depth_bracket == 0:
            prev = text[idx - 1] if idx > 0 else ""
            nxt = text[idx + 1] if idx + 1 < len(text) else ""
            if prev not in {"=", "~", ">", "<"} and nxt != "=":
                return idx
    return -1


def parse_data_raw_reference(expr: str) -> tuple[str | None, str | None]:
    expr = compact_spaces(expr)
    match = re.fullmatch(r'data\.raw(?:\.([A-Za-z0-9_-]+)|\["([^"]+)"\])\["([^"]+)"\]', expr)
    if not match:
        return None, None
    return match.group(1) or match.group(2), match.group(3)


def lua_truthy(value: Any) -> bool:
    return value is not None and value is not False


def merge_tints(first: Any, second: Any) -> Any:
    if first is None:
        return copy.deepcopy(second)
    if second is None:
        return copy.deepcopy(first)
    if not isinstance(first, list) or not isinstance(second, list):
        return copy.deepcopy(second)
    limit = max(len(first), len(second))
    merged = []
    for idx in range(limit):
        left = first[idx] if idx < len(first) else 1
        right = second[idx] if idx < len(second) else 1
        merged.append(left * right)
    return merged


def resolve_shift_value(value: Any) -> list[float] | None:
    if isinstance(value, list) and len(value) >= 2:
        return [float(value[0]), float(value[1])]
    return None


def normalize_icon_layer(layer: dict[str, Any]) -> dict[str, Any]:
    normalized = {
        "icon": layer.get("icon"),
        "icon_size": layer.get("icon_size"),
        "icon_mipmaps": layer.get("icon_mipmaps"),
        "scale": layer.get("scale"),
        "shift": normalize_shift(layer.get("shift")),
        "tint": copy.deepcopy(layer.get("tint")),
        "draw_background": layer.get("draw_background"),
    }
    if layer.get("floating") is not None:
        normalized["floating"] = layer.get("floating")
    return normalized


def build_default_companion_config(probe: dict[str, Any]) -> dict[str, Any]:
    defaults = {
        setting["name"]: setting.get("default_value")
        for setting in probe.get("startup_settings", [])
        if setting.get("name")
    }
    facilities_value = defaults.get("icon-visibility-esir-replace-facilities-icons", "minimum")
    items_value = defaults.get("icon-visibility-esir-replace-items-icons", "minimum")
    weapons_value = defaults.get("icon-visibility-esir-replace-weapons-icons", "minimum")
    fuel_value = defaults.get("icon-visibility-esir-add-fuel-overlay", "fuel-item")
    isotope_value = defaults.get("icon-visibility-esir-add-isotope-overlay", "overlay-nuclear")
    config = {
        "icons_replacing_level_facilities": (
            0 if facilities_value == "none" else 1 if facilities_value == "minimum" else 2
        ),
        "icons_replacing_level_items": (
            0
            if items_value == "none"
            else 1
            if items_value == "minimum"
            else 5
            if items_value == "full"
            else 3
        ),
        "icons_replacing_level_weapons": (
            0 if weapons_value == "none" else 2 if weapons_value == "all" else 1
        ),
        "fuel_overlay_level": (
            0 if fuel_value == "none" else 2 if fuel_value == "all" else 1
        ),
        "isotope_overlay_level": (
            0
            if isotope_value in {"none", "board-nuclear", "board-all"}
            else 2
            if isotope_value in {"overlay-all", "both-all"}
            else 1
        ),
        "isotope_board_level": (
            1
            if isotope_value == "board-nuclear"
            else 2
            if isotope_value in {"board-all", "both-all"}
            else 0
        ),
        "add_background": bool(defaults.get("icon-visibility-esir-add-backgroud")),
        "enable_verification": bool(defaults.get("icon-visibility-esir-skip-existence-verification")),
        "debug_mode": bool(defaults.get("icon-visibility-esir-skip-existence-verification")),
    }
    config["hide_signals"] = bool(defaults.get("icon-visibility-esir-hide-signals")) and all(
        config[key] > 0
        for key in (
            "icons_replacing_level_facilities",
            "icons_replacing_level_items",
            "icons_replacing_level_weapons",
        )
    )
    config["show_nucler_fusion_recipe"] = (
        config["icons_replacing_level_items"] > 0 and config["isotope_overlay_level"] > 0
    )
    return config


def build_default_color_values(probe: dict[str, Any]) -> dict[str, Any]:
    defaults = {
        setting["name"]: setting.get("default_value")
        for setting in probe.get("startup_settings", [])
        if setting.get("name")
    }
    add_background = bool(defaults.get("icon-visibility-esir-add-backgroud"))
    color_set = defaults.get("icon-visibility-esir-color-set") or "dark"
    colors: dict[str, Any] = {}
    if add_background:
        colors["tint_bg_white"] = [0.5, 0.5, 0.5, 0.5]
        colors["tint_bg_white_opaque"] = [0.5, 0.5, 0.5, 1]
        colors["tint_bg_gray"] = [0.3125, 0.3125, 0.3125, 0.3125]
    else:
        colors["tint_bg_white"] = [0.1875, 0.1875, 0.1875, 0.5]
        colors["tint_bg_white_opaque"] = [0.1875, 0.1875, 0.1875, 1]
        colors["tint_bg_gray"] = [0.1875, 0.1875, 0.1875, 0.3125]
    colors["tint_ovl_bg"] = [0.1875, 0.1875, 0.1875, 1]
    colors["tint_tier_bg"] = [0.1875, 0.1875, 0.1875, 0.75]
    colors["tint_outline"] = [0.1875, 0.1875, 0.1875, 1]
    colors["tint_outline_translucent"] = [0.1875, 0.1875, 0.1875, 0.375]
    if color_set == "vivid":
        colors.update(
            {
                "tint_white": [200 / 255, 200 / 255, 203 / 255],
                "tint_red": [1.0, 75 / 255, 0.0],
                "tint_orange": [246 / 255, 170 / 255, 0.0],
                "tint_yellow": [1.0, 241 / 255, 0.0],
                "tint_green": [3 / 255, 175 / 255, 122 / 255],
                "tint_cyan": [77 / 255, 196 / 255, 1.0],
                "tint_blue": [77 / 255, 196 / 255, 1.0],
                "tint_purple": [153 / 255, 0.0, 153 / 255],
                "tint_brown": [128 / 255, 64 / 255, 0.0],
                "tint_gray": [132 / 255, 145 / 255, 158 / 255],
                "tint_cold": [191 / 255, 228 / 255, 1.0],
                "tint_recycle_semiconductor": [77 / 255, 196 / 255, 1.0],
                "tint_poor_chunk": [132 / 255, 145 / 255, 158 / 255],
                "tint_text": [1.0, 1.0, 1.0],
            }
        )
    else:
        colors.update(
            {
                "tint_white": [0.75, 0.75, 0.75],
                "tint_red": [0.75, 0.25, 0.0],
                "tint_orange": [0.875, 0.625, 0.0],
                "tint_yellow": [0.9375, 0.875, 0.0],
                "tint_green": [0.1875, 0.75, 0.1875],
                "tint_cyan": [0.3125, 0.6875, 0.6875],
                "tint_blue": [0.3125, 0.5, 1.0],
                "tint_purple": [0.6875, 0.25, 0.6875],
                "tint_brown": [0.625, 0.4375, 0.0],
                "tint_gray": [0.5625, 0.5625, 0.5625],
                "tint_burner": [0.8125, 0.25, 0.0],
                "tint_cold": [0.75, 0.875, 1.0],
                "tint_from_air": [0.75, 0.75, 0.75],
                "tint_text": [1.0, 1.0, 1.0],
                "tint_text_yellow": [0.9375, 0.9375, 0.0],
                "tint_text_green": [0.125, 0.9375, 0.125],
                "tint_fusion_text": [0.875, 0.875, 0.875],
                "tint_fusion_rate_1": [0.3125, 0.75, 1.0],
                "tint_fusion_rate_2": [1.0, 0.9375, 0.0],
                "tint_fusion_rate_3": [1.0, 0.25, 0.0],
            }
        )
    colors["color_names"] = ["white", "red", "orange", "yellow", "green", "cyan", "blue", "purple", "brown", "gray"]
    colors["tint_mechanical"] = colors.get("tint_mechanical") or colors["tint_gray"]
    colors["tint_burner"] = colors.get("tint_burner") or colors["tint_red"]
    colors["tint_steam"] = colors.get("tint_steam") or colors["tint_white"]
    colors["tint_heat"] = colors.get("tint_heat") or colors["tint_orange"]
    colors["tint_electric"] = colors.get("tint_electric") or colors["tint_yellow"]
    colors["tint_fluid"] = colors.get("tint_fluid") or colors["tint_yellow"]
    colors["tint_metalworks"] = colors.get("tint_metalworks") or colors["tint_yellow"]
    colors["tint_cold"] = colors.get("tint_cold") or colors["tint_cyan"]
    colors["tint_radioactivity"] = colors.get("tint_radioactivity") or colors["tint_yellow"]
    colors["tint_pollution"] = colors.get("tint_pollution") or colors["tint_purple"]
    colors["tint_star"] = colors.get("tint_star") or colors["tint_orange"]
    colors["tint_poor_chunk"] = colors.get("tint_poor_chunk") or colors["tint_purple"]
    colors["tint_recycle_semiconductor"] = colors.get("tint_recycle_semiconductor") or colors["tint_brown"]
    colors["tint_recycle_atan_filter"] = colors.get("tint_recycle_atan_filter") or colors["tint_blue"]
    colors["tint_recycle_slag"] = colors.get("tint_recycle_slag") or colors["tint_blue"]
    colors["tint_recycle_nuclear_fission"] = colors.get("tint_recycle_nuclear_fission") or colors["tint_gray"]
    colors["tint_reuse"] = colors.get("tint_reuse") or colors["tint_green"]
    colors["tint_growing"] = colors.get("tint_growing") or colors["tint_orange"]
    colors["tint_vent"] = colors.get("tint_vent") or colors["tint_red"]
    colors["tint_from_air"] = colors.get("tint_from_air") or colors["tint_gray"]
    colors["tint_filling_barrel"] = colors.get("tint_filling_barrel") or colors["tint_orange"]
    colors["tint_text"] = colors.get("tint_text") or colors["tint_white"]
    colors["tint_text_yellow"] = colors.get("tint_text_yellow") or colors["tint_yellow"]
    colors["tint_text_green"] = colors.get("tint_text_green") or colors["tint_green"]
    colors["tint_fusion_text"] = colors.get("tint_fusion_text") or colors["tint_text"]
    colors["tint_fusion_rate_1"] = colors.get("tint_fusion_rate_1") or colors["tint_cyan"]
    colors["tint_fusion_rate_2"] = colors.get("tint_fusion_rate_2") or colors["tint_yellow"]
    colors["tint_fusion_rate_3"] = colors.get("tint_fusion_rate_3") or colors["tint_red"]
    return colors


class CompanionIconSynthesizer:
    def __init__(self, probe: dict[str, Any], data: dict[str, Any]) -> None:
        self.probe = probe
        self.data = data
        self.reader: ModReader | None = None
        source_path = probe.get("source_path")
        if source_path:
            source = Path(os.path.expandvars(str(source_path)))
            if source.exists():
                self.reader = ModReader(source)
        self.config_values = build_default_companion_config(probe)
        self.color_values = build_default_color_values(probe)
        self.rescale_relative = 2.0
        self.const_assignments: dict[str, str] = {}
        self.const_index_assignments: dict[str, dict[str, str]] = defaultdict(dict)
        self.shape_assignments: dict[str, str] = {}
        self.const_cache: dict[str, Any] = {}
        self.rule_locals_cache: dict[str, dict[str, str]] = {}
        if self.reader:
            self._parse_constants()

    def close(self) -> None:
        if self.reader:
            self.reader.close()

    def _parse_constants(self) -> None:
        assert self.reader is not None
        text = self.reader.read_text("prototypes/0-constants.lua")
        relative_match = re.search(r"rescale_relative\s*=\s*([0-9.]+)", text)
        if relative_match:
            self.rescale_relative = float(relative_match.group(1))
        clean = remove_lua_comments(text)
        assign_pattern = re.compile(
            r'(?m)^(?:local\s+)?(const|shapes)\.([A-Za-z_][A-Za-z0-9_]*)(?:\["([^"]+)"\])?\s*=\s*'
        )
        idx = 0
        while True:
            match = assign_pattern.search(clean, idx)
            if not match:
                break
            expr, end = capture_expression_until_line_break(clean, match.end())
            bucket = match.group(1)
            name = match.group(2)
            index_key = match.group(3)
            if bucket == "shapes":
                self.shape_assignments[name] = expr
            elif index_key is not None:
                self.const_index_assignments[name][index_key] = expr
            else:
                self.const_assignments[name] = expr
            idx = end

    def _rule_locals(self, rule_path: str) -> dict[str, str]:
        if rule_path in self.rule_locals_cache:
            return self.rule_locals_cache[rule_path]
        if not self.reader:
            self.rule_locals_cache[rule_path] = {}
            return {}
        text = self.reader.read_text(rule_path)
        clean = remove_lua_comments(text)
        locals_map: dict[str, str] = {}
        assign_pattern = re.compile(r"(?m)^local\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*")
        idx = 0
        while True:
            match = assign_pattern.search(clean, idx)
            if not match:
                break
            expr, end = capture_expression_until_line_break(clean, match.end())
            locals_map[match.group(1)] = expr
            idx = end
        self.rule_locals_cache[rule_path] = locals_map
        return locals_map

    def _resolve_background_const(self, name: str, stack: set[str] | None = None) -> dict[str, Any] | None:
        if not self.config_values.get("add_background"):
            return None
        layer_specs = {
            "icon_bg_white_11": ("bg-recipe1-white.png", "scale_11", "shift_11", "tint_bg_white", False, False),
            "icon_bg_white_f1b": ("bg-recipe1-white.png", "scale_f1b", "shift_f1b", "tint_bg_white", False, True),
            "icon_bg_white_20": ("bg-recipe2-white-r16.png", "scale_11", "shift_11", "tint_bg_white", False, False),
            "icon_bg_white_22tl": ("bg-recipe1-white.png", "scale_22", "shift_22tl", "tint_bg_white", False, True),
            "icon_bg_white_f2tr": ("bg-recipe1-white.png", "scale_f2", "shift_f2tr", "tint_bg_white", False, False),
            "icon_bg_white_32tl": ("bg-recipe1-white.png", "scale_32", "shift_32tl", "tint_bg_white", False, False),
            "icon_bg_white_32br": ("bg-recipe1-white.png", "scale_32", "shift_32br", "tint_bg_white", False, False),
            "icon_bg_white_p1bl": ("bg-recipe1-white.png", "scale_p1", "shift_p1bl", "tint_bg_white", False, False),
            "icon_bg_gray_11": ("bg-recipe1-white.png", "scale_11", "shift_11", "tint_bg_gray", False, False),
        }
        if name not in layer_specs:
            raise ExpressionUnresolved(f"unknown background const reference: {name}")
        filename, scale_name, shift_name, tint_name, draw_background, floating = layer_specs[name]
        if scale_name == "scale_f1b":
            scale = (64 * float(self._resolve_const("scale_f1", stack)) - 2 * float(self._resolve_const("shift_f1b", stack)[1])) / 64
        else:
            scale = float(self._resolve_const(scale_name, stack))
        layer: dict[str, Any] = {
            "icon": f"__recipe-icons-improvement-for-esir__/graphics/background/{filename}",
            "scale": scale,
            "shift": copy.deepcopy(self._resolve_const(shift_name, stack)),
            "tint": copy.deepcopy(self.color_values[tint_name]),
            "draw_background": draw_background,
        }
        if floating:
            layer["floating"] = True
        return normalize_icon_layer(layer)

    def _resolve_const(self, name: str, stack: set[str] | None = None) -> Any:
        if name in {"icon_null", "icon_empty"}:
            return None
        if name in self.const_cache:
            return copy.deepcopy(self.const_cache[name])
        stack = stack or set()
        if name in stack:
            raise ExpressionUnresolved(f"recursive const reference: {name}")
        stack = set(stack)
        stack.add(name)
        value: Any
        if name.startswith("icon_bg_"):
            value = self._resolve_background_const(name, stack)
        elif name == "shift_f1bl":
            value = copy.deepcopy(self._resolve_const("shift_b1bl", stack))
        elif name == "shift_f1br":
            value = copy.deepcopy(self._resolve_const("shift_b1br", stack))
        elif name.startswith("rescale_"):
            scale_name = "scale_" + name.split("rescale_", 1)[1]
            scale_value = self._resolve_const(scale_name, stack)
            if not isinstance(scale_value, (int, float)):
                raise ExpressionUnresolved(f"non-numeric scale constant: {name}")
            value = scale_value * self.rescale_relative
        elif name in self.const_assignments:
            value = self._evaluate_expression(self.const_assignments[name], None, stack)
            if name in self.const_index_assignments and isinstance(value, dict):
                for key, expr in self.const_index_assignments[name].items():
                    value[key] = self._evaluate_expression(expr, None, stack)
        elif name in self.const_index_assignments:
            value = {
                key: self._evaluate_expression(expr, None, stack)
                for key, expr in self.const_index_assignments[name].items()
            }
        else:
            shape_match = re.fullmatch(r"icon_([a-z]+)_([a-z0-9_]+)", name)
            if shape_match and shape_match.group(2) in self.shape_assignments:
                shape_value = self._evaluate_expression(self.shape_assignments[shape_match.group(2)], None, stack)
                if not isinstance(shape_value, dict):
                    raise ExpressionUnresolved(f"shape constant did not resolve to dict: {name}")
                value = copy.deepcopy(shape_value)
                tint_name = f"tint_{shape_match.group(1)}"
                if tint_name in self.color_values:
                    value["tint"] = copy.deepcopy(self.color_values[tint_name])
            else:
                raise ExpressionUnresolved(f"unknown const reference: {name}")
        self.const_cache[name] = copy.deepcopy(value)
        return copy.deepcopy(value)

    def _resolve_reference(self, expr: str, rule_path: str | None, stack: set[str] | None = None) -> Any:
        stack = stack or set()
        if expr.startswith("data.raw"):
            prototype_type, prototype_name = parse_data_raw_reference(expr)
            if prototype_type and prototype_name:
                prototype = self.data.get(prototype_type, {}).get(prototype_name)
                if prototype is not None:
                    return prototype
            raise ExpressionUnresolved(f"unresolved prototype reference: {expr}")
        if expr.startswith("config."):
            key = expr.split(".", 1)[1]
            if key in self.config_values:
                return self.config_values[key]
            raise ExpressionUnresolved(f"unknown config reference: {expr}")
        if expr.startswith("color."):
            key = expr.split(".", 1)[1]
            if key in self.color_values:
                return copy.deepcopy(self.color_values[key])
            raise ExpressionUnresolved(f"unknown color reference: {expr}")
        if expr.startswith("const."):
            return self._resolve_chain(self._resolve_const, expr[6:], rule_path, stack)
        if expr.startswith("shapes."):
            name = expr.split(".", 1)[1]
            if name in self.shape_assignments:
                return self._evaluate_expression(self.shape_assignments[name], rule_path, stack)
            raise ExpressionUnresolved(f"unknown shapes reference: {expr}")
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", expr):
            if not rule_path:
                raise ExpressionUnresolved(f"unresolved bare reference without rule scope: {expr}")
            locals_map = self._rule_locals(rule_path)
            if expr in locals_map:
                local_key = f"{rule_path}:{expr}"
                if local_key in stack:
                    raise ExpressionUnresolved(f"recursive local reference: {expr}")
                nested = set(stack)
                nested.add(local_key)
                return self._evaluate_expression(locals_map[expr], rule_path, nested)
            raise ExpressionUnresolved(f"unknown local reference: {expr}")
        raise ExpressionUnresolved(f"unsupported reference expression: {expr}")

    def _resolve_chain(
        self,
        root_resolver: Any,
        chain_text: str,
        rule_path: str | None,
        stack: set[str] | None = None,
    ) -> Any:
        name_match = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)", chain_text)
        if not name_match:
            raise ExpressionUnresolved(f"invalid chain: {chain_text}")
        current = root_resolver(name_match.group(1), stack)
        idx = name_match.end()
        while idx < len(chain_text):
            if chain_text[idx] == ".":
                field_match = re.match(r"\.([A-Za-z_][A-Za-z0-9_]*)", chain_text[idx:])
                if not field_match:
                    raise ExpressionUnresolved(f"invalid field access: {chain_text}")
                key = field_match.group(1)
                if not isinstance(current, dict) or key not in current:
                    raise ExpressionUnresolved(f"missing field {key} in {chain_text}")
                current = copy.deepcopy(current[key])
                idx += len(field_match.group(0))
                continue
            if chain_text[idx] == "[":
                end = find_matching(chain_text, idx, "[", "]")
                raw_key = strip_outer_parens(chain_text[idx + 1 : end])
                key_value = self._evaluate_expression(raw_key, rule_path, stack)
                if not isinstance(current, dict) or key_value not in current:
                    raise ExpressionUnresolved(f"missing index {key_value!r} in {chain_text}")
                current = copy.deepcopy(current[key_value])
                idx = end + 1
                continue
            raise ExpressionUnresolved(f"unsupported chain access: {chain_text}")
        return current

    def _evaluate_table(self, expr: str, rule_path: str | None, stack: set[str] | None = None) -> Any:
        inner = strip_outer_parens(expr)[1:-1].strip()
        if not inner:
            return {}
        items = split_top_level_args(inner)
        keyed = any(find_top_level_equals(item) != -1 for item in items)
        if not keyed:
            return [self._evaluate_expression(item, rule_path, stack) for item in items]
        result: dict[str, Any] = {}
        for item in items:
            eq_idx = find_top_level_equals(item)
            if eq_idx == -1:
                continue
            key = item[:eq_idx].strip()
            value_expr = item[eq_idx + 1 :].strip()
            result[key] = self._evaluate_expression(value_expr, rule_path, stack)
        return result

    def _evaluate_call(self, name: str, args: list[str], rule_path: str, stack: set[str] | None = None) -> Any:
        if name == "table.deepcopy" and args:
            return copy.deepcopy(self._evaluate_expression(args[0], rule_path, stack))
        if name == "try_get_single_icon" and len(args) >= 2:
            return self._make_single_icon(args[0], args[1], rule_path, stack)
        if name == "try_get_single_icon_if" and len(args) >= 3:
            condition = self._evaluate_expression(args[0], rule_path, stack)
            if lua_truthy(condition):
                return self._make_single_icon(args[1], args[2], rule_path, stack)
            return None
        if name == "pass_icon_if" and len(args) >= 2:
            condition = self._evaluate_expression(args[0], rule_path, stack)
            if lua_truthy(condition):
                return self._evaluate_expression(args[1], rule_path, stack)
            return None
        if name == "make_icon_outline" and args:
            icon = self._evaluate_expression(args[0], rule_path, stack)
            if icon is None:
                return None
            if not isinstance(icon, dict):
                raise ExpressionUnresolved(f"outline target is not an icon layer: {name}")
            params = self._evaluate_expression(args[1], rule_path, stack) if len(args) >= 2 else {}
            params = params if isinstance(params, dict) else {}
            outlined = copy.deepcopy(icon)
            outlined["scale"] = (outlined.get("scale") or 1) * float(params.get("scale") or 1.5)
            outlined["tint"] = copy.deepcopy(params.get("tint") or self.color_values["tint_outline"])
            outlined["floating"] = True
            outlined["draw_background"] = False
            return normalize_icon_layer(outlined)
        if name == "make_corner_outline" and args:
            icon = self._evaluate_expression(args[0], rule_path, stack)
            if icon is None:
                return None
            if not isinstance(icon, dict):
                raise ExpressionUnresolved(f"corner outline target is not an icon layer: {name}")
            params = {}
            if len(args) >= 2:
                raw_params = self._evaluate_expression(args[1], rule_path, stack)
                if isinstance(raw_params, dict):
                    params = raw_params
            way = self._evaluate_expression(args[2], rule_path, stack) if len(args) >= 3 else "tr"
            outlined = copy.deepcopy(icon)
            old_scale = float(outlined.get("scale") or 1)
            default_scale = 1.5 if outlined.get("icon") == "__recipe-icons-improvement-for-esir__/graphics/shapes/overlay-diamond-tr.png" else 1.25
            outlined["scale"] = old_scale * float(params.get("scale") or default_scale)
            outlined["tint"] = copy.deepcopy(params.get("tint") or self.color_values["tint_outline"])
            outlined["floating"] = True
            shift = resolve_shift_value(outlined.get("shift")) or [0.0, 0.0]
            reshift = float(outlined.get("icon_size") or 64) * (outlined["scale"] - old_scale) / 2
            if way == "tl":
                shift = [shift[0] + reshift, shift[1] + reshift]
            elif way == "bl":
                shift = [shift[0] + reshift, shift[1] - reshift]
            elif way == "br":
                shift = [shift[0] - reshift, shift[1] - reshift]
            else:
                shift = [shift[0] - reshift, shift[1] + reshift]
            outlined["shift"] = shift
            outlined["draw_background"] = False
            return normalize_icon_layer(outlined)
        if name == "make_bg_icon" and len(args) >= 2:
            base_icon = self._evaluate_expression(args[0], rule_path, stack)
            bg_icon = self._evaluate_expression(args[1], rule_path, stack)
            if not isinstance(base_icon, dict):
                raise ExpressionUnresolved("make_bg_icon base did not resolve to a layer")
            new_icon = copy.deepcopy(base_icon)
            new_icon["icon"] = bg_icon
            new_icon["floating"] = True
            new_icon["draw_background"] = False
            return normalize_icon_layer(new_icon)
        raise ExpressionUnresolved(f"unsupported function call: {name}")

    def _make_single_icon(
        self,
        target_expr: str,
        params_expr: str,
        rule_path: str,
        stack: set[str] | None = None,
    ) -> dict[str, Any] | None:
        target = self._evaluate_expression(target_expr, rule_path, stack)
        params = self._evaluate_expression(params_expr, rule_path, stack)
        if not isinstance(params, dict):
            raise ExpressionUnresolved("try_get_single_icon params did not resolve to a table")
        layers = derive_icon_layers(target) if isinstance(target, dict) else []
        if layers:
            icon = copy.deepcopy(layers[0])
            icon["scale"] = float(params.get("scale") or 1) * float(
                icon.get("scale") or (0.5 * 64 / float(icon.get("icon_size") or 64))
            )
            icon_shift = resolve_shift_value(icon.get("shift"))
            param_shift = resolve_shift_value(params.get("shift"))
            if icon_shift and param_shift:
                icon["shift"] = [icon_shift[0] + param_shift[0], icon_shift[1] + param_shift[1]]
            elif icon_shift:
                icon["shift"] = icon_shift
            elif param_shift:
                icon["shift"] = param_shift
            icon["tint"] = merge_tints(icon.get("tint"), params.get("tint"))
            icon["floating"] = icon.get("floating") or params.get("floating")
            icon["draw_background"] = params.get("draw_background")
            if icon["draw_background"] is None:
                icon["draw_background"] = True
            return normalize_icon_layer(icon)
        return None

    def _evaluate_expression(self, expr: str, rule_path: str | None, stack: set[str] | None = None) -> Any:
        expr = strip_outer_parens(expr)
        if expr in {"", "nil"}:
            return None
        if expr == "true":
            return True
        if expr == "false":
            return False
        if re.fullmatch(r"-?\d+(?:\.\d+)?", expr):
            return float(expr) if "." in expr else int(expr)
        if (expr.startswith('"') and expr.endswith('"')) or (expr.startswith("'") and expr.endswith("'")):
            return expr[1:-1]
        if expr.startswith("{") and expr.endswith("}"):
            return self._evaluate_table(expr, rule_path, stack)
        or_parts = split_top_level_keyword(expr, "or")
        if len(or_parts) > 1:
            current = self._evaluate_expression(or_parts[0], rule_path, stack)
            if lua_truthy(current):
                return current
            for part in or_parts[1:]:
                current = self._evaluate_expression(part, rule_path, stack)
                if lua_truthy(current):
                    return current
            return current
        and_parts = split_top_level_keyword(expr, "and")
        if len(and_parts) > 1:
            current = self._evaluate_expression(and_parts[0], rule_path, stack)
            if not lua_truthy(current):
                return current
            for part in and_parts[1:]:
                current = self._evaluate_expression(part, rule_path, stack)
                if not lua_truthy(current):
                    return current
            return current
        for operator in ("==", "~=", ">=", "<=", ">", "<"):
            split = split_top_level_operator(expr, operator)
            if split:
                left = self._evaluate_expression(split[0], rule_path, stack)
                right = self._evaluate_expression(split[1], rule_path, stack)
                if operator == "==":
                    return left == right
                if operator == "~=":
                    return left != right
                if operator == ">=":
                    return left >= right
                if operator == "<=":
                    return left <= right
                if operator == ">":
                    return left > right
                return left < right
        concat = split_top_level_operator(expr, "..")
        if concat:
            left = self._evaluate_expression(concat[0], rule_path, stack)
            right = self._evaluate_expression(concat[1], rule_path, stack)
            return f"{left or ''}{right or ''}"
        for operator in ("*", "/", "+", "-"):
            split = split_top_level_operator(expr, operator)
            if split:
                left = self._evaluate_expression(split[0], rule_path, stack)
                right = self._evaluate_expression(split[1], rule_path, stack)
                if operator == "*":
                    return left * right
                if operator == "/":
                    return left / right
                if operator == "+":
                    return left + right
                return left - right
        call_match = re.match(r"^([A-Za-z_][A-Za-z0-9_\.]*)\(", expr)
        if call_match:
            open_paren = expr.find("(")
            if open_paren != -1 and find_matching(expr, open_paren, "(", ")") == len(expr) - 1:
                args_text = expr[open_paren + 1 : -1]
                args = split_top_level_args(args_text)
                return self._evaluate_call(call_match.group(1), args, rule_path or "", stack)
        return self._resolve_reference(expr, rule_path, stack)

    def synthesize(self, rule_hits: list[dict[str, Any]]) -> SynthesizedIconPlan | None:
        if not self.reader:
            return None
        had_icon_hits = False
        notes: list[str] = []
        selected_layers: list[dict[str, Any]] | None = None
        selected_rule_path: str | None = None
        selected_helper: str | None = None
        unresolved_or_dynamic = False
        skipped_condition_false = False
        for hit in rule_hits:
            helper = hit.get("helper")
            icons_expression = hit.get("icons_expression")
            rule_path = hit.get("rule_path")
            if helper not in {"try_set_icons", "try_set_icons_if"} or not icons_expression or not rule_path:
                continue
            had_icon_hits = True
            condition_expression = hit.get("condition_expression")
            if condition_expression:
                try:
                    condition_value = self._evaluate_expression(condition_expression, rule_path)
                except ExpressionUnresolved as exc:
                    notes.append(f"{rule_path}: unresolved condition for icon synthesis ({exc})")
                    unresolved_or_dynamic = True
                    continue
                if not lua_truthy(condition_value):
                    notes.append(f"{rule_path}: default icon condition is false, skipped companion icon rule")
                    skipped_condition_false = True
                    continue
            try:
                layers_value = self._evaluate_expression(icons_expression, rule_path)
            except ExpressionUnresolved as exc:
                notes.append(f"{rule_path}: unresolved icon expression ({exc})")
                unresolved_or_dynamic = True
                continue
            if not isinstance(layers_value, list):
                notes.append(f"{rule_path}: icon expression did not resolve to an icon list")
                unresolved_or_dynamic = True
                continue
            layers = [
                normalize_icon_layer(layer)
                for layer in layers_value
                if isinstance(layer, dict) and layer.get("icon")
            ]
            if not layers:
                notes.append(f"{rule_path}: icon expression resolved without visible layers")
                unresolved_or_dynamic = True
                continue
            if selected_layers is not None:
                notes.append(f"{rule_path}: later companion icon rule overrides an earlier synthesized icon plan")
            selected_layers = layers
            selected_rule_path = rule_path
            selected_helper = helper
        if not had_icon_hits:
            return None
        if selected_layers is not None:
            mode = "selected"
        elif skipped_condition_false and not unresolved_or_dynamic:
            mode = "skipped-condition-false"
        else:
            mode = "unresolved"
        return SynthesizedIconPlan(
            layers=selected_layers,
            notes=notes,
            selected_rule_path=selected_rule_path,
            selected_helper=selected_helper,
            mode=mode,
        )


def load_products(data: dict[str, Any]) -> dict[str, dict[str, Any]]:
    product_map: dict[str, dict[str, Any]] = {}
    for section in (
        "item",
        "fluid",
        "tool",
        "capsule",
        "module",
        "ammo",
        "gun",
        "armor",
        "selection-tool",
    ):
        for name, proto in data.get(section, {}).items():
            product_map[name] = proto
    return product_map


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path("."), help="Repository root.")
    parser.add_argument("--dump", type=Path, default=DEFAULT_DUMP, help="data-raw dump JSON.")
    parser.add_argument("--probe", type=Path, help="Baseline probe JSON from companion_mod_probe.py.")
    parser.add_argument(
        "--dependency-catalog",
        type=Path,
        default=DEFAULT_DEPENDENCY_CATALOG,
        help="Checked-in ESIR dependency catalog used to keep the default scope to ESIR and declared touchpoints.",
    )
    parser.add_argument("--output", type=Path, help="Write the audit JSON here.")
    parser.add_argument(
        "--scope",
        choices=("esir-and-dependencies", "esir-only", "all-candidates"),
        default="esir-and-dependencies",
        help="Default report scope. Use `all-candidates` only when you explicitly want non-ESIR companion spillover.",
    )
    parser.add_argument(
        "--include-non-esir",
        action="store_true",
        help="Deprecated alias for `--scope all-candidates`.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    repo_root = args.repo_root.resolve()
    scope_mode = "all-candidates" if args.include_non_esir else args.scope
    if not args.dump.exists():
        print(f"[ERROR] Dump not found: {args.dump}", file=sys.stderr)
        return 1
    data = json.loads(args.dump.read_text(encoding="utf-8"))
    probe = json.loads(args.probe.read_text(encoding="utf-8")) if args.probe and args.probe.exists() else {}
    locale = parse_locale(repo_root / LOCALE_ROOT)
    source_index, mutation_index = build_repo_index(repo_root)
    companion_index, pattern_rules = build_companion_rule_index(probe)
    signal_gate_state = signal_cleanup_gate_state(probe)
    products = load_products(data)
    dependency_scope = load_dependency_scope(args.dependency_catalog)
    synthesizer = CompanionIconSynthesizer(probe, data)
    entries: list[dict[str, Any]] = []
    candidate_count = 0
    scope_filtered_out: list[dict[str, Any]] = []
    try:
        for recipe_name, recipe in sorted(data.get("recipe", {}).items()):
            source = source_index.get(recipe_name)
            mutations = mutation_index.get(recipe_name, [])
            rule_hits = dedupe_rule_hits(
                companion_index.get(recipe_name, []) + synthetic_pattern_hits(recipe_name, pattern_rules)
            )
            candidate = args.include_non_esir or source or mutations or rule_hits or recipe_name.startswith("ei-")
            if not candidate:
                continue
            candidate_count += 1
            owner_mods = infer_recipe_owner_mods(recipe, products)
            include, scope_reasons, scope_dependency_mods = determine_scope(
                recipe_name,
                source,
                mutations,
                owner_mods,
                dependency_scope,
                scope_mode,
            )
            if not include:
                scope_filtered_out.append(
                    {
                        "prototype_name": recipe_name,
                        "owner_mods": owner_mods,
                        "rule_paths": sorted(
                            {
                                hit.get("rule_path")
                                for hit in rule_hits
                                if isinstance(hit.get("rule_path"), str)
                            }
                        ),
                    }
                )
                continue
            display_name, display_name_source = resolve_localized_name(
                recipe.get("localised_name"),
                locale,
                recipe_name,
                "recipe",
            )
            source_surface_kind, declaration_source_file, primary_patch_file, mutation_files = classify_source_surface(
                source, mutations
            )
            current_layers = derive_icon_layers(recipe)
            notes: list[str] = []
            if not current_layers:
                current_layers, fallback_note = fallback_recipe_icon_layers(recipe, products)
                if fallback_note:
                    notes.append(fallback_note)
            current = {
                "icon_strategy": (
                    source.get("declared_icon_strategy")
                    if source
                    else ("layered-icons" if len(current_layers) > 1 else "single-icon")
                ),
                "icon_layers": current_layers,
                "subgroup": recipe.get("subgroup"),
                "order": recipe.get("order"),
                "hidden_in_factoriopedia": bool(recipe.get("hidden_in_factoriopedia")),
                "factoriopedia_alternative": recipe.get("factoriopedia_alternative"),
                "hide_from_player_crafting": bool(recipe.get("hide_from_player_crafting")),
                "hide_from_signal_gui": bool(recipe.get("hide_from_signal_gui")),
            }
            proposed = copy.deepcopy(current)
            synthesized_plan = synthesizer.synthesize(rule_hits)
            if synthesized_plan:
                notes.extend(
                    note for note in synthesized_plan.notes if note not in notes
                )
                if synthesized_plan.layers:
                    proposed["icon_layers"] = synthesized_plan.layers
            for hit in rule_hits:
                helper = hit.get("helper")
                if helper in {"try_set_icons", "try_set_icons_if"}:
                    proposed["icon_strategy"] = "companion-layered-icons"
                if helper == "try_set_full_order":
                    proposed["subgroup"] = hit.get("subgroup")
                    proposed["order"] = hit.get("order")
                elif helper == "try_set_subgroup":
                    proposed["subgroup"] = hit.get("subgroup")
                elif helper == "try_set_order":
                    proposed["order"] = hit.get("order")
                elif helper == "try_hide_factoriopeida":
                    proposed["hidden_in_factoriopedia"] = True
                elif helper == "try_redirect_factoriopeida":
                    proposed["hidden_in_factoriopedia"] = False
                    proposed["factoriopedia_alternative"] = hit.get("alternative_name")
                elif helper == "try_show_factoriopeida":
                    proposed["hidden_in_factoriopedia"] = False
                elif helper == "try_show_player_crafting":
                    proposed["hide_from_player_crafting"] = False
                elif helper == "try_show_dual":
                    proposed["hidden_in_factoriopedia"] = False
                    proposed["hide_from_player_crafting"] = False
                elif helper == "try_hide_player_crafting":
                    proposed["hide_from_player_crafting"] = True
                elif helper == "try_hide_signal":
                    proposed["hide_from_signal_gui"] = True
                elif helper == "show_fusion_bucket":
                    proposed["hidden_in_factoriopedia"] = False
                    proposed["hide_from_player_crafting"] = True
                    proposed["hide_from_signal_gui"] = True
                    notes.append("matched fusion visibility bucket from companion pattern rule")
            inferred_signal, inferred_note = infer_signal_cleanup(recipe_name, recipe, products)
            if inferred_signal and not proposed["hide_from_signal_gui"]:
                if signal_gate_state == "enabled":
                    proposed["hide_from_signal_gui"] = True
                    if inferred_note:
                        notes.append(inferred_note)
                elif inferred_note:
                    notes.append(f"conditional only: {inferred_note} (companion signal cleanup is setting-gated)")
            style_family = determine_style_family(rule_hits, source["source_file"] if source else None, recipe_name)
            evidence_state = classify_evidence_state(rule_hits)
            overlay_plan = build_overlay_plan(rule_hits, style_family, synthesized_plan)
            if overlay_plan:
                proposed["overlay_plan"] = overlay_plan
            icon_proposal_fidelity, icon_proposal_reason = classify_icon_proposal(
                current["icon_layers"],
                proposed["icon_layers"],
                overlay_plan,
            )
            icon_proposal_ready = (
                icon_proposal_fidelity == "concrete"
                and evidence_state in {"direct-helper", "direct-rule-file"}
            )
            preset_tags = determine_preset_tags(current, proposed, rule_hits, style_family)
            if mutations and not source:
                notes.append("source mapped from data.raw.recipe mutation rather than direct declaration")
            heuristic_only = evidence_state in {"pattern-rule", "heuristic-only"}
            has_source_surface = source_surface_kind != "none"
            if evidence_state == "pattern-rule":
                notes.append("proposal is backed by companion pattern rules, not direct prototype helper hits")
            elif heuristic_only:
                notes.append("no direct companion rule hit; proposed state is best-effort")
            if synthesized_plan and synthesized_plan.selected_rule_path:
                notes.append(f"synthesized companion icon layers from {synthesized_plan.selected_rule_path}")
            if style_family == "manual-review" or not has_source_surface:
                status = "manual-review-needed"
            elif heuristic_only:
                status = "heuristic-only"
            else:
                status = "ready"
            entries.append(
                {
                    "prototype_name": recipe_name,
                    "prototype_type": "recipe",
                    "display_name": display_name,
                    "display_name_source": display_name_source,
                    "source_file": declaration_source_file,
                    "declaration_source_file": declaration_source_file,
                    "primary_patch_file": primary_patch_file,
                    "source_mutation_files": mutation_files,
                    "source_surface_kind": source_surface_kind,
                    "owner_mods": owner_mods,
                    "scope_reason": scope_reasons,
                    "scope_dependency_mods": scope_dependency_mods,
                    "style_family": style_family,
                    "preset_tags": preset_tags,
                    "status": status,
                    "heuristic_only": heuristic_only,
                    "evidence_state": evidence_state,
                    "icon_proposal_fidelity": icon_proposal_fidelity,
                    "icon_proposal_ready": icon_proposal_ready,
                    "icon_proposal_reason": icon_proposal_reason,
                    "signal_cleanup_gate_state": signal_gate_state,
                    "notes": notes,
                    "rule_evidence": [
                        {
                            "rule_path": hit.get("rule_path"),
                            "helper": hit.get("helper"),
                            "subgroup": hit.get("subgroup"),
                            "order": hit.get("order"),
                            "alternative_name": hit.get("alternative_name"),
                            "condition_expression": hit.get("condition_expression"),
                            "icons_expression": hit.get("icons_expression"),
                        }
                        for hit in rule_hits
                    ],
                    "current": current,
                    "proposed": proposed,
                }
            )
    finally:
        synthesizer.close()
    payload = {
        "repo_root": str(repo_root),
        "dump_path": str(args.dump),
        "probe_path": str(args.probe) if args.probe else None,
        "scope": {
            "mode": scope_mode,
            "dependency_catalog_path": dependency_scope.get("catalog_path"),
            "allowed_mods_count": len(dependency_scope.get("allowed_mods", set())),
            "target_recipe_count": len(dependency_scope.get("target_recipe_names", set())),
            "target_recipe_by_name_count": len(dependency_scope.get("target_recipe_names_by_name", set())),
            "candidate_entries_before_scope": candidate_count,
            "filtered_out": len(scope_filtered_out),
            "filtered_examples": scope_filtered_out[:25],
        },
        "counts": {
            "entries": len(entries),
            "manual_review_needed": sum(1 for entry in entries if entry["status"] == "manual-review-needed"),
            "heuristic_only": sum(1 for entry in entries if entry["status"] == "heuristic-only"),
            "strategy_only_icon_proposals": sum(
                1 for entry in entries if entry["icon_proposal_fidelity"] == "strategy-only"
            ),
            "concrete_icon_proposals": sum(
                1 for entry in entries if entry["icon_proposal_fidelity"] == "concrete"
            ),
        },
        "entries": entries,
    }
    if args.output:
        write_json(args.output, payload)
    else:
        print(json.dumps(payload, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

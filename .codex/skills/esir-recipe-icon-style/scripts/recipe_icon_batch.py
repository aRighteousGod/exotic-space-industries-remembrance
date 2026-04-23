#!/usr/bin/env python3
"""
Normalize recipe icon audit data plus optional manual entries into one manifest that
can drive report rendering and later patch planning.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def load_entries(path: Path) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(payload, dict) and isinstance(payload.get("entries"), list):
        return payload, payload["entries"]
    if isinstance(payload, list):
        return {}, payload
    raise ValueError(f"Unsupported manifest shape in {path}")


def has_sort_change(entry: dict[str, Any]) -> bool:
    current = entry.get("current") or {}
    proposed = entry.get("proposed") or {}
    return any(current.get(key) != proposed.get(key) for key in ("subgroup", "order"))


def has_visibility_change(entry: dict[str, Any]) -> bool:
    current = entry.get("current") or {}
    proposed = entry.get("proposed") or {}
    return any(
        current.get(key) != proposed.get(key)
        for key in (
            "hidden_in_factoriopedia",
            "factoriopedia_alternative",
            "hide_from_player_crafting",
            "hide_from_signal_gui",
        )
    )


def patch_target_kind(entry: dict[str, Any]) -> str:
    declared_kind = entry.get("source_surface_kind")
    if declared_kind in {"source-file", "mutation-only", "source-and-mutation", "none"}:
        return declared_kind
    source = entry.get("source_file")
    mutations = sorted(set(entry.get("source_mutation_files") or []))
    if source:
        distinct_mutations = [path for path in mutations if path != source]
        if distinct_mutations:
            return "source-and-mutation"
        return "source-file"
    if mutations:
        return "mutation-only"
    return "none"


def compute_review_priority(entry: dict[str, Any]) -> tuple[str, int]:
    evidence_state = entry.get("evidence_state")
    fidelity = entry.get("icon_proposal_fidelity")
    target_kind = patch_target_kind(entry)
    has_patch_target = target_kind != "none"
    if entry.get("icon_proposal_ready"):
        if has_patch_target:
            return "patch-ready-icon", 100
        return "source-map-needed", 88
    if fidelity == "strategy-only" and evidence_state in {"direct-helper", "direct-rule-file"}:
        return "icon-plan-needed", 90
    if evidence_state in {"direct-helper", "direct-rule-file"} and (
        has_sort_change(entry) or has_visibility_change(entry)
    ):
        if has_patch_target:
            return "behavior-ready", 75
        return "source-map-needed", 68
    if fidelity == "strategy-only":
        return "icon-needs-evidence", 60
    if entry.get("status") == "heuristic-only" or evidence_state == "pattern-rule":
        return "needs-evidence", 45
    if entry.get("status") == "manual-review-needed":
        return "manual-review", 25
    return "informational", 10


def apply_review_priority(entry: dict[str, Any], force: bool = False) -> None:
    if not force and entry.get("review_priority") is not None and entry.get("review_priority_score") is not None:
        return
    review_priority, review_priority_score = compute_review_priority(entry)
    entry["review_priority"] = review_priority
    entry["review_priority_score"] = review_priority_score


def deep_merge_dict(base: dict[str, Any], extra: dict[str, Any]) -> dict[str, Any]:
    merged = dict(base)
    for key, value in extra.items():
        if isinstance(value, dict) and isinstance(merged.get(key), dict):
            merged[key] = deep_merge_dict(merged[key], value)
        else:
            merged[key] = value
    return merged


def ensure_preview_defaults(entry: dict[str, Any], force: bool = False) -> None:
    preview = entry.setdefault("preview", {})
    if force and preview.get("manual_override"):
        force = False
    proposal_fidelity = entry.get("icon_proposal_fidelity")
    current_layers = entry.get("current", {}).get("icon_layers") or []
    preview_layers = preview.get("layers") or []
    proposed_layers = entry.get("proposed", {}).get("icon_layers") or []
    if force or "render_basis" not in preview:
        if preview_layers:
            preview["render_basis"] = "preview-layers"
        elif proposal_fidelity == "concrete" and proposed_layers:
            preview["render_basis"] = "proposed-layers"
        elif current_layers:
            preview["render_basis"] = "current-fallback" if proposal_fidelity != "unchanged" else "current-layers"
        else:
            preview["render_basis"] = "placeholder"
    if force or "render_mode" not in preview:
        render_basis = preview.get("render_basis")
        if render_basis == "preview-layers":
            preview["render_mode"] = "from-preview-layers"
        elif render_basis == "proposed-layers":
            preview["render_mode"] = "from-proposed-layers"
        elif current_layers:
            preview["render_mode"] = "from-current-layers"
        else:
            preview["render_mode"] = "placeholder"
    if force or "proposal_reason" not in preview:
        preview["proposal_reason"] = entry.get("icon_proposal_reason")


def ensure_entry_shape(entry: dict[str, Any]) -> dict[str, Any]:
    normalized = {
        "prototype_name": entry.get("prototype_name"),
        "prototype_type": entry.get("prototype_type", "recipe"),
        "display_name": entry.get("display_name") or entry.get("prototype_name"),
        "display_name_source": entry.get("display_name_source", "prototype_name"),
        "source_file": entry.get("source_file"),
        "declaration_source_file": entry.get("declaration_source_file") or entry.get("source_file"),
        "primary_patch_file": entry.get("primary_patch_file"),
        "source_mutation_files": list(entry.get("source_mutation_files") or []),
        "source_surface_kind": entry.get("source_surface_kind"),
        "patch_target_kind": entry.get("patch_target_kind"),
        "has_patch_target": bool(entry.get("has_patch_target")),
        "owner_mods": list(entry.get("owner_mods") or []),
        "scope_reason": list(entry.get("scope_reason") or []),
        "scope_dependency_mods": list(entry.get("scope_dependency_mods") or []),
        "style_family": entry.get("style_family", "manual-review"),
        "preset_tags": sorted(set(entry.get("preset_tags") or [])),
        "status": entry.get("status", "manual-review-needed"),
        "heuristic_only": bool(entry.get("heuristic_only")),
        "evidence_state": entry.get("evidence_state", "heuristic-only"),
        "icon_proposal_fidelity": entry.get("icon_proposal_fidelity", "unchanged"),
        "icon_proposal_ready": bool(entry.get("icon_proposal_ready")),
        "icon_proposal_reason": entry.get("icon_proposal_reason", "no proposed icon-layer delta"),
        "review_priority": entry.get("review_priority"),
        "review_priority_score": (
            int(entry["review_priority_score"]) if entry.get("review_priority_score") is not None else None
        ),
        "notes": list(entry.get("notes") or []),
        "rule_evidence": list(entry.get("rule_evidence") or []),
        "current": entry.get("current") or {},
        "proposed": entry.get("proposed") or {},
        "preview": entry.get("preview") or {},
    }
    if normalized["primary_patch_file"] is None:
        if normalized["declaration_source_file"]:
            normalized["primary_patch_file"] = normalized["declaration_source_file"]
        elif normalized["source_mutation_files"]:
            normalized["primary_patch_file"] = normalized["source_mutation_files"][0]
    normalized["patch_target_kind"] = patch_target_kind(normalized)
    normalized["has_patch_target"] = normalized["patch_target_kind"] != "none"
    apply_review_priority(normalized, force=True)
    ensure_preview_defaults(normalized)
    return normalized


def entry_key(entry: dict[str, Any]) -> tuple[str, str]:
    return (
        str(entry.get("prototype_type") or "recipe"),
        str(entry.get("prototype_name") or ""),
    )


def merge_entries(base: dict[str, Any], extra: dict[str, Any]) -> dict[str, Any]:
    merged = ensure_entry_shape(base)
    explicit_priority_override = any(
        extra.get(key) is not None for key in ("review_priority", "review_priority_score")
    )
    if "prototype_type" in extra and extra.get("prototype_type") is not None:
        merged["prototype_type"] = extra["prototype_type"]
    for key in (
        "display_name",
        "display_name_source",
        "source_file",
        "declaration_source_file",
        "primary_patch_file",
        "source_surface_kind",
        "style_family",
        "status",
        "evidence_state",
        "icon_proposal_fidelity",
        "icon_proposal_reason",
        "review_priority",
    ):
        if key in extra and extra.get(key) is not None:
            merged[key] = extra[key]
    if "heuristic_only" in extra:
        merged["heuristic_only"] = bool(extra.get("heuristic_only"))
    if "icon_proposal_ready" in extra:
        merged["icon_proposal_ready"] = bool(extra.get("icon_proposal_ready"))
    if "review_priority_score" in extra and extra.get("review_priority_score") is not None:
        merged["review_priority_score"] = int(extra["review_priority_score"])
    if "preset_tags" in extra:
        merged["preset_tags"] = sorted(set(merged["preset_tags"]) | set(extra.get("preset_tags") or []))
    if "notes" in extra:
        merged["notes"] = merged["notes"] + [
            note for note in (extra.get("notes") or []) if note not in merged["notes"]
        ]
    if "rule_evidence" in extra:
        merged["rule_evidence"] = merged["rule_evidence"] + [
            item
            for item in (extra.get("rule_evidence") or [])
            if item not in merged["rule_evidence"]
        ]
    if "source_mutation_files" in extra:
        merged["source_mutation_files"] = merged["source_mutation_files"] + [
            path
            for path in (extra.get("source_mutation_files") or [])
            if path not in merged["source_mutation_files"]
        ]
    if "owner_mods" in extra:
        merged["owner_mods"] = list(extra.get("owner_mods") or [])
    if "scope_reason" in extra:
        merged["scope_reason"] = list(extra.get("scope_reason") or [])
    if "scope_dependency_mods" in extra:
        merged["scope_dependency_mods"] = list(extra.get("scope_dependency_mods") or [])
    if isinstance(extra.get("current"), dict):
        merged["current"] = deep_merge_dict(merged["current"], extra["current"])
    if isinstance(extra.get("proposed"), dict):
        merged["proposed"] = deep_merge_dict(merged["proposed"], extra["proposed"])
    if isinstance(extra.get("preview"), dict):
        merged["preview"] = deep_merge_dict(merged["preview"], extra["preview"])
    merged["patch_target_kind"] = patch_target_kind(merged)
    merged["has_patch_target"] = merged["patch_target_kind"] != "none"
    if not explicit_priority_override:
        apply_review_priority(merged, force=True)
    ensure_preview_defaults(merged, force=True)
    return merged


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--audit", type=Path, required=True, help="Audit JSON from recipe_icon_audit.py.")
    parser.add_argument(
        "--extra-manifest",
        action="append",
        type=Path,
        default=[],
        help="Optional extra manifest JSON files to merge in.",
    )
    parser.add_argument("--output", type=Path, help="Write the normalized batch manifest here.")
    parser.add_argument("--status", action="append", default=[], help="Filter by status.")
    parser.add_argument("--family", action="append", default=[], help="Filter by style family.")
    parser.add_argument("--prototype", action="append", default=[], help="Filter by prototype name.")
    parser.add_argument("--evidence-state", action="append", default=[], help="Filter by evidence state.")
    parser.add_argument(
        "--icon-proposal-fidelity",
        action="append",
        default=[],
        help="Filter by icon proposal fidelity.",
    )
    parser.add_argument("--review-priority", action="append", default=[], help="Filter by review priority.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    audit_payload, audit_entries = load_entries(args.audit)
    manifest_entries = {entry_key(entry): ensure_entry_shape(entry) for entry in audit_entries}
    extra_entries_added = 0
    for extra_path in args.extra_manifest:
        _, extra_entries = load_entries(extra_path)
        for entry in extra_entries:
            if not entry.get("prototype_name"):
                continue
            key = entry_key(entry)
            if key in manifest_entries:
                manifest_entries[key] = merge_entries(manifest_entries[key], entry)
            else:
                manifest_entries[key] = ensure_entry_shape(entry)
                extra_entries_added += 1
    entries = list(manifest_entries.values())
    entries_before_filters = len(entries)
    applied_filters = {
        "status": list(args.status),
        "family": list(args.family),
        "prototype": list(args.prototype),
        "evidence_state": list(args.evidence_state),
        "icon_proposal_fidelity": list(args.icon_proposal_fidelity),
        "review_priority": list(args.review_priority),
    }
    if args.status:
        allowed = set(args.status)
        entries = [entry for entry in entries if entry["status"] in allowed]
    if args.family:
        allowed = set(args.family)
        entries = [entry for entry in entries if entry["style_family"] in allowed]
    if args.prototype:
        allowed = set(args.prototype)
        entries = [entry for entry in entries if entry["prototype_name"] in allowed]
    if args.evidence_state:
        allowed = set(args.evidence_state)
        entries = [entry for entry in entries if entry["evidence_state"] in allowed]
    if args.icon_proposal_fidelity:
        allowed = set(args.icon_proposal_fidelity)
        entries = [entry for entry in entries if entry["icon_proposal_fidelity"] in allowed]
    if args.review_priority:
        allowed = set(args.review_priority)
        entries = [entry for entry in entries if entry["review_priority"] in allowed]
    entries.sort(
        key=lambda entry: (
            -entry.get("review_priority_score", 0),
            entry["status"],
            entry["style_family"],
            entry["prototype_name"],
        )
    )
    payload = {
        "manifest_version": 2,
        "repo_root": audit_payload.get("repo_root"),
        "audit_path": str(args.audit),
        "extra_manifests": [str(path) for path in args.extra_manifest],
        "scope": audit_payload.get("scope"),
        "selection": {
            "entries_from_audit": len(audit_entries),
            "entries_before_batch_filters": entries_before_filters,
            "entries_after_batch_filters": len(entries),
            "extra_entries_added": extra_entries_added,
            "applied_filters": applied_filters,
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
            "patch_ready_icons": sum(1 for entry in entries if entry["review_priority"] == "patch-ready-icon"),
            "source_map_needed": sum(1 for entry in entries if entry["review_priority"] == "source-map-needed"),
            "icon_plan_needed": sum(1 for entry in entries if entry["review_priority"] == "icon-plan-needed"),
            "behavior_ready": sum(1 for entry in entries if entry["review_priority"] == "behavior-ready"),
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

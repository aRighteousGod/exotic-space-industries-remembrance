#!/usr/bin/env python3
"""Read-only ESIR runtime GUI pattern inventory.

The audit is intentionally heuristic. It highlights likely standardization
work without rewriting Lua or deciding whether an exception is invalid.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


CONTROL_DIR = Path("exotic-space-industries-remembrance") / "scripts" / "control"
ROOT_CONTROL = Path("exotic-space-industries-remembrance") / "control.lua"

ROOT_CONST_RE = re.compile(
    r"(?:local\s+)?(?P<name>[A-Z][A-Z0-9_]*(?:GUI_NAME|GUI|STRIP_NAME)|GUI_NAME|RELATIVE_GUI_NAME|SCREEN_GUI_NAME)\s*=\s*\"(?P<value>[^\"]+)\""
)
PARENT_GUI_RE = re.compile(r"parent_gui\s*=\s*(?:\"(?P<literal>[^\"]+)\"|(?P<symbol>[A-Z][A-Z0-9_]*))")
ACTION_RE = re.compile(r"action\s*=\s*\"(?P<action>[^\"]+)\"")
RELATIVE_ANCHOR_RE = re.compile(r"defines\.relative_gui_type\.(?P<anchor>[A-Za-z0-9_]+)")
RELATIVE_POSITION_RE = re.compile(r"defines\.relative_gui_position\.(?P<position>[A-Za-z0-9_]+)")
HANDLER_RE = re.compile(r"function\s+[\w\._:]*on_gui_(?P<handler>opened|closed|click|value_changed|text_changed|selection_state_changed)\b")
FUNCTION_RE = re.compile(r"function\s+(?P<name>[\w\._:]+)")


SURFACE_PATTERNS = {
    "relative": re.compile(r"player\.gui\.relative(?:\.add|\[)"),
    "screen": re.compile(r"player\.gui\.screen(?:\.add|\[)"),
    "left": re.compile(r"player\.gui\.left(?:\.add|\[)"),
    "center": re.compile(r"player\.gui\.center(?:\.add|\[)"),
    "mod_gui_button": re.compile(r"mod_gui\.get_button_flow"),
    "mod_gui_frame": re.compile(r"mod_gui\.get_frame_flow"),
}


STYLE_NAMES = [
    "inside_shallow_frame",
    "ei_subheader_frame",
    "ei_subheader_frame_with_top_border",
    "ei_inner_content_flow",
    "ei_inner_content_flow_horizontal",
    "ei_titlebar_nondraggable_spacer",
    "ei_titlebar_draggable_spacer",
    "frame_action_button",
    "ei_status_progressbar",
    "ei_relative_gui_slider",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Read-only audit of ESIR runtime GUI patterns.")
    parser.add_argument("--repo-root", default=".", help="Repository root. Defaults to current directory.")
    parser.add_argument(
        "--module",
        action="append",
        help="Lua module path or directory to audit, relative to repo root. May be repeated.",
    )
    parser.add_argument("--format", choices=("json", "markdown"), default="markdown", help="Output format.")
    parser.add_argument("--output", help="Optional output path. Omit to print to stdout.")
    return parser.parse_args()


def line_entries(pattern: re.Pattern[str], text: str, value_group: str | None = None) -> list[dict[str, Any]]:
    entries: list[dict[str, Any]] = []
    for line_no, line in enumerate(text.splitlines(), start=1):
        for match in pattern.finditer(line):
            value = match.group(value_group) if value_group else match.group(0)
            entries.append({"line": line_no, "value": value})
    return entries


def resolve_modules(repo_root: Path, module_args: list[str] | None) -> list[Path]:
    if module_args:
        files: list[Path] = []
        for raw in module_args:
            path = Path(raw)
            if not path.is_absolute():
                path = repo_root / path
            if path.is_dir():
                files.extend(sorted(path.rglob("*.lua")))
            elif path.is_file():
                files.append(path)
            else:
                raise FileNotFoundError(f"Module path not found: {raw}")
        return sorted({p.resolve() for p in files})

    control_dir = repo_root / CONTROL_DIR
    files = sorted(control_dir.rglob("*.lua")) if control_dir.is_dir() else []
    root_control = repo_root / ROOT_CONTROL
    if root_control.is_file():
        files.insert(0, root_control)
    return sorted({p.resolve() for p in files})


def relpath(path: Path, repo_root: Path) -> str:
    try:
        return path.relative_to(repo_root).as_posix()
    except ValueError:
        return path.as_posix()


def audit_file(path: Path, repo_root: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8", errors="replace")
    surfaces = {
        name: [{"line": line_no} for line_no, line in enumerate(text.splitlines(), start=1) if pattern.search(line)]
        for name, pattern in SURFACE_PATTERNS.items()
    }
    surfaces = {name: hits for name, hits in surfaces.items() if hits}

    root_constants = [
        {"line": line_no, "name": match.group("name"), "value": match.group("value")}
        for line_no, line in enumerate(text.splitlines(), start=1)
        for match in ROOT_CONST_RE.finditer(line)
    ]
    constants_by_name = {entry["name"]: entry["value"] for entry in root_constants}

    parent_gui_tags: list[dict[str, Any]] = []
    for line_no, line in enumerate(text.splitlines(), start=1):
        for match in PARENT_GUI_RE.finditer(line):
            symbol = match.group("symbol")
            parent_gui_tags.append(
                {
                    "line": line_no,
                    "value": match.group("literal") or constants_by_name.get(symbol, symbol),
                    "raw": match.group("literal") or symbol,
                }
            )

    handlers = line_entries(HANDLER_RE, text, "handler")
    anchors = line_entries(RELATIVE_ANCHOR_RE, text, "anchor")
    positions = line_entries(RELATIVE_POSITION_RE, text, "position")
    actions = line_entries(ACTION_RE, text, "action")
    styles = sorted({style for style in STYLE_NAMES if style in text})

    function_names = [
        {"line": line_no, "name": match.group("name")}
        for line_no, line in enumerate(text.splitlines(), start=1)
        for match in FUNCTION_RE.finditer(line)
    ]
    close_paths = [
        fn for fn in function_names if any(token in fn["name"].lower() for token in ("close", "destroy", "clear_gui"))
    ]
    update_paths = [
        fn for fn in function_names if "gui" in fn["name"].lower() and any(token in fn["name"].lower() for token in ("update", "refresh", "service", "sync"))
    ]

    warnings = build_warnings(
        text=text,
        surfaces=surfaces,
        anchors=anchors,
        parent_gui_tags=parent_gui_tags,
        handlers=handlers,
        close_paths=close_paths,
        update_paths=update_paths,
        root_constants=root_constants,
    )

    return {
        "path": relpath(path, repo_root),
        "surfaces": surfaces,
        "root_constants": root_constants,
        "relative_anchors": anchors,
        "relative_positions": positions,
        "parent_gui_tags": parent_gui_tags,
        "actions": actions,
        "handlers": handlers,
        "styles": styles,
        "close_paths": close_paths,
        "update_paths": update_paths,
        "warnings": warnings,
    }


def build_warnings(
    *,
    text: str,
    surfaces: dict[str, list[dict[str, Any]]],
    anchors: list[dict[str, Any]],
    parent_gui_tags: list[dict[str, Any]],
    handlers: list[dict[str, Any]],
    close_paths: list[dict[str, Any]],
    update_paths: list[dict[str, Any]],
    root_constants: list[dict[str, Any]],
) -> list[str]:
    warnings: list[str] = []
    has_gui_surface = bool(surfaces)
    has_relative = "relative" in surfaces
    has_screen = "screen" in surfaces
    has_mod_gui = "mod_gui_button" in surfaces or "mod_gui_frame" in surfaces
    has_left = "left" in surfaces
    handler_values = {entry["value"] for entry in handlers}

    if has_relative and not anchors:
        warnings.append("Relative GUI references found, but no visible defines.relative_gui_type anchor was detected.")
    if has_screen and not has_relative and "on_gui_opened" in text:
        warnings.append("Screen-only GUI appears to be opened from runtime events; verify this is a modal, detached, proxy/core, or camera/dashboard exception.")
    if has_screen and has_relative:
        warnings.append("Hybrid relative/screen GUI detected; keep fallback or detachable mode explicit in tags or per-player state.")
    if has_mod_gui and (has_relative or has_screen):
        warnings.append("Mixed mod_gui and entity GUI surfaces detected; confirm persistent controls are intentionally separate from entity panels.")
    if (has_mod_gui or has_left) and not (has_relative or has_screen):
        warnings.append("Persistent mod GUI surface detected; keep it for mod-level workflows, not one-entity consoles.")
    if has_gui_surface and not root_constants:
        warnings.append("No stable GUI root constant was detected; prefer GUI_NAME or equivalent root constants.")
    if has_gui_surface and not parent_gui_tags:
        warnings.append("No tags.parent_gui assignments detected; dispatcher routing may rely on names or captions.")
    if "click" in handler_values and "valid" not in text:
        warnings.append("GUI click handler detected without an obvious element.valid guard.")
    if has_relative and not close_paths and "closed" not in handler_values:
        warnings.append("Relative GUI detected without an obvious close/destroy path.")
    if has_gui_surface and not update_paths and re.search(r"progressbar|slider|textfield|drop-down|list-box", text):
        warnings.append("Stateful controls detected without an obvious GUI update/refresh helper.")

    tag_values = {entry["value"] for entry in parent_gui_tags}
    legacy_tags = sorted(value for value in tag_values if value and ("_" in value or value == "mod_gui"))
    if legacy_tags:
        warnings.append(f"Legacy or non-house parent_gui values detected: {', '.join(legacy_tags)}.")

    return warnings


def render_markdown(report: dict[str, Any]) -> str:
    lines = [
        "# ESIR Runtime GUI Pattern Audit",
        "",
        f"- Repo root: `{report['repo_root']}`",
        f"- Modules audited: {len(report['modules'])}",
        "",
    ]
    for module in report["modules"]:
        lines.append(f"## `{module['path']}`")
        lines.append(f"- Surfaces: {format_surface_summary(module['surfaces'])}")
        lines.append(f"- Root names: {format_root_summary(module['root_constants'])}")
        lines.append(f"- Relative anchors: {format_value_summary(module['relative_anchors'])}")
        lines.append(f"- Parent GUI tags: {format_value_summary(module['parent_gui_tags'])}")
        lines.append(f"- Handlers: {format_value_summary(module['handlers'])}")
        lines.append(f"- Styles: {', '.join(module['styles']) if module['styles'] else 'none detected'}")
        if module["warnings"]:
            lines.append("- Warnings:")
            for warning in module["warnings"]:
                lines.append(f"  - {warning}")
        else:
            lines.append("- Warnings: none")
        lines.append("")
    return "\n".join(lines)


def format_surface_summary(surfaces: dict[str, list[dict[str, Any]]]) -> str:
    if not surfaces:
        return "none detected"
    return ", ".join(f"{name} ({len(hits)})" for name, hits in sorted(surfaces.items()))


def format_root_summary(entries: list[dict[str, Any]]) -> str:
    if not entries:
        return "none detected"
    return ", ".join(f"{entry['name']}=`{entry['value']}`" for entry in entries)


def format_value_summary(entries: list[dict[str, Any]]) -> str:
    if not entries:
        return "none detected"
    values: list[str] = []
    for entry in entries:
        value = str(entry["value"])
        if value not in values:
            values.append(value)
    return ", ".join(f"`{value}`" for value in values)


def main() -> int:
    args = parse_args()
    repo_root = Path(args.repo_root).resolve()
    try:
        files = resolve_modules(repo_root, args.module)
    except FileNotFoundError as exc:
        print(str(exc), file=sys.stderr)
        return 2

    modules = [audit_file(path, repo_root) for path in files]
    report = {
        "repo_root": str(repo_root),
        "module_count": len(modules),
        "modules": modules,
    }

    if args.format == "json":
        output = json.dumps(report, indent=2, sort_keys=True)
    else:
        output = render_markdown(report)

    if args.output:
        Path(args.output).write_text(output + "\n", encoding="utf-8")
    else:
        print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

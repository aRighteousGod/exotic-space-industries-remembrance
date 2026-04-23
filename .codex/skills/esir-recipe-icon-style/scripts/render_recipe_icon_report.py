#!/usr/bin/env python3
"""
Render a static HTML report, machine-readable JSON copy, and PNG contact sheet for
recipe icon review outside Factorio.
"""

from __future__ import annotations

import argparse
import base64
import html
import io
import json
import math
import os
import re
import zipfile
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFont, UnidentifiedImageError


CARD_WIDTH = 520
CARD_HEIGHT = 188
SLOT_SIZE = 96
ICON_SIZE = 64
RENDERER_VERSION = 4
FACTORIO_ROOT_HINTS = [
    Path(r"C:\Program Files\Factorio"),
    Path(r"C:\Program Files\Steam\steamapps\common\Factorio"),
    Path(r"C:\Program Files (x86)\Steam\steamapps\common\Factorio"),
    Path(os.path.expandvars(r"%LOCALAPPDATA%\Programs\Factorio")),
]
INSTALLED_MODS_DIR = Path(os.path.expandvars(r"%APPDATA%\Factorio\mods"))
EXTRA_MOD_ROOTS = [
    Path("output/tesla-run-mods"),
    Path(".factorio-qc/fmqc/mods-live"),
]


@dataclass
class ResolvedAsset:
    image: Image.Image | None
    note: str | None
    source_label: str | None


@dataclass
class RenderedPreview:
    icon_image: Image.Image
    slot_image: Image.Image
    notes: list[str]
    source_labels: list[str]
    render_result: str
    placeholder_reason: str | None


class ZipAssetSource:
    def __init__(self, path: Path, label: str) -> None:
        self.path = path
        self.label = label
        self._zip: zipfile.ZipFile | None = None
        self._member_map: dict[str, str] | None = None

    def _ensure_open(self) -> None:
        if self._zip is not None and self._member_map is not None:
            return
        self._zip = zipfile.ZipFile(self.path)
        names = [name for name in self._zip.namelist() if not name.endswith("/")]
        roots = {name.split("/", 1)[0] for name in names if "/" in name}
        root_prefix = ""
        if len(roots) == 1:
            candidate = next(iter(roots))
            if any(name.startswith(candidate + "/") for name in names):
                root_prefix = candidate + "/"
        self._member_map = {}
        for name in names:
            rel = name[len(root_prefix) :] if root_prefix and name.startswith(root_prefix) else name
            self._member_map[rel.replace("\\", "/")] = name

    def read_bytes(self, relative_path: str) -> bytes | None:
        self._ensure_open()
        assert self._zip is not None
        assert self._member_map is not None
        normalized = relative_path.replace("\\", "/")
        member = self._member_map.get(normalized)
        if not member:
            return None
        return self._zip.read(member)


class AssetResolver:
    def __init__(self, repo_root: Path) -> None:
        self.repo_root = repo_root.resolve()
        self.factorio_data_root = self._discover_factorio_data_root()
        self.repo_mod_dirs = self._scan_dir_roots([self.repo_root])
        self.extra_mod_dirs = self._scan_dir_roots(
            [root.resolve() for root in EXTRA_MOD_ROOTS if root.exists()]
        )
        self.factorio_data_dirs = self._scan_factorio_data_root(self.factorio_data_root)
        self.installed_mod_dirs, self.installed_mod_zips = self._scan_installed_mods(
            INSTALLED_MODS_DIR if INSTALLED_MODS_DIR.exists() else None
        )
        self._zip_cache: dict[Path, ZipAssetSource] = {}

    def _discover_factorio_data_root(self) -> Path | None:
        for candidate_root in FACTORIO_ROOT_HINTS:
            data_root = candidate_root / "data"
            if data_root.exists():
                return data_root
        return None

    def _scan_dir_roots(self, roots: list[Path]) -> dict[str, list[tuple[Path, str]]]:
        index: dict[str, list[tuple[Path, str]]] = {}
        for root in roots:
            if not root.exists():
                continue
            for child in root.iterdir():
                if child.is_dir():
                    index.setdefault(child.name, []).append((child, f"repo-local:{child.name}"))
        return index

    def _scan_factorio_data_root(self, root: Path | None) -> dict[str, list[tuple[Path, str]]]:
        index: dict[str, list[tuple[Path, str]]] = {}
        if not root or not root.exists():
            return index
        for child in root.iterdir():
            if child.is_dir():
                index.setdefault(child.name, []).append((child, f"factorio-data:{child.name}"))
        return index

    def _split_mod_name_version(self, name: str) -> tuple[str, str]:
        match = re.match(r"(.+)_([0-9][A-Za-z0-9.\-]*)$", name)
        if match:
            return match.group(1), match.group(2)
        return name, ""

    def _version_key(self, version: str) -> tuple[Any, ...]:
        if not version:
            return tuple()
        parts: list[Any] = []
        for token in re.split(r"[.\-_]", version):
            if token.isdigit():
                parts.append(int(token))
            else:
                parts.append(token)
        return tuple(parts)

    def _scan_installed_mods(
        self, mods_dir: Path | None
    ) -> tuple[dict[str, list[tuple[Path, str]]], dict[str, list[tuple[Path, str]]]]:
        dir_index: dict[str, list[tuple[Path, str]]] = {}
        zip_index: dict[str, list[tuple[Path, str]]] = {}
        if not mods_dir or not mods_dir.exists():
            return dir_index, zip_index
        dir_entries: dict[str, list[tuple[tuple[Any, ...], Path, str]]] = {}
        zip_entries: dict[str, list[tuple[tuple[Any, ...], Path, str]]] = {}
        for child in mods_dir.iterdir():
            if child.name == "mod-list.json":
                continue
            if child.is_dir():
                mod_name, version = self._split_mod_name_version(child.name)
                dir_entries.setdefault(mod_name, []).append(
                    (self._version_key(version), child, f"installed-mod-dir:{child.name}")
                )
            elif child.is_file() and child.suffix.lower() == ".zip":
                mod_name, version = self._split_mod_name_version(child.stem)
                zip_entries.setdefault(mod_name, []).append(
                    (self._version_key(version), child, f"installed-mod-zip:{child.name}")
                )
        for mod_name, entries in dir_entries.items():
            entries.sort(key=lambda item: item[0], reverse=True)
            dir_index[mod_name] = [(path, label) for _, path, label in entries]
        for mod_name, entries in zip_entries.items():
            entries.sort(key=lambda item: item[0], reverse=True)
            zip_index[mod_name] = [(path, label) for _, path, label in entries]
        return dir_index, zip_index

    def _zip_source(self, path: Path, label: str) -> ZipAssetSource:
        if path not in self._zip_cache:
            self._zip_cache[path] = ZipAssetSource(path, label)
        return self._zip_cache[path]

    def _extract_largest_mip(self, image: Image.Image, icon_size: Any) -> Image.Image:
        rgba = image.convert("RGBA")
        if rgba.width == rgba.height:
            return rgba
        crop_size: int | None = None
        if icon_size:
            try:
                crop_size = int(icon_size)
            except (TypeError, ValueError):
                crop_size = None
        if not crop_size or crop_size <= 0:
            crop_size = min(rgba.width, rgba.height)
        crop_size = min(crop_size, rgba.width, rgba.height)
        return rgba.crop((0, 0, crop_size, crop_size))

    def _image_from_bytes(self, payload: bytes, label: str, icon_size: Any = None) -> ResolvedAsset:
        try:
            return ResolvedAsset(
                image=self._extract_largest_mip(Image.open(io.BytesIO(payload)), icon_size),
                note=None,
                source_label=label,
            )
        except (OSError, UnidentifiedImageError) as exc:
            return ResolvedAsset(
                image=None,
                note=f"failed to decode icon from {label}: {exc}",
                source_label=label,
            )

    def _image_from_path(self, path: Path, label: str, icon_size: Any = None) -> ResolvedAsset:
        try:
            return ResolvedAsset(
                image=self._extract_largest_mip(Image.open(path), icon_size),
                note=None,
                source_label=label,
            )
        except (OSError, UnidentifiedImageError) as exc:
            return ResolvedAsset(
                image=None,
                note=f"failed to decode icon from {label}: {exc}",
                source_label=label,
            )

    def resolve_mod_asset(self, mod_name: str, relative_path: str, icon_size: Any = None) -> ResolvedAsset:
        normalized = relative_path.replace("\\", "/")
        resolution_order = [
            self.repo_mod_dirs.get(mod_name, []),
            self.extra_mod_dirs.get(mod_name, []),
            self.factorio_data_dirs.get(mod_name, []),
            self.installed_mod_dirs.get(mod_name, []),
        ]
        for group in resolution_order:
            for root, label in group:
                candidate = root / normalized
                if candidate.exists():
                    resolved = self._image_from_path(candidate, label, icon_size)
                    if resolved.image is None:
                        return resolved
                    note = None if label.startswith("repo-local:") else f"resolved from {label}"
                    return ResolvedAsset(image=resolved.image, note=note, source_label=label)
        for zip_path, label in self.installed_mod_zips.get(mod_name, []):
            source = self._zip_source(zip_path, label)
            payload = source.read_bytes(normalized)
            if payload is not None:
                resolved = self._image_from_bytes(payload, label, icon_size)
                if resolved.image is None:
                    return resolved
                note = f"resolved from {label}"
                return ResolvedAsset(image=resolved.image, note=note, source_label=label)
        return ResolvedAsset(
            image=None,
            note=f"unresolved icon path: __{mod_name}__/{normalized}",
            source_label=None,
        )

    def resolve(self, icon_path: str, icon_size: Any = None) -> ResolvedAsset:
        match = re.match(r"__([^/]+)__/(.+)", icon_path or "")
        if not match:
            candidate = (self.repo_root / (icon_path or "")).resolve()
            if candidate.exists():
                return self._image_from_path(candidate, "repo-local:path", icon_size)
            return ResolvedAsset(
                image=None,
                note=f"unresolved icon path: {icon_path}",
                source_label=None,
            )
        return self.resolve_mod_asset(match.group(1), match.group(2), icon_size)


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def safe_name(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "-", name).strip("-") or "entry"


def apply_tint(image: Image.Image, tint: Any) -> Image.Image:
    if not tint:
        return image
    channels = []
    if isinstance(tint, dict):
        channels = [tint.get(key, 1.0) for key in ("r", "g", "b", "a")]
    elif isinstance(tint, list):
        channels = list(tint)[:4]
    if len(channels) < 4:
        channels += [1.0] * (4 - len(channels))
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            pixels[x, y] = (
                max(0, min(255, int(r * channels[0]))),
                max(0, min(255, int(g * channels[1]))),
                max(0, min(255, int(b * channels[2]))),
                max(0, min(255, int(a * channels[3]))),
            )
    return rgba


def normalize_shift(shift: Any) -> tuple[float, float]:
    if isinstance(shift, list) and len(shift) >= 2:
        return float(shift[0]), float(shift[1])
    return 0.0, 0.0


def render_icon_from_layers(
    layers: list[dict[str, Any]], resolver: AssetResolver
) -> tuple[Image.Image, list[str], list[str], int]:
    canvas = Image.new("RGBA", (ICON_SIZE, ICON_SIZE), (0, 0, 0, 0))
    notes: list[str] = []
    source_labels: list[str] = []
    rendered_layers = 0
    if not layers:
        return canvas, ["no icon layers"], source_labels, rendered_layers
    for layer in layers:
        icon_path = layer.get("icon")
        if not icon_path:
            notes.append("missing icon path in layer")
            continue
        resolved = resolver.resolve(icon_path, layer.get("icon_size"))
        if resolved.note and resolved.note not in notes:
            notes.append(resolved.note)
        if resolved.source_label and resolved.source_label not in source_labels:
            source_labels.append(resolved.source_label)
        if resolved.image is None:
            continue
        image = apply_tint(resolved.image, layer.get("tint"))
        scale = layer.get("scale")
        if scale is None:
            rendered_size = ICON_SIZE
        else:
            rendered_size = max(8, int(round(float(scale) * ICON_SIZE)))
        resized = image.resize((rendered_size, rendered_size), Image.Resampling.LANCZOS)
        shift_x, shift_y = normalize_shift(layer.get("shift"))
        pos = (
            int(round((ICON_SIZE - rendered_size) / 2 + shift_x)),
            int(round((ICON_SIZE - rendered_size) / 2 + shift_y)),
        )
        canvas.alpha_composite(resized, dest=pos)
        rendered_layers += 1
    return canvas, notes, source_labels, rendered_layers


def render_placeholder_icon(label: str) -> Image.Image:
    image = Image.new("RGBA", (ICON_SIZE, ICON_SIZE), (32, 36, 41, 255))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle(
        (0, 0, ICON_SIZE - 1, ICON_SIZE - 1),
        radius=12,
        fill=(35, 40, 47, 255),
        outline=(88, 100, 112, 255),
        width=2,
    )
    font = ImageFont.load_default()
    draw.multiline_text(
        (ICON_SIZE / 2, ICON_SIZE / 2),
        label,
        font=font,
        anchor="mm",
        fill=(210, 215, 220, 255),
        align="center",
    )
    return image


def render_slot(icon_image: Image.Image) -> Image.Image:
    slot = Image.new("RGBA", (SLOT_SIZE, SLOT_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(slot)
    draw.rounded_rectangle(
        (8, 8, SLOT_SIZE - 8, SLOT_SIZE - 8),
        radius=14,
        fill=(31, 34, 38, 255),
        outline=(92, 102, 114, 255),
        width=2,
    )
    draw.rounded_rectangle(
        (12, 12, SLOT_SIZE - 12, SLOT_SIZE - 12),
        radius=10,
        fill=(43, 47, 53, 255),
    )
    slot.alpha_composite(icon_image, dest=((SLOT_SIZE - ICON_SIZE) // 2, (SLOT_SIZE - ICON_SIZE) // 2))
    return slot


def image_to_data_uri(image: Image.Image) -> str:
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    encoded = base64.b64encode(buffer.getvalue()).decode("ascii")
    return f"data:image/png;base64,{encoded}"


def current_vs_proposed(entry: dict[str, Any], key: str) -> str:
    current = entry.get("current", {}).get(key)
    proposed = entry.get("proposed", {}).get(key)
    if current is None or current == "":
        current_text = "-"
    else:
        current_text = str(current).lower() if isinstance(current, bool) else str(current)
    if proposed is None or proposed == "":
        proposed_text = "-"
    else:
        proposed_text = str(proposed).lower() if isinstance(proposed, bool) else str(proposed)
    if current == proposed:
        return current_text
    return f"{current_text} -> {proposed_text}"


def layer_signature(layers: list[dict[str, Any]]) -> str:
    return json.dumps(layers or [], sort_keys=True, ensure_ascii=False, separators=(",", ":"))


def has_unresolved_notes(notes: list[str]) -> bool:
    unresolved_prefixes = ("unresolved icon path", "failed to decode icon from")
    return bool(notes) and all(note.startswith(unresolved_prefixes) for note in notes)


def classify_render_result(
    selection_notes: list[str], render_notes: list[str], rendered_layers: int
) -> tuple[str, str | None]:
    combined = selection_notes + render_notes
    if any(note == "no icon layers" for note in combined):
        return "placeholder-no-icon", "no icon layers"
    if rendered_layers == 0:
        if any(note.startswith("failed to decode icon from") for note in combined):
            return "placeholder-decode-failure", "icon decode failure"
        if any(note.startswith("unresolved icon path") for note in combined):
            return "placeholder-unresolved", "unresolved icon path"
    return "rendered", None


def render_preview_variant(
    layers: list[dict[str, Any]],
    resolver: AssetResolver,
    selection_notes: list[str] | None = None,
) -> RenderedPreview:
    selection_notes = list(selection_notes or [])
    icon_image, render_notes, source_labels, rendered_layers = render_icon_from_layers(layers, resolver)
    render_result, placeholder_reason = classify_render_result(selection_notes, render_notes, rendered_layers)
    if render_result == "placeholder-no-icon":
        icon_image = render_placeholder_icon("NO\nICON")
    elif render_result in {"placeholder-unresolved", "placeholder-decode-failure"}:
        icon_image = render_placeholder_icon("UNRESOLVED")
    return RenderedPreview(
        icon_image=icon_image,
        slot_image=render_slot(icon_image),
        notes=selection_notes + render_notes,
        source_labels=source_labels,
        render_result=render_result,
        placeholder_reason=placeholder_reason,
    )


def summarize_counts(entries: list[dict[str, Any]]) -> dict[str, int]:
    unresolved = 0
    current_unresolved = 0
    review_placeholders = 0
    manual_review = 0
    heuristic_status = 0
    heuristic_evidence = 0
    external_sources = 0
    sort_changed = 0
    visibility_changed = 0
    notes_present = 0
    layer_changed = 0
    mutation_mapped = 0
    strategy_only_icon_proposals = 0
    concrete_icon_proposals = 0
    patch_ready_icons = 0
    source_map_needed = 0
    icon_plan_needed = 0
    behavior_ready = 0
    review_external_sources = 0
    for entry in entries:
        if entry.get("status") == "manual-review-needed":
            manual_review += 1
        if entry.get("status") == "heuristic-only":
            heuristic_status += 1
        if entry.get("evidence_state") == "heuristic-only":
            heuristic_evidence += 1
        if entry.get("icon_proposal_fidelity") == "strategy-only":
            strategy_only_icon_proposals += 1
        if entry.get("icon_proposal_fidelity") == "concrete":
            concrete_icon_proposals += 1
        if entry.get("review_priority") == "patch-ready-icon":
            patch_ready_icons += 1
        if entry.get("review_priority") == "source-map-needed":
            source_map_needed += 1
        if entry.get("review_priority") == "icon-plan-needed":
            icon_plan_needed += 1
        if entry.get("review_priority") == "behavior-ready":
            behavior_ready += 1
        notes = entry.get("notes") or []
        if notes:
            notes_present += 1
        if entry.get("source_mutation_files"):
            mutation_mapped += 1
        preview = entry.get("preview", {})
        if preview.get("current_render_result") in {"placeholder-unresolved", "placeholder-decode-failure"}:
            current_unresolved += 1
        if (preview.get("review_render_result") or "").startswith("placeholder"):
            review_placeholders += 1
        if preview.get("review_render_result") in {"placeholder-unresolved", "placeholder-decode-failure"}:
            unresolved += 1
        sources = (preview.get("current_resolved_sources") or []) + (preview.get("review_resolved_sources") or [])
        if any(source and not source.startswith("repo-local:") for source in sources):
            external_sources += 1
        if preview.get("review_external_source"):
            review_external_sources += 1
        if preview.get("layer_changed", preview.get("rendered_icon_changed")):
            layer_changed += 1
        if any(entry.get("current", {}).get(key) != entry.get("proposed", {}).get(key) for key in ("subgroup", "order")):
            sort_changed += 1
        if any(
            entry.get("current", {}).get(key) != entry.get("proposed", {}).get(key)
            for key in (
                "hidden_in_factoriopedia",
                "factoriopedia_alternative",
                "hide_from_player_crafting",
                "hide_from_signal_gui",
            )
        ):
            visibility_changed += 1
    return {
        "entries": len(entries),
        "manual_review_needed": manual_review,
        "heuristic_only": heuristic_status,
        "heuristic_status": heuristic_status,
        "heuristic_evidence": heuristic_evidence,
        "unresolved_previews": unresolved,
        "current_unresolved_previews": current_unresolved,
        "review_placeholder_entries": review_placeholders,
        "external_source_entries": external_sources,
        "review_external_source_entries": review_external_sources,
        "icon_changed": layer_changed,
        "layer_changed": layer_changed,
        "rendered_icon_changed": layer_changed,
        "sort_changed": sort_changed,
        "visibility_changed": visibility_changed,
        "notes_present": notes_present,
        "mutation_mapped": mutation_mapped,
        "strategy_only_icon_proposals": strategy_only_icon_proposals,
        "concrete_icon_proposals": concrete_icon_proposals,
        "patch_ready_icons": patch_ready_icons,
        "source_map_needed": source_map_needed,
        "icon_plan_needed": icon_plan_needed,
        "behavior_ready": behavior_ready,
    }


def select_layers_for_render(entry: dict[str, Any]) -> tuple[list[dict[str, Any]], list[str], str]:
    preview = entry.get("preview") or {}
    preview_layers = preview.get("layers") or []
    current_layers = entry.get("current", {}).get("icon_layers") or []
    proposed_layers = entry.get("proposed", {}).get("icon_layers") or []
    render_mode = preview.get("render_mode")
    render_basis = preview.get("render_basis")
    notes: list[str] = []
    if render_mode == "from-preview-layers":
        if preview_layers:
            return preview_layers, notes, render_basis or "preview-layers"
        notes.append("preview requested preview.layers but none were available")
    elif render_mode == "from-proposed-layers":
        if proposed_layers:
            return proposed_layers, notes, render_basis or "proposed-layers"
        notes.append("preview requested proposed.icon_layers but none were available")
    elif render_mode == "from-current-layers":
        return current_layers, notes, render_basis or "current-layers"
    if preview_layers:
        return preview_layers, notes, "preview-layers"
    if proposed_layers and (
        render_mode in {"prefer-proposed", "proposed-fallback"} or render_basis == "proposed-layers"
    ):
        return proposed_layers, notes, "proposed-layers"
    if current_layers:
        basis = "current-fallback" if entry.get("icon_proposal_fidelity") != "unchanged" else "current-layers"
        return current_layers, notes, basis
    return current_layers, notes, "placeholder"


def review_slot_label(render_basis: str) -> str:
    mapping = {
        "proposed-layers": "Review Proposed",
        "preview-layers": "Review Preview",
        "current-fallback": "Review Current Fallback",
        "current-layers": "Review Current",
        "placeholder": "Review Placeholder",
    }
    return mapping.get(render_basis, "Review")


def scope_reason_label(reason: str) -> str:
    mapping = {
        "esir-source": "ESIR source file",
        "esir-mutation": "ESIR mutation file",
        "esir-prefix": "ESIR-prefixed prototype",
        "dependency-target": "dependency touchpoint target",
        "dependency-target-by-name": "dependency touchpoint name match",
        "dependency-owner": "dependency-owned asset",
        "scope-all-candidates": "all candidate recipes mode",
        "manual-scope-override": "manual scope override",
    }
    return mapping.get(reason, reason.replace("-", " "))


def summarize_applied_filters(selection: dict[str, Any] | None) -> str:
    if not isinstance(selection, dict):
        return "none"
    filters = selection.get("applied_filters") or {}
    parts: list[str] = []
    for key in (
        "status",
        "family",
        "prototype",
        "evidence_state",
        "icon_proposal_fidelity",
        "review_priority",
    ):
        values = filters.get(key) or []
        if values:
            parts.append(f"{key.replace('_', ' ')}={', '.join(str(value) for value in values)}")
    return "; ".join(parts) if parts else "none"


def provenance_state(render_result: str | None, external_source: bool) -> str:
    if render_result == "placeholder-no-icon":
        return "no-icon"
    if render_result == "placeholder-unresolved":
        return "unresolved"
    if render_result == "placeholder-decode-failure":
        return "decode-failure"
    if external_source:
        return "external-root"
    return "repo-local"


def combined_provenance_state(current_state: str, review_state: str) -> str:
    if current_state == review_state:
        return current_state
    return "mixed"


def patch_target_kind_label(kind: str) -> str:
    mapping = {
        "source-file": "source file",
        "mutation-only": "mutation file only",
        "source-and-mutation": "source and mutation files",
        "none": "not mapped",
    }
    return mapping.get(kind, kind.replace("-", " "))


def proposal_compare_state(entry: dict[str, Any]) -> str:
    fidelity = entry.get("icon_proposal_fidelity")
    if fidelity == "strategy-only":
        return "not-visualized"
    if fidelity == "concrete":
        current_layers = entry.get("current", {}).get("icon_layers") or []
        proposed_layers = entry.get("proposed", {}).get("icon_layers") or []
        return "changed" if layer_signature(current_layers) != layer_signature(proposed_layers) else "same"
    return "unchanged"


def rendered_compare_state(entry: dict[str, Any]) -> str:
    preview = entry.get("preview") or {}
    if (preview.get("review_render_result") or "").startswith("placeholder"):
        return "placeholder"
    if preview.get("layer_changed", preview.get("rendered_icon_changed")):
        return "changed"
    basis = preview.get("render_basis")
    if basis == "current-fallback":
        return "current-fallback"
    if basis == "current-layers":
        return "same-current"
    return "same"


def render_contact_sheet(entries: list[dict[str, Any]], card_assets: list[dict[str, Any]], output_path: Path) -> None:
    cols = 2
    rows = max(1, math.ceil(len(entries) / cols))
    sheet = Image.new("RGBA", (cols * CARD_WIDTH + 32, rows * CARD_HEIGHT + 32), (16, 18, 22, 255))
    draw = ImageDraw.Draw(sheet)
    title_font = ImageFont.load_default()
    text_font = ImageFont.load_default()
    for index, (entry, asset) in enumerate(zip(entries, card_assets)):
        col = index % cols
        row = index // cols
        x = 16 + col * CARD_WIDTH
        y = 16 + row * CARD_HEIGHT
        draw.rounded_rectangle(
            (x, y, x + CARD_WIDTH - 12, y + CARD_HEIGHT - 12),
            radius=18,
            fill=(28, 31, 36, 255),
            outline=(80, 91, 103, 255),
            width=2,
        )
        current_slot = Image.open(asset["current_slot_path"]).convert("RGBA")
        review_slot = Image.open(asset["review_slot_path"]).convert("RGBA")
        draw.text((x + 24, y + 16), "CURRENT", fill=(186, 194, 202, 255), font=text_font)
        review_label = review_slot_label((entry.get("preview") or {}).get("render_basis") or "").upper()
        draw.text((x + 132, y + 16), review_label, fill=(171, 208, 184, 255), font=text_font)
        sheet.alpha_composite(current_slot, dest=(x + 18, y + 34))
        sheet.alpha_composite(review_slot, dest=(x + 126, y + 34))
        text_x = x + 240
        draw.text((text_x, y + 18), entry["prototype_name"], fill=(232, 236, 240, 255), font=title_font)
        draw.text((text_x, y + 40), entry["display_name"], fill=(186, 194, 202, 255), font=text_font)
        draw.text((text_x, y + 64), f"Family: {entry['style_family']}", fill=(171, 208, 184, 255), font=text_font)
        draw.text((text_x, y + 84), f"Audit: {entry['status']}", fill=(215, 201, 150, 255), font=text_font)
        draw.text((text_x, y + 104), f"Layer Spec: {rendered_compare_state(entry)}", fill=(172, 186, 222, 255), font=text_font)
        draw.text((text_x, y + 124), f"Signal: {current_vs_proposed(entry, 'hide_from_signal_gui')}", fill=(172, 186, 222, 255), font=text_font)
        draw.text((text_x, y + 144), f"Subgroup: {entry.get('proposed', {}).get('subgroup') or '-'}", fill=(172, 186, 222, 255), font=text_font)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path)


def build_html(entries: list[dict[str, Any]], card_assets: list[dict[str, Any]], report_meta: dict[str, Any]) -> str:
    families = sorted({entry["style_family"] for entry in entries})
    statuses = sorted({entry["status"] for entry in entries})
    evidence_states = sorted({entry.get("evidence_state") or "-" for entry in entries})
    patch_target_kinds = sorted({entry.get("patch_target_kind") or "none" for entry in entries})
    scope_reasons = sorted(
        {
            reason
            for entry in entries
            for reason in (entry.get("scope_reason") or [])
            if reason
        }
    )
    proposal_fidelities = sorted({entry.get("icon_proposal_fidelity") or "-" for entry in entries})
    review_priorities = sorted({entry.get("review_priority") or "-" for entry in entries})
    render_bases = sorted({(entry.get("preview") or {}).get("render_basis") or "-" for entry in entries})
    current_render_results = sorted(
        {(entry.get("preview") or {}).get("current_render_result") or "-" for entry in entries}
    )
    review_render_results = sorted(
        {(entry.get("preview") or {}).get("review_render_result") or "-" for entry in entries}
    )
    proposal_compare_states = sorted({proposal_compare_state(entry) for entry in entries})
    rendered_compare_states = sorted({rendered_compare_state(entry) for entry in entries})
    counts = summarize_counts(entries)
    cards = []
    for entry, asset in zip(entries, card_assets):
        preview = entry.get("preview", {})
        entry_notes = entry.get("notes") or []
        notes = "<br>".join(html.escape(note) for note in (entry_notes or ["-"]))
        presets = ", ".join(entry.get("preset_tags") or []) or "-"
        current_sources = ", ".join(preview.get("current_resolved_sources") or []) or "-"
        review_sources = ", ".join(preview.get("review_resolved_sources") or []) or "-"
        rule_helpers = ", ".join(
            sorted(
                {
                    helper
                    for helper in (
                        item.get("helper")
                        for item in (entry.get("rule_evidence") or [])
                    )
                    if helper
                }
            )
        ) or "-"
        prototype_name = html.escape(entry["prototype_name"])
        display_name = html.escape(entry["display_name"])
        declaration_source_file = entry.get("declaration_source_file") or entry.get("source_file")
        primary_patch_file = entry.get("primary_patch_file")
        source_file = html.escape(declaration_source_file or "-")
        primary_patch_file_text = html.escape(primary_patch_file or "-")
        style_family = html.escape(entry["style_family"])
        status = html.escape(entry["status"])
        prototype_type = html.escape(entry.get("prototype_type") or "recipe")
        subgroup = html.escape(current_vs_proposed(entry, "subgroup"))
        order = html.escape(current_vs_proposed(entry, "order"))
        factoriopedia = html.escape(current_vs_proposed(entry, "hidden_in_factoriopedia"))
        factoriopedia_alt = html.escape(current_vs_proposed(entry, "factoriopedia_alternative"))
        player_crafting = html.escape(current_vs_proposed(entry, "hide_from_player_crafting"))
        signal_gui = html.escape(current_vs_proposed(entry, "hide_from_signal_gui"))
        review_mode = html.escape(preview.get("render_mode") or "-")
        render_basis = html.escape(preview.get("render_basis") or "-")
        layer_changed = bool(preview.get("layer_changed", preview.get("rendered_icon_changed")))
        mutation_mapped = bool(entry.get("source_mutation_files"))
        mutation_files = "<br>".join(
            html.escape(path) for path in (entry.get("source_mutation_files") or ["-"])
        )
        current_render_result = html.escape(preview.get("current_render_result") or "-")
        review_render_result = html.escape(preview.get("review_render_result") or "-")
        review_placeholder_reason = html.escape(preview.get("review_placeholder_reason") or "-")
        evidence_state = html.escape(entry.get("evidence_state") or "-")
        patch_target_kind = entry.get("patch_target_kind") or "none"
        patch_target_label = html.escape(patch_target_kind_label(patch_target_kind))
        icon_proposal_fidelity = html.escape(entry.get("icon_proposal_fidelity") or "-")
        icon_proposal_ready = html.escape(str(bool(entry.get("icon_proposal_ready"))).lower())
        icon_proposal_reason = html.escape(
            preview.get("proposal_reason") or entry.get("icon_proposal_reason") or "-"
        )
        review_priority = html.escape(entry.get("review_priority") or "-")
        review_slot = html.escape(review_slot_label(preview.get("render_basis") or ""))
        current_external_source = bool(preview.get("current_external_source"))
        review_external_source = bool(preview.get("review_external_source"))
        uses_external_source = current_external_source or review_external_source
        current_provenance = provenance_state(preview.get("current_render_result"), current_external_source)
        review_provenance = provenance_state(preview.get("review_render_result"), review_external_source)
        current_provenance_label = f"current:{current_provenance}"
        review_provenance_label = f"review:{review_provenance}"
        combined_provenance_label = combined_provenance_state(current_provenance, review_provenance)
        rendered_compare = html.escape(rendered_compare_state(entry))
        proposal_compare = html.escape(proposal_compare_state(entry))
        sort_changed = any(
            entry.get("current", {}).get(key) != entry.get("proposed", {}).get(key)
            for key in ("subgroup", "order")
        )
        visibility_changed = any(
            entry.get("current", {}).get(key) != entry.get("proposed", {}).get(key)
            for key in (
                "hidden_in_factoriopedia",
                "factoriopedia_alternative",
                "hide_from_player_crafting",
                "hide_from_signal_gui",
            )
        )
        placeholder_only = (preview.get("review_render_result") or "").startswith("placeholder")
        search_blob = html.escape(
            f"{entry['prototype_name']} {entry['display_name']} {entry.get('prototype_type') or ''} {declaration_source_file or ''} {primary_patch_file or ''} {' '.join(entry.get('owner_mods') or [])} {' '.join(entry.get('scope_reason') or [])}",
            quote=True,
        )
        scope_reason = html.escape(
            ", ".join(scope_reason_label(reason) for reason in (entry.get("scope_reason") or [])) or "-"
        )
        owner_mods = html.escape(", ".join(entry.get("owner_mods") or ["-"]))
        scope_dependency_mods = html.escape(", ".join(entry.get("scope_dependency_mods") or ["-"]))
        scope_reason_data = html.escape(" ".join(entry.get("scope_reason") or []), quote=True)
        patch_target_line = ""
        if patch_target_kind != "none":
            patch_target_line = f'<p><strong>Patch Target:</strong> {patch_target_label}</p>'
        elif entry.get("review_priority") == "source-map-needed":
            patch_target_line = "<p><strong>Patch Target:</strong> missing patch map</p>"
        cards.append(
            f"""
            <article class="card" data-family="{html.escape(entry['style_family'], quote=True)}" data-status="{html.escape(entry['status'], quote=True)}" data-name="{search_blob}" data-scope-reason="{scope_reason_data}" data-icon-changed="{str(layer_changed).lower()}" data-layer-changed="{str(layer_changed).lower()}" data-rendered-compare="{html.escape(rendered_compare_state(entry), quote=True)}" data-proposal-compare="{html.escape(proposal_compare_state(entry), quote=True)}" data-sort-changed="{str(sort_changed).lower()}" data-visibility-changed="{str(visibility_changed).lower()}" data-has-notes="{str(bool(entry_notes)).lower()}" data-placeholder="{str(placeholder_only).lower()}" data-mutation-mapped="{str(mutation_mapped).lower()}" data-evidence-state="{html.escape(entry.get('evidence_state') or '-', quote=True)}" data-icon-proposal-fidelity="{html.escape(entry.get('icon_proposal_fidelity') or '-', quote=True)}" data-review-priority="{html.escape(entry.get('review_priority') or '-', quote=True)}" data-patch-target-kind="{html.escape(patch_target_kind, quote=True)}" data-render-basis="{html.escape(preview.get('render_basis') or '-', quote=True)}" data-proposal-ready="{html.escape(str(bool(entry.get('icon_proposal_ready'))).lower(), quote=True)}" data-external-source="{str(uses_external_source).lower()}" data-current-external-source="{str(current_external_source).lower()}" data-review-external-source="{str(review_external_source).lower()}" data-current-render-result="{html.escape(preview.get('current_render_result') or '-', quote=True)}" data-review-render-result="{html.escape(preview.get('review_render_result') or '-', quote=True)}">
              <div class="preview-pair">
                <div class="slot-block">
                  <span class="slot-label">Current</span>
                  <img class="slot" src="{asset['current_slot_data_uri']}" alt="{prototype_name} current icon preview" />
                </div>
                <div class="slot-block {html.escape((preview.get('render_basis') or '').replace('_', '-'))}">
                  <span class="slot-label">{review_slot}</span>
                  <img class="slot" src="{asset['review_slot_data_uri']}" alt="{prototype_name} review icon preview" />
                </div>
              </div>
              <div class="meta">
                <h2>{prototype_name}</h2>
                <p class="display-name">{display_name}</p>
                <p class="badge-row"><span class="badge">{review_priority}</span> <span class="badge">{evidence_state}</span> <span class="badge">{icon_proposal_fidelity}</span> <span class="badge">{html.escape(preview.get("render_basis") or "-")}</span> <span class="badge">{current_provenance_label}</span> <span class="badge">{review_provenance_label}</span></p>
                <p><strong>Prototype Type:</strong> {prototype_type}</p>
                <p><strong>Declaration Source:</strong> {source_file}</p>
                <p><strong>Primary Patch File:</strong> {primary_patch_file_text}</p>
                <p><strong>Included Because:</strong> {scope_reason}</p>
                <p><strong>Owner Mods:</strong> {owner_mods}</p>
                <p><strong>Dependency Mods:</strong> {scope_dependency_mods}</p>
                <p><strong>Family:</strong> {style_family}</p>
                <p><strong>Preset Tags:</strong> {html.escape(presets)}</p>
                <p><strong>Audit Status:</strong> {status}</p>
                <p><strong>Review Priority:</strong> {review_priority}</p>
                {patch_target_line}
                <p><strong>Evidence:</strong> {evidence_state}</p>
                <p><strong>Layer Spec Compare:</strong> {rendered_compare}</p>
                <p><strong>Proposal Compare:</strong> {proposal_compare}</p>
                <p><strong>Icon Proposal:</strong> {icon_proposal_fidelity}</p>
                <p><strong>Icon Proposal Ready:</strong> {icon_proposal_ready}</p>
                <p><strong>Icon Proposal Reason:</strong> {icon_proposal_reason}</p>
                <p><strong>Review Mode:</strong> {review_mode}</p>
                <p><strong>Review Basis:</strong> {render_basis}</p>
                <p><strong>Provenance:</strong> {combined_provenance_label}</p>
                <p><strong>Current Render:</strong> {current_render_result}</p>
                <p><strong>Review Render:</strong> {review_render_result}</p>
                <p><strong>Placeholder Reason:</strong> {review_placeholder_reason}</p>
                <p><strong>Subgroup:</strong> {subgroup}</p>
                <p><strong>Order:</strong> {order}</p>
                <p><strong>Factoriopedia:</strong> {factoriopedia}</p>
                <p><strong>Factoriopedia Redirect:</strong> {factoriopedia_alt}</p>
                <p><strong>Player Crafting:</strong> {player_crafting}</p>
                <p><strong>Signal GUI:</strong> {signal_gui}</p>
                <p><strong>Mutation Files:</strong><br>{mutation_files}</p>
                <p><strong>Rule Helpers:</strong> {html.escape(rule_helpers)}</p>
                <p><strong>Current Sources:</strong> {html.escape(current_sources)}</p>
                <p><strong>Review Sources:</strong> {html.escape(review_sources)}</p>
                <p><strong>Notes:</strong><br>{notes}</p>
              </div>
            </article>
            """
        )
    family_options = "".join(f'<option value="{family}">{family}</option>' for family in families)
    status_options = "".join(f'<option value="{status}">{status}</option>' for status in statuses)
    evidence_options = "".join(
        f'<option value="{value}">{value}</option>' for value in evidence_states
    )
    patch_target_options = "".join(
        f'<option value="{value}">{html.escape(patch_target_kind_label(value))}</option>' for value in patch_target_kinds
    )
    scope_reason_options = "".join(
        f'<option value="{html.escape(value, quote=True)}">{html.escape(scope_reason_label(value))}</option>'
        for value in scope_reasons
    )
    fidelity_options = "".join(
        f'<option value="{value}">{value}</option>' for value in proposal_fidelities
    )
    priority_options = "".join(
        f'<option value="{value}">{value}</option>' for value in review_priorities
    )
    basis_options = "".join(
        f'<option value="{value}">{value}</option>' for value in render_bases
    )
    current_render_result_options = "".join(
        f'<option value="{value}">{value}</option>' for value in current_render_results
    )
    review_render_result_options = "".join(
        f'<option value="{value}">{value}</option>' for value in review_render_results
    )
    rendered_compare_options = "".join(
        f'<option value="{value}">{value}</option>' for value in rendered_compare_states
    )
    proposal_compare_options = "".join(
        f'<option value="{value}">{value}</option>' for value in proposal_compare_states
    )
    filtered_examples = report_meta.get("scope_filtered_examples") or []
    filtered_examples_text = ", ".join(
        example.get("prototype_name") or "?"
        for example in filtered_examples[:5]
        if isinstance(example, dict)
    ) or "-"
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>ESIR Recipe Icon Report</title>
  <style>
    :root {{
      color-scheme: dark;
      --bg: #101217;
      --panel: #1b1f26;
      --panel-2: #252b35;
      --line: #55606d;
      --text: #e7ebef;
      --muted: #aab4c0;
      --accent: #9dc6a8;
      --warn: #d8c790;
      font-family: "Segoe UI", "Trebuchet MS", sans-serif;
    }}
    body {{ margin: 0; background: radial-gradient(circle at top, #18202b, var(--bg) 55%); color: var(--text); }}
    header {{ padding: 24px 28px 12px; }}
    h1 {{ margin: 0 0 8px; font-size: 28px; }}
    .controls {{ display: flex; gap: 12px; flex-wrap: wrap; padding: 0 28px 18px; }}
    .controls input, .controls select {{
      background: var(--panel);
      color: var(--text);
      border: 1px solid var(--line);
      border-radius: 10px;
      padding: 10px 12px;
    }}
    .grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(660px, 1fr)); gap: 18px; padding: 0 28px 32px; }}
    .card {{
      display: grid;
      grid-template-columns: 220px 1fr;
      gap: 16px;
      padding: 18px;
      border-radius: 18px;
      background: linear-gradient(180deg, rgba(37,43,53,0.95), rgba(23,27,34,0.95));
      border: 1px solid rgba(105,119,133,0.55);
      box-shadow: 0 14px 28px rgba(0, 0, 0, 0.24);
    }}
    .preview-pair {{ display: grid; grid-template-columns: repeat(2, 96px); gap: 12px; align-content: start; }}
    .slot-block {{ display: grid; gap: 6px; justify-items: center; }}
    .slot-label {{ color: var(--muted); font-size: 12px; letter-spacing: 0.08em; text-transform: uppercase; }}
    .slot-block.current-fallback .slot-label, .slot-block.placeholder .slot-label {{ color: var(--warn); }}
    .slot {{ width: 96px; height: 96px; }}
    .meta h2 {{ margin: 0 0 4px; font-size: 20px; }}
    .display-name {{ margin: 0 0 12px; color: var(--accent); }}
    .meta p {{ margin: 6px 0; color: var(--muted); line-height: 1.35; }}
    .badge-row {{ display: flex; gap: 6px; flex-wrap: wrap; margin: 0 0 10px; }}
    .badge {{ display: inline-block; padding: 3px 8px; border-radius: 999px; background: rgba(85, 96, 109, 0.35); color: var(--text); font-size: 12px; }}
    strong {{ color: var(--text); }}
  </style>
</head>
<body>
  <header>
    <h1>ESIR Recipe Icon Batch Report</h1>
    <p>Out-of-game sanity check for prototype names, display names, current vs review icon previews, and before/after behavior data.</p>
    <p><strong>Renderer:</strong> v{report_meta['renderer_version']} | <strong>Generated:</strong> {html.escape(report_meta['generated_at_utc'])} UTC</p>
    <p><strong>Audit Scope Mode:</strong> {html.escape(report_meta.get('scope_mode') or '-')} | <strong>Audit Candidates:</strong> {report_meta.get('scope_candidate_entries', '-')} | <strong>Audit Excluded:</strong> {report_meta.get('scope_filtered_out', '-')}</p>
    <p><strong>Batch Selection:</strong> {report_meta.get('selection_entries_after_filters', '-')} shown from {report_meta.get('selection_entries_before_filters', '-')} manifest entries | <strong>Extra Entries Added:</strong> {report_meta.get('selection_extra_entries_added', '-')}</p>
    <p><strong>Batch Filters:</strong> {html.escape(report_meta.get('selection_applied_filters_text') or 'none')}</p>
    <p><strong>Audit Excluded Examples:</strong> {html.escape(filtered_examples_text)}</p>
    <p><strong>Entries:</strong> {counts['entries']} | <strong>Audit Manual Review:</strong> {counts['manual_review_needed']} | <strong>Heuristic Status:</strong> {counts['heuristic_status']} | <strong>Heuristic Evidence:</strong> {counts['heuristic_evidence']} | <strong>Strategy Only Icons:</strong> {counts['strategy_only_icon_proposals']} | <strong>Concrete Icon Proposals:</strong> {counts['concrete_icon_proposals']} | <strong>Patch-Ready Icons:</strong> {counts['patch_ready_icons']} | <strong>Entries Missing Patch Map:</strong> {counts['source_map_needed']} | <strong>Icon Plans Needed:</strong> {counts['icon_plan_needed']} | <strong>Behavior Ready:</strong> {counts['behavior_ready']} | <strong>Selected Layers Changed:</strong> {counts['layer_changed']} | <strong>Mutation Mapped:</strong> {counts['mutation_mapped']} | <strong>Either-Side External:</strong> {counts['external_source_entries']} | <strong>Review External:</strong> {counts['review_external_source_entries']} | <strong>Review Placeholders:</strong> {counts['review_placeholder_entries']}</p>
  </header>
  <section class="controls">
    <input id="search" type="search" placeholder="Filter by prototype or display name">
    <select id="family">
      <option value="">All families</option>
      {family_options}
    </select>
    <select id="status">
      <option value="">All statuses</option>
      {status_options}
    </select>
    <select id="evidence-state">
      <option value="">All evidence</option>
      {evidence_options}
    </select>
    <select id="patch-target-kind">
      <option value="">All patch targets</option>
      {patch_target_options}
    </select>
    <select id="scope-reason">
      <option value="">All inclusion reasons</option>
      {scope_reason_options}
    </select>
    <select id="icon-proposal-fidelity">
      <option value="">All icon proposals</option>
      {fidelity_options}
    </select>
    <select id="review-priority">
      <option value="">All priorities</option>
      {priority_options}
    </select>
    <select id="render-basis">
      <option value="">All review bases</option>
      {basis_options}
    </select>
    <select id="current-render-result">
      <option value="">All current renders</option>
      {current_render_result_options}
    </select>
    <select id="review-render-result">
      <option value="">All review renders</option>
      {review_render_result_options}
    </select>
    <select id="rendered-compare">
      <option value="">All layer-spec compare</option>
      {rendered_compare_options}
    </select>
    <select id="proposal-compare">
      <option value="">All proposal compare</option>
      {proposal_compare_options}
    </select>
    <label><input id="icon-changed" type="checkbox"> Selected layers changed</label>
    <label><input id="sort-changed" type="checkbox"> Sort changed</label>
    <label><input id="visibility-changed" type="checkbox"> Visibility changed</label>
    <label><input id="mutation-mapped" type="checkbox"> Mutation mapped</label>
    <label><input id="proposal-ready" type="checkbox"> Icon proposal ready</label>
    <label><input id="external-source" type="checkbox"> Either-side external</label>
    <label><input id="review-external-source" type="checkbox"> Review external</label>
    <label><input id="has-notes" type="checkbox"> Has notes</label>
    <label><input id="placeholder-only" type="checkbox"> Placeholder only</label>
  </section>
  <main class="grid" id="grid">
    {''.join(cards)}
  </main>
  <script>
    const search = document.getElementById('search');
    const family = document.getElementById('family');
    const status = document.getElementById('status');
    const evidenceState = document.getElementById('evidence-state');
    const patchTargetKind = document.getElementById('patch-target-kind');
    const scopeReason = document.getElementById('scope-reason');
    const iconProposalFidelity = document.getElementById('icon-proposal-fidelity');
    const reviewPriority = document.getElementById('review-priority');
    const renderBasis = document.getElementById('render-basis');
    const currentRenderResult = document.getElementById('current-render-result');
    const reviewRenderResult = document.getElementById('review-render-result');
    const renderedCompare = document.getElementById('rendered-compare');
    const proposalCompare = document.getElementById('proposal-compare');
    const iconChanged = document.getElementById('icon-changed');
    const sortChanged = document.getElementById('sort-changed');
    const visibilityChanged = document.getElementById('visibility-changed');
    const mutationMapped = document.getElementById('mutation-mapped');
    const proposalReady = document.getElementById('proposal-ready');
    const externalSource = document.getElementById('external-source');
    const reviewExternalSource = document.getElementById('review-external-source');
    const hasNotes = document.getElementById('has-notes');
    const placeholderOnly = document.getElementById('placeholder-only');
    const cards = Array.from(document.querySelectorAll('.card'));
    function applyFilters() {{
      const q = search.value.trim().toLowerCase();
      const fam = family.value;
      const st = status.value;
      const evidence = evidenceState.value;
      const patchTarget = patchTargetKind.value;
      const scope = scopeReason.value;
      const fidelity = iconProposalFidelity.value;
      const priority = reviewPriority.value;
      const basis = renderBasis.value;
      const currentRender = currentRenderResult.value;
      const reviewRender = reviewRenderResult.value;
      const renderedCompareValue = renderedCompare.value;
      const proposalCompareValue = proposalCompare.value;
      const requireIconChanged = iconChanged.checked;
      const requireSortChanged = sortChanged.checked;
      const requireVisibilityChanged = visibilityChanged.checked;
      const requireMutationMapped = mutationMapped.checked;
      const requireProposalReady = proposalReady.checked;
      const requireExternalSource = externalSource.checked;
      const requireReviewExternalSource = reviewExternalSource.checked;
      const requireNotes = hasNotes.checked;
      const requirePlaceholderOnly = placeholderOnly.checked;
      for (const card of cards) {{
        const matchesSearch = !q || card.dataset.name.toLowerCase().includes(q);
        const matchesFamily = !fam || card.dataset.family === fam;
        const matchesStatus = !st || card.dataset.status === st;
        const matchesEvidence = !evidence || card.dataset.evidenceState === evidence;
        const matchesPatchTarget = !patchTarget || card.dataset.patchTargetKind === patchTarget;
        const matchesScope = !scope || card.dataset.scopeReason.split(' ').includes(scope);
        const matchesFidelity = !fidelity || card.dataset.iconProposalFidelity === fidelity;
        const matchesPriority = !priority || card.dataset.reviewPriority === priority;
        const matchesBasis = !basis || card.dataset.renderBasis === basis;
        const matchesCurrentRender = !currentRender || card.dataset.currentRenderResult === currentRender;
        const matchesReviewRender = !reviewRender || card.dataset.reviewRenderResult === reviewRender;
        const matchesRenderedCompare = !renderedCompareValue || card.dataset.renderedCompare === renderedCompareValue;
        const matchesProposalCompare = !proposalCompareValue || card.dataset.proposalCompare === proposalCompareValue;
        const matchesIconChanged = !requireIconChanged || card.dataset.iconChanged === 'true';
        const matchesSortChanged = !requireSortChanged || card.dataset.sortChanged === 'true';
        const matchesVisibilityChanged = !requireVisibilityChanged || card.dataset.visibilityChanged === 'true';
        const matchesMutationMapped = !requireMutationMapped || card.dataset.mutationMapped === 'true';
        const matchesProposalReady = !requireProposalReady || card.dataset.proposalReady === 'true';
        const matchesExternalSource = !requireExternalSource || card.dataset.externalSource === 'true';
        const matchesReviewExternalSource = !requireReviewExternalSource || card.dataset.reviewExternalSource === 'true';
        const matchesNotes = !requireNotes || card.dataset.hasNotes === 'true';
        const matchesPlaceholderOnly = !requirePlaceholderOnly || card.dataset.placeholder === 'true';
        card.style.display = matchesSearch && matchesFamily && matchesStatus && matchesEvidence && matchesPatchTarget && matchesScope && matchesFidelity && matchesPriority && matchesBasis && matchesCurrentRender && matchesReviewRender && matchesRenderedCompare && matchesProposalCompare && matchesIconChanged && matchesSortChanged && matchesVisibilityChanged && matchesMutationMapped && matchesProposalReady && matchesExternalSource && matchesReviewExternalSource && matchesNotes && matchesPlaceholderOnly ? 'grid' : 'none';
      }}
    }}
    search.addEventListener('input', applyFilters);
    family.addEventListener('change', applyFilters);
    status.addEventListener('change', applyFilters);
    evidenceState.addEventListener('change', applyFilters);
    patchTargetKind.addEventListener('change', applyFilters);
    scopeReason.addEventListener('change', applyFilters);
    iconProposalFidelity.addEventListener('change', applyFilters);
    reviewPriority.addEventListener('change', applyFilters);
    renderBasis.addEventListener('change', applyFilters);
    currentRenderResult.addEventListener('change', applyFilters);
    reviewRenderResult.addEventListener('change', applyFilters);
    renderedCompare.addEventListener('change', applyFilters);
    proposalCompare.addEventListener('change', applyFilters);
    iconChanged.addEventListener('change', applyFilters);
    sortChanged.addEventListener('change', applyFilters);
    visibilityChanged.addEventListener('change', applyFilters);
    mutationMapped.addEventListener('change', applyFilters);
    proposalReady.addEventListener('change', applyFilters);
    externalSource.addEventListener('change', applyFilters);
    reviewExternalSource.addEventListener('change', applyFilters);
    hasNotes.addEventListener('change', applyFilters);
    placeholderOnly.addEventListener('change', applyFilters);
  </script>
</body>
</html>
"""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True, help="Batch manifest JSON.")
    parser.add_argument("--output-dir", type=Path, required=True, help="Directory for the report outputs.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    entries = manifest.get("entries", [])
    repo_root = Path(manifest.get("repo_root") or os.getcwd()).resolve()
    generated_at_utc = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    resolver = AssetResolver(repo_root)
    output_dir = args.output_dir.resolve()
    assets_dir = output_dir / "assets"
    assets_dir.mkdir(parents=True, exist_ok=True)
    card_assets: list[dict[str, Any]] = []
    rendered_entries: list[dict[str, Any]] = []
    for entry in entries:
        current_layers = entry.get("current", {}).get("icon_layers") or []
        current_render = render_preview_variant(current_layers, resolver)
        render_layers, selection_notes, render_basis = select_layers_for_render(entry)
        review_render = render_preview_variant(render_layers, resolver, selection_notes)
        name = safe_name(f"{entry.get('prototype_type') or 'prototype'}-{entry['prototype_name']}")
        current_icon_path = assets_dir / f"{name}-current.png"
        current_slot_path = assets_dir / f"{name}-current-slot.png"
        review_icon_path = assets_dir / f"{name}-review.png"
        review_slot_path = assets_dir / f"{name}-review-slot.png"
        current_render.icon_image.save(current_icon_path)
        current_render.slot_image.save(current_slot_path)
        review_render.icon_image.save(review_icon_path)
        review_render.slot_image.save(review_slot_path)
        card_assets.append(
            {
                "current_icon_path": current_icon_path,
                "current_slot_path": current_slot_path,
                "current_slot_data_uri": image_to_data_uri(current_render.slot_image),
                "review_icon_path": review_icon_path,
                "review_slot_path": review_slot_path,
                "review_slot_data_uri": image_to_data_uri(review_render.slot_image),
            }
        )
        enriched = dict(entry)
        enriched.setdefault("notes", [])
        for note in review_render.notes:
            if note not in enriched["notes"]:
                enriched["notes"].append(note)
        enriched.setdefault("preview", {})
        enriched["preview"]["current_flattened_icon_path"] = str(current_icon_path)
        enriched["preview"]["current_preview_slot_path"] = str(current_slot_path)
        enriched["preview"]["current_resolved_sources"] = current_render.source_labels
        enriched["preview"]["current_render_notes"] = current_render.notes
        enriched["preview"]["current_render_result"] = current_render.render_result
        enriched["preview"]["current_placeholder_reason"] = current_render.placeholder_reason
        enriched["preview"]["current_external_source"] = any(
            source and not source.startswith("repo-local:") for source in current_render.source_labels
        )
        enriched["preview"]["review_flattened_icon_path"] = str(review_icon_path)
        enriched["preview"]["review_preview_slot_path"] = str(review_slot_path)
        enriched["preview"]["review_resolved_sources"] = review_render.source_labels
        enriched["preview"]["review_render_notes"] = review_render.notes
        enriched["preview"]["review_render_result"] = review_render.render_result
        enriched["preview"]["review_placeholder_reason"] = review_render.placeholder_reason
        enriched["preview"]["review_external_source"] = any(
            source and not source.startswith("repo-local:") for source in review_render.source_labels
        )
        enriched["preview"]["render_basis"] = render_basis
        enriched["preview"]["proposal_reason"] = (
            enriched["preview"].get("proposal_reason") or enriched.get("icon_proposal_reason")
        )
        enriched["preview"]["icon_changed"] = layer_signature(current_layers) != layer_signature(render_layers)
        enriched["preview"]["layer_changed"] = enriched["preview"]["icon_changed"]
        enriched["preview"]["rendered_icon_changed"] = enriched["preview"]["icon_changed"]
        enriched["preview"]["external_source"] = bool(
            enriched["preview"]["current_external_source"] or enriched["preview"]["review_external_source"]
        )
        enriched["preview"]["current_provenance"] = provenance_state(
            enriched["preview"].get("current_render_result"),
            bool(enriched["preview"].get("current_external_source")),
        )
        enriched["preview"]["review_provenance"] = provenance_state(
            enriched["preview"].get("review_render_result"),
            bool(enriched["preview"].get("review_external_source")),
        )
        enriched["preview"]["combined_provenance"] = combined_provenance_state(
            enriched["preview"]["current_provenance"],
            enriched["preview"]["review_provenance"],
        )
        enriched["preview"]["rendered_compare_state"] = rendered_compare_state(enriched)
        enriched["preview"]["proposal_compare_state"] = proposal_compare_state(enriched)
        enriched["preview"]["flattened_icon_path"] = str(review_icon_path)
        enriched["preview"]["preview_slot_path"] = str(review_slot_path)
        enriched["preview"]["resolved_sources"] = review_render.source_labels
        enriched["scope_reason_labels"] = [
            scope_reason_label(reason) for reason in (enriched.get("scope_reason") or [])
        ]
        rendered_entries.append(enriched)
    report_meta = {
        "renderer_version": RENDERER_VERSION,
        "generated_at_utc": generated_at_utc,
        "scope_mode": (manifest.get("scope") or {}).get("mode"),
        "scope_candidate_entries": (manifest.get("scope") or {}).get("candidate_entries_before_scope"),
        "scope_filtered_out": (manifest.get("scope") or {}).get("filtered_out"),
        "scope_filtered_examples": (manifest.get("scope") or {}).get("filtered_examples") or [],
        "selection_entries_before_filters": (manifest.get("selection") or {}).get("entries_before_batch_filters"),
        "selection_entries_after_filters": (manifest.get("selection") or {}).get("entries_after_batch_filters"),
        "selection_extra_entries_added": (manifest.get("selection") or {}).get("extra_entries_added"),
        "selection_applied_filters_text": summarize_applied_filters(manifest.get("selection")),
    }
    report_json = {
        "manifest_version": manifest.get("manifest_version"),
        "repo_root": str(repo_root),
        "audit_path": manifest.get("audit_path"),
        "extra_manifests": manifest.get("extra_manifests"),
        "scope": manifest.get("scope"),
        "selection": manifest.get("selection"),
        **report_meta,
        "counts": summarize_counts(rendered_entries),
        "entries": rendered_entries,
    }
    write_json(output_dir / "report.json", report_json)
    (output_dir / "report.html").write_text(build_html(rendered_entries, card_assets, report_meta), encoding="utf-8")
    render_contact_sheet(rendered_entries, card_assets, output_dir / "report-sheet.png")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

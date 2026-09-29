"""Read-only structural coverage audit for ESIR conceptual blueprints.

The dependency graph is deliberately conservative: it includes conditional local
imports, not just branches enabled by a workstation's installed mod list. Lua is
tokenized for comments/strings/imports, never evaluated. Semantic review remains
the responsibility of the model's editor.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from dataclasses import dataclass
import json
from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit

PACK = "exotic-space-industries-remembrance"
MODEL_ROOT = ".codex/esir/blueprints"
LONG_OPEN = re.compile(r"\[(=*)\[")
LINK = re.compile(r"\[[^\]\n]*\]\((<?[^\s)]+>?)\)")
ANCHOR = re.compile(r'<a\s+id=["\']([a-zA-Z0-9_-]+)["\']\s*>\s*</a>')


@dataclass(frozen=True)
class Token:
    kind: str
    value: str
    start: int
    end: int
    line: int


def lex_lua(text: str) -> list[Token]:
    """Retain raw token text and positions; comments are separate token kinds."""
    result = []
    i, line = 0, 1
    while i < len(text):
        start, start_line = i, line
        if text[i].isspace():
            line += text[i] == "\n"
            i += 1
            continue
        kind = "symbol"
        if text.startswith("--", i):
            kind = "comment"
            bracket = LONG_OPEN.match(text, i + 2)
            if bracket:
                close = "]" + bracket[1] + "]"
                end = text.find(close, bracket.end())
                if end < 0:
                    raise ValueError(f"Unterminated long comment at line {line}")
                i = end + len(close)
            else:
                end = text.find("\n", i)
                i = len(text) if end < 0 else end
        elif text[i] in "\"'":
            kind, quote = "string", text[i]
            i += 1
            while i < len(text):
                if text[i] == "\\":
                    i += 2
                elif text[i] == quote:
                    i += 1
                    break
                else:
                    i += 1
            else:
                raise ValueError(f"Unterminated quoted string at line {line}")
        elif (bracket := LONG_OPEN.match(text, i)):
            kind = "string"
            close = "]" + bracket[1] + "]"
            end = text.find(close, bracket.end())
            if end < 0:
                raise ValueError(f"Unterminated long string at line {line}")
            i = end + len(close)
        elif text[i].isalpha() or text[i] == "_":
            kind = "identifier"
            i += 1
            while i < len(text) and (text[i].isalnum() or text[i] == "_"):
                i += 1
        else:
            i += 1
        value = text[start:i]
        result.append(Token(kind, value, start, i, start_line))
        line += value.count("\n")
    return result


def executable_tokens(text: str) -> list[tuple[str, str]]:
    """Useful for proving comment-only edits against a starting worktree."""
    return [(t.kind, t.value) for t in lex_lua(text) if t.kind != "comment"]


def string_value(raw: str) -> str:
    if (bracket := LONG_OPEN.match(raw)):
        value = raw[bracket.end():-(len(bracket[1]) + 2)]
        return value[1:] if value.startswith("\n") else value
    value = raw[1:-1]
    escapes = {"n": "\n", "r": "\r", "t": "\t", "a": "\a", "b": "\b", "f": "\f", "v": "\v"}
    def replace(match: re.Match) -> str:
        item = match[1]
        if item.isdigit():
            return chr(int(item))
        if item.startswith("x") and len(item) == 3:
            return chr(int(item[1:], 16))
        if item.startswith("z"):
            return ""
        return escapes.get(item, item)
    return re.sub(r"\\(\d{1,3}|x[0-9a-fA-F]{2}|z\s*|.)", replace, value, flags=re.S)


def code_markers(tokens: list[Token], label: str) -> list[tuple[int, str]]:
    pattern = re.compile(r"^--\s*" + re.escape(label) + r":\s*(.*?)\s*$")
    return [(t.line, m[1]) for t in tokens if t.kind == "comment" and (m := pattern.fullmatch(t.value))]


def markdown_lines(text: str) -> list[tuple[int, str]]:
    """Ignore fenced examples so templates/examples cannot establish ownership."""
    text = re.sub(r"<!--.*?-->", lambda m: "\n" * m[0].count("\n"), text, flags=re.S)
    lines, fence = [], None
    for number, line in enumerate(text.splitlines(), 1):
        marker = re.match(r"^\s*(`{3,}|~{3,})", line)
        if marker:
            if fence is None:
                fence = marker[1]
            elif marker[1][0] == fence[0] and len(marker[1]) >= len(fence):
                fence = None
            continue
        if fence is None:
            lines.append((number, line))
    if fence:
        raise ValueError("Unclosed Markdown fence")
    return lines


def audit(repo_root: Path) -> dict:
    root = repo_root.resolve()
    findings: list[dict] = []
    tokens_by_path: dict[str, list[Token]] = {}

    def issue(code: str, file: str, line: int = 0, target: str = "", message: str = "") -> None:
        findings.append(dict(code=code, file=file, line=line, target=target, message=message))

    def relative(path: Path) -> str:
        return path.resolve().relative_to(root).as_posix()

    def target_path(base: Path, target: str, file: str, line: int) -> tuple[str | None, str]:
        parsed = urlsplit(unquote(target.strip("<>")))
        if parsed.scheme or parsed.netloc:
            issue("nonlocal-target", file, line, target, "Ownership and blueprint targets must be local.")
            return None, ""
        candidate = ((base / parsed.path.replace("\\", "/")) if parsed.path else (root / file)).resolve()
        try:
            name = relative(candidate)
        except ValueError:
            issue("outside-repo", file, line, target, "Target escapes the repository.")
            return None, parsed.fragment
        if not candidate.is_file():
            issue("missing-target", file, line, target, "Target file does not exist.")
        return name, parsed.fragment

    def read_tokens(name: str) -> list[Token]:
        if name not in tokens_by_path:
            try:
                tokens_by_path[name] = lex_lua((root / name).read_text(encoding="utf-8-sig"))
            except (OSError, UnicodeError, ValueError) as error:
                issue("lua-scan-failed", name, message=str(error))
                tokens_by_path[name] = []
        return tokens_by_path[name]

    mods = {}
    for info in sorted(root.glob("*/info.json")):
        try:
            mods[json.loads(info.read_text(encoding="utf-8-sig"))["name"]] = info.parent
        except (OSError, ValueError, KeyError) as error:
            issue("mod-info-invalid", relative(info), message=str(error))
    mods.setdefault(PACK, root / PACK)

    def resolve_require(name: str, caller: str, line: int) -> str | None:
        name = name.replace("\\", "/")
        prefixed = re.match(r"^__([^/]+?)__(?:[/.])(.*)$", name)
        if prefixed:
            mod_name, tail = prefixed.groups()
            if mod_name not in mods:
                return None  # Engine or external mod boundary.
            bases, name = [mods[mod_name]], tail
        elif name in {"util", "serpent", "mod-gui"}:
            return None
        else:
            owner = next((p for p in mods.values() if (root / caller).is_relative_to(p)), root / PACK)
            bases = [owner, (root / caller).parent]
        stem = name[:-4] if name.endswith(".lua") else name
        variants = [stem]
        if "/" not in stem:
            variants.append(stem.replace(".", "/"))
        for base in bases:
            for variant in dict.fromkeys(variants):
                candidate = (base / (variant + ".lua")).resolve()
                try:
                    rel = relative(candidate)
                except ValueError:
                    issue("outside-repo-import", caller, line, name, "Local import escapes the repository.")
                    return None
                if candidate.is_file():
                    return rel
        issue("unresolved-local-import", caller, line, name, "Cannot resolve local dependency.")
        return None

    def imports(name: str) -> list[str]:
        all_tokens = read_tokens(name)
        code = [t for t in all_tokens if t.kind != "comment"]
        mappings = dict(code_markers(all_tokens, "blueprint-requires"))
        used, result = set(), []
        for i, token in enumerate(code):
            if token.value != "require" or token.kind != "identifier":
                continue
            if i and code[i - 1].value in {".", ":", "function"}:
                continue
            following = code[i + 1] if i + 1 < len(code) else None
            names = None
            protected_call = i >= 2 and code[i - 1].value == "(" and code[i - 2].value in {"pcall", "xpcall"}
            if protected_call:
                argument = i + (2 if code[i - 2].value == "pcall" else 4)
                # xpcall's simple error-handler expression occupies one token;
                # complex expressions require a bounded declaration.
                if (argument + 1 < len(code) and code[argument - 1].value == ","
                        and code[argument].kind == "string" and code[argument + 1].value == ")"):
                    names = [string_value(code[argument].value)]
            elif following is not None and following.kind == "string":
                names = [string_value(following.value)]
            elif following is not None and following.value == "(":
                if i + 3 < len(code) and code[i + 2].kind == "string" and code[i + 3].value == ")":
                    names = [string_value(code[i + 2].value)]
            # Other require references (including aliases) must be explicitly
            # bounded rather than silently disappearing from the source graph.
            if names is None:
                mapping_line = token.line - 1
                if mapping_line in mappings:
                    used.add(mapping_line)
                    try:
                        names = json.loads(mappings[mapping_line])
                        if not isinstance(names, list) or not names or any(not isinstance(n, str) or not n or "*" in n for n in names):
                            raise ValueError("Expected a nonempty JSON list of literal module names.")
                    except ValueError as error:
                        issue("invalid-import-map", name, mapping_line, message=str(error))
                        names = []
                else:
                    issue("dynamic-import", name, token.line, message="Add an adjacent bounded blueprint-requires declaration.")
                    names = []
            for required in names:
                if (resolved := resolve_require(required, name, token.line)):
                    result.append(resolved)
        for line in mappings.keys() - used:
            issue("stale-import-map", name, line, message="No dynamic require follows this declaration.")
        return result

    entry = f"{PACK}/control.lua"
    migration_files = {relative(p) for p in (root / PACK / "migrations").glob("*.lua")}
    graph, pending = set(), [entry, *sorted(migration_files)]
    while pending:
        name = pending.pop()
        if name in graph:
            continue
        graph.add(name)
        if not (root / name).is_file():
            issue("missing-runtime-root", name)
            continue
        pending.extend(imports(name))
    control_files = {relative(p) for p in (root / PACK / "scripts/control").rglob("*.lua")}
    sentinels = {relative(p) for p in (root / PACK).rglob("control.lua")}
    universe = graph | control_files | sentinels

    model_dir = root / MODEL_ROOT
    index = model_dir / "index.md"
    docs, owners, exceptions = {}, defaultdict(list), {}
    model_names = {relative(p) for p in model_dir.glob("*.md") if p.name != "index.md"}
    if not index.is_file():
        issue("missing-index", f"{MODEL_ROOT}/index.md")
    for document in sorted(model_dir.glob("*.md")):
        name = relative(document)
        try:
            lines = markdown_lines(document.read_text(encoding="utf-8-sig"))
        except (OSError, ValueError, UnicodeError) as error:
            issue("markdown-invalid", name, message=str(error))
            continue
        anchors = [a for _, text in lines for a in ANCHOR.findall(text)]
        docs[name] = set(anchors)
        for anchor, count in Counter(anchors).items():
            if count > 1:
                issue("duplicate-anchor", name, target=anchor)
        if name in model_names and "contract" not in anchors:
            issue("missing-contract-anchor", name)
        section, owned_count = "", 0
        index_links = set()
        for number, line in lines:
            if line.startswith("## "):
                section = line[3:].strip()
            if section == "Implementation sources" and re.match(r"^\s*[-*]\s+", line):
                matches = LINK.findall(line)
                if len(matches) != 1:
                    issue("invalid-source-entry", name, number, message="Use one Markdown source link per list entry.")
                    continue
                source, fragment = target_path(document.parent, matches[0], name, number)
                if source:
                    owned_count += 1
                    if not source.endswith(".lua") or fragment:
                        issue("invalid-source-entry", name, number, matches[0], "Implementation sources must link Lua files without line anchors.")
                    owners[source].append(name)
            if document == index and section == "Coverage exceptions" and line.startswith("|"):
                cells = [c.strip() for c in line.strip("|").split("|")]
                if cells and LINK.search(cells[0]):
                    if len(cells) != 3 or cells[1] not in {"inactive", "data-only"} or not cells[2]:
                        issue("invalid-exception", name, number, message="Expected Source | inactive or data-only | evidence/reason.")
                        continue
                    source, _ = target_path(document.parent, LINK.search(cells[0])[1], name, number)
                    if source in exceptions:
                        issue("duplicate-exception", name, number, source or "")
                    if source:
                        exceptions[source] = {"classification": cells[1], "reason": cells[2]}
                        if cells[1] == "data-only":
                            proven = False
                            for link in LINK.findall(cells[2]):
                                importer, _ = target_path(document.parent, link, name, number)
                                if (not importer or not importer.endswith(".lua")
                                        or not (root / importer).is_file()
                                        or importer in universe
                                        or "/scripts/control/" in ("/" + importer).casefold()
                                        or Path(importer).name.casefold() == "control.lua"):
                                    continue
                                # Inspect the declared importer only. Evidence
                                # does not enroll its data-stage closure in
                                # runtime blueprint coverage.
                                if source in imports(importer):
                                    proven = True
                            if not proven:
                                issue("unproven-data-only", name, number, source,
                                      "Reason must link an existing non-runtime Lua importer outside scripts/control whose imports resolve this source.")
            # All written local Markdown file links must resolve. Only owned
            # source list entries participate in reciprocal ownership checks.
            for link in LINK.findall(line):
                parsed = urlsplit(link.strip("<>"))
                if parsed.scheme or parsed.netloc:
                    continue
                target, fragment = target_path(document.parent, link, name, number)
                if target:
                    index_links.add(target)
                    if fragment and target.startswith(MODEL_ROOT + "/"):
                        # Resolve after all documents' anchors are known.
                        pass
        if name in model_names and owned_count == 0:
            issue("orphan-model", name, message="Model declares no implementation sources.")
        if document == index:
            for missing in model_names - index_links:
                issue("unindexed-model", name, target=missing)

    # Validate cross-model Markdown fragments after loading all anchors.
    for document in model_dir.glob("*.md"):
        name = relative(document)
        if name not in docs:
            continue
        for number, line in markdown_lines(document.read_text(encoding="utf-8-sig")):
            for link in LINK.findall(line):
                parsed = urlsplit(link.strip("<>"))
                if parsed.scheme or parsed.netloc or not parsed.fragment:
                    continue
                try:
                    target = relative(document.parent / unquote(parsed.path)) if parsed.path else name
                except ValueError:
                    continue
                if target in docs and parsed.fragment not in docs[target]:
                    issue("missing-anchor", name, number, link)

    # Sources outside the runtime graph may opt into the same contract.
    marked = set()
    for mod in mods.values():
        if not mod.is_dir():
            continue
        for source in mod.rglob("*.lua"):
            name = relative(source)
            source_text = source.read_text(encoding="utf-8-sig")
            if "blueprint:" in source_text or "blueprint-ref:" in source_text:
                source_tokens = read_tokens(name)
                if code_markers(source_tokens, "blueprint") or code_markers(source_tokens, "blueprint-ref"):
                    marked.add(name)
    all_sources = universe | set(owners) | set(exceptions) | marked
    classified = []
    for source in sorted(all_sources):
        if source in exceptions:
            if source not in universe:
                issue("stale-exception", source, message="Exception is outside current runtime coverage.")
            if source in graph:
                issue("runtime-exception", source, message="A runtime dependency cannot be excluded.")
            if source in owners:
                issue("owned-exception", source, message="Choose an owner or a justified exception, not both.")
        tokens = read_tokens(source) if (root / source).is_file() else []
        if source in exceptions and exceptions[source]["classification"] == "inactive" and any(t.kind != "comment" for t in tokens):
            issue("nonempty-inactive", source, message="Inactive placeholder exceptions must contain no executable code; model an inert sentinel explicitly.")
        primary = code_markers(tokens, "blueprint")
        references = code_markers(tokens, "blueprint-ref")
        expected = owners.get(source, [])
        if len(expected) > 1:
            issue("duplicate-owner", source, target=", ".join(expected))
        if source not in exceptions:
            if not expected:
                issue("unowned-source", source, message="Declare this source in a model's Implementation sources.")
            if len(primary) != 1:
                issue("primary-count", source, message=f"Expected one primary marker, found {len(primary)}.")
        elif primary:
            issue("excluded-primary", source, message="Exception unexpectedly has a model marker.")
        for line, target in primary + references:
            document, anchor = target_path(root, target, source, line)
            if document not in docs or document not in model_names:
                issue("invalid-model-target", source, line, target)
            elif not anchor or anchor not in docs[document]:
                issue("missing-anchor", source, line, target)
            if (line, target) in primary:
                if document not in expected:
                    issue("missing-reciprocal-owner", source, line, target)
                if anchor != "contract":
                    issue("primary-anchor", source, line, target, "Primary markers target #contract.")
                marker_offset = next(t.start for t in tokens if t.kind == "comment" and t.line == line and re.match(r"^--\s*blueprint:", t.value))
                code_before = [t for t in tokens if t.kind != "comment" and t.start < marker_offset]
                if code_before:
                    issue("late-primary", source, line, target, "Primary marker must precede executable code.")
                text = (root / source).read_text(encoding="utf-8-sig")
                header = re.search(r"(?s)^--=+\r?\n-- ESIR FILE MAP\r?\n.*?--=+", text)
                if header and line <= text[:header.end()].count("\n") + 1:
                    issue("generated-header-primary", source, line, target, "Move marker after the generated file map.")
        classified.append({"file": source, "discovered_runtime": source in graph,
                           "owner": expected[0] if len(expected) == 1 else None,
                           "exception": exceptions.get(source)})
    # Repeated link parsing should not duplicate actionable diagnostics.
    unique = {json.dumps(f, sort_keys=True): f for f in findings}
    findings = sorted(unique.values(), key=lambda f: (f["file"], f["line"], f["code"], f["target"]))
    return {"overall_status": "failed" if findings else "ok",
            "counts": {"runtime_dependencies": len(graph), "runtime_inventory": len(universe),
                       "models": len(model_names), "owned_sources": len(owners), "exceptions": len(exceptions),
                       "findings": len(findings)}, "sources": classified, "findings": findings}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--format", choices=("json", "markdown"), default="markdown")
    args = parser.parse_args()
    try:
        result = audit(Path(args.repo_root))
    except (OSError, ValueError) as error:
        result = {"overall_status": "failed", "counts": {}, "sources": [],
                  "findings": [{"code": "audit-error", "file": "", "line": 0, "target": "", "message": str(error)}]}
        exit_code = 2
    else:
        exit_code = 0 if result["overall_status"] == "ok" else 1
    if args.format == "json":
        print(json.dumps(result, indent=2, ensure_ascii=True))
    else:
        print(f"Conceptual blueprints: {result['overall_status']}")
        print(json.dumps(result["counts"], sort_keys=True))
        for finding in result["findings"]:
            print(f"- {finding['file']}:{finding['line']} [{finding['code']}] {finding['target']} {finding['message']}")
        print("Structural coverage only; review model behavior against current source separately.")
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())

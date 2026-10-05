"""Read-only structural advisory for ESIR runtime module contracts.

Uses the conceptual blueprint lexer, never evaluates Lua. Unknown bindings,
conditional exports and dynamic/forwarded interfaces remain inventory.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

PACK = "exotic-space-industries-remembrance"
NOTICE = "Structural advisory; behavior and performance require runtime verification."
REGISTRATIONS = {"on_event", "on_nth_tick", "on_init", "on_load", "on_configuration_changed"}
RULES = {"signature", "parallel-registration", "module-call-form",
         "required-export-probe", "duplicate-export", "clock-review"}


def load_lexer():
    path = Path(__file__).resolve().parents[2] / "esir-conceptual-blueprints/scripts/blueprint_audit.py"
    spec = importlib.util.spec_from_file_location("_esir_runtime_lexer", path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


LEXER = None


def sequence(tokens, index, values):
    return [t.value for t in tokens[index:index + len(values)]] == values


def block_depths(tokens):
    """Conservative Lua block nesting; loops own their subsequent do token."""
    depths, stack = [], []
    for token in tokens:
        value = token.value if token.kind != "string" else ""
        depths.append(len(stack))
        if value in {"function", "if", "repeat"}:
            stack.append(value)
        elif value in {"for", "while"}:
            stack.append("await-do")
        elif value == "do":
            if stack and stack[-1] == "await-do":
                stack[-1] = "loop"
            else:
                stack.append("do")
        elif value in {"end", "until"} and stack:
            stack.pop()
    return depths


def parameters(tokens, opening):
    if opening >= len(tokens) or tokens[opening].value != "(":
        return None, opening
    values, index = [], opening + 1
    while index < len(tokens) and tokens[index].value != ")":
        values.append(tokens[index].value)
        index += 1
    if index == len(tokens):
        raise ValueError(f"Unterminated parameter list at line {tokens[opening].line}")
    text = "".join(values)
    return ([p for p in text.split(",") if p], index)


def family(symbol, params):
    first = (params or [""])[0].lstrip("_")
    if params is None:
        return "unresolved-alias"
    if symbol == "on_scripted_research_burst":
        return "research-burst"
    if symbol.startswith("has_") or symbol.startswith("is_"):
        return "predicate"
    if symbol.startswith(("get_pending_", "get_work_", "get_fluid_work_")):
        return "workload-query"
    if symbol in {"on_init", "on_load", "on_configuration_changed"} or symbol.startswith(("rebuild_", "check_")):
        return "lifecycle"
    if "status" in symbol or symbol.startswith(("debug_", "get_qc_")):
        return "diagnostic"
    if symbol.startswith("on_"):
        return "entity-adapter" if first in {"entity", "ent"} else "event-or-domain-receiver"
    if symbol in {"update", "updater"} or symbol.endswith("_updater") or symbol.startswith("service_"):
        if first in {"budget", "limit", "updates", "max_updates", "update_limit"}:
            return "budget-first-service"
        if first in {"tick", "current_tick"}:
            return "clock-only-service"
        return "event-or-domain-service"
    return "helper"


def resolve_require(name):
    if name.startswith("__") or ".." in name or "\\" in name:
        return None
    if name.endswith(".lua"):
        name = name[:-4]
    return f"{PACK}/{name.replace('.', '/')}.lua"


def uncertain_bindings(tokens):
    """Collect loop bindings and comma-separated assignment/declaration names."""
    uncertain = set()
    for i, token in enumerate(tokens):
        if token.value in {"for", "local"}:
            j = i + 1
            while j < len(tokens) and (tokens[j].kind == "identifier" or tokens[j].value == ","):
                if tokens[j].value in {"in", "function"}:
                    break
                if tokens[j].kind == "identifier" and (token.value == "for" or j > i + 1):
                    uncertain.add(tokens[j].value)
                j += 1
        if token.value == "=":
            j, roots = i - 1, []
            while j >= 0 and tokens[j].kind == "identifier":
                while j >= 2 and tokens[j - 1].value == "." and tokens[j - 2].kind == "identifier":
                    j -= 2
                roots.append(tokens[j].value)
                j -= 1
                if j < 0 or tokens[j].value != ",":
                    break
                j -= 1
            if len(roots) > 1:
                uncertain.update(roots)
    return uncertain


def inspect_file(path, repo):
    global LEXER
    if LEXER is None:
        LEXER = load_lexer()
    source = path.read_text(encoding="utf-8-sig")
    tokens = [t for t in LEXER.lex_lua(source) if t.kind != "comment"]
    depths = block_depths(tokens)
    file = path.relative_to(repo).as_posix()
    root = tokens[-1].value if len(tokens) >= 2 and tokens[-2].value == "return" and tokens[-1].kind == "identifier" else None
    exports, imports, aliases, declarations, param_names = [], [], [], set(), set()
    replaced_receivers, bracket_writes = set(), set()
    for i, token in enumerate(tokens):
        if token.kind == "identifier" and (not i or tokens[i - 1].value not in {".", ":"}):
            j = i + 1
            while j + 1 < len(tokens) and tokens[j].value == "." and tokens[j + 1].kind == "identifier":
                j += 2
            if j > i + 1 and j < len(tokens) and tokens[j].value == "=":
                replaced_receivers.add(token.value)
            if i + 1 < len(tokens) and tokens[i + 1].value == "[":
                j, nesting = i + 1, 0
                while j < len(tokens):
                    if tokens[j].kind != "string":
                        nesting += tokens[j].value == "["
                        nesting -= tokens[j].value == "]"
                    if nesting == 0:
                        break
                    j += 1
                if j + 1 < len(tokens) and tokens[j + 1].value == "=":
                    bracket_writes.add(token.value)
                    replaced_receivers.add(token.value)
        if token.value == "function":
            if i + 2 < len(tokens) and tokens[i + 1].kind == "identifier" and tokens[i + 2].value in {".", ":"}:
                replaced_receivers.add(tokens[i + 1].value)
            opening = i + 1
            while opening < len(tokens) and tokens[opening].value != "(":
                opening += 1
            params, closing = parameters(tokens, opening)
            param_names.update(params or [])
            declarations.update(range(i, closing + 1))
            # Only exports on the final returned table are proven.
            if root and i + 3 < len(tokens) and tokens[i + 1].value == root and tokens[i + 2].value in {".", ":"} and tokens[i + 3].kind == "identifier" and opening == i + 4:
                exports.append({"file": file, "line": token.line, "symbol": tokens[i + 3].value,
                                "form": tokens[i + 2].value, "parameters": params,
                                "conditional": depths[i] != 0})
        if root and (not i or tokens[i - 1].value not in {".", ":"}) and sequence(tokens, i, [root, "."]) and i + 3 < len(tokens) and tokens[i + 2].kind == "identifier" and tokens[i + 3].value == "=":
            symbol = tokens[i + 2].value
            if i + 5 < len(tokens) and tokens[i + 4].value == "function" and tokens[i + 5].value == "(":
                params, closing = parameters(tokens, i + 5)
                declarations.update(range(i, closing + 1))
                exports.append({"file": file, "line": token.line, "symbol": symbol, "form": ".",
                                "parameters": params, "conditional": depths[i] != 0})
            else:
                aliases.append({"file": file, "line": token.line, "symbol": symbol, "family": "unresolved-alias"})
        if token.kind == "identifier" and i + 3 < len(tokens) and sequence(tokens, i + 1, ["=", "require"]):
            if i and tokens[i - 1].value in {".", ":"}:
                continue
            literal = i + 3 + (tokens[i + 3].value == "(")
            if literal < len(tokens) and tokens[literal].kind == "string":
                module = LEXER.string_value(tokens[literal].value)
                imports.append({"file": file, "line": token.line, "alias": token.value,
                                "module": module, "target": resolve_require(module),
                                "position": i, "top_level": depths[i] == 0})
            else:
                imports.append({"file": file, "line": token.line, "alias": token.value,
                                "module": None, "target": None, "position": i,
                                "top_level": depths[i] == 0})
    uncertain = uncertain_bindings(tokens)
    root_assignments = sum(1 for i, t in enumerate(tokens[:-1]) if t.value == root and tokens[i + 1].value == "=")
    root_declarations = sum(1 for i, t in enumerate(tokens[:-1]) if t.value == "local" and tokens[i + 1].value == root)
    overridden = {a["symbol"] for a in aliases}
    for item in exports:
        item["family"] = family(item["symbol"], item["parameters"])
        item["uncertain"] = root_assignments > 1 or root_declarations > 1 or root in uncertain or root in bracket_writes or item["symbol"] in overridden
    bindings = {}
    for item in imports:
        name = item["alias"]
        assignments = sum(1 for i, t in enumerate(tokens[:-1]) if t.value == name and tokens[i + 1].value == "=")
        declarations_count = sum(1 for i, t in enumerate(tokens[:-1]) if t.value == "local" and tokens[i + 1].value == name)
        i = item["position"]
        declared_local = i > 0 and tokens[i - 1].value == "local"
        parenthesized = i + 3 < len(tokens) and tokens[i + 3].value == "("
        end = i + (5 if parenthesized else 3)
        exact_literal = (item["module"] is not None and (not parenthesized or tokens[end].value == ")"))
        expression_tail = end + 1 < len(tokens) and tokens[end + 1].value in {".", ":", "[", "+", "-", "*", "/", "%", "^", "and", "or"}
        item["proven"] = (exact_literal and not expression_tail and name not in uncertain and name not in replaced_receivers and item["top_level"] and assignments == 1 and declarations_count == int(declared_local) and
                          name not in param_names and sum(v["alias"] == name for v in imports) == 1)
        if item["proven"]:
            bindings[name] = item
    return {"file": file, "sha256": hashlib.sha256(source.encode()).hexdigest(), "root": root,
            "tokens": tokens, "declarations": declarations, "exports": exports,
            "imports": imports, "aliases": aliases, "bindings": bindings}


def finding(rule, file, line, symbol, observed, message):
    return {"rule": rule, "file": file, "line": line, "symbol": symbol,
            "observed": observed, "message": message, "blocking": False}


def load_exceptions(path):
    if not path.is_file():
        raise FileNotFoundError(f"Exception configuration missing: {path}")
    config = json.loads(path.read_text(encoding="utf-8-sig"))
    if config.get("version") != 1 or not isinstance(config.get("exceptions"), list):
        raise ValueError("Expected exception configuration version 1 and exceptions array")
    seen = set()
    for entry in config["exceptions"]:
        if not isinstance(entry, dict):
            raise ValueError("Exception must be an object")
        key = tuple(entry.get(k) for k in ("file", "rule", "symbol"))
        if any(not isinstance(v, str) or not v for v in key) or key[1] not in RULES:
            raise ValueError(f"Invalid exception key: {key}")
        if key in seen or "*" in key[0] or "\\" in key[0] or ".." in Path(key[0]).parts or Path(key[0]).is_absolute():
            raise ValueError(f"Duplicate or nonliteral exception path: {key}")
        if not isinstance(entry.get("reason"), str) or not entry["reason"].strip() or not isinstance(entry.get("expected"), dict) or not entry["expected"]:
            raise ValueError(f"Exception requires reason and expected shape: {key}")
        seen.add(key)
    return config["exceptions"]


def audit(repo, exceptions_path=None):
    repo = Path(repo).resolve()
    pack = repo / PACK
    paths = [pack / "control.lua"]
    for directory in (pack / "lib", pack / "scripts/control"):
        if not directory.is_dir():
            raise FileNotFoundError(f"Required runtime source directory missing: {directory}")
        paths.extend(directory.rglob("*.lua"))
    files = [inspect_file(p, repo) for p in sorted(set(paths))]
    by_path = {f["file"]: f for f in files}
    exceptions = load_exceptions(Path(exceptions_path) if exceptions_path else repo / ".codex/esir/runtime-contract-exceptions.json")
    observations, findings, calls, clocks = [], [], [], []
    for file in files:
        tokens = file["tokens"]
        counts = Counter(e["symbol"] for e in file["exports"])
        for export in file["exports"]:
            observations.append({"rule": "signature", "file": file["file"], "line": export["line"],
                                 "symbol": export["symbol"],
                                 "observed": {"parameters": export["parameters"], "form": export["form"]}})
            if counts[export["symbol"]] > 1:
                findings.append(finding("duplicate-export", file["file"], export["line"], export["symbol"],
                                        {"count": counts[export["symbol"]]}, "Multiple recognized definitions; review conditional/override semantics."))
                counts[export["symbol"]] = 0
        for i, token in enumerate(tokens):
            if sequence(tokens, i, ["game", ".", "tick"]):
                item = finding("clock-review", file["file"], token.line, "game.tick", {"read": "game.tick"},
                               "Review boundary/context; this inventory does not prove a forbidden clock read.")
                clocks.append({"file": file["file"], "line": token.line})
                findings.append(item)
            if sequence(tokens, i, ["script", "."]) and i + 3 < len(tokens) and tokens[i + 2].value in REGISTRATIONS and tokens[i + 3].value == "(" and file["file"] != f"{PACK}/control.lua":
                findings.append(finding("parallel-registration", file["file"], token.line, tokens[i + 2].value,
                                        {"receiver": "script"}, "Keep event/cadence registration in control.lua."))
            binding = file["bindings"].get(token.value)
            if not binding or i <= binding["position"] or i in file["declarations"] or i + 2 >= len(tokens) or tokens[i + 1].value not in {".", ":"} or tokens[i + 2].kind != "identifier":
                continue
            if i and tokens[i - 1].value in {".", ":"}:
                continue
            symbol, form = tokens[i + 2].value, tokens[i + 1].value
            target = by_path.get(binding["target"])
            matches = [e for e in target["exports"] if e["symbol"] == symbol] if target else []
            export = matches[0] if len(matches) == 1 and not matches[0]["conditional"] and not matches[0]["uncertain"] else None
            observed = {"form": form, "target": binding["target"]}
            if i + 3 < len(tokens) and tokens[i + 3].value == "(":
                calls.append({"file": file["file"], "line": token.line, "alias": token.value,
                              "symbol": symbol, **observed, "proven_export": export is not None})
                if export:
                    expects_self = export["form"] == ":" or (export["parameters"] or [""])[0] == "self"
                    explicit_self = i + 5 < len(tokens) and tokens[i + 4].value == token.value and tokens[i + 5].value in {",", ")"}
                    if (form == ":" and not expects_self) or (form == "." and expects_self and not explicit_self):
                        findings.append(finding("module-call-form", file["file"], token.line, symbol, observed,
                                                "Call form disagrees with the recognized export; preserve explicit self methods."))
            elif export and (tokens[i + 3].value if i + 3 < len(tokens) else "") in {"then", "and", "or", ")"} and i and tokens[i - 1].value in {"if", "elseif", "and", "or", "not", "("}:
                findings.append(finding("required-export-probe", file["file"], token.line, symbol, observed,
                                        "Recognized local export is capability-probed; review whether this is a required interface or intentional diagnostic."))
    applied, stale = [], []
    for exception in exceptions:
        key = tuple(exception[k] for k in ("file", "rule", "symbol"))
        candidates = observations if exception["rule"] == "signature" else findings
        matching = [f for f in candidates if tuple(f[k] for k in ("file", "rule", "symbol")) == key and
                    all(k in f["observed"] and f["observed"][k] == v for k, v in exception["expected"].items())]
        if matching:
            applied.append(exception)
            if exception["rule"] != "signature":
                findings = [f for f in findings if f not in matching]
        else:
            stale.append(exception)
            findings.append(finding("stale-exception", exception["file"], 1, exception["symbol"],
                                    exception["expected"], f"Expected {exception['rule']} shape absent or changed: {exception['reason']}"))
    sort_key = lambda f: (f["file"], f.get("line", 0), f.get("rule", ""), f.get("symbol", ""))
    exports = sorted([e for f in files for e in f["exports"]], key=sort_key)
    return {"run_status": "ok", "blocking": False, "notice": NOTICE,
            "audited_file_count": len(files),
            "source_hashes": [{"file": f["file"], "sha256": f["sha256"]} for f in files],
            "family_counts": dict(sorted(Counter(e["family"] for e in exports).items())),
            "finding_counts": dict(sorted(Counter(f["rule"] for f in findings).items())),
            "applied_exception_count": len(applied), "stale_exception_count": len(stale),
            "exceptions": {"applied": applied, "stale": stale},
            "exports": exports, "aliases": sorted([a for f in files for a in f["aliases"]], key=sort_key),
            "imports": [{k: v for k, v in item.items() if k != "position"}
                        for f in files for item in f["imports"]],
            "calls": sorted(calls, key=sort_key), "clock_reads": sorted(clocks, key=sort_key),
            "findings": sorted(findings, key=sort_key)}


def markdown(report):
    rows = ["# Runtime Contract Advisory", "", report["notice"], "",
            f"Files: {report['audited_file_count']}; findings: {len(report['findings'])}; "
            f"exceptions applied/stale: {report['applied_exception_count']}/{report['stale_exception_count']}.",
            "Preflight pass/fail is unaffected, including under Strict.", "",
            "| Rule | Source | Symbol | Review |", "| --- | --- | --- | --- |"]
    for item in report["findings"]:
        values = [item["rule"], f"{item['file']}:{item['line']}", item["symbol"], item["message"]]
        rows.append("| " + " | ".join(str(v).replace("|", "\\|").replace("\n", " ") for v in values) + " |")
    rows.extend(["", "## Export family inventory", ""])
    rows.extend(f"- {name}: {count}" for name, count in report["family_counts"].items())
    return "\n".join(rows) + "\n"


def main():
    parser = argparse.ArgumentParser(description=NOTICE)
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--exceptions", help="Explicit exception JSON; default is repo-owned configuration.")
    parser.add_argument("--format", choices=("json", "markdown"), default="markdown")
    args = parser.parse_args()
    try:
        report = audit(args.repo_root, args.exceptions)
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(json.dumps({"run_status": "unavailable", "blocking": False, "error": str(error)}), file=sys.stderr)
        return 2
    print(json.dumps(report, indent=2) if args.format == "json" else markdown(report), end="\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

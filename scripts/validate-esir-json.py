"""Validate a large Factorio JSON object with bounded memory; no generated files."""
import re
import sys

TOKEN = re.compile(r'"(?:[^"\\\x00-\x1f]|\\(?:["\\/bfnrt]|u[0-9a-fA-F]{4}))*"|-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?(?=[ \t\r\n,\]}]|$)|true|false|null|[{}\[\]:,]')
SPACE = re.compile(r"[ \t\r\n]*")


def tokens(stream):
    buffer = ""
    eof = False
    position = 0
    while True:
        if not eof and len(buffer) - position < 4096:
            chunk = stream.read(65536)
            buffer = buffer[position:] + chunk
            position = 0
            eof = not chunk
        position = SPACE.match(buffer, position).end()
        if position == len(buffer):
            if eof:
                return
            continue
        match = TOKEN.match(buffer, position)
        if not eof and (not match or match.end() == len(buffer)):
            if len(buffer) - position > 16 * 1024 * 1024:
                raise ValueError("Invalid JSON or token exceeds 16 MiB safety limit")
            chunk = stream.read(65536)
            buffer = buffer[position:] + chunk
            position = 0
            eof = not chunk
            continue
        if not match:
            raise ValueError("Invalid JSON token")
        value = match.group()
        position = match.end()
        yield value


def validate(stream, require_nonempty=False):
    stack = []
    finished = False
    started = False
    root_has_member = False
    for token in tokens(stream):
        if finished:
            raise ValueError("Trailing JSON content")
        if not started:
            if token != "{":
                raise ValueError("Expected a JSON object")
            started = True
            stack.append("key-or-end")
            continue
        state = stack[-1]
        if state in ("key", "key-or-end"):
            if token == "}" and state == "key-or-end":
                stack.pop()
            elif token.startswith('"'):
                if len(stack) == 1:
                    root_has_member = True
                stack[-1] = "colon"
            else:
                raise ValueError("Expected object key")
        elif state == "colon":
            if token != ":":
                raise ValueError("Expected colon")
            stack[-1] = "object-value"
        elif state in ("object-comma", "array-comma"):
            closing = "}" if state == "object-comma" else "]"
            if token == closing:
                stack.pop()
            elif token == ",":
                stack[-1] = "key" if state == "object-comma" else "array-value"
            else:
                raise ValueError("Expected comma or end")
        else:
            if state == "value-or-end" and token == "]":
                stack.pop()
            else:
                if token in ("}", "]", ":", ","):
                    raise ValueError("Expected value")
                stack[-1] = "object-comma" if state == "object-value" else "array-comma"
                if token == "{":
                    stack.append("key-or-end")
                elif token == "[":
                    stack.append("value-or-end")
        finished = not stack
    if not finished:
        raise ValueError("Empty or truncated JSON")
    if require_nonempty and not root_has_member:
        raise ValueError("Final-data dump contains an empty object")


if __name__ == "__main__":
    try:
        with open(sys.argv[1], encoding="utf-8-sig") as source:
            validate(source, require_nonempty=True)
    except (OSError, ValueError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)

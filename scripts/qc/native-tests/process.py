"""Structured bridge to the native runner's owned-process supervisor."""
import hashlib
import json
from pathlib import Path
import sys

from runner import run_process, write_json


def main():
    request_path = Path(sys.argv[1])
    request_bytes = request_path.read_bytes()
    request = json.loads(request_bytes.decode('utf-8-sig'))
    result = run_process(request['command'], request['output'], request['timeout_seconds'])
    result['run_id'] = request['run_id']
    result['request_sha256'] = hashlib.sha256(request_bytes).hexdigest()
    write_json(request['report'], result)


if __name__ == '__main__':
    main()

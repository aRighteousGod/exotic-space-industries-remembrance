"""Compare normalized correctness reports from identical baseline/current lanes."""
import argparse
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('dispatch', 'research'))
    parser.add_argument('baseline', type=Path)
    parser.add_argument('current', type=Path)
    args = parser.parse_args()
    reports = [json.loads(p.read_text(encoding='utf-8-sig')) for p in (args.baseline, args.current)]
    fields = ['checks', 'trace'] if args.mode == 'dispatch' else [
        'checks', 'scripted', 'normal', 'native_scripted_event_count',
        'native_normal_events', 'tesla_relevance', 'targets', 'snapshots']
    comparisons = {field: all(field in r for r in reports) and reports[0][field] == reports[1][field]
                   for field in fields}
    passed = all(r.get('all_pass') is True for r in reports) and all(comparisons.values())
    print(json.dumps({'all_pass': passed, 'mode': args.mode, 'fields_equal': comparisons,
                      'performance_evidence': False}, indent=2))
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())

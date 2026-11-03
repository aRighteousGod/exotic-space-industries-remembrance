"""Summarize accepted paired trials without merging distinct cost measurements."""
import argparse, json, pathlib, statistics

p = argparse.ArgumentParser()
p.add_argument('--context', type=pathlib.Path, required=True)
a = p.parse_args()
r = json.loads(a.context.read_text(encoding='utf-8-sig'))
root = pathlib.Path(r['evidence'])
data = json.loads((root / 'observer-performance-acceptance.json').read_text())
assert data['passed'] and data['measured_runs'] == 160
rows = []
for count in (1000, 10000):
    for fraction in (0, 10):
        for budget in (256, 1024):
            for circuit in (1, 1024):
                row = dict(crafters=count, circuit_percent=fraction, main_budget=budget, circuit_budget=circuit)
                for revision in ('baseline', 'candidate'):
                    case = data['cases'][f'observers-{count}-{fraction}-{budget}-{circuit}-{revision}']
                    trials = case['trials']
                    assert len(trials) == 5 and all(t['monitor']['isolated'] for t in trials)
                    row[revision] = dict(
                        native_ms_per_tick=statistics.mean(t['ms_per_tick'] for t in trials),
                        passage_ms_per_tick=statistics.mean(t['script_ms_per_tick'] for t in trials),
                        watcher_attempts=sorted({t['watcher_attempts'] for t in trials}),
                        circuit_attempts=sorted({t['circuit_attempts'] for t in trials}),
                        helper_counts=sorted({t['helper_count'] for t in trials}),
                        peak_private_mib=max(t['monitor']['peak_private_bytes'] for t in trials)/1048576,
                        peak_working_mib=max(t['monitor']['peak_working_set_bytes'] for t in trials)/1048576,
                        latency=trials[0]['latency'],
                        initial_ready_tick=case['ready']['ready_tick'])
                row['native_delta_ms'] = row['candidate']['native_ms_per_tick']-row['baseline']['native_ms_per_tick']
                rows.append(row)
summary = dict(passed=True, engine=data['engine'], measured_runs=160, observation_ticks=5990,
               baseline_sha256=data['baseline_sha256'], candidate_sha256=data['candidate_sha256'], rows=rows,
               worst_paired_delta_ms=max(p['delta_ms'] for p in data['comparisons']),
               smallest_margin_ms=min(p['limit_ms']-p['delta_ms'] for p in data['comparisons']))
(root/'observer-performance-summary.json').write_text(json.dumps(summary, indent=2), encoding='utf8')
lines = ['# Native observer performance', '',
         'Five isolated old/new runs per case; times are means in ms/tick. Private memory is the maximum sampled whole-process value in MiB.', '',
         '| Crafters | Circuit % | Main / circuit budget | Native old / new | Passage old / new | Private MiB old / new | New circuit attempts / 5,990 ticks | New signal-to-joint ticks |',
         '|---:|---:|---:|---:|---:|---:|---:|---:|']
for row in rows:
    old, new = row['baseline'], row['candidate']
    lines.append(f"| {row['crafters']:,} | {row['circuit_percent']} | {row['main_budget']} / {row['circuit_budget']} | "
                 f"{old['native_ms_per_tick']:.6f} / {new['native_ms_per_tick']:.6f} | "
                 f"{old['passage_ms_per_tick']:.6f} / {new['passage_ms_per_tick']:.6f} | "
                 f"{old['peak_private_mib']:.1f} / {new['peak_private_mib']:.1f} | "
                 f"{','.join(map(str,new['circuit_attempts']))} | {new['latency'].get('joint_ticks','n/a')} |")
lines += ['', 'The JSON companion retains watcher attempts, helper counts, working memory, discovery settling and explicit-refresh latency separately.',
          'Timing acceptance applies to every paired run: the larger of 5% of its baseline or 0.1 ms/tick.',
          'These are crafter steady-state measurements with pre-checkpoint recipe-change probes, not a new construction/removal burst benchmark.']
(root/'observer-performance-summary.md').write_text('\n'.join(lines)+'\n', encoding='utf8')
print(json.dumps({k: v for k, v in summary.items() if k != 'rows'}))

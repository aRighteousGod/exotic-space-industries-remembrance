"""Strict engine lifecycle acceptance, including comparison of all ordered records."""
import argparse
import json
from pathlib import Path

parser=argparse.ArgumentParser()
parser.add_argument('kind',choices=('queue','gui'))
parser.add_argument('runs',nargs='+',type=Path)
parser.add_argument('--expect-reload',action='store_true')
args=parser.parse_args()
reference=None
for run in args.runs:
    report=json.loads((run/f'script-output/control-ups-{args.kind}.json').read_text(encoding='utf-8-sig'))
    assert report['complete'] is True,run
    manifest=json.loads((run/'manifest.json').read_text(encoding='utf-8-sig'))
    assert manifest['runs']==1 and manifest['bridge_sha256'] and manifest['exports_sha256'],run
    expected_kind='configuration' if manifest['force_config'] else 'ordinary'
    if args.kind=='queue':
        assert report['reload_kind']==expected_kind,(run,report)
        assert report['spawned_chests']==6 and len(report['trace'])==23,run
        trace=report['trace']
        assert [r['value']['tick'] for r in trace]==[25,25,26,30,30,31,31,40,40,41,50,55,65,65,75,90,100,100,101,110,115,125,150],run
        assert next(r for r in trace if r['value'].get('label')=='invalid')['value']['valid'] is False,run
        assert trace[5]['value']['x']==24 and trace[6]['value']['x']==16,run
        source_is_baseline=Path(manifest['source']).resolve()==Path(manifest['baseline']).resolve()
        if source_is_baseline:
            assert report['saved_minima']=={'gaia':False,'alien':False},run
        else:
            assert isinstance(report['saved_minima']['gaia'],int) and report['saved_minima']['gaia']>0,run
            assert report['saved_minima']['gaia']==report['saved_minima']['alien'],run
    else:
        trace=report['trace']
        snapshots=[r for r in trace if r['kind']=='snapshot']
        assert snapshots and all(r['detail']['connected'] and r['detail']['connected_count']>=1 for r in snapshots),run
        labels={r['detail']['label'] for r in snapshots}
        assert {'black-open-A','black-retarget-B','black-close','black-destroy','matrix-open-A','matrix-retarget-B','matrix-retag-B','matrix-core-destroy','matrix-explicit-repair','orphans-created','pre-save-open','final'}<=labels,run
        by_label={r['detail']['label']:r['detail'] for r in snapshots}
        assert by_label['black-open-A']['black'] and not by_label['black-close']['black'],run
        assert by_label['matrix-open-A']['matrix_data']['id']=='A',run
        assert by_label['matrix-retarget-B']['matrix_data']['id']=='B',run
        assert by_label['matrix-retag-B']['matrix_data']['id']=='B',run
        assert by_label['matrix-retag-B']['matrix_data']['camera']==by_label['matrix-open-A']['matrix_data']['camera'],run
        assert by_label['matrix-core-destroy']['matrix'],run
        assert by_label['matrix-explicit-repair']['matrix_data']['id']=='A',run
        assert any(r['kind']=='on_gui_opened' for r in trace),run
        assert any(r['kind']=='on_gui_closed' for r in trace),run
        if args.expect_reload or report.get('reload_kind'):
            assert report['reload_kind']==expected_kind,run
            assert 'reload-'+expected_kind in labels,run
    if reference is None:reference=trace
    else:assert trace==reference,f'Ordered trace mismatch: {run}'
print(json.dumps({'kind':args.kind,'runs':len(args.runs),'records':len(reference),'all_complete':True,'traces_equal':True},indent=2))

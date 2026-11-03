"""Require the complete native matrix and exact production source identities."""
import argparse, hashlib, json, pathlib

PRODUCTION=('lib/factory-passage-config.lua','prototypes/factory-passage.lua',
            'scripts/data-final-updates/factory-passage.lua','scripts/control/factory-passage.lua')

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--context',required=True);args=parser.parse_args()
    context=json.loads(pathlib.Path(args.context).read_text(encoding='utf-8-sig'));root=pathlib.Path(context['evidence'])
    source=pathlib.Path(context['mods'])/'exotic-space-industries-remembrance'
    expected={name:hashlib.sha256((source/name).read_bytes()).hexdigest() for name in PRODUCTION}
    modes=('esir','squeak-through','vanilla');cases=[]
    for mode in modes:cases.append((f'full-{mode}',mode,True,None))
    for before in modes:
        for after in modes:
            if before!=after:cases.append((f'{before}-to-{after}',after,True,before))
    cases += [('full-reload','esir',True,None),('full-master-off','esir',False,'esir'),('full-master-on','esir',True,'esir')]
    cases += [(name+'-off','esir',True,None) for name in ('production','power','logistics','turrets')]
    cases += [('actors','esir',True,None)]
    results=[]
    for label,mode,enabled,before in cases:
        receipt=json.loads((root/(label+'.json')).read_text(encoding='utf-8-sig'))
        assert receipt['passed'] and receipt['engine']=='2.1.24' and receipt['mode']==mode and receipt['enabled']==enabled,label
        assert receipt['checks'] and all(check['passed'] for check in receipt['checks']),label
        status=receipt['status'];assert status['mode']==(mode if enabled else 'vanilla')
        assert status['dirty']==status['pending']==0 and status['counters']['unsupported']==0 and status['counters']['max_processed']<=256
        if mode!='esir' or not enabled:assert status['helpers']==0
        if before:assert receipt['transition'] and receipt['from_mode']==before
        if label=='full-reload':assert receipt['loaded'] and not receipt.get('transition')
        if label=='actors':assert status['helpers']==status['joints']==status['watchers']==0
        manifest=json.loads((root/(label+'-sources.json')).read_text(encoding='utf-8-sig'))
        manifest={name.replace('\\','/'):value for name,value in manifest.items()}
        for name,sha in expected.items():assert manifest['exotic-space-industries-remembrance/'+name]==sha,(label,name,'source mismatch')
        results.append(dict(label=label,checks=len(receipt['checks']),status=status))
    visual=[]
    for label in ('esir-visual','squeak-through-visual','vanilla-visual','master-off-visual'):
        receipt=json.loads((root/(label+'.json')).read_text(encoding='utf-8-sig'))
        frames=json.loads((root/(label+'-frames.json')).read_text(encoding='utf-8-sig'))
        assert receipt['passed'] and len(frames)==96 and all(frame['sha256'] for frame in frames)
        visual.append(dict(label=label,frames=len(frames),source_manifest=label+'-sources.json'))
    report=dict(passed=True,engine='2.1.24',required_labels=[case[0] for case in cases],production_sha256=expected,cases=results,visual=visual,
                visual_scope='Native regression/pipe scenes captured before final unrelated custom receiver and eight-way admission refinements; exact capture source manifests retained. Final native matrix repeats those movement invariants.',
                multiplayer_scope='Hosted server save/reload and native player/robot/platform actors; no two-client synchronization claim.',
                performance_scope='Separate final performance-acceptance.json required for the cost gate.')
    (root/'native-acceptance.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    print(json.dumps(dict(passed=True,case_groups=len(results),native_assertion_records=sum(row['checks'] for row in results),visual_frames=384)))

if __name__=='__main__':main()

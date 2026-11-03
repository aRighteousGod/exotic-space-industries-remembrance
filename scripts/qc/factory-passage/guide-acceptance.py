"""Accept native guide receipts and captures against current delivered sources."""
import argparse, hashlib, json, pathlib

p=argparse.ArgumentParser();p.add_argument('--context',type=pathlib.Path,required=True);a=p.parse_args()
repo=pathlib.Path(__file__).resolve().parents[3]
context=json.loads(a.context.read_text(encoding='utf-8-sig'));root=pathlib.Path(context['evidence'])
labels=['guide-esir-'+locale for locale in ('en','de','fr','ja','pl','ru','zh-CN','zh-TW')]
labels+=['guide-vanilla-en','guide-disabled-en']
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
for label in labels:
    result=json.loads((root/(label+'.json')).read_text(encoding='utf8'))
    assert result['passed'] and result['engine']=='2.1.24' and len(result['translations'])==22
    assert all(c['passed'] for c in result['checks'])
    assert any(c['name']=='opening guide has no gameplay side effects' for c in result['checks'])
    sources={k.replace('\\','/'):v for k,v in json.loads((root/(label+'-sources.json')).read_text(encoding='utf8')).items()}
    for relative in ('scripts/control/informatron.lua','scripts/control/factory-passage.lua','lib/factory-passage-config.lua'):
        path='exotic-space-industries-remembrance/'+relative
        assert sources[path]==sha(repo/path),path
    assert sources['exotic-space-industries-remembrance/factory-passage-guide-qc.lua']==sha(pathlib.Path(__file__).with_name('guide.lua'))
    frames=json.loads((root/(label+'-frames.json')).read_text(encoding='utf8'))
    assert [f['scene'] for f in frames]==['top','scanner','settings']
    assert frames[0]['sha256']!=frames[2]['sha256'],'Scroll captures did not change'
    for frame in frames: assert sha(pathlib.Path(frame['absolute_path']))==frame['sha256']
output=dict(passed=True,engine='2.1.24',required_labels=labels,locales=8,cases=10,captures=30,
            boundary='Programmatic native Informatron navigation; not physical recipe-picker or two-client evidence.')
(root/'guide-acceptance.json').write_text(json.dumps(output,indent=2),encoding='utf8')
print(json.dumps(output))

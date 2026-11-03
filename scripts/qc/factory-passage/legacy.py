"""Native adoption of the frozen old owner's actual populated benchmark save."""
import argparse,json,pathlib,runpy,shutil
support=runpy.run_path(str(pathlib.Path(__file__).with_name('observer-run.py')))
p=argparse.ArgumentParser();p.add_argument('--context',type=pathlib.Path,required=True);a=p.parse_args()
r=json.loads(a.context.read_text(encoding='utf-8-sig'));helper=pathlib.Path(r['mods'])/r['helper']
control=helper/'control.lua';original=control.read_bytes();original_context=a.context.read_bytes()
try:
    owner=pathlib.Path('scripts/control/factory-passage.lua')
    assert support['sha'](helper/owner)==support['sha'](support['ROOT']/'exotic-space-industries-remembrance'/owner)
    shutil.copy2(pathlib.Path(__file__).with_suffix('.lua'),helper/'legacy-suite.lua')
    control.write_text('require("legacy-suite")\n',encoding='utf8')
    r['performance']=0;a.context.write_text(json.dumps(r,indent=2))
    save=pathlib.Path(r['write_data'])/'observers-1000-10-256-1-baseline-settled.zip'
    result=support['run'](a.context,r,'observer-legacy',save,'observer-legacy',1210)
    assert result['passed'] and all(c['passed'] for c in result['checks'])
    (pathlib.Path(r['evidence'])/'observer-legacy-acceptance.json').write_text(json.dumps(dict(passed=True,required_labels=['observer-legacy'],checks=len(result['checks'])),indent=2))
    print(json.dumps(dict(passed=True,checks=len(result['checks']))))
finally:
    control.write_bytes(original);a.context.write_bytes(original_context)

"""Exercise real ESIR recipe owners and render the new Administration counts."""
import argparse, hashlib, json, pathlib, runpy, shutil, subprocess
support=runpy.run_path(str(pathlib.Path(__file__).with_name('observer-run.py')))
def main():
    p=argparse.ArgumentParser();p.add_argument('--context',required=True,type=pathlib.Path);p.add_argument('--accept-existing',action='store_true');a=p.parse_args()
    support['ps'](a.context,'Configure','-PipeMode','esir','-Render','-Actors')
    r=json.loads(a.context.read_text(encoding='utf-8-sig'));evidence=pathlib.Path(r['evidence'])
    main=pathlib.Path(r['mods'])/'exotic-space-industries-remembrance';helper=pathlib.Path(r['mods'])/r['helper']
    control=main/'control.lua';helper_control=helper/'control.lua';original=control.read_bytes();original_helper=helper_control.read_bytes()
    try:
        shutil.copy2(pathlib.Path(__file__).with_suffix('.lua'),main/'factory-passage-writer-qc.lua')
        control.write_bytes(original+b'\nrequire("factory-passage-writer-qc").configure(passage_recipe_changed)\n')
        helper_control.write_text('-- Native owner fixture is dispatched inside the private main copy.\n')
        save=pathlib.Path(r['write_data'])/'full-esir-settled.zip'
        result=json.loads((evidence/'observer-writers.json').read_text()) if a.accept_existing else support['run'](a.context,r,'observer-writers',save,'observer-writers',80,True)
        assert result['passed'] and all(c['passed'] for c in result['checks'])
        assert len({c['case'] for c in result['callbacks']})>=6
        sources={k.replace('\\','/'):v for k,v in json.loads((evidence/'observer-writers-sources.json').read_text()).items()}
        assert sources['exotic-space-industries-remembrance/factory-passage-writer-qc.lua']==support['sha'](pathlib.Path(__file__).with_suffix('.lua'))
        owner='exotic-space-industries-remembrance/scripts/control/factory-passage.lua'
        expected=support['sha'](support['ROOT']/owner)
        assert sources[owner]==expected
        (evidence/'observer-writers-acceptance.json').write_text(json.dumps(dict(passed=True,engine='2.1.24',required_labels=['observer-writers'],checks=len(result['checks']),owner_sha256=expected,callbacks=result['callbacks']),indent=2))
        print(json.dumps(dict(passed=True,checks=len(result['checks']),cases=sorted({c['case'] for c in result['callbacks']}))))
    finally:
        control.write_bytes(original);helper_control.write_bytes(original_helper)
if __name__=='__main__':main()

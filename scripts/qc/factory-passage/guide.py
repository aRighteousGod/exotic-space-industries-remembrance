"""Render the real Informatron guide in eight native locales, with pure-state checks."""
import argparse,json,pathlib,re,runpy,shutil
support=runpy.run_path(str(pathlib.Path(__file__).with_name('observer-run.py')))
def main():
    p=argparse.ArgumentParser();p.add_argument('--context',type=pathlib.Path,required=True)
    p.add_argument('--locales',default='en,de,fr,ja,pl,ru,zh-CN,zh-TW')
    p.add_argument('--mode',choices=('esir','vanilla','squeak-through'),default='esir')
    p.add_argument('--disabled',action='store_true');a=p.parse_args()
    support['ps'](a.context,'Configure','-PipeMode',a.mode,'-Render','-Actors',*(['-Disabled'] if a.disabled else []))
    tag='disabled' if a.disabled else a.mode
    r=json.loads(a.context.read_text(encoding='utf-8-sig'));main=pathlib.Path(r['mods'])/'exotic-space-industries-remembrance'
    helper=pathlib.Path(r['mods'])/r['helper'];control=main/'control.lua';hc=helper/'control.lua';cfg=pathlib.Path(r['config'])
    original,original_helper,original_config=control.read_bytes(),hc.read_bytes(),cfg.read_text(encoding='utf-8-sig')
    labels=[];results=[]
    try:
        shutil.copy2(pathlib.Path(__file__).with_suffix('.lua'),main/'factory-passage-guide-qc.lua')
        control.write_bytes(original+b'\nrequire("factory-passage-guide-qc")\n');hc.write_text('-- Guide fixture lives in private main copy.\n')
        for locale in a.locales.split(','):
            content=original_config
            if '[general]' not in content:content+='\n[general]\n'
            if re.search(r'(?m)^\s*;?\s*locale\s*=',content):content=re.sub(r'(?m)^\s*;?\s*locale\s*=.*$',f'locale={locale}',content)
            else:content=content.replace('[general]','[general]\nlocale='+locale)
            cfg.write_text(content,encoding='utf8')
            label='guide-'+tag+'-'+locale
            result=support['run'](a.context,r,label,pathlib.Path(r['write_data'])/'full-esir-settled.zip','guide',80,True)
            assert result['locale']==locale and all(c['passed'] for c in result['checks'])
            assert result['status']['configured_mode']==a.mode
            assert result['status']['inactive_reason']==('master-disabled' if a.disabled else 'active' if a.mode=='esir' else 'pipe-mode')
            labels.append(label);results.append(dict(locale=locale,checks=len(result['checks']),translations=len(result['translations'])))
            print(json.dumps(results[-1]),flush=True)
        (pathlib.Path(r['evidence'])/('guide-'+tag+'-acceptance.json')).write_text(json.dumps(dict(passed=True,required_labels=labels,results=results),indent=2))
    finally:
        control.write_bytes(original);hc.write_bytes(original_helper);cfg.write_text(original_config,encoding='utf8')
if __name__=='__main__':main()

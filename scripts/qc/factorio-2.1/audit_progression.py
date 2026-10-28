"""Check final technology prerequisites, science identities and native lab coverage.

This deliberately does not call a prerequisite graph a playable research route:
science manufacturing, surface access and resource acquisition need other evidence.
"""
import argparse
import hashlib
import json
from pathlib import Path

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('inventory',type=Path)
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args()
data=json.loads(args.inventory.read_text(encoding='utf-8'))
technologies=data['technology']
enabled={n:t for n,t in technologies.items() if t.get('enabled',True)}
reached=set()
while True:
    batch={name for name,tech in enabled.items() if name not in reached and set(tech.get('prerequisites',[]))<=reached}
    if not batch:break
    reached.update(batch)
unreachable={name:tech.get('prerequisites',[]) for name,tech in enabled.items() if name not in reached}
labs={name:set(lab.get('inputs',[])) for name,lab in data['lab'].items() if 'dummy' not in name}
science={}
errors=[]
for name,technology in enabled.items():
    ingredients=technology.get('unit',{}).get('ingredients',[])
    packs=[entry['name'] if isinstance(entry,dict) else entry[0] for entry in ingredients]
    matching=sorted(n for n,inputs in labs.items() if set(packs)<=inputs) if packs else []
    if packs and not matching:errors.append({'technology':name,'error':'No single real lab accepts the complete science set','packs':packs})
    for pack in packs:
        kind='tool' if pack in data.get('tool',{}) else 'item' if pack in data.get('item',{}) else None
        if not kind:errors.append({'technology':name,'error':'Missing science item/tool','pack':pack})
        science.setdefault(pack,{'type':kind,'technologies':[],'labs':sorted(n for n,inputs in labs.items() if pack in inputs)})['technologies'].append(name)
report={'passed':not unreachable and not errors,'enabled_technologies':len(enabled),'prerequisite_reachable':len(reached),
    'unreachable':unreachable,'errors':errors,'science':science,'labs':{n:sorted(v) for n,v in labs.items()},
    'input':str(args.inventory.absolute()),'input_sha256':hashlib.sha256(args.inventory.read_bytes()).hexdigest(),
    'evidence_class':'static native merged data',
    'limits':['No science-production bootstrap, full playthrough, optional progression or physical lab interaction claim']}
args.output.write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k not in ('science','labs','input','input_sha256')}))
if not report['passed']:raise SystemExit(1)

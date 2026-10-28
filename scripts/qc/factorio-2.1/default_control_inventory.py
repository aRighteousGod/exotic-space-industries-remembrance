"""Inventory newly defaulted prototype controls from the exact release data dump.

This reports applicability and explicit values; it does not infer behavioral
parity from omission. Nested type controls are reviewed in the semantic ledger.
"""
import argparse
import hashlib
import json
from pathlib import Path
import final_data
import classify_api_ledger


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--ledger',type=Path,required=True)
    p.add_argument('--dump',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    a=p.parse_args()
    docs_path=Path('.factorio-lua-docs-cache/2.1.23/prototype-api.json')
    docs=json.loads(docs_path.read_text())
    classes={r['name']:r for r in docs['prototypes']}
    ledger=json.loads(a.ledger.read_text())
    rows=[r for r in ledger['entries'] if r['change']=='added' and classify_api_ledger.classify_added(r)[0] in ('explicit-default-control-reviewed','implicit-default-control-reviewed')]
    assert len(rows)==143
    ancestry={}
    for name,c in classes.items():
        if 'typename' not in c: continue
        lineage={name}
        while c.get('parent'):
            lineage.add(c['parent']);c=classes[c['parent']]
        ancestry[classes[name]['typename']]=lineage
    fields={kind:{'name'} for kind in ancestry}
    for row in rows:
        category,owner,_,field=row['path'].split('.')
        if category!='prototypes': continue
        for kind,lineage in ancestry.items():
            if owner in lineage: fields[kind].add(field)
    final_data.FIELDS={k:v for k,v in fields.items() if len(v)>1}
    inventory=final_data.inventory(a.dump)
    result=[]
    source=list(Path('exotic-space-industries-remembrance').rglob('*.lua'))
    contents={str(f):f.read_text(encoding='utf-8-sig') for f in source}
    for row in rows:
        category,owner,_,field=row['path'].split('.')
        matched={}
        if category=='prototypes':
            for kind,lineage in ancestry.items():
                if owner not in lineage: continue
                for name,value in inventory.get(kind,{}).items():
                    matched[kind+'/'+name]={'explicit':field in value,'value':value.get(field)}
        hits=[]
        for file,text in contents.items():
            for number,line in enumerate(text.splitlines(),1):
                if field in line: hits.append({'file':file,'line':number,'source':line.strip()})
        result.append({'path':row['path'],'default':row.get('after',{}).get('default'),
                       'prototype_values':matched,'source_hits':hits})
    receipt={'application_version':docs['application_version'],
             'docs_sha256':hashlib.sha256(docs_path.read_bytes()).hexdigest(),
             'dump':str(a.dump),'rows':result,'behavioral_acceptance':False}
    a.output.write_text(json.dumps(receipt,indent=2),encoding='utf-8')
    for row in result:
        values=row['prototype_values']
        explicit=[v['value'] for v in values.values() if v['explicit']]
        unique=sorted({json.dumps(v,sort_keys=True) for v in explicit})
        print(row['path'],f"applicable={len(values)} explicit={len(explicit)}",'values='+str(unique)[:180],f"source_hits={len(row['source_hits'])}")


if __name__=='__main__':
    main()

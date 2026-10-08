"""Selective mmap audit of the final dump, keeping only requested prototypes."""
from pathlib import Path
import hashlib
import json
import mmap
import re
import sys

ROOT=Path(__file__).resolve().parents[3]
PACK=ROOT/'exotic-space-industries-remembrance'
DUMP=Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/'.factorio-qc/terrain-evolution/final-data/script-output/data-raw-dump.json'
POLICY=PACK/'lib/terrain-policy.lua'
report={'dump':str(DUMP),'dump_bytes':DUMP.stat().st_size,'policy_sha256':hashlib.sha256(POLICY.read_bytes()).hexdigest()}
source=POLICY.read_text(encoding='utf-8')
edges=dict(re.findall(r'\["([^"\n]+)"\]\s*=\s*"([^"\n]+)"',source.split('model.planets',1)[0]))

with DUMP.open('rb') as handle,mmap.mmap(handle.fileno(),0,access=mmap.ACCESS_READ) as mm:
    headers=list(re.finditer(rb'^  "([^"\r\n]+)":',mm,re.M))
    spans={m.group(1).decode(): (m.end(),headers[i+1].start() if i+1<len(headers) else len(mm)) for i,m in enumerate(headers)}
    def names(category):
        start,end=spans[category]
        return [m.group(1).decode() for m in re.compile(rb'^    "([^"\r\n]+)":',re.M).finditer(mm,start,end)]
    def record(category,name):
        start,end=spans[category]
        prefix=re.compile(rb'^    "'+re.escape(name.encode())+rb'":\s*',re.M).search(mm,start,end)
        if not prefix:return None
        following=re.compile(rb'^    (?:"[^"\r\n]+":|\},?\s*$)',re.M).search(mm,prefix.end(),end)
        # A prototype closes at four-space indentation. Never decode the category.
        assert following and mm[following.start():following.start()+5]==b'    }'
        return json.loads(mm[prefix.end():following.end()].rstrip().rstrip(b','))
    tiles=set(names('tile'))
    valid={a:b for a,b in edges.items() if a in tiles and b in tiles}
    missing_target=[{'source':a,'target':b} for a,b in edges.items() if a in tiles and b not in tiles]
    absent_source=[{'source':a,'target':b,'target_present':b in tiles} for a,b in edges.items() if a not in tiles]
    max_path=0;cycles=[]
    for start in valid:
        seen=set();cursor=start
        while cursor in valid:
            if cursor in seen:cycles.append(start);break
            seen.add(cursor);cursor=valid[cursor]
        max_path=max(max_path,len(seen))
    report['tiles']={'loaded_count':len(tiles),'declared_edges':len(edges),'compiled_edges':len(valid),
        'missing_target_for_loaded_source':sorted(missing_target,key=lambda x:x['source']),
        'absent_sources':sorted(absent_source,key=lambda x:x['source']),
        'max_edge_path':max_path,'cycles':cycles}
    fire=record('fire','ei-ecology-fire')
    selected=['name','initial_lifetime','maximum_lifetime','lifetime_increase_by','maximum_spread_count',
        'spawn_entity','tree_dying_factor','spread_delay','spread_delay_deviation','on_fuel_added_action',
        'on_damage_tick_effect','damage_per_tick','emissions_per_second']
    report['contained_fire']={k:fire.get(k,'<absent>') for k in selected}
    report['contained_fire']['contract_pass']=fire.get('maximum_spread_count')==0 and fire.get('spawn_entity') is None \
        and fire.get('initial_lifetime')==600 and fire.get('maximum_lifetime')==600 and fire.get('lifetime_increase_by')==0
    report['planets']={}
    for name in ['nauvis','gaia','vulcanus','gleba','fulgora','aquilo']:
        planet=record('planet',name)
        if not planet:report['planets'][name]={'missing':True};continue
        report['planets'][name]={k:planet.get(k,'<absent>') for k in ['distance','orientation','solar_power_in_space','magnitude','gravity_pull','orbit','surface_properties']}
    natural={f'tree-{i:02}' for i in range(1,10)}|{f'ei-gaia-tree-{i:02}' for i in range(1,7)}
    natural.update(re.findall(r'model\.natural_trees\["([^"]+)"\]',source))
    natural.update(['dry-tree','dead-dry-hairy-tree','dead-grey-trunk','dead-tree-desert','dry-hairy-tree'])
    gleba_block=source.split('model.gleba_trees={',1)[1].split('}',1)[0]
    natural.update(re.findall(r'([a-z]+)=true',gleba_block))
    natural.update(re.findall(r'\["([^\"]+)"\]=true',gleba_block))
    tree_names=set(names('tree'))
    report['tree_allowlist']={'declared_count':len(natural),'present_count':len(natural & tree_names),'missing':sorted(natural-tree_names)}
    drills=['ei-burner-quarry','ei-steam-quarry','ei-electric-quarry','big-mining-drill']
    report['drills']={n:n in set(names('mining-drill')) for n in drills}

def locale(path):
    values={};duplicates=[];section='';raw=path.read_bytes();text=raw.decode('utf-8-sig')
    for number,line in enumerate(text.splitlines(),1):
        if line.startswith('[') and line.endswith(']'):section=line[1:-1]
        elif '=' in line and not line.startswith(('#',';')):
            key,value=line.split('=',1);full=section+'.'+key
            if full in values:duplicates.append([full,number])
            values[full]=value
    bad=[{'line':i,'text':line} for i,line in enumerate(text.splitlines(),1)
        if '\ufffd' in line or re.search('[\u0080-\u009f]',line) or any(token in line for token in ['Ã','Â','â€','ðŸ','ãƒ','ã‚'])]
    return values,{'keys':len(values),'bytes':len(raw),'duplicates':duplicates,'suspicious_encoding':bad,
        'bom':raw.startswith(b'\xef\xbb\xbf'),'sha256':hashlib.sha256(raw).hexdigest()}
baseline,english=locale(PACK/'locale/en/terrain-evolution.cfg')
english_catalog={}
for path in (PACK/'locale/en').glob('*.cfg'):english_catalog.update(locale(path)[0])
report['locales']={}
for code in ['en','fr','ja','pl','ru','zh-CN','zh-TW']:
    values,result=locale(PACK/f'locale/{code}/terrain-evolution.cfg')
    result['missing_keys']=sorted(set(baseline)-set(values))
    result['extra_keys']=sorted(set(values)-set(baseline))
    result['unanchored_extra_keys']=sorted(set(result['extra_keys'])-set(english_catalog))
    result['parameter_mismatches']=[key for key,value in values.items() if key in baseline and
        sorted(re.findall(r'__\d+__',value))!=sorted(re.findall(r'__\d+__',baseline[key]))]
    result['english_identical']=[key for key,value in values.items() if code!='en' and baseline.get(key)==value
        and not key.startswith(('mod-setting-name.ei-terrain-planet-','ei-terrain.status-TerrainEvolution','ei-terrain.status-diurnal-dynamics'))]
    # Confirm this sidecar does not override any same-language existing key.
    overlaps=[]
    for sibling in (PACK/f'locale/{code}').glob('*.cfg'):
        if sibling.name=='terrain-evolution.cfg':continue
        sibling_values,_=locale(sibling)
        overlaps.extend({'key':key,'file':sibling.name} for key in values.keys() & sibling_values.keys())
    result['other_file_duplicates']=overlaps
    report['locales'][code]=result

out=ROOT/'.factorio-qc/terrain-evolution/final-data-audit.json'
out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
locale_errors={code:sum(len(values[key]) for key in ('missing_keys','unanchored_extra_keys','duplicates',
    'suspicious_encoding','parameter_mismatches','other_file_duplicates')) for code,values in report['locales'].items()}
passed=not missing_target and not cycles and report['contained_fire']['contract_pass'] \
    and not report['tree_allowlist']['missing'] and all(report['drills'].values()) and not any(locale_errors.values())
print(json.dumps({'all_pass':passed,'report':str(out),'loaded_edges':len(valid),'missing_targets':len(missing_target),
    'tree_allowlist':report['tree_allowlist'],'locale_errors':locale_errors},indent=2))
if not passed:raise SystemExit(1)

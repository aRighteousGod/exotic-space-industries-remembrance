"""Live-source contract checks for ESIR alerts; run from any directory."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
MOD = ROOT / 'exotic-space-industries-remembrance'
LUA = ROOT / '.tools/lua-5.4.8/lua54.exe'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--icons-dir', type=Path, default=ROOT / 'exotic-space-industries-remembrance-graphics-6/graphics/gui/alerts')
parser.add_argument('--sources-dir', type=Path, default=ROOT / '.codex/esir/asset-generators/alert-icons/sources')
args = parser.parse_args()
code = '''package.path='exotic-space-industries-remembrance/?.lua;'..package.path
local c=require('lib/alert-catalog'); local settings=c.setting_definitions()
for i,e in ipairs(c.entries) do local s=settings[i]
assert(s.type=='bool-setting' and s.setting_type=='runtime-per-user' and s.hidden==false)
assert(type(e.default_enabled)=='boolean' and s.default_value==e.default_enabled)
print(table.concat({e.id,e.channel,e.setting_name,tostring(e.default_enabled),e.icon_signal,e.localised_name[1],e.localised_description[1]},'|')) end'''
result = subprocess.run([str(LUA), '-'], input=code, cwd=ROOT, text=True, capture_output=True, check=True)
rows = [line.split('|') for line in result.stdout.splitlines()]
assert len(rows) >= 27, 'Current alert types disappeared'
for field in (0, 2, 4):
    assert len({row[field] for row in rows}) == len(rows), f'Duplicate identity field {field}'
locale = {}
for file in (MOD / 'locale/en').glob('*.cfg'):
    section = ''
    for line in file.read_text(encoding='utf-8-sig').splitlines():
        if line.startswith('[') and line.endswith(']'): section = line[1:-1]
        elif '=' in line and not line.startswith(('#', ';')):
            key, value = line.split('=', 1); locale[f'{section}.{key}'] = value
for alert_id, channel, setting, default, signal, name, description in rows:
    assert locale.get(name) and locale.get(description), f'Missing locale: {alert_id}'
    for set_id in ('original','svg','rendered','vanilla'):
        folder=args.icons_dir if set_id=='original' else args.icons_dir/set_id
        path=folder/f'{alert_id}.png'
        with Image.open(path) as im:
            assert im.size==(128,128) and im.mode=='RGBA',f'Invalid icon: {path}'
            assert im.getextrema()[3][0]==0 and im.getextrema()[3][1]==255,f'No transparency: {path}'
        source=args.sources_dir/f'{alert_id}.svg' if set_id=='original' else args.sources_dir/set_id/f'{alert_id}.{ "png" if set_id=="rendered" else "svg"}'
        assert source.is_file(),f'Missing actual source: {source}'
        if set_id!='rendered':ET.parse(source)
        else:
            with Image.open(source) as im:
                assert im.size==(1254,1254) and im.mode=='RGBA',f'Invalid rendered original: {source}'
ids = {r[0] for r in rows}
digest=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
for set_id in ('svg','rendered','vanilla'):
    manifest=json.loads((args.sources_dir/set_id/'export-manifest.json').read_text(encoding='utf-8'))
    assert manifest['set_id']==set_id and set(manifest['icons'])==ids
    assert {p.stem for p in (args.icons_dir/set_id).glob('*.png')}==ids,f'Unexpected shipping files: {set_id}'
    for name,entry in manifest['icons'].items():
        assert digest(args.icons_dir/set_id/f'{name}.png')==entry['png_sha256'],f'Changed shipping {set_id}/{name}'
        ext='png' if set_id=='rendered' else 'svg'
        assert digest(args.sources_dir/set_id/f'{name}.{ext}')==entry['source_sha256'],f'Changed source {set_id}/{name}'
original=json.loads((args.sources_dir/'original/manifest.json').read_text(encoding='utf-8'))
for path,expected in original['files'].items():
    # Keep historical source paths in the manifest while checking the current owner.
    current_path=path.replace('exotic-space-industries-remembrance/graphics/',
                              'exotic-space-industries-remembrance-graphics-6/graphics/',1)
    assert digest(ROOT/current_path)==expected,f'Original changed: {path}'
provenance=json.loads((args.sources_dir/'rendered/provenance.json').read_text(encoding='utf-8'))
assert set(provenance['icons'])==ids
assert not list((args.sources_dir/'rendered').glob('*.svg')),'Raster artwork must not have fabricated SVG masters'
for name,entry in provenance['icons'].items():
    for field in ('source','prompt'):
        assert digest(ROOT/entry[field])==entry[field+'_sha256'],f'Changed rendered {field}: {name}'
    if entry.get('correction'):
        for field in ('input','prompt'):
            assert digest(ROOT/entry['correction'][field])==entry['correction'][field+'_sha256']
for entry in provenance['generation_evidence']:
    assert digest(ROOT/entry['path'])==entry['sha256'],'Changed generation evidence'

# Execute the stage-safe public module, checking the actual selectors/prototypes.
set_code='''package.path='exotic-space-industries-remembrance/?.lua;'..package.path
local c=require('lib/alert-catalog')
package.loaded['__exotic-space-industries-remembrance__/lib/alert-catalog']=c
package.loaded['__exotic-space-industries-remembrance__/lib/lib']=require('lib/lib')
local a=require('lib/alert-icon-sets')
local expected={original=true,svg=true,rendered=true,vanilla=true}; local seen={}
for _,id in ipairs(a.builtin_ids) do assert(expected[id] and not seen[id]); seen[id]=true end
for id in pairs(expected) do assert(seen[id]) end
local settings={}; for _,s in ipairs(a.setting_definitions()) do settings[s.name]=s end
local personal=settings['ei-alert-icon-set'];local default=settings['ei-alert-icon-set-default']
assert(personal.type=='string-setting' and personal.setting_type=='runtime-per-user' and not personal.hidden)
assert(personal.default_value=='startup-default')
assert(default.type=='string-setting' and default.setting_type=='startup' and default.default_value=='rendered')
for _,s in ipairs{personal,default} do
 local values={};for _,v in ipairs(s.allowed_values) do assert(not values[v]);values[v]=true end
 for id in pairs(expected) do assert(values[id]) end
 assert(#s.allowed_values==#a.builtin_ids+(s==personal and 1 or 0))
 for _,v in ipairs(s.allowed_values) do print('LOCALE|string-mod-setting.'..s.name..'-'..v) end
 print('LOCALE|mod-setting-name.'..s.name);print('LOCALE|mod-setting-description.'..s.name)
end
local signals={};for _,p in ipairs(a.builtin_prototypes()) do
 assert(p.type=='virtual-signal' and p.hidden==true and p.hidden_in_factoriopedia==true and p.icon_size==128)
 assert(not signals[p.name]);signals[p.name]=p
end
local count=0
for _,id in ipairs(a.builtin_ids) do for _,e in ipairs(c.entries) do
 local name=a.signal_name(id,e.id);local p=signals[name];assert(p,'Missing signal '..name)
 local suffix=(id=='original' and '' or id..'/')..e.id..'.png'
 assert(p.icon=='__exotic-space-industries-remembrance-graphics-6__/graphics/gui/alerts/'..suffix)
 assert(name==(id=='original' and e.icon_signal or 'ei-alert-set-'..id..'__'..e.id))
 count=count+1
end end
local actual=0;for _ in pairs(signals) do actual=actual+1 end;assert(actual==count and count==#c.entries*#a.builtin_ids)
print('SIGNALS|'..count)'''
set_result=subprocess.run([str(LUA),'-'],input=set_code,cwd=ROOT,text=True,capture_output=True)
assert set_result.returncode==0,set_result.stderr
for line in set_result.stdout.splitlines():
    if line.startswith('LOCALE|'):assert locale.get(line.split('|',1)[1]),f'Missing selector locale: {line}'
native = re.compile(r'\.(?:add_alert|add_custom_alert|remove_alert)\s*(?:\(|\{)')
emit = re.compile(r'\.(?:record_incident|set_condition)\(\s*["\'](?:operational|ecology)["\']\s*,\s*(?:[^,\n]+,\s*)?["\']([^"\']+)["\']')
for path in MOD.rglob('*.lua'):
    source = path.read_text(encoding='utf-8-sig')
    if native.search(source): assert path == MOD / 'lib/alerts.lua', f'Native alert outside handler: {path}'
    for match in emit.finditer(source):
        value = match.group(1)
        if value != 'ecology-': assert value in ids, f'Undeclared emitted alert {value}: {path}'
handler = (MOD / 'lib/alerts.lua').read_text(encoding='utf-8')
assert 'if not setting or setting.value ~= true then return false end' in handler, 'Missing-setting fail-closed guard removed'
prototype = (MOD / 'prototypes/alerts.lua').read_text(encoding='utf-8')
assert 'builtin_prototypes()' in prototype,'Prototype loader must use named-set definitions'
assert 'require("lib/alert-catalog").setting_definitions()' in (MOD / 'settings.lua').read_text(encoding='utf-8')
print(f'PASS {len(rows)} catalogue settings, selectors, {len(rows)*4} named signals/Graphics 6 PNGs, actual sources/provenance, Original preservation and native-call ownership')

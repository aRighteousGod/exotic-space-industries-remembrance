"""Prepare the approved Quality-aware buffer policy patch, without editing Lua."""
import argparse
import difflib
import json
from pathlib import Path
from luaparser import ast
from luaparser.astnodes import Number, Table
from prepare_fluid_buffers import fields, key

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
patch=['*** Begin Patch'];records=[];files=0
for path in Path('exotic-space-industries-remembrance').rglob('*.lua'):
    source=path.read_text(encoding='utf-8-sig')
    if 'fluidbox_multiplier' not in source or path.name=='recipe-buffer-sizing.lua':continue
    edits=[]
    for node in ast.walk(ast.parse(source)):
        if not isinstance(node,Table):continue
        f=fields(node)
        if 'fluidbox_multiplier' not in f:continue
        value=f['fluidbox_multiplier'].value
        if not isinstance(value,Number):continue
        if path.name=='railgun-cooling.lua' and node.first_token.line<100:continue
        assert key(f['type'].value)=='fluid'
        assert value.n in (1,2,9),(path,node.first_token.line,value.n)
        argument={1:'',2:'nil, true',9:'10'}[value.n]
        replacement='ei_lib.recipe_fluidbox_multiplier('+argument+')'
        edits.append((value.first_token.start,value.last_token.stop+1,replacement))
        records.append(dict(path=path.as_posix(),line=node.first_token.line,before=value.n,after=replacement))
    updated=source
    for start,end,replacement in sorted(edits,reverse=True):updated=updated[:start]+replacement+updated[end:]
    if path.name=='lib.lua':
        updated=updated.replace('typus == "fluid" and 2 or nil','typus == "fluid" and ei_lib.recipe_fluidbox_multiplier(nil, true) or nil')
        updated=updated.replace('fluid and 1 or nil','fluid and ei_lib.recipe_fluidbox_multiplier() or nil')
    if path.name in ('final-recipe-fixes.lua','krastorio-patches.lua'):
        updated=updated.replace('ingredient.fluidbox_multiplier = 1 end','ingredient.fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier() end')
        updated=updated.replace('result.fluidbox_multiplier = 2 end','result.fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier(nil, true) end')
    if updated==source:continue
    ast.parse(updated)
    files+=1;patch.append('*** Update File: '+path.as_posix())
    for line in list(difflib.unified_diff(source.splitlines(),updated.splitlines(),lineterm=''))[2:]:
        patch.append('@@' if line.startswith('@@') else line)
patch.append('*** End Patch')
(a.output/'policy.patch').write_text('\n'.join(patch)+'\n',encoding='utf-8')
(a.output/'inventory.json').write_text(json.dumps(dict(files=files,records=records,
    excluded='Locked railgun helper input/output remain explicit 1/2 with 15/30 amounts.'),indent=2),encoding='utf-8')
print(json.dumps(dict(files=files,literal_records=len(records),patch=str(a.output/'policy.patch'))))

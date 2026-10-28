"""Adapt the retained orbital cohort for connected native GUI and reload checks."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--run',type=Path,required=True)
p.add_argument('--refresh',action='store_true')
a=p.parse_args()
source=Path('.factorio-qc/ol21/mods/zzz-orbital-logistics-qc')
target=a.run/'mods/zzz-orbital-logistics-qc'
shutil.copytree(source,target,dirs_exist_ok=a.refresh)
control=target/'control.lua'
text=control.read_text(encoding='utf-8')
original=hashlib.sha256(control.read_bytes()).hexdigest()
text=text.replace('pcall(script.raise_event, defines.events.on_gui_opened, {','pcall(remote.call, "esir-orbital-gui-qc", "opened", {')
text=text.replace('pcall(script.raise_event, defines.events.on_gui_closed, {','pcall(remote.call, "esir-orbital-gui-qc", "closed", {')
# The retained helper predates the shipping section frames. Inspect the actual
# nested controls; do not mistake outdated fixture paths for absent widgets.
sections={
    'override-flow':'override-section','mode-flow':'mode-section',
    'focus-flow':'focus-section','release-selector-lease':'focus-section',
    'coordinator-flow':'coordinator-section','silo-dropdown':'binding-section',
    'binding-flow':'binding-section','oversize-flow':'oversize-section',
    'threshold-flow':'oversize-section',
}
for name,section in sections.items():
    old='root.body["'+name+'"]'
    assert old in text,name
    text=text.replace(old,'root.body["'+section+'"]["'+name+'"]')
needle='  return entity, unit_number\nend\n\nlocal function collect_gui_smoke'
assert text.count(needle)==1
text=text.replace(needle,'  if key == "coordinator" and not entity then\n    return get_gui_probe_target(state, force, "coordinator_b")\n  end\n'+needle)
needle='script.on_init(function()\n  build_scenario(game.tick)'
assert text.count(needle)==1
text=text.replace(needle,'script.on_init(function()\n  remote.call("freeplay", "set_skip_intro", true)\n  build_scenario(game.tick)')
text+='\n'+Path(__file__).with_name('orbital-client.lua').read_text()
control.write_text(text,encoding='utf-8')
selection=a.run/'mods/mod-list.json';j=json.loads(selection.read_text())
if not any(r['name']==target.name for r in j['mods']):j['mods'].append(dict(name=target.name,enabled=True))
selection.write_text(json.dumps(j),encoding='utf-8')
(a.run/'orbital-fixture-adapter.json').write_text(json.dumps(dict(original_sha256=original,adapted_sha256=hashlib.sha256(control.read_bytes()).hexdigest(),shipping_changes=False),indent=2),encoding='utf-8')

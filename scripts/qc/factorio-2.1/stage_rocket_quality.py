"""Adapt the retained 29-scenario rocket suite for 2.1 quality phase timing."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--run',type=Path,required=True)
p.add_argument('--refresh',action='store_true')
p.add_argument('--visual',action='store_true')
a=p.parse_args()
fixture=Path('scripts/qc/rocket-launch-pollution')
main=a.run/'mods/exotic-space-industries-remembrance'
if not a.refresh:
    subprocess.run([sys.executable,'-X','utf8','-B','scripts/qc/factorio-2.1/stage_owner.py',
        '--run',str(a.run),'--bridge',str(fixture/'instrument.lua')],check=True)
else:
    shutil.copy2('exotic-space-industries-remembrance/scripts/control/rocket-launch-pollution.lua',main/'scripts/control/rocket-launch-pollution.lua')
    (main/'control.lua').write_text(Path('exotic-space-industries-remembrance/control.lua').read_text(encoding='utf-8')+'\n'+(fixture/'instrument.lua').read_text(encoding='utf-8'),encoding='utf-8')
owner=main/'scripts/control/rocket-launch-pollution.lua'
s=owner.read_text(encoding='utf-8')
s=s.replace('surface.create_trivial_smoke{','rocket_qc_smoke(surface){')
s=s.replace('surface.pollute(launch.position, amount, LAUNCH_POLLUTION_SOURCE)',
    'rocket_qc_pollute(surface, launch.position, amount, LAUNCH_POLLUTION_SOURCE, current_tick)')
s=s.replace('return model','model._qc_retaliation = try_form_retaliation\nreturn model')
owner.write_text(s,encoding='utf-8')
instrument=main/'control.lua'
s=instrument.read_text(encoding='utf-8')
s=s.replace('row.particles = row.particles + 1','''row.particles = row.particles + 1
    row.smoke = row.smoke or {}
    local kind = row.smoke[spec.name] or {count=0,first=game.tick}
    kind.count=kind.count+1; kind.last=game.tick
    row.smoke[spec.name]=kind''')
instrument.write_text(s,encoding='utf-8')
s=s.replace('  row.emitted = row.emitted + amount','''  if row.emission_tick~=tick then row.emission_tick=tick;row.before_tick_total=row.emitted end
  row.emitted = row.emitted + amount''')
s=s.replace('or {emitted = activity.emitted, particles = activity.particles}',
    'or {emitted = activity.emitted, particles = activity.particles, graph_expected=activity.emission_tick==game.tick and activity.before_tick_total or activity.emitted}')
instrument.write_text(s,encoding='utf-8')
target=a.run/'mods/zzz-esir-rocket-pollution-qc'
target.mkdir(exist_ok=True)
shutil.copy2(fixture/'data-final-fixes.lua',target/'data-final-fixes.lua')
info=json.loads((fixture/'info.json').read_text());info['factorio_version']='2.1'
(target/'info.json').write_text(json.dumps(info,indent=2),encoding='utf-8')
s=(fixture/'control.lua').read_text(encoding='utf-8')
s=s.replace('close(graph, snap.activity.emitted)', 'close(graph, snap.activity.graph_expected)')
s=s.replace('row.name .. " graph equals physical emissions"','row.name .. " graph equals completed-tick emissions: "..graph.." / "..snap.activity.graph_expected')
s=s.replace('close(graph - row.graph_baseline, target)', 'close(snap.activity.emitted - row.graph_baseline, target)')
s=s.replace('  for _, spec in ipairs(specs) do','''  for _,quality in ipairs{"uncommon","rare","epic","legendary"} do
    for _,style in ipairs{"hybrid","plume","cinematic","spiral"} do
      specs[#specs+1]={quality.."-"..style,quality=quality,style=style}
    end
  end
  for _, spec in ipairs(specs) do''')
s=s.replace('position = {0, 0}, force = "player"}', 'position = {0, 0}, force = "player", quality=spec.quality or "normal"}')
s=s.replace('  row.ignition_tick = nil','''  row.ignition_tick = nil
  row.ascent_tick = nil
  row.engine_ticks = math.ceil(1/(event.rocket.prototype.engine_starting_speed
      *(1+event.rocket_silo.prototype.rocket_engine_starting_speed_modifier_per_quality_level*event.rocket_silo.quality.level)))''')
s=s.replace('row.expected / 812','row.expected * 330 / (812 * row.engine_ticks)')
s=s.replace('        if not row.ignition_tick then','''        if phase==defines.rocket_silo_status.arms_retract and not row.ascent_tick then
          row.ascent_tick=event.tick
          if not row.fallback then check(math.abs(row.ascent_tick-row.ignition_tick-row.engine_ticks)<=1,row.name.." native engine duration") end
        end
        if not row.ignition_tick then''')
s=s.replace('local target = row.expected * math.min((sampled_age + 1) / 812, 1)', '''local sampled_tick = row.ignition_tick + sampled_age
          local reference = row.ascent_tick and sampled_tick>=row.ascent_tick
              and (330+sampled_tick-row.ascent_tick+1)
              or (330*math.min((sampled_age+1)/row.engine_ticks,1))
          local target = row.expected * math.min(reference / 812, 1)''')
s=s.replace('if row.name == "hybrid" and game.is_multiplayer() then','if row.name == "hybrid" then')
s=s.replace('game.server_save("rocket-" .. checkpoint)','game.auto_save("rocket-" .. checkpoint)')
s=s.replace('local snap = call("snapshot", row.id, row.surface.index, true)', '''local snap = call("snapshot", row.id, row.surface.index, true)
      local plume=snap.activity.smoke and snap.activity.smoke["ei-rocket-launch-plume-smoke"]
      if (row.quality or row.name=="hybrid" or row.name=="plume" or row.name=="cinematic") and row.style~="spiral" then
        check(plume and plume.first==row.ascent_tick+239,row.name.." phase-aligned plume start")
        check(plume.last<=row.confirm_tick,row.name.." plume stops at confirmation")
      end''')
s=s.replace('emitted = snap.activity.emitted, particles = snap.activity.particles, emissions = snap.activity.emissions}',
    'emitted = snap.activity.emitted, particles = snap.activity.particles, emissions = snap.activity.emissions, smoke=snap.activity.smoke, ascent_tick=row.ascent_tick, engine_ticks=row.engine_ticks}')
if a.visual:s+='\n'+Path(__file__).with_name('rocket-quality-visual.lua').read_text(encoding='utf-8')
(target/'control.lua').write_text(s,encoding='utf-8')
selection=a.run/'mods/mod-list.json';j=json.loads(selection.read_text())
if not any(r['name']==target.name for r in j['mods']):j['mods'].append(dict(name=target.name,enabled=True))
selection.write_text(json.dumps(j),encoding='utf-8')
(a.run/'rocket-adapter.json').write_text(json.dumps(dict(original_sha256=hashlib.sha256((fixture/'control.lua').read_bytes()).hexdigest(),
    adapted_sha256=hashlib.sha256((target/'control.lua').read_bytes()).hexdigest(),scenarios=45),indent=2),encoding='utf-8')

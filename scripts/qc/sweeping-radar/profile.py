"""Inject profiler probes into an isolated staged module, never shipping code."""
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
stages = ["control", "wake", "geometry", "observation", "aggregate", "maintenance", "publish"]
for index, stage in enumerate(stages):
    field = "maintenance" if stage == "wake" else stage
    suffix = "-root.last.maintenance" if stage == "maintenance" else ""
    marker = f"    for _=1,config.budget.{field}{suffix} do"
    assert text.count(marker) == 1
    before = ""
    if index:
        before = f'    radar_qc_timer.stop();root.qc_profiles.{stages[index-1]}=radar_qc_timer\n'
    else:
        before = "    root.qc_profiles={}\n    local radar_qc_timer\n"
    text = text.replace(marker, before + "    radar_qc_timer=game.create_profiler()\n" + marker)
marker = "    if #root.transfer_order>0 then"
assert text.count(marker) == 1
profile_output = '''    radar_qc_timer.stop();root.qc_profiles.publish=radar_qc_timer
    if not root.qc_file then helpers.write_file("radar-stages.csv","tick,control,wake,geometry,observation,aggregate,maintenance,publish\\n",false);root.qc_file=true end
    local q=root.qc_profiles
    helpers.write_file("radar-stages.csv",{"",tostring(tick)..",",q.control,",",q.wake,",",q.geometry,",",q.observation,",",q.aggregate,",",q.maintenance,",",q.publish,"\\n"},true)
'''
text = text.replace(marker, profile_output + marker)
path.write_text(text, encoding="utf-8")

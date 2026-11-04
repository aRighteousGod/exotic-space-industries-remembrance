"""Run the optional actual-input turbine check in managed private staging."""
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'native-tests'))
from runner import execute_selection


def stage_mouse_fixture(main, helper, suite):
    (helper / 'integration.lua').write_text((HERE / 'manual.lua').read_text(encoding='utf-8'), encoding='utf-8')
    return 'Interactive mouse fixture; four real option changes, no synthetic GUI events'


if __name__ == '__main__':
    row = {'suite': 'combustion-turbine', 'profile': {'id': 'quality-enabled', 'quality': 'enabled', 'integration': True},
           'cases': ['reload'], 'deadline_ticks': 36000, 'timeout_seconds': 650, 'checkpoint_executor': 'graphical'}
    result = execute_selection([row], qualification=stage_mouse_fixture)
    print(json.dumps(result))

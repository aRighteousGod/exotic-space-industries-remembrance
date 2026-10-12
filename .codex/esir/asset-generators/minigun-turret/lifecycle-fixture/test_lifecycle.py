"""Focused offline contract tests; none constitutes native acceptance."""
import copy
import importlib.util
import json
from pathlib import Path
import shutil
import sys
import unittest
from uuid import uuid4

from PIL import Image, ImageDraw

REPO=next(root for root in Path(__file__).resolve().parents
          if (root/"exotic-space-industries-remembrance/info.json").is_file())
CONTRACT=REPO/".codex/esir/asset-generators/minigun-turret/firing-fixture"
sys.path.insert(0,str(CONTRACT))
spec=importlib.util.spec_from_file_location("minigun_lifecycle_analysis",Path(__file__).parent/"analyze_fixture.py")
a=importlib.util.module_from_spec(spec)
spec.loader.exec_module(a)


class LifecycleTests(unittest.TestCase):
    def setUp(self):
        self.root=REPO/"output/minigun-implementation/lifecycle-offline-tests"/("lifecycle-test-"+uuid4().hex)
        self.root.mkdir(parents=True)

    def tearDown(self):
        assert self.root.parent==REPO/"output/minigun-implementation/lifecycle-offline-tests" and self.root.name.startswith("lifecycle-test-")
        shutil.rmtree(self.root)

    def marker(self,index):
        image=Image.new("RGB",(256,384),(40,50,60));draw=ImageDraw.Draw(image)
        x,y=96,282
        draw.rectangle((x,y,x+5,y+11),fill=(255,0,255))
        draw.rectangle((x+58,y,x+63,y+11),fill=(0,255,255))
        for bit in range(3):
            left=x+12+bit*14
            draw.rectangle((left,y+2,left+9,y+9),fill="white" if index&(1<<bit) else "black")
        path=self.root/(str(index)+".png");image.save(path)
        return path

    def test_all_native_state_marker_codes(self):
        for state in range(8):
            self.assertEqual(a.decode(self.marker(state)),{"origin":[96,282],"state":state})

    def test_missing_and_ambiguous_markers_rejected(self):
        path=self.marker(1)
        image=Image.open(path);draw=ImageDraw.Draw(image)
        draw.rectangle((96,282,101,293),fill="black");image.save(path)
        with self.assertRaisesRegex(ValueError,"missing/ambiguous"):a.decode(path)
        path=self.marker(1)
        image=Image.open(path);draw=ImageDraw.Draw(image)
        draw.rectangle((110,285,115,290),fill=(128,128,128));image.save(path)
        with self.assertRaisesRegex(ValueError,"barcode bit"):a.decode(path)

    def row(self,kind="ammo_shortage"):
        row={"id":kind+"/preparing","kind":kind,"phase":"preparing","failures":[],
             "events":[{"kind":"intervention_command","tick":100},
                       {"kind":"effective_interruption","tick":100},
                       {"kind":"recovery_command","tick":190},
                       {"kind":"effective_recovery","tick":192}],
             "inserted":101,"removed":0,"remaining":100,"shots":1,"shot_ticks":[200],
             "observations":[{"tick":tick,"ammo":0,"energy":0,"disabled_by_script":True,
                              "disabled_by_control_behavior":True,"is_freezable":True,"frozen":True}
                             for tick in range(102,190)]}
        decoded={(row["id"],"baseline",99):{"state":1}}
        return row,decoded

    def test_blocked_native_conditions_and_recovery(self):
        for kind in ("ammo_shortage","energy_shortage","script_disable","circuit_disable","freeze_thaw"):
            row,decoded=self.row(kind)
            self.assertEqual(a.row_checks(row,{}, {},decoded),[])

    def test_wrong_actual_phase_rejected(self):
        row,decoded=self.row();decoded[row["id"],"baseline",99]["state"]=4
        self.assertIn("Actual interruption did not occur in the requested visible native phase",a.row_checks(row,{}, {},decoded))

    def test_unfrozen_native_flag_and_unblocked_shot_rejected(self):
        row,decoded=self.row("freeze_thaw")
        row["observations"][0]["frozen"]=False
        self.assertTrue(any("flag" in message for message in a.row_checks(row,{}, {},decoded)))
        row,decoded=self.row();row["shot_ticks"]=[130]
        self.assertTrue(any("fired while" in message for message in a.row_checks(row,{}, {},decoded)))
        self.assertTrue(any("did not resume" in message for message in a.row_checks(row,{}, {},decoded)))

    def test_save_load_cannot_pass_without_actual_replay(self):
        row,decoded=self.row("save_load")
        self.assertTrue(any("not resumed" in message for message in a.row_checks(row,{}, {},decoded)))

    def test_damage_graph_and_combat_changes_rejected(self):
        ammo={"action":{"type":"direct","action_delivery":{"type":"instant","target_effects":[{"type":"damage","damage":{"amount":8,"type":"physical"}}]}}}
        observed=copy.deepcopy(ammo)
        observed["action"]=[observed["action"],{"type":"direct","action_delivery":{"type":"instant","source_effects":[{"type":"script","effect_id":"mg-lifecycle-shot"}]}}]
        original={"name":"original","attack_parameters":{"range":32,"cooldown":.25},"max_health":1500}
        candidate=copy.deepcopy(original);candidate["name"]="candidate"
        audit={"original":original,"candidate":candidate,"original_ammo_type":ammo,
               "instrumented_ammo_type":observed,"observer_count":1}
        self.assertEqual(a.combat_audit(audit),[])
        audit["candidate"]["attack_parameters"]["range"]=33
        self.assertTrue(any("Range" in message for message in a.combat_audit(audit)))
        audit["instrumented_ammo_type"]["action"][0]["action_delivery"]["target_effects"][0]["damage"]["amount"]=9
        self.assertTrue(any("damage delivery" in message for message in a.combat_audit(audit)))

    def test_capture_path_traversal_rejected(self):
        for path in ("../capture.png","minigun-lifecycle/../../escape.png","C:/escape.png"):
            with self.assertRaises(ValueError):a.capture_path(self.root,path)


if __name__=="__main__":unittest.main(verbosity=2)

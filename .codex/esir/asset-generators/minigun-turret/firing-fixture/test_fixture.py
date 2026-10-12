"""Small offline checks for the fixture's evidence gates, not native validation."""
import hashlib
from contextlib import nullcontext
import json
import math
import shutil
from pathlib import Path
import unittest
from types import SimpleNamespace

import numpy as np
from PIL import Image

from analyze_fixture import contrast, decay_review, decode_direction, fs_path, image_review, late_residual_review, rgb, sha
from build_fixture import build, inverse_projection, marker, PILOT_DIRECTIONS
from fit_flash_origin import correlate, fit


class EvidenceChecks(unittest.TestCase):
    def scratch(self,label):
        repo=next(parent for parent in Path(__file__).resolve().parents
                  if (parent/'exotic-space-industries-remembrance/info.json').is_file())
        root=repo/'output/minigun-firing-offline-tests'
        root.mkdir(parents=True,exist_ok=True)
        destination=root/label
        destination.mkdir(parents=True,exist_ok=True)
        self.assertTrue(destination.resolve().is_relative_to(root.resolve()))
        # Reusable ignored artifacts avoid Windows TemporaryDirectory's private
        # mode-0700 ACL interaction with the sandbox identity. No recursive delete.
        return nullcontext(destination)

    def test_marker_all_directions_and_pilot(self):
        with self.scratch('markers') as directory:
            path=Path(directory)
            for directions in (list(range(256)),PILOT_DIRECTIONS):
                marker(path/'sheet.png',directions)
                sheet=Image.open(path/'sheet.png')
                for index,direction in enumerate(directions):
                    image=Image.new('RGB',(512,640))
                    tile=sheet.crop((index%16*72,index//16*12,index%16*72+72,index//16*12+12))
                    image.paste(tile.resize((144,24),Image.Resampling.NEAREST),(184,500))
                    image.save(path/'frame.png')
                    observed=decode_direction(path/'frame.png',{'zoom':2,'entity_center':[256,320],'marker_shift_tiles':[0,3]})
                    self.assertEqual(observed,direction)
                image.paste((0,0,0),(184,500,192,524))
                image.save(path/'damaged.png')
                with self.assertRaises(ValueError):
                    decode_direction(path/'damaged.png',{'zoom':2,'entity_center':[256,320],'marker_shift_tiles':[0,3]})

    def test_pilot_matrix_and_full_calibration_gate(self):
        with self.scratch('builder') as root:
            anchors={'source_sha256':'offline-unit-test-only','status':'synthetic_test_fixture',
                     'visual_anchors':[{'direction':direction,'visual_offset_tiles':[0,-2]} for direction in range(256)]}
            (root/'anchors.json').write_text(json.dumps(anchors),encoding='utf8')
            references=[]
            for profile in ('sd','hd'):
                image=root/'assets'/profile/'graphics/test.png'
                image.parent.mkdir(parents=True,exist_ok=True)
                Image.new('RGBA',(2,2),(90,80,70,255)).save(image)
                references.append('"__zzz-esir-minigun-firing__/candidate/'+profile+'/graphics/test.png"')
            (root/'candidate.lua').write_text('-- Synthetic offline images, not native metadata.\nreturn {'+','.join(references)+'}\n',encoding='utf8')
            args=SimpleNamespace(output=root/'pilot',anchors=root/'anchors.json',calibration=None,
                 candidate_data=root/'candidate.lua',candidate_assets=root/'assets',mechanical_data=None,
                 coverage='pilot',mode='off',profile='sd')
            plan=build(args)
            self.assertEqual(plan['config']['case_count'],89)
            self.assertEqual(len([row for row in plan['cases'] if row['kind']=='static']),88)
            self.assertEqual(len(plan['config']['ammo_names']),11)
            self.assertEqual(plan['cases'][-1]['rounds'],1024)
            self.assertEqual(plan['planned_wired_captures'],0)
            args.calibration_only=True
            plan=build(args)
            self.assertEqual(plan['config']['case_count'],8)
            self.assertEqual(plan['config']['ammo_names'],['piercing-rounds-magazine'])
            self.assertEqual(plan['benchmark_ticks'],1850)
            self.assertEqual(plan['planned_flash_template_atlases'],14)
            self.assertEqual(plan['maximum_moving_shot_captures'],0)
            self.assertEqual(plan['config']['assets_manifest_sha256'],sha(args.output/'candidate-assets-manifest.json'))
            args.compact_heading_templates=True
            plan=build(args)
            self.assertEqual(plan['planned_heading_template_atlases'],48)
            self.assertEqual(plan['heading_template_cells'],9)
            self.assertTrue(plan['config']['heading_templates'])
            self.assertTrue(all((args.output/f'graphics/compact-background-{role}.png').is_file() for role in ('a','b','c')))
            args.heading_templates=True
            with self.assertRaises(ValueError):build(args)
            args.compact_heading_templates=False
            args.heading_templates=True
            plan=build(args)
            self.assertEqual(plan['planned_heading_template_atlases'],224)
            self.assertTrue(plan['config']['heading_templates'])
            self.assertEqual(plan['planned_muzzle_clips']+plan['planned_direction_captures']+
                plan['planned_flash_template_atlases']+plan['planned_heading_template_atlases'],942)
            self.assertNotIn('circuit_connector', (args.output/'candidate-mechanical-data.lua').read_text())
            args.include_moving=True;args.include_wired_preview=True
            with self.assertRaises(ValueError):build(args)
            args.calibration_only=False
            plan=build(args)
            self.assertEqual(plan['config']['case_count'],89)
            self.assertEqual(plan['benchmark_ticks'],19870)
            self.assertEqual(plan['planned_wired_captures'],8)
            args.coverage='full'
            with self.assertRaises(ValueError):
                build(args)

    def test_inverse_is_an_explicit_roundtrip_hypothesis(self):
        for direction in range(256):
            heading=inverse_projection(direction)*math.tau
            rendered=math.atan2(math.sin(heading),math.sqrt(2)*math.cos(heading))/math.tau%1
            self.assertEqual(round(rendered*256)%256,direction)

    def test_coordinates_do_not_satisfy_image_review(self):
        with self.scratch('review') as directory:
            root=Path(directory)
            Image.new('RGB',(320,320)).save(root/'native.png')
            cap={'path':'native.png','zoom':2}
            self.assertIsNotNone(image_review({'origin_pixels':[160,160]},cap,root,[160,160],4))
            valid={'capture':'native.png','sha256':hashlib.sha256((root/'native.png').read_bytes()).hexdigest(),
                   'origin_pixels':[160,160],'native_visibility_confirmed':True}
            self.assertIsNone(image_review(valid,cap,root,[160,160],4))
            valid['origin_pixels']=[180,160]
            self.assertIsNotNone(image_review(valid,cap,root,[160,160],4))
            valid['origin_pixels']=[157,163]
            self.assertIsNotNone(image_review(valid,cap,root,[160,160],2))
            valid['origin_pixels']=[160,160]
            for invalid in (float('nan'), float('inf'), -float('inf')):
                valid['origin_pixels']=[invalid,160]
                self.assertIsNotNone(image_review(valid,cap,root,[160,160],2))
            valid['origin_pixels']=[160,160]
            valid['sha256']='stale-image'
            self.assertIsNotNone(image_review(valid,cap,root,[160,160],4))

    def test_contrast_cancels_static_background_difference(self):
        first=np.full((320,320,3),70,dtype=np.float32)
        blank=np.full((320,320,3),110,dtype=np.float32)
        self.assertEqual(contrast(first,blank,first,blank)[0]['pixels'],0)
        lit=first.copy();lit[158:162,158:162]+=100
        details,_=contrast(lit,blank,first,blank)
        self.assertEqual(details['pixels'],16)
        self.assertEqual(details['nearest_anchor_pixels'],0)

    def test_decay_review_binds_images_and_distinguishes_remote_particles(self):
        with self.scratch('decay-review') as root:
            captures={}
            image=Image.new('RGB',(320,320),(70,70,70))
            for offset in (-1,0,1,2,3,12,96):
                name=f'{offset}.png';image.save(root/name)
                captures[offset]={'path':name}
            entry={'first_appearance_and_decay_reviewed':True,'reviewed_captures':[
                {'shot_offset':offset,'capture':cap['path'],'sha256':sha(root/cap['path'])}
                for offset,cap in captures.items()]}
            self.assertIsNone(decay_review(entry,captures,root))
            image.putpixel((160,160),(255,255,255));image.save(root/'2.png')
            self.assertIsNotNone(decay_review(entry,captures,root))
            image=Image.new('RGB',(320,320),(70,70,70))
            image.putpixel((160,250),(255,255,255));image.save(root/'96.png')
            residual={'capture':'96.png','sha256':sha(root/'96.png'),
                'baseline_capture':'-1.png','baseline_sha256':sha(root/'-1.png'),
                'residual_is_not_muzzle_flash':True,
                'explanation':'Reviewed persistent particle far below the unchanged muzzle region.',
                'unchanged_muzzle_region':[96,96,224,197]}
            self.assertTrue(late_residual_review(residual,captures[96],captures[-1],root))
            image.putpixel((160,160),(255,255,255));image.save(root/'96.png')
            residual['sha256']=sha(root/'96.png')
            self.assertFalse(late_residual_review(residual,captures[96],captures[-1],root))

    def test_attachment_fit_uses_template_origin_not_bright_pixel_centroid(self):
        template=np.zeros((32,32),dtype=np.float32)
        template[8:14,18:27]=50
        template[17:23,10:14]=-30
        source=np.zeros((90,90),dtype=np.float32)
        source[37:69,12:44]=template
        measured=correlate(source,template)
        self.assertEqual(measured['origin_pixels'],[28,53])
        self.assertGreater(measured['score'],0.999)
        self.assertEqual(fit(np.zeros((90,90)),[])['status'],'no_native_signal')
        result=fit(source,[{'signal':template,'identity':{'variation':1}}])
        self.assertFalse(result['approved'])
        json.dumps(result)  # Alternatives must be serializable, not recursive.

    def test_extended_windows_paths_retain_and_read_native_images(self):
        with self.scratch('long-paths') as root:
            source=root/('source-'+('a'*75))/('native-'+('b'*75))
            fs_path(source).mkdir(parents=True,exist_ok=True)
            Image.new('RGB',(12,10),(37,52,99)).save(fs_path(source/'direction-prefire.png'))
            destination=root/('retained-'+('c'*75))/('review-'+('d'*75))
            shutil.copytree(fs_path(source),fs_path(destination),dirs_exist_ok=True)
            self.assertGreater(len(str((destination/'direction-prefire.png').absolute())),260)
            self.assertEqual(sha(source/'direction-prefire.png'),sha(destination/'direction-prefire.png'))
            self.assertEqual(rgb(destination/'direction-prefire.png')[0,0].tolist(),[37,52,99])


if __name__=='__main__':
    unittest.main()

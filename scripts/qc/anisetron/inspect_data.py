"""Selective audit of an installed Factorio pretty-printed final prototype dump."""
import argparse
import hashlib
import json
import mmap
from pathlib import Path
from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument('--dump', type=Path, required=True)
parser.add_argument('--repo', type=Path, default=Path('.'))
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--expected-legs', type=int, choices=(4,10), default=4)
args = parser.parse_args()
name = 'ei-anisetron'
gates = ['ei-gaian-saucer','ei-crystal-accumulator','ei-computing-unit',
    'ei-neodymium-magnet','ei-sus-plating','ei-high-energy-crystal','ei-electronic-parts','laser-weapons-damage-5','ei-singularity-lance']
with args.dump.open('rb') as stream, mmap.mmap(stream.fileno(),0,access=mmap.ACCESS_READ) as raw:
    def section(group):
        key = raw.find(f'\n  "{group}":'.encode())
        if key < 0: raise KeyError(group)
        start = raw.find(b'{',key)
        end = raw.find(b'\n  }',start)+4
        return start,end

    def prototype(group, identity):
        start,end = section(group)
        key = raw.find(f'    "{identity}":'.encode(),start,end)
        if key < 0: raise KeyError((group,identity))
        begin = raw.find(b'{',key)
        finish = raw.find(b'\n    }',begin)+6
        return json.loads(raw[begin:finish])

    start,end = section('technology')
    technologies = json.loads(raw[start:end])
    technology = technologies[name]
    vehicle = prototype('spider-vehicle',name)
    grid = prototype('equipment-grid',vehicle['equipment_grid'])
    gun = prototype('gun',name+'-beam-gun')['attack_parameters']
    ammo = prototype('ammo',name+'-crystal-charge')
    visual = prototype('beam',name+'-beam')
    crown = prototype('beam',name+'-crown-beam')
    trigger = prototype('beam',name+'-charge-trigger')
    hull = prototype('recipe',name)
    charge = prototype('recipe',name+'-crystal-charge')
    item = prototype('item-with-entity-data',name)
    assert set(technology['prerequisites']) == set(gates)
    pending, ancestors = [name],set()
    while pending:
        identity = pending.pop()
        if identity in ancestors: continue
        assert identity in technologies,identity
        ancestors.add(identity)
        pending.extend(technologies[identity].get('prerequisites',[]))
    assert not [x for x in ancestors if any(word in x for word in ('quantum','exotic','singularity-lance-'))]
    category = ammo['ammo_category']
    research_effects = {t['name']:effect['modifier'] for t in technologies.values() for effect in t.get('effects',[])
        if effect.get('ammo_category') == category and effect['type'] == 'ammo-damage'}
    assert set(research_effects) == {'laser-weapons-damage-6','laser-weapons-damage-7'}
    for key,value in research_effects.items():
        assert value == next(e['modifier'] for e in technologies[key]['effects'] if e.get('ammo_category') == 'ei-singularity-lance' and e['type']=='ammo-damage')
    assert not [t['name'] for t in technologies.values() for e in t.get('effects',[]) if e.get('ammo_category')==category and e['type']=='gun-speed']
    assert vehicle['energy_source']['type']=='void' and vehicle['movement_energy_consumption']=='750kW'
    assert vehicle['height']==1.8 and vehicle['inventory_size']==80 and vehicle['trash_inventory_size']==20
    anchors = vehicle['spider_engine']['legs']
    assert len(anchors)==args.expected_legs and vehicle['spider_engine'].get('walking_group_overlap',0)==0
    groups = [sum(a['walking_group']==g for a in anchors) for g in (1,2)]
    assert groups==[args.expected_legs//2]*2
    leg = prototype('spider-leg',name+'-leg')
    assert all(a['leg']==leg['name'] for a in anchors)
    assert leg['hidden'] and not leg['selectable_in_game'] and not leg.get('graphics_set')
    assert not leg['collision_mask']['layers']
    assert leg['initial_movement_speed']==leg['movement_acceleration']==.02
    expected_force = .2 if args.expected_legs==10 else prototype('spider-leg','ei-gaian-saucer-leg')['stretch_force_scalar']
    assert leg['stretch_force_scalar']==expected_force
    assert vehicle['torso_bob_speed']==1 and vehicle['torso_rotation_speed']==.005
    assert [grid['width'],grid['height']]==[12,8]
    assert gun['cooldown']==1200 and gun['range']==85 and gun['ammo_category']==category
    assert gun['range_mode']=='bounding-box-to-bounding-box'
    assert gun['turn_range']==1 and ammo['magazine_size']==1
    assert vehicle['graphics_set']['animation']['layers'][0]['direction_count']==128
    assert vehicle['graphics_set']['shadow_animation']['direction_count']==128
    delivery = ammo['ammo_type']['action']['action_delivery']
    effects = trigger['action']['action_delivery']['target_effects']
    assert delivery['beam']==trigger['name'] and delivery['duration']==1
    assert len(effects)==1 and effects[0]['type']=='script' and effects[0]['effect_id']==name+'-charge'
    assert not trigger['action_triggered_automatically'] and not visual.get('action')
    assert not visual['action_triggered_automatically']
    assert not crown.get('action') and not crown['action_triggered_automatically']
    assert crown['damage_interval']==visual['damage_interval']==12
    assert crown['width']==2*visual['width']
    fields = ammo['custom_tooltip_fields']
    assert len(fields)==10 and [float(x['value'][1]) for x in fields[:9]]==[20,320,160,12,2400,360,120,85,30]
    assert float(fields[1]['quality_values']['rare'][1])==512
    assert float(fields[2]['quality_values']['rare'][1])==256
    assert float(fields[4]['quality_values']['rare'][1])==3840
    assert all(isinstance(x['value'][1],str) for x in fields[:9])
    assert fields[9]['value']==['anisetron-stat.lance-upgrades-value']
    assert hull['energy_required']==120 and hull['category']=='crafting' and not hull['enabled']
    assert hull['surface_conditions']==[{'property':'gravity','min':15.5,'max':15.5}]
    assert {x['name']:x['amount'] for x in hull['ingredients']}=={
        'ei-gaian-saucer':1,'ei-crystal-accumulator':1,'ei-high-energy-crystal':160,
        'ei-sus-plating':250,'ei-computing-unit':60,'ei-alien-resin':220,'ei-magnet':150,'ei-singularity-lance':1}
    assert charge['energy_required']==10 and not charge['enabled'] and not charge.get('surface_conditions')
    assert {x['name']:x['amount'] for x in charge['ingredients']}=={
        'ei-high-energy-crystal':10,'ei-electronic-parts':2,'ei-sus-plating':2}
    unlocks = {x['recipe'] for x in technology['effects'] if x['type']=='unlock-recipe'}
    assert {hull['name'],charge['name']}<=unlocks
    references = set()
    def images(value):
        if isinstance(value,dict):
            for child in value.values(): images(child)
        elif isinstance(value,list):
            for child in value: images(child)
        elif isinstance(value,str) and value.startswith('__') and value.endswith('.png'):
            references.add(value)
    for value in (vehicle,ammo,item,technology,visual,crown,trigger): images(value)
    paths = []
    game_data = Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/data')
    for reference in sorted(references):
        pack,relative = reference[2:].split('__/',1)
        path = (game_data/pack/relative) if pack in ('core','base','space-age','quality','elevated-rails') else args.repo/pack/relative
        assert path.is_file(),reference
        with Image.open(path) as image:
            size = list(image.size)
        paths.append({'reference':reference,'size':size})
    report = {'pass':True,'dump':str(args.dump),'bytes':args.dump.stat().st_size,
        'research':{'prerequisites':gates,'laser_effects':research_effects,'ancestry_nodes':len(ancestors),'unit':technology['unit']},
        'weapon':{'category':category,'magazine_size':1,'cooldown':1200,'crown_range':85,'facade_range':30,
            'crown_arc_degrees':360,'facade_arc_degrees':120,'crown_contact':320,'facade_contact':160,'contacts_per_channel':100,'combined_charge_damage':48000,'body_directions':128,'tooltip_fields':fields,'cosmetic_action':None},
        'chassis':{'height':1.8,'trunk':80,'trash':20,'grid':[12,8],'void':True,
            'legs':args.expected_legs,'walking_groups':groups,'overlap':0,'response':.02,'stretch_force':expected_force},
        'recipes':{hull['name']:hull,charge['name']:charge},'assets':paths,
        'runtime_source_sha256':{str(path):hashlib.sha256(path.read_bytes()).hexdigest() for path in (
            args.repo/'exotic-space-industries-remembrance/lib/anisetron-config.lua',
            args.repo/'exotic-space-industries-remembrance/scripts/control/anisetron.lua',
            args.repo/'exotic-space-industries-remembrance/scripts/control/anisetron-visuals.lua',
            args.repo/'exotic-space-industries-remembrance/scripts/control/anisetron-mobility.lua',
            args.repo/'exotic-space-industries-remembrance/lib/anisetron-mobility-config.lua',
            args.repo/'exotic-space-industries-remembrance/lib/anisetron-visual-config.lua')}}
args.output.parent.mkdir(parents=True,exist_ok=True)
args.output.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'pass':True,'ancestry_nodes':len(ancestors),'png_paths':len(paths),'tooltip_fields':len(fields)}))

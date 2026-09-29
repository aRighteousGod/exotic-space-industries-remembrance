"""UV-preserving local rig for the inspected maximum-detail radar sources.

Source models remain unchanged. This partitions original triangles without
remeshing; new bearing geometry closes the mechanical boundary. Review renders
and the partition report are required before promoting any result.
"""
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path
import bpy
import numpy as np
from mathutils import Matrix

parser=argparse.ArgumentParser()
parser.add_argument('--asset', choices=['sweeping-radar','phased-array-radar'], required=True)
parser.add_argument('--seam', type=float)
parser.add_argument('--core-radius', type=float, default=0.43)
parser.add_argument('--core-top', type=float, default=-0.005)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
root=Path.cwd()/'output/meshy'/args.asset
source_path=root/'source/attempt-01.glb'
expected={'sweeping-radar':'7bcf55b384b853e7c760dbe8e3c7e39ee62095ce19c8f9daeb0106dcff1cf366',
          'phased-array-radar':'8239316631930f34d462d8a0e3d561ff7e78c32ebd71925c8945a16a09a2fd99'}
with source_path.open('rb') as stream:
    digest=hashlib.file_digest(stream,'sha256').hexdigest()
assert digest==expected[args.asset], 'Partition requires its inspected source'
bpy.ops.wm.open_mainfile(filepath=str(root/'inspection/inspection.blend'))
sources=[o for o in bpy.data.objects if o.type=='MESH']
assert len(sources)==1, 'Inspected source contract changed'
source=sources[0]
assert all(len(p.vertices)==3 for p in source.data.polygons), 'Expected triangle source'
positions=np.empty(len(source.data.vertices)*3,dtype=np.float32)
source.data.vertices.foreach_get('co',positions)
positions=positions.reshape((-1,3))
indices=np.empty(len(source.data.loops),dtype=np.int32)
source.data.loops.foreach_get('vertex_index',indices)
faces=indices.reshape((-1,3))
uv=np.empty(len(source.data.loops)*2,dtype=np.float32)
source.data.uv_layers.active.data.foreach_get('uv',uv)
uv=uv.reshape((-1,3,2))
centers=positions[faces].mean(axis=1)
radius=np.linalg.norm(centers[:,:2],axis=1)
advanced=args.asset=='phased-array-radar'
seam=args.seam if args.seam is not None else (-0.32 if advanced else -0.10)
fixed=(centers[:,2]<seam)
if advanced:
    fixed |= (radius<args.core_radius)&(centers[:,2]<args.core_top)
ground=float(positions[:,2].min())
rotor_vertices=np.unique(faces[~fixed])
radius_max=float(np.linalg.norm(positions[rotor_vertices,:2],axis=1).max())
fixed_vertices=np.unique(faces[fixed])
fixed_extent=float(np.abs(positions[fixed_vertices,:2]).max())
scale=min(1.40/radius_max,1.40/fixed_extent)
lift=0.045 if advanced else 0.010
report=dict(asset=args.asset,source_sha256=digest,source_faces=len(faces),seam_z=seam,
            central_fixed_radius=args.core_radius if advanced else None,
            central_fixed_top=args.core_top if advanced else None,scale=scale,ground=ground,
            rotor_lift=lift,groups=[],source_preserved=True,review_status='pending-render-review')
groups={'fixed':[],'rotor':[]}

def build(name, mask, rotating):
    selected=faces[mask]
    unique, local=np.unique(selected.reshape(-1),return_inverse=True)
    coords=positions[unique].copy()
    coords[:,2]-=ground
    if rotating: coords[:,2]+=lift
    coords*=scale
    mesh=bpy.data.meshes.new(name)
    mesh.vertices.add(len(unique));mesh.vertices.foreach_set('co',coords.reshape(-1))
    mesh.loops.add(local.size);mesh.loops.foreach_set('vertex_index',local)
    mesh.polygons.add(len(selected))
    mesh.polygons.foreach_set('loop_start',np.arange(len(selected),dtype=np.int32)*3)
    mesh.polygons.foreach_set('loop_total',np.full(len(selected),3,dtype=np.int32))
    mesh.polygons.foreach_set('use_smooth',np.ones(len(selected),dtype=bool))
    mesh.update()
    mesh.uv_layers.new(name='UVMap').data.foreach_set('uv',uv[mask].reshape(-1))
    mesh.materials.append(source.data.materials[0])
    if advanced and rotating:
        eligible=(radius[mask]>0.38)&(centers[mask,2]>-0.31)
        region=mesh.attributes.new('panel_emission_eligible','FLOAT','FACE')
        region.data.foreach_set('value',eligible.astype(np.float32))
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    groups['rotor' if rotating else 'fixed'].append(obj)
    report['groups'].append(dict(name=name,vertices=len(unique),faces=len(selected),
                                minimum=coords.min(axis=0).tolist(),maximum=coords.max(axis=0).tolist()))
    return obj

base=build('fixed_wired_base',fixed,False)
head=build('rotor_upper_assembly',~fixed,True)
bpy.data.objects.remove(source,do_unlink=True)

def material(name,color,metallic=0.6,roughness=0.42):
    mat=bpy.data.materials.new(name);mat.use_nodes=True
    node=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    node.inputs['Base Color'].default_value=(*color,1)
    node.inputs['Metallic'].default_value=metallic
    node.inputs['Roughness'].default_value=roughness
    return mat

steel=material('bearing_steel',(0.16,0.18,0.19))
dark=material('bearing_gap',(0.025,0.028,0.032),0.4)
def cylinder(name,radius,low,high,mat,rotating):
    z=(low+high)/2-ground+(lift if rotating else 0)
    bpy.ops.mesh.primitive_cylinder_add(vertices=96,radius=radius*scale,depth=(high-low)*scale,
                                      location=(0,0,z*scale))
    obj=bpy.context.object;obj.name=name;obj.data.materials.append(mat)
    groups['rotor' if rotating else 'fixed'].append(obj)
    return obj

joint=args.core_top if advanced else seam
cylinder('fixed_bearing_race',0.21 if advanced else 0.16,joint-0.025,joint+0.012,steel,False)
cylinder('fixed_bearing_gap',0.19 if advanced else 0.145,joint+0.01,joint+lift,dark,False)
cylinder('rotor_bearing_rim',0.20 if advanced else 0.155,joint-0.008,joint+0.014,steel,True)

if advanced:
    mat=head.data.materials[0].copy();mat.name='rotor_PBR_white_panel_emission'
    head.data.materials[0]=mat
    nodes=mat.node_tree.nodes;links=mat.node_tree.links
    principled=next(n for n in nodes if n.type=='BSDF_PRINCIPLED')
    albedo=principled.inputs['Base Color'].links[0].from_socket
    separate=nodes.new('ShaderNodeSeparateColor');separate.mode='RGB'
    links.new(albedo,separate.inputs['Color'])
    minimum=nodes.new('ShaderNodeMath');minimum.operation='MINIMUM'
    links.new(separate.outputs[0],minimum.inputs[0]);links.new(separate.outputs[1],minimum.inputs[1])
    minimum2=nodes.new('ShaderNodeMath');minimum2.operation='MINIMUM'
    links.new(minimum.outputs[0],minimum2.inputs[0]);links.new(separate.outputs[2],minimum2.inputs[1])
    threshold=nodes.new('ShaderNodeMath');threshold.operation='GREATER_THAN';threshold.inputs[1].default_value=0.42
    links.new(minimum2.outputs[0],threshold.inputs[0])
    region=nodes.new('ShaderNodeAttribute');region.attribute_name='panel_emission_eligible'
    multiply=nodes.new('ShaderNodeMath');multiply.operation='MULTIPLY'
    links.new(threshold.outputs[0],multiply.inputs[0]);links.new(region.outputs['Fac'],multiply.inputs[1])
    strength=nodes.new('ShaderNodeMath');strength.operation='MULTIPLY';strength.inputs[1].default_value=1.2
    links.new(multiply.outputs[0],strength.inputs[0])
    principled.inputs['Emission Color'].default_value=(1.0,0.90,0.75,1)
    links.new(strength.outputs[0],principled.inputs['Emission Strength'])
    red=material('emissive_core_red',(0.23,0.005,0.008),0.15)
    red_node=next(n for n in red.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    red_node.inputs['Emission Color'].default_value=(1,0.008,0.015,1)
    red_node.inputs['Emission Strength'].default_value=4
    # Preserve a readable core lamp even when the source texture's red is weak.
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,
        location=(0,-0.198*scale,(0.035-ground+lift)*scale))
    lamp=bpy.context.object;lamp.name='rotor_red_core_indicator'
    lamp.scale=(0.012*scale,0.010*scale,0.024*scale);lamp.data.materials.append(red)
    groups['rotor'].append(lamp)

controller=bpy.data.objects.new('rotor_control',None);bpy.context.collection.objects.link(controller)
controller.empty_display_type='CIRCLE';controller.empty_display_size=0.4
bpy.context.view_layer.update()
for obj in groups['rotor']:
    matrix=obj.matrix_world.copy();obj.parent=controller;obj.matrix_world=matrix
controller.rotation_mode='XYZ'
controller.rotation_euler.z=0;controller.keyframe_insert(data_path='rotation_euler',frame=1,index=2)
controller.rotation_euler.z=-2*math.pi;controller.keyframe_insert(data_path='rotation_euler',frame=65,index=2)
action=controller.animation_data.action
for layer in action.layers:
    for strip in layer.strips:
        for slot in action.slots:
            bag=strip.channelbag(slot,ensure=False)
            if bag:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:key.interpolation='LINEAR'
                    curve.modifiers.new('CYCLES')
scene=bpy.context.scene;scene.frame_start=1;scene.frame_end=64;scene.frame_set(1)
scene.render.fps=16
destination=root/'prepared';destination.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(destination/(args.asset+'.blend')))
report['fixed_objects']=[o.name for o in groups['fixed']]
report['rotating_objects']=[o.name for o in groups['rotor']]
report['emission']=advanced
report['rotor_swept_radius_tiles']=radius_max*scale
(destination/'mechanical-split.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))

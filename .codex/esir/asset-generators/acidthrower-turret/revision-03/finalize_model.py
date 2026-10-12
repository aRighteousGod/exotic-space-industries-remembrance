"""Finalize model exports without the rejected custom pipe-collar geometry."""
import bpy,json,os,shutil
from pathlib import Path
root=Path(os.environ.get('ESIR_ACID_REVISION_ROOT','D:/CodexArtifacts/esir-acidthrower-20261009/revision-03'))
prepared=root/'prepared'
archive=prepared/'rejected-custom-collars'
archive.mkdir(exist_ok=True)
for name in ['assembled.glb','base.glb','acidthrower-revision03.blend']:
    if not (archive/name).exists():shutil.copy2(prepared/name,archive/name)
bpy.ops.wm.open_mainfile(filepath=str(prepared/'acidthrower-revision03.blend'))
for obj in list(bpy.data.objects):
    if obj.name.startswith('acid_fixed_port_'):bpy.data.objects.remove(obj,do_unlink=True)
objects=[obj for obj in bpy.data.objects if obj.type=='MESH']
base=[obj for obj in objects if not obj.name.startswith('acid_yaw_')]
# The source chassis is only 1.696 tiles wide. Fill the native two-tile width;
# keep the bearing and head untouched so their contact geometry stays exact.
chassis=next(obj for obj in base if obj.name=='acid_fixed_chassis')
width=max(abs(v.co.x) for v in chassis.data.vertices)
width_scale=1.0/width
for obj in base:
    if obj.name=='acid_fixed_chassis':
        for vertex in obj.data.vertices:vertex.co.x*=width_scale
        obj.data.update()
tanks=next(obj for obj in base if obj.name=='acid_fixed_tanks_manifold')
# Preserve the source's round canisters; only the low deck needs widening.
if not tanks.get('acid_source_dimensions_preserved'):
    with bpy.data.libraries.load(str(archive/'acidthrower-revision03.blend'),link=False) as (available,loaded):
        loaded.objects=['acid_fixed_tanks_manifold']
    source_tanks=loaded.objects[0]
    tanks.data=source_tanks.data.copy()
    bpy.data.objects.remove(source_tanks,do_unlink=True)
    tanks['acid_source_dimensions_preserved']=True
for filename,chosen in [('assembled.glb',objects),('base.glb',base),('chassis-with-tanks.glb',base)]:
    bpy.ops.object.select_all(action='DESELECT')
    for obj in chosen:obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(prepared/filename),export_format='GLB',use_selection=True,export_apply=True,export_image_format='AUTO',export_yup=True,export_animations=False)
bpy.ops.wm.save_as_mainfile(filepath=str(prepared/'acidthrower-revision03.blend'))
anchors=json.loads((root/'model-anchors.json').read_text())
points=[obj.matrix_world@v.co for obj in base for v in obj.data.vertices]
anchors['base_objects']=[obj.name for obj in base]
anchors['base_bounds']=[[min(p[i] for p in points) for i in range(3)],[max(p[i] for p in points) for i in range(3)]]
assert anchors['base_bounds'][0][0]>=-1.00001 and anchors['base_bounds'][1][0]<=1.00001
assert anchors['base_bounds'][0][1]>=-1.5 and anchors['base_bounds'][1][1]<=1.5
for field in ['native_collar_facings','pipe_mouths','collar_outer_radius','collar_ground_clearance','collar_grid_note']:
    anchors.pop(field,None)
anchors['pipe_cover_policy']='Native pipecoverspictures() overlay; Factorio owns port placement, orientation and connected-state visibility.'
anchors['fluid_connections']=[{'direction':'west','position':[-.5,1]},{'direction':'east','position':[.5,1]}]
anchors['connector_mirror_error']=0.0
anchors['base_render_ground_projection']={'world_x':1,'world_y':2**.5,'world_z':1,
    'bearing_and_canisters':'translate centers only; preserve local mesh dimensions'}
anchors['glow_active_states']=['prepared','starting-attack','attacking','ending-attack','rotate-for-folding']
anchors['final_alignment_policy']='Lua sprite shifts only: 0.18 tile rearward per placement; no model, PNG or vanilla-cover changes.'
(root/'model-anchors.json').write_text(json.dumps(anchors,indent=2))
print('ACID_FINAL_MODEL vanilla_pipe_covers=true custom_collars=false footprint_pass=true')

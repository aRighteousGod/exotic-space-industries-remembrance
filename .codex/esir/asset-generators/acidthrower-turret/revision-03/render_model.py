"""Factorio preset wrapper: exact frame poses and isolated window/tint AOVs."""
import importlib.util,json,math,os
from pathlib import Path
import bpy
from mathutils import Matrix,Vector
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(os.environ.get('ESIR_ACID_REVISION_ROOT','D:/CodexArtifacts/esir-acidthrower-20261009/revision-03'))
spec=importlib.util.spec_from_file_location('acid_preset',Path.cwd()/'.codex/skills/meshy-blender-spritesheet/scripts/render_factorio_preset.py')
preset=importlib.util.module_from_spec(spec);spec.loader.exec_module(preset)
old_output=preset.set_file_output_path
old_render=preset.render_animation
collar_objects=[]
rigid_parts=[]

def fit_bearing(scene):
    # Compensate ground-plane foreshortening without stretching the ring that
    # must meet the independently rendered, unmodified rotating head.
    args=preset.parse_args()
    angle=-((scene.frame_current-1)//args.animation_frames)*math.tau/args.directions
    rotation=Matrix.Rotation(angle,4,'Z')
    for obj,pivot,rest in rigid_parts:
        center=rotation@pivot;center.y*=math.sqrt(2)
        obj.matrix_world=Matrix.Translation(center)@rotation@Matrix.Translation(-pivot)@rest

def fit_collars(scene):
    # Ground attachment positions use Factorio's square tile grid; model
    # silhouettes use the preset's 45-degree projection. Bridge those spaces
    # per placement rather than moving the gameplay fluid ports.
    args=preset.parse_args();angle=-((scene.frame_current-1)//args.animation_frames)*math.tau/args.directions
    rotation=Matrix.Rotation(angle,4,'Z')
    profile=[(.78,.105,0),(.88,.18,.45),(.93,.27,.9),(.95,.32,1),(1,.32,1),(1,.225,1),(.89,.225,.85)]
    for obj,side in collar_objects:
        coords=[]
        for x,radius,t in profile:
            center=rotation@Vector((side*x,-1,.30*(1-t)+.34*t))
            center.y*=1+t*(math.sqrt(2)-1)
            center.y-=.24*t
            for i in range(64):
                offset=rotation@Vector((0,radius*math.cos(i*math.tau/64),radius*math.sin(i*math.tau/64)))
                coords.append(center+offset)
        for vertex,co in zip(obj.data.vertices,coords):vertex.co=co
        obj.data.update()

def output(node,folder):
    folder.mkdir(parents=True,exist_ok=True)
    if hasattr(node,'directory'):node.directory=str(folder);node.file_name=''
    else:old_output(node,folder)

def place(objects,args,slope_parent=None):
    rotator=bpy.data.objects['Rotation by Frames & Directions']
    rest={obj.name:obj.matrix_world.copy() for obj in objects}
    for obj in objects:
        preset.unlink_from_all(obj);preset.link_to_collection(obj,'Normal')
        obj.parent=rotator;obj.matrix_parent_inverse=Matrix.Identity(4);obj.matrix_basis=rest[obj.name]
        # Production uses native Factorio pipe-cover sprites. Exclude the
        # rejected custom collars from both the body and its baked shadows.
        collar=obj.name.startswith('acid_fixed_port_')
        if args.asset_name.endswith('-base') and collar:
            obj.hide_render=True
            continue
        if collar and (args.asset_name.endswith('-base') or args.asset_name.endswith('-collars')):
            material=obj.data.materials[0]
            mesh=bpy.data.meshes.new(obj.name+'_native_grid')
            faces=[(ring*64+i,ring*64+(i+1)%64,(ring+1)*64+(i+1)%64,(ring+1)*64+i) for ring in range(6) for i in range(64)]
            side=-1 if obj.name.endswith('left') else 1
            if side<0:faces=[tuple(reversed(face)) for face in faces]
            mesh.from_pydata([(0,0,0)]*(7*64),[],faces);mesh.materials.append(material)
            obj.data=mesh;obj.parent=None;obj.matrix_world=Matrix.Identity(4)
            for polygon in mesh.polygons:polygon.use_smooth=True
            collar_objects.append((obj,side))
        if args.asset_name.endswith('-collars') and not collar:obj.is_holdout=True
    if collar_objects:
        bpy.app.handlers.frame_change_pre.append(fit_collars)
        fit_collars(bpy.context.scene)
    if args.asset_name.endswith('-base'):
        # Factorio's ground grid is square. The preset projects world Y by
        # sqrt(.5); undo that for the fixed base only, leaving height unchanged.
        ground=bpy.data.objects.new('acid_native_ground_grid',None)
        bpy.context.scene.collection.objects.link(ground)
        ground.scale=(1,math.sqrt(2),1)
        rotator.parent=ground
        for obj in objects:
            if obj.name not in {'acid_fixed_bearing_seal','acid_fixed_tanks_manifold'}:continue
            if obj.name=='acid_fixed_bearing_seal':
                pivot=Vector(json.loads((ROOT/'model-anchors.json').read_text())['bearing_xyz'])
            else:
                points=[rest[obj.name]@v.co for v in obj.data.vertices]
                pivot=Vector([(min(p[i] for p in points)+max(p[i] for p in points))/2 for i in range(3)])
            obj.parent=None
            rigid_parts.append((obj,pivot,rest[obj.name]))
        bpy.app.handlers.frame_change_pre.append(fit_bearing)
        fit_bearing(bpy.context.scene)

def math_node(nodes,links,operation,left,right):
    n=nodes.new('ShaderNodeMath');n.operation=operation
    if isinstance(left,(float,int)):n.inputs[0].default_value=left
    else:links.new(left,n.inputs[0])
    if isinstance(right,(float,int)):n.inputs[1].default_value=right
    else:links.new(right,n.inputs[1])
    return n.outputs[0]

def render(output_dir):
    args=preset.parse_args();scene=bpy.context.scene
    layer=scene.view_layers['Object']
    for name,kind in [('AcidGlow','COLOR'),('AcidGlowAlpha','VALUE'),('AcidOwnerAlpha','VALUE')]:
        aov=layer.aovs.add();aov.name=name;aov.type=kind
    done=set()
    for obj in bpy.data.objects:
        if obj.type!='MESH' or not obj.name.startswith('acid_'):continue
        for material in obj.data.materials:
            if not material or material.name in done:continue
            done.add(material.name);nodes=material.node_tree.nodes;links=material.node_tree.links
            if 'owner' in material.name:
                a=nodes.new('ShaderNodeOutputAOV');a.name='AcidOwnerAlpha';a.aov_name='AcidOwnerAlpha';a.inputs['Value'].default_value=1
                continue
            bsdf=next((n for n in nodes if n.type=='BSDF_PRINCIPLED'),None)
            if not bsdf or not bsdf.inputs['Base Color'].is_linked:continue
            color=bsdf.inputs['Base Color'].links[0].from_socket
            split=nodes.new('ShaderNodeSeparateColor');split.mode='RGB';links.new(color,split.inputs[0])
            r,g,b=split.outputs[:3]
            # UV-colour classification selects only the source's yellow-green
            # glass, excluding ivory, steel and dark seams. It never adds
            # emission to the diffuse render, so the idle sprite stays unlit.
            a=math_node(nodes,links,'GREATER_THAN',g,math_node(nodes,links,'MULTIPLY',r,1.035))
            c=math_node(nodes,links,'GREATER_THAN',g,math_node(nodes,links,'MULTIPLY',b,2.0))
            bright=math_node(nodes,links,'GREATER_THAN',g,.025)
            mask=math_node(nodes,links,'MULTIPLY',math_node(nodes,links,'MULTIPLY',a,c),bright)
            out=nodes.new('ShaderNodeOutputAOV');out.aov_name='AcidGlowAlpha';links.new(mask,out.inputs['Value'])
            out=nodes.new('ShaderNodeOutputAOV');out.aov_name='AcidGlow';out.inputs['Color'].default_value=(.35,.8,.018,1)
    tree=scene.compositing_node_group
    render_node=next(n for n in tree.nodes if n.bl_idname=='CompositorNodeRLayers' and n.layer=='Object')
    bpy.context.view_layer.update()
    for role,color_name,alpha_name in [('Glow','AcidGlow','AcidGlowAlpha'),('Owner','Image','AcidOwnerAlpha')]:
        setalpha=tree.nodes.new('CompositorNodeSetAlpha')
        if hasattr(setalpha,'mode'):setalpha.mode='REPLACE_ALPHA'
        else:setalpha.inputs['Type'].default_value='Replace Alpha'
        tree.links.new(render_node.outputs[color_name],setalpha.inputs['Image'])
        tree.links.new(render_node.outputs[alpha_name],setalpha.inputs['Alpha'])
        file=tree.nodes.new('CompositorNodeOutputFile');file.label='Acid '+role
        if hasattr(file.format,'media_type'):
            file.format.media_type='IMAGE'
            file.file_output_items.new('RGBA','')
        file.format.file_format='PNG';file.format.color_mode='RGBA';file.format.color_depth='8'
        output(file,output_dir/role);tree.links.new(setalpha.outputs['Image'],file.inputs[0])
    rotator=bpy.data.objects['Rotation by Frames & Directions']
    records=[];collar_meshes=[]
    for frame in range(1,args.frames+1):
        scene.frame_set(frame);bpy.context.view_layer.update()
        expected=((frame-1)//args.animation_frames)*360/args.directions
        actual=-math.degrees(rotator.rotation_euler.z)
        assert abs(actual-expected)<.001,(frame,actual,expected)
        records.append({'frame':frame,'world_yaw_degrees':actual})
        if args.asset_name.endswith('-base'):
            records[-1]['ground_projection_compensation']=[1,math.sqrt(2),1]
        if collar_objects:
            # The two native mouths share a diameter and height and their
            # projected centre lands on the unchanged pipe attachment grid.
            mouths=[]
            for obj,side in collar_objects:
                ring=[obj.data.vertices[4*64+i].co for i in range(64)]
                center=sum(ring,Vector())/64
                angle=-(frame-1)*math.tau/args.directions
                native=Matrix.Rotation(angle,4,'Z')@Vector((side,-1,0))
                assert abs(center.x-native.x)<1e-5
                assert abs((center.y+.24)*math.sqrt(.5)-native.y)<1e-5
                assert abs(center.z-.34)<1e-5
                mouths.append({'side':side,'model_xyz':list(center),'projected_tiles':[center.x,-(center.y+center.z)*math.sqrt(.5)]})
            records[-1]['native_pipe_mouths']=mouths
            if args.asset_name.endswith('-collars'):
                collar_meshes.append([{'name':obj.name,'vertices':[list(v.co) for v in obj.data.vertices],
                    'faces':[list(p.vertices) for p in obj.data.polygons]} for obj,side in collar_objects])
    (output_dir/'verified-frame-poses.json').write_text(json.dumps(records,indent=2))
    if collar_meshes:(ROOT/'prepared/collars-native-geometry.json').write_text(json.dumps(collar_meshes))
    if not os.environ.get('ESIR_ACID_EXPORT_COLLARS_ONLY'):old_render(output_dir)

preset.set_file_output_path=output
preset.place_imported_objects=place
preset.render_animation=render
preset.main()

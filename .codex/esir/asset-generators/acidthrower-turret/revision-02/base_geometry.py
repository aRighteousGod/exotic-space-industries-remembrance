"""Deterministic fixed acidthrower base and exportable weathered materials."""
import bpy, bmesh, math, json
from mathutils import Vector, Matrix
from pathlib import Path

FIXED=[]
YAW=[]
MATERIALS={}

def material_tiles(root):
    """Bake UV material tiles so procedural weathering survives GLB export."""
    folder=Path(root)/'source/material-tiles'
    folder.mkdir(parents=True,exist_ok=True)
    specs={
        'olive':((.19,.205,.15),.38,.65),
        'darksteel':((.078,.088,.071),.55,.68),
        'steel':((.32,.34,.30),.7,.47),
        'ivory':((.61,.56,.43),.06,.65),
        'rubber':((.024,.029,.023),.02,.86),
        'brass':((.31,.22,.085),.65,.55),
        'green':((.17,.28,.022),.08,.48),
        'neutral':((.42,.43,.40),.22,.58),
    }
    scene=bpy.context.scene
    scene.render.engine='CYCLES'
    scene.cycles.samples=1
    scene.cycles.device='CPU'
    for name,(color,metallic,roughness) in specs.items():
        path=folder/f'{name}.png'
        material=bpy.data.materials.new('acid_'+name)
        material.use_nodes=True
        nodes=material.node_tree.nodes
        links=material.node_tree.links
        nodes.clear()
        output=nodes.new('ShaderNodeOutputMaterial')
        target=nodes.new('ShaderNodeTexImage')
        if path.exists():
            tile=bpy.data.images.load(str(path),check_existing=True)
        else:
            tile=bpy.data.images.new('acid_'+name+'_tile',width=512,height=512,alpha=False)
            target.image=tile
            coord=nodes.new('ShaderNodeTexCoord')
            noise=nodes.new('ShaderNodeTexNoise')
            noise.inputs['Scale'].default_value=28
            noise.inputs['Detail'].default_value=4
            noise.inputs['Roughness'].default_value=.72
            links.new(coord.outputs['UV'],noise.inputs['Vector'])
            ramp=nodes.new('ShaderNodeValToRGB')
            ramp.color_ramp.elements.remove(ramp.color_ramp.elements[1])
            values=[(.13,.40),(.31,.70),(.57,1.0),(.78,1.32)]
            for index,(position,factor) in enumerate(values):
                element=ramp.color_ramp.elements[0] if index==0 else ramp.color_ramp.elements.new(position)
                element.position=position
                element.color=tuple(min(.95,value*factor) for value in color)+(1,)
            links.new(noise.outputs['Fac'],ramp.inputs['Fac'])
            emission=nodes.new('ShaderNodeEmission')
            links.new(ramp.outputs['Color'],emission.inputs['Color'])
            links.new(emission.outputs[0],output.inputs['Surface'])
            nodes.active=target
            bpy.ops.mesh.primitive_plane_add(size=2)
            plane=bpy.context.object
            plane.data.materials.append(material)
            bpy.ops.object.bake(type='EMIT',margin=4,use_clear=True)
            tile.filepath_raw=str(path)
            tile.file_format='PNG'
            tile.save()
            bpy.data.objects.remove(plane,do_unlink=True)
            for node in list(nodes):
                if node not in (output,target):
                    nodes.remove(node)
        target.image=tile
        tile.pack()
        bsdf=nodes.new('ShaderNodeBsdfPrincipled')
        bsdf.inputs['Metallic'].default_value=metallic
        bsdf.inputs['Roughness'].default_value=roughness
        links.new(target.outputs['Color'],bsdf.inputs['Base Color'])
        links.new(bsdf.outputs[0],output.inputs['Surface'])
        material.diffuse_color=(*color,1)
        MATERIALS[name]=material
    return MATERIALS

def finish(obj,name,material='olive',group=FIXED,bevel=0):
    obj.name=name
    obj.data.materials.clear()
    obj.data.materials.append(MATERIALS[material])
    if bevel:
        modifier=obj.modifiers.new('machined_edges','BEVEL')
        modifier.width=bevel
        modifier.segments=2
        bpy.context.view_layer.objects.active=obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    group.append(obj)
    return obj

def box(name,location,dimensions,material='olive',bevel=.02,group=FIXED):
    bpy.ops.mesh.primitive_cube_add(size=1,location=location)
    obj=bpy.context.object
    obj.dimensions=dimensions
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(obj,name,material,group,bevel)

def cylinder(name,location,radius,depth,material='steel',vertices=48,axis='Z',group=FIXED):
    rotation={'Z':(0,0,0),'X':(0,math.pi/2,0),'Y':(math.pi/2,0,0)}[axis]
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=location,rotation=rotation)
    obj=finish(bpy.context.object,name,material,group,.003 if vertices>8 else .001)
    for face in obj.data.polygons:
        face.use_smooth=len(face.vertices)==4
    return obj

def lathe(name,profile,center=(0,0,0),material='olive',axis='Z',closed=False,segments=64,group=FIXED):
    vertices=[]
    for radius,axial in profile:
        for j in range(segments):
            a=j*math.tau/segments
            x,y=radius*math.cos(a),radius*math.sin(a)
            vertices.append({'Z':(x,y,axial),'Y':(x,axial,y),'X':(axial,x,y)}[axis])
    faces=[]
    uv_faces=[]
    spans=len(profile) if closed else len(profile)-1
    for ring in range(spans):
        next_ring=(ring+1)%len(profile)
        for j in range(segments):
            next_j=(j+1)%segments
            faces.append((ring*segments+j,ring*segments+next_j,next_ring*segments+next_j,next_ring*segments+j))
            uv_faces.append(((j/segments,ring/len(profile)),((j+1)/segments,ring/len(profile)),((j+1)/segments,(ring+1)/len(profile)),(j/segments,(ring+1)/len(profile))))
    if not closed:
        faces.extend([tuple(reversed(range(segments))),tuple((len(profile)-1)*segments+j for j in range(segments))])
        uv_faces.extend([tuple((.5+.5*math.cos(j*math.tau/segments),.5+.5*math.sin(j*math.tau/segments)) for j in reversed(range(segments))),tuple((.5+.5*math.cos(j*math.tau/segments),.5+.5*math.sin(j*math.tau/segments)) for j in range(segments))])
    mesh=bpy.data.meshes.new(name+'_mesh')
    mesh.from_pydata(vertices,[],faces)
    mesh.update()
    uv=mesh.uv_layers.new(name='UVMap')
    for polygon,coordinates in zip(mesh.polygons,uv_faces):
        for loop,coordinate in zip(polygon.loop_indices,coordinates):
            uv.data[loop].uv=coordinate
    bm=bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    obj=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    obj.location=center
    for polygon in obj.data.polygons:
        polygon.use_smooth=len(polygon.vertices)==4
    return finish(obj,name,material,group)

def pipe(name,points,radius=.045,material='steel',group=FIXED):
    curve=bpy.data.curves.new(name+'_curve','CURVE')
    curve.dimensions='3D'
    curve.resolution_u=12
    curve.bevel_depth=radius
    curve.bevel_resolution=3
    curve.use_fill_caps=True
    spline=curve.splines.new('BEZIER')
    spline.bezier_points.add(len(points)-1)
    for bp,coordinate in zip(spline.bezier_points,points):
        bp.co=coordinate
        bp.handle_left_type='AUTO'
        bp.handle_right_type='AUTO'
    obj=bpy.data.objects.new(name,curve)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.convert(target='MESH')
    obj=bpy.context.object
    # Converted bevel UVs are exported; add planar fallback only if absent.
    if not obj.data.uv_layers:
        layer=obj.data.uv_layers.new(name='UVMap')
        for loop in obj.data.loops:
            v=obj.data.vertices[loop.vertex_index].co
            layer.data[loop.index].uv=(v.x*2,v.y*2)
    return finish(obj,name,material,group)

def mirror_x(objects,prefix):
    copies=[]
    reflection=Matrix.Diagonal((-1,1,1,1))
    for source in objects:
        obj=source.copy()
        obj.data=source.data.copy()
        bpy.context.collection.objects.link(obj)
        # Bake the source world matrix and reflect vertex coordinates exactly.
        obj.data.transform(reflection @ source.matrix_world)
        obj.matrix_world=Matrix.Identity(4)
        obj.name=source.name.replace(prefix,prefix.replace('right','left'))
        bm=bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        bm.to_mesh(obj.data)
        bm.free()
        FIXED.append(obj)
        copies.append(obj)
    return copies

def build_base():
    box('acid_fixed_tray_floor',(0,0,.11),(1.74,2.74,.12),'darksteel',.055)
    for side in [-1,1]:
        box(f'acid_fixed_side_rail_{side}',(side*.84,0,.245),(.12,2.70,.27),'olive',.035)
        for y in [-1.13,1.13]:
            box(f'acid_fixed_foot_{side}_{y}',(side*.71,y,.065),(.34,.46,.13),'darksteel',.025)
            cylinder(f'acid_fixed_anchor_{side}_{y}',(side*.72,y,.145),.062,.04,'steel',6)
    box('acid_fixed_rear_rim',(0,-1.32,.245),(1.62,.12,.27),'olive',.025)
    box('acid_fixed_front_rim',(0,1.32,.205),(1.62,.12,.19),'olive',.025)
    box('acid_fixed_front_deck',(0,.69,.20),(1.53,1.18,.10),'olive',.025)
    for x in [-.63,.63]:
        for y in [.22,1.13]:
            cylinder(f'acid_fixed_deck_bolt_{x}_{y}',(x,y,.263),.042,.027,'steel',6)
    for y in [-1.19,-.91,-.38,-.12]:
        box(f'acid_fixed_bed_rib_{y}',(0,y,.18),(1.46,.034,.032),'steel',.004)

    # The tank shells begin below the raised tray lip: visibly recessed.
    for side in [-1,1]:
        x=side*.43
        tank=f'acid_fixed_tank_{side}'
        lathe(tank,[(.20,.14),(.252,.19),(.266,.27),(.266,.68),(.245,.76),(.16,.82),(.08,.83)],(x,-.66,0),'ivory')
        for z in [.29,.61]:
            cylinder(f'{tank}_band_{z}',(x,-.66,z),.273,.055,'darksteel')
            for sx in [-1,1]:
                box(f'{tank}_strap_foot_{z}_{sx}',(x+sx*.23,-.66,.24),(.065,.22,.17),'darksteel',.008)
        cylinder(f'{tank}_cap',(x,-.66,.85),.094,.044,'steel',8)
        cylinder(f'{tank}_valve_stem',(x,-.66,.888),.024,.04,'brass',12)
        box(f'{tank}_valve_handle',(x,-.66,.91),(.15,.035,.022),'darksteel',.009)
        box(f'{tank}_level_frame',(x,-.925,.465),(.09,.035,.215),'darksteel',.01)
        box(f'{tank}_level_window',(x,-.947,.465),(.037,.018,.168),'green',.006)
        box(f'{tank}_front_level_frame',(x,-.395,.465),(.09,.035,.215),'darksteel',.01)
        box(f'{tank}_front_level_window',(x,-.373,.465),(.037,.018,.168),'green',.006)
        pipe(f'{tank}_outlet',[(x,-.65,.26),(x,-.94,.26),(x,-1,.29)],.046,'steel')

    # Preserve current rear west/east connection mouths at x=+/-1, y=-1.
    start=len(FIXED)
    profile=[(.105,.73),(.105,.86),(.159,.88),(.159,.98),(.145,1.0),(.094,1.0),(.094,.73)]
    lathe('acid_fixed_port_right_body',profile,(0,-1,.29),'steel','X',True)
    cylinder('acid_fixed_port_right_socket',(.746,-1,.29),.095,.012,'rubber',48,'X')
    for index in range(6):
        angle=index*math.tau/6
        cylinder(f'acid_fixed_port_right_bolt_{index}',(.981,-1+.126*math.cos(angle),.29+.126*math.sin(angle)),.021,.022,'darksteel',6,'X')
    right_ports=FIXED[start:]
    bpy.context.view_layer.update()
    left_ports=mirror_x(right_ports,'acid_fixed_port_right')
    pipe('acid_fixed_rear_manifold',[(-.75,-1,.29),(0,-1,.29),(.75,-1,.29)],.073,'darksteel')
    pipe('acid_fixed_supply_spine',[(0,-1,.29),(0,-.54,.29),(0,.32,.29),(0,.55,.355)],.059,'steel')
    cylinder('acid_fixed_rotary_union',(0,.55,.345),.175,.15,'brass')
    cylinder('acid_fixed_bearing_lower',(0,.55,.385),.43,.085,'darksteel')
    cylinder('acid_fixed_bearing_seal',(0,.55,.427),.405,.006,'rubber')
    for index in range(8):
        angle=index*math.tau/8
        cylinder(f'acid_fixed_bearing_bolt_{index}',(.375*math.cos(angle),.55+.375*math.sin(angle),.433),.023,.02,'steel',6)
    box('acid_trim_fixed_rear_panel',(0,-1.389,.259),(.44,.018,.12),'neutral',.006)
    return right_ports,left_ports

def export(path,objects):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_apply=True,export_image_format='AUTO',export_yup=True)

def validate_base(right,left):
    bpy.context.view_layer.update()
    mirror_error=0
    for a,b in zip(right,left):
        assert len(a.data.vertices)==len(b.data.vertices)
        for va,vb in zip(a.data.vertices,b.data.vertices):
            pa=a.matrix_world@va.co
            pb=b.matrix_world@vb.co
            mirror_error=max(mirror_error,(Vector((-pa.x,pa.y,pa.z))-pb).length)
    points=[obj.matrix_world@v.co for obj in FIXED for v in obj.data.vertices]
    low=[min(p[i] for p in points) for i in range(3)]
    high=[max(p[i] for p in points) for i in range(3)]
    assert mirror_error<1e-6,mirror_error
    assert low[0]>=-1.00001 and high[0]<=1.00001,(low,high)
    assert low[1]>=-1.50001 and high[1]<=1.50001,(low,high)
    assert low[2]>=-1e-6,(low,high)
    return {'mirror_max_vertex_error':mirror_error,'bounds_min':low,'bounds_max':high,
        'gameplay_footprint':[2,3],'base_body_target':[1.8,2.8],
        'pipe_mouths_blender':[[-1,-1,.29],[1,-1,.29]],
        'native_pipe_connection_tiles':[[-.5,1],[.5,1]],
        'native_adjacent_pipe_centers':[[-1.5,1],[1.5,1]],
        'fixed_objects':[obj.name for obj in FIXED],'canisters_fixed':True}

if __name__=='__main__':
    import os
    root=Path(os.environ.get('ESIR_ACID_REVISION_ROOT','D:/CodexArtifacts/esir-acidthrower-20261008/revision-02'))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    material_tiles(root)
    right,left=build_base()
    qa=validate_base(right,left)
    destination=root/'prepared'
    destination.mkdir(parents=True,exist_ok=True)
    export(destination/'base.glb',FIXED)
    bpy.ops.wm.save_as_mainfile(filepath=str(destination/'base-working.blend'))
    (root/'base-geometry-qa.json').write_text(json.dumps(qa,indent=2))
    print('BASE_QA '+json.dumps({k:v for k,v in qa.items() if k!='fixed_objects'}))

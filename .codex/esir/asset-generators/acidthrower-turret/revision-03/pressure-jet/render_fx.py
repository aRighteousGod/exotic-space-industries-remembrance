"""Deterministic liquid geometry rendered through the repository Factorio preset."""
import importlib.util, math, os, random
from pathlib import Path
import bpy

spec=importlib.util.spec_from_file_location('jet_preset',Path.cwd()/'.codex/skills/meshy-blender-spritesheet/scripts/render_factorio_preset.py')
preset=importlib.util.module_from_spec(spec);spec.loader.exec_module(preset)
kind=os.environ['ESIR_JET_PART']
animated=[]
material=None

def animate(scene):
    t=(scene.frame_current-1)/(24 if kind=='splash' else 16)
    if kind=='spine':
        mesh=animated[0].data
        for ring in range(97):
            x=-.43+ring*.86/96
            # Unequal wavelengths and travelling knots avoid a repeated wire.
            radius=.043*(1+.30*math.sin(x*29-t*math.tau)+.16*math.sin(x*53+t*math.tau*2+.7))
            drift=.027*math.sin(x*18-t*math.tau)+.009*math.sin(x*43+t*math.tau*3+1.1)
            for j in range(12):
                angle=j*math.tau/12
                mesh.vertices[ring*12+j].co=(x,drift+radius*math.cos(angle),.10+.012*math.sin(x*23-t*math.tau*2)+radius*math.sin(angle))
        mesh.update()
    elif kind=='droplet':
        animated[0].scale=(.055*(1+.22*math.sin(t*math.tau)),.037*(1+.2*math.cos(t*math.tau)),.035)
    elif kind=='flecks':
        for obj,angle,radius,size,phase in animated:
            wobble=.012*math.sin(t*math.tau+phase*9)
            obj.location=(math.cos(angle+t*.35)*radius+wobble,
                math.sin(angle+t*.35)*radius*math.sqrt(2),.025)
            obj.scale=(size*(1+.15*math.sin(t*math.tau+phase)),size*.72,size*.65)
    else:
        for obj,angle,radius,size,phase in animated:
            u=min(1,t*1.1+phase)
            r=radius*(.12+.88*u**.65)
            obj.location=(math.cos(angle)*r,math.sin(angle)*r*math.sqrt(2),.035+.35*math.sin(math.pi*u)*(1-radius/4))
            obj.scale=(size*(1-.5*u),size*.65*(1-.5*u),size*(1-u)*1.6+.004)
        material.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value=max(.02,.7*(1-t)**1.4)

def create():
    global material
    material=bpy.data.materials.new('acid_wet_olive');material.use_nodes=True
    shader=material.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value=(.19,.34,.035,1)
    shader.inputs['Roughness'].default_value=.22
    shader.inputs['Coat Weight'].default_value=.35
    objects=[]
    if kind=='spine':
        mesh=bpy.data.meshes.new('liquid_column')
        faces=[(r*12+j,r*12+(j+1)%12,(r+1)*12+(j+1)%12,(r+1)*12+j) for r in range(96) for j in range(12)]
        mesh.from_pydata([(0,0,0)]*(97*12),[],faces)
        obj=bpy.data.objects.new('pressure_ribbon',mesh);bpy.context.scene.collection.objects.link(obj)
        objects.append(obj);animated.append(obj)
    else:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1)
        first=bpy.context.object;first.name='wet_droplet'
        if kind=='droplet':
            first.location.z=.06;objects.append(first);animated.append(first)
        elif kind=='flecks':
            rng=random.Random(712035)
            for i in range(26):
                obj=first if i==0 else bpy.data.objects.new('airborne_fleck_%03d'%i,first.data)
                if i:bpy.context.scene.collection.objects.link(obj)
                # An open cluster of small wet beads, never a translucent cloud.
                radius=.46*(rng.random()**.55)
                size=rng.uniform(.012,.028)
                animated.append((obj,rng.random()*math.tau,radius,size,rng.random()*math.tau))
                objects.append(obj)
        else:
            rng=random.Random(712003)
            for i in range(170):
                obj=first if i==0 else bpy.data.objects.new('splash_fleck_%03d'%i,first.data)
                if i: bpy.context.scene.collection.objects.link(obj)
                radius=(rng.random()**.65)*3 if i>30 else rng.uniform(.1,.65)
                size=rng.uniform(.018,.043) if i>30 else rng.uniform(.045,.08)
                animated.append((obj,rng.random()*math.tau,radius,size,rng.uniform(0,.08)))
                objects.append(obj)
    for obj in objects:
        if not obj.data.materials:obj.data.materials.append(material)
        for face in obj.data.polygons:face.use_smooth=True
    bpy.app.handlers.frame_change_pre.append(animate)
    animate(bpy.context.scene)
    return objects

old_output=preset.set_file_output_path
def output(node,folder):
    folder.mkdir(parents=True,exist_ok=True)
    if hasattr(node,'directory'):node.directory=str(folder);node.file_name=''
    else:old_output(node,folder)

preset.create_test_cube=create
preset.set_file_output_path=output
preset.main()

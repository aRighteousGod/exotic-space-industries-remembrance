"""Reproducible Blender ANISETRON: open black/gold nave and cyan crown.
Geometry is authored in tiles around the native torso pivot; forward is -Y.
"""
import argparse
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector

def material(name,color,metallic=0,emission=0):
    mat=bpy.data.materials.new(name);mat.use_nodes=True
    node=mat.node_tree.nodes.get('Principled BSDF')
    for key,val in {'Base Color':(*color,1),'Metallic':metallic,'Roughness':0.5,
                    'Emission Color':(*color,1),'Emission Strength':emission}.items():
        node.inputs[key].default_value=val
    return mat

def finish(obj,name,mat):
    obj.name=name;obj.data.materials.append(mat);return obj

def box(name,pos,size,mat,bevel=0.025):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos)
    obj=finish(bpy.context.object,name,mat);obj.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=obj.modifiers.new('Forged edges','BEVEL');mod.width=bevel;mod.segments=2
        obj.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    return obj

def rod(name,a,b,radius,mat):
    a,b=Vector(a),Vector(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=8,radius=radius,depth=(b-a).length,location=(a+b)/2)
    obj=finish(bpy.context.object,name,mat)
    obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return obj

def crystal(name,pos,radius,height,mat,inverted=False):
    x,y,z=pos;sign=-1 if inverted else 1;sides=6
    verts=[(x,y,z+sign*height)]
    for level,r in ((height*0.63,radius),(height*0.14,radius*0.83)):
        for i in range(sides):
            angle=i*math.tau/sides
            verts.append((x+r*math.cos(angle),y+r*math.sin(angle),z+sign*level))
    verts.append((x,y,z));faces=[]
    for i in range(sides):
        j=(i+1)%sides
        faces.extend([(0,1+i,1+j),(1+i,1+sides+i,1+sides+j,1+j),
                      (1+sides+i,1+2*sides,1+sides+j)])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    return finish(obj,name,mat)

def arch(name,center,width,spring,peak,mat,radius=0.07,axis='front'):
    x,y,base=center;half=width/2
    pts=[(-half,0),(-half,spring),(-half*.92,spring+.26*(peak-spring)),
         (-half*.64,spring+.65*(peak-spring)),(0,peak),
         (half*.64,spring+.65*(peak-spring)),(half*.92,spring+.26*(peak-spring)),(half,spring),(half,0)]
    coords=[(x+u,y,base+v) if axis=='front' else (x,y+u,base+v) for u,v in pts]
    for i in range(len(coords)-1):rod(f'{name}_{i}',coords[i],coords[i+1],radius,mat)

def roof(name,x,y,z,width,length,height,mat):
    verts=[(x-width/2,y-length/2,z),(x+width/2,y-length/2,z),
           (x-width/2,y+length/2,z),(x+width/2,y+length/2,z),
           (x,y-length/2,z+height),(x,y+length/2,z+height)]
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],[(0,2,5,4),(1,4,5,3),(0,4,1),(2,3,5),(0,1,3,2)]);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    return finish(obj,name,mat)

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',default='output/meshy/anisetron/prepared/cathedral.blend')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    dark=material('Basalt enamel',(0.025,.035,.043),.28)
    stone=material('Raised black ribs',(.065,.08,.09),.2)
    gold=material('Old liturgical gold',(.62,.39,.075),.52)
    teal=material('Keel teal facets',(.012,.24,.23),.24,.12)
    cyan=material('Sanctuary cyan crystal',(.025,.65,.58),.15,.8)
    bright=material('Crown inner facet',(.48,1,.88),0,1.4)
    trim=material('Owner neutral crest',(.82,.82,.82))
    box('cathedral_nave_foundation',(0,0,.08),(3.25,6.55,.38),dark,.1)
    box('cathedral_gold_plinth',(0,0,.3),(3.42,6.7,.10),gold)
    box('cathedral_black_deck',(0,0,.375),(3.20,6.48,.08),dark)
    # The open nave leaves the crystal visible from the high game camera.
    for side in (-1,1):
        box(f'cathedral_aisle_body_{side}',(side*1.37,0,.94),(.58,5.9,1.3),dark)
        roof(f'cathedral_aisle_roof_{side}',side*1.39,0,1.60,.77,5.9,.34,dark)
        for i,y in enumerate((-2.85,-1.45,0,1.45,2.85)):
            arch(f'cathedral_side_arc_{side}_{i}',(side*1.81,y,.37),.69,.64,1.11,gold,.045,'side')
            box(f'cathedral_side_window_{side}_{i}',(side*1.67,y,.97),(.018,.26,.52),teal,0)
            tip=(side*2.90,y+.22,.13)
            rod(f'cathedral_buttress_{side}_{i}',(side*1.30,y,1.73),tip,.17,dark)
            rod(f'cathedral_buttress_gold_{side}_{i}',(side*1.32,y,1.87),(side*2.90,y+.22,.31),.055,gold)
            crystal(f'cathedral_keel_side_{side}_{i}',(side*1.55,y,0),.27,.77,teal,True)
        x,y=side*1.15,2.68
        rod(f'cathedral_aisle_gold_sill_{side}',(side*1.69,-2.98,.52),(side*1.69,2.98,.52),.038,gold)
        box(f'cathedral_rear_tower_{side}',(x,y,1.38),(.72,.72,2.3),dark)
        roof(f'cathedral_rear_spire_{side}',x,y,2.55,.87,.84,.98,dark)
        for dx in (-.33,.33):
            rod(f'cathedral_tower_edge_{side}_{dx}',(x+dx,y-.37,.35),(x+dx,y-.37,2.56),.045,gold)
        crystal(f'cathedral_spire_finial_{side}',(x,y,3.53),.06,.25,gold)
        arch(f'cathedral_rear_window_{side}',(x,y+.38,1.04),.46,.68,1.06,gold,.035)
    box('cathedral_rear_apse',(0,2.65,.9),(2.2,1.1,1.25),dark)
    roof('cathedral_rear_apse_roof',0,2.65,1.6,2.4,1.15,.65,dark)
    rod('cathedral_apse_gold_ridge',(0,2.07,2.26),(0,3.23,2.26),.065,gold)
    for i,y in enumerate((-.85,.85)):
        arch(f'cathedral_sanctuary_outer_{i}',(0,y,.36),2.66,1.65,3.29,dark,.15)
        arch(f'cathedral_sanctuary_gold_{i}',(0,y,.36),2.30,1.65,3.17,gold,.11)
    for x in (-1.13,1.13):
        rod(f'cathedral_sanctuary_lintel_{x}',(x,-.85,1.9),(x,.85,1.9),.08,gold)
    crystal('cathedral_sanctuary_crystal',(0,0,.49),.67,2.67,cyan)
    crystal('cathedral_crown_prism',(0,0,2.84),.36,1.10,cyan)
    crystal('cathedral_crown_muzzle',(0,0,3.65),.11,.32,bright)
    for i in range(6):
        angle=math.tau*i/6;x,y=.47*math.cos(angle),.47*math.sin(angle)
        rod(f'cathedral_crown_gold_cradle_{i}',(x,y,2.85),(x*.64,y*.64,3.35),.045,gold)
    crystal('cathedral_front_reliquary_window',(0,-3.33,.5),.36,.78,cyan)
    arch('cathedral_front_window_frame',(0,-3.36,.4),.91,.4,1.04,gold,.075)
    crystal('cathedral_keel_center',(0,-.38,-.1),.87,1.30,teal,True)
    for x,y,h in ((-.65,-1.5,.92),(.65,-1.5,.92),(-.65,1.5,.72),(.65,1.5,.72)):
        crystal(f'cathedral_keel_{x}_{y}',(x,y,-.02),.43,h,teal,True)
    for side in (-1,1):
        box(f'force_trim_crest_{side}',(side*1.83,.3,1.36),(.025,.46,.46),trim,.015)
    box('force_trim_rear_crest',(0,3.23,1.2),(.5,.025,.42),trim,.015)
    out=Path(args.output).resolve();out.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(out))
    record={'schema':1,'reference':'C:/Users/Theorun/Documents/1righteousgod/ANISETRON 16.png',
            'source':'procedural Blender geometry','forward_axis':'-Y','body_origin':[0,0,0],
            'crown_muzzle':[0,0,3.97],'component_count':len(bpy.context.scene.objects),
            'roles':{'cathedral_*':'baked body/selective crystal emission','force_trim_*':'owner mask'},
            'model':str(out)}
    out.with_suffix('.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
    print('ANISETRON_MODEL '+json.dumps(record),flush=True)

if __name__=='__main__':main()

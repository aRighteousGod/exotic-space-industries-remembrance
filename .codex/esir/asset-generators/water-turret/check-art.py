"""Read-only pixel/layout checks for the water-turret render handoff."""
from pathlib import Path
from PIL import Image, ImageChops
import json
root=Path('output/meshy/water-turret')
report={'roles':{},'passed':True}
for role,count,columns in [('base',4,4),('head',64,8)]:
    result={}
    for kind,packed in [('Object','object_0.png'),('Shadow','object_shadow_0.png'),('ColorMask','object_mask_0.png')]:
        files=sorted((root/role/'Render'/kind).glob('*.png'))
        if role=='base' and kind=='ColorMask':continue
        assert len(files)==count,(role,kind,len(files),count)
        bounds=[];neutral=True;differences=0;export_differences=0
        sheet=Image.open(root/role/'Render/.Sheets'/packed).convert('RGBA')
        suffix={'Object':'','Shadow':'_shadow','ColorMask':'_mask'}[kind]
        exported=Image.open(root/role/'factorio-export'/f'water-turret-{role}{suffix}.png').convert('RGBA')
        for index,path in enumerate(files):
            frame=Image.open(path).convert('RGBA');assert frame.size==(576,576)
            bbox=frame.getchannel('A').getbbox()
            if bbox:bounds.append(min(bbox[0],bbox[1],576-bbox[2],576-bbox[3]))
            if kind=='ColorMask':
                r,g,b,a=frame.split()
                neutral=neutral and ImageChops.difference(r,g).getextrema()[1]<=2 and ImageChops.difference(r,b).getextrema()[1]<=2
            x,y=(index%columns)*576,(index//columns)*576
            tile=sheet.crop((x,y,x+576,y+576))
            if ImageChops.difference(frame,tile).getbbox(alpha_only=False):differences+=1
            shipped=exported.crop((x,y,x+576,y+576))
            diff=ImageChops.difference(frame,shipped)
            visible=frame.getchannel('A').point(lambda value:255 if value else 0).convert('RGB')
            if diff.getchannel('A').getbbox() or ImageChops.multiply(diff.convert('RGB'),visible).getbbox():export_differences+=1
        result[kind]={'frames':len(files),'minimum_alpha_margin':min(bounds) if bounds else None,'neutral':neutral,'blender_packed_differing_frames':differences,'exported_differing_frames':export_differences}
        report['passed']=report['passed'] and neutral and not export_differences and (not bounds or min(bounds)>=8)
    report['roles'][role]=result
for name,size in [('items/water-turret.png',(224,128)),('technology/water-turret.png',(256,256))]:
    assert Image.open(Path('exotic-space-industries-remembrance/graphics')/name).size==size
(root/'art-qa.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
assert report['passed']

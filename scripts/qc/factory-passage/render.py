"""Assemble hash-verified native Factorio frames into compact movement receipts."""
import argparse,hashlib,json,pathlib
from PIL import Image,ImageDraw,ImageFont

def main():
    p=argparse.ArgumentParser();p.add_argument('--evidence',required=True);p.add_argument('--output',required=True);a=p.parse_args()
    evidence=pathlib.Path(a.evidence);output=pathlib.Path(a.output);output.mkdir(parents=True,exist_ok=True)
    inventories={}
    for label in ['esir-visual','squeak-through-visual','vanilla-visual','master-off-visual']:
        inventory=json.loads((evidence/(label+'-frames.json')).read_text())
        for entry in inventory:
            assert hashlib.sha256(pathlib.Path(entry['absolute_path']).read_bytes()).hexdigest()==entry['sha256']
        inventories[label]={(entry['scene'],int(pathlib.Path(entry['path']).stem.rsplit('-',1)[1])):entry for entry in inventory}
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',23)
    small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
    products=[]
    for name,columns,scenes in [
        ('factory-passage',[('master-off-visual','Passage OFF'),('esir-visual','Passage ON')],['ei-steam-crusher','ei-burner-heater','ei-steam-assembler']),
        ('pipe-modes',[('vanilla-visual','Vanilla'),('squeak-through-visual','Squeak Through'),('esir-visual','ESIR')],['pipe-joint','separate-parallel']),
        ('occupied-joint',[('esir-visual','ESIR: construction around a character')],['occupied-joint'])]:
        frames=[]
        for age in range(15,46,2):
            width=len(columns)*480;height=52+len(scenes)*390
            frame=Image.new('RGB',(width,height),'#172128');draw=ImageDraw.Draw(frame)
            draw.text((14,12),'Factorio 2.1.24 | native movement | slowed playback',font=small,fill='white')
            for column,(label,title) in enumerate(columns):
                for row,scene in enumerate(scenes):
                    entry=inventories[label][scene,age]
                    shot=Image.open(entry['absolute_path']).convert('RGB').resize((480,360),Image.Resampling.LANCZOS)
                    x=column*480;y=52+row*390
                    frame.paste(shot,(x,y+30))
                    readable=scene.replace('ei-','').replace('-',' ')
                    draw.text((x+10,y+3),title+' | '+readable,font=small,fill='white')
            frames.append(frame)
        target=output/(name+'.webp')
        frames[0].save(target,save_all=True,append_images=frames[1:],duration=180,loop=0,quality=85,method=6)
        still=output/(name+'-final.png');frames[-1].save(still)
        products.append(dict(path=str(target),sha256=hashlib.sha256(target.read_bytes()).hexdigest(),frames=len(frames),source_labels=[c[0] for c in columns]))
    (output/'manifest.json').write_text(json.dumps(dict(engine='2.1.24',generated_from='native take_screenshot frames; no synthetic motion',products=products),indent=2),encoding='utf8')
    print(json.dumps(products,indent=2))
if __name__=='__main__':main()

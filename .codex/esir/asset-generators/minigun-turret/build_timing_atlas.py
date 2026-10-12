"""Cheap diagnostic atlas; phase and state bits can be decoded from engine captures."""
import argparse
from pathlib import Path
from PIL import Image, ImageDraw

parser=argparse.ArgumentParser()
parser.add_argument('destination',type=Path)
args=parser.parse_args()
args.destination.mkdir(parents=True,exist_ok=True)
Image.new('RGBA',(8,8)).save(args.destination/'blank.png')
def cell(phase,state):
    image=Image.new('RGBA',(64,32),(0,0,0,0));draw=ImageDraw.Draw(image)
    draw.rectangle((1,1,62,30),fill=(30+phase*10,90+state*20,100,255))
    for bit in range(4):
        x=5+bit*12
        draw.rectangle((x,4,x+9,14),fill=(255,255,255,255) if (phase>>bit)&1 else (0,0,0,255))
    for bit in range(3):
        x=5+bit*12
        draw.rectangle((x,20,x+9,28),fill=(255,255,255,255) if (state>>bit)&1 else (0,0,0,255))
    draw.text((48,20),str(phase),fill='white')
    return image
for chunk in range(16):
    sheet=Image.new('RGBA',(1024,512))
    for direction in range(16):
        for phase in range(16):sheet.paste(cell(phase,3),(phase*64,direction*32))
    sheet.save(args.destination/f'attack-{chunk}.png')
for state,name in enumerate(('folded','preparing','prepared','attacking','folding')):
    sheet=Image.new('RGBA',(1024,512))
    for direction in range(256):sheet.paste(cell(0,state),((direction%16)*64,(direction//16)*32))
    sheet.save(args.destination/f'{name}.png')
shadow=Image.new('RGBA',(1024,512))
for direction in range(256):
    tile=Image.new('RGBA',(64,32))
    ImageDraw.Draw(tile).rectangle((56,4,60,14),fill=(0,0,0,128))
    shadow.paste(tile,((direction%16)*64,(direction//16)*32))
shadow.save(args.destination/'shadow.png')
print(args.destination)

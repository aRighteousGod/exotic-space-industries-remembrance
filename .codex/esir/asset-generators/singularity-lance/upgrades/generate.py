"""Deterministic lance capability art. Pillow; --output stages transparent layers.
Review preview.png and animation strips before promoting to main-pack graphics.
Extends the existing procedural lance art family; no companion-version change.
"""
from pathlib import Path
import argparse, math
from PIL import Image, ImageDraw, ImageFilter
parser=argparse.ArgumentParser()
parser.add_argument('--output',type=Path,required=True)
out=parser.parse_args().output
out.mkdir(parents=True,exist_ok=True)
WHITE=(242,254,255,255); CYAN=(55,224,255,255); VIOLET=(182,111,255,255)
def blank(size): return Image.new('RGBA',size)
def save(name,core):
    core.save(out/(name+'.png'))
    glow=core.filter(ImageFilter.GaussianBlur(5))
    glow.putalpha(glow.getchannel('A').point(lambda a:int(a*.65)))
    glow.save(out/(name+'-glow.png'))
def ring(d,p,r,color,width=2,start=0,end=360):
    x,y=p
    d.arc((x-r,y-r,x+r,y+r),start,end,fill=color,width=width)
def sigil(band,size=128):
    im=blank((size,size)); d=ImageDraw.Draw(im); s=size/128
    def line(points,color=WHITE,width=3):
        d.line([(x*s,y*s) for x,y in points],fill=color,width=max(1,int(width*s)),joint='curve')
    crack=[(58,16),(70,42),(54,61),(70,82),(59,112)]
    line(crack,VIOLET,8); line(crack)
    if band>=2:
        for pts in [[(66,40),(95,29),(100,14)],[(58,60),(27,43),(16,48)],[(66,82),(97,76),(109,94)],[(62,96),(31,103),(27,117)]]:
            line(pts,VIOLET,6); line(pts,WHITE,2)
    if band>=3:
        for start,end in [(8,76),(99,165),(193,255),(281,341)]:
            ring(d,(64*s,64*s),48*s,VIOLET,int(7*s),start,end)
            ring(d,(64*s,64*s),48*s,WHITE,int(3*s),start,end)
    return im
for band in range(1,4): save('wound-'+str(band),sigil(band))
for kind in ['base','axial','testament']:
    im=blank((256,64)); d=ImageDraw.Draw(im)
    if kind=='base':
        d.line([(0,32),(255,32)],fill=VIOLET,width=10)
        d.line([(0,32),(255,32)],fill=WHITE,width=3)
    elif kind=='axial':
        for y in [19,45]:
            d.line([(0,y),(40,y-3),(75,y+2),(118,y-2),(157,y+3),(205,y-2),(255,y)],fill=CYAN,width=4)
        d.line([(0,32),(255,32)],fill=WHITE,width=5)
    else:
        d.line([(0,32),(255,32)],fill=VIOLET,width=34)
        d.line([(0,32),(255,32)],fill=WHITE,width=23)
        d.line([(0,32),(255,32)],fill=(5,2,16,255),width=11)
        for x in [8,72,136,200,248]:
            d.polygon([(x,11),(x+5,32),(x,53),(x-4,32)],fill=(170,100,255,210))
    save('beam-'+kind,im)
for testament in [False,True]:
    for impact in [False,True]:
        name=('testament' if testament else 'collapse')+('-impact' if impact else '-warning')
        frames=12 if impact else 30
        sheet=blank((192*6,192*math.ceil(frames/6)))
        for frame in range(frames):
            im=blank((192,192)); d=ImageDraw.Draw(im); t=frame/(frames-1)
            if impact:
                alpha=int(255*(1-t)**.6); r=25+63*t
                if testament:
                    d.ellipse((96-r,96-r,96+r,96+r),fill=(4,1,12,alpha))
                    ring(d,(96,96),r,(210,180,255,alpha),7)
                    d.line((7,96,185,96),fill=(255,255,255,alpha),width=max(1,int(14*(1-t))))
                    d.line((96,7,96,185),fill=(255,255,255,alpha),width=max(1,int(14*(1-t))))
                else:
                    ring(d,(96,96),r,(135,244,255,alpha),max(1,int(9*(1-t))))
                    d.ellipse((86,86,106,106),fill=(255,255,255,alpha))
            else:
                r=90*(1-t)+4*t
                if testament: d.ellipse((96-r,96-r,96+r,96+r),fill=(4,1,12,220))
                ring(d,(96,96),r,WHITE,4)
                ring(d,(96,96),max(1,r-7),VIOLET if testament else CYAN,2)
                for angle in [0,90,180,270]:
                    a=math.radians(angle)
                    d.line((96+math.cos(a)*(r-13),96+math.sin(a)*(r-13),96+math.cos(a)*r,96+math.sin(a)*r),fill=WHITE,width=3)
            sheet.alpha_composite(im,((frame%6)*192,(frame//6)*192))
        save(name,sheet)
names=['axial-rupture','wound-memory','terminal-collapse','black-hole-testament']
for i,name in enumerate(names):
    im=blank((256,256)); d=ImageDraw.Draw(im)
    d.regular_polygon((128,130,117),8,rotation=22.5,fill=(11,17,27,255),outline=(73,93,113,255))
    for r in [106,102]: ring(d,(128,128),r,(102,125,145,255),2,190,355)
    for a in range(0,360,45):
        x,y=128+94*math.cos(math.radians(a)),128+94*math.sin(math.radians(a))
        d.ellipse((x-3,y-3,x+3,y+3),fill=(180,204,216,255))
    if i==0:
        d.line((54,202,202,54),fill=CYAN,width=22)
        d.line((50,198,198,50),fill=(9,20,31,255),width=13)
        d.line((47,194,194,47),fill=WHITE,width=6)
        for x,y in [(86,172),(135,126),(177,84)]: d.line((x,y,x-29,y-3,x-38,y-20),fill=CYAN,width=4)
    elif i==1: im.alpha_composite(sigil(3,180),(38,38))
    elif i==2:
        for r in [77,53,29]: ring(d,(128,128),r,CYAN if r==53 else WHITE,4)
        for a in [0,90,180,270]:
            x,y=128+67*math.cos(math.radians(a)),128+67*math.sin(math.radians(a))
            d.line((x,y,128+(x-128)*.55,128+(y-128)*.55),fill=VIOLET,width=10)
    else:
        d.ellipse((57,57,199,199),fill=(1,0,6,255),outline=VIOLET,width=14)
        ring(d,(128,128),72,WHITE,5)
        d.line((27,128,229,128),fill=WHITE,width=5)
        d.line((128,27,128,229),fill=WHITE,width=5)
        d.ellipse((69,69,187,187),fill=(2,0,7,255))
    im.save(out/(name+'.png'))
preview=Image.new('RGB',(1024,720),(31,39,41)); d=ImageDraw.Draw(preview)
for i,name in enumerate(names):
    im=Image.open(out/(name+'.png')); preview.paste(im,(i*256,0),im)
    d.text((i*256+12,258),name,fill='white')
for i,kind in enumerate(['base','axial','testament']):
    im=Image.open(out/('beam-'+kind+'.png')).resize((590,64))
    preview.paste(im,(20,300+i*74),im)
for band in range(1,4):
    im=sigil(band); preview.paste(im,(610+(band-1)*132,300),im)
for i,name in enumerate(['collapse-warning','collapse-impact','testament-warning','testament-impact']):
    im=Image.open(out/(name+'.png')).crop((0,0,192,192))
    preview.paste(im,(i*256+32,515),im)
preview.save(out/'preview.png')
print(out/'preview.png')


"""Original ESIR pictograms in the flat triangle language of vanilla alerts.

Installed Factorio 2.0.77 alert PNGs were visual references only. No game artwork
is copied: this geometry and its editable SVG masters are authored here.
"""
from math import cos, sin, pi

INK='#242627'
PALETTE={'danger':'#ff3930','warning':'#ffcf00','cold':'#00c2ee',
         'recovery':'#72d65b','earth':'#d2b478'}

class Pictogram:
    def __init__(self, tone='danger'):
        self.background=PALETTE[tone];self.shapes=[]
    def poly(self,points,cut=False):
        self.shapes.append(('polygon',points,self.background if cut else INK,0))
    def line(self,points,width=8,cut=False):
        self.shapes.append(('polyline',points,self.background if cut else INK,width))
    def oval(self,box,cut=False):
        self.shapes.append(('ellipse',box,self.background if cut else INK,0))
    def band(self,x,y,outer,inner,start=0,end=360):
        angles=[start+(end-start)*i/64 for i in range(65)]
        points=[(x+outer*cos(a*pi/180),y+outer*sin(a*pi/180)) for a in angles]
        points += [(x+inner*cos(a*pi/180),y+inner*sin(a*pi/180)) for a in reversed(angles)]
        self.poly(points)

def make_icons():
    icons={}
    def new(name,tone='danger'):
        icon=Pictogram(tone);icons[name]=icon;return icon

    g=new('gate-low-power','warning')
    g.band(64,83,27,18,10,167);g.band(64,83,27,18,197,350)
    g.poly([(63,35),(51,71),(64,71),(58,101),(79,63),(67,63),(75,35)])
    g.poly([(58,71),(70,66),(66,77),(55,82)],True)

    g=new('black-hole-containment')
    g.band(64,80,29,20,15,155);g.band(64,80,29,20,195,335)
    g.oval((54,70,74,90))

    g=new('matter-cascade')
    g.poly([(43,66),(64,53),(85,66),(64,78)])
    g.poly([(40,75),(59,86),(59,108),(40,96)])
    g.poly([(70,86),(89,75),(89,96),(70,108)])
    g.poly([(25,87),(35,91),(29,102)]);g.poly([(96,96),(105,103),(95,110)])

    g=new('gaia-degradation','warning')
    g.poly([(29,108),(29,81),(45,81),(45,50),(62,50),(55,70),(64,81),(51,108)])
    g.poly([(73,50),(83,50),(83,81),(99,81),(99,108),(64,108),(77,84),(67,70)])

    g=new('fluid-phase-shift','warning')
    g.poly([(49,56),(65,82),(64,96),(55,106),(43,106),(34,98),(33,84)])
    g.line([(78,104),(88,93),(79,81),(88,68),(81,57)],8)

    g=new('fluid-data')
    g.line([(27,89),(42,89),(52,56),(59,83)],9)
    g.line([(69,94),(73,106),(85,74),(93,89),(102,89)],9)

    g=new('fluid-cryo','cold')
    for angle in (30,90,150):
        x=25*cos(angle*pi/180);y=25*sin(angle*pi/180)
        g.line([(64-x,80-y),(64+x,80+y)],8)
    g.line([(48,61),(53,73),(40,73)],7)
    g.line([(80,61),(75,73),(88,73)],7)
    g.line([(48,98),(53,87),(40,87)],7)
    g.line([(79,99),(75,87),(88,87)],7)
    g.poly([(57,92),(70,86),(76,91),(59,99)],True)

    g=new('fluid-thermal')
    g.poly([(26,96),(44,96),(44,79),(55,79),(55,108),(26,108)])
    g.poly([(75,43),(75,64),(86,57),(96,82),(95,97),(83,109),(68,106),(58,94),(60,78)])
    g.poly([(76,77),(79,90),(86,84),(87,97),(78,102),(70,95)],True)

    g=new('fluid-chemical')
    g.poly([(64,39),(81,68),(80,79),(71,88),(59,88),(48,80),(47,68)])
    g.poly([(26,97),(48,97),(56,107),(72,107),(80,94),(102,94),(102,113),(26,113)])

    g=new('fluid-rupture')
    g.poly([(31,80),(51,80),(46,91),(54,100),(46,109),(28,109)])
    g.poly([(79,80),(97,80),(100,109),(77,109),(85,100),(76,91)])
    g.line([(33,78),(33,113)],7);g.line([(95,78),(95,113)],7)
    g.poly([(61,46),(68,46),(67,65),(62,65)])
    g.poly([(48,60),(55,55),(61,70),(55,73)]);g.poly([(75,56),(82,61),(74,73),(68,70)])

    g=new('ecology-wildfire')
    g.poly([(50,45),(64,69),(57,69),(70,87),(56,87),(56,110),(45,110),(45,87),(30,87),(42,69),(38,69)])
    g.poly([(82,64),(83,79),(92,73),(101,93),(97,105),(87,112),(75,108),(70,97),(73,82)])

    g=new('ecology-flood','warning')
    g.line([(26,90),(39,84),(52,90),(65,95),(79,89),(91,84),(103,89)],8)
    g.line([(26,108),(39,102),(52,108),(65,113),(79,107),(91,102),(103,107)],8)
    g.poly([(59,75),(59,59),(48,59),(64,42),(80,59),(69,59),(69,75)])

    g=new('ecology-drought','warning')
    g.oval((52,43,77,68))
    g.poly([(25,88),(49,80),(60,88),(51,99),(57,112),(25,112)])
    g.poly([(78,80),(103,88),(103,112),(77,112),(69,99),(80,90)])

    g=new('ecology-cliff','warning')
    g.poly([(30,110),(30,82),(55,45),(69,45),(59,76),(69,86),(53,110)])
    g.poly([(79,66),(90,80),(102,110),(67,110),(81,87),(72,77)])

    g=new('ecology-paving','warning')
    g.poly([(45,61),(60,61),(60,81),(37,81)])
    g.poly([(70,61),(83,61),(91,81),(78,81),(78,73),(70,73)])
    g.poly([(29,91),(59,91),(59,112),(42,112),(42,103),(29,103)])
    g.poly([(70,91),(101,91),(101,112),(70,112)])

    g=new('ecology-pollution','warning')
    g.oval((41,57,64,79));g.oval((57,48,80,79));g.oval((73,62,91,80))
    g.poly([(35,104),(47,84),(70,83),(94,97),(77,110),(52,113)])
    g.line([(44,105),(78,92)],6,True)

    g=new('ecology-restoration','recovery')
    g.poly([(25,88),(50,88),(60,98),(52,111),(25,111)])
    g.poly([(78,88),(103,88),(103,111),(76,111),(68,98)])
    g.poly([(40,69),(51,69),(51,60),(64,75),(51,88),(51,80),(36,80)])
    g.poly([(77,60),(77,69),(88,69),(92,80),(77,80),(77,88),(64,75)])

    g=new('ecology-depletion-scars','warning')
    g.poly([(64,42),(77,56),(64,69),(51,56)])
    g.poly([(28,88),(44,75),(53,86),(47,97),(53,111),(28,104)])
    g.poly([(84,75),(101,88),(101,104),(75,111),(82,97),(75,86)])

    g=new('ecology-working-scars','warning')
    g.poly([(49,42),(79,42),(79,75),(64,100),(49,75)])
    g.poly([(47,61),(81,72),(77,80),(47,70)],True)
    g.poly([(53,80),(75,87),(70,95),(57,90)],True)
    g.poly([(25,102),(46,102),(54,112),(25,112)]);g.poly([(83,102),(103,102),(103,112),(75,112)])

    g=new('ecology-mining-restoration','recovery')
    g.poly([(28,82),(36,82),(36,95),(48,104),(80,104),(92,95),(92,82),(100,82),(100,102),(83,113),(45,113),(28,102)])
    g.poly([(60,99),(60,74),(45,71),(43,59),(55,57),(65,69),(72,50),(81,49),(82,65),(70,77),(70,99)])

    g=new('ecology-tree-stress','warning')
    g.line([(40,110),(40,87),(47,65),(59,57),(71,62)],9)
    g.poly([(59,49),(75,51),(88,70),(92,105),(78,96),(64,76),(56,60)])

    g=new('ecology-tree-recovery','recovery')
    g.poly([(59,111),(59,94),(42,84),(38,68),(47,52),(64,40),(84,50),(89,67),(84,83),(69,95),(69,111)])
    g.line([(60,90),(62,70),(76,56)],7,True)

    g=new('ecology-regrowth','recovery')
    for x,top,base,w in [(38,86,111,9),(64,47,111,14),(90,86,111,9)]:
        g.poly([(x-4,base),(x-4,top+15),(x-w,top+10),(x-w-3,top),
                (x-4,top+3),(x,top+11),(x+4,top+3),(x+w+3,top),
                (x+w,top+10),(x+4,top+16),(x+4,base)])

    g=new('ecology-aging','earth')
    g.poly([(47,58),(67,52),(86,61),(94,81),(88,103),(68,113),(44,106),(33,86),(35,70)])
    g.poly([(49,68),(65,62),(78,68),(84,82),(80,96),(66,103),(49,97),(43,83)],True)
    g.poly([(55,77),(66,72),(76,82),(72,92),(59,94),(51,85)])

    g=new('ecology-rot','earth')
    g.poly([(36,71),(88,85),(80,108),(30,90)])
    g.poly([(57,74),(50,85),(62,88),(56,99),(65,103),(72,85),(61,82),(65,77)],True)
    g.oval((77,84,103,112));g.oval((84,91,97,105),True)

    g=new('ecology-thermal')
    g.poly([(24,105),(40,98),(54,105),(72,97),(104,105),(104,114),(24,114)])
    g.line([(43,90),(37,80),(43,66)],7)
    g.line([(65,88),(57,71),(65,49)],8)
    g.line([(85,90),(79,80),(85,66)],7)

    g=new('ecology-blood','recovery')
    g.poly([(64,37),(79,61),(78,74),(70,82),(58,82),(49,73),(49,62)])
    g.poly([(60,84),(69,84),(69,97),(82,89),(96,95),(93,103),(83,99),(73,107),(73,115),(63,115),(63,108),(49,102),(40,112),(29,112),(29,104),(37,104),(47,91),(60,97)])
    return icons

def svg_document(name,glyph):
    fmt=lambda n:f'{n:.3f}'.rstrip('0').rstrip('.')
    lines=['<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">',
           f'<title>{name}: ESIR vanilla-style alert pictogram</title>',
           f'<polygon points="64,5 123,119 5,119" fill="{glyph.background}" stroke="none" stroke-width="0"/>']
    for kind,coords,color,width in glyph.shapes:
        attrs=f'fill="{color if kind!="polyline" else "none"}" stroke="{color if width else "none"}" stroke-width="{width}" stroke-linejoin="round" stroke-linecap="butt"'
        if kind=='ellipse':
            x1,y1,x2,y2=coords
            lines.append(f'<ellipse cx="{fmt((x1+x2)/2)}" cy="{fmt((y1+y2)/2)}" rx="{fmt((x2-x1)/2)}" ry="{fmt((y2-y1)/2)}" {attrs}/>')
        else:
            points=' '.join(f'{fmt(x)},{fmt(y)}' for x,y in coords)
            lines.append(f'<{kind} points="{points}" {attrs}/>')
    return '\n'.join(lines+['</svg>',''])

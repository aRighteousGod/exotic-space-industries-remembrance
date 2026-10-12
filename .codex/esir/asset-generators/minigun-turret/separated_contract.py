"""Exact endpoint exposure contract for mechanically separated minigun sprites."""
import math
SOURCE_SHA256 = '453a8f5b75fd16630803d698293222cf9e07a3e1cecb1f7c3b40434d75008f59'
SCHEMA = 'esir.minigun.separated.v2'
PARKED, RUNNING = [1], [2]
SPIN_UP = [1, *range(3, 13), 2]
SPIN_DOWN = [2, *range(13, 29), 1]
PILOT_DIRECTIONS = list(range(0, 256, 32))

def phase_degrees(kind, t):
    if kind == 'parked': return 0.0
    if kind == 'running': return 90.0*t
    if kind == 'up':
        if t <= .5: return 0.0
        if t >= 10.5: return 315+90*(t-10.5)
        u=(t-.5)/10
        return 900*(u**4/4+3*u**5/5-u**6/2)
    if kind == 'down':
        if t <= .5: return 90*t
        if t >= 16.5: return 720.0
        u=(t-.5)/16
        return 45+1440*(u-23*u**3/16+43*u**4/32-9*u**5/16+u**6/8)
    raise ValueError(kind)

def physical_pose(index):
    if index == 0: return 'parked',0.0
    if index == 1: return 'running',0.0
    if 2 <= index <= 11: return 'up',float(index-1)
    if 12 <= index <= 27: return 'down',float(index-11)
    raise ValueError(index)

def phase_expression(kind, center):
    t=f'(frame-100+{center!r})'
    if kind == 'parked': degrees='0.0'
    elif kind == 'running': degrees=f'(90*{t})'
    elif kind == 'up':
        u=f'(({t}-0.5)/10)'
        ramp=f'(900*({u}**4/4+3*{u}**5/5-{u}**6/2))'
        degrees=f'(0 if {t}<=0.5 else (315+90*({t}-10.5) if {t}>=10.5 else {ramp}))'
    elif kind == 'down':
        u=f'(({t}-0.5)/16)'
        ramp=f'(45+1440*({u}-23*{u}**3/16+43*{u}**4/32-9*{u}**5/16+{u}**6/8))'
        degrees=f'(90*{t} if {t}<=0.5 else (720 if {t}>=16.5 else {ramp}))'
    else: raise ValueError(kind)
    return f'({math.pi/180!r}*{degrees})'

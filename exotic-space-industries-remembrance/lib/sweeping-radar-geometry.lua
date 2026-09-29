--==============================================================================
-- ESIR FILE MAP
-- owns: exact chunk supercover and incremental angular bucket construction
-- loaded_by: scripts/control/sweeping-radar; isolated geometry QC
-- cadence: bounded candidate/cursor operations; no full-disk sorting
--==============================================================================
-- blueprint: .codex/esir/blueprints/sweeping-radar.md#contract
local geometry = {}
local pi, abs, min, max = math.pi, math.abs, math.min, math.max
local EPS = 0.00000001

function geometry.angle(x,y)
    return (math.atan2(x,-y)*180/pi)%360
end

local function clip(poly,a,b,c)
    local result={}
    local previous=poly[#poly]
    if not previous then return result end
    local old=a*previous.x+b*previous.y+c
    for _,point in ipairs(poly) do
        local value=a*point.x+b*point.y+c
        if (value>=-EPS)~=(old>=-EPS) then
            local t=old/(old-value)
            result[#result+1]={x=previous.x+(point.x-previous.x)*t,y=previous.y+(point.y-previous.y)*t}
        end
        if value>=-EPS then result[#result+1]=point end
        previous,old=point,value
    end
    return result
end

local function annulus(poly,near2,far2)
    if #poly==0 then return false end
    local inside=true
    local least=math.huge
    local most=0
    local area=0
    local old=poly[#poly]
    for _,point in ipairs(poly) do
        area=area+old.x*point.y-point.x*old.y
        most=max(most,point.x*point.x+point.y*point.y)
        local dx,dy=point.x-old.x,point.y-old.y
        if dx*(-old.y)-dy*(-old.x)<-EPS then inside=false end
        local length=dx*dx+dy*dy
        local t=length>EPS and max(0,min(1,-(old.x*dx+old.y*dy)/length)) or 0
        local x,y=old.x+t*dx,old.y+t*dy
        least=min(least,x*x+y*y)
        old=point
    end
    if inside and #poly>=3 and abs(area)>EPS then least=0 end
    return least<=far2+EPS and most>=near2-EPS
end

local function wedge(poly,start,width)
    local a=start*pi/180
    local b=(start+width)*pi/180
    poly=clip(poly,math.cos(a),math.sin(a),0)
    return clip(poly,-math.cos(b),-math.sin(b),0)
end

---@param settings table Effective validated settings.
---@param position MapPosition
---@return table Incremental serializable geometry builder.
function geometry.new(settings,position)
    local far=settings.radius*32
    local start=settings.mode==1 and 0 or settings.start%360
    local width=settings.mode==1 and 360 or (settings.stop-start)%360
    if width==0 then width=360 end
    local cx,cy=position.x,position.y
    local lowerx,upperx=math.floor((cx-far-16)/32)-1,math.floor((cx+far+16)/32)
    local lowery,uppery=math.floor((cy-far-16)/32)-1,math.floor((cy+far+16)/32)
    return {mode=settings.mode,start=start,width=width,bearing=settings.bearing,
        near=(settings.mode==1 or settings.mode==2) and 0 or settings.near*32,far=far,
        position={x=cx,y=cy},minx=lowerx,maxx=upperx,miny=lowery,maxy=uppery,
        x=lowerx,y=lowery,buckets={},cells={},phase="cells",bucket=0,offset=1,count=0}
end

function geometry.contains(g,x,y)
    local distance=x*x+y*y
    if g.mode==5 then
        local angle=g.bearing*pi/180
        local along=x*math.sin(angle)-y*math.cos(angle)
        local across=x*math.cos(angle)+y*math.sin(angle)
        return along>=g.near-EPS and along<=g.far+EPS and abs(across)<=16+EPS
    end
    return distance>=g.near*g.near-EPS and distance<=g.far*g.far+EPS
        and (g.width==360 or (geometry.angle(x,y)-g.start)%360<=g.width+EPS)
end

function geometry.intersects(g,x,y)
    local x0,y0=x*32-g.position.x,y*32-g.position.y
    local poly={{x=x0,y=y0},{x=x0+32,y=y0},{x=x0+32,y=y0+32},{x=x0,y=y0+32}}
    if g.mode==5 then
        local angle=g.bearing*pi/180
        local sx,sy=math.sin(angle),-math.cos(angle)
        local ax,ay=math.cos(angle),math.sin(angle)
        poly=clip(poly,sx,sy,-g.near)
        poly=clip(poly,-sx,-sy,g.far)
        poly=clip(poly,ax,ay,16)
        poly=clip(poly,-ax,-ay,16)
        return #poly>0
    end
    local near2,far2=g.near*g.near,g.far*g.far
    if g.width==360 then return annulus(poly,near2,far2) end
    if g.width<=180 then return annulus(wedge(poly,g.start,g.width),near2,far2) end
    return annulus(wedge(poly,g.start,180),near2,far2)
        or annulus(wedge(poly,g.start+180,g.width-180),near2,far2)
end

---One operation is one candidate cell, copied cell, or empty bucket traversal.
function geometry.step(g)
    if g.phase=="ready" then return false end
    if g.phase=="cells" then
        local x,y=g.x,g.y
        if geometry.intersects(g,x,y) then
            local dx,dy=x*32+16-g.position.x,y*32+16-g.position.y
            local angle=geometry.angle(dx,dy)
            local delta=(angle-g.start)%360
            if delta>g.width then delta=(360-delta)<(delta-g.width) and 0 or g.width end
            local bucket=min(359,math.floor(delta))
            if g.mode==5 then
                local a=g.bearing*pi/180
                bucket=max(0,min(359,math.floor((dx*math.sin(a)-dy*math.cos(a))/max(1,g.far)*359)))
            end
            g.buckets[bucket]=g.buckets[bucket] or {}
            local entries=g.buckets[bucket]
            entries[#entries+1]={x=x,y=y,angle=g.mode==5 and g.bearing or (g.start+delta)%360}
        end
        g.x=g.x+1
        if g.x>g.maxx then g.x=g.minx;g.y=g.y+1 end
        if g.y>g.maxy then g.phase="buckets" end
    else
        local bucket=g.buckets[g.bucket]
        if bucket and bucket[g.offset] then
            g.count=g.count+1
            g.cells[g.count]=bucket[g.offset]
            g.offset=g.offset+1
        else
            g.buckets[g.bucket]=nil
            g.bucket=g.bucket+1
            g.offset=1
            if g.bucket>359 then g.phase="ready";g.buckets=nil end
        end
    end
    return true
end
return geometry

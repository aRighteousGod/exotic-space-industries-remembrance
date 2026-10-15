-- Supplemental Lua screening: actual updater/consumers/history/commit, native seams mocked.
-- Run from repo root; no engine or production writes.
local file=assert(io.open("scripts/qc/terrain-evolution/v2-static.lua","r"))
local source=file:read("*a");file:close()
local boundary=assert(source:find("local saved={}",1,true))
assert(load(source:sub(1,boundary-1)..[===[
local failures=0
check=function(ok,label) checks=checks+1;if not ok then failures=failures+1;print("FAIL "..label) end end
local propose=up(service,"propose")
local commit=up(update,"commit")
local validate=up(update,"recover_tiles")
terrain.configure{vat={is_terrain_claimed=function() return false end}}
local function fixture()
    local root,entry=fresh()
    root.config.cold_chunks=0
    entry.config.recovery=false;entry.config.mining_recovery=true
    entry.config.mining_probability=1;entry.config.mining_patch_radius=0;entry.config.hazard_radius=0
    local prototype={is_foundation=false,collision_mask={layers={}}}
    prototypes={tile={}}
    for _,name in ipairs{"grass-1","grass-3","grass-4"} do prototypes.tile[name]=prototype end
    local state={tiles={},writes=0,decoratives=0,ignore_writes=false}
    local function key(x,y) if type(x)=="table" then y=x.y or x[2];x=x.x or x[1] end;return x..":"..y end
    entry.surface.get_tile=function(x,y)
        return {valid=true,name=state.tiles[key(x,y)] or "grass-1",prototype=prototype,collides_with=function() return false end}
    end
    entry.surface.set_tiles=function(tiles)
        for _,tile in ipairs(tiles) do
            if state.before_write then state.before_write() end
            state.writes=state.writes+1
            if not state.ignore_writes then state.tiles[key(tile.position)]=tile.name end
        end
    end
    entry.surface.destroy_decoratives=function() state.decoratives=state.decoratives+1 end
    return root,entry,state
end
local function run(first,last) for tick=first,last,16 do update{tick=tick} end end
local function get_history(root,x,y) local i=root.history.index["1:"..x..":"..y];return i and root.history.items[i] end

-- Real admission and updater order, including background ownership validation.
for _,cause in ipairs{"thermal","mining"} do
    local root,entry,state=fixture()
    check(terrain.enqueue_scar(entry.surface,{x=768,y=768},cause,200,{trigger="depletion"}),cause.." accepted")
    local request=root.pending.items[1]
    state.before_write=function() check(request.last_result=="retry",cause.." has no applied receipt before native write") end
    run(200,504)
    local h=get_history(root,768,768)
    check(state.tiles["768:768"]=="grass-3" and state.writes==1,cause.." native tile write commits once")
    check(h and h.origin=="grass-1" and h.expected=="grass-3" and #h.path==1,cause.." keeps exact lineage with recovery disabled")
    check((root.counters.ownership_lost or 0)==0,cause.." does not self-invalidate staged history")
    check(request.last_result=="applied",cause.." reports applied only after commit")
end

-- Committing another stage preserves both steps, then final recovery frees history.
local root,entry,state=fixture()
local b=budget();check(propose(root,b,entry.surface,0,0,"thermal",100)==true,"first transition staged")
b.searches=0;validate(root,b,100);commit(root,b)
b=budget();check(propose(root,b,entry.surface,0,0,"thermal",200)==true,"second transition staged")
b.searches=0;validate(root,b,200);commit(root,b)
local h=get_history(root,0,0)
check(h and h.expected=="grass-4" and #h.path==2 and h.path[1]=="grass-1" and h.path[2]=="grass-3","repeated degradation retains exact path")
for _,target in ipairs{"grass-3","grass-1"} do
    b=budget();check(propose(root,b,entry.surface,0,0,"thermal",300,target,true)==true,"recovery stage "..target)
    b.searches=0;validate(root,b,300);commit(root,b)
end
check(state.tiles["0:0"]=="grass-1" and #root.history.items==0,"exact final restoration releases lineage")
check((root.counters.ownership_lost or 0)==0,"successful staged recovery does not lose ownership")

-- Native refusal must not report success, clear decoratives, or erase still-owned older history.
root,entry,state=fixture()
b=budget();propose(root,b,entry.surface,0,0,"thermal",100);commit(root,b)
h=get_history(root,0,0)
state.ignore_writes=true
local request={last_result="retry"}
b=budget();check(propose(root,b,entry.surface,0,0,"thermal",200,nil,false,request)==true,"second stage admitted before native refusal")
b.searches=0;validate(root,b,200);commit(root,b)
h=get_history(root,0,0)
check(request.last_result~="applied" and root.counters.changed==1,"refused native write emits no applied effect")
check(state.decoratives==1,"refused native write leaves decoratives alone")
check(h and h.origin=="grass-1" and h.expected=="grass-3" and #h.path==1 and h.path[1]=="grass-1","refused write preserves still-owned committed lineage")

-- A new proposal whose native write never applies must not retain fictional history.
root,entry,state=fixture();state.ignore_writes=true
request={last_result="retry"};b=budget()
propose(root,b,entry.surface,0,0,"thermal",100,nil,false,request);commit(root,b)
check(#root.history.items==0 and (root.counters.changed or 0)==0 and state.decoratives==0,"refused first write leaves no fictional history or effect")

-- Actual external replacement invalidates previous ownership rather than rolling it back.
root,entry,state=fixture();b=budget()
propose(root,b,entry.surface,0,0,"thermal",100);commit(root,b)
b=budget();propose(root,b,entry.surface,0,0,"thermal",200)
state.tiles["0:0"]="grass-1";commit(root,b)
check(#root.history.items==0 and root.counters.changed==1,"external replacement invalidates committed ownership")

print(("RESULT %d history-order checks; %d failures"):format(checks,failures))
if failures>0 then os.exit(1) end
]===],"ev2-history-order","t",_ENV))()

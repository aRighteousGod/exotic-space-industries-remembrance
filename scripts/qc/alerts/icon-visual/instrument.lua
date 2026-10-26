-- Staged only; production retains the shared handler as native-alert owner.
local visual=require('__zzz-esir-icons-qc__/visual')
local visual_context={alerts=require('lib/alerts'),catalog=require('lib/alert-catalog'),
    ecology=require('scripts/control/terrain-alerts'),gui=require('scripts/control/terrain-gui')}
remote.add_interface('ei-icons-qc',{step=function(index,tick)
    return visual.step(visual_context,game.get_player(index),tick)
end})

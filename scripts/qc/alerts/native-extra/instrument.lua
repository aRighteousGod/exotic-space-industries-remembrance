local extra=require('__zzz-esir-alerts-qc__/extra')
local extra_context={gate=require('scripts/control/gate'),alerts=require('lib/alerts'),
    ecology=require('scripts/control/terrain-alerts'),gui=require('scripts/control/terrain-gui')}
remote.add_interface('ei-alerts-qc',{step=function(index,tick) return extra.step(extra_context,game.get_player(index),tick) end})

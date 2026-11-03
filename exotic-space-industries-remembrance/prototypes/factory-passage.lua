--==============================================================================
-- ESIR FILE MAP
-- owns: permanent identity of invisible character-only pipe joint barriers
-- loaded_by: data.lua
-- cadence: data stage
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: startup
--==============================================================================
-- blueprint: .codex/esir/blueprints/factory-passage.md#contract
local config = require("lib/factory-passage-config")
local util = require("util")
data:extend{{type="collision-layer",name=config.layer}}
for _, axis in ipairs{"horizontal","vertical"} do
  for step=1,config.helper_steps do
    local half=step*config.helper_quantum/2
    local x,y = axis=="horizontal" and half or 0.2,axis=="horizontal" and 0.2 or half
    data:extend{{type="simple-entity-with-owner",name=config.helper_prefix..axis.."-"..step,
        flags={"placeable-off-grid","not-on-map","not-blueprintable","not-deconstructable","not-flammable","not-upgradable","not-repairable"},
        hidden=true,hidden_in_factoriopedia=true,selectable_in_game=false,max_health=1,is_military_target=false,
        collision_box={{-x,-y},{x,y}},selection_box={{0,0},{0,0}},
        collision_mask={layers={[config.layer]=true},not_colliding_with_itself=true},
        picture=util.empty_sprite(),create_ghost_on_death=false}}
  end
end

--==============================================================================
-- ESIR FILE MAP
-- owns: custom alert signals and shared invisible position marker
-- loaded_by: data.lua
-- cadence: data stage
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: data stage reload
--==============================================================================
-- blueprint: .codex/esir/blueprints/runtime-alerts.md#contract
data:extend(require("lib/alert-icon-sets").builtin_prototypes())
-- Nonselectable notification helper: intentionally no death, hit, sound or encyclopedia presentation.
data:extend{{type="simple-entity-with-owner",name="ei-alert-anchor",hidden=true,hidden_in_factoriopedia=true,
    flags={"not-on-map","placeable-off-grid","not-blueprintable","not-deconstructable","not-upgradable","not-repairable","not-flammable","not-in-kill-statistics","hide-alt-info"},
    selectable_in_game=false,collision_mask={layers={}},collision_box={{0,0},{0,0}},selection_box={{0,0},{0,0}},
    is_military_target=false,max_health=1,random_variation_on_create=false,
    picture={filename=ei_lib.empty_sprite(),width=64,height=64}}}
-- Keep legacy saves loadable even if ecology is disabled at startup.
local legacy = table.deepcopy(data.raw["simple-entity-with-owner"]["ei-alert-anchor"])
legacy.name = "ei-ecology-alert-anchor"
data:extend{legacy}

require ("bonus-gui-ordering")

data:extend({  
  {
    type = "ammo-category",
    name = "tl-advanced-tesla-coil-turret-category"
  }
})

-- TODO not really sure what this is supposed to be...
--      However, bonus GUI is the panel below the minimap
--      which brings up a UI with bonus values
for k,v in pairs(data.raw["ammo-category"]) do
  if not v.bonus_gui_order then
    v.bonus_gui_order = bonus_gui_ordering[k]
  end
end


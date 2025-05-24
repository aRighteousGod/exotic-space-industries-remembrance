data.raw['tool']['space-science-pack'].icon = data.raw['item']['ei-space-data'].icon
data.raw['tool']['space-science-pack'].pictures = data.raw['item']['ei-space-data'].pictures
data.raw['tool']['space-science-pack'].icon_size = data.raw['item']['ei-space-data'].icon_size

data.raw['item']["iron-plate"].icon = ei_graphics_item_path.."iron-ingot.png"
data.raw['item']["copper-plate"].icon = ei_graphics_item_path.."copper-ingot.png"
data.raw['item']["steel-plate"].icon = ei_graphics_item_path.."steel-ingot.png"

data.raw['item']["iron-plate"].subgroup = "ei-refining-ingot"
data.raw['item']["copper-plate"].subgroup = "ei-refining-ingot"
data.raw['item']["steel-plate"].subgroup = "ei-refining-ingot"
data.raw['item']["ei-gold-ingot"].subgroup = "ei-refining-ingot"
data.raw['item']["ei-lead-ingot"].subgroup = "ei-refining-ingot"
data.raw['item']["ei-neodym-ingot"].subgroup = "ei-refining-ingot"

ei_lib.disable("automation-science-pack")
ei_lib.disable("logistic-science-pack")
ei_lib.disable("chemical-science-pack")
ei_lib.disable("military-science-pack")
ei_lib.disable("production-science-pack")
ei_lib.disable("utility-science-pack")

for _, item in pairs(data.raw.item) do
  if endswith(item.name,"-barrel") then item.stack_size = 100 end
  if item.type == "gun" then item.stack_size = 1 end
  if item.subgroup == "gun" then item.stack_size = 1 end
end

table.insert(data.raw['simple-entity']['fulgurite'].minable.results, {
  amount_max = 1,
  amount_min = 0,
  name = "ei-alien-seed",
  type = "item"
})
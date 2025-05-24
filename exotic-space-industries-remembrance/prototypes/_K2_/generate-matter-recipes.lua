local matter_lib = require("prototypes._K2_.libraries.matter")

matter_lib.make_recipes({
  material = { type = "item", name = "coal", amount = 100 },
  matter_count = 100,
  energy_required = 10,
  unlocked_by = "kr-matter-coal-processing",
  needs_stabilizer = true,
  loss = 2
})

matter_lib.make_recipes({
  material = { type = "item", name = "copper-ore", amount = 100 },
  matter_count = 100,
  energy_required = 10,
  unlocked_by = "kr-matter-copper-processing",
  needs_stabilizer = true,
  loss = 2
})

matter_lib.make_recipes({
  material = { type = "fluid", name = "crude-oil", amount = 100 },
  matter_count = 100,
  energy_required = 10,
  unlocked_by = "kr-matter-oil-processing",
  needs_stabilizer = true,
  loss = 10
})

matter_lib.make_recipes({
  material = { type = "fluid", name = "water", amount = 100 },
  matter_count = 100,
  energy_required = 10,
  needs_stabilizer = true,
  loss = 10
})

matter_lib.make_recipes({
  material = { type = "item", name = "iron-ore", amount = 100 },
  matter_count = 100,
  energy_required = 10,
  unlocked_by = "kr-matter-iron-processing",
  needs_stabilizer = true,
  loss = 2
})

matter_lib.make_recipes({
  material = { type = "item", name = "matter-cube", amount = 1 },
  matter_count = 10000,
  energy_required = 100,
  needs_stabilizer = true,
  unlocked_by = "kr-matter-cube",
  loss = 1
})

matter_lib.make_recipes({
  material = { type = "item", name = "raw-rare-metals", amount = 100 },
  matter_count = 1000,
  energy_required = 10,
  unlocked_by = "kr-matter-rare-metals-processing",
  needs_stabilizer = true,
  loss = 4
})

matter_lib.make_recipes({
  material = { type = "item", name = "stone", amount = 100 },
  matter_count = 100,
  energy_required = 10,
  unlocked_by = "kr-matter-stone-processing",
  needs_stabilizer = true,
  loss = 2
})

matter_lib.make_recipes({
  material = { type = "item", name = "uranium-ore", amount = 100 },
  matter_count = 1000,
  energy_required = 10,
  unlocked_by = "kr-matter-uranium-processing",
  needs_stabilizer = true,
  loss = 4
})

matter_lib.make_recipes({
  material = { type = "item", name = "wood", amount = 100 },
  matter_count = 100,
  energy_required = 10,
  needs_stabilizer = true,
  loss = 2
})

matter_lib.make_recipes({
  material = { type = "item", name = "raw-imersite", amount = 100 },
  matter_count = 1000,
  energy_required = 10,
  needs_stabilizer = true,
  unlocked_by = "kr-matter-minerals-processing",
  loss = 4
})

matter_lib.make_recipes({
  material = { type = "item", name = "carbon", amount = 100 },
  matter_count = 5000,
  energy_required = 10,
  needs_stabilizer = true,
  unlocked_by = "tungsten-carbide",
  loss = 5
})

matter_lib.make_recipes({
  material = { type = "item", name = "tungsten-ore", amount = 100 },
  matter_count = 5000,
  energy_required = 10,
  needs_stabilizer = true,
  unlocked_by = "tungsten-carbide",
  loss = 5
})

matter_lib.make_recipes({
  material = { type = "item", name = "holmium-ore", amount = 100 },
  matter_count = 5000,
  energy_required = 10,
  needs_stabilizer = true,
  unlocked_by = "holmium-processing",
  loss = 5
})

matter_lib.make_recipes({
  material = { type = "item", name = "calcite", amount = 100 },
  matter_count = 5000,
  energy_required = 10,
  needs_stabilizer = true,
  unlocked_by = "foundry",
  loss = 5
})

matter_lib.make_recipes({
  material = { type = "fluid", name = "thruster-fuel", amount = 100 },
  matter_count = 100,
  energy_required = 10,
  needs_stabilizer = true,
  loss = 2
})

matter_lib.make_recipes({
  material = { type = "fluid", name = "thruster-oxidizer", amount = 100 },
  matter_count = 100,
  energy_required = 10,
  needs_stabilizer = true,
  loss = 2
})

if mods["exotic-space-industries-remembrance"] then 

matter_lib.make_recipes({
  material = { type = "fluid", name = "ei-cryoflux", amount = 100 },
  matter_count = 100,
  energy_required = 10,
  needs_stabilizer = true,
  loss = 20
})

matter_lib.make_recipes({
  material = { type = "fluid", name = "ei-phythogas", amount = 100 },
  matter_count = 100,
  energy_required = 10,
  needs_stabilizer = true,
  loss = 20
})

end
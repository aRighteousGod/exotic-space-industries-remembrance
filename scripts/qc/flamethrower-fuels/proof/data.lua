local turret = table.deepcopy(data.raw["fluid-turret"]["flamethrower-turret"])
turret.name = "esir-flamethrower-proof"
turret.attack_parameters.fluids = {{type="crude-oil"},{type="light-oil"},{type="heavy-oil"}}
data:extend{turret}

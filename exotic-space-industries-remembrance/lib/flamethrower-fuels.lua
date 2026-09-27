-- Shared startup/data/runtime contract for flamethrower fuel identity and balance.
---@class ESIRFlameFuel
---@field id string
---@field fluid string
---@field damage number
---@field lifetime number
---@field technology string
---@field flame number[]
---@field smoke number[]
---@field ammo string
---@field turret string
local model = {setting="ei-flamethrower-fuel-adaptation", base_turret="flamethrower-turret"}
---@type ESIRFlameFuel[]
model.fuels = {
    {id="heavy-distillate", fluid="ei-heavy-destilate", damage=0.4, lifetime=2, technology="ei-destill-tower", flame={0.85,0.19,0.06}, smoke={0.12,0.10,0.09,0.75}},
    {id="medium-distillate", fluid="ei-medium-destilate", damage=0.5, lifetime=1.75, technology="ei-destill-tower", flame={1,0.38,0.12}, smoke={0.26,0.20,0.15,0.65}},
    {id="residual-oil", fluid="ei-residual-oil", damage=0.65, lifetime=1.5, technology="flamethrower", flame={0.90,0.46,0.10}, smoke={0.09,0.08,0.07,0.8}},
    {id="bio-oil", fluid="ei-bio-oil", damage=0.8, lifetime=1.25, technology="ei-bio-oil", flame={0.65,1,0.16}, smoke={0.33,0.38,0.17,0.5}},
    {id="crude-oil", fluid="crude-oil", damage=1, lifetime=1, technology="flamethrower", flame={1,0.58,0.22}, smoke={0.3,0.3,0.3,0.55}},
    {id="heavy-oil", fluid="heavy-oil", damage=1.15, lifetime=1.5, technology="ei-destill-tower", flame={1,0.55,0.12}, smoke={0.19,0.19,0.19,0.65}},
    {id="light-oil", fluid="light-oil", damage=1.25, lifetime=1, technology="ei-destill-tower", flame={1,0.83,0.3}, smoke={0.5,0.46,0.37,0.3}},
    {id="petroleum-gas", fluid="petroleum-gas", damage=1.35, lifetime=0.5, technology="flamethrower", flame={0.35,0.7,1}, smoke={0.62,0.73,0.83,0.16}},
    {id="kerosene", fluid="ei-kerosene", damage=1.45, lifetime=0.75, technology="ei-destill-tower", flame={1,0.93,0.66}, smoke={0.7,0.7,0.66,0.2}},
    {id="diesel", fluid="ei-diesel", damage=1.6, lifetime=2, technology="advanced-oil-processing", flame={1,0.73,0.48}, smoke={0.22,0.22,0.22,0.7}},
}
model.by_fluid = {}
model.by_turret = {}
-- Exact effect identities shared by the final notification pass and runtime
-- cleanup. Performance profiles make private vanilla copies; fuel variants
-- already have private turret effects. Acid and tree fire never enter these sets.
---@type table<string, boolean>
model.fire_stickers = {["fire-sticker"]=true, ["ei-thrower-performance-fire-sticker"]=true}
---@type table<string, boolean>
model.ground_fires = {["fire-flame"]=true, ["ei-thrower-performance-fire-flame"]=true}
---@type string[]
model.ground_fire_names = {"fire-flame", "ei-thrower-performance-fire-flame"}
for _,fuel in ipairs(model.fuels) do
    fuel.ammo = fuel.id=="crude-oil" and "flamethrower-ammo" or "ei-flamethrower-ammo-"..fuel.id
    fuel.turret = "ei-flamethrower-turret-"..fuel.id
    model.by_fluid[fuel.fluid] = fuel
    model.by_turret[fuel.turret] = fuel
    for _,kind in ipairs{"ammo","turret"} do
        local prefix="ei-flame-"..fuel.id.."-"..kind
        model.fire_stickers[prefix.."-sticker"]=true
        model.ground_fires[prefix.."-fire"]=true
        model.ground_fire_names[#model.ground_fire_names+1]=prefix.."-fire"
    end
end
return model
